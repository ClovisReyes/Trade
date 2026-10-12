-- ==============================================================================
-- 🔒 FISH IT: ITEM LOCK & TRADE COOLDOWN (15 MENIT) INSPECTOR & DEBUG DUMPER
-- Script untuk memeriksa status Lock & Cooldown Trade 15 Menit pada Inventory
-- ==============================================================================

local ipairs, pairs, tostring, tonumber, pcall, tick, os_time = ipairs, pairs, tostring, tonumber, pcall, tick, os.time
local math_floor, math_max, string_format, string_lower, string_find = math.floor, math.max, string.format, string.lower, string.find

local cloneref = cloneref or function(ref) return ref end
local players = cloneref(game:GetService("Players"))
local local_player = players.LocalPlayer
local replicated_storage = cloneref(game:GetService("ReplicatedStorage"))
local http_service = cloneref(game:GetService("HttpService"))
local user_input_service = cloneref(game:GetService("UserInputService"))
local tween_service = cloneref(game:GetService("TweenService"))
local workspace_service = cloneref(game:GetService("Workspace"))

local core = gethui and pcall(gethui) and gethui() or game:GetService("CoreGui")
local old_gui = core:FindFirstChild("FishItItemLockInspectorGui")
if old_gui then pcall(function() old_gui:Destroy() end) end

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

-- ==============================================================================
-- 1. LOAD GAME MODULES (Replion Data, ItemUtility, TradeData)
-- ==============================================================================
local packages = replicated_storage:WaitForChild("Packages", 5)
local replion_mod = nil
pcall(function()
    local replion_pkg = packages and packages:WaitForChild("Replion", 5)
    if replion_pkg then replion_mod = require(replion_pkg) end
end)

local player_data = nil
if replion_mod and replion_mod.Client then
    pcall(function()
        player_data = replion_mod.Client:WaitReplion("Data")
    end)
end

local item_utility = nil
pcall(function()
    item_utility = require(replicated_storage:WaitForChild("Shared", 5):WaitForChild("ItemUtility", 5))
end)

local trade_data = nil
pcall(function()
    trade_data = require(replicated_storage:WaitForChild("Shared", 5):WaitForChild("Trading", 5):WaitForChild("TradeData", 5))
end)

-- ==============================================================================
-- 2. SAFE TABLE SANITIZER & JSON SERIALIZER
-- ==============================================================================
local function sanitize_table(tbl, depth, seen)
    depth = depth or 0
    if depth > 5 then return "[Depth Limit]" end
    seen = seen or {}
    if seen[tbl] then return "[Circular]" end
    seen[tbl] = true

    local clean = {}
    for k, v in pairs(tbl) do
        local key_str = tostring(k)
        local val_type = type(v)
        if val_type == "table" then
            clean[key_str] = sanitize_table(v, depth + 1, seen)
        elseif val_type == "number" or val_type == "string" or val_type == "boolean" then
            clean[key_str] = v
        else
            clean[key_str] = tostring(v)
        end
    end
    return clean
end

local function to_json_pretty(tbl)
    local ok, res = pcall(function()
        local sanitized = sanitize_table(tbl)
        return http_service:JSONEncode(sanitized)
    end)
    return ok and res or "{}"
end

-- ==============================================================================
-- 3. CORE LOCK & 15-MINUTE TRADE COOLDOWN DETECTOR ENGINE
-- ==============================================================================
local COOLDOWN_DURATION = 15 * 60 -- 15 Menit = 900 Detik

local function get_current_server_time()
    local ok, t = pcall(function() return workspace_service:GetServerTimeNow() end)
    if ok and type(t) == "number" and t > 0 then return t end
    return os_time()
end

local function inspect_item_lock(item)
    local meta = (type(item) == "table" and type(item.Metadata) == "table" and item.Metadata)
        or (type(item) == "table" and type(item.Data) == "table" and item.Data)
        or {}

    local now = get_current_server_time()
    local is_locked = false
    local lock_type = "Unlocked"
    local remaining_seconds = 0
    local reasons = {}
    local details = {
        item_keys = {},
        metadata_keys = {},
        timestamp_detected = nil,
        evaluated_now = now,
    }

    if type(item) == "table" then
        for k, v in pairs(item) do
            if k ~= "Metadata" and k ~= "Data" then
                details.item_keys[tostring(k)] = v
            end
        end
    end
    for k, v in pairs(meta) do
        details.metadata_keys[tostring(k)] = v
    end

    -- 1. Evaluasi Direct Boolean Flags (Locked, TradeLocked, Untradable, dll.)
    local flag_checks = {
        {"TradeLocked", (item and item.TradeLocked == true) or (meta.TradeLocked == true)},
        {"TradeLock",   (item and item.TradeLock == true) or (meta.TradeLock == true)},
        {"Locked",      (item and item.Locked == true) or (meta.Locked == true)},
        {"Untradable",  (item and item.Untradable == true) or (meta.Untradable == true)},
        {"IsLocked",    (item and item.IsLocked == true) or (meta.IsLocked == true)},
        {"Lock",        (item and item.Lock == true) or (meta.Lock == true)},
    }
    for _, check in ipairs(flag_checks) do
        if check[2] then
            is_locked = true
            table.insert(reasons, check[1] .. " = true")
        end
    end

    -- 2. Evaluasi Timestamp / Cooldown (Trade cooldown 15 menit)
    local timestamp_candidates = {
        {"TradeLockTime",     meta.TradeLockTime or (item and item.TradeLockTime)},
        {"TradeLockExpires",  meta.TradeLockExpires or (item and item.TradeLockExpires)},
        {"LockExpires",       meta.LockExpires or (item and item.LockExpires)},
        {"LockTime",          meta.LockTime or (item and item.LockTime)},
        {"TradeCooldown",     meta.TradeCooldown or (item and item.TradeCooldown)},
        {"CooldownExpires",   meta.CooldownExpires or (item and item.CooldownExpires)},
        {"TradedAt",          meta.TradedAt or (item and item.TradedAt)},
        {"TradeTimestamp",    meta.TradeTimestamp or (item and item.TradeTimestamp)},
        {"ReceivedAt",        meta.ReceivedAt or (item and item.ReceivedAt)},
        {"TradedTime",        meta.TradedTime or (item and item.TradedTime)},
        {"TradeLock",         (type(meta.TradeLock) == "number" and meta.TradeLock) or (item and type(item.TradeLock) == "number" and item.TradeLock)},
        {"LockedUntil",       meta.LockedUntil or (item and item.LockedUntil)},
        {"Timestamp",         meta.Timestamp or (item and item.Timestamp)},
    }

    for _, cand in ipairs(timestamp_candidates) do
        local raw_val = cand[2]
        if type(raw_val) == "number" and raw_val > 0 then
            -- Handle millisecond timestamps (13 digits)
            local ts = raw_val > 10000000000 and (raw_val / 1000) or raw_val
            details.timestamp_detected = { key = cand[1], value = ts, raw = raw_val }

            -- Kasus A: Nilai adalah Expiration Timestamp (Kapan cooldown berakhir)
            if ts > (now - 3600) and ts > now then
                local rem = math_floor(ts - now)
                if rem > 0 then
                    is_locked = true
                    remaining_seconds = math_max(remaining_seconds, rem)
                    table.insert(reasons, string_format("%s (Ends in %ds)", cand[1], rem))
                end
            -- Kasus B: Nilai adalah Creation/Traded-At Timestamp (Waktu saat selesai trade)
            elseif ts <= now and (now - ts) < COOLDOWN_DURATION then
                local elapsed = now - ts
                local rem = math_floor(COOLDOWN_DURATION - elapsed)
                if rem > 0 then
                    is_locked = true
                    remaining_seconds = math_max(remaining_seconds, rem)
                    table.insert(reasons, string_format("%s + 15m Cooldown (%ds left)", cand[1], rem))
                end
            end
        end
    end

    -- 3. Evaluasi Resmi Game: TradeData.FollowTradeRules
    local follow_rules_result = nil
    if trade_data and trade_data.FollowTradeRules and item_utility then
        local itemId = item and item.Id
        local itemInfo = itemId and item_utility:GetItemData(itemId)
        if itemInfo then
            local callTarget = itemInfo
            local testItem = {}
            for k, v in pairs(item) do
                -- Jangan exclude flags asli agar hasil FollowTradeRules akurat mendeteksi lock
                testItem[k] = v
            end
            local ok, canTrade = pcall(trade_data.FollowTradeRules, callTarget, testItem)
            if ok and canTrade ~= nil then
                follow_rules_result = canTrade
                if canTrade == false then
                    is_locked = true
                    table.insert(reasons, "TradeData.FollowTradeRules = false")
                end
            end
        end
    end
    details.follow_trade_rules = follow_rules_result

    -- Tentukan Tipe Lock
    if is_locked then
        if remaining_seconds > 0 then
            lock_type = "Cooldown"
        else
            lock_type = "LockedFlag"
        end
    else
        lock_type = "Tradable"
    end

    details.reasons = reasons
    details.is_locked = is_locked
    details.lock_type = lock_type
    details.remaining_seconds = remaining_seconds

    return is_locked, lock_type, remaining_seconds, reasons, details
end

-- Export global agar bisa dipanggil langsung oleh script lain (misal msdm.lua)
_G.CheckFishItItemLock = inspect_item_lock

-- ==============================================================================
-- 4. INVENTORY SCANNER
-- ==============================================================================
local function scan_inventory()
    if not player_data then
        return nil, "Player Data (Replion) belum siap. Pastikan script dieksekusi setelah game selesai loading."
    end

    local inv = player_data:Get("Inventory")
    local items = inv and inv.Items or {}
    local results = {}

    for idx, item in ipairs(items) do
        if item and item.Id then
            local item_info = item_utility and item_utility:GetItemData(item.Id)
            local item_data = (item_info and item_info.Data) or item_info or {}

            local name = item_data.Name or item.Name or ("Item #" .. tostring(item.Id))
            local category = item_data.Type or item_data.Category or "Item"
            local meta = item.Metadata or {}

            local variant_name = nil
            if meta.VariantId and item_utility and item_utility.GetVariantData then
                pcall(function()
                    local v = item_utility.GetVariantData(tonumber(meta.VariantId))
                    if v and v.Data and v.Data.Name then variant_name = v.Data.Name end
                end)
            end

            local is_locked, lock_type, rem_sec, reasons, details = inspect_item_lock(item)

            table.insert(results, {
                index = idx,
                uuid = item.UUID or "No-UUID",
                id = item.Id,
                name = name,
                category = category,
                variant = variant_name,
                is_shiny = meta.Shiny == true,
                is_fav = (item.Favorited == true or meta.Favorited == true),
                is_locked = is_locked,
                lock_type = lock_type,
                remaining_seconds = rem_sec,
                reasons = reasons,
                raw_item = item,
                details = details,
            })
        end
    end

    return results, nil
end

-- ==============================================================================
-- 5. INSPECTOR UI
-- ==============================================================================
local gui = Instance.new("ScreenGui")
gui.Name = "FishItItemLockInspectorGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = core

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 480, 0, 430)
main.Position = UDim2.new(0.5, -240, 0.5, -215)
main.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui

local main_corner = Instance.new("UICorner")
main_corner.CornerRadius = UDim.new(0, 10)
main_corner.Parent = main

local main_stroke = Instance.new("UIStroke")
main_stroke.Color = Color3.fromRGB(45, 52, 70)
main_stroke.Thickness = 1.2
main_stroke.Parent = main

-- Header Dragging
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 32)
header.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
header.BorderSizePixel = 0
header.Parent = main

local header_corner = Instance.new("UICorner")
header_corner.CornerRadius = UDim.new(0, 10)
header_corner.Parent = header

local title_lbl = Instance.new("TextLabel")
title_lbl.Size = UDim2.new(1, -70, 1, 0)
title_lbl.Position = UDim2.new(0, 12, 0, 0)
title_lbl.BackgroundTransparency = 1
title_lbl.Text = "🔒 Fish It: Item Lock & Trade Cooldown Inspector"
title_lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
title_lbl.TextSize = 11.5
title_lbl.Font = Enum.Font.GothamBold
title_lbl.TextXAlignment = Enum.TextXAlignment.Left
title_lbl.Parent = header

local close_btn = Instance.new("TextButton")
close_btn.Size = UDim2.new(0, 26, 0, 22)
close_btn.Position = UDim2.new(1, -32, 0.5, -11)
close_btn.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
close_btn.Text = "X"
close_btn.TextColor3 = Color3.fromRGB(255, 90, 90)
close_btn.TextSize = 11
close_btn.Font = Enum.Font.GothamBold
close_btn.Parent = header
local c_corner = Instance.new("UICorner"); c_corner.CornerRadius = UDim.new(0, 4); c_corner.Parent = close_btn
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

-- Stats Summary Cards
local stats_row = Instance.new("Frame")
stats_row.Size = UDim2.new(1, -20, 0, 36)
stats_row.Position = UDim2.new(0, 10, 0, 40)
stats_row.BackgroundTransparency = 1
stats_row.Parent = main

local function create_stat_card(parent, pos, size, label, val_color)
    local card = Instance.new("Frame")
    card.Position = pos
    card.Size = size
    card.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
    card.BorderSizePixel = 0
    card.Parent = parent
    local cd_corner = Instance.new("UICorner"); cd_corner.CornerRadius = UDim.new(0, 6); cd_corner.Parent = card
    local cd_stroke = Instance.new("UIStroke"); cd_stroke.Color = Color3.fromRGB(38, 45, 60); cd_stroke.Parent = card

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -10, 0, 12)
    lbl.Position = UDim2.new(0, 6, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(140, 150, 170)
    lbl.TextSize = 8.5
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = card

    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(1, -10, 0, 16)
    val.Position = UDim2.new(0, 6, 0, 16)
    val.BackgroundTransparency = 1
    val.Text = "0"
    val.TextColor3 = val_color
    val.TextSize = 12
    val.Font = Enum.Font.GothamBold
    val.TextXAlignment = Enum.TextXAlignment.Left
    val.Parent = card

    return val
end

local stat_total = create_stat_card(stats_row, UDim2.new(0, 0, 0, 0), UDim2.new(0.31, 0, 1, 0), "TOTAL ITEMS", Color3.fromRGB(240, 240, 240))
local stat_locked = create_stat_card(stats_row, UDim2.new(0.34, 0, 0, 0), UDim2.new(0.32, 0, 1, 0), "LOCKED / COOLDOWN", Color3.fromRGB(255, 85, 85))
local stat_tradable = create_stat_card(stats_row, UDim2.new(0.68, 0, 0, 0), UDim2.new(0.32, 0, 1, 0), "TRADABLE (READY)", Color3.fromRGB(75, 225, 135))

-- Filter Tabs & Search
local ctrl_row = Instance.new("Frame")
ctrl_row.Size = UDim2.new(1, -20, 0, 26)
ctrl_row.Position = UDim2.new(0, 10, 0, 82)
ctrl_row.BackgroundTransparency = 1
ctrl_row.Parent = main

local search_box = Instance.new("TextBox")
search_box.Size = UDim2.new(0.4, 0, 1, 0)
search_box.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
search_box.Text = ""
search_box.PlaceholderText = "Search item name/id..."
search_box.PlaceholderColor3 = Color3.fromRGB(110, 120, 140)
search_box.TextColor3 = Color3.fromRGB(240, 240, 240)
search_box.TextSize = 10
search_box.Font = Enum.Font.GothamMedium
search_box.ClearTextOnFocus = false
search_box.Parent = ctrl_row
local sb_corner = Instance.new("UICorner"); sb_corner.CornerRadius = UDim.new(0, 5); sb_corner.Parent = search_box
local sb_stroke = Instance.new("UIStroke"); sb_stroke.Color = Color3.fromRGB(38, 45, 60); sb_stroke.Parent = search_box

local tab_container = Instance.new("Frame")
tab_container.Size = UDim2.new(0.58, 0, 1, 0)
tab_container.Position = UDim2.new(0.42, 0, 0, 0)
tab_container.BackgroundTransparency = 1
tab_container.Parent = ctrl_row
local tc_layout = Instance.new("UIListLayout"); tc_layout.FillDirection = Enum.FillDirection.Horizontal; tc_layout.Padding = UDim.new(0, 4); tc_layout.Parent = tab_container

local active_filter = "All" -- "All", "Locked", "Tradable"
local tab_btns = {}

local function create_tab(name, filter_key)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.32, 0, 1, 0)
    btn.BackgroundColor3 = (active_filter == filter_key) and Color3.fromRGB(45, 100, 200) or Color3.fromRGB(24, 28, 38)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(240, 240, 240)
    btn.TextSize = 9.5
    btn.Font = Enum.Font.GothamBold
    btn.Parent = tab_container
    local b_corner = Instance.new("UICorner"); b_corner.CornerRadius = UDim.new(0, 5); b_corner.Parent = btn
    tab_btns[filter_key] = btn
    return btn
end

-- Scroll Item List
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -175)
scroll.Position = UDim2.new(0, 10, 0, 114)
scroll.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(60, 70, 90)
scroll.Parent = main
local sc_corner = Instance.new("UICorner"); sc_corner.CornerRadius = UDim.new(0, 6); sc_corner.Parent = scroll
local sc_stroke = Instance.new("UIStroke"); sc_stroke.Color = Color3.fromRGB(30, 36, 48); sc_stroke.Parent = scroll

local list_layout = Instance.new("UIListLayout")
list_layout.Padding = UDim.new(0, 3)
list_layout.Parent = scroll

-- Bottom Action Buttons & Status
local bottom_row = Instance.new("Frame")
bottom_row.Size = UDim2.new(1, -20, 0, 48)
bottom_row.Position = UDim2.new(0, 10, 1, -54)
bottom_row.BackgroundTransparency = 1
bottom_row.Parent = main

local status_lbl = Instance.new("TextLabel")
status_lbl.Size = UDim2.new(1, 0, 0, 16)
status_lbl.Position = UDim2.new(0, 0, 0, 0)
status_lbl.BackgroundTransparency = 1
status_lbl.Text = "Ready to inspect inventory."
status_lbl.TextColor3 = Color3.fromRGB(150, 165, 190)
status_lbl.TextSize = 9.5
status_lbl.Font = Enum.Font.GothamMedium
status_lbl.TextXAlignment = Enum.TextXAlignment.Left
status_lbl.TextTruncate = Enum.TextTruncate.AtEnd
status_lbl.Parent = bottom_row

local btn_row = Instance.new("Frame")
btn_row.Size = UDim2.new(1, 0, 0, 26)
btn_row.Position = UDim2.new(0, 0, 0, 20)
btn_row.BackgroundTransparency = 1
btn_row.Parent = bottom_row
local br_layout = Instance.new("UIListLayout"); br_layout.FillDirection = Enum.FillDirection.Horizontal; br_layout.Padding = UDim.new(0, 6); br_layout.Parent = btn_row

local function create_action_btn(text, color, width_scale)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(width_scale, -4, 1, 0)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 9.5
    btn.Font = Enum.Font.GothamBold
    btn.Parent = btn_row
    local b_corner = Instance.new("UICorner"); b_corner.CornerRadius = UDim.new(0, 5); b_corner.Parent = btn
    return btn
end

local refresh_btn   = create_action_btn("🔄 Refresh Scan", Color3.fromRGB(35, 42, 60), 0.32)
local copy_lock_btn = create_action_btn("📋 Copy Locked (JSON)", Color3.fromRGB(180, 50, 50), 0.35)
local copy_all_btn  = create_action_btn("📋 Copy All (JSON)", Color3.fromRGB(35, 110, 180), 0.33)

-- ==============================================================================
-- 6. RENDER LOGIC
-- ==============================================================================
local cached_results = {}

local function format_cooldown(sec)
    local m = math_floor(sec / 60)
    local s = sec % 60
    return string_format("%02dm %02ds", m, s)
end

local function render_items()
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local search_query = string_lower(search_box.Text or "")
    local total_count = #cached_results
    local locked_count = 0
    local tradable_count = 0
    local rendered_count = 0

    for _, res in ipairs(cached_results) do
        if res.is_locked then
            locked_count = locked_count + 1
        else
            tradable_count = tradable_count + 1
        end

        local matches_filter = (active_filter == "All")
            or (active_filter == "Locked" and res.is_locked)
            or (active_filter == "Tradable" and not res.is_locked)

        local display_name = res.name .. (res.variant and (" [" .. res.variant .. "]") or "")
        local matches_search = (search_query == "")
            or string_find(string_lower(display_name), search_query)
            or string_find(string_lower(tostring(res.id)), search_query)
            or string_find(string_lower(res.uuid), search_query)

        if matches_filter and matches_search then
            rendered_count = rendered_count + 1

            local item_card = Instance.new("Frame")
            item_card.Size = UDim2.new(1, -6, 0, 32)
            item_card.BackgroundColor3 = res.is_locked and Color3.fromRGB(28, 20, 24) or Color3.fromRGB(18, 22, 30)
            item_card.BorderSizePixel = 0
            item_card.Parent = scroll
            local ic_corner = Instance.new("UICorner"); ic_corner.CornerRadius = UDim.new(0, 5); ic_corner.Parent = item_card
            local ic_stroke = Instance.new("UIStroke")
            ic_stroke.Color = res.is_locked and Color3.fromRGB(80, 35, 45) or Color3.fromRGB(35, 45, 60)
            ic_stroke.Parent = item_card

            -- Title & Type
            local name_lbl = Instance.new("TextLabel")
            name_lbl.Size = UDim2.new(0.52, 0, 0, 16)
            name_lbl.Position = UDim2.new(0, 8, 0, 2)
            name_lbl.BackgroundTransparency = 1
            name_lbl.Text = display_name
            name_lbl.TextColor3 = res.is_locked and Color3.fromRGB(255, 170, 170) or Color3.fromRGB(240, 240, 240)
            name_lbl.TextSize = 10
            name_lbl.Font = Enum.Font.GothamBold
            name_lbl.TextXAlignment = Enum.TextXAlignment.Left
            name_lbl.TextTruncate = Enum.TextTruncate.AtEnd
            name_lbl.Parent = item_card

            local sub_lbl = Instance.new("TextLabel")
            sub_lbl.Size = UDim2.new(0.52, 0, 0, 12)
            sub_lbl.Position = UDim2.new(0, 8, 0, 17)
            sub_lbl.BackgroundTransparency = 1
            sub_lbl.Text = string_format("ID: %s • UUID: %s", tostring(res.id), string.sub(res.uuid, 1, 8) .. "...")
            sub_lbl.TextColor3 = Color3.fromRGB(120, 130, 150)
            sub_lbl.TextSize = 8
            sub_lbl.Font = Enum.Font.Code
            sub_lbl.TextXAlignment = Enum.TextXAlignment.Left
            sub_lbl.Parent = item_card

            -- Status Tag / Badge
            local tag_badge = Instance.new("Frame")
            tag_badge.Size = UDim2.new(0.32, 0, 0, 20)
            tag_badge.Position = UDim2.new(0.54, 0, 0.5, -10)
            tag_badge.BackgroundColor3 = res.is_locked and Color3.fromRGB(60, 20, 25) or Color3.fromRGB(20, 50, 35)
            tag_badge.BorderSizePixel = 0
            tag_badge.Parent = item_card
            local tb_corner = Instance.new("UICorner"); tb_corner.CornerRadius = UDim.new(0, 4); tb_corner.Parent = tag_badge

            local tag_lbl = Instance.new("TextLabel")
            tag_lbl.Size = UDim2.new(1, -4, 1, 0)
            tag_lbl.Position = UDim2.new(0, 2, 0, 0)
            tag_lbl.BackgroundTransparency = 1
            if res.is_locked then
                if res.remaining_seconds > 0 then
                    tag_lbl.Text = "⏳ " .. format_cooldown(res.remaining_seconds)
                else
                    tag_lbl.Text = "🔒 " .. (res.reasons[1] or "LOCKED")
                end
                tag_lbl.TextColor3 = Color3.fromRGB(255, 100, 100)
            else
                tag_lbl.Text = "🔓 TRADABLE"
                tag_lbl.TextColor3 = Color3.fromRGB(75, 225, 135)
            end
            tag_lbl.TextSize = 8.5
            tag_lbl.Font = Enum.Font.GothamBold
            tag_lbl.TextTruncate = Enum.TextTruncate.AtEnd
            tag_lbl.Parent = tag_badge

            -- Dump Button for Individual Item
            local dump_btn = Instance.new("TextButton")
            dump_btn.Size = UDim2.new(0, 42, 0, 20)
            dump_btn.Position = UDim2.new(1, -48, 0.5, -10)
            dump_btn.BackgroundColor3 = Color3.fromRGB(35, 42, 60)
            dump_btn.Text = "Dump"
            dump_btn.TextColor3 = Color3.fromRGB(200, 210, 230)
            dump_btn.TextSize = 8.5
            dump_btn.Font = Enum.Font.GothamBold
            dump_btn.Parent = item_card
            local d_corner = Instance.new("UICorner"); d_corner.CornerRadius = UDim.new(0, 4); d_corner.Parent = dump_btn

            dump_btn.MouseButton1Click:Connect(function()
                local dump_payload = {
                    item_info = {
                        name = res.name,
                        id = res.id,
                        uuid = res.uuid,
                        is_locked = res.is_locked,
                        lock_type = res.lock_type,
                        remaining_seconds = res.remaining_seconds,
                        reasons = res.reasons,
                    },
                    raw_item = res.raw_item,
                    details = res.details,
                }
                local json_str = to_json_pretty(dump_payload)
                if copy_to_clipboard(json_str) then
                    status_lbl.Text = string_format("Dump '%s' disalin ke Clipboard!", res.name)
                    status_lbl.TextColor3 = Color3.fromRGB(75, 225, 135)
                else
                    status_lbl.Text = "Gagal menyalin (Executor tidak mendukung clipboard)."
                    status_lbl.TextColor3 = Color3.fromRGB(255, 100, 100)
                end
            end)
        end
    end

    stat_total.Text = tostring(total_count)
    stat_locked.Text = tostring(locked_count)
    stat_tradable.Text = tostring(tradable_count)

    scroll.CanvasSize = UDim2.new(0, 0, 0, rendered_count * 35 + 10)
end

local function execute_scan()
    status_lbl.Text = "Scanning inventory..."
    status_lbl.TextColor3 = Color3.fromRGB(255, 200, 80)
    task.wait(0.05)

    local res, err = scan_inventory()
    if err then
        status_lbl.Text = "❌ " .. err
        status_lbl.TextColor3 = Color3.fromRGB(255, 90, 90)
        return
    end

    cached_results = res or {}
    render_items()

    local locked_num = 0
    for _, r in ipairs(cached_results) do if r.is_locked then locked_num = locked_num + 1 end end
    status_lbl.Text = string_format("Scan selesai: %d item total, %d terkunci (cooldown/lock).", #cached_results, locked_num)
    status_lbl.TextColor3 = Color3.fromRGB(75, 225, 135)
end

-- ==============================================================================
-- 7. EVENT CONNECTIONS
-- ==============================================================================
create_tab("Semua", "All")
create_tab("🔒 Terkunci", "Locked")
create_tab("🔓 Tradable", "Tradable")

for key, btn in pairs(tab_btns) do
    btn.MouseButton1Click:Connect(function()
        active_filter = key
        for k, b in pairs(tab_btns) do
            b.BackgroundColor3 = (k == active_filter) and Color3.fromRGB(45, 100, 200) or Color3.fromRGB(24, 28, 38)
        end
        render_items()
    end)
end

search_box:GetPropertyChangedSignal("Text"):Connect(function()
    render_items()
end)

refresh_btn.MouseButton1Click:Connect(function()
    execute_scan()
end)

copy_lock_btn.MouseButton1Click:Connect(function()
    local locked_list = {}
    for _, r in ipairs(cached_results) do
        if r.is_locked then
            table.insert(locked_list, {
                name = r.name,
                id = r.id,
                uuid = r.uuid,
                reasons = r.reasons,
                remaining_seconds = r.remaining_seconds,
                raw = r.raw_item,
                details = r.details,
            })
        end
    end
    local json_str = to_json_pretty({
        scan_timestamp = get_current_server_time(),
        total_locked = #locked_list,
        items = locked_list
    })
    if copy_to_clipboard(json_str) then
        status_lbl.Text = string_format("Berhasil salin data %d item terkunci ke Clipboard!", #locked_list)
        status_lbl.TextColor3 = Color3.fromRGB(75, 225, 135)
    else
        status_lbl.Text = "Gagal menyalin ke Clipboard."
        status_lbl.TextColor3 = Color3.fromRGB(255, 100, 100)
    end
end)

copy_all_btn.MouseButton1Click:Connect(function()
    local all_list = {}
    for _, r in ipairs(cached_results) do
        table.insert(all_list, {
            name = r.name,
            id = r.id,
            uuid = r.uuid,
            is_locked = r.is_locked,
            remaining_seconds = r.remaining_seconds,
            reasons = r.reasons,
            raw = r.raw_item,
        })
    end
    local json_str = to_json_pretty({
        scan_timestamp = get_current_server_time(),
        total_items = #all_list,
        items = all_list
    })
    if copy_to_clipboard(json_str) then
        status_lbl.Text = string_format("Berhasil salin data seluruh %d item ke Clipboard!", #all_list)
        status_lbl.TextColor3 = Color3.fromRGB(75, 225, 135)
    else
        status_lbl.Text = "Gagal menyalin ke Clipboard."
        status_lbl.TextColor3 = Color3.fromRGB(255, 100, 100)
    end
end)

-- Initial Auto-Scan
task.spawn(function()
    task.wait(0.5)
    execute_scan()
end)

print("[FishItLockInspector] Loaded successfully!")
