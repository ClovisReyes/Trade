-- Keenan Hub - Fish It Trade Debugger & Data Inspector
-- Inspects exact game item types, tier representations, inventory lock/favorited fields, and trade remotes without fallback assumptions.

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

local task_wait     = task.wait
local task_spawn    = task.spawn
local task_delay    = task.delay
local task_cancel   = task.cancel
local task_defer    = task.defer

local Color3_fromRGB = Color3.fromRGB
local UDim2_new      = UDim2.new
local UDim_new       = UDim.new
local Instance_new   = Instance.new
local TweenInfo_new  = TweenInfo.new

if _G.KeenanHub_Debug_Cleanup then
    pcall(_G.KeenanHub_Debug_Cleanup)
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

-- UI Colors
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

-- Deep inspect / serialize helper
local function safe_serialize(obj, max_depth, current_depth)
    current_depth = current_depth or 1
    max_depth = max_depth or 4
    if current_depth > max_depth then return "\"... (depth limit)\"" end

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
                local k_str = tostring(k)
                table_insert(parts, string_format("%q: %s", k_str, safe_serialize(v, max_depth, current_depth + 1)))
            end
            return "{" .. table_concat(parts, ", ") .. "}"
        end
    elseif typeof and typeof(obj) == "Instance" then
        return string_format("\"[Instance: %s (%s)]\"", obj.Name, obj.ClassName)
    else
        return string_format("\"[%s: %s]\"", t, tostring(obj))
    end
end

-- ============================================================================
-- DATA INSPECTION ENGINE
-- ============================================================================

local function run_inspection()
    local report = {
        meta = {
            timestamp = os.time(),
            game_id = game.GameId,
            place_id = game.PlaceId,
            player_name = local_player.Name,
            user_id = local_player.UserId
        },
        game_modules = {
            all_types = {},
            all_tiers = {},
            tier_definitions = {},
            enchant_stones = {},
            other_items = {},
            fish_items = {},
            raw_sample_by_type = {}
        },
        inventory = {
            total_items = 0,
            counts_by_type = {},
            property_keys_found = {},
            metadata_keys_found = {},
            locked_favorited_items = {},
            enchant_stones_in_inv = {},
            fishes_in_inv = {},
            other_items_in_inv = {},
            sample_items = {}
        },
        trade_remotes = {},
        diagnostics = {}
    }

    -- 1. Scan Game Modules in ReplicatedStorage.Items
    if variables.items then
        for _, item in ipairs(variables.items:GetDescendants()) do
            if item:IsA("ModuleScript") then
                local success, item_data = pcall(require, item)
                if success and type(item_data) == "table" and item_data.Data then
                    local d = item_data.Data
                    local item_name = d.Name or item.Name
                    local item_type = d.Type or "UNKNOWN_TYPE"
                    local item_tier = d.Tier

                    -- Track types
                    report.game_modules.all_types[item_type] = (report.game_modules.all_types[item_type] or 0) + 1

                    -- Track tiers
                    local tier_key = tostring(item_tier) .. " (" .. type(item_tier) .. ")"
                    report.game_modules.all_tiers[tier_key] = (report.game_modules.all_tiers[tier_key] or 0) + 1

                    -- Store samples by type
                    if not report.game_modules.raw_sample_by_type[item_type] then
                        report.game_modules.raw_sample_by_type[item_type] = d
                    end

                    -- Categorize
                    if item_type == "Enchant Stones" or string_find(string_lower(item_type), "enchant") or string_find(string_lower(item_name), "enchant") then
                        table_insert(report.game_modules.enchant_stones, {
                            name = item_name,
                            type = item_type,
                            tier = item_tier,
                            path = item:GetFullName(),
                            data = d
                        })
                    elseif item_type == "Fish" then
                        table_insert(report.game_modules.fish_items, {
                            name = item_name,
                            tier = item_tier,
                            path = item:GetFullName()
                        })
                    else
                        table_insert(report.game_modules.other_items, {
                            name = item_name,
                            type = item_type,
                            tier = item_tier
                        })
                    end
                end
            end
        end
    else
        table_insert(report.diagnostics, "ReplicatedStorage.Items NOT FOUND")
    end

    -- 2. Search for any Tier / Rarity Constants / Modules in ReplicatedStorage
    for _, desc in ipairs(replicated_storage:GetDescendants()) do
        if desc:IsA("ModuleScript") then
            local n_lower = string_lower(desc.Name)
            if string_find(n_lower, "tier") or string_find(n_lower, "rarit") then
                local success, mod_data = pcall(require, desc)
                if success and type(mod_data) == "table" then
                    report.game_modules.tier_definitions[desc:GetFullName()] = mod_data
                end
            end
        end
    end

    -- 3. Scan Player Inventory via Replion
    if player_data then
        local inv_ok, inventory = pcall(function() return player_data:Get("Inventory") end)
        if inv_ok and inventory and inventory.Items then
            local items = inventory.Items
            report.inventory.total_items = #items

            for idx, item in ipairs(items) do
                -- Track all root keys on item object
                for k, _ in pairs(item) do
                    report.inventory.property_keys_found[k] = (report.inventory.property_keys_found[k] or 0) + 1
                end

                -- Track metadata keys
                if item.Metadata and type(item.Metadata) == "table" then
                    for mk, _ in pairs(item.Metadata) do
                        report.inventory.metadata_keys_found[mk] = (report.inventory.metadata_keys_found[mk] or 0) + 1
                    end
                end

                -- Resolve item data via item_utility or fallback
                local item_data = nil
                if item_utility and item.Id then
                    pcall(function() item_data = item_utility:GetItemData(item.Id) end)
                end

                local d = item_data and item_data.Data or {}
                local item_type = d.Type or "Unresolved"
                local item_name = d.Name or ("ID_" .. tostring(item.Id))
                local item_tier = d.Tier

                report.inventory.counts_by_type[item_type] = (report.inventory.counts_by_type[item_type] or 0) + (item.Amount or 1)

                -- Check lock / favorite variations
                local is_favorited = (item.Favorited == true or item.Favorited == 1)
                local is_locked = (item.Locked == true or item.Locked == 1 or item.IsLocked == true or item.IsLocked == 1)
                local meta_fav = item.Metadata and (item.Metadata.Favorited == true or item.Metadata.Favorited == 1 or item.Metadata.Favorite == true)
                local meta_lock = item.Metadata and (item.Metadata.Locked == true or item.Metadata.Locked == 1 or item.Metadata.IsLocked == true)

                if is_favorited or is_locked or meta_fav or meta_lock then
                    table_insert(report.inventory.locked_favorited_items, {
                        index = idx,
                        name = item_name,
                        type = item_type,
                        id = item.Id,
                        uuid = item.UUID,
                        amount = item.Amount,
                        favorited_prop = item.Favorited,
                        locked_prop = item.Locked,
                        is_locked_prop = item.IsLocked,
                        meta_favorited = item.Metadata and item.Metadata.Favorited,
                        meta_locked = item.Metadata and item.Metadata.Locked,
                        raw_item = item
                    })
                end

                -- Record categorized inventory items
                if item_type == "Enchant Stones" or string_find(string_lower(item_type), "enchant") or string_find(string_lower(item_name), "enchant") then
                    table_insert(report.inventory.enchant_stones_in_inv, {
                        name = item_name,
                        type = item_type,
                        tier = item_tier,
                        id = item.Id,
                        uuid = item.UUID,
                        amount = item.Amount or 1,
                        raw = item
                    })
                elseif item_type == "Fish" then
                    if #report.inventory.fishes_in_inv < 15 then
                        table_insert(report.inventory.fishes_in_inv, {
                            name = item_name,
                            tier = item_tier,
                            id = item.Id,
                            uuid = item.UUID,
                            meta = item.Metadata,
                            raw = item
                        })
                    end
                else
                    table_insert(report.inventory.other_items_in_inv, {
                        name = item_name,
                        type = item_type,
                        id = item.Id,
                        amount = item.Amount or 1,
                        raw = item
                    })
                end

                if #report.inventory.sample_items < 10 then
                    table_insert(report.inventory.sample_items, {
                        name = item_name,
                        type = item_type,
                        resolved_data = d,
                        raw_inventory_entry = item
                    })
                end
            end
        else
            table_insert(report.diagnostics, "Player inventory is empty or unreadable via Replion")
        end
    else
        table_insert(report.diagnostics, "Replion Data object is nil")
    end

    -- 4. Check Trade Remotes in sleitnick_net
    local net_ok, net_folder = pcall(function()
        return replicated_storage.Packages._Index["sleitnick_net@0.2.0"].net
    end)
    if net_ok and net_folder then
        local children = net_folder:GetChildren()
        for i, v in ipairs(children) do
            for _, rname in ipairs({"SendTradeOffer", "AddItem", "SetReady", "ConfirmTrade", "TradeEnded", "DeclineTrade", "CancelTrade"}) do
                if string_find(v.Name, rname, 1, true) then
                    local target_remote = nil
                    for j = i + 1, #children do
                        local next_obj = children[j]
                        if string_match(next_obj.Name, "^RF/") or string_match(next_obj.Name, "^RE/") then
                            target_remote = next_obj
                            break
                        end
                    end
                    report.trade_remotes[rname] = {
                        found = true,
                        definition = v.Name,
                        remote_name = target_remote and target_remote.Name or "N/A",
                        class_name = target_remote and target_remote.ClassName or "N/A"
                    }
                end
            end
        end
    else
        table_insert(report.diagnostics, "sleitnick_net folder not located in ReplicatedStorage.Packages._Index")
    end

    return report
end

-- ============================================================================
-- FORMATTED REPORT BUILDERS
-- ============================================================================

local function format_overview_tab(report)
    local lines = {}
    table_insert(lines, "=== KEENAN HUB - TRADE DATA INSPECTOR OVERVIEW ===")
    table_insert(lines, string_format("Player: %s (ID: %d)", report.meta.player_name, report.meta.user_id))
    table_insert(lines, string_format("Inventory Items Count: %d", report.inventory.total_items))
    table_insert(lines, "")

    table_insert(lines, "--- [1] GAME ITEM TYPES DETECTED (ReplicatedStorage.Items) ---")
    for t_name, count in pairs(report.game_modules.all_types) do
        table_insert(lines, string_format(" • Type: %-20s -> %d game items", "\"" .. t_name .. "\"", count))
    end
    table_insert(lines, "")

    table_insert(lines, "--- [2] INVENTORY COUNTS BY TYPE ---")
    for t_name, count in pairs(report.inventory.counts_by_type) do
        table_insert(lines, string_format(" • Type: %-20s -> %d owned units", "\"" .. t_name .. "\"", count))
    end
    table_insert(lines, "")

    table_insert(lines, "--- [3] INVENTORY ROOT PROPERTY KEYS (Structure Check) ---")
    for k_name, count in pairs(report.inventory.property_keys_found) do
        table_insert(lines, string_format(" • Key: %-15s (present on %d/%d items)", k_name, count, report.inventory.total_items))
    end
    table_insert(lines, "")

    table_insert(lines, "--- [4] INVENTORY METADATA KEYS ---")
    for mk_name, count in pairs(report.inventory.metadata_keys_found) do
        table_insert(lines, string_format(" • Metadata Key: %-15s (present on %d items)", mk_name, count))
    end
    table_insert(lines, "")

    table_insert(lines, "--- [5] TRADE REMOTES DISCOVERY ---")
    for r_key, r_info in pairs(report.trade_remotes) do
        table_insert(lines, string_format(" • %-16s: %s [%s]", r_key, r_info.remote_name, r_info.class_name))
    end

    if #report.diagnostics > 0 then
        table_insert(lines, "")
        table_insert(lines, "--- [!] DIAGNOSTICS & WARNINGS ---")
        for _, d in ipairs(report.diagnostics) do
            table_insert(lines, " ⚠️ " .. d)
        end
    end

    return table_concat(lines, "\n")
end

local function format_enchants_tab(report)
    local lines = {}
    table_insert(lines, "=== ENCHANT STONES ACCURACY AUDIT ===")
    table_insert(lines, "Here are all Enchant Stone definitions found in game modules vs your inventory:")
    table_insert(lines, "")

    table_insert(lines, string_format("--- REGISTERED ENCHANT STONES IN GAME (%d items) ---", #report.game_modules.enchant_stones))
    for idx, enc in ipairs(report.game_modules.enchant_stones) do
        table_insert(lines, string_format(" %02d. Name: %-24s | Type: %-16s | Tier: %s", idx, enc.name, "\"" .. enc.type .. "\"", tostring(enc.tier)))
    end
    table_insert(lines, "")

    table_insert(lines, string_format("--- ENCHANT STONES CURRENTLY IN INVENTORY (%d items) ---", #report.inventory.enchant_stones_in_inv))
    if #report.inventory.enchant_stones_in_inv == 0 then
        table_insert(lines, " (Tidak ada Enchant Stone di dalam inventory saat ini)")
    else
        for idx, enc in ipairs(report.inventory.enchant_stones_in_inv) do
            table_insert(lines, string_format(" %02d. %-24s | Qty/Amount: %s | UUID: %s | Type: %s", idx, enc.name, tostring(enc.amount), tostring(enc.uuid), enc.type))
        end
    end
    table_insert(lines, "")

    table_insert(lines, "--- CRITICAL ACCURACY INSIGHT ---")
    table_insert(lines, "• Game assigns Enchant Stones to Type = 'Enchant Stones'.")
    table_insert(lines, "• Filtering for 'All' MUST check `item_data.Data.Type == 'Enchant Stones'` to prevent trading Fish/Bait/Rods!")

    return table_concat(lines, "\n")
end

local function format_tiers_tab(report)
    local lines = {}
    table_insert(lines, "=== TIERS & RARITY REPRESENTATION AUDIT ===")
    table_insert(lines, "Exact Tier values discovered in game ModuleScripts:")
    table_insert(lines, "")

    table_insert(lines, "--- ALL TIER VALUES IN GAME ---")
    for tier_val, count in pairs(report.game_modules.all_tiers) do
        table_insert(lines, string_format(" • Value: %-25s -> %d items in game", tier_val, count))
    end
    table_insert(lines, "")

    table_insert(lines, "--- DEDICATED TIER/RARITY MODULES FOUND IN REPLICATED STORAGE ---")
    local def_count = 0
    for path, mod_data in pairs(report.game_modules.tier_definitions) do
        def_count = def_count + 1
        table_insert(lines, string_format(" • Module: %s", path))
        for k, v in pairs(mod_data) do
            table_insert(lines, string_format("     [%s] = %s", tostring(k), safe_serialize(v, 2)))
        end
    end
    if def_count == 0 then
        table_insert(lines, " (No standalone Tier / Rarity mapping module found in ReplicatedStorage)")
    end
    table_insert(lines, "")

    table_insert(lines, "--- SAMPLE FISHES IN INVENTORY & THEIR TIERS ---")
    for idx, f in ipairs(report.inventory.fishes_in_inv) do
        local meta_str = f.meta and safe_serialize(f.meta, 2) or "none"
        table_insert(lines, string_format(" %02d. Fish: %-20s | Tier: %-12s | Meta: %s", idx, f.name, tostring(f.tier) .. " (" .. type(f.tier) .. ")", meta_str))
    end

    return table_concat(lines, "\n")
end

local function format_lock_fav_tab(report)
    local lines = {}
    table_insert(lines, "=== LOCKED & FAVORITED ITEMS AUDIT ===")
    table_insert(lines, "Inspecting exact keys used for locking and favoriting items in Fish It:")
    table_insert(lines, "")

    table_insert(lines, string_format("--- LOCKED / FAVORITED ITEMS DETECTED IN INVENTORY (%d items) ---", #report.inventory.locked_favorited_items))
    if #report.inventory.locked_favorited_items == 0 then
        table_insert(lines, " (Tidak ada item yang sedang dikunci/difavoritkan dalam inventory)")
        table_insert(lines, "")
        table_insert(lines, "Tips: Kunci atau favoritkan 1 item di inventory Anda lalu klik 'Refresh Data'")
        table_insert(lines, "untuk melihat nama properti persis yang digunakan game!")
    else
        for idx, item in ipairs(report.inventory.locked_favorited_items) do
            table_insert(lines, string_format(" [%02d] %s (Type: %s, ID: %s)", idx, item.name, item.type, tostring(item.id)))
            table_insert(lines, string_format("      item.Favorited     = %s", tostring(item.favorited_prop)))
            table_insert(lines, string_format("      item.Locked        = %s", tostring(item.locked_prop)))
            table_insert(lines, string_format("      item.IsLocked      = %s", tostring(item.is_locked_prop)))
            table_insert(lines, string_format("      item.Metadata.Fav  = %s", tostring(item.meta_favorited)))
            table_insert(lines, string_format("      item.Metadata.Lock = %s", tostring(item.meta_locked)))
            table_insert(lines, string_format("      Raw Item Dump      = %s", safe_serialize(item.raw_item, 3)))
            table_insert(lines, "")
        end
    end

    return table_concat(lines, "\n")
end

local function format_raw_json_tab(report)
    local ok, json = pcall(function()
        return http_service:JSONEncode(report)
    end)
    if ok then
        return json
    else
        return safe_serialize(report, 5)
    end
end

-- ============================================================================
-- GUI INTERACTION & DISPLAY
-- ============================================================================

local report_data = run_inspection()

local gui = Instance_new("ScreenGui")
gui.Name = "KeenanHub_TradeDebugger"
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

_G.KeenanHub_Debug_Cleanup = function()
    pcall(function() gui:Destroy() end)
end

-- Main Window
local main = Instance_new("Frame")
main.Name = "DebugWindow"
main.Size = UDim2_new(0, 520, 0, 360)
main.Position = UDim2_new(0.5, -260, 0.5, -180)
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
title_lbl.Text = "Keenan Hub - Fish It Trade Debugger"
title_lbl.TextColor3 = ACCENT_COLOR
title_lbl.TextSize = 11
title_lbl.FontFace = font_bold
title_lbl.TextXAlignment = Enum.TextXAlignment.Left
title_lbl.Parent = header

-- Window Controls (Minimize, Close)
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
close_btn.MouseButton1Click:Connect(function()
    _G.KeenanHub_Debug_Cleanup()
end)

-- Dragging logic
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

-- Content Viewer (Scroll + TextBox for native select/copy)
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
    viewer_scroll.CanvasSize = UDim2_new(0, 0, 0, display_box.TextBounds.Y + 20)
    display_box.Size = UDim2_new(1, -10, 0, display_box.TextBounds.Y + 10)
end)

-- Bottom Action Buttons Bar
local action_bar = Instance_new("Frame")
action_bar.Size = UDim2_new(1, -20, 0, 28)
action_bar.Position = UDim2_new(0, 10, 1, -34)
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

-- Tab Management
local active_tab_btn = nil
local current_tab_id = "overview"

local tabs = {
    { id = "overview", name = "Overview", formatter = format_overview_tab },
    { id = "enchants", name = "Enchants Audit", formatter = format_enchants_tab },
    { id = "tiers",    name = "Tiers / Rarity", formatter = format_tiers_tab },
    { id = "lock_fav", name = "Lock & Favorite", formatter = format_lock_fav_tab },
    { id = "raw_json", name = "Raw JSON", formatter = format_raw_json_tab },
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

    local content = tab_info.formatter(report_data)
    display_box.Text = content
    viewer_scroll.CanvasPosition = Vector2.new(0, 0)
end

for idx, tab_info in ipairs(tabs) do
    local btn = Instance_new("TextButton")
    btn.Size = UDim2_new(0, 94, 1, 0)
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

-- Action Buttons Callbacks
create_action_btn("🔄 Refresh Data", function()
    report_data = run_inspection()
    for _, t in ipairs(tabs) do
        if t.id == current_tab_id then
            display_box.Text = t.formatter(report_data)
            break
        end
    end
end)

create_action_btn("📋 Copy Tab Text", function()
    local text = display_box.Text
    local set_clip = setclipboard or toclipboard or (Clipboard and Clipboard.set)
    if set_clip then
        set_clip(text)
    end
end)

create_action_btn("💾 Export JSON", function()
    local json_str = format_raw_json_tab(report_data)
    if writefile then
        pcall(function()
            writefile("FishIt_Trade_Debug_Report.json", json_str)
        end)
    end
    local set_clip = setclipboard or toclipboard or (Clipboard and Clipboard.set)
    if set_clip then
        set_clip(json_str)
    end
end)
