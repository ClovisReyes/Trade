-- Keenan Hub - Exact Sell Multiplier & Weight Factor Deep Scanner
-- Inspects Replion Data, Player Attributes, Weight ratios, and exact Sell All formula.

local ipairs        = ipairs
local pairs         = pairs
local tostring      = tostring
local tonumber      = tonumber
local type          = type
local typeof        = typeof
local pcall         = pcall

local table_insert  = table.insert
local table_concat  = table.concat
local string_lower  = string.lower
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
local replicated_storage    = cloneref(game:GetService("ReplicatedStorage"))
local http_service          = cloneref(game:GetService("HttpService"))
local core_gui              = pcall(function() return cloneref(game:GetService("CoreGui")) end) and cloneref(game:GetService("CoreGui")) or nil
local player_gui            = cloneref(local_player:WaitForChild("PlayerGui"))

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
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
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
                if i > 6 then table_insert(parts, "..."); break end
                table_insert(parts, safe_serialize(v, max_depth, current_depth + 1))
            end
            return "[" .. table_concat(parts, ", ") .. "]"
        else
            local count = 0
            for k, v in pairs(obj) do
                count = count + 1
                if count > 6 then table_insert(parts, "\"...\" : \"...\""); break end
                table_insert(parts, string_format("%q: %s", tostring(k), safe_serialize(v, max_depth, current_depth + 1)))
            end
            return "{" .. table_concat(parts, ", ") .. "}"
        end
    else
        return string_format("\"[%s]\"", tostring(obj))
    end
end

local shared_folder = replicated_storage:FindFirstChild("Shared")
local packages_folder = replicated_storage:FindFirstChild("Packages")
local item_utility = shared_folder and shared_folder:FindFirstChild("ItemUtility") and pcall(require, shared_folder.ItemUtility) and require(shared_folder.ItemUtility) or nil
local replion_mod = packages_folder and packages_folder:FindFirstChild("Replion") and pcall(require, packages_folder.Replion) and require(packages_folder.Replion) or nil
local player_data = replion_mod and replion_mod.Client and pcall(function() return replion_mod.Client:WaitReplion("Data") end) and replion_mod.Client:WaitReplion("Data") or nil

local function run_factor_analysis()
    local report = {
        player_attributes = {},
        all_replions = {},
        player_data_boosts = {},
        equipped_pets = {},
        weight_comparison_samples = {},
        total_unlocked_items = 0,
        sum_raw_sellprice = 0,
        sum_with_variants = 0,
        sum_with_weight_ratio = 0,
        sum_with_both = 0,
    }

    -- 1. Scan Player Attributes
    pcall(function()
        for k, v in pairs(local_player:GetAttributes()) do
            report.player_attributes[k] = safe_serialize(v, 1)
        end
    end)

    -- 2. Scan Replion Data for Boosts / Pets / Multipliers / Gamepasses
    if player_data then
        pcall(function()
            local raw = player_data:Get()
            if type(raw) == "table" then
                for k, v in pairs(raw) do
                    if k ~= "Inventory" then
                        report.player_data_boosts[k] = safe_serialize(v, 2)
                    end
                end
            end
        end)
    end

    -- 3. Variant Multipliers
    local variant_multipliers = {}
    pcall(function()
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
    end)
    if not variant_multipliers["shiny"] then variant_multipliers["shiny"] = 1.5 end

    -- 4. Calculate across all 4,044 unfavorited fish using candidate formulas
    if player_data then
        local inv_ok, inv = pcall(function() return player_data:Get("Inventory") end)
        local items = (inv_ok and inv and inv.Items) or {}

        local sample_count = 0
        for _, itm in ipairs(items) do
            if itm.Id then
                local is_fav = (itm.Favorited == true or (itm.Metadata and itm.Metadata.Favorited == true))
                if not is_fav then
                    local item_info = item_utility and item_utility.GetItemData and pcall(function() return item_utility:GetItemData(itm.Id) end) and item_utility:GetItemData(itm.Id)
                    if item_info and item_info.Data and item_info.Data.Type == "Fish" then
                        report.total_unlocked_items = report.total_unlocked_items + 1
                        local base_price = tonumber(item_info.SellPrice) or 0
                        local default_weight = (item_info.Weight and tonumber(item_info.Weight.Default)) or 1
                        local actual_weight = (itm.Metadata and tonumber(itm.Metadata.Weight)) or default_weight

                        local v_mult = 1
                        local meta = itm.Metadata
                        if meta then
                            if meta.VariantId and meta.VariantId ~= "" and meta.VariantId ~= "None" then
                                local vname = tostring(meta.VariantId)
                                local found_m = variant_multipliers[string_lower(vname)] or variant_multipliers[vname]
                                if found_m then v_mult = v_mult * found_m end
                            end
                            if meta.Shiny == true or meta.Shiny == 1 or (type(meta.Shiny) == "string" and string_lower(meta.Shiny) == "true") then
                                if not meta.VariantId or string_lower(tostring(meta.VariantId)) ~= "shiny" then
                                    v_mult = v_mult * (variant_multipliers["shiny"] or 1.5)
                                end
                            end
                        end

                        local weight_ratio = 1
                        if default_weight > 0 and actual_weight > 0 then
                            weight_ratio = actual_weight / default_weight
                        end

                        report.sum_raw_sellprice = report.sum_raw_sellprice + base_price
                        report.sum_with_variants = report.sum_with_variants + math_floor(base_price * v_mult)
                        report.sum_with_weight_ratio = report.sum_with_weight_ratio + math_floor(base_price * weight_ratio)
                        report.sum_with_both = report.sum_with_both + math_floor(base_price * v_mult * weight_ratio)

                        if sample_count < 5 then
                            sample_count = sample_count + 1
                            table_insert(report.weight_comparison_samples, {
                                name = item_info.Data.Name,
                                tier = item_info.Data.Tier,
                                base_price = base_price,
                                default_weight = default_weight,
                                actual_weight = actual_weight,
                                weight_ratio = string_format("%.2fx", weight_ratio),
                                variant_mult = string_format("%.2fx", v_mult),
                                price_variants_only = math_floor(base_price * v_mult),
                                price_with_weight = math_floor(base_price * v_mult * weight_ratio)
                            })
                        end
                    end
                end
            end
        end
    end

    return report
end

-- ============================================================================
-- GUI DISPLAY
-- ============================================================================

local gui = Instance_new("ScreenGui")
gui.Name = "KeenanHub_CoinHunter"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local function protect_gui(g)
    if gethui then g.Parent = gethui()
    elseif core_gui then g.Parent = core_gui
    else g.Parent = player_gui end
end
protect_gui(gui)

_G.KeenanHub_CoinDebug_Cleanup = function() pcall(function() gui:Destroy() end) end

local main = Instance_new("Frame")
main.Name = "HunterWindow"
main.Size = UDim2_new(0, 500, 0, 340)
main.Position = UDim2_new(0.5, -250, 0.5, -170)
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
title_lbl.Size = UDim2_new(1, -120, 1, 0)
title_lbl.Position = UDim2_new(0, 10, 0, 0)
title_lbl.BackgroundTransparency = 1
title_lbl.Text = "Keenan Hub - Exact Multiplier & Boost Analysis"
title_lbl.TextColor3 = ACCENT_COLOR
title_lbl.TextSize = 11
title_lbl.FontFace = font_bold
title_lbl.TextXAlignment = Enum.TextXAlignment.Left
title_lbl.Parent = header

local header_btns = Instance_new("Frame")
header_btns.Size = UDim2_new(0, 110, 1, -6)
header_btns.Position = UDim2_new(1, -115, 0, 3)
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

make_btn(header_btns, "X", ERROR_COLOR, 24, function() _G.KeenanHub_CoinDebug_Cleanup() end)

-- Content Box
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
display_box.Text = "⏳ Menganalisis perbedaan harga (Analyzing formulas)..."
display_box.Parent = viewer_scroll

display_box:GetPropertyChangedSignal("TextBounds"):Connect(function()
    viewer_scroll.CanvasSize = UDim2_new(0, 0, 0, display_box.TextBounds.Y + 20)
    display_box.Size = UDim2_new(1, -10, 0, display_box.TextBounds.Y + 10)
end)

local function format_analysis_output(rep)
    local lines = {}
    table_insert(lines, "=== KEENAN HUB - MERCHANT PRICE FORMULA COMPARISON ===")
    table_insert(lines, "🎯 IN-GAME MERCHANT DIALOG VALUE: 898.34M Coins (898,340,000 Coins) for 4,044 items")
    table_insert(lines, "")

    table_insert(lines, "--- [1] CANDIDATE FORMULA TOTALS (Across 4,044 Unlocked Fish) ---")
    table_insert(lines, string_format(" A. Base Price Only:            %s Coins (Ratio: %.2fx)", format_number(rep.sum_raw_sellprice), 898340000 / math.max(1, rep.sum_raw_sellprice)))
    table_insert(lines, string_format(" B. Base Price * Variants:       %s Coins (Ratio: %.2fx)", format_number(rep.sum_with_variants), 898340000 / math.max(1, rep.sum_with_variants)))
    table_insert(lines, string_format(" C. Base Price * Weight Ratio:   %s Coins (Ratio: %.2fx)", format_number(rep.sum_with_weight_ratio), 898340000 / math.max(1, rep.sum_with_weight_ratio)))
    table_insert(lines, string_format(" D. Base * Variants * Weight:    %s Coins (Ratio: %.2fx)", format_number(rep.sum_with_both), 898340000 / math.max(1, rep.sum_with_both)))
    table_insert(lines, "")

    table_insert(lines, "--- [2] PLAYER BOOSTS / PETS / REPLION KEYS ---")
    for k, v in pairs(rep.player_data_boosts) do
        table_insert(lines, string_format(" • %-16s: %s", k, v))
    end
    table_insert(lines, "")

    table_insert(lines, "--- [3] PLAYER ATTRIBUTES ---")
    if next(rep.player_attributes) == nil then
        table_insert(lines, " (No custom player attributes)")
    else
        for k, v in pairs(rep.player_attributes) do
            table_insert(lines, string_format(" • %-16s = %s", k, v))
        end
    end
    table_insert(lines, "")

    table_insert(lines, "--- [4] SAMPLE FISH WITH WEIGHT RATIOS ---")
    for idx, s in ipairs(rep.weight_comparison_samples) do
        table_insert(lines, string_format(" [%02d] %s (Tier %s)", idx, s.name, tostring(s.tier)))
        table_insert(lines, string_format("      BasePrice: %s | DefaultWeight: %s | ActualWeight: %s", format_number(s.base_price), tostring(s.default_weight), tostring(s.actual_weight)))
        table_insert(lines, string_format("      WeightRatio: %s | VariantMult: %s -> VarOnly: %s | WithWeight: %s", s.weight_ratio, s.variant_mult, format_number(s.price_variants_only), format_number(s.price_with_weight)))
        table_insert(lines, "")
    end

    return table_concat(lines, "\n")
end

local function run_and_display()
    display_box.Text = "⏳ Menganalisis formula harga..."
    task.spawn(function()
        task.wait(0.05)
        local rep = run_factor_analysis()
        display_box.Text = format_analysis_output(rep)
        viewer_scroll.CanvasPosition = Vector2.new(0, 0)
    end)
end

make_btn(header_btns, "📋 Copy", TEXT_COLOR, 50, function()
    local set_clip = setclipboard or toclipboard or (Clipboard and Clipboard.set)
    if set_clip then set_clip(display_box.Text) end
end)

make_btn(header_btns, "🔄", ACCENT_COLOR, 24, run_and_display)

task.spawn(function()
    task.wait(0.15)
    run_and_display()
end)
