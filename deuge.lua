-- Keenan Hub - Fish It Sell Script Hunter & Price Extractor (Ultra Fast & Lightweight)
-- Non-freezing async scanner for ItemUtility, Modules, and Merchant UI.

local ipairs        = ipairs
local pairs         = pairs
local tostring      = tostring
local tonumber      = tonumber
local type          = type
local typeof        = typeof
local pcall         = pcall
local os_clock      = os.clock

local table_find    = table.find
local table_insert  = table.insert
local table_remove  = table.remove
local table_sort    = table.sort
local table_concat  = table.concat

local string_lower  = string.lower
local string_upper  = string.upper
local string_sub    = string.sub
local string_find   = string.find
local string_gsub   = string.gsub
local string_format = string.format
local string_match  = string.match

local math_floor    = math.floor

local Color3_fromRGB = Color3.fromRGB
local UDim2_new      = UDim2.new
local UDim_new       = UDim.new
local Instance_new   = Instance.new

if _G.KeenanHub_CoinDebug_Cleanup then
    pcall(_G.KeenanHub_CoinDebug_Cleanup)
end

local cloneref = cloneref or function(ref) return ref end

local players               = cloneref(game:GetService("Players"))
local local_player          = players.LocalPlayer
local user_input_service    = cloneref(game:GetService("UserInputService"))
local replicated_storage    = cloneref(game:GetService("ReplicatedStorage"))
local http_service          = cloneref(game:GetService("HttpService"))
local core_gui              = pcall(function() return cloneref(game:GetService("CoreGui")) end) and cloneref(game:GetService("CoreGui")) or nil
local player_gui            = cloneref(local_player:WaitForChild("PlayerGui"))

-- Theme Colors
local BG_COLOR        = Color3_fromRGB(18, 20, 24)
local CARD_COLOR      = Color3_fromRGB(25, 28, 35)
local SIDEBAR_COLOR   = Color3_fromRGB(22, 25, 30)
local INPUT_BG_COLOR  = Color3_fromRGB(14, 16, 20)
local TEXT_COLOR      = Color3_fromRGB(220, 225, 230)
local MUTED_COLOR     = Color3_fromRGB(120, 130, 140)
local ACCENT_COLOR    = Color3_fromRGB(250, 204, 21)
local BORDER_COLOR    = Color3_fromRGB(38, 42, 52)
local SUCCESS_COLOR   = Color3_fromRGB(34, 197, 94)
local ERROR_COLOR     = Color3_fromRGB(239, 68, 68)

local font_face = Font.fromEnum(Enum.Font.SourceSans)
local font_bold = Font.fromEnum(Enum.Font.SourceSans)

local function format_number(n)
    if not n or n ~= n then return "0" end
    local num = tonumber(n) or 0
    local formatted = tostring(math_floor(num))
    local k
    while true do
        formatted, k = string_gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

local function safe_serialize(obj, max_depth, current_depth)
    current_depth = current_depth or 1
    max_depth = max_depth or 2
    if current_depth > max_depth then return "\"...\"" end

    local t = type(obj)
    if t == "nil" then return "nil"
    elseif t == "boolean" or t == "number" then return tostring(obj)
    elseif t == "string" then return string_format("%q", obj)
    elseif t == "table" then
        local is_array = #obj > 0
        local parts = {}
        if is_array then
            for i, v in ipairs(obj) do
                if i > 8 then table_insert(parts, "..."); break end
                table_insert(parts, safe_serialize(v, max_depth, current_depth + 1))
            end
            return "[" .. table_concat(parts, ", ") .. "]"
        else
            local count = 0
            for k, v in pairs(obj) do
                count = count + 1
                if count > 8 then table_insert(parts, "\"...\" : \"...\""); break end
                table_insert(parts, string_format("%q: %s", tostring(k), safe_serialize(v, max_depth, current_depth + 1)))
            end
            return "{" .. table_concat(parts, ", ") .. "}"
        end
    else
        return string_format("\"[%s]\"", tostring(obj))
    end
end

-- ============================================================================
-- FAST SCANNER LOGIC (No lag, No getgc freeze)
-- ============================================================================

local shared_folder = replicated_storage:FindFirstChild("Shared")
local packages_folder = replicated_storage:FindFirstChild("Packages")
local item_utility = shared_folder and shared_folder:FindFirstChild("ItemUtility") and pcall(require, shared_folder.ItemUtility) and require(shared_folder.ItemUtility) or nil
local replion_mod = packages_folder and packages_folder:FindFirstChild("Replion") and pcall(require, packages_folder.Replion) and require(packages_folder.Replion) or nil
local player_data = replion_mod and replion_mod.Client and pcall(function() return replion_mod.Client:WaitReplion("Data") end) and replion_mod.Client:WaitReplion("Data") or nil

local function run_fast_scan()
    local report = {
        merchant_gui = {},
        item_utility_methods = {},
        sample_fish_calls = {},
        item_modules = {},
        variant_modules = {},
        tier_data = {},
        sample_inventory_fish = {},
        total_items = 0,
        total_fish = 0,
    }

    -- 1. Scan PlayerGui specifically for Sell Dialog
    pcall(function()
        for _, obj in ipairs(player_gui:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                local txt = obj.Text or ""
                local low = string_lower(txt)
                if string_find(low, "sell") or string_find(low, "coins") or string_find(low, "items for") then
                    table_insert(report.merchant_gui, {
                        text = txt,
                        path = obj:GetFullName(),
                    })
                end
            end
        end
    end)

    -- 2. Test ItemUtility
    if item_utility and type(item_utility) == "table" then
        -- List all exported functions
        for k, v in pairs(item_utility) do
            if type(v) == "function" then
                table_insert(report.item_utility_methods, k)
            end
        end
        table_sort(report.item_utility_methods)

        -- Test sample item IDs (Elshark: 269, Ruby: 243, Enchant: 10)
        local test_ids = { 269, 243, 10 }
        for _, id in ipairs(test_ids) do
            local res_entry = { id = id, calls = {} }
            for _, fn_name in ipairs({"GetFish", "GetItemData", "GetFishIdentifiers", "GetVariantData"}) do
                local fn = item_utility[fn_name]
                if type(fn) == "function" then
                    local ok, val = pcall(fn, item_utility, id)
                    if not ok or val == nil then
                        ok, val = pcall(fn, id)
                    end
                    if ok and val ~= nil then
                        res_entry.calls[fn_name] = safe_serialize(val, 2)
                    end
                end
            end
            table_insert(report.sample_fish_calls, res_entry)
        end

        -- Test zero-arg calls (GetFish(), GetVariants(), GetFishIdentifiers())
        for _, fn_name in ipairs({"GetFish", "GetVariants", "GetFishIdentifiers", "GetAllItems"}) do
            local fn = item_utility[fn_name]
            if type(fn) == "function" then
                local ok, val = pcall(fn, item_utility)
                if not ok or val == nil then ok, val = pcall(fn) end
                if ok and val ~= nil then
                    local count = 0
                    local preview_keys = {}
                    if type(val) == "table" then
                        for k in pairs(val) do
                            count = count + 1
                            if count <= 4 then table_insert(preview_keys, tostring(k)) end
                        end
                        report.item_utility_methods[fn_name .. "()"] = string_format("Table with %d entries (keys: %s)", count, table_concat(preview_keys, ", "))
                    else
                        report.item_utility_methods[fn_name .. "()"] = tostring(val)
                    end
                end
            end
        end
    end

    -- 3. Scan Sample Modules in ReplicatedStorage.Items
    local items_f = replicated_storage:FindFirstChild("Items")
    if items_f then
        local count = 0
        for _, mod in ipairs(items_f:GetDescendants()) do
            if mod:IsA("ModuleScript") and count < 4 then
                local ok, data = pcall(require, mod)
                if ok and type(data) == "table" and data.Data and data.Data.Type == "Fish" then
                    count = count + 1
                    table_insert(report.item_modules, {
                        name = mod.Name,
                        full_data = safe_serialize(data, 2)
                    })
                end
            end
        end
    end

    -- 4. Scan Sample Variants in ReplicatedStorage.Variants
    local vars_f = replicated_storage:FindFirstChild("Variants")
    if vars_f then
        local count = 0
        for _, mod in ipairs(vars_f:GetDescendants()) do
            if mod:IsA("ModuleScript") and count < 4 then
                local ok, data = pcall(require, mod)
                if ok and type(data) == "table" then
                    count = count + 1
                    table_insert(report.variant_modules, {
                        name = mod.Name,
                        data = safe_serialize(data, 2)
                    })
                end
            end
        end
    end

    -- 5. Scan ReplicatedStorage.Tiers
    local tiers_mod = replicated_storage:FindFirstChild("Tiers")
    if tiers_mod and tiers_mod:IsA("ModuleScript") then
        local ok, data = pcall(require, tiers_mod)
        if ok and type(data) == "table" then
            report.tier_data = safe_serialize(data, 2)
        end
    end

    -- 6. Sample 5 real fish from inventory
    if player_data then
        local inv_ok, inv = pcall(function() return player_data:Get("Inventory") end)
        local items = (inv_ok and inv and inv.Items) or {}
        report.total_items = #items

        local fish_count = 0
        local sample_count = 0
        for _, itm in ipairs(items) do
            if itm.Id then
                local d = item_utility and item_utility.GetItemData and pcall(function() return item_utility:GetItemData(itm.Id).Data end) and item_utility:GetItemData(itm.Id).Data or {}
                if d.Type == "Fish" then
                    fish_count = fish_count + 1
                    if sample_count < 5 then
                        sample_count = sample_count + 1
                        table_insert(report.sample_inventory_fish, {
                            name = d.Name,
                            id = itm.Id,
                            tier = d.Tier,
                            metadata = itm.Metadata,
                            item_data = d,
                            favorited = itm.Favorited
                        })
                    end
                end
            end
        end
        report.total_fish = fish_count
    end

    return report
end

-- ============================================================================
-- FORMATTERS
-- ============================================================================

local function format_report_tab(report)
    local lines = {}
    table_insert(lines, "=== KEENAN HUB - FISH IT SELL ENGINE SCAN ===")
    table_insert(lines, string_format("Total Bag Items: %s | Total Fish: %s", format_number(report.total_items), format_number(report.total_fish)))
    table_insert(lines, "")

    table_insert(lines, "--- [1] MERCHANT SELL PROMPTS IN PLAYER GUI ---")
    if #report.merchant_gui == 0 then
        table_insert(lines, " (Tidak ada dialog merchant yang aktif)")
        table_insert(lines, " Tips: Dekati NPC Merchant -> Buka prompt jual -> Klik '🔄 Scan'")
    else
        for idx, g in ipairs(report.merchant_gui) do
            table_insert(lines, string_format(" %02d. Text: %q", idx, g.text))
            table_insert(lines, "     Path: " .. g.path)
        end
    end
    table_insert(lines, "")

    table_insert(lines, "--- [2] ITEM UTILITY FUNCTION RETURNS ---")
    for _, item in ipairs(report.sample_fish_calls) do
        table_insert(lines, string_format(" • Testing Item ID %d:", item.id))
        for fn_name, res in pairs(item.calls) do
            table_insert(lines, string_format("     %s -> %s", fn_name, res))
        end
        table_insert(lines, "")
    end

    table_insert(lines, "--- [3] REPLICATEDSTORAGE FISH MODULES ---")
    for idx, m in ipairs(report.item_modules) do
        table_insert(lines, string_format(" %02d. %s: %s", idx, m.name, m.full_data))
    end
    table_insert(lines, "")

    table_insert(lines, "--- [4] REPLICATEDSTORAGE VARIANTS (Mutasi) ---")
    for idx, v in ipairs(report.variant_modules) do
        table_insert(lines, string_format(" %02d. %s: %s", idx, v.name, v.data))
    end
    table_insert(lines, "")

    table_insert(lines, "--- [5] REPLICATEDSTORAGE TIERS ---")
    table_insert(lines, " " .. tostring(report.tier_data))
    table_insert(lines, "")

    table_insert(lines, "--- [6] SAMPLE 5 INVENTORY FISH RAW METADATA ---")
    for idx, s in ipairs(report.sample_inventory_fish) do
        table_insert(lines, string_format(" [%02d] %s (ID: %d | Tier: %s | Fav: %s)", idx, s.name, s.id, tostring(s.tier), tostring(s.favorited)))
        table_insert(lines, "      Metadata: " .. safe_serialize(s.metadata, 2))
        table_insert(lines, "      ItemData: " .. safe_serialize(s.item_data, 2))
        table_insert(lines, "")
    end

    return table_concat(lines, "\n")
end

-- ============================================================================
-- GUI CREATION (Mobile-Friendly, Top Action Buttons)
-- ============================================================================

local gui = Instance_new("ScreenGui")
gui.Name = "KeenanHub_CoinHunter"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local function protect_gui(g)
    if gethui then
        g.Parent = gethui()
    elseif core_gui then
        g.Parent = core_gui
    else
        g.Parent = player_gui
    end
end
protect_gui(gui)

_G.KeenanHub_CoinDebug_Cleanup = function()
    pcall(function() gui:Destroy() end)
end

-- Compact window (480 x 300)
local main = Instance_new("Frame")
main.Name = "HunterWindow"
main.Size = UDim2_new(0, 480, 0, 300)
main.Position = UDim2_new(0.5, -240, 0.5, -150)
main.BackgroundColor3 = BG_COLOR
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui

local main_corner = Instance_new("UICorner")
main_corner.CornerRadius = UDim_new(0, 8)
main_corner.Parent = main

local main_stroke = Instance_new("UIStroke")
main_stroke.Color = BORDER_COLOR
main_stroke.Thickness = 1.2
main_stroke.Parent = main

-- Top Header
local header = Instance_new("Frame")
header.Name = "Header"
header.Size = UDim2_new(1, 0, 0, 32)
header.BackgroundColor3 = SIDEBAR_COLOR
header.BorderSizePixel = 0
header.Parent = main

local header_corner = Instance_new("UICorner")
header_corner.CornerRadius = UDim_new(0, 8)
header_corner.Parent = header

local title_lbl = Instance_new("TextLabel")
title_lbl.Size = UDim2_new(1, -200, 1, 0)
title_lbl.Position = UDim2_new(0, 10, 0, 0)
title_lbl.BackgroundTransparency = 1
title_lbl.Text = "Keenan Hub - Sell Engine Hunter"
title_lbl.TextColor3 = ACCENT_COLOR
title_lbl.TextSize = 11
title_lbl.FontFace = font_bold
title_lbl.TextXAlignment = Enum.TextXAlignment.Left
title_lbl.Parent = header

-- Header Buttons Container
local header_btns = Instance_new("Frame")
header_btns.Size = UDim2_new(0, 180, 1, -6)
header_btns.Position = UDim2_new(1, -185, 0, 3)
header_btns.BackgroundTransparency = 1
header_btns.Parent = header

local h_layout = Instance_new("UIListLayout")
h_layout.FillDirection = Enum.FillDirection.Horizontal
h_layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
h_layout.Padding = UDim_new(0, 5)
h_layout.Parent = header_btns

local function make_header_btn(text, color, width, callback)
    local btn = Instance_new("TextButton")
    btn.Size = UDim2_new(0, width, 1, 0)
    btn.BackgroundColor3 = CARD_COLOR
    btn.Text = text
    btn.TextColor3 = color
    btn.TextSize = 10
    btn.FontFace = font_bold
    btn.Parent = header_btns

    local c = Instance_new("UICorner")
    c.CornerRadius = UDim_new(0, 4)
    c.Parent = btn

    local s = Instance_new("UIStroke")
    s.Color = BORDER_COLOR
    s.Thickness = 1
    s.Parent = btn

    btn.MouseButton1Click:Connect(callback)
    return btn
end

-- Close Button
local close_btn = make_header_btn("X", ERROR_COLOR, 24, function()
    _G.KeenanHub_CoinDebug_Cleanup()
end)

-- Dragging
local dragging, drag_start, start_pos
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging, drag_start, start_pos = true, input.Position, main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
header.InputChanged:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and dragging then
        local delta = input.Position - drag_start
        main.Position = UDim2_new(start_pos.X.Scale, start_pos.X.Offset + delta.X, start_pos.Y.Scale, start_pos.Y.Offset + delta.Y)
    end
end)

-- Content Viewer Box
local viewer_frame = Instance_new("Frame")
viewer_frame.Size = UDim2_new(1, -16, 1, -44)
viewer_frame.Position = UDim2_new(0, 8, 0, 36)
viewer_frame.BackgroundColor3 = INPUT_BG_COLOR
viewer_frame.BorderSizePixel = 0
viewer_frame.Parent = main

local viewer_corner = Instance_new("UICorner")
viewer_corner.CornerRadius = UDim_new(0, 6)
viewer_corner.Parent = viewer_frame

local viewer_stroke = Instance_new("UIStroke")
viewer_stroke.Color = BORDER_COLOR
viewer_stroke.Thickness = 1
viewer_stroke.Parent = viewer_frame

local viewer_scroll = Instance_new("ScrollingFrame")
viewer_scroll.Size = UDim2_new(1, -6, 1, -6)
viewer_scroll.Position = UDim2_new(0, 3, 0, 3)
viewer_scroll.BackgroundTransparency = 1
viewer_scroll.BorderSizePixel = 0
viewer_scroll.ScrollBarThickness = 4
viewer_scroll.ScrollBarImageColor3 = ACCENT_COLOR
viewer_scroll.CanvasSize = UDim2_new(0, 0, 0, 0)
viewer_scroll.Parent = viewer_frame

local display_box = Instance_new("TextBox")
display_box.Size = UDim2_new(1, -10, 1, 0)
display_box.Position = UDim2_new(0, 5, 0, 0)
display_box.BackgroundTransparency = 1
display_box.TextColor3 = TEXT_COLOR
display_box.TextSize = 10
display_box.FontFace = font_face
display_box.TextXAlignment = Enum.TextXAlignment.Left
display_box.TextYAlignment = Enum.TextYAlignment.Top
display_box.ClearTextOnFocus = false
display_box.TextEditable = false
display_box.MultiLine = true
display_box.Text = "⏳ Memulai pemindaian ringan (Scanning game data)..."
display_box.Parent = viewer_scroll

display_box:GetPropertyChangedSignal("TextBounds"):Connect(function()
    viewer_scroll.CanvasSize = UDim2_new(0, 0, 0, display_box.TextBounds.Y + 20)
    display_box.Size = UDim2_new(1, -10, 0, display_box.TextBounds.Y + 10)
end)

-- Header Action Buttons
local scan_btn
local copy_btn

local current_report = nil

local function do_scan()
    display_box.Text = "⏳ Sedang memindai data game (Scanning)..."
    task.spawn(function()
        task.wait(0.05)
        local ok, rep = pcall(run_fast_scan)
        if ok and rep then
            current_report = rep
            local formatted = format_report_tab(rep)
            display_box.Text = formatted
            viewer_scroll.CanvasPosition = Vector2.new(0, 0)
        else
            display_box.Text = "❌ Gagal memindai: " .. tostring(rep)
        end
    end)
end

copy_btn = make_header_btn("📋 Copy", TEXT_COLOR, 60, function()
    local set_clip = setclipboard or toclipboard or (Clipboard and Clipboard.set)
    if set_clip then
        set_clip(display_box.Text)
        copy_btn.Text = "✅ Copied!"
        task.delay(1.5, function()
            pcall(function() copy_btn.Text = "📋 Copy" end)
        end)
    end
end)

scan_btn = make_header_btn("🔄 Scan", ACCENT_COLOR, 60, function()
    do_scan()
end)

-- Start initial scan non-blocking
task.spawn(function()
    task.wait(0.2)
    do_scan()
end)
