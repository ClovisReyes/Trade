-- Keenan Hub - Fish It "Trade by Coin" Valuation & Debug Inspector
-- Inspects exact fish price formulas, weight multipliers, variant multipliers, inventory valuation, and simulates coin-target trade selection.

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
local math_huge     = math.huge

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

-- Services and Module References
local variables = {
    items        = replicated_storage:FindFirstChild("Items"),
    variants     = replicated_storage:FindFirstChild("Variants"),
    packages     = replicated_storage:FindFirstChild("Packages"),
    shared       = replicated_storage:FindFirstChild("Shared"),
    tiers        = replicated_storage:FindFirstChild("Tiers"),
}

local replion_mod = nil
if variables.packages then
    local replion_obj = variables.packages:FindFirstChild("Replion")
    if replion_obj then
        local ok, res = pcall(require, replion_obj)
        if ok then replion_mod = res end
    end
end

local player_data = nil
if replion_mod and replion_mod.Client then
    pcall(function()
        player_data = replion_mod.Client:WaitReplion("Data")
    end)
end

local item_utility = nil
if variables.shared and variables.shared:FindFirstChild("ItemUtility") then
    local ok, res = pcall(require, variables.shared.ItemUtility)
    if ok then item_utility = res end
end

local function format_number(n)
    if not n or n ~= n then return "0" end
    local formatted = tostring(math_floor(n))
    local k
    while true do
        formatted, k = string_gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

local function parse_formatted_number(str)
    if not str then return 0 end
    local clean = string_gsub(str, "[,%s_]", "")
    local mult = 1
    if string_find(string_lower(clean), "k$") then
        mult = 1000
        clean = string_sub(clean, 1, -2)
    elseif string_find(string_lower(clean), "m$") then
        mult = 1000000
        clean = string_sub(clean, 1, -2)
    elseif string_find(string_lower(clean), "b$") then
        mult = 1000000000
        clean = string_sub(clean, 1, -2)
    end
    local val = tonumber(clean)
    return val and (val * mult) or 0
end

-- ============================================================================
-- GAME VALUATION & PRICE DISCOVERY ENGINE
-- ============================================================================

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

-- Discover Price Method from ItemUtility / Game Modules
local function inspect_item_utility_methods()
    local methods = {}
    if item_utility and type(item_utility) == "table" then
        for k, v in pairs(item_utility) do
            table_insert(methods, { name = tostring(k), value_type = type(v), value_str = tostring(v) })
        end
    end
    return methods
end

-- Scan Variant & Mutation Multipliers
local function inspect_variants_data()
    local variant_info = {}
    if variables.variants then
        for _, v in ipairs(variables.variants:GetChildren()) do
            if v:IsA("ModuleScript") then
                local success, data = pcall(require, v)
                if success and type(data) == "table" and data.Data then
                    variant_info[data.Data.Name or v.Name] = data.Data
                end
            end
        end
    end
    return variant_info
end

-- Calculate Sell Value of an individual fish
local function calculate_fish_value(fish_data, inventory_item, variant_lookup)
    if not fish_data or not fish_data.Data then
        return 0, "No ItemData", {}
    end

    local d = fish_data.Data
    local meta = inventory_item.Metadata or {}
    local details = {
        base_price = d.Price or d.SellPrice or d.BasePrice or d.Value or 0,
        weight = meta.Weight or d.Weight or 1,
        variant_id = meta.VariantId or meta.Variant or meta.Mutation or "None",
        is_shiny = (meta.Shiny == true or meta.Shiny == 1 or inventory_item.Shiny == true),
        multiplier = 1,
        calculation_method = "Native"
    }

    -- 1. Try Native ItemUtility Functions if available
    if item_utility then
        local candidate_funcs = {"GetSellPrice", "CalculateSellPrice", "GetPrice", "CalculatePrice", "GetItemPrice", "GetItemValue", "CalculateItemPrice"}
        for _, fname in ipairs(candidate_funcs) do
            if type(item_utility[fname]) == "function" then
                local ok, res = pcall(function()
                    return item_utility[fname](item_utility, inventory_item) or item_utility[fname](inventory_item) or item_utility[fname](fish_data, inventory_item)
                end)
                if ok and type(res) == "number" and res > 0 then
                    details.calculation_method = "ItemUtility." .. fname
                    return res, details.calculation_method, details
                end
            end
        end
    end

    -- 2. Formula fallback based on Fish It engine standard
    -- Price = BasePrice * (Weight / BaseWeight) * VariantMultiplier * ShinyMultiplier
    local base_price = details.base_price
    local weight = details.weight
    local var_mult = 1

    if details.variant_id ~= "None" and variant_lookup and variant_lookup[details.variant_id] then
        local vdata = variant_lookup[details.variant_id]
        var_mult = vdata.SellMultiplier or vdata.PriceMultiplier or vdata.Multiplier or 1.5
    elseif details.variant_id == "Gemstone" then
        var_mult = 2.5
    elseif details.variant_id ~= "None" then
        var_mult = 1.5
    end

    local shiny_mult = details.is_shiny and 2.0 or 1.0

    local final_price = math_floor(base_price * weight * var_mult * shiny_mult)
    if final_price < base_price and base_price > 0 then
        final_price = base_price
    end

    details.multiplier = var_mult * shiny_mult
    details.calculation_method = "Formula (BasePrice * Weight * Variant * Shiny)"

    return final_price, details.calculation_method, details
end

-- ============================================================================
-- INVENTORY VALUATION & SIMULATION ENGINE
-- ============================================================================

local function scan_and_evaluate_inventory(target_coin)
    target_coin = target_coin or 8000000
    local variant_lookup = inspect_variants_data()
    local utility_methods = inspect_item_utility_methods()

    local report = {
        meta = {
            target_coin = target_coin,
            player_name = local_player.Name,
            timestamp = os.time()
        },
        utility_methods = utility_methods,
        variants_data = variant_lookup,
        fishes = {},
        total_fishes_count = 0,
        total_inventory_worth = 0,
        worth_by_tier = {},
        count_by_tier = {},
        simulation = {
            target_coin = target_coin,
            achievable = false,
            total_selected_value = 0,
            total_selected_count = 0,
            excess_amount = 0,
            trades_needed = 0,
            batches = {},
            selected_fish = {}
        }
    }

    if not player_data then
        return report
    end

    local inv_ok, inventory = pcall(function() return player_data:Get("Inventory") end)
    local items = (inv_ok and inventory and inventory.Items) or {}

    for _, item in ipairs(items) do
        if item.Id then
            local is_fav = (item.Favorited == true or (item.Metadata and item.Metadata.Favorited == true))
            local item_data = item_utility and item_utility:GetItemData(item.Id) or nil
            if item_data and item_data.Data and item_data.Data.Type == "Fish" then
                local d = item_data.Data
                local val, method, details = calculate_fish_value(item_data, item, variant_lookup)
                local tier = d.Tier or 1

                local fish_entry = {
                    id = item.Id,
                    uuid = item.UUID,
                    name = d.Name,
                    tier = tier,
                    value = val,
                    method = method,
                    details = details,
                    favorited = is_fav,
                    raw = item
                }

                table_insert(report.fishes, fish_entry)
                report.total_fishes_count = report.total_fishes_count + 1
                report.total_inventory_worth = report.total_inventory_worth + val

                local tier_key = "Tier " .. tostring(tier)
                report.worth_by_tier[tier_key] = (report.worth_by_tier[tier_key] or 0) + val
                report.count_by_tier[tier_key] = (report.count_by_tier[tier_key] or 0) + 1
            end
        end
    end

    -- ========================================================================
    -- SMART COIN-TARGET SELECTION ALGORITHM (Optimized Knapsack-Greedy Hybrid)
    -- ========================================================================
    -- Goal: Reach >= target_coin with MINIMUM OVERPAY, selecting unfavorited fish first
    -- Strategy:
    -- 1. Filter usable fish (unfavorited by default)
    -- 2. Sort available fish ascending and descending
    -- 3. Use greedy high-value fish to close the large gap, then fine-tune with lowest-value fish near the target

    local candidate_pool = {}
    for _, f in ipairs(report.fishes) do
        if not f.favorited then
            table_insert(candidate_pool, f)
        end
    end

    -- Sort candidates descending by price
    table_sort(candidate_pool, function(a, b)
        return a.value > b.value
    end)

    local accumulated_value = 0
    local selected_list = {}
    local remaining_target = target_coin

    -- Pass 1: Add larger items while gap is large
    local pool_idx = 1
    while pool_idx <= #candidate_pool and accumulated_value < target_coin do
        local current = candidate_pool[pool_idx]
        local next_rem = target_coin - accumulated_value

        -- If this item is <= remaining target, or if it's the smallest big-step we need
        if current.value <= next_rem or (pool_idx == #candidate_pool and accumulated_value < target_coin) then
            table_insert(selected_list, current)
            accumulated_value = accumulated_value + current.value
            table_remove(candidate_pool, pool_idx)
        else
            -- We are close to the target! Switch to ascending order to find the smallest item that hits or barely exceeds target
            break
        end
    end

    -- Pass 2: Fine-tune near threshold using smallest possible fish
    if accumulated_value < target_coin and #candidate_pool > 0 then
        -- Sort remaining candidates ascending (smallest price first)
        table_sort(candidate_pool, function(a, b)
            return a.value < b.value
        end)

        -- Find the single smallest item that fulfills the remaining gap
        local needed = target_coin - accumulated_value
        local best_single_idx = nil
        for i, f in ipairs(candidate_pool) do
            if f.value >= needed then
                best_single_idx = i
                break
            end
        end

        if best_single_idx then
            -- Single smallest item covers the remaining gap perfectly!
            table_insert(selected_list, candidate_pool[best_single_idx])
            accumulated_value = accumulated_value + candidate_pool[best_single_idx].value
            table_remove(candidate_pool, best_single_idx)
        else
            -- Stack multiple small items until target is reached
            while #candidate_pool > 0 and accumulated_value < target_coin do
                local smallest = table_remove(candidate_pool, 1)
                table_insert(selected_list, smallest)
                accumulated_value = accumulated_value + smallest.value
            end
        end
    end

    -- Split into 20-item trade batches
    local batches = {}
    local current_batch = {}
    local current_batch_val = 0

    for idx, item in ipairs(selected_list) do
        table_insert(current_batch, item)
        current_batch_val = current_batch_val + item.value

        if #current_batch == 20 or idx == #selected_list then
            table_insert(batches, {
                batch_number = #batches + 1,
                items_count = #current_batch,
                total_value = current_batch_val,
                items = current_batch
            })
            current_batch = {}
            current_batch_val = 0
        end
    end

    report.simulation.achievable = (accumulated_value >= target_coin)
    report.simulation.total_selected_value = accumulated_value
    report.simulation.total_selected_count = #selected_list
    report.simulation.excess_amount = math_max(0, accumulated_value - target_coin)
    report.simulation.trades_needed = #batches
    report.simulation.batches = batches
    report.simulation.selected_fish = selected_list

    return report
end

-- ============================================================================
-- FORMATTERS
-- ============================================================================

local current_target = 8000000
local report_data = scan_and_evaluate_inventory(current_target)

local function format_formulas_tab(report)
    local lines = {}
    table_insert(lines, "=== COIN VALUATION & FORMULA DISCOVERY ===")
    table_insert(lines, "Inspecting how Fish It calculates Sell Value for Fish:")
    table_insert(lines, "")

    table_insert(lines, "--- [1] ITEM UTILITY METHODS DISCOVERED ---")
    if #report.utility_methods == 0 then
        table_insert(lines, " (ItemUtility module not loaded or empty)")
    else
        for _, m in ipairs(report.utility_methods) do
            table_insert(lines, string_format(" • %-24s [%s] -> %s", m.name, m.value_type, m.value_str))
        end
    end
    table_insert(lines, "")

    table_insert(lines, "--- [2] VARIANT & MUTATION MULTIPLIERS DETECTED ---")
    local var_count = 0
    for vname, vdata in pairs(report.variants_data) do
        var_count = var_count + 1
        table_insert(lines, string_format(" • Variant: %-18s -> %s", vname, safe_serialize(vdata, 2)))
    end
    if var_count == 0 then
        table_insert(lines, " (No variants found in ReplicatedStorage.Variants)")
    end
    table_insert(lines, "")

    table_insert(lines, "--- [3] VALUATION FORMULA BREAKDOWN ---")
    table_insert(lines, "• Base Formula: FinalPrice = BasePrice * Weight * VariantMultiplier * ShinyMultiplier")
    table_insert(lines, "• Shiny Multiplier: 2.0x")
    table_insert(lines, "• Gemstone Variant Multiplier: 2.5x")
    table_insert(lines, "• Standard Variant Multiplier: 1.5x")

    return table_concat(lines, "\n")
end

local function format_inventory_tab(report)
    local lines = {}
    table_insert(lines, "=== INVENTORY VALUATION AUDIT ===")
    table_insert(lines, string_format("Total Fish in Bag: %d items", report.total_fishes_count))
    table_insert(lines, string_format("Total Estimated Bag Worth: %s Coins", format_number(report.total_inventory_worth)))
    table_insert(lines, "")

    table_insert(lines, "--- WORTH BREAKDOWN BY TIER ---")
    for t_name, worth in pairs(report.worth_by_tier) do
        local count = report.count_by_tier[t_name] or 0
        table_insert(lines, string_format(" • %-10s: %-4d fish | Total Worth: %12s Coins", t_name, count, format_number(worth)))
    end
    table_insert(lines, "")

    table_insert(lines, "--- ALL FISH IN INVENTORY (Sorted by Price Descending) ---")
    local sorted_fish = {}
    for _, f in ipairs(report.fishes) do table_insert(sorted_fish, f) end
    table_sort(sorted_fish, function(a, b) return a.value > b.value end)

    for idx, f in ipairs(sorted_fish) do
        local d = f.details or {}
        local fav_tag = f.favorited and "[FAVORITED] " or ""
        local var_tag = (d.variant_id and d.variant_id ~= "None") and (" | " .. d.variant_id) or ""
        local shiny_tag = d.is_shiny and " | SHINY" or ""
        table_insert(lines, string_format(" %03d. %s%-20s | Tier %s | W: %.1fkg%s%s -> %9s Coins",
            idx, fav_tag, f.name, tostring(f.tier), d.weight or 1, var_tag, shiny_tag, format_number(f.value)))
    end

    return table_concat(lines, "\n")
end

local function format_simulation_tab(report)
    local sim = report.simulation
    local lines = {}
    table_insert(lines, "=== 'TRADE BY COIN' SMART SIMULATION ===")
    table_insert(lines, string_format("Target Amount Requested: %s Coins", format_number(sim.target_coin)))
    table_insert(lines, string_format("Total Inventory Value:   %s Coins", format_number(report.total_inventory_worth)))
    table_insert(lines, string_format("Status:                  %s", sim.achievable and "✅ TARGET REACHABLE!" or "❌ INSUFFICIENT FISH IN INVENTORY"))
    table_insert(lines, "")

    table_insert(lines, "--- SIMULATION RESULT SUMMARY ---")
    table_insert(lines, string_format(" • Total Value Selected: %s Coins", format_number(sim.total_selected_value)))
    table_insert(lines, string_format(" • Total Fish Used:      %d fish", sim.total_selected_count))
    table_insert(lines, string_format(" • Total Trades Needed:  %d trade session(s)", sim.trades_needed))
    table_insert(lines, string_format(" • Difference (Over):    +%s Coins (%.2f%% excess)", format_number(sim.excess_amount), sim.target_coin > 0 and (sim.excess_amount / sim.target_coin * 100) or 0))
    table_insert(lines, "")

    table_insert(lines, "--- TRADE SESSIONS BATCHING (Max 20 Items per Trade Window) ---")
    if #sim.batches == 0 then
        table_insert(lines, " (No batches generated)")
    else
        for _, b in ipairs(sim.batches) do
            table_insert(lines, string_format(" ▶ [TRADE #%d] %d Fish | Subtotal: %s Coins", b.batch_number, b.items_count, format_number(b.total_value)))
            for item_idx, item in ipairs(b.items) do
                local d = item.details or {}
                local var_str = (d.variant_id and d.variant_id ~= "None") and (" (" .. d.variant_id .. ")") or ""
                table_insert(lines, string_format("     #%02d: %-20s | W: %.1fkg%s -> %8s Coins", item_idx, item.name, d.weight or 1, var_str, format_number(item.value)))
            end
            table_insert(lines, "")
        end
    end

    table_insert(lines, "--- ALGORITHM STRATEGY USED ---")
    table_insert(lines, "1. Uses high-value fish to close the bulk gap rapidly.")
    table_insert(lines, "2. Switches to smallest available fish when nearing target so the excess is minimized.")
    table_insert(lines, "3. Automatically ignores Favorited fish to protect precious collection.")

    return table_concat(lines, "\n")
end

local function format_raw_json(report)
    local ok, json = pcall(function() return http_service:JSONEncode(report) end)
    return ok and json or safe_serialize(report, 4)
end

-- ============================================================================
-- GUI DISPLAY
-- ============================================================================

local gui = Instance_new("ScreenGui")
gui.Name = "KeenanHub_CoinDebugger"
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

-- Main Window Frame
local main = Instance_new("Frame")
main.Name = "CoinDebugWindow"
main.Size = UDim2_new(0, 540, 0, 400)
main.Position = UDim2_new(0.5, -270, 0.5, -200)
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
title_lbl.Text = "Keenan Hub - Trade By Coin Value Inspector"
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

-- Target Input Row
local input_bar = Instance_new("Frame")
input_bar.Size = UDim2_new(1, -20, 0, 26)
input_bar.Position = UDim2_new(0, 10, 0, 38)
input_bar.BackgroundTransparency = 1
input_bar.Parent = main

local input_lbl = Instance_new("TextLabel")
input_lbl.Size = UDim2_new(0, 120, 1, 0)
input_lbl.BackgroundTransparency = 1
input_lbl.Text = "Target Coin Amount:"
input_lbl.TextColor3 = TEXT_COLOR
input_lbl.TextSize = 10
input_lbl.FontFace = font_bold
input_lbl.TextXAlignment = Enum.TextXAlignment.Left
input_lbl.Parent = input_bar

local coin_input_box = Instance_new("TextBox")
coin_input_box.Size = UDim2_new(0, 180, 1, 0)
coin_input_box.Position = UDim2_new(0, 125, 0, 0)
coin_input_box.BackgroundColor3 = INPUT_BG_COLOR
coin_input_box.Text = format_number(current_target)
coin_input_box.PlaceholderText = "e.g. 8,000,000 or 8m"
coin_input_box.TextColor3 = ACCENT_COLOR
coin_input_box.TextSize = 10
coin_input_box.FontFace = font_bold
coin_input_box.Parent = input_bar

local cib_corner = Instance_new("UICorner")
cib_corner.CornerRadius = UDim_new(0, 4)
cib_corner.Parent = coin_input_box

local cib_stroke = Instance_new("UIStroke")
cib_stroke.Color = BORDER_COLOR
cib_stroke.Thickness = 1
cib_stroke.Parent = coin_input_box

local sim_btn = Instance_new("TextButton")
sim_btn.Size = UDim2_new(0, 100, 1, 0)
sim_btn.Position = UDim2_new(0, 312, 0, 0)
sim_btn.BackgroundColor3 = CARD_COLOR
sim_btn.Text = "⚡ Simulate"
sim_btn.TextColor3 = ACCENT_COLOR
sim_btn.TextSize = 10
sim_btn.FontFace = font_bold
sim_btn.Parent = input_bar

local sim_corner = Instance_new("UICorner")
sim_corner.CornerRadius = UDim_new(0, 4)
sim_corner.Parent = sim_btn

local sim_stroke = Instance_new("UIStroke")
sim_stroke.Color = BORDER_COLOR
sim_stroke.Thickness = 1
sim_stroke.Parent = sim_btn

-- Tab Bar
local tab_bar = Instance_new("Frame")
tab_bar.Size = UDim2_new(1, -20, 0, 24)
tab_bar.Position = UDim2_new(0, 10, 0, 68)
tab_bar.BackgroundTransparency = 1
tab_bar.Parent = main

local tab_layout = Instance_new("UIListLayout")
tab_layout.FillDirection = Enum.FillDirection.Horizontal
tab_layout.Padding = UDim_new(0, 6)
tab_layout.Parent = tab_bar

-- Content Viewer
local viewer_frame = Instance_new("Frame")
viewer_frame.Size = UDim2_new(1, -20, 1, -136)
viewer_frame.Position = UDim2_new(0, 10, 0, 96)
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
    viewer_scroll.CanvasSize = UDim2_new(0, 0, 0, display_box.TextBounds.Y + 20)
    display_box.Size = UDim2_new(1, -10, 0, display_box.TextBounds.Y + 10)
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

-- Tabs
local active_tab_btn = nil
local current_tab_id = "simulation"

local tabs = {
    { id = "simulation", name = "Coin Simulation", formatter = format_simulation_tab },
    { id = "inventory",  name = "Bag Valuation",   formatter = format_inventory_tab },
    { id = "formulas",   name = "Price Engine",    formatter = format_formulas_tab },
    { id = "raw_json",   name = "Raw JSON",        formatter = format_raw_json },
}

local function switch_tab(tab_info, btn)
    if active_tab_btn then
        active_tab_btn.BackgroundColor3 = CARD_COLOR
        active_tab_btn.TextColor3 = TEXT_COLOR
    end
    active_tab_btn = btn
    current_tab_id = tab_info.id
    btn.BackgroundColor3 = ACCENT_COLOR
    btn.TextColor3 = BG_COLOR

    display_box.Text = tab_info.formatter(report_data)
    viewer_scroll.CanvasPosition = Vector2.new(0, 0)
end

for idx, tab_info in ipairs(tabs) do
    local btn = Instance_new("TextButton")
    btn.Size = UDim2_new(0, 115, 1, 0)
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

    btn.MouseButton1Click:Connect(function()
        switch_tab(tab_info, btn)
    end)

    if idx == 1 then
        switch_tab(tab_info, btn)
    end
end

-- Actions
local function refresh_all()
    current_target = parse_formatted_number(coin_input_box.Text)
    report_data = scan_and_evaluate_inventory(current_target)
    for _, t in ipairs(tabs) do
        if t.id == current_tab_id then
            display_box.Text = t.formatter(report_data)
            break
        end
    end
end

sim_btn.MouseButton1Click:Connect(refresh_all)
coin_input_box.FocusLost:Connect(function()
    coin_input_box.Text = format_number(parse_formatted_number(coin_input_box.Text))
    refresh_all()
end)

create_action_btn("🔄 Refresh Data", refresh_all)

create_action_btn("📋 Copy Tab Text", function()
    local set_clip = setclipboard or toclipboard or (Clipboard and Clipboard.set)
    if set_clip then set_clip(display_box.Text) end
end)

create_action_btn("💾 Export JSON", function()
    local json_str = format_raw_json(report_data)
    if writefile then
        pcall(function() writefile("FishIt_CoinTrade_Debug.json", json_str) end)
    end
    local set_clip = setclipboard or toclipboard or (Clipboard and Clipboard.set)
    if set_clip then set_clip(json_str) end
end)
