-- Keenan Hub - Fish It Sell Script Hunter & Exact Price Extractor
-- Deeply scans ItemUtility, ReplicatedStorage.Items/Variants/Tiers, PlayerGui, and GC functions.

local ipairs        = ipairs
local pairs         = pairs
local tostring      = tostring
local tonumber      = tonumber
local type          = type
local typeof        = typeof
local pcall         = pcall
local tick          = tick
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

local math_max      = math.max
local math_min      = math.min
local math_floor    = math.floor
local math_ceil     = math.ceil
local math_abs      = math.abs

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
local tween_service         = cloneref(game:GetService("TweenService"))
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
local ACCENT_HOVER    = Color3_fromRGB(234, 179, 8)
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

local function format_compact(n)
    local num = tonumber(n) or 0
    if num >= 1e12 then return string_format("%.2fT", num / 1e12) end
    if num >= 1e9  then return string_format("%.2fB", num / 1e9) end
    if num >= 1e6  then return string_format("%.2fM", num / 1e6) end
    if num >= 1e3  then return string_format("%.2fK", num / 1e3) end
    return format_number(num)
end

local function safe_serialize(obj, max_depth, current_depth)
    current_depth = current_depth or 1
    max_depth = max_depth or 3
    if current_depth > max_depth then return "\"...\"" end

    local t = type(obj)
    if t == "nil" then return "nil"
    elseif t == "boolean" or t == "number" then return tostring(obj)
    elseif t == "string" then return string_format("%q", obj)
    elseif t == "table" then
        local is_array = #obj > 0
        local parts = {}
        if is_array then
            for _, v in ipairs(obj) do
                table_insert(parts, safe_serialize(v, max_depth, current_depth + 1))
            end
            return "[" .. table_concat(parts, ", ") .. "]"
        else
            for k, v in pairs(obj) do
                table_insert(parts, string_format("%q: %s", tostring(k), safe_serialize(v, max_depth, current_depth + 1)))
            end
            return "{" .. table_concat(parts, ", ") .. "}"
        end
    else
        return string_format("\"[%s]\"", tostring(obj))
    end
end

-- ============================================================================
-- HUNT SELL MECHANISM & EXTRACTORS
-- ============================================================================

local shared_folder = replicated_storage:FindFirstChild("Shared")
local packages_folder = replicated_storage:FindFirstChild("Packages")
local item_utility = shared_folder and shared_folder:FindFirstChild("ItemUtility") and pcall(require, shared_folder.ItemUtility) and require(shared_folder.ItemUtility) or nil
local replion_mod = packages_folder and packages_folder:FindFirstChild("Replion") and pcall(require, packages_folder.Replion) and require(packages_folder.Replion) or nil
local player_data = replion_mod and replion_mod.Client and pcall(function() return replion_mod.Client:WaitReplion("Data") end) and replion_mod.Client:WaitReplion("Data") or nil

local function run_deep_hunter()
    local report = {
        sell_gui_elements = {},
        item_utility_zero_arg_calls = {},
        item_utility_test_results = {},
        replicated_items_sample = {},
        replicated_variants_sample = {},
        replicated_tiers_sample = {},
        gc_functions_found = {},
        sample_fish_inspections = {},
        sell_remotes = {},
        total_items = 0,
        total_fish = 0,
    }

    -- 1. Scan PlayerGui for Sell Dialog / UI Elements
    for _, obj in ipairs(player_gui:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            local txt = obj.Text or ""
            if string_find(string_lower(txt), "sell") or string_find(string_lower(txt), "coins") or string_find(string_lower(txt), "items for") then
                table_insert(report.sell_gui_elements, {
                    name = obj.Name,
                    path = obj:GetFullName(),
                    text = txt,
                    class = obj.ClassName,
                    parent_gui = obj:FindFirstAncestorOfClass("ScreenGui") and obj:FindFirstAncestorOfClass("ScreenGui").Name or "Unknown"
                })
            end
        end
    end

    -- 2. Test ItemUtility with NO ARGUMENTS and with SAMPLE IDS
    if item_utility and type(item_utility) == "table" then
        -- Zero-arg inspections
        for mname, mfunc in pairs(item_utility) do
            if type(mfunc) == "function" then
                local ok, res = pcall(mfunc)
                if ok and res ~= nil then
                    local preview = ""
                    if type(res) == "table" then
                        local keys = {}
                        local count = 0
                        for k, v in pairs(res) do
                            count = count + 1
                            if count <= 5 then
                                table_insert(keys, tostring(k) .. " (" .. type(v) .. ")")
                            end
                        end
                        preview = string_format("table (total keys: %d, sample keys: %s)", count, table_concat(keys, ", "))
                    else
                        preview = tostring(res)
                    end
                    report.item_utility_zero_arg_calls[mname .. "()"] = preview
                end

                local ok2, res2 = pcall(mfunc, item_utility)
                if ok2 and res2 ~= nil and not report.item_utility_zero_arg_calls[mname .. "()"] then
                    local preview = ""
                    if type(res2) == "table" then
                        local count = 0
                        local keys = {}
                        for k, v in pairs(res2) do
                            count = count + 1
                            if count <= 5 then table_insert(keys, tostring(k)) end
                        end
                        preview = string_format("table (keys: %d, sample: %s)", count, table_concat(keys, ", "))
                    else
                        preview = tostring(res2)
                    end
                    report.item_utility_zero_arg_calls[mname .. "(self)"] = preview
                end
            end
        end

        -- ID-based calls for real sample fish
        local test_ids = { 269, 243, 283, 263, 10 } -- Elshark, Ruby, Squid, Crocodile, Enchant Stone
        for _, id in ipairs(test_ids) do
            local test_entry = { id = id, calls = {} }
            for _, fn_name in ipairs({"GetFish", "GetItemData", "GetFishIdentifiers", "GetVariantData", "GetBaitData"}) do
                local fn = item_utility[fn_name]
                if type(fn) == "function" then
                    local ok, res = pcall(fn, item_utility, id)
                    if ok and res ~= nil then
                        test_entry.calls[fn_name .. "(self, " .. id .. ")"] = safe_serialize(res, 2)
                    else
                        local ok2, res2 = pcall(fn, id)
                        if ok2 and res2 ~= nil then
                            test_entry.calls[fn_name .. "(" .. id .. ")"] = safe_serialize(res2, 2)
                        end
                    end
                end
            end
            table_insert(report.item_utility_test_results, test_entry)
        end
    end

    -- 3. Scan ReplicatedStorage.Items Modules
    local items_folder = replicated_storage:FindFirstChild("Items")
    if items_folder then
        local count = 0
        for _, mod in ipairs(items_folder:GetDescendants()) do
            if mod:IsA("ModuleScript") and count < 6 then
                local ok, data = pcall(require, mod)
                if ok and type(data) == "table" then
                    count = count + 1
                    table_insert(report.replicated_items_sample, {
                        name = mod.Name,
                        path = mod:GetFullName(),
                        raw = safe_serialize(data, 3)
                    })
                end
            end
        end
    end

    -- 4. Scan ReplicatedStorage.Variants Modules
    local variants_folder = replicated_storage:FindFirstChild("Variants")
    if variants_folder then
        local count = 0
        for _, mod in ipairs(variants_folder:GetDescendants()) do
            if mod:IsA("ModuleScript") and count < 6 then
                local ok, data = pcall(require, mod)
                if ok and type(data) == "table" then
                    count = count + 1
                    table_insert(report.replicated_variants_sample, {
                        name = mod.Name,
                        path = mod:GetFullName(),
                        raw = safe_serialize(data, 3)
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
            table_insert(report.replicated_tiers_sample, safe_serialize(data, 3))
        end
    end

    -- 6. Scan GC Functions (if supported by executor)
    pcall(function()
        if getgc then
            local gc_list = getgc(true)
            local fn_count = 0
            for _, v in ipairs(gc_list) do
                if type(v) == "function" and fn_count < 10 then
                    local info = debug.getinfo and debug.getinfo(v)
                    local name = info and (info.name or info.short_src) or ""
                    local consts = getconstants and getconstants(v) or {}
                    local has_keyword = false
                    for _, c in ipairs(consts) do
                        if type(c) == "string" then
                            local clow = string_lower(c)
                            if clow == "sell" or clow == "sellitems" or clow == "fishworth" or clow == "calculateworth" or clow == "getfishprice" then
                                has_keyword = true
                                break
                            end
                        end
                    end
                    if has_keyword then
                        fn_count = fn_count + 1
                        table_insert(report.gc_functions_found, {
                            name = name,
                            constants = safe_serialize(consts, 1),
                            upvalues = getupvalues and safe_serialize(getupvalues(v), 2) or "N/A"
                        })
                    end
                end
            end
        end
    end)

    -- 7. Scan Inventory & Sample Real Fish
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
                    if sample_count < 8 then
                        sample_count = sample_count + 1
                        table_insert(report.sample_fish_inspections, {
                            name = d.Name,
                            id = itm.Id,
                            uuid = itm.UUID,
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

    -- 8. Remotes
    pcall(function()
        local net_folder = replicated_storage.Packages._Index["sleitnick_net@0.2.0"].net
        for _, child in ipairs(net_folder:GetChildren()) do
            if string_find(string_lower(child.Name), "sell") or string_find(string_lower(child.Name), "merchant") then
                table_insert(report.sell_remotes, child.Name)
            end
        end
    end)

    return report
end

-- ============================================================================
-- FORMATTERS
-- ============================================================================

local report_data = run_deep_hunter()

local function format_hunter_tab(report)
    local lines = {}
    table_insert(lines, "=== MERCHANT SELL ENGINE DEEP SCAN ===")
    table_insert(lines, string_format("Total Inventory Items: %s | Total Fish: %s", format_number(report.total_items), format_number(report.total_fish)))
    table_insert(lines, "")

    table_insert(lines, "--- [1] SELL DIALOG ELEMENTS IN PLAYER GUI ---")
    if #report.sell_gui_elements == 0 then
        table_insert(lines, " (No Sell dialog open right now)")
        table_insert(lines, " Tips: Bicara ke Merchant / Buka pop-up 'Would you like to sell' lalu klik Refresh Data!")
    else
        for idx, el in ipairs(report.sell_gui_elements) do
            table_insert(lines, string_format(" %02d. [%s] Text: %q", idx, el.parent_gui .. "." .. el.name, el.text))
            table_insert(lines, "     Path: " .. el.path)
        end
    end
    table_insert(lines, "")

    table_insert(lines, "--- [2] ITEM UTILITY ZERO-ARG CALLS (Table Indexes) ---")
    for call_sig, preview in pairs(report.item_utility_zero_arg_calls) do
        table_insert(lines, string_format(" • %-24s -> %s", call_sig, preview))
    end
    table_insert(lines, "")

    table_insert(lines, "--- [3] ITEM UTILITY FUNCTION RETURNS (Sample Fish) ---")
    for _, t in ipairs(report.item_utility_test_results) do
        table_insert(lines, string_format(" • Testing Item ID %d:", t.id))
        for call_sig, res_val in pairs(t.calls) do
            table_insert(lines, string_format("     %s -> %s", call_sig, res_val))
        end
        table_insert(lines, "")
    end

    table_insert(lines, "--- [4] REPLICATEDSTORAGE.ITEMS SAMPLES (Fish Modules) ---")
    for idx, s in ipairs(report.replicated_items_sample) do
        table_insert(lines, string_format(" %02d. %s [%s]", idx, s.name, s.path))
        table_insert(lines, "     Data: " .. s.raw)
    end
    table_insert(lines, "")

    table_insert(lines, "--- [5] REPLICATEDSTORAGE.VARIANTS SAMPLES ---")
    for idx, v in ipairs(report.replicated_variants_sample) do
        table_insert(lines, string_format(" %02d. %s: %s", idx, v.name, v.raw))
    end
    table_insert(lines, "")

    table_insert(lines, "--- [6] REPLICATEDSTORAGE.TIERS MODULE ---")
    for _, t in ipairs(report.replicated_tiers_sample) do
        table_insert(lines, " " .. t)
    end
    table_insert(lines, "")

    table_insert(lines, "--- [7] GC FUNCTIONS DISCOVERED (Sell / Worth / Price) ---")
    if #report.gc_functions_found == 0 then
        table_insert(lines, " (No specific sell functions found in GC or getgc not enabled)")
    else
        for idx, fn in ipairs(report.gc_functions_found) do
            table_insert(lines, string_format(" %02d. Name: %q", idx, fn.name))
            table_insert(lines, "     Constants: " .. fn.constants)
            table_insert(lines, "     Upvalues:  " .. fn.upvalues)
        end
    end
    table_insert(lines, "")

    table_insert(lines, "--- [8] SELL REMOTES IN SLEITNICK_NET ---")
    if #report.sell_remotes == 0 then
        table_insert(lines, " (None)")
    else
        for _, r in ipairs(report.sell_remotes) do
            table_insert(lines, " • " .. r)
        end
    end

    return table_concat(lines, "\n")
end

local function format_samples_tab(report)
    local lines = {}
    table_insert(lines, "=== SAMPLE FISH RAW DUMPS FROM INVENTORY ===")
    for idx, s in ipairs(report.sample_fish_inspections) do
        table_insert(lines, string_format(" [%02d] %s (ID: %d | Tier: %s)", idx, s.name, s.id, tostring(s.tier)))
        table_insert(lines, "      Metadata:  " .. safe_serialize(s.metadata, 2))
        table_insert(lines, "      ItemData:  " .. safe_serialize(s.item_data, 2))
        table_insert(lines, "      Favorited: " .. tostring(s.favorited))
        table_insert(lines, "")
    end
    return table_concat(lines, "\n")
end

local function format_raw_json(report)
    local ok, json = pcall(function() return http_service:JSONEncode(report) end)
    return ok and json or safe_serialize(report, 4)
end

-- ============================================================================
-- GUI SETUP
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

local main = Instance_new("Frame")
main.Name = "HunterWindow"
main.Size = UDim2_new(0, 580, 0, 440)
main.Position = UDim2_new(0.5, -290, 0.5, -220)
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

-- Header
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
title_lbl.Size = UDim2_new(1, -70, 1, 0)
title_lbl.Position = UDim2_new(0, 10, 0, 0)
title_lbl.BackgroundTransparency = 1
title_lbl.Text = "Keenan Hub - Exact Sell Price Hunter & Trade Simulator"
title_lbl.TextColor3 = ACCENT_COLOR
title_lbl.TextSize = 11
title_lbl.FontFace = font_bold
title_lbl.TextXAlignment = Enum.TextXAlignment.Left
title_lbl.Parent = header

local close_btn = Instance_new("TextButton")
close_btn.Size = UDim2_new(0, 24, 0, 24)
close_btn.Position = UDim2_new(1, -28, 0.5, -12)
close_btn.BackgroundTransparency = 1
close_btn.Text = "X"
close_btn.TextColor3 = MUTED_COLOR
close_btn.TextSize = 11
close_btn.FontFace = font_bold
close_btn.Parent = header

close_btn.MouseEnter:Connect(function() close_btn.TextColor3 = ERROR_COLOR end)
close_btn.MouseLeave:Connect(function() close_btn.TextColor3 = MUTED_COLOR end)
close_btn.MouseButton1Click:Connect(function() _G.KeenanHub_CoinDebug_Cleanup() end)

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

-- Tab Bar
local tab_bar = Instance_new("Frame")
tab_bar.Size = UDim2_new(1, -20, 0, 26)
tab_bar.Position = UDim2_new(0, 10, 0, 38)
tab_bar.BackgroundTransparency = 1
tab_bar.Parent = main

local tab_layout = Instance_new("UIListLayout")
tab_layout.FillDirection = Enum.FillDirection.Horizontal
tab_layout.Padding = UDim_new(0, 6)
tab_layout.Parent = tab_bar

-- Content Viewer
local viewer_frame = Instance_new("Frame")
viewer_frame.Size = UDim2_new(1, -20, 1, -112)
viewer_frame.Position = UDim2_new(0, 10, 0, 70)
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
viewer_scroll.Size = UDim2_new(1, -8, 1, -8)
viewer_scroll.Position = UDim2_new(0, 4, 0, 4)
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
display_box.Parent = viewer_scroll

display_box:GetPropertyChangedSignal("TextBounds"):Connect(function()
    viewer_scroll.CanvasSize = UDim2_new(0, 0, 0, display_box.TextBounds.Y + 30)
    display_box.Size = UDim2_new(1, -10, 0, display_box.TextBounds.Y + 15)
end)

-- Action Bar
local action_bar = Instance_new("Frame")
action_bar.Size = UDim2_new(1, -20, 0, 26)
action_bar.Position = UDim2_new(0, 10, 1, -32)
action_bar.BackgroundTransparency = 1
action_bar.Parent = main

local action_layout = Instance_new("UIListLayout")
action_layout.FillDirection = Enum.FillDirection.Horizontal
action_layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
action_layout.Padding = UDim_new(0, 6)
action_layout.Parent = action_bar

local function create_action_btn(text, callback)
    local btn = Instance_new("TextButton")
    btn.Size = UDim2_new(0, 110, 1, 0)
    btn.BackgroundColor3 = CARD_COLOR
    btn.Text = text
    btn.TextColor3 = ACCENT_COLOR
    btn.TextSize = 10
    btn.FontFace = font_bold
    btn.Parent = action_bar

    local c = Instance_new("UICorner")
    c.CornerRadius = UDim_new(0, 4)
    c.Parent = btn

    local s = Instance_new("UIStroke")
    s.Color = BORDER_COLOR
    s.Thickness = 1
    s.Parent = btn

    btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Color3_fromRGB(35, 40, 50) end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3 = CARD_COLOR end)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

-- Tabs Config
local current_tab_id = "hunter"
local tabs = {
    { id = "hunter",  name = "Sell Engine Scan", formatter = format_hunter_tab },
    { id = "samples", name = "Sample Fish Dumps",formatter = format_samples_tab },
    { id = "raw_json",name = "Raw JSON",         formatter = format_raw_json },
}

local tab_buttons = {}

local function switch_tab(tab_info)
    current_tab_id = tab_info.id
    for _, item in ipairs(tab_buttons) do
        if item.id == tab_info.id then
            item.btn.BackgroundColor3 = ACCENT_COLOR
            item.btn.TextColor3 = BG_COLOR
        else
            item.btn.BackgroundColor3 = CARD_COLOR
            item.btn.TextColor3 = TEXT_COLOR
        end
    end

    local ok, text = pcall(tab_info.formatter, report_data)
    display_box.Text = ok and text or ("Error: " .. tostring(text))
    viewer_scroll.CanvasPosition = Vector2.new(0, 0)
end

for _, tab_info in ipairs(tabs) do
    local btn = Instance_new("TextButton")
    btn.Size = UDim2_new(0, 125, 1, 0)
    btn.BackgroundColor3 = CARD_COLOR
    btn.Text = tab_info.name
    btn.TextColor3 = TEXT_COLOR
    btn.TextSize = 10
    btn.FontFace = font_bold
    btn.Parent = tab_bar

    local btn_c = Instance_new("UICorner")
    btn_c.CornerRadius = UDim_new(0, 4)
    btn_c.Parent = btn

    local btn_s = Instance_new("UIStroke")
    btn_s.Color = BORDER_COLOR
    btn_s.Thickness = 1
    btn_s.Parent = btn

    table_insert(tab_buttons, { id = tab_info.id, btn = btn, info = tab_info })

    btn.MouseButton1Click:Connect(function()
        switch_tab(tab_info)
    end)
end

switch_tab(tabs[1])

local function refresh_all()
    report_data = run_deep_hunter()
    for _, t in ipairs(tabs) do
        if t.id == current_tab_id then
            switch_tab(t)
            break
        end
    end
end

create_action_btn("🔄 Refresh Data", refresh_all)

create_action_btn("📋 Copy Tab Text", function()
    local set_clip = setclipboard or toclipboard or (Clipboard and Clipboard.set)
    if set_clip then set_clip(display_box.Text) end
end)

create_action_btn("💾 Export JSON", function()
    local json_str = format_raw_json(report_data)
    if writefile then
        pcall(function() writefile("FishIt_SellHunter_Debug.json", json_str) end)
    end
    local set_clip = setclipboard or toclipboard or (Clipboard and Clipboard.set)
    if set_clip then set_clip(json_str) end
end)
