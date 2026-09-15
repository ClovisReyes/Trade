-- Keenan Hub - Fish It Sell Script Hunter & Exact Price Extractor + Trade Simulator
-- Fully integrates exact SellPrice + Variant Multipliers with live Coin Target Trade Simulator.

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
local math_ceil     = math.ceil
local math_max      = math.max
local math_min      = math.min

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

local function format_compact(n)
    local num = tonumber(n) or 0
    if num >= 1e12 then return string_format("%.2fT", num / 1e12) end
    if num >= 1e9  then return string_format("%.2fB", num / 1e9) end
    if num >= 1e6  then return string_format("%.2fM", num / 1e6) end
    if num >= 1e3  then return string_format("%.2fK", num / 1e3) end
    return format_number(num)
end

local function parse_coin_input(str)
    if not str or str == "" then return 0 end
    local clean = string_gsub(string_lower(str), "[%s,%$]", "")
    local num, suffix = string_match(clean, "^([%d%.]+)([kmbte]?)$")
    if not num then
        num = string_match(clean, "^([%d%.]+)")
    end
    local val = tonumber(num) or 0
    if suffix == "k" then val = val * 1e3
    elseif suffix == "m" then val = val * 1e6
    elseif suffix == "b" then val = val * 1e9
    elseif suffix == "t" then val = val * 1e12
    end
    return math_floor(val)
end

-- ============================================================================
-- PRICE ENGINE & VARIANT CACHE
-- ============================================================================

local shared_folder = replicated_storage:FindFirstChild("Shared")
local packages_folder = replicated_storage:FindFirstChild("Packages")
local item_utility = shared_folder and shared_folder:FindFirstChild("ItemUtility") and pcall(require, shared_folder.ItemUtility) and require(shared_folder.ItemUtility) or nil
local replion_mod = packages_folder and packages_folder:FindFirstChild("Replion") and pcall(require, packages_folder.Replion) and require(packages_folder.Replion) or nil
local player_data = replion_mod and replion_mod.Client and pcall(function() return replion_mod.Client:WaitReplion("Data") end) and replion_mod.Client:WaitReplion("Data") or nil

local variant_multipliers = {}
local function load_variants()
    variant_multipliers = {}
    local vars_f = replicated_storage:FindFirstChild("Variants")
    if vars_f then
        for _, mod in ipairs(vars_f:GetDescendants()) do
            if mod:IsA("ModuleScript") then
                local ok, data = pcall(require, mod)
                if ok and type(data) == "table" then
                    local mult = tonumber(data.SellMultiplier or (data.Data and data.Data.SellMultiplier)) or 1
                    local name = (data.Data and data.Data.Name) or mod.Name
                    variant_multipliers[string_lower(name)] = mult
                    variant_multipliers[name] = mult
                    if data.Data and data.Data.Id then
                        variant_multipliers[data.Data.Id] = mult
                    end
                end
            end
        end
    end
    if not variant_multipliers["shiny"] then
        variant_multipliers["shiny"] = 1.5
    end
end
pcall(load_variants)

local function calculate_fish_coin_value(item)
    if not item or not item.Id then return 0, 0, 1 end
    local item_info = item_utility and item_utility.GetItemData and pcall(function() return item_utility:GetItemData(item.Id) end) and item_utility:GetItemData(item.Id)
    if not item_info or not item_info.Data or item_info.Data.Type ~= "Fish" then
        return 0, 0, 1
    end

    local base_price = tonumber(item_info.SellPrice) or 0
    if base_price <= 0 then
        local tier = tonumber(item_info.Data.Tier) or 1
        base_price = (tier >= 7 and 250000) or (tier == 6 and 50000) or (tier == 5 and 15000) or (tier == 4 and 5000) or 1000
    end

    local mult = 1
    local meta = item.Metadata
    if meta then
        if meta.VariantId and meta.VariantId ~= "" and meta.VariantId ~= "None" then
            local vname = tostring(meta.VariantId)
            local vmult = variant_multipliers[string_lower(vname)] or variant_multipliers[vname]
            if vmult then
                mult = mult * vmult
            end
        end
        if meta.Shiny == true or meta.Shiny == 1 or (type(meta.Shiny) == "string" and string_lower(meta.Shiny) == "true") then
            if not meta.VariantId or string_lower(tostring(meta.VariantId)) ~= "shiny" then
                mult = mult * (variant_multipliers["shiny"] or 1.5)
            end
        end
    end

    local final_price = math_floor(base_price * mult)
    return final_price, base_price, mult
end

-- ============================================================================
-- SIMULATION ENGINE: Trade by Coin Selection
-- ============================================================================

local function simulate_coin_trade(target_coins)
    local result = {
        target = target_coins,
        total_bag_value = 0,
        total_bag_fish = 0,
        unlocked_fish_count = 0,
        unlocked_fish_value = 0,
        selected_fish = {},
        selected_total_value = 0,
        trades = {},
        excess = 0,
        excess_percent = 0,
        status = "OK",
        status_message = ""
    }

    if not player_data then
        result.status = "ERROR"
        result.status_message = "Player inventory data not ready!"
        return result
    end

    local inv_ok, inv = pcall(function() return player_data:Get("Inventory") end)
    local items = (inv_ok and inv and inv.Items) or {}

    local candidate_pool = {}

    for _, itm in ipairs(items) do
        if itm.Id then
            local val, base_p, mult = calculate_fish_coin_value(itm)
            if val > 0 then
                result.total_bag_fish = result.total_bag_fish + 1
                result.total_bag_value = result.total_bag_value + val

                local is_fav = (itm.Favorited == true or (itm.Metadata and itm.Metadata.Favorited == true))
                if not is_fav then
                    result.unlocked_fish_count = result.unlocked_fish_count + 1
                    result.unlocked_fish_value = result.unlocked_fish_value + val

                    local item_info = item_utility:GetItemData(itm.Id)
                    table_insert(candidate_pool, {
                        raw = itm,
                        id = itm.Id,
                        uuid = itm.UUID,
                        name = item_info.Data.Name,
                        tier = item_info.Data.Tier,
                        weight = (itm.Metadata and itm.Metadata.Weight) or 0,
                        variant = (itm.Metadata and itm.Metadata.VariantId) or "None",
                        shiny = (itm.Metadata and itm.Metadata.Shiny == true),
                        value = val,
                        base_price = base_p,
                        multiplier = mult
                    })
                end
            end
        end
    end

    if target_coins <= 0 then
        result.status = "IDLE"
        result.status_message = "Enter a coin amount (e.g. 8,000,000 or 8M) to simulate!"
        return result
    end

    if result.unlocked_fish_value < target_coins then
        result.status = "INSUFFICIENT"
        result.status_message = string_format("Not enough unlocked fish worth! You have %s coins available (Target: %s coins).", format_number(result.unlocked_fish_value), format_number(target_coins))
        return result
    end

    -- Smart Selection Algorithm:
    -- 1. Sort pool by price descending (big fish first) to close bulk distance
    table_sort(candidate_pool, function(a, b) return a.value > b.value end)

    local chosen = {}
    local current_sum = 0
    local used_indices = {}

    -- Step 1: Greedy bulk filling up to target
    for i, fish in ipairs(candidate_pool) do
        if current_sum + fish.value <= target_coins then
            table_insert(chosen, fish)
            current_sum = current_sum + fish.value
            used_indices[i] = true
            if current_sum == target_coins then
                break
            end
        end
    end

    -- Step 2: If deficit remains, find the single smallest fish that covers the deficit
    if current_sum < target_coins then
        local deficit = target_coins - current_sum
        local best_single_idx = nil
        local best_single_val = math.huge

        for i, fish in ipairs(candidate_pool) do
            if not used_indices[i] then
                if fish.value >= deficit and fish.value < best_single_val then
                    best_single_val = fish.value
                    best_single_idx = i
                end
            end
        end

        if best_single_idx then
            table_insert(chosen, candidate_pool[best_single_idx])
            current_sum = current_sum + candidate_pool[best_single_idx].value
            used_indices[best_single_idx] = true
        else
            -- If no single fish covers deficit, take remaining fish from smallest to largest
            local remaining_small = {}
            for i, fish in ipairs(candidate_pool) do
                if not used_indices[i] then
                    table_insert(remaining_small, { idx = i, fish = fish })
                end
            end
            table_sort(remaining_small, function(a, b) return a.fish.value < b.fish.value end)

            for _, entry in ipairs(remaining_small) do
                table_insert(chosen, entry.fish)
                current_sum = current_sum + entry.fish.value
                used_indices[entry.idx] = true
                if current_sum >= target_coins then
                    break
                end
            end
        end
    end

    result.selected_fish = chosen
    result.selected_total_value = current_sum
    result.excess = current_sum - target_coins
    result.excess_percent = target_coins > 0 and ((result.excess / target_coins) * 100) or 0

    -- Batch into 20-item trade sessions
    local current_batch = {}
    local batch_sum = 0
    for _, fish in ipairs(chosen) do
        table_insert(current_batch, fish)
        batch_sum = batch_sum + fish.value
        if #current_batch == 20 then
            table_insert(result.trades, { items = current_batch, subtotal = batch_sum })
            current_batch = {}
            batch_sum = 0
        end
    end
    if #current_batch > 0 then
        table_insert(result.trades, { items = current_batch, subtotal = batch_sum })
    end

    return result
end

-- ============================================================================
-- FORMATTERS
-- ============================================================================

local current_target = 8000000

local function format_simulation_output(sim)
    local lines = {}
    table_insert(lines, "=== KEENAN HUB - TRADE BY COIN SIMULATOR ===")
    table_insert(lines, string_format("Target Amount:   %s Coins (%s)", format_number(sim.target), format_compact(sim.target)))
    table_insert(lines, string_format("Total Bag Worth: %s Coins (%s) across %s fish", format_number(sim.total_bag_value), format_compact(sim.total_bag_value), format_number(sim.total_bag_fish)))
    table_insert(lines, string_format("Unlocked Worth:  %s Coins (in %s unfavorited fish)", format_number(sim.unlocked_fish_value), format_number(sim.unlocked_fish_count)))
    table_insert(lines, "")

    if sim.status ~= "OK" then
        table_insert(lines, "⚠️ STATUS: " .. sim.status)
        table_insert(lines, " " .. sim.status_message)
        return table_concat(lines, "\n")
    end

    table_insert(lines, "--- [1] SIMULATION RESULT SUMMARY ---")
    table_insert(lines, string_format(" • Total Selected Value: %s Coins (%s)", format_number(sim.selected_total_value), format_compact(sim.selected_total_value)))
    table_insert(lines, string_format(" • Total Fish Used:      %d fish", #sim.selected_fish))
    table_insert(lines, string_format(" • Total Trade Sessions: %d trade(s) (Max 20 items per trade)", #sim.trades))
    table_insert(lines, string_format(" • Excess (Over Target): +%s Coins (+%.2f%%)", format_number(sim.excess), sim.excess_percent))
    table_insert(lines, "")

    table_insert(lines, "--- [2] TRADE SESSIONS BREAKDOWN (20 Items/Trade) ---")
    for t_idx, trade in ipairs(sim.trades) do
        table_insert(lines, string_format(" ▶ [TRADE #%d] %d Fish | Subtotal: %s Coins", t_idx, #trade.items, format_number(trade.subtotal)))
        for i_idx, f in ipairs(trade.items) do
            local var_str = (f.variant ~= "None" and (" [" .. f.variant .. "]")) or ""
            local shiny_str = (f.shiny and " [Shiny]") or ""
            table_insert(lines, string_format("    %02d. %-22s | Tier %s%s%s -> %s Coins", i_idx, f.name, tostring(f.tier), var_str, shiny_str, format_number(f.value)))
        end
        table_insert(lines, "")
    end

    return table_concat(lines, "\n")
end

-- ============================================================================
-- GUI CREATION (Mobile/Cloudphone Friendly, Top Controls)
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

-- Main Window (490 x 320)
local main = Instance_new("Frame")
main.Name = "HunterWindow"
main.Size = UDim2_new(0, 490, 0, 320)
main.Position = UDim2_new(0.5, -245, 0.5, -160)
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
title_lbl.Size = UDim2_new(1, -160, 1, 0)
title_lbl.Position = UDim2_new(0, 10, 0, 0)
title_lbl.BackgroundTransparency = 1
title_lbl.Text = "Keenan Hub - Exact Price & Trade Simulator"
title_lbl.TextColor3 = ACCENT_COLOR
title_lbl.TextSize = 11
title_lbl.FontFace = font_bold
title_lbl.TextXAlignment = Enum.TextXAlignment.Left
title_lbl.Parent = header

-- Header Buttons
local header_btns = Instance_new("Frame")
header_btns.Size = UDim2_new(0, 150, 1, -6)
header_btns.Position = UDim2_new(1, -155, 0, 3)
header_btns.BackgroundTransparency = 1
header_btns.Parent = header

local h_layout = Instance_new("UIListLayout")
h_layout.FillDirection = Enum.FillDirection.Horizontal
h_layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
h_layout.Padding = UDim_new(0, 5)
h_layout.Parent = header_btns

local function make_btn(parent, text, color, width, callback)
    local btn = Instance_new("TextButton")
    btn.Size = UDim2_new(0, width, 1, 0)
    btn.BackgroundColor3 = CARD_COLOR
    btn.Text = text
    btn.TextColor3 = color
    btn.TextSize = 10
    btn.FontFace = font_bold
    btn.Parent = parent

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

make_btn(header_btns, "X", ERROR_COLOR, 24, function()
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

-- Target Input Bar
local input_bar = Instance_new("Frame")
input_bar.Size = UDim2_new(1, -16, 0, 26)
input_bar.Position = UDim2_new(0, 8, 0, 36)
input_bar.BackgroundTransparency = 1
input_bar.Parent = main

local input_lbl = Instance_new("TextLabel")
input_lbl.Size = UDim2_new(0, 65, 1, 0)
input_lbl.BackgroundTransparency = 1
input_lbl.Text = "Target Coins:"
input_lbl.TextColor3 = MUTED_COLOR
input_lbl.TextSize = 10
input_lbl.FontFace = font_face
input_lbl.TextXAlignment = Enum.TextXAlignment.Left
input_lbl.Parent = input_bar

local target_input = Instance_new("TextBox")
target_input.Size = UDim2_new(0, 110, 1, 0)
target_input.Position = UDim2_new(0, 70, 0, 0)
target_input.BackgroundColor3 = INPUT_BG_COLOR
target_input.TextColor3 = ACCENT_COLOR
target_input.Text = "8,000,000"
target_input.TextSize = 10
target_input.FontFace = font_bold
target_input.ClearTextOnFocus = false
target_input.Parent = input_bar

local input_c = Instance_new("UICorner")
input_c.CornerRadius = UDim_new(0, 4)
input_c.Parent = target_input

local input_s = Instance_new("UIStroke")
input_s.Color = BORDER_COLOR
input_s.Thickness = 1
input_s.Parent = target_input

local calc_btn = Instance_new("TextButton")
calc_btn.Size = UDim2_new(0, 75, 1, 0)
calc_btn.Position = UDim2_new(0, 185, 0, 0)
calc_btn.BackgroundColor3 = CARD_COLOR
calc_btn.Text = "⚡ Simulate"
calc_btn.TextColor3 = ACCENT_COLOR
calc_btn.TextSize = 10
calc_btn.FontFace = font_bold
calc_btn.Parent = input_bar

local calc_c = Instance_new("UICorner")
calc_c.CornerRadius = UDim_new(0, 4)
calc_c.Parent = calc_btn

local calc_s = Instance_new("UIStroke")
calc_s.Color = BORDER_COLOR
calc_s.Thickness = 1
calc_s.Parent = calc_btn

-- Presets
local presets_frame = Instance_new("Frame")
presets_frame.Size = UDim2_new(0, 130, 1, 0)
presets_frame.Position = UDim2_new(0, 265, 0, 0)
presets_frame.BackgroundTransparency = 1
presets_frame.Parent = input_bar

local p_layout = Instance_new("UIListLayout")
p_layout.FillDirection = Enum.FillDirection.Horizontal
p_layout.Padding = UDim_new(0, 4)
p_layout.Parent = presets_frame

local function make_preset(text, val)
    local btn = Instance_new("TextButton")
    btn.Size = UDim2_new(0, 38, 1, 0)
    btn.BackgroundColor3 = CARD_COLOR
    btn.Text = text
    btn.TextColor3 = TEXT_COLOR
    btn.TextSize = 10
    btn.FontFace = font_face
    btn.Parent = presets_frame

    local c = Instance_new("UICorner")
    c.CornerRadius = UDim_new(0, 4)
    c.Parent = btn

    local s = Instance_new("UIStroke")
    s.Color = BORDER_COLOR
    s.Thickness = 1
    s.Parent = btn

    btn.MouseButton1Click:Connect(function()
        target_input.Text = format_number(val)
        current_target = val
        if _G.RunSim then _G.RunSim() end
    end)
end

make_preset("1M", 1000000)
make_preset("8M", 8000000)
make_preset("50M", 50000000)

-- Content Viewer Box
local viewer_frame = Instance_new("Frame")
viewer_frame.Size = UDim2_new(1, -16, 1, -72)
viewer_frame.Position = UDim2_new(0, 8, 0, 66)
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
display_box.Text = "⏳ Menghitung simulasi koin (Calculating)..."
display_box.Parent = viewer_scroll

display_box:GetPropertyChangedSignal("TextBounds"):Connect(function()
    viewer_scroll.CanvasSize = UDim2_new(0, 0, 0, display_box.TextBounds.Y + 20)
    display_box.Size = UDim2_new(1, -10, 0, display_box.TextBounds.Y + 10)
end)

local function run_simulation_update()
    local target = parse_coin_input(target_input.Text)
    current_target = target
    display_box.Text = "⏳ Menghitung simulasi trade untuk " .. format_number(target) .. " Coins..."
    task.spawn(function()
        task.wait(0.05)
        local sim = simulate_coin_trade(target)
        display_box.Text = format_simulation_output(sim)
        viewer_scroll.CanvasPosition = Vector2.new(0, 0)
    end)
end
_G.RunSim = run_simulation_update

calc_btn.MouseButton1Click:Connect(run_simulation_update)
target_input.FocusLost:Connect(function(enterPressed)
    if enterPressed then run_simulation_update() end
end)

local copy_btn = make_btn(header_btns, "📋 Copy", TEXT_COLOR, 50, function()
    local set_clip = setclipboard or toclipboard or (Clipboard and Clipboard.set)
    if set_clip then
        set_clip(display_box.Text)
    end
end)

make_btn(header_btns, "🔄", ACCENT_COLOR, 24, function()
    load_variants()
    run_simulation_update()
end)

-- Run initial simulation
task.spawn(function()
    task.wait(0.15)
    run_simulation_update()
end)
