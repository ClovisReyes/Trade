-- Keenan Hub - Fish It Exact Merchant Sell Price Hunter & Valuation Inspector
-- Searches game scripts, merchant controllers, and ItemUtility to get the 100% exact sell formula matching the in-game Merchant.

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
local starter_player        = cloneref(game:GetService("StarterPlayer"))

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

local function parse_formatted_number(str)
    if not str then return 0 end
    local clean = string_gsub(tostring(str), "[,%s_]", "")
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
-- HUNT ALL GAME MODULES FOR PRICE & SELL FUNCTIONS
-- ============================================================================

local packages = replicated_storage:FindFirstChild("Packages")
local shared_folder = replicated_storage:FindFirstChild("Shared")
local replion_mod = packages and packages:FindFirstChild("Replion") and pcall(require, packages.Replion) and require(packages.Replion) or nil
local player_data = replion_mod and replion_mod.Client and pcall(function() return replion_mod.Client:WaitReplion("Data") end) and replion_mod.Client:WaitReplion("Data") or nil
local item_utility = shared_folder and shared_folder:FindFirstChild("ItemUtility") and pcall(require, shared_folder.ItemUtility) and require(shared_folder.ItemUtility) or nil

-- Hunt every module in ReplicatedStorage and PlayerScripts
local discovered_sell_modules = {}

local function scan_modules(root)
    if not root then return end
    for _, desc in ipairs(root:GetDescendants()) do
        if desc:IsA("ModuleScript") then
            local n_lower = string_lower(desc.Name)
            if string_find(n_lower, "sell") or string_find(n_lower, "merchant") or string_find(n_lower, "price") or string_find(n_lower, "shop") or string_find(n_lower, "itemutility") or string_find(n_lower, "fishutility") or string_find(n_lower, "economy") or string_find(n_lower, "worth") then
                local success, mod_data = pcall(require, desc)
                if success and type(mod_data) == "table" then
                    local funcs = {}
                    for k, v in pairs(mod_data) do
                        table_insert(funcs, { name = tostring(k), type = type(v) })
                    end
                    table_insert(discovered_sell_modules, {
                        name = desc.Name,
                        fullname = desc:GetFullName(),
                        instance = desc,
                        data = mod_data,
                        keys = funcs
                    })
                end
            end
        end
    end
end

pcall(function() scan_modules(replicated_storage) end)
pcall(function() scan_modules(starter_player) end)
pcall(function() scan_modules(player_gui) end)

-- ============================================================================
-- EXACT SELL PRICE RESOLVER
-- ============================================================================

local function resolve_exact_sell_price(item, item_data)
    if not item or not item.Id then return 0, "No Item" end

    local meta = (type(item) == "table" and item.Metadata) or {}
    local d = (item_data and item_data.Data) or (item_utility and item_utility.GetItemData and pcall(function() return item_utility:GetItemData(item.Id).Data end) and item_utility:GetItemData(item.Id).Data) or {}

    -- Test Method 1: Check discovered modules for sell price functions
    for _, mod in ipairs(discovered_sell_modules) do
        local m = mod.data
        if type(m) == "table" then
            for _, fname in ipairs({"GetSellPrice", "CalculateSellPrice", "GetPrice", "CalculatePrice", "GetItemSellPrice", "GetWorth", "GetFishValue", "GetSellValue", "GetItemPrice"}) do
                if type(m[fname]) == "function" then
                    local ok, res = pcall(function()
                        return m[fname](m, item) or m[fname](item) or m[fname](item, d) or m[fname](d, item) or m[fname](item.Id, meta)
                    end)
                    if ok and type(res) == "number" and res > 0 then
                        return res, mod.name .. ":" .. fname
                    end
                end
            end
        end
    end

    -- Test Method 2: Check ItemUtility directly
    if item_utility and type(item_utility) == "table" then
        for fname, fval in pairs(item_utility) do
            if type(fval) == "function" then
                local ok, res = pcall(function()
                    return item_utility[fname](item_utility, item) or item_utility[fname](item) or item_utility[fname](item.Id, meta)
                end)
                if ok and type(res) == "number" and res > 0 then
                    return res, "ItemUtility." .. fname
                end
            end
        end
    end

    -- Test Method 3: Formula Check based on Fish It Base Price and Weight
    -- In Fish It: Price = BasePrice * (Weight / BaseWeight) * Multipliers or BasePrice * math.sqrt(Weight) or BasePrice * Weight
    local base_price = tonumber(d.Price or d.SellPrice or d.BasePrice or d.Value or 0) or 0
    local raw_weight = tonumber(meta.Weight or d.Weight or 1) or 1
    local base_weight = tonumber(d.BaseWeight or d.DefaultWeight or d.AvgWeight or 1) or 1

    local var_id = tostring(meta.VariantId or meta.Variant or meta.Mutation or "None")
    local is_shiny = (meta.Shiny == true or meta.Shiny == 1 or item.Shiny == true)

    local var_mult = (var_id == "Gemstone" and 2.5) or (var_id ~= "None" and 1.5) or 1
    local shiny_mult = is_shiny and 2.0 or 1.0

    -- Weight scaling ratio
    local weight_ratio = raw_weight / base_weight
    if base_weight == 1 and raw_weight > 50 then
        -- Scaled weight formula
        weight_ratio = 1 + (raw_weight * 0.05)
    end

    local calc = math_floor(base_price * weight_ratio * var_mult * shiny_mult)
    if calc <= 0 then calc = base_price end

    return calc, "Calculated Formula (BasePrice * WeightRatio)"
end

-- ============================================================================
-- INVENTORY EVALUATION
-- ============================================================================

local function scan_and_evaluate_all(target_coin)
    target_coin = tonumber(target_coin) or 8000000
    if target_coin < 0 then target_coin = 0 end

    local report = {
        meta = {
            target_coin = target_coin,
            player_name = local_player.Name,
            timestamp = os.time()
        },
        discovered_modules = discovered_sell_modules,
        fishes = {},
        total_items_in_bag = 0,
        total_fish_count = 0,
        total_inventory_worth = 0,
        worth_by_method = {},
        worth_by_tier = {},
        count_by_tier = {},
        sample_item_dumps = {},
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
    report.total_items_in_bag = #items

    for idx, item in ipairs(items) do
        if item.Id then
            local is_fav = (item.Favorited == true or (item.Metadata and item.Metadata.Favorited == true))
            local item_data = nil
            if item_utility and type(item_utility.GetItemData) == "function" then
                pcall(function() item_data = item_utility:GetItemData(item.Id) end)
            end

            local d = (item_data and item_data.Data) or {}
            local item_type = d.Type or "Unknown"

            if item_type == "Fish" or item_type == "FishItems" or string_find(string_lower(d.Name or ""), "fish") or d.Tier then
                local price, method = resolve_exact_sell_price(item, item_data)
                local tier = d.Tier or 1

                local fish_entry = {
                    idx = idx,
                    id = item.Id,
                    uuid = item.UUID or "N/A",
                    name = d.Name or ("Fish_ID_" .. tostring(item.Id)),
                    tier = tier,
                    value = price,
                    method = method,
                    weight = item.Metadata and item.Metadata.Weight,
                    variant = item.Metadata and (item.Metadata.VariantId or item.Metadata.Mutation),
                    shiny = item.Metadata and item.Metadata.Shiny or item.Shiny,
                    favorited = is_fav,
                    raw = item,
                    raw_data = d
                }

                table_insert(report.fishes, fish_entry)
                report.total_fish_count = report.total_fish_count + 1
                report.total_inventory_worth = report.total_inventory_worth + price

                local tier_key = "Tier " .. tostring(tier)
                report.worth_by_tier[tier_key] = (report.worth_by_tier[tier_key] or 0) + price
                report.count_by_tier[tier_key] = (report.count_by_tier[tier_key] or 0) + 1
                report.worth_by_method[method] = (report.worth_by_method[method] or 0) + 1

                if #report.sample_item_dumps < 5 then
                    table_insert(report.sample_item_dumps, {
                        name = fish_entry.name,
                        price = price,
                        method = method,
                        item_data_data = d,
                        raw_inventory_item = item
                    })
                end
            end
        end
    end

    -- ========================================================================
    -- SMART BOTTOM-UP SELECTION (Smallest Fish First for Minimum Excess)
    -- ========================================================================
    local candidate_pool = {}
    for _, f in ipairs(report.fishes) do
        if not f.favorited then
            table_insert(candidate_pool, f)
        end
    end

    -- Sort candidates ascending (cheapest fish first to minimize overshoot)
    table_sort(candidate_pool, function(a, b)
        return (a.value or 0) < (b.value or 0)
    end)

    local accumulated_value = 0
    local selected_list = {}

    while #candidate_pool > 0 and accumulated_value < target_coin do
        local item = table_remove(candidate_pool, 1)
        table_insert(selected_list, item)
        accumulated_value = accumulated_value + (item.value or 0)
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

local function format_merchant_tab(report)
    local ok, res = pcall(function()
        local lines = {}
        table_insert(lines, "=== MERCHANT SELL SYSTEM & MODULE AUDIT ===")
        table_insert(lines, string_format("Total Items in Inventory: %s items", format_number(report.total_items_in_bag)))
        table_insert(lines, string_format("Total Fish Counted:       %s fish", format_number(report.total_fish_count)))
        table_insert(lines, string_format("Total Calculated Worth:   %s Coins", format_number(report.total_inventory_worth)))
        table_insert(lines, "")

        table_insert(lines, "--- [1] DISCOVERED GAME MODULES WITH SELL/PRICE FUNCTIONS ---")
        if #report.discovered_modules == 0 then
            table_insert(lines, " (No dedicated sell modules found in scan)")
        else
            for idx, mod in ipairs(report.discovered_modules) do
                table_insert(lines, string_format(" %02d. %s [%s]", idx, mod.name, mod.fullname))
                local key_names = {}
                for _, k in ipairs(mod.keys) do
                    table_insert(key_names, k.name .. " (" .. k.type .. ")")
                end
                table_insert(lines, "     Exported: " .. table_concat(key_names, ", "))
            end
        end
        table_insert(lines, "")

        table_insert(lines, "--- [2] RESOLUTION METHODS USED ACROSS INVENTORY ---")
        for m_name, count in pairs(report.worth_by_method) do
            table_insert(lines, string_format(" • %-35s -> %d fish resolved", m_name, count))
        end
        table_insert(lines, "")

        table_insert(lines, "--- [3] SAMPLE FISH RAW DATA (Inspection) ---")
        for idx, s in ipairs(report.sample_item_dumps) do
            table_insert(lines, string_format(" [%02d] %s -> %s Coins (via %s)", idx, s.name, format_number(s.price), s.method))
            table_insert(lines, "      item_data.Data = " .. safe_serialize(s.item_data_data, 2))
            table_insert(lines, "      raw_inventory  = " .. safe_serialize(s.raw_inventory_item, 2))
            table_insert(lines, "")
        end

        return table_concat(lines, "\n")
    end)
    return ok and res or ("Error: " .. tostring(res))
end

local function format_inventory_tab(report)
    local ok, res = pcall(function()
        local lines = {}
        table_insert(lines, "=== INVENTORY FISH VALUATION (Comparison) ===")
        table_insert(lines, string_format("Total Fish:  %s fish", format_number(report.total_fish_count)))
        table_insert(lines, string_format("Total Value: %s Coins", format_number(report.total_inventory_worth)))
        table_insert(lines, "")

        table_insert(lines, "--- BREAKDOWN BY TIER ---")
        for t_name, worth in pairs(report.worth_by_tier) do
            local count = report.count_by_tier[t_name] or 0
            table_insert(lines, string_format(" • %-10s: %-5d fish | Subtotal: %14s Coins", t_name, count, format_number(worth)))
        end
        table_insert(lines, "")

        table_insert(lines, "--- ALL FISH IN INVENTORY (Smallest to Largest Price) ---")
        local sorted_fish = {}
        for _, f in ipairs(report.fishes) do table_insert(sorted_fish, f) end
        table_sort(sorted_fish, function(a, b) return (a.value or 0) < (b.value or 0) end)

        if #sorted_fish == 0 then
            table_insert(lines, " (No fish in inventory)")
        else
            for idx, f in ipairs(sorted_fish) do
                local fav_tag = f.favorited and "[FAV] " or ""
                local w_str = f.weight and string_format("W: %.1fkg", tonumber(f.weight) or 1) or ""
                local v_str = f.variant and (" | " .. tostring(f.variant)) or ""
                local s_str = f.shiny and " | SHINY" or ""
                table_insert(lines, string_format(" %04d. %s%-18s | Tier %s | %-10s%s%s -> %9s Coins",
                    idx, fav_tag, tostring(f.name), tostring(f.tier), w_str, v_str, s_str, format_number(f.value)))
            end
        end

        return table_concat(lines, "\n")
    end)
    return ok and res or ("Error: " .. tostring(res))
end

local function format_simulation_tab(report)
    local ok, res = pcall(function()
        local sim = report.simulation
        local lines = {}
        table_insert(lines, "=== 'TRADE BY COIN' BOTTOM-UP SMART SIMULATION ===")
        table_insert(lines, string_format("Target Amount Requested: %s Coins", format_number(sim.target_coin)))
        table_insert(lines, string_format("Total Bag Fish Value:    %s Coins", format_number(report.total_inventory_worth)))
        table_insert(lines, string_format("Status:                  %s", sim.achievable and "✅ TARGET REACHABLE!" or "❌ INSUFFICIENT COIN VALUE"))
        table_insert(lines, "")

        table_insert(lines, "--- SIMULATION RESULT (Smallest Fish First) ---")
        table_insert(lines, string_format(" • Total Value Selected: %s Coins", format_number(sim.total_selected_value)))
        table_insert(lines, string_format(" • Total Fish Used:      %d fish", tonumber(sim.total_selected_count) or 0))
        table_insert(lines, string_format(" • Total Trades Needed:  %d trade session(s)", tonumber(sim.trades_needed) or 0))
        local pct_excess = (sim.target_coin and sim.target_coin > 0) and ((sim.excess_amount or 0) / sim.target_coin * 100) or 0
        table_insert(lines, string_format(" • Excess Amount (Over): +%s Coins (%.3f%% excess)", format_number(sim.excess_amount), pct_excess))
        table_insert(lines, "")

        table_insert(lines, "--- TRADE BATCHES (Max 20 Items per Trade Window) ---")
        if not sim.batches or #sim.batches == 0 then
            table_insert(lines, " (No batches generated)")
        else
            for _, b in ipairs(sim.batches) do
                table_insert(lines, string_format(" ▶ [TRADE #%d] %d Fish | Subtotal: %s Coins", tonumber(b.batch_number) or 1, tonumber(b.items_count) or 0, format_number(b.total_value)))
                for item_idx, item in ipairs(b.items) do
                    local w_str = item.weight and string_format("W: %.1fkg", tonumber(item.weight) or 1) or ""
                    local v_str = item.variant and (" (" .. tostring(item.variant) .. ")") or ""
                    table_insert(lines, string_format("     #%02d: %-18s | %-10s%s -> %8s Coins", item_idx, tostring(item.name), w_str, v_str, format_number(item.value)))
                end
                table_insert(lines, "")
            end
        end

        return table_concat(lines, "\n")
    end)
    return ok and res or ("Error: " .. tostring(res))
end

local function format_raw_json(report)
    local ok, json = pcall(function() return http_service:JSONEncode(report) end)
    return ok and json or safe_serialize(report, 4)
end

-- ============================================================================
-- GUI SETUP
-- ============================================================================

local current_target = 8000000
local report_data = scan_and_evaluate_all(current_target)

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

local main = Instance_new("Frame")
main.Name = "CoinDebugWindow"
main.Size = UDim2_new(0, 560, 0, 420)
main.Position = UDim2_new(0.5, -280, 0.5, -210)
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
title_lbl.Text = "Keenan Hub - Exact Merchant Sell Price & Coin Valuation"
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
input_lbl.Size = UDim2_new(0, 130, 1, 0)
input_lbl.BackgroundTransparency = 1
input_lbl.Text = "Target Coin Amount:"
input_lbl.TextColor3 = TEXT_COLOR
input_lbl.TextSize = 10
input_lbl.FontFace = font_bold
input_lbl.TextXAlignment = Enum.TextXAlignment.Left
input_lbl.Parent = input_bar

local coin_input_box = Instance_new("TextBox")
coin_input_box.Size = UDim2_new(0, 180, 1, 0)
coin_input_box.Position = UDim2_new(0, 135, 0, 0)
coin_input_box.BackgroundColor3 = INPUT_BG_COLOR
coin_input_box.Text = format_number(current_target)
coin_input_box.PlaceholderText = "e.g. 8,000,000 or 8m"
coin_input_box.TextColor3 = ACCENT_COLOR
coin_input_box.TextSize = 10
coin_input_box.FontFace = font_bold
coin_input_box.ClearTextOnFocus = false
coin_input_box.Parent = input_bar

local cib_corner = Instance_new("UICorner")
cib_corner.CornerRadius = UDim_new(0, 4)
cib_corner.Parent = coin_input_box

local cib_stroke = Instance_new("UIStroke")
cib_stroke.Color = BORDER_COLOR
cib_stroke.Thickness = 1
cib_stroke.Parent = coin_input_box

local sim_btn = Instance_new("TextButton")
sim_btn.Size = UDim2_new(0, 110, 1, 0)
sim_btn.Position = UDim2_new(0, 325, 0, 0)
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
tab_bar.Size = UDim2_new(1, -20, 0, 26)
tab_bar.Position = UDim2_new(0, 10, 0, 70)
tab_bar.BackgroundTransparency = 1
tab_bar.Parent = main

local tab_layout = Instance_new("UIListLayout")
tab_layout.FillDirection = Enum.FillDirection.Horizontal
tab_layout.Padding = UDim_new(0, 6)
tab_layout.Parent = tab_bar

-- Content Viewer
local viewer_frame = Instance_new("Frame")
viewer_frame.Size = UDim2_new(1, -20, 1, -140)
viewer_frame.Position = UDim2_new(0, 10, 0, 100)
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
local current_tab_id = "simulation"
local tabs = {
    { id = "simulation", name = "Coin Simulation", formatter = format_simulation_tab },
    { id = "merchant",   name = "Merchant Audit",  formatter = format_merchant_tab },
    { id = "inventory",  name = "Bag Valuation",   formatter = format_inventory_tab },
    { id = "raw_json",   name = "Raw JSON",        formatter = format_raw_json },
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
    display_box.Text = ok and text or ("Error generating tab content: " .. tostring(text))
    viewer_scroll.CanvasPosition = Vector2.new(0, 0)
end

for _, tab_info in ipairs(tabs) do
    local btn = Instance_new("TextButton")
    btn.Size = UDim2_new(0, 120, 1, 0)
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
    current_target = parse_formatted_number(coin_input_box.Text)
    report_data = scan_and_evaluate_all(current_target)
    for _, t in ipairs(tabs) do
        if t.id == current_tab_id then
            switch_tab(t)
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
        pcall(function() writefile("FishIt_MerchantSell_Debug.json", json_str) end)
    end
    local set_clip = setclipboard or toclipboard or (Clipboard and Clipboard.set)
    if set_clip then set_clip(json_str) end
end)
