-- ==============================================================================
-- 🔒 FISH IT: ITEM LOCK & TRADE COOLDOWN (15 MENIT) INSPECTOR & DEBUG DUMPER
-- Berdasarkan acuan arsitektur msdm.lua (Ringan, Cepat, Bebas Freeze/Lag)
-- Fitur: Filter Kategori (Fish / Enchant Stone / Semua) & Scan Manual
-- ==============================================================================

local ipairs, pairs, tostring, tonumber, pcall, tick, os_clock = ipairs, pairs, tostring, tonumber, pcall, tick, os.clock
local table_insert, table_concat, table_sort = table.insert, table.concat, table.sort
local string_format, string_lower, string_sub = string.format, string.lower, string.sub
local math_floor, math_max = math.floor, math.max
local task_wait, task_spawn = task.wait, task.spawn

local cloneref = cloneref or function(ref) return ref end
local players = cloneref(game:GetService("Players"))
local local_player = players.LocalPlayer
local user_input_service = cloneref(game:GetService("UserInputService"))
local replicated_storage = cloneref(game:GetService("ReplicatedStorage"))
local http_service = cloneref(game:GetService("HttpService"))
local workspace_service = cloneref(game:GetService("Workspace"))

-- 1. Game Modules (Acuan Persis dari msdm.lua)
local variables = {
    replion      = replicated_storage:WaitForChild("Packages"):WaitForChild("Replion"),
    item_utility = replicated_storage:WaitForChild("Shared"):WaitForChild("ItemUtility"),
}

local success_replion, replion_mod = pcall(require, variables.replion)
local player_data = success_replion and replion_mod.Client:WaitReplion("Data") or nil
local item_utility = require(variables.item_utility)

-- Clipboard Helper
local function copy_to_clipboard(text)
    if setclipboard then
        setclipboard(text)
        return true
    elseif toclipboard then
        toclipboard(text)
        return true
    elseif Clipboard and Clipboard.set then
        Clipboard.set(text)
        return true
    end
    return false
end

-- Safe JSON serializer (Mencegah circular ref / userdata error)
local function safe_json_encode(data)
    local function clean_copy(v, depth)
        depth = depth or 0
        if depth > 4 then return "[Depth Limit]" end
        local tv = type(v)
        if tv == "table" then
            local t = {}
            for k, val in pairs(v) do
                t[tostring(k)] = clean_copy(val, depth + 1)
            end
            return t
        elseif tv == "number" or tv == "string" or tv == "boolean" then
            return v
        else
            return tostring(v)
        end
    end
    local ok, res = pcall(function()
        return http_service:JSONEncode(clean_copy(data))
    end)
    return ok and res or "{}"
end

-- ==============================================================================
-- 2. DETEKSI ITEM LOCK & 15-MINUTE COOLDOWN
-- ==============================================================================
local COOLDOWN_15M = 15 * 60 -- 900 Detik

local function get_server_time()
    local ok, t = pcall(function() return workspace_service:GetServerTimeNow() end)
    if ok and type(t) == "number" and t > 0 then return t end
    return os.time()
end

local function evaluate_item_lock(item)
    if not item or type(item) ~= "table" then return false, nil, 0, {} end

    local meta = (type(item.Metadata) == "table" and item.Metadata)
        or (type(item.Data) == "table" and item.Data)
        or {}

    local is_locked = false
    local lock_type = "Unlocked"
    local remaining_sec = 0
    local reasons = {}
    local now = get_server_time()

    -- 1. Cek Boolean Flag Lock
    if item.TradeLocked == true or meta.TradeLocked == true then
        is_locked = true
        table_insert(reasons, "TradeLocked = true")
    end
    if item.TradeLock == true or meta.TradeLock == true then
        is_locked = true
        table_insert(reasons, "TradeLock = true")
    end
    if item.Locked == true or meta.Locked == true then
        is_locked = true
        table_insert(reasons, "Locked = true")
    end
    if item.Untradable == true or meta.Untradable == true then
        is_locked = true
        table_insert(reasons, "Untradable = true")
    end

    -- 2. Cek Cooldown / Timestamp (15 Menit Cooldown dari Trade)
    local ts_keys = {
        "TradeLockTime", "TradeLockExpires", "LockExpires", "LockTime",
        "TradeCooldown", "CooldownExpires", "TradedAt", "TradeTimestamp",
        "ReceivedAt", "TradeTime", "LockedUntil", "TradeLock", "Timestamp"
    }

    for _, k in ipairs(ts_keys) do
        local val = meta[k] or item[k]
        if type(val) == "number" and val > 0 then
            local ts = val > 10000000000 and (val / 1000) or val
            -- Kasus Expiration (waktu berakhir di masa depan)
            if ts > (now - 3600) and ts > now then
                local rem = math_floor(ts - now)
                if rem > 0 then
                    is_locked = true
                    remaining_sec = math_max(remaining_sec, rem)
                    table_insert(reasons, string_format("%s (Ends in %ds)", k, rem))
                end
            -- Kasus Traded-At (waktu trade dicatat, cooldown 15 menit)
            elseif ts <= now and (now - ts) < COOLDOWN_15M then
                local rem = math_floor(COOLDOWN_15M - (now - ts))
                if rem > 0 then
                    is_locked = true
                    remaining_sec = math_max(remaining_sec, rem)
                    table_insert(reasons, string_format("%s (Cooldown: %ds left)", k, rem))
                end
            end
        end
    end

    if is_locked then
        lock_type = remaining_sec > 0 and "Cooldown" or "FlagLocked"
    end

    return is_locked, lock_type, remaining_sec, reasons
end

-- Export fungsi global untuk digunakan script lain
_G.IsItemTradeLocked = evaluate_item_lock

-- ==============================================================================
-- 3. SCANNER INVENTORY DENGAN FILTER KATEGORI (Acuan dari msdm.lua)
-- ==============================================================================
local function perform_inventory_scan(filter_mode)
    if not player_data then
        return nil, "Player Data belum siap! Pastikan karakter sudah masuk ke game."
    end

    local inv = player_data:Get("Inventory")
    local items = inv and inv.Items or {}

    local total_count = 0
    local locked_count = 0
    local locked_items = {}
    local unlocked_count = 0
    local all_item_keys = {}
    local all_meta_keys = {}

    for idx, itm in ipairs(items) do
        if itm and itm.Id then
            local item_info = item_utility and item_utility:GetItemData(itm.Id)
            local item_data = item_info and item_info.Data or {}
            local item_type = item_data.Type or item_data.Category or "Item"

            -- Filter Kategori Persis seperti di msdm.lua
            local is_match = false
            if filter_mode == "Fish" then
                is_match = (item_type == "Fish")
            elseif filter_mode == "Enchant" then
                is_match = (item_type == "Enchant Stones")
            else
                is_match = true -- Semua Kategori
            end

            if is_match then
                total_count = total_count + 1

                -- Catat semua key yang ditemukan untuk keperluan debug
                for k in pairs(itm) do all_item_keys[tostring(k)] = true end
                if type(itm.Metadata) == "table" then
                    for k in pairs(itm.Metadata) do all_meta_keys[tostring(k)] = true end
                end

                local is_locked, l_type, rem_sec, reasons = evaluate_item_lock(itm)

                local name = item_data.Name or itm.Name or ("Item #" .. tostring(itm.Id))
                local meta = itm.Metadata or {}
                local var_name = nil
                if meta.VariantId and item_utility and item_utility.GetVariantData then
                    pcall(function()
                        local v = item_utility.GetVariantData(tonumber(meta.VariantId))
                        if v and v.Data and v.Data.Name then var_name = v.Data.Name end
                    end)
                end

                if is_locked then
                    locked_count = locked_count + 1
                    table_insert(locked_items, {
                        name = name .. (var_name and (" [" .. var_name .. "]") or ""),
                        id = itm.Id,
                        uuid = itm.UUID or "No-UUID",
                        category = item_type,
                        lock_type = l_type,
                        remaining_sec = rem_sec,
                        reasons = reasons,
                        metadata = itm.Metadata,
                        raw = itm
                    })
                else
                    unlocked_count = unlocked_count + 1
                end
            end
        end
    end

    local item_key_list = {}
    for k in pairs(all_item_keys) do table_insert(item_key_list, k) end
    table_sort(item_key_list)

    local meta_key_list = {}
    for k in pairs(all_meta_keys) do table_insert(meta_key_list, k) end
    table_sort(meta_key_list)

    return {
        target = filter_mode,
        total = total_count,
        locked_count = locked_count,
        unlocked_count = unlocked_count,
        locked_items = locked_items,
        item_keys = item_key_list,
        metadata_keys = meta_key_list,
    }
end

-- ==============================================================================
-- 4. GUI TAMPILAN (Sleek Noir Theme Persis msdm.lua)
-- ==============================================================================
local parent_gui = (gethui and gethui()) or game:GetService("CoreGui")
pcall(function()
    local old = parent_gui:FindFirstChild("FishIt_LockInspector")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "FishIt_LockInspector"
gui.ResetOnSpawn = false
gui.DisplayOrder = 2147483647
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = parent_gui

local BG_COLOR       = Color3.fromRGB(15, 15, 15)
local SIDEBAR_COLOR  = Color3.fromRGB(10, 10, 10)
local ACCENT_COLOR   = Color3.fromRGB(255, 125, 0)
local BUTTON_COLOR   = Color3.fromRGB(235, 95, 20)
local TEXT_COLOR     = Color3.fromRGB(240, 240, 240)
local MUTED_COLOR    = Color3.fromRGB(150, 150, 150)
local CARD_COLOR     = Color3.fromRGB(22, 22, 22)
local INPUT_BG_COLOR = Color3.fromRGB(28, 28, 28)

local font_face = Font.fromEnum(Enum.Font.SourceSans)
local font_bold = Font.fromEnum(Enum.Font.SourceSansBold)

local function create_corner(parent, radius)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, radius); c.Parent = parent; return c
end
local function create_stroke(parent, color, thickness)
    local s = Instance.new("UIStroke"); s.Color = color; s.Thickness = thickness or 1; s.Parent = parent; return s
end

local main = Instance.new("Frame")
main.Name = "MainFrame"
main.Size = UDim2.new(0, 310, 0, 260)
main.Position = UDim2.new(0.5, -155, 0.4, -130)
main.BackgroundColor3 = BG_COLOR
main.Active = true
main.Parent = gui
create_corner(main, 8); create_stroke(main, Color3.fromRGB(45, 45, 45))

-- Header
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 26)
header.BackgroundColor3 = SIDEBAR_COLOR
header.Parent = main
create_corner(header, 8)

local title_lbl = Instance.new("TextLabel")
title_lbl.Size = UDim2.new(1, -90, 1, 0)
title_lbl.Position = UDim2.new(0, 8, 0, 0)
title_lbl.BackgroundTransparency = 1
title_lbl.Text = "NØIR • Lock & Cooldown Inspector"
title_lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
title_lbl.TextSize = 11
title_lbl.FontFace = font_bold
title_lbl.TextXAlignment = Enum.TextXAlignment.Left
title_lbl.Parent = header

local close_btn = Instance.new("TextButton")
close_btn.Size = UDim2.new(0, 20, 0, 20)
close_btn.Position = UDim2.new(1, -24, 0.5, -10)
close_btn.BackgroundTransparency = 1
close_btn.Text = "X"
close_btn.TextColor3 = MUTED_COLOR
close_btn.TextSize = 11
close_btn.Font = Enum.Font.SourceSansBold
close_btn.Parent = header
close_btn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- Drag Logic
local dragging, drag_start, start_pos
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging, drag_start, start_pos = true, input.Position, main.Position
        local end_conn
        end_conn = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                if end_conn then end_conn:Disconnect(); end_conn = nil end
            end
        end)
    end
end)
user_input_service.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - drag_start
        main.Position = UDim2.new(start_pos.X.Scale, start_pos.X.Offset + delta.X, start_pos.Y.Scale, start_pos.Y.Offset + delta.Y)
    end
end)

-- Pilihan Kategori Scan (Filter: Fish / Enchant Stone / Semua)
local filter_row = Instance.new("Frame")
filter_row.Size = UDim2.new(1, -16, 0, 22)
filter_row.Position = UDim2.new(0, 8, 0, 30)
filter_row.BackgroundTransparency = 1
filter_row.Parent = main

local current_filter = "Fish" -- Default: Fish (Ikan)
local filter_buttons = {}

local function create_filter_btn(name, target_key, x_scale, width_scale)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(width_scale, -3, 1, 0)
    btn.Position = UDim2.new(x_scale, 0, 0, 0)
    btn.BackgroundColor3 = (current_filter == target_key) and BUTTON_COLOR or CARD_COLOR
    btn.Text = name
    btn.TextColor3 = (current_filter == target_key) and Color3.fromRGB(255, 255, 255) or MUTED_COLOR
    btn.TextSize = 9.5
    btn.FontFace = font_bold
    btn.Parent = filter_row
    create_corner(btn, 4); create_stroke(btn, Color3.fromRGB(45, 45, 45))
    filter_buttons[target_key] = btn
    return btn
end

local btn_fish    = create_filter_btn("🐟 Fish (Ikan)", "Fish", 0, 0.35)
local btn_enchant = create_filter_btn("💎 Enchant Stone", "Enchant", 0.36, 0.38)
local btn_all     = create_filter_btn("📦 Semua", "All", 0.75, 0.25)

local function update_filter_ui(target_key)
    current_filter = target_key
    for k, btn in pairs(filter_buttons) do
        local is_active = (k == current_filter)
        btn.BackgroundColor3 = is_active and BUTTON_COLOR or CARD_COLOR
        btn.TextColor3 = is_active and Color3.fromRGB(255, 255, 255) or MUTED_COLOR
    end
end

btn_fish.MouseButton1Click:Connect(function() update_filter_ui("Fish") end)
btn_enchant.MouseButton1Click:Connect(function() update_filter_ui("Enchant") end)
btn_all.MouseButton1Click:Connect(function() update_filter_ui("All") end)

-- Stats Row
local stats_row = Instance.new("Frame")
stats_row.Size = UDim2.new(1, -16, 0, 24)
stats_row.Position = UDim2.new(0, 8, 0, 56)
stats_row.BackgroundColor3 = CARD_COLOR
stats_row.Parent = main
create_corner(stats_row, 4); create_stroke(stats_row, Color3.fromRGB(35, 35, 35))

local stat_lbl = Instance.new("TextLabel")
stat_lbl.Size = UDim2.new(1, -12, 1, 0)
stat_lbl.Position = UDim2.new(0, 6, 0, 0)
stat_lbl.BackgroundTransparency = 1
stat_lbl.Text = "Status: Siap scan. Silakan klik [Mulai Scan]."
stat_lbl.TextColor3 = TEXT_COLOR
stat_lbl.TextSize = 9.5
stat_lbl.FontFace = font_bold
stat_lbl.TextXAlignment = Enum.TextXAlignment.Left
stat_lbl.Parent = stats_row

-- Scrolling Report Box
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -16, 1, -118)
scroll.Position = UDim2.new(0, 8, 0, 84)
scroll.BackgroundColor3 = INPUT_BG_COLOR
scroll.ScrollBarThickness = 3
scroll.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
scroll.Parent = main
create_corner(scroll, 5); create_stroke(scroll, Color3.fromRGB(35, 35, 35))

local content_lbl = Instance.new("TextLabel")
content_lbl.Size = UDim2.new(1, -8, 1, 0)
content_lbl.Position = UDim2.new(0, 4, 0, 4)
content_lbl.BackgroundTransparency = 1
content_lbl.Text = "Pilih target scan di atas (Fish / Enchant / Semua),\nlalu tekan tombol [Mulai Scan] di bawah untuk memeriksa status Lock & Cooldown 15 Menit."
content_lbl.TextColor3 = MUTED_COLOR
content_lbl.TextSize = 9.5
content_lbl.FontFace = font_face
content_lbl.TextXAlignment = Enum.TextXAlignment.Left
content_lbl.TextYAlignment = Enum.TextYAlignment.Top
content_lbl.TextWrapped = true
content_lbl.Parent = scroll

-- Bottom Buttons
local scan_btn = Instance.new("TextButton")
scan_btn.Size = UDim2.new(0.48, -4, 0, 24)
scan_btn.Position = UDim2.new(0, 8, 1, -28)
scan_btn.BackgroundColor3 = BUTTON_COLOR
scan_btn.Text = "▶ Mulai Scan"
scan_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
scan_btn.TextSize = 10
scan_btn.FontFace = font_bold
scan_btn.Parent = main
create_corner(scan_btn, 4)

local copy_btn = Instance.new("TextButton")
copy_btn.Size = UDim2.new(0.48, -4, 0, 24)
copy_btn.Position = UDim2.new(0.52, 0, 1, -28)
copy_btn.BackgroundColor3 = CARD_COLOR
copy_btn.Text = "📋 Copy Dump JSON"
copy_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
copy_btn.TextSize = 10
copy_btn.FontFace = font_bold
copy_btn.Parent = main
create_corner(copy_btn, 4); create_stroke(copy_btn, Color3.fromRGB(45, 45, 45))

-- Scanner Controller (Hanya Jalan Saat Tombol Diklik)
local last_scan_data = nil

local function render_report()
    task_spawn(function()
        local target_name = (current_filter == "Fish" and "Ikan") or (current_filter == "Enchant" and "Enchant Stones") or "Semua Item"
        stat_lbl.Text = string_format("Sedang memindai %s...", target_name)
        content_lbl.TextColor3 = TEXT_COLOR
        content_lbl.Text = "Memproses inventory..."
        task_wait(0.05)

        local data, err = perform_inventory_scan(current_filter)
        if not data then
            stat_lbl.Text = "❌ " .. tostring(err)
            content_lbl.Text = "Gagal memindai inventory:\n" .. tostring(err)
            return
        end

        last_scan_data = data
        stat_lbl.Text = string_format("[%s] Total: %d | 🔒 Kunci: %d | 🔓 Siap: %d", current_filter, data.total, data.locked_count, data.unlocked_count)

        local lines = {}
        table_insert(lines, string_format("=== HASIL SCAN: %s ===", target_name:upper()))
        table_insert(lines, string_format("Total: %d item  |  🔒 Terkunci: %d  |  🔓 Tradable: %d", data.total, data.locked_count, data.unlocked_count))
        table_insert(lines, "")

        if data.total == 0 then
            table_insert(lines, "⚠️ Tidak ditemukan item untuk kategori ini di inventory.")
        elseif data.locked_count == 0 then
            table_insert(lines, "✅ Tidak ada item yang terkena Lock / Cooldown 15 Menit.")
            table_insert(lines, string_format("Seluruh %s (%d item) siap untuk di-trade!", target_name, data.unlocked_count))
        else
            table_insert(lines, "--- DAFTAR ITEM TERKUNCI ---")
            for i, itm in ipairs(data.locked_items) do
                local rem_str = itm.remaining_sec > 0 and (math_floor(itm.remaining_sec / 60) .. "m " .. (itm.remaining_sec % 60) .. "s") or "Aktif"
                table_insert(lines, string_format("[%d] 🔒 %s", i, itm.name))
                table_insert(lines, "    • Sisa Cooldown: " .. rem_str)
                table_insert(lines, "    • Alasan Lock: " .. table_concat(itm.reasons, ", "))
                table_insert(lines, "    • UUID: " .. string_sub(tostring(itm.uuid), 1, 12) .. "...")
            end
        end

        table_insert(lines, "")
        table_insert(lines, "--- METADATA KEYS YANG DITEMUKAN ---")
        table_insert(lines, "Keys di Metadata: " .. (#data.metadata_keys > 0 and table_concat(data.metadata_keys, ", ") or "-"))
        table_insert(lines, "Keys di Item: " .. (#data.item_keys > 0 and table_concat(data.item_keys, ", ") or "-"))

        local full_text = table_concat(lines, "\n")
        content_lbl.Text = full_text

        content_lbl.Size = UDim2.new(1, -8, 0, #lines * 14 + 20)
        scroll.CanvasSize = UDim2.new(0, 0, 0, content_lbl.Size.Y.Offset)
    end)
end

scan_btn.MouseButton1Click:Connect(render_report)

copy_btn.MouseButton1Click:Connect(function()
    if not last_scan_data then
        copy_btn.Text = "Scan Dulu!"
        task_wait(1)
        copy_btn.Text = "📋 Copy Dump JSON"
        return
    end

    local json = safe_json_encode(last_scan_data)
    if copy_to_clipboard(json) then
        copy_btn.Text = "Disalin ke Clipboard! ✅"
    else
        copy_btn.Text = "Gagal Salin :("
    end
    task_wait(1.5)
    copy_btn.Text = "📋 Copy Dump JSON"
end)

print("[FishItLockInspector] Loaded successfully. Silakan klik tombol 'Mulai Scan'.")
