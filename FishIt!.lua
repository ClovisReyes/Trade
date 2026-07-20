-- Localized Globals for optimization (Roberto Ierusalimschy's Lua Performance Tip #1)
local ipairs        = ipairs
local pairs         = pairs
local tostring      = tostring
local tonumber      = tonumber
local pcall         = pcall
local tick          = tick
local os_clock      = os.clock

local table_find    = table.find
local table_insert  = table.insert
local table_remove  = table.remove
local table_sort    = table.sort
local table_concat  = table.concat

local string_lower  = string.lower
local string_find   = string.find
local string_gsub   = string.gsub
local string_format = string.format
local string_match  = string.match

local task_wait     = task.wait
local task_spawn    = task.spawn

-- 0. Clean up previous script execution instances (preventing double UI and thread leaks)
if _G.NoirHub_AutoTrade_Cleanup then
    pcall(_G.NoirHub_AutoTrade_Cleanup)
end

local script_id = os_clock()
_G.NoirHub_AutoTrade_ScriptID = script_id

local cloneref = cloneref or function(ref) return ref end

--#region Services
local players               = cloneref(game:GetService("Players"))
local local_player          = players.LocalPlayer
if not local_player then
    pcall(function()
        players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    end)
    local_player = players.LocalPlayer
end
local player_gui            = cloneref(local_player and local_player:WaitForChild("PlayerGui", 10))
local user_input_service    = cloneref(game:GetService("UserInputService"))
local run_service           = cloneref(game:GetService("RunService"))
local tween_service         = cloneref(game:GetService("TweenService"))
local replicated_storage    = cloneref(game:GetService("ReplicatedStorage"))
local http_service          = cloneref(game:GetService("HttpService"))
--#endregion

--#region Variables
local variables = {
    items                   = replicated_storage:FindFirstChild("Items"),
    variants                = replicated_storage:FindFirstChild("Variants"),
    replion                 = replicated_storage:FindFirstChild("Packages") and replicated_storage.Packages:FindFirstChild("Replion"),
    item_utility            = replicated_storage:FindFirstChild("Shared") and replicated_storage.Shared:FindFirstChild("ItemUtility"),
    vendor_utility          = replicated_storage:FindFirstChild("Shared") and replicated_storage.Shared:FindFirstChild("VendorUtility"),
    player_stats_utility    = replicated_storage:FindFirstChild("Shared") and replicated_storage.Shared:FindFirstChild("PlayerStatsUtility")
}

local success_replion, replion_mod = pcall(require, variables.replion)
local player_data = nil
if success_replion and replion_mod and replion_mod.Client then
    pcall(function()
        player_data = replion_mod.Client:GetReplion("Data")
    end)
    if not player_data then
        task_spawn(function()
            pcall(function()
                player_data = replion_mod.Client:WaitReplion("Data")
            end)
        end)
    end
end

local success_item, item_utility = pcall(require, variables.item_utility)
item_utility = success_item and item_utility or nil
local success_vendor, vendor_utility = pcall(require, variables.vendor_utility)
vendor_utility = success_vendor and vendor_utility or nil

-- Net Lookup for Sleitnick Net Remotes
local remote_map = {
    SendTradeOffer     = "SendTradeOffer",
    AddItem            = "AddItem",
    SetReady           = "SetReady",
    ConfirmTrade       = "ConfirmTrade",
    TradeOfferReceived = "TradeOfferReceived",
    TradeEnded         = "TradeEnded",
    TradeStarted       = "TradeStarted",
    AcceptTradeOffer   = "AcceptTradeOffer",
}

local _net_lookup = nil
local function get_net_lookup()
    if _net_lookup then return _net_lookup end
    _net_lookup = {}

    local net_folder = nil
    pcall(function()
        local packages = replicated_storage:FindFirstChild("Packages")
        local index = packages and packages:FindFirstChild("_Index")
        if index then
            for _, child in ipairs(index:GetChildren()) do
                if string_find(child.Name, "sleitnick_net") and child:FindFirstChild("net") then
                    net_folder = child.net
                    break
                end
            end
        end
    end)

    if not net_folder then return _net_lookup end
    local children = net_folder:GetChildren()

    for i, v in ipairs(children) do
        for _, logical_name in pairs(remote_map) do
            if string_find(v.Name, logical_name, 1, true) then
                for j = i + 1, #children do
                    local next_obj = children[j]
                    if string_match(next_obj.Name, "^RF/") or string_match(next_obj.Name, "^RE/") then
                        _net_lookup[logical_name] = next_obj
                        break
                    end
                end
                break
            end
        end
    end

    return _net_lookup
end

local remote_cache = {}
local remotes = setmetatable({}, {
    __index = function(_, key)
        if remote_cache[key] then return remote_cache[key] end
        local logical_name = remote_map[key]
        if not logical_name then return nil end
        local remote = get_net_lookup()[logical_name]
        if remote then
            -- Wrap the remote to handle both FireServer and InvokeServer
            local wrapped = setmetatable({
                instance = remote,
                FireServer = function(_, ...)
                    if remote:IsA("RemoteEvent") then
                        remote:FireServer(...)
                    elseif remote:IsA("RemoteFunction") then
                        remote:InvokeServer(...)
                    end
                end,
                InvokeServer = function(_, ...)
                    if remote:IsA("RemoteFunction") then
                        return remote:InvokeServer(...)
                    elseif remote:IsA("RemoteEvent") then
                        remote:FireServer(...)
                    end
                end,
                IsA = function(_, className)
                    return remote:IsA(className)
                end
            }, {
                __index = function(_, k)
                    return remote[k]
                end
            })
            remote_cache[key] = wrapped
            return wrapped
        end
        return nil
    end
})

local trade_remotes = remotes
--#endregion

--#region Configuration & Cache
local config = {
    enabled             = false,
    trade_favorited     = false,
    quantity            = 0, -- 0 = unlimited
    target_coin_amount  = 0,
    trade_with          = "",

    -- Toggles
    trade_fish_enabled  = false,
    trade_enchants_enabled = false,
    trade_coins_enabled = false,
    trade_rarity_enabled = false,
    auto_accept_enabled = false,

    -- Selection Filters
    selected_fish       = {},
    selected_tiers      = { "All" },
    selected_mutations  = { "All" },
    selected_items      = {}, -- Enchants
}

local cache = {
    processed_trades    = {},
    current_item        = nil,
    fish_list           = {},
    loaded_fish         = {},
    loaded_mutations    = {},
    loaded_enchants     = {},
    start_time          = tick(),
    total_caught_start  = 0,
    caught_history      = {},
    active_trade        = false,
    receiving_trade     = false,
    receiving_trade_time = 0,
    fish_status_text    = "Idle",
    fish_status_details = "",
    enchant_status_text = "Idle",
    enchant_status_details = "",
    coin_status_text    = "Idle",
    coin_status_details = "",
    rarity_status_text  = "Idle",
    rarity_status_details = "",
    count_labels        = {},
    last_trade_time     = nil,
    stats = {
        fish = { success_trades = 0, attempts = 0, failed = 0, last_items = 0, total_items = 0 },
        rarity = { success_trades = 0, attempts = 0, failed = 0, last_items = 0, total_items = 0 },
        enchant = { success_trades = 0, attempts = 0, failed = 0, last_items = 0, total_items = 0 },
        coin = { success_trades = 0, attempts = 0, failed = 0, last_items = 0, total_items = 0 }
    },
}

_G.AutoTradeConfig = config
_G.AutoTradeCache = cache

local function save_config()
    pcall(function()
        if writefile and http_service then
            local temp_config = {}
            for k, v in pairs(config) do
                temp_config[k] = v
            end
            temp_config.enabled = false
            temp_config.trade_fish_enabled = false
            temp_config.trade_enchants_enabled = false
            temp_config.trade_coins_enabled = false
            temp_config.trade_rarity_enabled = false
            
            local data = http_service:JSONEncode(temp_config)
            writefile("NoirHub_AutoTrade_Config.json", data)
        end
    end)
end

local function load_config()
    pcall(function()
        if isfile and readfile and http_service then
            local filename = "NoirHub_AutoTrade_Config.json"
            if isfile(filename) then
                local data = readfile(filename)
                local loaded = http_service:JSONDecode(data)
                if loaded and type(loaded) == "table" then
                    for k, v in pairs(loaded) do
                        if config[k] ~= nil then
                            config[k] = v
                        end
                    end
                end
            end
        end
    end)
end

load_config()

-- Enforce mutual exclusion of trade modes on script load
local active_modes = 0
if config.trade_fish_enabled then active_modes = active_modes + 1 end
if config.trade_enchants_enabled then active_modes = active_modes + 1 end
if config.trade_rarity_enabled then active_modes = active_modes + 1 end
if config.trade_coins_enabled then active_modes = active_modes + 1 end

if active_modes > 1 then
    local found = false
    if config.trade_fish_enabled then
        found = true
    end
    if config.trade_enchants_enabled then
        if found then config.trade_enchants_enabled = false else found = true end
    end
    if config.trade_rarity_enabled then
        if found then config.trade_rarity_enabled = false else found = true end
    end
    if config.trade_coins_enabled then
        if found then config.trade_coins_enabled = false end
    end
    save_config()
end

-- CUSTOMABLE SIZE CONFIGURATION (Change these values to scale/adjust the UI)
local UI_CONFIG = {
    HUD_WIDTH = 225,
    HUD_HEIGHT = 270,
    MINI_HUD_HEIGHT = 165,
    SETTINGS_WIDTH = 250,
    SETTINGS_HEIGHT = 380,
}

local function get_item_count(item_name)
    local count = 0
    pcall(function()
        if player_data then
            local inventory = player_data:Get("Inventory")
            local items = inventory and inventory.Items or {}
            for _, item in ipairs(items) do
                if item.Id then
                    local data = item_utility:GetItemData(item.Id)
                    if data and data.Data and (data.Data.Name == item_name or (item_name == "Ruby" and data.Data.Name == "Ruby Gemstone") or (item_name == "Ruby Gemstone" and data.Data.Name == "Ruby")) then
                        count = count + (item.Amount or 1)
                    end
                end
            end
        end
    end)
    return count
end

local function get_runic_count()
    return get_item_count("Runic Enchant Stone")
end

local function get_inventory_enchants(bypass_favorited)
    local enchants = {}
    local success, err = pcall(function()
        if player_data then
            local inventory = player_data:Get("Inventory")
            local items = inventory and inventory.Items or {}
            -- print("get_inventory_enchants: read " .. tostring(#items) .. " total items from player_data.")
            for _, item in ipairs(items) do
                if item.Id then
                    local include_item = true
                    if not bypass_favorited and item.Favorited and not config.trade_favorited then
                        include_item = false
                    end

                    if include_item then
                        local data = item_utility:GetItemData(item.Id)
                        if data and data.Data then
                            local name = data.Data.Name
                            local is_enchant = string_find(name, "Enchant", 1, true) or data.Data.Type == "Enchants" or data.Data.Type == "Enchant"
                            if is_enchant then
                                enchants[name] = (enchants[name] or 0) + (item.Amount or 1)
                            end
                        end
                    end
                end
            end
        else
            -- print("get_inventory_enchants: player_data is nil!")
        end
    end)
    if not success then
        warn("get_inventory_enchants error: " .. tostring(err))
    end
    return enchants
end

local function strip_quantity(str)
    return string_gsub(str, "%s*%(x%d+%)", "")
end

-- Load all fish/mutation/enchant definitions
local function load_game_data()
    -- Load Tiers
    cache.loaded_tiers = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "SECRET", "Forgotten" }

    -- Load Mutations
    for _, variant in ipairs(variables.variants:GetChildren()) do
        if variant:IsA("ModuleScript") then
            local success, data = pcall(require, variant)
            if success and type(data) == "table" and data.Data and data.Data.Name then
                table_insert(cache.loaded_mutations, data.Data.Name)
            end
        end
    end
    if not table_find(cache.loaded_mutations, "Shiny") then
        table_insert(cache.loaded_mutations, "Shiny")
    end
    table_sort(cache.loaded_mutations)

    -- Load Fish & Enchants
    for _, item in ipairs(variables.items:GetDescendants()) do
        if item:IsA("ModuleScript") then
            local success, item_data = pcall(require, item)
            if success and type(item_data) == "table" and item_data.Data then
                if item_data.Data.Type == "Fish" then
                    cache.loaded_fish[item_data.Data.Name] = item_data.Data
                elseif item_data.Data.Type == "Enchant Stones" then
                    cache.loaded_enchants[item_data.Data.Name] = item_data.Data
                end
            end
        end
    end
end
pcall(load_game_data)

--#endregion

--#region Auto Trade Engine
local function find_target_player()
    if config.trade_with == "" then return nil end
    for _, player in ipairs(players:GetPlayers()) do
        if player.Name == config.trade_with or player.DisplayName == config.trade_with then
            return player
        end
    end
    return nil
end

local tier_mapping = {
    [1] = "common",
    [2] = "uncommon",
    [3] = "rare",
    [4] = "epic",
    [5] = "legendary",
    [6] = "mythic",
    [7] = "secret",
    [8] = "forgotten"
}

local function should_trade_fish(item_data, inventory_item)
    if not config.enabled then return false end
    
    local name_match = false
    local mutation_match = false

    -- 1. Check Fish Name
    local fish_name = string_lower(item_data.Data.Name)
    local has_all_fish = table_find(config.selected_fish, "All") ~= nil
    if has_all_fish then
        name_match = true
    elseif #config.selected_fish > 0 then
        for _, selected_name in ipairs(config.selected_fish) do
            if fish_name == string_lower(selected_name) then
                name_match = true
                break
            end
        end
    else
        name_match = false
    end

    -- 3. Check Mutation
    local has_all_mutation = table_find(config.selected_mutations, "All") ~= nil
    if #config.selected_mutations == 0 or has_all_mutation then
        mutation_match = true
    else
        local mutation_name = inventory_item.Mutation and string_lower(inventory_item.Mutation)
        if mutation_name then
            for _, selected_mutation in ipairs(config.selected_mutations) do
                if mutation_name == string_lower(selected_mutation) then
                    mutation_match = true
                    break
                end
            end
        end
    end

    local should_trade = name_match and mutation_match

    if inventory_item.Favorited and not config.trade_favorited then
        should_trade = false
    end

    return should_trade;
end

local function should_trade_fish_by_rarity(item_data, inventory_item)
    if not config.enabled then return false end
    
    local rarity_match = false
    local mutation_match = false

    -- 2. Check Rarity (Tier)
    local has_all_rarity = table_find(config.selected_tiers, "All") ~= nil
    if #config.selected_tiers == 0 or has_all_rarity then
        rarity_match = true
    else
        local raw_tier = item_data.Data.Tier
        local tier_name = ""
        if type(raw_tier) == "number" then
            tier_name = tier_mapping[raw_tier] or ""
        elseif type(raw_tier) == "string" then
            tier_name = string_lower(raw_tier)
        end

        for _, selected_tier in ipairs(config.selected_tiers) do
            if tier_name == string_lower(selected_tier) then
                rarity_match = true
                break
            end
        end
    end

    -- 3. Check Mutation
    local has_all_mutation = table_find(config.selected_mutations, "All") ~= nil
    if #config.selected_mutations == 0 or has_all_mutation then
        mutation_match = true
    else
        local mutation_name = inventory_item.Mutation and string_lower(inventory_item.Mutation)
        if mutation_name then
            for _, selected_mutation in ipairs(config.selected_mutations) do
                if mutation_name == string_lower(selected_mutation) then
                    mutation_match = true
                    break
                end
            end
        end
    end

    local should_trade = rarity_match and mutation_match

    if inventory_item.Favorited and not config.trade_favorited then
        should_trade = false
    end

    return should_trade;
end

local function log_inventory_fish()
    local log_lines = {}
    table_insert(log_lines, "=== CURRENT INVENTORY FISH LOG ===")
    
    local fish_count = 0
    local match_count = 0
    
    local success, err = pcall(function()
        if player_data then
            local inventory = player_data:Get("Inventory")
            local items = inventory and inventory.Items or {}
            
            if #items == 0 then
                table_insert(log_lines, "No items found in inventory.")
                return
            end

            for _, item in ipairs(items) do
                if item.Id then
                    local data = item_utility:GetItemData(item.Id)
                    if data and data.Data and data.Data.Type == "Fish" then
                        fish_count = fish_count + 1
                        local fish_name = data.Data.Name
                        local tier = data.Data.Tier or "Unknown"
                        local mutation = item.Mutation or "None"
                        local is_favorited = item.Favorited and " [Favorited]" or ""
                        local matches = should_trade_fish(data, item)
                        local matches_filter = matches and " [MATCHES FILTER]" or ""
                        if matches then
                            match_count = match_count + 1
                        end
                        table_insert(log_lines, string_format("[%d] %s | Tier: %s | Mutation: %s%s%s | UUID: %s", 
                            fish_count, fish_name, tier, mutation, is_favorited, matches_filter, item.UUID))
                    end
                end
            end
            
            if fish_count == 0 then
                table_insert(log_lines, "No fish items found in inventory.")
            else
                table_insert(log_lines, string_format("Total fish found: %d | Matches Filter: %d", fish_count, match_count))
            end
        else
            table_insert(log_lines, "Player data (replion) is not loaded.")
        end
    end)
    
    if not success then
        table_insert(log_lines, "Error logging inventory: " .. tostring(err))
    end
    table_insert(log_lines, "==================================")
    
    local log_text = table_concat(log_lines, "\n")
    print(log_text)
    
    -- Write to executor workspace file
    pcall(function()
        if writefile then
            writefile("trade_inventory_log.txt", log_text)
            print("Successfully wrote trade_inventory_log.txt to executor workspace.")
        end
    end)
end

local function click_gui_button(btn)
    if not btn then return end

    -- 1. Direct button click signals (firesignal/getconnections)
    pcall(function()
        if firesignal then
            firesignal(btn.MouseButton1Click)
            firesignal(btn.MouseButton1Down)
            firesignal(btn.MouseButton1Up)
            firesignal(btn.Activated)
        end
    end)

    pcall(function()
        if getconnections then
            for _, event_name in ipairs({"MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "Activated"}) do
                local event = btn[event_name]
                if event then
                    for _, conn in ipairs(getconnections(event)) do
                        conn:Fire()
                    end
                end
            end
        end
    end)

    -- 2. Coordinate-based Lua signals (Safe, undetected by BAC since it fires purely in Lua)
    pcall(function()
        local abs_pos = btn.AbsolutePosition
        local abs_size = btn.AbsoluteSize
        local x = abs_pos.X + abs_size.X / 2
        local y = abs_pos.Y + abs_size.Y / 2

        local mock_input_begin = {
            UserInputType = Enum.UserInputType.MouseButton1,
            UserInputState = Enum.UserInputState.Begin,
            Position = Vector3.new(x, y, 0)
        }
        local mock_input_end = {
            UserInputType = Enum.UserInputType.MouseButton1,
            UserInputState = Enum.UserInputState.End,
            Position = Vector3.new(x, y, 0)
        }

        local uis = game:GetService("UserInputService")
        if firesignal then
            firesignal(uis.InputBegan, mock_input_begin, false)
            firesignal(uis.InputEnded, mock_input_end, false)
        end
        if getconnections then
            for _, conn in ipairs(getconnections(uis.InputBegan)) do
                conn:Fire(mock_input_begin, false)
            end
            for _, conn in ipairs(getconnections(uis.InputEnded)) do
                conn:Fire(mock_input_end, false)
            end
        end
    end)
end

local function decline_active_trade()
    pcall(function()
        local trading_gui = local_player.PlayerGui:FindFirstChild("! Trading")
        if trading_gui then
            local frame = trading_gui:FindFirstChild("Frame")
            if frame then
                local interior = frame:FindFirstChild("Interior")
                local decline = interior and interior:FindFirstChild("Decline")
                if decline then
                    click_gui_button(decline)
                else
                    local close = frame:FindFirstChild("Close")
                    if close then
                        click_gui_button(close)
                    end
                end
            end
        end
    end)
end

local function find_success_notification()
    local found = false
    pcall(function()
        local PlayerGui = local_player:FindFirstChild("PlayerGui")
        if not PlayerGui then return end
        
        -- 1. Targeted Fast Path Check (Lag-Free & Specific)
        local text_notifications = PlayerGui:FindFirstChild("Text Notifications")
        local frame = text_notifications and text_notifications:FindFirstChild("Frame")
        if frame then
            for _, tile in ipairs(frame:GetChildren()) do
                local header = tile:FindFirstChild("Header")
                if header then
                    local text = ""
                    local has_text = pcall(function() text = header.Text end)
                    if has_text and text then
                        local lower = string.lower(text)
                        if lower:find("completed") and (lower:find("trade") or lower:find("with")) then
                            found = true
                            return
                        end
                    end
                end
            end
        end
        
        -- 2. Fallback Scan of Descendants (Case-Insensitive & Class-Agnostic)
        for _, desc in ipairs(PlayerGui:GetDescendants()) do
            local text = ""
            local has_text = pcall(function() text = desc.Text end)
            if has_text and text then
                local lower = string.lower(text)
                if lower:find("completed") and (lower:find("trade") or lower:find("with")) then
                    found = true
                    break
                end
            end
        end
    end)
    return found
end

local function listen_for_trade_completion()
    local completed = false
    local connections = {}

    -- Modern TextChatService
    pcall(function()
        local TextChatService = game:GetService("TextChatService")
        local conn = TextChatService.MessageReceived:Connect(function(msg)
            local text = msg.Text or ""
            if text:find("completed!") and (text:find("Trade with") or text:find("Trade completed")) then
                completed = true
            end
        end)
        table_insert(connections, conn)
    end)

    -- Legacy Chat Events
    pcall(function()
        local chat_events = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
        local on_message = chat_events and chat_events:FindFirstChild("OnMessageDoneFiltering")
        if on_message then
            local conn = on_message.OnClientEvent:Connect(function(msg_data)
                local text = msg_data and msg_data.Message or ""
                if text:find("completed!") and (text:find("Trade with") or text:find("Trade completed")) then
                    completed = true
                end
            end)
            table_insert(connections, conn)
        end
    end)

    return {
        is_completed = function()
            if completed then return true end
            return find_success_notification()
        end,
        disconnect = function()
            for _, conn in ipairs(connections) do
                pcall(function() conn:Disconnect() end)
            end
        end
    }
end

local function get_mode_display_name(mode_name)
    if mode_name == "enchant" then
        if #config.selected_items > 0 and config.selected_items[1] ~= "All" then
            return config.selected_items[1]
        end
        return "Enchant Stone"
    elseif mode_name == "fish" then
        if #config.selected_fish > 0 and config.selected_fish[1] ~= "All" then
            return config.selected_fish[1]
        end
        return "Fish"
    elseif mode_name == "rarity" then
        if #config.selected_tiers > 0 and config.selected_tiers[1] ~= "All" then
            local names = {}
            for _, tier in ipairs(config.selected_tiers) do
                local t_name = tier_mapping[tier]
                if t_name then table_insert(names, t_name:sub(1,1):upper() .. t_name:sub(2)) end
            end
            if #names > 0 then return table_concat(names, "/") end
        end
        return "Rarity"
    elseif mode_name == "coin" then
        return "Coin"
    end
    return "Items"
end

local function set_status_msg(mode_name, msg, details_override)
    local s = cache.stats[mode_name]
    if not s then return end
    
    local target = config.quantity
    if mode_name == "coin" then target = config.target_coin_amount end
    local progress_str = (target == 0) and (s.total_items .. "/∞") or (s.total_items .. "/" .. target)
    
    local details = details_override or string.format("Items Sent: %d | Progress: %s | Attempts: %d | Failed: %d", s.total_items, progress_str, s.attempts, s.failed)
    
    if mode_name == "fish" then
        if msg then cache.fish_status_text = msg end
        cache.fish_status_details = details
    elseif mode_name == "rarity" then
        if msg then cache.rarity_status_text = msg end
        cache.rarity_status_details = details
    elseif mode_name == "enchant" then
        if msg then cache.enchant_status_text = msg end
        cache.enchant_status_details = details
    elseif mode_name == "coin" then
        if msg then cache.coin_status_text = msg end
        cache.coin_status_details = details
    end
end

local function wait_for_trade_end(mode_name)
    while local_player:GetAttribute("IsTrading") do
        local stage = "Waiting PlayersReady..."
        
        pcall(function()
            local t_gui = local_player.PlayerGui:FindFirstChild("! Trading")
            if t_gui then
                local seconds = nil
                for _, desc in ipairs(t_gui:GetDescendants()) do
                    if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                        local text = desc.Text or ""
                        local sec = string_match(text, "%((%d)s?%)") or string_match(text, "^(%d)$") or string_match(text, "Countdown: (%d)") or string_match(text, "Confirm%s*%(?(%d)%)?") or string_match(text, "Ready%s*%(?(%d)%)?")
                        if sec then
                            seconds = sec
                            break
                        end
                    end
                end
                
                if seconds then
                    stage = "Waiting lock countdown (5s)..."
                else
                    local has_confirm = false
                    local frame = t_gui:FindFirstChild("Frame")
                    local interior = frame and frame:FindFirstChild("Interior")
                    local buttons = interior and interior:FindFirstChild("Buttons")
                    if buttons then
                        local confirm_btn = buttons:FindFirstChild("Confirm")
                        if confirm_btn and confirm_btn.Visible then
                            has_confirm = true
                        end
                    end
                    
                    if not has_confirm then
                        for _, desc in ipairs(t_gui:GetDescendants()) do
                            if desc:IsA("TextButton") and (desc.Name == "Confirm" or desc.Text == "Confirm") then
                                has_confirm = true
                                break
                            end
                        end
                    end
                    
                    if has_confirm then
                        stage = "Confirming trade (spamming)..."
                    end
                end
            end
        end)
        
        set_status_msg(mode_name, stage)
        task_wait(0.1)
    end
end

local function start_trade_session(target_player, mode)
    if not target_player or not trade_remotes then return false, "No remotes" end

    if not local_player:GetAttribute("IsTrading") then
        if cache.last_trade_time then
            local elapsed = tick() - cache.last_trade_time
            if elapsed < 5 then
                set_status_msg(mode, nil, "Cooldown (" .. string.format("%.1fs", 5 - elapsed) .. ")")
                task_wait(5 - elapsed)
            end
        end

        set_status_msg(mode, "Waiting for target to accept offer...")
        local success, err = trade_remotes.SendTradeOffer:InvokeServer(target_player)
        if not success then
            cache.last_trade_time = tick()
            set_status_msg(mode, "Failed: " .. (err or "Declined"))
            return false, err
        end

        local start_time = tick()
        while not local_player:GetAttribute("IsTrading") and tick() - start_time < 10 do
            task_wait(0.1)
        end

        if not local_player:GetAttribute("IsTrading") then
            cache.last_trade_time = tick()
            set_status_msg(mode, "Trade request timed out")
            return false, "Timeout"
        end
    end

    return true
end

local function update_mode_status(mode_name)
    local s = cache.stats[mode_name]
    if not s then return end
    
    local target = config.quantity
    if mode_name == "coin" then
        target = config.target_coin_amount
    end
    
    local progress_str = (target == 0) and (s.total_items .. "/∞") or (s.total_items .. "/" .. target)
    
    local text
    if target > 0 and s.total_items >= target then
        text = string.format("Completed! %d/%d sukses | %d items sent", s.total_items, target, s.total_items)
    else
        local display_name = get_mode_display_name(mode_name)
        text = string.format("Success: %s - %d items sent (%s)", display_name, s.total_items, progress_str)
    end
    
    local details = string.format("Items Sent: %d | Progress: %s | Attempts: %d | Failed: %d", s.total_items, progress_str, s.attempts, s.failed)
    
    if mode_name == "fish" then
        cache.fish_status_text = text
        cache.fish_status_details = details
    elseif mode_name == "rarity" then
        cache.rarity_status_text = text
        cache.rarity_status_details = details
    elseif mode_name == "enchant" then
        cache.enchant_status_text = text
        cache.enchant_status_details = details
    elseif mode_name == "coin" then
        cache.coin_status_text = text
        cache.coin_status_details = details
    end
end

local function try_trade_fish()
    cache.processed_trades = {}
    local target_player = find_target_player()
    if not target_player or not player_data then
        local err_msg = "Error: Target player belum dipilih"
        if config.trade_with ~= "" and player_data then
            err_msg = "Error: Target player tidak ditemukan"
        end
        set_status_msg("fish", err_msg)
        return
    end

    local total_sent = cache.stats.fish.total_items
    if config.quantity > 0 and total_sent >= config.quantity then
        config.enabled = false
        if byname_toggle_ctrl then
            byname_toggle_ctrl.set_state(false)
            config.trade_fish_enabled = false
        end
        save_config()
        return
    end

    local inventory = player_data:Get("Inventory")
    local player_data_items = inventory and inventory.Items or {}
    
    local items_to_trade = {}
    local limit = config.quantity > 0 and (config.quantity - total_sent) or 999999
    for _, fish_item in ipairs(player_data_items) do
        if #items_to_trade >= limit then
            break
        end

        if fish_item and fish_item.Id then
            local fish_data = item_utility:GetItemData(fish_item.Id)
            if fish_data and fish_data.Data.Type == "Fish" then
                if should_trade_fish(fish_data, fish_item) then
                    if not table_find(cache.processed_trades, fish_item.UUID) then
                        table_insert(items_to_trade, fish_item)
                    end
                end
            end
        end
    end

    if #items_to_trade == 0 then
        local item_name = "fish"
        if #config.selected_fish > 0 then
            item_name = config.selected_fish[1]
        end
        set_status_msg("fish", "Error: Tidak ada lagi " .. item_name .. " di inventory")
        config.enabled = false
        if byname_toggle_ctrl then
            byname_toggle_ctrl.set_state(false)
            config.trade_fish_enabled = false
        end
        save_config()
        return
    end

    cache.stats.fish.attempts = cache.stats.fish.attempts + 1
    update_mode_status("fish")

    local success, err = start_trade_session(target_player, "fish")
    if not success then
        cache.stats.fish.failed = cache.stats.fish.failed + 1
        update_mode_status("fish")
        return
    end

    local added_items = {}
    set_status_msg("fish", "Offer accepted! Adding " .. #items_to_trade .. " item(s)...")
    for _, item in ipairs(items_to_trade) do
        if not config.enabled or not local_player:GetAttribute("IsTrading") then break end
        
        local fish_data = item_utility:GetItemData(item.Id)
        local add_success, add_err = trade_remotes.AddItem:InvokeServer("Fish", item.UUID)
        if add_success then
            table_insert(cache.processed_trades, item.UUID)
            table_insert(added_items, item)
        end
    end

    if #added_items > 0 and local_player:GetAttribute("IsTrading") then
        local chat_listener = listen_for_trade_completion()

        pcall(function()
            trade_remotes.SetReady:InvokeServer(true)
        end)
        
        wait_for_trade_end("fish")
        task_wait(0.5)

        local trade_success = false
        local check_start = tick()
        while tick() - check_start < 3.5 do
            if chat_listener.is_completed() then
                trade_success = true
                break
            end

            local still_has_items = false
            pcall(function()
                local inv = player_data:Get("Inventory")
                local current_items = inv and inv.Items or {}
                for _, trade_item in ipairs(added_items) do
                    local found = false
                    for _, inv_item in ipairs(current_items) do
                        if inv_item.UUID == trade_item.UUID then
                            found = true
                            break
                        end
                    end
                    if found then
                        still_has_items = true
                        break
                    end
                end
            end)
            if not still_has_items then
                trade_success = true
                break
            end

            task_wait(0.2)
        end
        chat_listener.disconnect()

        if trade_success then
            cache.stats.fish.success_trades = cache.stats.fish.success_trades + 1
            cache.stats.fish.last_items = #added_items
            cache.stats.fish.total_items = cache.stats.fish.total_items + #added_items
            
            if config.quantity > 0 and cache.stats.fish.total_items >= config.quantity then
                config.enabled = false
                if byname_toggle_ctrl then
                    byname_toggle_ctrl.set_state(false)
                    config.trade_fish_enabled = false
                end
                save_config()
            end
        else
            cache.stats.fish.failed = cache.stats.fish.failed + 1
        end
        update_mode_status("fish")
    else
        cache.stats.fish.failed = cache.stats.fish.failed + 1
        update_mode_status("fish")
    end
end

local function try_trade_rarity()
    cache.processed_trades = {}
    local target_player = find_target_player()
    if not target_player or not player_data then
        local err_msg = "Error: Target player belum dipilih"
        if config.trade_with ~= "" and player_data then
            err_msg = "Error: Target player tidak ditemukan"
        end
        set_status_msg("rarity", err_msg)
        return
    end

    local total_sent = cache.stats.rarity.total_items
    if config.quantity > 0 and total_sent >= config.quantity then
        config.enabled = false
        if rarity_toggle_ctrl then
            rarity_toggle_ctrl.set_state(false)
            config.trade_rarity_enabled = false
        end
        save_config()
        return
    end

    local inventory = player_data:Get("Inventory")
    local player_data_items = inventory and inventory.Items or {}
    
    local items_to_trade = {}
    local limit = config.quantity > 0 and (config.quantity - total_sent) or 999999
    for _, fish_item in ipairs(player_data_items) do
        if #items_to_trade >= limit then
            break
        end

        if fish_item and fish_item.Id then
            local fish_data = item_utility:GetItemData(fish_item.Id)
            if fish_data and fish_data.Data.Type == "Fish" then
                if should_trade_fish_by_rarity(fish_data, fish_item) then
                    if not table_find(cache.processed_trades, fish_item.UUID) then
                        table_insert(items_to_trade, fish_item)
                    end
                end
            end
        end
    end

    if #items_to_trade == 0 then
        local rarity_name = "matching rarity"
        if #config.selected_tiers > 0 then
            local names = {}
            for _, tier in ipairs(config.selected_tiers) do
                local t_name = tier_mapping[tier]
                if t_name then table_insert(names, t_name:sub(1,1):upper() .. t_name:sub(2)) end
            end
            if #names > 0 then rarity_name = table_concat(names, "/") end
        end
        set_status_msg("rarity", "Error: Tidak ada lagi " .. rarity_name .. " di inventory")
        config.enabled = false
        if rarity_toggle_ctrl then
            rarity_toggle_ctrl.set_state(false)
            config.trade_rarity_enabled = false
        end
        save_config()
        return
    end

    cache.stats.rarity.attempts = cache.stats.rarity.attempts + 1
    update_mode_status("rarity")

    local success, err = start_trade_session(target_player, "rarity")
    if not success then
        cache.stats.rarity.failed = cache.stats.rarity.failed + 1
        update_mode_status("rarity")
        return
    end

    local added_items = {}
    set_status_msg("rarity", "Offer accepted! Adding " .. #items_to_trade .. " item(s)...")
    for _, item in ipairs(items_to_trade) do
        if not config.enabled or not local_player:GetAttribute("IsTrading") then break end
        
        local fish_data = item_utility:GetItemData(item.Id)
        local add_success, add_err = trade_remotes.AddItem:InvokeServer("Fish", item.UUID)
        if add_success then
            table_insert(cache.processed_trades, item.UUID)
            table_insert(added_items, item)
        end
    end

    if #added_items > 0 and local_player:GetAttribute("IsTrading") then
        local chat_listener = listen_for_trade_completion()

        pcall(function()
            trade_remotes.SetReady:InvokeServer(true)
        end)
        
        wait_for_trade_end("rarity")
        task_wait(0.5)

        local trade_success = false
        local check_start = tick()
        while tick() - check_start < 3.5 do
            if chat_listener.is_completed() then
                trade_success = true
                break
            end

            local still_has_items = false
            pcall(function()
                local inv = player_data:Get("Inventory")
                local current_items = inv and inv.Items or {}
                for _, trade_item in ipairs(added_items) do
                    local found = false
                    for _, inv_item in ipairs(current_items) do
                        if inv_item.UUID == trade_item.UUID then
                            found = true
                            break
                        end
                    end
                    if found then
                        still_has_items = true
                        break
                    end
                end
            end)
            if not still_has_items then
                trade_success = true
                break
            end

            task_wait(0.2)
        end
        chat_listener.disconnect()

        if trade_success then
            cache.stats.rarity.success_trades = cache.stats.rarity.success_trades + 1
            cache.stats.rarity.last_items = #added_items
            cache.stats.rarity.total_items = cache.stats.rarity.total_items + #added_items
            
            if config.quantity > 0 and cache.stats.rarity.total_items >= config.quantity then
                config.enabled = false
                if rarity_toggle_ctrl then
                    rarity_toggle_ctrl.set_state(false)
                    config.trade_rarity_enabled = false
                end
                save_config()
            end
        else
            cache.stats.rarity.failed = cache.stats.rarity.failed + 1
        end
        update_mode_status("rarity")
    else
        cache.stats.rarity.failed = cache.stats.rarity.failed + 1
        update_mode_status("rarity")
    end
end

local function try_trade_enchant()
    cache.processed_trades = {}
    local target_player = find_target_player()
    if not target_player or not player_data then
        local err_msg = "Error: Target player belum dipilih"
        if config.trade_with ~= "" and player_data then
            err_msg = "Error: Target player tidak ditemukan"
        end
        set_status_msg("enchant", err_msg)
        return
    end

    local total_sent = cache.stats.enchant.total_items
    if config.quantity > 0 and total_sent >= config.quantity then
        config.enabled = false
        if enchant_toggle_ctrl then
            enchant_toggle_ctrl.set_state(false)
            config.trade_enchants_enabled = false
        end
        save_config()
        return
    end

    local inventory = player_data:Get("Inventory")
    local player_data_items = inventory and inventory.Items or {}
    
    local items_to_trade = {}
    local limit = config.quantity > 0 and (config.quantity - total_sent) or 999999
    for _, item in ipairs(player_data_items) do
        if #items_to_trade >= limit then
            break
        end

        if item and item.Id then
            local item_data = item_utility:GetItemData(item.Id)
            if item_data then
                local has_all_enchant = table_find(config.selected_items, "All") ~= nil
                if has_all_enchant or table_find(config.selected_items, item_data.Data.Name) then
                    if not table_find(cache.processed_trades, item.UUID) then
                        table_insert(items_to_trade, item)
                    end
                end
            end
        end
    end

    if #items_to_trade == 0 then
        local item_name = "Enchant Stone"
        if #config.selected_items > 0 then
            item_name = config.selected_items[1]
        end
        set_status_msg("enchant", "Error: Tidak ada lagi " .. item_name .. " di inventory")
        config.enabled = false
        if enchant_toggle_ctrl then
            enchant_toggle_ctrl.set_state(false)
            config.trade_enchants_enabled = false
        end
        save_config()
        return
    end

    cache.stats.enchant.attempts = cache.stats.enchant.attempts + 1
    update_mode_status("enchant")

    local success, err = start_trade_session(target_player, "enchant")
    if not success then
        cache.stats.enchant.failed = cache.stats.enchant.failed + 1
        update_mode_status("enchant")
        return
    end

    local added_items = {}
    set_status_msg("enchant", "Offer accepted! Adding " .. #items_to_trade .. " item(s)...")
    for _, item in ipairs(items_to_trade) do
        if not config.enabled or not local_player:GetAttribute("IsTrading") then break end
        
        local item_data = item_utility:GetItemData(item.Id)
        local add_success, add_err = trade_remotes.AddItem:InvokeServer(item_data.Data.Type or "Items", item.UUID)
        if add_success then
            table_insert(cache.processed_trades, item.UUID)
            table_insert(added_items, item)
        end
    end

    if #added_items > 0 and local_player:GetAttribute("IsTrading") then
        local chat_listener = listen_for_trade_completion()

        pcall(function()
            trade_remotes.SetReady:InvokeServer(true)
        end)
        
        wait_for_trade_end("enchant")
        task_wait(0.5)

        local trade_success = false
        local check_start = tick()
        while tick() - check_start < 3.5 do
            if chat_listener.is_completed() then
                trade_success = true
                break
            end

            local still_has_items = false
            pcall(function()
                local inv = player_data:Get("Inventory")
                local current_items = inv and inv.Items or {}
                for _, trade_item in ipairs(added_items) do
                    local found = false
                    for _, inv_item in ipairs(current_items) do
                        if inv_item.UUID == trade_item.UUID then
                            found = true
                            break
                        end
                    end
                    if found then
                        still_has_items = true
                        break
                    end
                end
            end)
            if not still_has_items then
                trade_success = true
                break
            end

            task_wait(0.2)
        end
        chat_listener.disconnect()

        if trade_success then
            cache.stats.enchant.success_trades = cache.stats.enchant.success_trades + 1
            cache.stats.enchant.last_items = #added_items
            cache.stats.enchant.total_items = cache.stats.enchant.total_items + #added_items
            
            if config.quantity > 0 and cache.stats.enchant.total_items >= config.quantity then
                config.enabled = false
                if enchant_toggle_ctrl then
                    enchant_toggle_ctrl.set_state(false)
                    config.trade_enchants_enabled = false
                end
                save_config()
            end
        else
            cache.stats.enchant.failed = cache.stats.enchant.failed + 1
        end
        update_mode_status("enchant")
    else
        cache.stats.enchant.failed = cache.stats.enchant.failed + 1
        update_mode_status("enchant")
    end
end

local function choose_fishes_by_range(fish_list, target_amount)
    table_sort(fish_list, function(a, b) return a.SellPrice > b.SellPrice end)
    local selected_fishes = {}
    local accumulated_amount = 0
    for _, fish in ipairs(fish_list) do
        if (accumulated_amount + fish.SellPrice) <= target_amount then
            accumulated_amount = accumulated_amount + fish.SellPrice
            table_insert(selected_fishes, fish)
        end
        if accumulated_amount >= target_amount then break end
    end
    return selected_fishes
end

local function try_trade_by_coin()
    cache.processed_trades = {}
    local target_player = find_target_player()
    if not target_player or not player_data then
        local err_msg = "Error: Target player belum dipilih"
        if config.trade_with ~= "" and player_data then
            err_msg = "Error: Target player tidak ditemukan"
        end
        set_status_msg("coin", err_msg)
        return
    end

    local inventory = player_data:Get("Inventory")
    local player_data_items = inventory and inventory.Items or {}
    local fish_list = {}
    for _, item in ipairs(player_data_items) do
        if item and item.Id then
            local data = item_utility.GetItemDataFromItemType("Fish", item.Id)
            if data then
                if not (item.Favorited and not config.trade_favorited) then
                    table_insert(fish_list, {
                        UUID = item.UUID,
                        Name = data.Data.Name,
                        SellPrice = vendor_utility:GetSellPrice(item) or 0
                    })
                end
            end
        end
    end

    if #fish_list == 0 then
        set_status_msg("coin", "Error: Tidak ada lagi fish di inventory")
        config.enabled = false
        if coin_toggle_ctrl then
            coin_toggle_ctrl.set_state(false)
            config.trade_coins_enabled = false
        end
        save_config()
        return
    end

    local selected = choose_fishes_by_range(fish_list, config.target_coin_amount)
    
    local items_to_trade = {}
    for _, fish in ipairs(selected) do
        if not table_find(cache.processed_trades, fish.UUID) then
            table_insert(items_to_trade, fish)
        end
    end

    if #items_to_trade == 0 or #selected == 0 then
        set_status_msg("coin", "Error: Tidak ada lagi fish di inventory")
        config.enabled = false
        if coin_toggle_ctrl then
            coin_toggle_ctrl.set_state(false)
            config.trade_coins_enabled = false
        end
        save_config()
        return
    end

    cache.stats.coin.attempts = cache.stats.coin.attempts + 1
    update_mode_status("coin")

    local success, err = start_trade_session(target_player, "coin")
    if not success then
        cache.stats.coin.failed = cache.stats.coin.failed + 1
        update_mode_status("coin")
        return
    end

    local added_items = {}
    set_status_msg("coin", "Offer accepted! Adding " .. #items_to_trade .. " item(s)...")
    for _, fish in ipairs(items_to_trade) do
        if not config.enabled or not local_player:GetAttribute("IsTrading") then break end
        
        local add_success, add_err = trade_remotes.AddItem:InvokeServer("Fish", fish.UUID)
        if add_success then
            table_insert(cache.processed_trades, fish.UUID)
            table_insert(added_items, fish)
        end
    end

    if #added_items > 0 and local_player:GetAttribute("IsTrading") then
        local chat_listener = listen_for_trade_completion()

        pcall(function()
            trade_remotes.SetReady:InvokeServer(true)
        end)
        
        wait_for_trade_end("coin")
        task_wait(0.5)

        local trade_success = false
        local check_start = tick()
        while tick() - check_start < 3.5 do
            if chat_listener.is_completed() then
                trade_success = true
                break
            end

            local still_has_items = false
            pcall(function()
                local inv = player_data:Get("Inventory")
                local current_items = inv and inv.Items or {}
                for _, trade_item in ipairs(added_items) do
                    local found = false
                    for _, inv_item in ipairs(current_items) do
                        if inv_item.UUID == trade_item.UUID then
                            found = true
                            break
                        end
                    end
                    if found then
                        still_has_items = true
                        break
                    end
                end
            end)
            if not still_has_items then
                trade_success = true
                break
            end

            task_wait(0.2)
        end
        chat_listener.disconnect()

        if trade_success then
            cache.stats.coin.success_trades = cache.stats.coin.success_trades + 1
            cache.stats.coin.last_items = #added_items
            cache.stats.coin.total_items = cache.stats.coin.total_items + #added_items
            
            if config.target_coin_amount > 0 then
                config.enabled = false
                if coin_toggle_ctrl then
                    coin_toggle_ctrl.set_state(false)
                    config.trade_coins_enabled = false
                end
                save_config()
            end
        else
            cache.stats.coin.failed = cache.stats.coin.failed + 1
        end
        update_mode_status("coin")
    else
        cache.stats.coin.failed = cache.stats.coin.failed + 1
        update_mode_status("coin")
    end
end

local function run_auto_trade_loop()
    if cache.loop_running then return end
    cache.loop_running = true

    log_inventory_fish()
    
    -- 1. Loop for Fish
    task_spawn(function()
        while _G.NoirHub_AutoTrade_ScriptID == script_id do
            if config.enabled and config.trade_fish_enabled then
                if not cache.is_trading_active then
                    cache.is_trading_active = true
                    pcall(try_trade_fish)
                    cache.is_trading_active = false
                end
            end
            task_wait(3)
        end
    end)

    -- 1.5 Loop for Rarity
    task_spawn(function()
        while _G.NoirHub_AutoTrade_ScriptID == script_id do
            if config.enabled and config.trade_rarity_enabled then
                if not cache.is_trading_active then
                    cache.is_trading_active = true
                    pcall(try_trade_rarity)
                    cache.is_trading_active = false
                end
            end
            task_wait(3)
        end
    end)

    -- 2. Loop for Enchants & Gears
    task_spawn(function()
        while _G.NoirHub_AutoTrade_ScriptID == script_id do
            if config.enabled and config.trade_enchants_enabled then
                if not cache.is_trading_active then
                    cache.is_trading_active = true
                    pcall(function()
                        if config.trade_enchants_enabled and #config.selected_items > 0 then
                            try_trade_enchant()
                        end
                    end)
                    cache.is_trading_active = false
                end
            end
            task_wait(3)
        end
    end)

    -- 3. Loop for Coins
    task_spawn(function()
        while _G.NoirHub_AutoTrade_ScriptID == script_id do
            if config.enabled and config.trade_coins_enabled and config.target_coin_amount > 0 then
                if not cache.is_trading_active then
                    cache.is_trading_active = true
                    pcall(try_trade_by_coin)
                    cache.is_trading_active = false
                end
            end
            task_wait(3)
        end
    end)
end
_G.run_auto_trade_loop = run_auto_trade_loop

-- Auto Accept Trade Connections & Game Event Suppression
local auto_accept_conn = nil
local trade_started_conn = nil
local trade_ended_conn = nil
local prompt_observer_conn = nil

local function set_game_trade_connections(enabled)
    pcall(function()
        if not getconnections or not trade_remotes then return end
        local raw_remote = trade_remotes.TradeOfferReceived.instance
        if not raw_remote or not raw_remote.OnClientEvent then return end

        for _, conn in ipairs(getconnections(raw_remote.OnClientEvent)) do
            if auto_accept_conn and (conn == auto_accept_conn or (conn.Function and auto_accept_conn.Function and conn.Function == auto_accept_conn.Function)) then
                -- Keep script connection active
            else
                pcall(function() conn.Enabled = enabled end)
                if not enabled then
                    pcall(function() if conn.Disable then conn:Disable() end end)
                else
                    pcall(function() if conn.Enable then conn:Enable() end end)
                end
            end
        end
    end)
end

local function toggle_auto_accept(enable)
    if auto_accept_conn then auto_accept_conn:Disconnect(); auto_accept_conn = nil end
    if trade_started_conn then trade_started_conn:Disconnect(); trade_started_conn = nil end
    if trade_ended_conn then trade_ended_conn:Disconnect(); trade_ended_conn = nil end
    if prompt_observer_conn then prompt_observer_conn:Disconnect(); prompt_observer_conn = nil end

    -- Re-enable game's native trade offer connections if auto accept is OFF
    if not enable or not trade_remotes then
        set_game_trade_connections(true)
        pcall(function()
            local prompt_gui = local_player.PlayerGui:FindFirstChild("Prompt")
            if prompt_gui then
                prompt_gui.Enabled = true
            end
        end)
        return
    end

    -- Disable game's native trade offer connections so game NEVER creates the popup GUI
    set_game_trade_connections(false)

    -- Real-time Prompt Suppressor: If game client still pops up a trade prompt, instantly click Yes and hide it
    pcall(function()
        local function check_and_suppress(prompt_gui)
            if not config.auto_accept_enabled or not prompt_gui then return end
            
            local blackout = prompt_gui:FindFirstChild("Blackout")
            if blackout then
                local is_trade = false
                for _, child in ipairs(prompt_gui:GetDescendants()) do
                    if child:IsA("TextLabel") and child.Text ~= "" then
                        local text = child.Text:lower()
                        if text:find("trade request") or text:find("want to accept") or text:find("trade") then
                            is_trade = true
                            break
                        end
                    end
                end

                if is_trade or (cache.status_text == "Accepting") then
                    prompt_gui.Enabled = false
                    blackout.Visible = false
                    
                    local options = blackout:FindFirstChild("Options")
                    local yes_btn = options and options:FindFirstChild("Yes")
                    if yes_btn then
                        click_gui_button(yes_btn)
                    end
                end
            end
        end

        local prompt_gui = local_player.PlayerGui:FindFirstChild("Prompt")
        if prompt_gui then
            check_and_suppress(prompt_gui)
            prompt_observer_conn = prompt_gui:GetPropertyChangedSignal("Enabled"):Connect(function()
                if prompt_gui.Enabled then
                    check_and_suppress(prompt_gui)
                end
            end)
        end
    end)

    -- Remote-based auto accept
    auto_accept_conn = trade_remotes.TradeOfferReceived.OnClientEvent:Connect(function(requester)
        if not config.auto_accept_enabled then return end
        cache.status_text = "Accepting"
        cache.status_details = "Accepting from " .. (requester and requester.DisplayName or "Player")
        
        -- Enforce suppression of game native connections
        set_game_trade_connections(false)

        -- 1. Hide any active prompt immediately
        pcall(function()
            local prompt_gui = local_player.PlayerGui:FindFirstChild("Prompt")
            if prompt_gui then
                prompt_gui.Enabled = false
                local blackout = prompt_gui:FindFirstChild("Blackout")
                if blackout then blackout.Visible = false end
                local options = blackout and blackout:FindFirstChild("Options")
                local yes_btn = options and options:FindFirstChild("Yes")
                if yes_btn then click_gui_button(yes_btn) end
            end
        end)

        -- 2. Call server remote to accept the trade offer directly (stealth)
        pcall(function()
            trade_remotes.AcceptTradeOffer:InvokeServer(requester, true)
        end)
    end)

    trade_ended_conn = trade_remotes.TradeEnded.OnClientEvent:Connect(function()
        cache.last_trade_time = tick()
        cache.active_trade = false
    end)

    trade_started_conn = trade_remotes.TradeStarted.OnClientEvent:Connect(function()
        if not (config.auto_accept_enabled or config.enabled) then return end
        cache.active_trade = true

        -- Ensure trade GUI (! Trading) is enabled on client when trade starts
        pcall(function()
            local t_gui = local_player.PlayerGui:FindFirstChild("! Trading")
            if t_gui then
                t_gui.Enabled = true
                local frame = t_gui:FindFirstChild("Frame")
                if frame then
                    frame.Visible = true
                end
            end
        end)

        task_spawn(function()
            task_wait(1)
            if not cache.active_trade then return end

            local start_time = tick()
            while (config.auto_accept_enabled or config.enabled) and cache.active_trade and (tick() - start_time) < 60 do
                -- Click GUI Accept/Confirm button (safe Lua event trigger)
                pcall(function()
                    local t_gui = local_player.PlayerGui:FindFirstChild("! Trading")
                    if t_gui then
                        for _, btn_name in ipairs({"Accept", "Confirm"}) do
                            local btn = t_gui:FindFirstChild(btn_name, true)
                            if btn then
                                click_gui_button(btn)
                            end
                        end
                    end
                end)

                task_wait(0.5)
            end
        end)
    end)
end

-- Background Auto Accept/Confirm GUI button spammer (always active, no connection required)
task_spawn(function()
    while true do
        task_wait(0.5)
        if (config.auto_accept_enabled or config.enabled) and local_player:GetAttribute("IsTrading") then
            pcall(function()
                local t_gui = local_player.PlayerGui:FindFirstChild("! Trading")
                local frame = t_gui and t_gui:FindFirstChild("Frame")
                local interior = frame and frame:FindFirstChild("Interior")
                local buttons = interior and interior:FindFirstChild("Buttons")
                if buttons then
                    for _, child in ipairs(buttons:GetChildren()) do
                        if child:IsA("GuiButton") and child.Name ~= "Decline" then
                            click_gui_button(child)
                        end
                    end
                end
            end)
        end
    end
end)
--#endregion

--#region UI Rendering
local function create_ui()
    local parent_gui
    local success_core = pcall(function()
        parent_gui = gethui and gethui() or game:GetService("CoreGui")
    end)
    if not success_core or not parent_gui then
        parent_gui = local_player and (local_player:FindFirstChild("PlayerGui") or local_player:WaitForChild("PlayerGui", 5))
    end

    -- Destroy old GUIs in CoreGui/gethui
    pcall(function()
        local core = gethui and gethui() or game:GetService("CoreGui")
        local old = core:FindFirstChild("NoirHub_AutoTrade") or core:FindFirstChild("AutoTrade")
        if old then old:Destroy() end
    end)
    -- Destroy old GUIs in PlayerGui
    pcall(function()
        local pgui = local_player:FindFirstChild("PlayerGui")
        local old = pgui and (pgui:FindFirstChild("NoirHub_AutoTrade") or pgui:FindFirstChild("AutoTrade"))
        if old then old:Destroy() end
    end)

    local gui = Instance.new("ScreenGui")
    gui.Name = "AutoTrade"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 2147483647
    gui.Parent = parent_gui

    -- Periodically force UI to top and keep it enabled to bypass game script disabling
    task_spawn(function()
        while _G.NoirHub_AutoTrade_ScriptID == script_id do
            task_wait(1)
            pcall(function()
                if gui and gui.Parent == parent_gui then
                    gui.Enabled = true
                    gui.DisplayOrder = 2147483647
                    gui.Parent = nil
                    gui.Parent = parent_gui
                end
            end)
        end
    end)

    local byname_fav_toggle = nil
    local enchant_fav_toggle = nil
    local coin_fav_toggle = nil
    local rarity_fav_toggle = nil

    local function sync_fav_toggles(active)
        config.trade_favorited = active
        save_config()
        if byname_fav_toggle then byname_fav_toggle.set_state(active) end
        if enchant_fav_toggle then enchant_fav_toggle.set_state(active) end
        if coin_fav_toggle then coin_fav_toggle.set_state(active) end
        if rarity_fav_toggle then rarity_fav_toggle.set_state(active) end

        -- Reload caches based on new favorited filter state
        cache.loaded_fish = get_owned_fish_options()
        cache.loaded_enchants = get_owned_enchant_options()

        -- Refresh selection panels if they are currently visible
        if item_panel and item_panel.Visible and populate_items_panel and fish_dropdown_btn then
            pcall(function() populate_items_panel(fish_dropdown_btn) end)
        end
        if enchant_panel and enchant_panel.Visible and populate_enchants_panel and enchant_dropdown_btn then
            pcall(function() populate_enchants_panel(enchant_dropdown_btn) end)
        end
    end

    local function sync_qty_boxes(val)
        config.quantity = val
        save_config()
        if qty_box then qty_box.Text = tostring(val) end
        if es_qty_box then es_qty_box.Text = tostring(val) end
        if r_qty_box then r_qty_box.Text = tostring(val) end
    end

    local function truncate_string(str, max_len)
        if #str > max_len then
            return string.sub(str, 1, max_len - 2) .. ".."
        end
        return str
    end

    -- Pre-declared helpers to resolve scope issues
    local function safe_set_scroll(scroll)
        pcall(function()
            scroll.ScrollingDirection = Enum.ScrollingDirection.Y
        end)
        pcall(function()
            scroll.AutomaticCanvasSize = Enum.AutomaticCanvasSize.Y
        end)
    end

    local function get_other_players()
        local list = {}
        for _, p in ipairs(players:GetPlayers()) do
            if p ~= local_player then
                table_insert(list, p.Name)
            end
        end
        table_sort(list)
        return list
    end

    local function get_owned_enchant_options()
        local list = {}
        local counts = get_inventory_enchants(true)
        for name, qty in pairs(counts) do
            table_insert(list, name .. " (x" .. qty .. ")")
        end
        table_sort(list)
        return list
    end

    local function get_owned_fish_options()
        local list = {}
        local counts = {}
        local success, err = pcall(function()
            if player_data then
                local inventory = player_data:Get("Inventory")
                local items = inventory and inventory.Items or {}
                -- print("get_owned_fish_options: read " .. tostring(#items) .. " total items from player_data.")
                for _, item in ipairs(items) do
                    if item.Id then
                        local include_item = true
                        if item.Favorited and not config.trade_favorited then
                            include_item = false
                        end

                        if include_item then
                            local data = item_utility:GetItemData(item.Id)
                            if data and data.Data then
                                local name = data.Data.Name
                                if data.Data.Type == "Fish" then
                                    counts[name] = (counts[name] or 0) + (item.Amount or 1)
                                end
                            end
                        end
                    end
                end
            else
                -- print("get_owned_fish_options: player_data is nil!")
            end
        end)
        if not success then
            warn("get_owned_fish_options error: " .. tostring(err))
        end
        for name, qty in pairs(counts) do
            table_insert(list, name .. " (x" .. qty .. ")")
        end
        table_sort(list)
        return list
    end

    cache.loaded_fish = get_owned_fish_options()
    cache.loaded_enchants = get_owned_enchant_options()

    -- Theme colors (Magenta accent with dark-mode theme)
    local BG_COLOR = Color3.fromRGB(15, 15, 15)
    local SIDEBAR_COLOR = Color3.fromRGB(10, 10, 10)
    local ACCENT_COLOR = Color3.fromRGB(255, 0, 255) -- Magenta Accent Theme
    local TEXT_COLOR = Color3.fromRGB(240, 240, 240)
    local MUTED_COLOR = Color3.fromRGB(150, 150, 150)
    local CARD_COLOR = Color3.fromRGB(22, 22, 22)
    local TOGGLE_ON_COLOR = Color3.fromRGB(255, 0, 255) -- Magenta active state
    local INPUT_BG_COLOR = Color3.fromRGB(28, 28, 28)

    local font_face = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
    local font_bold = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

    local ply_dropdown_btn
    local target_lbl
    local fish_dropdown_btn
    local enchant_dropdown_btn
    local rarity_dropdown_btn
    local close_detector
    local active_dropdown_list = nil
    local player_panel
    local item_panel
    local enchant_panel
    local rarity_panel
    local status_val_lbl = nil
    local enchant_status_val_lbl = nil
    local coin_status_val_lbl = nil
    local rarity_status_val_lbl = nil
    local sb_status = nil
    local populate_items_panel
    local populate_enchants_panel
    local qty_box
    local es_qty_box
    local r_qty_box


    -- Main Frame (Active = true sinks click-throughs to prevent screen/camera drag)
    local main = Instance.new("Frame")
    main.Name = "MainFrame"
    main.Size = UDim2.new(0, 250, 0, 200)
    main.Position = UDim2.new(0.5, -178, 0.5, -100)
    main.BackgroundColor3 = BG_COLOR
    main.BorderSizePixel = 0
    main.Active = true
    main.ZIndex = 10
    main.Parent = gui

    local main_stroke = Instance.new("UIStroke")
    main_stroke.Color = Color3.fromRGB(45, 45, 45)
    main_stroke.Thickness = 1
    main_stroke.Parent = main

    local main_corner = Instance.new("UICorner")
    main_corner.CornerRadius = UDim.new(0, 10)
    main_corner.Parent = main

    -- Close detector overlay (covers the screen to block clicks/scrolls to settings when side panels are open)
    close_detector = Instance.new("TextButton")
    close_detector.Name = "CloseDetector"
    close_detector.Size = UDim2.new(0, 5000, 0, 5000)
    close_detector.Position = UDim2.new(0.5, -2500, 0.5, -2500)
    close_detector.BackgroundTransparency = 0.99
    close_detector.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    close_detector.Text = ""
    close_detector.ZIndex = 5
    close_detector.Active = true
    close_detector.Visible = false
    close_detector.Parent = main

    close_detector.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            item_panel.Visible = false
            enchant_panel.Visible = false
            rarity_panel.Visible = false
            if active_dropdown_list then
                active_dropdown_list.Visible = false
                active_dropdown_list = nil
            end
            close_detector.Visible = false
        end
    end)

    -- Right Side Player Selection Panel (Permanent, floating next to the main window)
    player_panel = Instance.new("Frame")
    player_panel.Name = "PlayerSelectionPanel"
    player_panel.Size = UDim2.new(0, 100, 1, 0)
    player_panel.Position = UDim2.new(1, 5, 0, 0)
    player_panel.BackgroundColor3 = BG_COLOR
    player_panel.BorderSizePixel = 0
    player_panel.Active = true
    player_panel.Visible = true
    player_panel.ZIndex = 10
    player_panel.Parent = main

    local p_stroke = Instance.new("UIStroke")
    p_stroke.Color = Color3.fromRGB(45, 45, 45)
    p_stroke.Thickness = 1
    p_stroke.Parent = player_panel

    local p_corner = Instance.new("UICorner")
    p_corner.CornerRadius = UDim.new(0, 10)
    p_corner.Parent = player_panel

    -- Refresh Players Button
    local ply_refresh = Instance.new("TextButton")
    ply_refresh.Size = UDim2.new(1, -20, 0, 26)
    ply_refresh.Position = UDim2.new(0, 10, 0, 10)
    ply_refresh.BackgroundColor3 = Color3.fromRGB(192, 0, 192)
    ply_refresh.Text = "Refresh"
    ply_refresh.TextColor3 = Color3.fromRGB(255, 255, 255)
    ply_refresh.TextSize = 9
    ply_refresh.FontFace = font_bold
    ply_refresh.Active = true
    ply_refresh.ZIndex = 10
    ply_refresh.Parent = player_panel

    local ply_refresh_c = Instance.new("UICorner")
    ply_refresh_c.CornerRadius = UDim.new(0, 5)
    ply_refresh_c.Parent = ply_refresh

    ply_refresh.MouseEnter:Connect(function()
        ply_refresh.BackgroundColor3 = Color3.fromRGB(240, 50, 240)
    end)
    ply_refresh.MouseLeave:Connect(function()
        ply_refresh.BackgroundColor3 = Color3.fromRGB(192, 0, 192)
    end)

    -- Target Player Header
    -- Target Player Header Box with Border
    target_lbl = Instance.new("TextLabel")
    target_lbl.Size = UDim2.new(1, -12, 0, 20)
    target_lbl.Position = UDim2.new(0, 6, 0, 42)
    target_lbl.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    target_lbl.BackgroundTransparency = 0
    target_lbl.Text = truncate_string(config.trade_with ~= "" and config.trade_with or "None", 10)
    target_lbl.TextColor3 = Color3.fromRGB(255, 0, 255)
    target_lbl.TextSize = 9
    target_lbl.FontFace = font_bold
    target_lbl.TextXAlignment = Enum.TextXAlignment.Center
    target_lbl.ZIndex = 10
    target_lbl.Parent = player_panel

    local target_lbl_corner = Instance.new("UICorner")
    target_lbl_corner.CornerRadius = UDim.new(0, 4)
    target_lbl_corner.Parent = target_lbl

    local target_lbl_stroke = Instance.new("UIStroke")
    target_lbl_stroke.Color = Color3.fromRGB(45, 45, 45)
    target_lbl_stroke.Thickness = 1
    target_lbl_stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    target_lbl_stroke.Parent = target_lbl

    -- Separator
    local p_sep = Instance.new("Frame")
    p_sep.Size = UDim2.new(1, 0, 0, 1)
    p_sep.Position = UDim2.new(0, 0, 0, 68)
    p_sep.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    p_sep.BorderSizePixel = 0
    p_sep.ZIndex = 10
    p_sep.Parent = player_panel

    -- Scrolling Frame
    local p_scroll = Instance.new("ScrollingFrame")
    p_scroll.Size = UDim2.new(1, -12, 1, -78)
    p_scroll.Position = UDim2.new(0, 6, 0, 73)
    p_scroll.BackgroundTransparency = 1
    p_scroll.BorderSizePixel = 0
    p_scroll.ScrollBarThickness = 3
    p_scroll.ScrollBarImageColor3 = Color3.fromRGB(45, 45, 45)
    p_scroll.Active = true
    p_scroll.ZIndex = 10
    safe_set_scroll(p_scroll)
    p_scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    p_scroll.Parent = player_panel

    local p_layout = Instance.new("UIListLayout")
    p_layout.Padding = UDim.new(0, 2)
    p_layout.Parent = p_scroll

    local function populate_players_panel()
        local success, err = pcall(function()
            for _, child in ipairs(p_scroll:GetChildren()) do
                if child:IsA("TextButton") then child:Destroy() end
            end

            local player_list = get_other_players()
            local match_count = 0

            for _, name in ipairs(player_list) do
                match_count = match_count + 1
                local is_selected = (config.trade_with == name)
                local opt_btn = Instance.new("TextButton")
                opt_btn.Size = UDim2.new(1, -6, 0, 24)
                opt_btn.BackgroundTransparency = is_selected and 0 or 1
                opt_btn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
                opt_btn.Text = ""
                opt_btn.Active = true
                opt_btn.ZIndex = 12
                opt_btn.Parent = p_scroll

                local opt_corner = Instance.new("UICorner")
                opt_corner.CornerRadius = UDim.new(0, 4)
                opt_corner.Parent = opt_btn

                local opt_lbl = Instance.new("TextLabel")
                opt_lbl.Size = UDim2.new(1, -20, 1, 0)
                opt_lbl.Position = UDim2.new(0, 15, 0, 0)
                opt_lbl.BackgroundTransparency = 1
                opt_lbl.Text = truncate_string(name, 10)
                opt_lbl.TextColor3 = is_selected and ACCENT_COLOR or TEXT_COLOR
                opt_lbl.TextSize = 9
                opt_lbl.FontFace = font_face
                opt_lbl.TextXAlignment = Enum.TextXAlignment.Left
                opt_lbl.ZIndex = 13
                opt_lbl.Parent = opt_btn

                local indicator = Instance.new("Frame")
                indicator.Size = UDim2.new(0, 3, 0, 14)
                indicator.Position = UDim2.new(0, 5, 0.5, -7)
                indicator.BackgroundColor3 = ACCENT_COLOR
                indicator.BorderSizePixel = 0
                indicator.ZIndex = 14
                indicator.Visible = is_selected
                indicator.Parent = opt_btn

                opt_btn.MouseEnter:Connect(function()
                    if not is_selected then
                        opt_btn.BackgroundTransparency = 0
                        opt_btn.BackgroundColor3 = Color3.fromRGB(35, 15, 35)
                    end
                end)
                opt_btn.MouseLeave:Connect(function()
                    if not is_selected then
                        opt_btn.BackgroundTransparency = 1
                    else
                        opt_btn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
                    end
                end)

                opt_btn.MouseButton1Click:Connect(function()
                    config.trade_with = name
                    if target_lbl then
                        target_lbl.Text = truncate_string(name, 10)
                    end
                    save_config()
                    populate_players_panel()
                end)
            end

            p_scroll.CanvasSize = UDim2.new(0, 0, 0, match_count * 26 + 10)
        end)
        if not success then
            warn("populate_players_panel error: " .. tostring(err))
            print("populate_players_panel error: " .. tostring(err))
        end
    end

    ply_refresh.Activated:Connect(function()
        ply_refresh.Text = "Refreshed!"
        populate_players_panel()
        task_wait(1)
        ply_refresh.Text = "Refresh"
    end)

    -- Populate initial player list
    populate_players_panel()

    -- Right Side Item Selection Panel
    item_panel = Instance.new("Frame")
    item_panel.Name = "ItemSelectionPanel"
    item_panel.Size = UDim2.new(0, 150, 1, -34)
    item_panel.Position = UDim2.new(1, -160, 0, 28)
    item_panel.BackgroundColor3 = BG_COLOR
    item_panel.BorderSizePixel = 0
    item_panel.Active = true
    item_panel.Visible = false
    item_panel.ZIndex = 10
    item_panel.Parent = main

    local i_stroke = Instance.new("UIStroke")
    i_stroke.Color = Color3.fromRGB(45, 45, 45)
    i_stroke.Thickness = 1
    i_stroke.Parent = item_panel

    local i_corner = Instance.new("UICorner")
    i_corner.CornerRadius = UDim.new(0, 10)
    i_corner.Parent = item_panel

    -- Search Box for Items
    local item_search_box = Instance.new("TextBox")
    item_search_box.Size = UDim2.new(1, -20, 0, 24)
    item_search_box.Position = UDim2.new(0, 10, 0, 10)
    item_search_box.BackgroundColor3 = INPUT_BG_COLOR
    item_search_box.Text = ""
    item_search_box.PlaceholderText = "Search..."
    item_search_box.PlaceholderColor3 = MUTED_COLOR
    item_search_box.TextColor3 = TEXT_COLOR
    item_search_box.TextSize = 9
    item_search_box.FontFace = font_face
    item_search_box.TextXAlignment = Enum.TextXAlignment.Center
    item_search_box.Active = true
    item_search_box.ZIndex = 10
    item_search_box.Parent = item_panel

    local isb_c = Instance.new("UICorner")
    isb_c.CornerRadius = UDim.new(0, 5)
    isb_c.Parent = item_search_box

    local isb_stroke = Instance.new("UIStroke")
    isb_stroke.Color = Color3.fromRGB(45, 45, 45)
    isb_stroke.Thickness = 1
    isb_stroke.Parent = item_search_box

    local isb_padding = Instance.new("UIPadding")
    isb_padding.PaddingLeft = UDim.new(0, 8)
    isb_padding.PaddingRight = UDim.new(0, 8)
    isb_padding.Parent = item_search_box

    -- Separator
    local i_sep = Instance.new("Frame")
    i_sep.Size = UDim2.new(1, 0, 0, 1)
    i_sep.Position = UDim2.new(0, 0, 0, 42)
    i_sep.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    i_sep.BorderSizePixel = 0
    i_sep.ZIndex = 10
    i_sep.Parent = item_panel

    -- Scrolling Frame for Items
    -- Scrolling Frame for Items
    local i_scroll = Instance.new("ScrollingFrame")
    i_scroll.Size = UDim2.new(1, -12, 1, -52)
    i_scroll.Position = UDim2.new(0, 6, 0, 47)
    i_scroll.BackgroundTransparency = 1
    i_scroll.BorderSizePixel = 0
    i_scroll.ScrollBarThickness = 3
    i_scroll.ScrollBarImageColor3 = Color3.fromRGB(45, 45, 45)
    i_scroll.Active = true
    i_scroll.ZIndex = 10
    safe_set_scroll(i_scroll)
    i_scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    i_scroll.Parent = item_panel

    local i_layout = Instance.new("UIListLayout")
    i_layout.Padding = UDim.new(0, 2)
    i_layout.Parent = i_scroll

    populate_items_panel = function(update_dropdown_btn)
        local success, err = pcall(function()
            for _, child in ipairs(i_scroll:GetChildren()) do
                if child:IsA("TextButton") then child:Destroy() end
            end

            local fish_options = cache.loaded_fish or {}
            local query = string_lower(item_search_box.Text)
            if query == "search..." then query = "" end
            local match_count = 0

            -- Insert "All" at the top of options
            local options_list = {}
            table_insert(options_list, "All")
            for _, opt in ipairs(fish_options) do
                table_insert(options_list, opt)
            end

            for _, opt in ipairs(options_list) do
                local clean_opt = strip_quantity(opt)
                if query == "" or string_find(string_lower(clean_opt), query) then
                    match_count = match_count + 1
                    local is_selected = table_find(config.selected_fish, clean_opt) ~= nil
                    local opt_btn = Instance.new("TextButton")
                    opt_btn.Size = UDim2.new(1, -6, 0, 24)
                    opt_btn.BackgroundTransparency = is_selected and 0 or 1
                    opt_btn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
                    opt_btn.Text = ""
                    opt_btn.Active = true
                    opt_btn.ZIndex = 12
                    opt_btn.Parent = i_scroll

                    local opt_corner = Instance.new("UICorner")
                    opt_corner.CornerRadius = UDim.new(0, 4)
                    opt_corner.Parent = opt_btn

                    local opt_lbl = Instance.new("TextLabel")
                    opt_lbl.Size = UDim2.new(1, -20, 1, 0)
                    opt_lbl.Position = UDim2.new(0, 15, 0, 0)
                    opt_lbl.BackgroundTransparency = 1
                    opt_lbl.Text = opt
                    opt_lbl.TextColor3 = is_selected and ACCENT_COLOR or TEXT_COLOR
                    opt_lbl.TextSize = 9
                    opt_lbl.FontFace = font_face
                    opt_lbl.TextXAlignment = Enum.TextXAlignment.Left
                    opt_lbl.ZIndex = 13
                    opt_lbl.Parent = opt_btn

                    local indicator = Instance.new("Frame")
                    indicator.Size = UDim2.new(0, 3, 0, 14)
                    indicator.Position = UDim2.new(0, 5, 0.5, -7)
                    indicator.BackgroundColor3 = ACCENT_COLOR
                    indicator.BorderSizePixel = 0
                    indicator.ZIndex = 14
                    indicator.Visible = is_selected
                    indicator.Parent = opt_btn

                    opt_btn.MouseEnter:Connect(function()
                        if not is_selected then
                            opt_btn.BackgroundTransparency = 0
                            opt_btn.BackgroundColor3 = Color3.fromRGB(35, 15, 35)
                        end
                    end)
                    opt_btn.MouseLeave:Connect(function()
                        if not is_selected then
                            opt_btn.BackgroundTransparency = 1
                        else
                            opt_btn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
                        end
                    end)

                    opt_btn.MouseButton1Click:Connect(function()
                        if clean_opt == "All" then
                            config.selected_fish = { "All" }
                        else
                            local all_idx = table_find(config.selected_fish, "All")
                            if all_idx then table_remove(config.selected_fish, all_idx) end

                            local idx = table_find(config.selected_fish, clean_opt)
                            if idx then
                                table_remove(config.selected_fish, idx)
                            else
                                table_insert(config.selected_fish, clean_opt)
                            end
                        end

                        config.trade_fish_enabled = #config.selected_fish > 0
                        
                        -- Update dropdown text
                        if #config.selected_fish == 0 then
                            update_dropdown_btn.Text = "Select Option"
                        elseif #config.selected_fish == 1 then
                            update_dropdown_btn.Text = tostring(config.selected_fish[1])
                        else
                            update_dropdown_btn.Text = tostring(#config.selected_fish) .. " selected"
                        end

                        save_config()
                        populate_items_panel(update_dropdown_btn)
                    end)
                end
            end

            i_scroll.CanvasSize = UDim2.new(0, 0, 0, match_count * 26 + 10)
        end)
        if not success then
            warn("populate_items_panel error: " .. tostring(err))
            print("populate_items_panel error: " .. tostring(err))
        end
    end

    item_search_box:GetPropertyChangedSignal("Text"):Connect(function()
        if fish_dropdown_btn then
            populate_items_panel(fish_dropdown_btn)
        end
    end)

    -- Right Side Enchant Selection Panel
    enchant_panel = Instance.new("Frame")
    enchant_panel.Name = "EnchantSelectionPanel"
    enchant_panel.Size = UDim2.new(0, 150, 1, -34)
    enchant_panel.Position = UDim2.new(1, -160, 0, 28)
    enchant_panel.BackgroundColor3 = BG_COLOR
    enchant_panel.BorderSizePixel = 0
    enchant_panel.Active = true
    enchant_panel.Visible = false
    enchant_panel.ZIndex = 10
    enchant_panel.Parent = main

    local en_stroke = Instance.new("UIStroke")
    en_stroke.Color = Color3.fromRGB(45, 45, 45)
    en_stroke.Thickness = 1
    en_stroke.Parent = enchant_panel

    local en_corner = Instance.new("UICorner")
    en_corner.CornerRadius = UDim.new(0, 10)
    en_corner.Parent = enchant_panel

    -- Search Box for Enchants
    local enchant_search_box = Instance.new("TextBox")
    enchant_search_box.Size = UDim2.new(1, -20, 0, 24)
    enchant_search_box.Position = UDim2.new(0, 10, 0, 10)
    enchant_search_box.BackgroundColor3 = INPUT_BG_COLOR
    enchant_search_box.Text = ""
    enchant_search_box.PlaceholderText = "Search..."
    enchant_search_box.PlaceholderColor3 = MUTED_COLOR
    enchant_search_box.TextColor3 = TEXT_COLOR
    enchant_search_box.TextSize = 9
    enchant_search_box.FontFace = font_face
    enchant_search_box.TextXAlignment = Enum.TextXAlignment.Center
    enchant_search_box.Active = true
    enchant_search_box.ZIndex = 10
    enchant_search_box.Parent = enchant_panel

    local esb_c = Instance.new("UICorner")
    esb_c.CornerRadius = UDim.new(0, 5)
    esb_c.Parent = enchant_search_box

    local esb_stroke = Instance.new("UIStroke")
    esb_stroke.Color = Color3.fromRGB(45, 45, 45)
    esb_stroke.Thickness = 1
    esb_stroke.Parent = enchant_search_box

    local esb_padding = Instance.new("UIPadding")
    esb_padding.PaddingLeft = UDim.new(0, 8)
    esb_padding.PaddingRight = UDim.new(0, 8)
    esb_padding.Parent = enchant_search_box

    -- Separator
    local en_sep = Instance.new("Frame")
    en_sep.Size = UDim2.new(1, 0, 0, 1)
    en_sep.Position = UDim2.new(0, 0, 0, 42)
    en_sep.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    en_sep.BorderSizePixel = 0
    en_sep.ZIndex = 10
    en_sep.Parent = enchant_panel

    -- Scrolling Frame for Enchants
    local en_scroll = Instance.new("ScrollingFrame")
    en_scroll.Size = UDim2.new(1, -12, 1, -52)
    en_scroll.Position = UDim2.new(0, 6, 0, 47)
    en_scroll.BackgroundTransparency = 1
    en_scroll.BorderSizePixel = 0
    en_scroll.ScrollBarThickness = 3
    en_scroll.ScrollBarImageColor3 = Color3.fromRGB(45, 45, 45)
    en_scroll.Active = true
    en_scroll.ZIndex = 10
    safe_set_scroll(en_scroll)
    en_scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    en_scroll.Parent = enchant_panel

    local en_layout = Instance.new("UIListLayout")
    en_layout.Padding = UDim.new(0, 2)
    en_layout.Parent = en_scroll

    populate_enchants_panel = function(update_dropdown_btn)
        local success, err = pcall(function()
            for _, child in ipairs(en_scroll:GetChildren()) do
                if child:IsA("TextButton") then child:Destroy() end
            end

            local enchant_options = cache.loaded_enchants or {}
            local query = string_lower(enchant_search_box.Text)
            if query == "search..." then query = "" end
            local match_count = 0

            local options_list = {}
            table_insert(options_list, "All")
            for _, opt in ipairs(enchant_options) do
                table_insert(options_list, opt)
            end

            for _, opt in ipairs(options_list) do
                local clean_opt = strip_quantity(opt)
                if query == "" or string_find(string_lower(clean_opt), query) then
                    match_count = match_count + 1
                    local is_selected = table_find(config.selected_items, clean_opt) ~= nil

                    local opt_btn = Instance.new("TextButton")
                    opt_btn.Size = UDim2.new(1, -6, 0, 24)
                    opt_btn.BackgroundTransparency = is_selected and 0 or 1
                    opt_btn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
                    opt_btn.Text = ""
                    opt_btn.Active = true
                    opt_btn.ZIndex = 12
                    opt_btn.Parent = en_scroll

                    local opt_corner = Instance.new("UICorner")
                    opt_corner.CornerRadius = UDim.new(0, 4)
                    opt_corner.Parent = opt_btn

                    local opt_lbl = Instance.new("TextLabel")
                    opt_lbl.Size = UDim2.new(1, -20, 1, 0)
                    opt_lbl.Position = UDim2.new(0, 15, 0, 0)
                    opt_lbl.BackgroundTransparency = 1
                    opt_lbl.Text = opt
                    opt_lbl.TextColor3 = is_selected and ACCENT_COLOR or TEXT_COLOR
                    opt_lbl.TextSize = 9
                    opt_lbl.FontFace = font_face
                    opt_lbl.TextXAlignment = Enum.TextXAlignment.Left
                    opt_lbl.ZIndex = 13
                    opt_lbl.Parent = opt_btn

                    local indicator = Instance.new("Frame")
                    indicator.Size = UDim2.new(0, 3, 0, 14)
                    indicator.Position = UDim2.new(0, 5, 0.5, -7)
                    indicator.BackgroundColor3 = ACCENT_COLOR
                    indicator.BorderSizePixel = 0
                    indicator.ZIndex = 14
                    indicator.Visible = is_selected
                    indicator.Parent = opt_btn

                    opt_btn.MouseEnter:Connect(function()
                        if not is_selected then
                            opt_btn.BackgroundTransparency = 0
                            opt_btn.BackgroundColor3 = Color3.fromRGB(35, 15, 35)
                        end
                    end)
                    opt_btn.MouseLeave:Connect(function()
                        if not is_selected then
                            opt_btn.BackgroundTransparency = 1
                        else
                            opt_btn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
                        end
                    end)

                    opt_btn.MouseButton1Click:Connect(function()
                        if clean_opt == "All" then
                            config.selected_items = { "All" }
                        else
                            local all_idx = table_find(config.selected_items, "All")
                            if all_idx then table_remove(config.selected_items, all_idx) end

                            local idx = table_find(config.selected_items, clean_opt)
                            if idx then
                                table_remove(config.selected_items, idx)
                            else
                                table_insert(config.selected_items, clean_opt)
                            end
                        end

                        config.trade_enchants_enabled = #config.selected_items > 0
                        
                        -- Update dropdown text
                        if #config.selected_items == 0 then
                            update_dropdown_btn.Text = "Select Option"
                        elseif #config.selected_items == 1 then
                            update_dropdown_btn.Text = tostring(config.selected_items[1])
                        else
                            update_dropdown_btn.Text = tostring(#config.selected_items) .. " selected"
                        end

                        save_config()
                        populate_enchants_panel(update_dropdown_btn)
                    end)
                end
            end

            en_scroll.CanvasSize = UDim2.new(0, 0, 0, match_count * 26 + 10)
        end)
        if not success then
            warn("populate_enchants_panel error: " .. tostring(err))
            print("populate_enchants_panel error: " .. tostring(err))
        end
    end

    enchant_search_box:GetPropertyChangedSignal("Text"):Connect(function()
        if enchant_dropdown_btn then
            populate_enchants_panel(enchant_dropdown_btn)
        end
    end)

    -- Right Side Rarity Selection Panel
    rarity_panel = Instance.new("Frame")
    rarity_panel.Name = "RaritySelectionPanel"
    rarity_panel.Size = UDim2.new(0, 150, 1, -34)
    rarity_panel.Position = UDim2.new(1, -160, 0, 28)
    rarity_panel.BackgroundColor3 = BG_COLOR
    rarity_panel.BorderSizePixel = 0
    rarity_panel.Active = true
    rarity_panel.Visible = false
    rarity_panel.ZIndex = 10
    rarity_panel.Parent = main

    local r_stroke = Instance.new("UIStroke")
    r_stroke.Color = Color3.fromRGB(45, 45, 45)
    r_stroke.Thickness = 1
    r_stroke.Parent = rarity_panel

    local r_corner = Instance.new("UICorner")
    r_corner.CornerRadius = UDim.new(0, 10)
    r_corner.Parent = rarity_panel

    local r_title = Instance.new("TextLabel")
    r_title.Size = UDim2.new(1, -20, 0, 24)
    r_title.Position = UDim2.new(0, 10, 0, 10)
    r_title.BackgroundTransparency = 1
    r_title.Text = "Select Rarity"
    r_title.TextColor3 = ACCENT_COLOR
    r_title.TextSize = 9
    r_title.FontFace = font_bold
    r_title.TextXAlignment = Enum.TextXAlignment.Center
    r_title.ZIndex = 10
    r_title.Parent = rarity_panel

    local r_sep = Instance.new("Frame")
    r_sep.Size = UDim2.new(1, 0, 0, 1)
    r_sep.Position = UDim2.new(0, 0, 0, 42)
    r_sep.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    r_sep.BorderSizePixel = 0
    r_sep.ZIndex = 10
    r_sep.Parent = rarity_panel

    -- List Container Box with Outline
    -- Scrolling Frame for Rarity
    local r_scroll = Instance.new("ScrollingFrame")
    r_scroll.Size = UDim2.new(1, -12, 1, -52)
    r_scroll.Position = UDim2.new(0, 6, 0, 47)
    r_scroll.BackgroundTransparency = 1
    r_scroll.BorderSizePixel = 0
    r_scroll.ScrollBarThickness = 3
    r_scroll.ScrollBarImageColor3 = Color3.fromRGB(45, 45, 45)
    r_scroll.Active = true
    r_scroll.ZIndex = 10
    safe_set_scroll(r_scroll)
    r_scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    r_scroll.Parent = rarity_panel

    local r_layout = Instance.new("UIListLayout")
    r_layout.Padding = UDim.new(0, 2)
    r_layout.Parent = r_scroll

    local function populate_rarity_panel(update_dropdown_btn)
        local success, err = pcall(function()
            for _, child in ipairs(r_scroll:GetChildren()) do
                if child:IsA("TextButton") then child:Destroy() end
            end

            local rarity_options = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "SECRET", "Forgotten" }
            local match_count = 0

            local options_list = {}
            table_insert(options_list, "All")
            for _, opt in ipairs(rarity_options) do
                table_insert(options_list, opt)
            end

            for _, opt in ipairs(options_list) do
                match_count = match_count + 1
                local is_selected = table_find(config.selected_tiers, opt) ~= nil
                local opt_btn = Instance.new("TextButton")
                opt_btn.Size = UDim2.new(1, -6, 0, 24)
                opt_btn.BackgroundTransparency = is_selected and 0 or 1
                opt_btn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
                opt_btn.Text = ""
                opt_btn.Active = true
                opt_btn.ZIndex = 12
                opt_btn.Parent = r_scroll

                local opt_corner = Instance.new("UICorner")
                opt_corner.CornerRadius = UDim.new(0, 4)
                opt_corner.Parent = opt_btn

                local opt_lbl = Instance.new("TextLabel")
                opt_lbl.Size = UDim2.new(1, -20, 1, 0)
                opt_lbl.Position = UDim2.new(0, 15, 0, 0)
                opt_lbl.BackgroundTransparency = 1
                opt_lbl.Text = opt
                opt_lbl.TextColor3 = is_selected and ACCENT_COLOR or TEXT_COLOR
                opt_lbl.TextSize = 9
                opt_lbl.FontFace = font_face
                opt_lbl.TextXAlignment = Enum.TextXAlignment.Left
                opt_lbl.ZIndex = 13
                opt_lbl.Parent = opt_btn

                local indicator = Instance.new("Frame")
                indicator.Size = UDim2.new(0, 3, 0, 14)
                indicator.Position = UDim2.new(0, 5, 0.5, -7)
                indicator.BackgroundColor3 = ACCENT_COLOR
                indicator.BorderSizePixel = 0
                indicator.ZIndex = 14
                indicator.Visible = is_selected
                indicator.Parent = opt_btn

                opt_btn.MouseEnter:Connect(function()
                    if not is_selected then
                        opt_btn.BackgroundTransparency = 0
                        opt_btn.BackgroundColor3 = Color3.fromRGB(35, 15, 35)
                    end
                end)
                opt_btn.MouseLeave:Connect(function()
                    if not is_selected then
                        opt_btn.BackgroundTransparency = 1
                    else
                        opt_btn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
                    end
                end)

                opt_btn.MouseButton1Click:Connect(function()
                    if opt == "All" then
                        config.selected_tiers = { "All" }
                    else
                        local all_idx = table_find(config.selected_tiers, "All")
                        if all_idx then table_remove(config.selected_tiers, all_idx) end

                        local idx = table_find(config.selected_tiers, opt)
                        if idx then
                            table_remove(config.selected_tiers, idx)
                        else
                            table_insert(config.selected_tiers, opt)
                        end
                    end

                    config.trade_rarity_enabled = #config.selected_tiers > 0
                    
                    -- Update dropdown text
                    if #config.selected_tiers == 0 then
                        update_dropdown_btn.Text = "Select Option"
                    elseif #config.selected_tiers == 1 then
                        update_dropdown_btn.Text = tostring(config.selected_tiers[1])
                    else
                        update_dropdown_btn.Text = tostring(#config.selected_tiers) .. " selected"
                    end

                    save_config()
                    populate_rarity_panel(update_dropdown_btn)
                end)
            end

            r_scroll.CanvasSize = UDim2.new(0, 0, 0, match_count * 26 + 10)
        end)
        if not success then
            warn("populate_rarity_panel error: " .. tostring(err))
        end
    end

    -- Top Header Bar (Used for dragging)
    local header = Instance.new("Frame")
    header.Name = "HeaderBar"
    header.Size = UDim2.new(1, 0, 0, 24)
    header.BackgroundColor3 = SIDEBAR_COLOR
    header.BorderSizePixel = 0
    header.Active = true
    header.ZIndex = 5
    header.Parent = main

    local header_corner = Instance.new("UICorner")
    header_corner.CornerRadius = UDim.new(0, 10)
    header_corner.Parent = header

    -- Flat cover for bottom-left/right of header rounded corners
    local header_cover = Instance.new("Frame")
    header_cover.Size = UDim2.new(1, 0, 0, 6)
    header_cover.Position = UDim2.new(0, 0, 1, -6)
    header_cover.BackgroundColor3 = SIDEBAR_COLOR
    header_cover.BorderSizePixel = 0
    header_cover.ZIndex = 5
    header_cover.Parent = header

    local header_div = Instance.new("Frame")
    header_div.Size = UDim2.new(1, 0, 0, 1)
    header_div.Position = UDim2.new(0, 0, 1, 0)
    header_div.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    header_div.BorderSizePixel = 0
    header_div.ZIndex = 5
    header_div.Parent = header

    -- Header Title (NØIR Hub)
    local title_lbl = Instance.new("TextLabel")
    title_lbl.Size = UDim2.new(1, -40, 1, 0)
    title_lbl.Position = UDim2.new(0, 10, 0, 0)
    title_lbl.BackgroundTransparency = 1
    title_lbl.Text = "NØIR Hub"
    title_lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    title_lbl.TextSize = 10
    title_lbl.FontFace = font_bold
    title_lbl.TextXAlignment = Enum.TextXAlignment.Left
    title_lbl.ZIndex = 6
    title_lbl.Parent = header

    -- Drag Logic on Header Bar (prevents misclicks on inputs)
    local dragging, drag_input, drag_start, start_pos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, drag_start, start_pos = true, input.Position, main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            drag_input = input
        end
    end)
    user_input_service.InputChanged:Connect(function(input)
        if input == drag_input and dragging then
            local delta = input.Position - drag_start
            main.Position = UDim2.new(start_pos.X.Scale, start_pos.X.Offset + delta.X, start_pos.Y.Scale, start_pos.Y.Offset + delta.Y)
        end
    end)

    -- Floating Icon (Left Side Restore Button)
    local floating_btn = Instance.new("TextButton")
    floating_btn.Name = "FloatingRestore"
    floating_btn.Size = UDim2.new(0, 32, 0, 32)
    floating_btn.Position = UDim2.new(0, 15, 0.5, -16)
    floating_btn.BackgroundColor3 = SIDEBAR_COLOR
    floating_btn.Text = "⇄"
    floating_btn.TextColor3 = ACCENT_COLOR
    floating_btn.TextSize = 14
    floating_btn.FontFace = font_bold
    floating_btn.Active = true
    floating_btn.Modal = true -- Forces mouse unlock & blocks game camera dragging
    floating_btn.ZIndex = 20
    floating_btn.Visible = false
    floating_btn.Parent = gui

    local float_corner = Instance.new("UICorner")
    float_corner.CornerRadius = UDim.new(1, 0)
    float_corner.Parent = floating_btn

    local float_stroke = Instance.new("UIStroke")
    float_stroke.Color = ACCENT_COLOR
    float_stroke.Thickness = 1.5
    float_stroke.Parent = floating_btn

    floating_btn.MouseButton1Click:Connect(function()
        main.Visible = true
        floating_btn.Visible = false
    end)

    -- Minimize Button in Header Bar
    local min_btn = Instance.new("TextButton")
    min_btn.Name = "MinimizeBtn"
    min_btn.Size = UDim2.new(0, 24, 0, 24)
    min_btn.Position = UDim2.new(1, -28, 0.5, -12)
    min_btn.BackgroundTransparency = 1
    min_btn.Text = "-"
    min_btn.TextColor3 = MUTED_COLOR
    min_btn.TextSize = 16
    min_btn.FontFace = font_bold
    min_btn.Active = true
    min_btn.Modal = true
    min_btn.ZIndex = 6
    min_btn.Parent = header

    min_btn.MouseButton1Click:Connect(function()
        main.Visible = false
        floating_btn.Visible = true
    end)

    local container = Instance.new("Frame")
    container.Name = "Content"
    container.Size = UDim2.new(1, -12, 1, -34)
    container.Position = UDim2.new(0, 6, 0, 28)
    container.BackgroundTransparency = 1
    container.Active = false
    container.ZIndex = 2
    container.Parent = main

    -- Settings panel scrolling frame
    local settings_panel = Instance.new("ScrollingFrame")
    settings_panel.Name = "SettingsPanel"
    settings_panel.Size = UDim2.new(1, 0, 1, 0)
    settings_panel.Position = UDim2.new(0, 0, 0, 0)
    settings_panel.BackgroundTransparency = 1
    settings_panel.BorderSizePixel = 0
    settings_panel.ScrollBarThickness = 3
    settings_panel.ScrollBarImageColor3 = Color3.fromRGB(45, 45, 45)
    settings_panel.Active = true
    safe_set_scroll(settings_panel)
    settings_panel.Parent = container

    local settings_pad = Instance.new("UIPadding")
    settings_pad.PaddingLeft = UDim.new(0, 6)
    settings_pad.PaddingRight = UDim.new(0, 10)
    settings_pad.PaddingTop = UDim.new(0, 6)
    settings_pad.PaddingBottom = UDim.new(0, 6)
    settings_pad.Parent = settings_panel

    local settings_layout = Instance.new("UIListLayout")
    settings_layout.Padding = UDim.new(0, 6)
    settings_layout.Parent = settings_panel

    ----------------------------------------------------
    -- ACCORDION COMPONENT BUILDER
    ----------------------------------------------------
    local function create_accordion(parent, title_text)
        local item_frame = Instance.new("Frame")
        item_frame.Size = UDim2.new(1, 0, 0, 26)
        item_frame.BackgroundColor3 = CARD_COLOR
        item_frame.BorderSizePixel = 0
        item_frame.ClipsDescendants = true
        item_frame.Active = false
        item_frame.Parent = parent

        local accordion_stroke = Instance.new("UIStroke")
        accordion_stroke.Color = Color3.fromRGB(35, 35, 35)
        accordion_stroke.Thickness = 1
        accordion_stroke.Parent = item_frame

        local accordion_corner = Instance.new("UICorner")
        accordion_corner.CornerRadius = UDim.new(0, 5)
        accordion_corner.Parent = item_frame

        -- Header Bar
        local header = Instance.new("TextButton")
        header.Size = UDim2.new(1, 0, 0, 26)
        header.BackgroundTransparency = 1
        header.Text = "  " .. title_text
        header.TextColor3 = TEXT_COLOR
        header.TextSize = 9
        header.FontFace = font_bold
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.Active = true
        header.Modal = true
        header.Parent = item_frame

        local chevron = Instance.new("TextLabel")
        chevron.Size = UDim2.new(0, 20, 1, 0)
        chevron.Position = UDim2.new(1, -25, 0, 0)
        chevron.BackgroundTransparency = 1
        chevron.Text = "▼"
        chevron.TextColor3 = ACCENT_COLOR
        chevron.TextSize = 9
        chevron.FontFace = font_face
        chevron.TextXAlignment = Enum.TextXAlignment.Right
        chevron.Parent = header

        -- Content Frame
        local content = Instance.new("Frame")
        content.Name = "Content"
        content.Size = UDim2.new(1, -12, 0, 0)
        content.Position = UDim2.new(0, 6, 0, 28)
        content.BackgroundTransparency = 1
        content.Active = false
        content.Parent = item_frame

        local content_layout = Instance.new("UIListLayout")
        content_layout.Padding = UDim.new(0, 6)
        content_layout.SortOrder = Enum.SortOrder.LayoutOrder
        content_layout.Parent = content

        local expanded = false
        local function toggle_expand()
            expanded = not expanded
            chevron.Text = expanded and "▲" or "▼"
            
            local target_height = 26
            if expanded then
                target_height = 32 + content_layout.AbsoluteContentSize.Y
            end
            
            tween_service:Create(item_frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(1, 0, 0, target_height)
            }):Play()
            
            task_wait(0.21)
            parent.CanvasSize = UDim2.new(0, 0, 0, settings_layout.AbsoluteContentSize.Y + 20)
        end

        content_layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            if expanded then
                item_frame.Size = UDim2.new(1, 0, 0, 32 + content_layout.AbsoluteContentSize.Y)
            end
        end)

        header.MouseButton1Click:Connect(toggle_expand)

        return content, toggle_expand
    end

    ----------------------------------------------------
    -- DYNAMIC DROP-DOWNS & TEXTBOX HELPERS
    ----------------------------------------------------
    local function create_dropdown(parent, placeholder, options, default, is_multi, callback)
        local drop_btn = Instance.new("TextButton")
        drop_btn.Size = UDim2.new(1, 0, 0, 22)
        drop_btn.BackgroundColor3 = INPUT_BG_COLOR
        drop_btn.Text = placeholder
        drop_btn.TextColor3 = TEXT_COLOR
        drop_btn.TextSize = 9
        drop_btn.FontFace = font_face
        drop_btn.TextXAlignment = Enum.TextXAlignment.Left
        drop_btn.Active = true
        drop_btn.Modal = true
        drop_btn.Parent = parent

        local drop_btn_c = Instance.new("UICorner")
        drop_btn_c.CornerRadius = UDim.new(0, 4)
        drop_btn_c.Parent = drop_btn

        local d_stroke = Instance.new("UIStroke")
        d_stroke.Color = Color3.fromRGB(45, 45, 45)
        d_stroke.Thickness = 1
        d_stroke.Parent = drop_btn

        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 8)
        padding.PaddingRight = UDim.new(0, 8)
        padding.Parent = drop_btn

        local chevron = Instance.new("TextLabel")
        chevron.Size = UDim2.new(0, 20, 1, 0)
        chevron.Position = UDim2.new(1, -12, 0, 0)
        chevron.BackgroundTransparency = 1
        chevron.Text = "▼"
        chevron.TextColor3 = MUTED_COLOR
        chevron.TextSize = 7
        chevron.FontFace = font_face
        chevron.TextXAlignment = Enum.TextXAlignment.Right
        chevron.Parent = drop_btn

        local selected_values = {}
        if type(default) == "table" then
            for _, val in ipairs(default) do
                table_insert(selected_values, val)
            end
        else
            if default and default ~= "" then
                table_insert(selected_values, default)
            end
        end

        local function update_button_text()
            if #selected_values == 0 then
                drop_btn.Text = placeholder
            elseif #selected_values == 1 then
                drop_btn.Text = tostring(selected_values[1])
            else
                drop_btn.Text = tostring(#selected_values) .. " selected"
            end
        end
        update_button_text()

        local list_frame = Instance.new("Frame")
        list_frame.Size = UDim2.new(0, 160, 0, 130)
        list_frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        list_frame.BorderSizePixel = 0
        list_frame.Visible = false
        list_frame.ZIndex = 999
        list_frame.Active = true
        list_frame.Parent = gui

        local list_stroke = Instance.new("UIStroke")
        list_stroke.Color = Color3.fromRGB(50, 50, 50)
        list_stroke.Thickness = 1
        list_stroke.Parent = list_frame

        local list_corner = Instance.new("UICorner")
        list_corner.CornerRadius = UDim.new(0, 6)
        list_corner.Parent = list_frame

        local list_scroll = Instance.new("ScrollingFrame")
        list_scroll.Size = UDim2.new(1, 0, 1, 0)
        list_scroll.BackgroundTransparency = 1
        list_scroll.BorderSizePixel = 0
        list_scroll.ScrollBarThickness = 3
        list_scroll.ScrollBarImageColor3 = MUTED_COLOR
        list_scroll.Active = true
        safe_set_scroll(list_scroll)
        list_scroll.Parent = list_frame

        local list_layout = Instance.new("UIListLayout")
        list_layout.Padding = UDim.new(0, 2)
        list_layout.Parent = list_scroll

        local function populate_options()
            for _, child in ipairs(list_scroll:GetChildren()) do
                if child:IsA("TextButton") then child:Destroy() end
            end

            local resolved_options = options
            if type(options) == "function" then
                resolved_options = options()
            end

            for _, opt in ipairs(resolved_options) do
                local opt_btn = Instance.new("TextButton")
                opt_btn.Size = UDim2.new(1, 0, 0, 22)
                opt_btn.BackgroundTransparency = 1
                opt_btn.Text = opt
                opt_btn.TextSize = 9
                opt_btn.TextXAlignment = Enum.TextXAlignment.Left
                local clean_opt = strip_quantity(opt)
                local is_selected = table_find(selected_values, clean_opt) ~= nil
                opt_btn.TextColor3 = is_selected and ACCENT_COLOR or TEXT_COLOR
                opt_btn.FontFace = font_face
                opt_btn.Active = true
                opt_btn.Parent = list_scroll

                local opt_padding = Instance.new("UIPadding")
                opt_padding.PaddingLeft = UDim.new(0, 10)
                opt_padding.Parent = opt_btn

                opt_btn.MouseButton1Click:Connect(function()
                    local clean_opt = strip_quantity(opt)
                    if is_multi then
                        if opt == "All" or clean_opt == "All" then
                            selected_values = { "All" }
                        else
                            local all_idx = table_find(selected_values, "All")
                            if all_idx then table_remove(selected_values, all_idx) end
                            
                            local idx = table_find(selected_values, clean_opt)
                            if idx then
                                table_remove(selected_values, idx)
                            else
                                table_insert(selected_values, clean_opt)
                            end
                            if #selected_values == 0 then
                                selected_values = { "All" }
                            end
                        end
                    else
                        selected_values = { clean_opt }
                        list_frame.Visible = false
                        active_dropdown_list = nil
                        close_detector.Visible = false
                    end
                    
                    update_button_text()
                    populate_options()
                    callback(selected_values)
                end)
            end
            list_scroll.CanvasSize = UDim2.new(0, 0, 0, list_layout.AbsoluteContentSize.Y + 10)
        end

        drop_btn.MouseButton1Click:Connect(function()
            local resolved_options = options
            if type(options) == "function" then
                resolved_options = options()
            elseif #options == 0 then
                local temp = {}
                for name, _ in pairs(cache.loaded_fish) do
                    table_insert(temp, name)
                end
                table_sort(temp)
                options = temp
                resolved_options = temp
            end

            populate_options()
            
            if active_dropdown_list and active_dropdown_list ~= list_frame then
                active_dropdown_list.Visible = false
            end
            
            list_frame.Visible = not list_frame.Visible
            chevron.Text = list_frame.Visible and "▲" or "▼"
            if list_frame.Visible then
                local abs_pos = drop_btn.AbsolutePosition
                list_frame.Position = UDim2.new(0, abs_pos.X, 0, abs_pos.Y + drop_btn.AbsoluteSize.Y + 2)
                active_dropdown_list = list_frame
                close_detector.Visible = true
            else
                active_dropdown_list = nil
                close_detector.Visible = false
            end
        end)

        return drop_btn
    end

    local function create_input(parent, placeholder, default, callback)
        local box = Instance.new("TextBox")
        box.Size = UDim2.new(1, 0, 0, 22)
        box.BackgroundColor3 = INPUT_BG_COLOR
        box.Text = tostring(default)
        box.PlaceholderText = placeholder
        box.TextColor3 = TEXT_COLOR
        box.TextSize = 9
        box.FontFace = font_face
        box.Active = true
        box.Parent = parent

        local box_c = Instance.new("UICorner")
        box_c.CornerRadius = UDim.new(0, 4)
        box_c.Parent = box

        local box_stroke = Instance.new("UIStroke")
        box_stroke.Color = Color3.fromRGB(45, 45, 45)
        box_stroke.Thickness = 1
        box_stroke.Parent = box

        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 8)
        padding.PaddingRight = UDim.new(0, 8)
        padding.Parent = box

        box.FocusLost:Connect(function()
            callback(box.Text)
        end)
        
        return box
    end

    local function create_toggle(parent, label_text, default, callback)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 22)
        row.BackgroundTransparency = 1
        row.Active = true
        row.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.65, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = label_text
        lbl.TextColor3 = TEXT_COLOR
        lbl.TextSize = 9
        lbl.FontFace = font_bold
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        -- Capsule background button
        local capsule = Instance.new("TextButton")
        capsule.Size = UDim2.new(0, 32, 0, 16)
        capsule.Position = UDim2.new(1, -32, 0.5, -8)
        capsule.BackgroundColor3 = default and TOGGLE_ON_COLOR or Color3.fromRGB(45, 45, 45)
        capsule.Text = ""
        capsule.AutoButtonColor = false
        capsule.Active = true
        capsule.Parent = row

        local cap_c = Instance.new("UICorner")
        cap_c.CornerRadius = UDim.new(0.5, 0)
        cap_c.Parent = capsule

        local cap_stroke = Instance.new("UIStroke")
        cap_stroke.Color = Color3.fromRGB(35, 35, 35)
        cap_stroke.Thickness = 1
        cap_stroke.Parent = capsule

        -- Sliding knob
        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 12, 0, 12)
        knob.Position = default and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
        knob.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
        knob.BorderSizePixel = 0
        knob.Parent = capsule

        local knob_c = Instance.new("UICorner")
        knob_c.CornerRadius = UDim.new(0.5, 0)
        knob_c.Parent = knob

        local active = default
        local function update_visual(state, instant)
            local target_pos = state and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
            local target_color = state and TOGGLE_ON_COLOR or Color3.fromRGB(45, 45, 45)
            if instant then
                knob.Position = target_pos
                capsule.BackgroundColor3 = target_color
            else
                tween_service:Create(knob, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Position = target_pos
                }):Play()
                tween_service:Create(capsule, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    BackgroundColor3 = target_color
                }):Play()
            end
        end

        capsule.MouseButton1Click:Connect(function()
            active = not active
            update_visual(active, false)
            callback(active)
        end)

        return {
            set_state = function(state, instant)
                if state == active and not instant then return end
                active = state
                update_visual(state, instant)
            end,
            Frame = row
        }
    end

    ----------------------------------------------------
    -- RENDER CONTEXT-SPECIFIC ACCORDIONS
    ----------------------------------------------------
    local byname_toggle_ctrl
    local enchant_toggle_ctrl
    local rarity_toggle_ctrl
    local coin_toggle_ctrl

    local function sync_mode_toggles(active_mode)
        if active_mode ~= "fish" and byname_toggle_ctrl then
            byname_toggle_ctrl.set_state(false, false)
            config.trade_fish_enabled = false
        end
        if active_mode ~= "enchant" and enchant_toggle_ctrl then
            enchant_toggle_ctrl.set_state(false, false)
            config.trade_enchants_enabled = false
        end
        if active_mode ~= "rarity" and rarity_toggle_ctrl then
            rarity_toggle_ctrl.set_state(false, false)
            config.trade_rarity_enabled = false
        end
        if active_mode ~= "coin" and coin_toggle_ctrl then
            coin_toggle_ctrl.set_state(false, false)
            config.trade_coins_enabled = false
        end
        save_config()
    end
    -- 2. Trade By Name
    local byname_content, byname_toggle = create_accordion(settings_panel, "Trade By Name")
    local status_box = Instance.new("Frame")
    status_box.Name = "1_StatusBox"
    status_box.LayoutOrder = 1
    status_box.Size = UDim2.new(1, 0, 0, 50)
    status_box.AutomaticSize = Enum.AutomaticSize.Y
    status_box.BackgroundColor3 = CARD_COLOR
    status_box.BorderSizePixel = 0
    status_box.Parent = byname_content
    
    local status_box_pad = Instance.new("UIPadding")
    status_box_pad.PaddingBottom = UDim.new(0, 4)
    status_box_pad.PaddingRight = UDim.new(0, 10)
    status_box_pad.Parent = status_box
    
    local status_box_c = Instance.new("UICorner")
    status_box_c.CornerRadius = UDim.new(0, 6)
    status_box_c.Parent = status_box
    
    local status_box_stroke = Instance.new("UIStroke")
    status_box_stroke.Color = Color3.fromRGB(35, 35, 35)
    status_box_stroke.Thickness = 1
    status_box_stroke.Parent = status_box
 
    local status_title = Instance.new("TextLabel")
    status_title.Size = UDim2.new(1, -10, 0, 14)
    status_title.Position = UDim2.new(0, 10, 0, 4)
    status_title.BackgroundTransparency = 1
    status_title.Text = "Status"
    status_title.TextColor3 = ACCENT_COLOR
    status_title.TextSize = 9
    status_title.FontFace = font_bold
    status_title.TextXAlignment = Enum.TextXAlignment.Left
    status_title.Parent = status_box
 
    status_val_lbl = Instance.new("TextLabel")
    status_val_lbl.Size = UDim2.new(1, -20, 0, 24)
    status_val_lbl.Position = UDim2.new(0, 10, 0, 20)
    status_val_lbl.AutomaticSize = Enum.AutomaticSize.Y
    status_val_lbl.BackgroundTransparency = 1
    status_val_lbl.Text = "Idle"
    status_val_lbl.TextColor3 = TEXT_COLOR
    status_val_lbl.TextSize = 9
    status_val_lbl.FontFace = font_face
    status_val_lbl.TextXAlignment = Enum.TextXAlignment.Left
    status_val_lbl.TextYAlignment = Enum.TextYAlignment.Top
    status_val_lbl.TextWrapped = true
    status_val_lbl.Parent = status_box
 
    -- Select Item Row
    local item_row = Instance.new("Frame")
    item_row.Name = "2_ItemRow"
    item_row.LayoutOrder = 2
    item_row.Size = UDim2.new(1, 0, 0, 22)
    item_row.BackgroundTransparency = 1
    item_row.Active = false
    item_row.Parent = byname_content

    local item_lbl = Instance.new("TextLabel")
    item_lbl.Size = UDim2.new(0.45, 0, 1, 0)
    item_lbl.BackgroundTransparency = 1
    item_lbl.Text = "Select Item"
    item_lbl.TextColor3 = TEXT_COLOR
    item_lbl.TextSize = 9
    item_lbl.FontFace = font_bold
    item_lbl.TextXAlignment = Enum.TextXAlignment.Left
    item_lbl.Parent = item_row

    fish_dropdown_btn = Instance.new("TextButton")
    fish_dropdown_btn.Size = UDim2.new(0.55, 0, 1, 0)
    fish_dropdown_btn.Position = UDim2.new(0.45, 0, 0, 0)
    fish_dropdown_btn.BackgroundColor3 = INPUT_BG_COLOR
    
    local function get_fish_dropdown_text()
        if not config.selected_fish or #config.selected_fish == 0 then
            return "Select Option"
        elseif #config.selected_fish == 1 then
            return tostring(config.selected_fish[1])
        else
            return tostring(#config.selected_fish) .. " selected"
        end
    end
    
    fish_dropdown_btn.Text = get_fish_dropdown_text()
    fish_dropdown_btn.TextColor3 = TEXT_COLOR
    fish_dropdown_btn.TextSize = 9
    fish_dropdown_btn.FontFace = font_face
    fish_dropdown_btn.TextXAlignment = Enum.TextXAlignment.Left
    fish_dropdown_btn.Active = true
    fish_dropdown_btn.Parent = item_row

    local fish_dropdown_c = Instance.new("UICorner")
    fish_dropdown_c.CornerRadius = UDim.new(0, 4)
    fish_dropdown_c.Parent = fish_dropdown_btn

    local fish_dropdown_stroke = Instance.new("UIStroke")
    fish_dropdown_stroke.Color = Color3.fromRGB(45, 45, 45)
    fish_dropdown_stroke.Thickness = 1
    fish_dropdown_stroke.Parent = fish_dropdown_btn

    local fish_dropdown_pad = Instance.new("UIPadding")
    fish_dropdown_pad.PaddingLeft = UDim.new(0, 8)
    fish_dropdown_pad.PaddingRight = UDim.new(0, 8)
    fish_dropdown_pad.Parent = fish_dropdown_btn

    local fish_chevron = Instance.new("TextLabel")
    fish_chevron.Size = UDim2.new(0, 20, 1, 0)
    fish_chevron.Position = UDim2.new(1, -12, 0, 0)
    fish_chevron.BackgroundTransparency = 1
    fish_chevron.Text = "♦"
    fish_chevron.TextColor3 = Color3.fromRGB(192, 0, 192)
    fish_chevron.TextSize = 8
    fish_chevron.FontFace = font_face
    fish_chevron.TextXAlignment = Enum.TextXAlignment.Right
    fish_chevron.Parent = fish_dropdown_btn

    fish_dropdown_btn.Activated:Connect(function()
        item_search_box.Text = ""
        enchant_panel.Visible = false
        item_panel.Visible = not item_panel.Visible
        close_detector.Visible = item_panel.Visible
        if item_panel.Visible then
            populate_items_panel(fish_dropdown_btn)
        end
    end)

    -- Amount Row
    local amount_row = Instance.new("Frame")
    amount_row.Name = "3_AmountRow"
    amount_row.LayoutOrder = 3
    amount_row.Size = UDim2.new(1, 0, 0, 22)
    amount_row.BackgroundTransparency = 1
    amount_row.Active = false
    amount_row.Parent = byname_content

    local amount_lbl = Instance.new("TextLabel")
    amount_lbl.Size = UDim2.new(0.45, 0, 1, 0)
    amount_lbl.BackgroundTransparency = 1
    amount_lbl.Text = "Amount Fish Name"
    amount_lbl.TextColor3 = TEXT_COLOR
    amount_lbl.TextSize = 9
    amount_lbl.FontFace = font_bold
    amount_lbl.TextXAlignment = Enum.TextXAlignment.Left
    amount_lbl.Parent = amount_row

    qty_box = Instance.new("TextBox")
    qty_box.Size = UDim2.new(0.55, 0, 1, 0)
    qty_box.Position = UDim2.new(0.45, 0, 0, 0)
    qty_box.BackgroundColor3 = INPUT_BG_COLOR
    qty_box.Text = tostring(config.quantity)
    qty_box.TextColor3 = TEXT_COLOR
    qty_box.TextSize = 9
    qty_box.FontFace = font_face
    qty_box.TextXAlignment = Enum.TextXAlignment.Center
    qty_box.ClearTextOnFocus = false
    qty_box.Parent = amount_row

    local qty_c = Instance.new("UICorner")
    qty_c.CornerRadius = UDim.new(0, 4)
    qty_c.Parent = qty_box

    local qty_stroke = Instance.new("UIStroke")
    qty_stroke.Color = Color3.fromRGB(45, 45, 45)
    qty_stroke.Thickness = 1
    qty_stroke.Parent = qty_box

    qty_box.FocusLost:Connect(function()
        local text = qty_box.Text
        local val = (text == "") and 0 or (tonumber(text) or config.quantity)
        task.defer(function()
            sync_qty_boxes(val)
        end)
    end)

    -- Refresh Fish Items Button
    local refresh_btn = Instance.new("TextButton")
    refresh_btn.Name = "4_RefreshButton"
    refresh_btn.LayoutOrder = 4
    refresh_btn.Size = UDim2.new(1, 0, 0, 26)
    refresh_btn.BackgroundColor3 = Color3.fromRGB(192, 0, 192)
    refresh_btn.Text = "Refresh Fish Items"
    refresh_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    refresh_btn.TextSize = 9
    refresh_btn.FontFace = font_bold
    refresh_btn.Active = true
    refresh_btn.Parent = byname_content

    local refresh_btn_c = Instance.new("UICorner")
    refresh_btn_c.CornerRadius = UDim.new(0, 5)
    refresh_btn_c.Parent = refresh_btn

    refresh_btn.MouseEnter:Connect(function()
        refresh_btn.BackgroundColor3 = Color3.fromRGB(240, 50, 240)
    end)
    refresh_btn.MouseLeave:Connect(function()
        refresh_btn.BackgroundColor3 = Color3.fromRGB(192, 0, 192)
    end)

    refresh_btn.Activated:Connect(function()
        refresh_btn.Text = "Fish Items Refreshed!"
        cache.loaded_fish = get_owned_fish_options()
        if item_panel.Visible then
            populate_items_panel(fish_dropdown_btn)
        end
        task_wait(1)
        refresh_btn.Text = "Refresh Fish Items"
    end)

    -- Toggle Row
    byname_toggle_ctrl = create_toggle(byname_content, "Start Trade ByName", (config.enabled and config.trade_fish_enabled), function(active)
        if active then
            cache.stats.fish.success_trades = 0
            cache.stats.fish.last_items = 0
            cache.stats.fish.total_items = 0
            cache.stats.fish.attempts = 0
            cache.stats.fish.failed = 0
            update_mode_status("fish")

            config.trade_fish_enabled = true
            config.enabled = true
            sync_mode_toggles("fish")
            cache.processed_trades = {}
            run_auto_trade_loop()
        else
            config.enabled = false
            decline_active_trade()
        end
    end)
    byname_toggle_ctrl.Frame.LayoutOrder = 5
    byname_toggle_ctrl.Frame.Name = "5_StartTradeToggle"

    byname_fav_toggle = create_toggle(byname_content, "Trade Favorite Items", config.trade_favorited, function(active)
        sync_fav_toggles(active)
    end)
    byname_fav_toggle.Frame.LayoutOrder = 6
    byname_fav_toggle.Frame.Name = "6_FavToggle"

    -- 3. Trade Enchant Stone
    local enchant_content, enchant_toggle = create_accordion(settings_panel, "Trade Enchant Stone")    local enchant_status_box = Instance.new("Frame")
    enchant_status_box.Name = "1_StatusBox"
    enchant_status_box.LayoutOrder = 1
    enchant_status_box.Size = UDim2.new(1, 0, 0, 50)
    enchant_status_box.AutomaticSize = Enum.AutomaticSize.Y
    enchant_status_box.BackgroundColor3 = CARD_COLOR
    enchant_status_box.BorderSizePixel = 0
    enchant_status_box.Parent = enchant_content
    
    local enchant_status_box_pad = Instance.new("UIPadding")
    enchant_status_box_pad.PaddingBottom = UDim.new(0, 4)
    enchant_status_box_pad.PaddingRight = UDim.new(0, 10)
    enchant_status_box_pad.Parent = enchant_status_box
    
    local enchant_status_box_c = Instance.new("UICorner")
    enchant_status_box_c.CornerRadius = UDim.new(0, 6)
    enchant_status_box_c.Parent = enchant_status_box
    
    local enchant_status_box_stroke = Instance.new("UIStroke")
    enchant_status_box_stroke.Color = Color3.fromRGB(35, 35, 35)
    enchant_status_box_stroke.Thickness = 1
    enchant_status_box_stroke.Parent = enchant_status_box
 
    local enchant_status_title = Instance.new("TextLabel")
    enchant_status_title.Size = UDim2.new(1, -10, 0, 14)
    enchant_status_title.Position = UDim2.new(0, 10, 0, 4)
    enchant_status_title.BackgroundTransparency = 1
    enchant_status_title.Text = "Status"
    enchant_status_title.TextColor3 = ACCENT_COLOR
    enchant_status_title.TextSize = 9
    enchant_status_title.FontFace = font_bold
    enchant_status_title.TextXAlignment = Enum.TextXAlignment.Left
    enchant_status_title.Parent = enchant_status_box
 
    enchant_status_val_lbl = Instance.new("TextLabel")
    enchant_status_val_lbl.Size = UDim2.new(1, -20, 0, 24)
    enchant_status_val_lbl.Position = UDim2.new(0, 10, 0, 20)
    enchant_status_val_lbl.AutomaticSize = Enum.AutomaticSize.Y
    enchant_status_val_lbl.BackgroundTransparency = 1
    enchant_status_val_lbl.Text = "Idle"
    enchant_status_val_lbl.TextColor3 = TEXT_COLOR
    enchant_status_val_lbl.TextSize = 9
    enchant_status_val_lbl.FontFace = font_face
    enchant_status_val_lbl.TextXAlignment = Enum.TextXAlignment.Left
    enchant_status_val_lbl.TextYAlignment = Enum.TextYAlignment.Top
    enchant_status_val_lbl.TextWrapped = true
    enchant_status_val_lbl.Parent = enchant_status_box

    -- Stone Type Row
    local stone_row = Instance.new("Frame")
    stone_row.Name = "2_StoneRow"
    stone_row.LayoutOrder = 2
    stone_row.Size = UDim2.new(1, 0, 0, 22)
    stone_row.BackgroundTransparency = 1
    stone_row.Active = false
    stone_row.Parent = enchant_content

    local stone_lbl = Instance.new("TextLabel")
    stone_lbl.Size = UDim2.new(0.45, 0, 1, 0)
    stone_lbl.BackgroundTransparency = 1
    stone_lbl.Text = "Stone Type"
    stone_lbl.TextColor3 = TEXT_COLOR
    stone_lbl.TextSize = 9
    stone_lbl.FontFace = font_bold
    stone_lbl.TextXAlignment = Enum.TextXAlignment.Left
    stone_lbl.Parent = stone_row

    enchant_dropdown_btn = Instance.new("TextButton")
    enchant_dropdown_btn.Size = UDim2.new(0.55, 0, 1, 0)
    enchant_dropdown_btn.Position = UDim2.new(0.45, 0, 0, 0)
    enchant_dropdown_btn.BackgroundColor3 = INPUT_BG_COLOR
    
    local function get_enchant_dropdown_text()
        if not config.selected_items or #config.selected_items == 0 then
            return "Select Option"
        elseif #config.selected_items == 1 then
            return tostring(config.selected_items[1])
        else
            return tostring(#config.selected_items) .. " selected"
        end
    end
    
    enchant_dropdown_btn.Text = get_enchant_dropdown_text()
    enchant_dropdown_btn.TextColor3 = TEXT_COLOR
    enchant_dropdown_btn.TextSize = 9
    enchant_dropdown_btn.FontFace = font_face
    enchant_dropdown_btn.TextXAlignment = Enum.TextXAlignment.Left
    enchant_dropdown_btn.Active = true
    enchant_dropdown_btn.Parent = stone_row

    local enchant_dropdown_c = Instance.new("UICorner")
    enchant_dropdown_c.CornerRadius = UDim.new(0, 4)
    enchant_dropdown_c.Parent = enchant_dropdown_btn

    local enchant_dropdown_stroke = Instance.new("UIStroke")
    enchant_dropdown_stroke.Color = Color3.fromRGB(45, 45, 45)
    enchant_dropdown_stroke.Thickness = 1
    enchant_dropdown_stroke.Parent = enchant_dropdown_btn

    local enchant_dropdown_pad = Instance.new("UIPadding")
    enchant_dropdown_pad.PaddingLeft = UDim.new(0, 8)
    enchant_dropdown_pad.PaddingRight = UDim.new(0, 8)
    enchant_dropdown_pad.Parent = enchant_dropdown_btn

    local enchant_chevron = Instance.new("TextLabel")
    enchant_chevron.Size = UDim2.new(0, 20, 1, 0)
    enchant_chevron.Position = UDim2.new(1, -12, 0, 0)
    enchant_chevron.BackgroundTransparency = 1
    enchant_chevron.Text = "♦"
    enchant_chevron.TextColor3 = Color3.fromRGB(192, 0, 192)
    enchant_chevron.TextSize = 8
    enchant_chevron.FontFace = font_face
    enchant_chevron.TextXAlignment = Enum.TextXAlignment.Right
    enchant_chevron.Parent = enchant_dropdown_btn

    enchant_dropdown_btn.Activated:Connect(function()
        enchant_search_box.Text = ""
        item_panel.Visible = false
        enchant_panel.Visible = not enchant_panel.Visible
        close_detector.Visible = enchant_panel.Visible
        if enchant_panel.Visible then
            populate_enchants_panel(enchant_dropdown_btn)
        end
    end)

    -- Amount Enchant Stone Row
    local es_amount_row = Instance.new("Frame")
    es_amount_row.Name = "3_AmountRow"
    es_amount_row.LayoutOrder = 3
    es_amount_row.Size = UDim2.new(1, 0, 0, 22)
    es_amount_row.BackgroundTransparency = 1
    es_amount_row.Active = false
    es_amount_row.Parent = enchant_content

    local es_amount_lbl = Instance.new("TextLabel")
    es_amount_lbl.Size = UDim2.new(0.45, 0, 1, 0)
    es_amount_lbl.BackgroundTransparency = 1
    es_amount_lbl.Text = "Amount Enchant Stone"
    es_amount_lbl.TextColor3 = TEXT_COLOR
    es_amount_lbl.TextSize = 9
    es_amount_lbl.FontFace = font_bold
    es_amount_lbl.TextXAlignment = Enum.TextXAlignment.Left
    es_amount_lbl.Parent = es_amount_row

    es_qty_box = Instance.new("TextBox")
    es_qty_box.Size = UDim2.new(0.55, 0, 1, 0)
    es_qty_box.Position = UDim2.new(0.45, 0, 0, 0)
    es_qty_box.BackgroundColor3 = INPUT_BG_COLOR
    es_qty_box.Text = tostring(config.quantity)
    es_qty_box.TextColor3 = TEXT_COLOR
    es_qty_box.TextSize = 9
    es_qty_box.FontFace = font_face
    es_qty_box.TextXAlignment = Enum.TextXAlignment.Center
    es_qty_box.ClearTextOnFocus = false
    es_qty_box.Parent = es_amount_row

    local es_qty_c = Instance.new("UICorner")
    es_qty_c.CornerRadius = UDim.new(0, 4)
    es_qty_c.Parent = es_qty_box

    local es_qty_stroke = Instance.new("UIStroke")
    es_qty_stroke.Color = Color3.fromRGB(45, 45, 45)
    es_qty_stroke.Thickness = 1
    es_qty_stroke.Parent = es_qty_box

    es_qty_box.FocusLost:Connect(function()
        local text = es_qty_box.Text
        local val = (text == "") and 0 or (tonumber(text) or config.quantity)
        task.defer(function()
            sync_qty_boxes(val)
        end)
    end)

    -- Check Enchant Stones Button
    local es_refresh = Instance.new("TextButton")
    es_refresh.Name = "4_RefreshButton"
    es_refresh.LayoutOrder = 4
    es_refresh.Size = UDim2.new(1, 0, 0, 26)
    es_refresh.BackgroundColor3 = Color3.fromRGB(192, 0, 192)
    es_refresh.Text = "Check Enchant Stones"
    es_refresh.TextColor3 = Color3.fromRGB(255, 255, 255)
    es_refresh.TextSize = 9
    es_refresh.FontFace = font_bold
    es_refresh.Active = true
    es_refresh.Parent = enchant_content

    local es_refresh_c = Instance.new("UICorner")
    es_refresh_c.CornerRadius = UDim.new(0, 5)
    es_refresh_c.Parent = es_refresh

    es_refresh.MouseEnter:Connect(function()
        es_refresh.BackgroundColor3 = Color3.fromRGB(240, 50, 240)
    end)
    es_refresh.MouseLeave:Connect(function()
        es_refresh.BackgroundColor3 = Color3.fromRGB(192, 0, 192)
    end)

    es_refresh.MouseButton1Click:Connect(function()
        es_refresh.Text = "Enchant Stones Checked!"
        cache.loaded_enchants = get_owned_enchant_options()
        if enchant_panel.Visible then
            populate_enchants_panel(enchant_dropdown_btn)
        end
        
        -- Update status box with inventory list
        local counts = get_inventory_enchants(true)
        local status_lines = { "Inventory:" }
        local sorted_names = {}
        for name, _ in pairs(counts) do
            table_insert(sorted_names, name)
        end
        table_sort(sorted_names)
        
        for _, name in ipairs(sorted_names) do
            local qty = counts[name]
            local short_name = string.gsub(name, "%s*Enchant%s*Stone", "")
            if short_name == "" then
                short_name = "Enchant Stone"
            end
            table_insert(status_lines, short_name .. " x" .. qty)
        end
        
        cache.enchant_status_text = table.concat(status_lines, "\n")
        cache.enchant_status_details = ""
        if enchant_status_val_lbl then
            enchant_status_val_lbl.Text = cache.enchant_status_text
        end
        
        task_wait(1)
        es_refresh.Text = "Check Enchant Stones"
    end)

    enchant_toggle_ctrl = create_toggle(enchant_content, "Start Trade EnchantStone", (config.enabled and config.trade_enchants_enabled), function(active)
        if active then
            cache.stats.enchant.success_trades = 0
            cache.stats.enchant.last_items = 0
            cache.stats.enchant.total_items = 0
            cache.stats.enchant.attempts = 0
            cache.stats.enchant.failed = 0
            update_mode_status("enchant")

            config.trade_enchants_enabled = true
            config.enabled = true
            sync_mode_toggles("enchant")
            cache.processed_trades = {}
            run_auto_trade_loop()
        else
            config.enabled = false
            decline_active_trade()
        end
    end)
    enchant_toggle_ctrl.Frame.LayoutOrder = 5
    enchant_toggle_ctrl.Frame.Name = "5_StartTradeToggle"


    -- 3.5 Trade By Rarity
    local rarity_content, rarity_toggle = create_accordion(settings_panel, "Trade By Rarity")
    local rarity_status_box = Instance.new("Frame")
    rarity_status_box.Name = "1_StatusBox"
    rarity_status_box.LayoutOrder = 1
    rarity_status_box.Size = UDim2.new(1, 0, 0, 50)
    rarity_status_box.AutomaticSize = Enum.AutomaticSize.Y
    rarity_status_box.BackgroundColor3 = CARD_COLOR
    rarity_status_box.BorderSizePixel = 0
    rarity_status_box.Parent = rarity_content
    
    local rarity_status_box_pad = Instance.new("UIPadding")
    rarity_status_box_pad.PaddingBottom = UDim.new(0, 4)
    rarity_status_box_pad.PaddingRight = UDim.new(0, 10)
    rarity_status_box_pad.Parent = rarity_status_box
    
    local rarity_status_box_c = Instance.new("UICorner")
    rarity_status_box_c.CornerRadius = UDim.new(0, 6)
    rarity_status_box_c.Parent = rarity_status_box
    
    local rarity_status_box_stroke = Instance.new("UIStroke")
    rarity_status_box_stroke.Color = Color3.fromRGB(35, 35, 35)
    rarity_status_box_stroke.Thickness = 1
    rarity_status_box_stroke.Parent = rarity_status_box

    local rarity_status_title = Instance.new("TextLabel")
    rarity_status_title.Size = UDim2.new(1, -10, 0, 14)
    rarity_status_title.Position = UDim2.new(0, 10, 0, 4)
    rarity_status_title.BackgroundTransparency = 1
    rarity_status_title.Text = "Status"
    rarity_status_title.TextColor3 = ACCENT_COLOR
    rarity_status_title.TextSize = 9
    rarity_status_title.FontFace = font_bold
    rarity_status_title.TextXAlignment = Enum.TextXAlignment.Left
    rarity_status_title.Parent = rarity_status_box

    rarity_status_val_lbl = Instance.new("TextLabel")
    rarity_status_val_lbl.Size = UDim2.new(1, -20, 0, 24)
    rarity_status_val_lbl.Position = UDim2.new(0, 10, 0, 20)
    rarity_status_val_lbl.AutomaticSize = Enum.AutomaticSize.Y
    rarity_status_val_lbl.BackgroundTransparency = 1
    rarity_status_val_lbl.Text = "Idle"
    rarity_status_val_lbl.TextColor3 = TEXT_COLOR
    rarity_status_val_lbl.TextSize = 9
    rarity_status_val_lbl.FontFace = font_face
    rarity_status_val_lbl.TextXAlignment = Enum.TextXAlignment.Left
    rarity_status_val_lbl.TextYAlignment = Enum.TextYAlignment.Top
    rarity_status_val_lbl.TextWrapped = true
    rarity_status_val_lbl.Parent = rarity_status_box

    -- Select Rarity Dropdown Row
    local r_row = Instance.new("Frame")
    r_row.Name = "2_RarityRow"
    r_row.LayoutOrder = 2
    r_row.Size = UDim2.new(1, 0, 0, 22)
    r_row.BackgroundTransparency = 1
    r_row.Active = false
    r_row.Parent = rarity_content

    local r_lbl = Instance.new("TextLabel")
    r_lbl.Size = UDim2.new(0.45, 0, 1, 0)
    r_lbl.BackgroundTransparency = 1
    r_lbl.Text = "Select Rarity"
    r_lbl.TextColor3 = TEXT_COLOR
    r_lbl.TextSize = 9
    r_lbl.FontFace = font_bold
    r_lbl.TextXAlignment = Enum.TextXAlignment.Left
    r_lbl.Parent = r_row

    rarity_dropdown_btn = Instance.new("TextButton")
    rarity_dropdown_btn.Size = UDim2.new(0.55, 0, 1, 0)
    rarity_dropdown_btn.Position = UDim2.new(0.45, 0, 0, 0)
    rarity_dropdown_btn.BackgroundColor3 = INPUT_BG_COLOR
    
    local function get_rarity_dropdown_text()
        if not config.selected_tiers or #config.selected_tiers == 0 then
            return "Select Option"
        elseif #config.selected_tiers == 1 then
            return tostring(config.selected_tiers[1])
        else
            return tostring(#config.selected_tiers) .. " selected"
        end
    end
    
    rarity_dropdown_btn.Text = get_rarity_dropdown_text()
    rarity_dropdown_btn.TextColor3 = TEXT_COLOR
    rarity_dropdown_btn.TextSize = 9
    rarity_dropdown_btn.FontFace = font_face
    rarity_dropdown_btn.TextXAlignment = Enum.TextXAlignment.Left
    rarity_dropdown_btn.Active = true
    rarity_dropdown_btn.Parent = r_row

    local rarity_dropdown_c = Instance.new("UICorner")
    rarity_dropdown_c.CornerRadius = UDim.new(0, 4)
    rarity_dropdown_c.Parent = rarity_dropdown_btn

    local rarity_dropdown_stroke = Instance.new("UIStroke")
    rarity_dropdown_stroke.Color = Color3.fromRGB(45, 45, 45)
    rarity_dropdown_stroke.Thickness = 1
    rarity_dropdown_stroke.Parent = rarity_dropdown_btn

    local rarity_dropdown_pad = Instance.new("UIPadding")
    rarity_dropdown_pad.PaddingLeft = UDim.new(0, 8)
    rarity_dropdown_pad.PaddingRight = UDim.new(0, 8)
    rarity_dropdown_pad.Parent = rarity_dropdown_btn

    local rarity_chevron = Instance.new("TextLabel")
    rarity_chevron.Size = UDim2.new(0, 20, 1, 0)
    rarity_chevron.Position = UDim2.new(1, -12, 0, 0)
    rarity_chevron.BackgroundTransparency = 1
    rarity_chevron.Text = "♦"
    rarity_chevron.TextColor3 = Color3.fromRGB(192, 0, 192)
    rarity_chevron.TextSize = 8
    rarity_chevron.FontFace = font_face
    rarity_chevron.TextXAlignment = Enum.TextXAlignment.Right
    rarity_chevron.Parent = rarity_dropdown_btn

    rarity_dropdown_btn.Activated:Connect(function()
        item_panel.Visible = false
        enchant_panel.Visible = false
        rarity_panel.Visible = not rarity_panel.Visible
        close_detector.Visible = rarity_panel.Visible
        if rarity_panel.Visible then
            populate_rarity_panel(rarity_dropdown_btn)
        end
    end)

    -- Amount Rarity Row (Textbox)
    local r_amount_row = Instance.new("Frame")
    r_amount_row.Name = "3_AmountRow"
    r_amount_row.LayoutOrder = 3
    r_amount_row.Size = UDim2.new(1, 0, 0, 22)
    r_amount_row.BackgroundTransparency = 1
    r_amount_row.Active = false
    r_amount_row.Parent = rarity_content

    local r_amount_lbl = Instance.new("TextLabel")
    r_amount_lbl.Size = UDim2.new(0.45, 0, 1, 0)
    r_amount_lbl.BackgroundTransparency = 1
    r_amount_lbl.Text = "Amount Fish Rarity"
    r_amount_lbl.TextColor3 = TEXT_COLOR
    r_amount_lbl.TextSize = 9
    r_amount_lbl.FontFace = font_bold
    r_amount_lbl.TextXAlignment = Enum.TextXAlignment.Left
    r_amount_lbl.Parent = r_amount_row

    r_qty_box = Instance.new("TextBox")
    r_qty_box.Size = UDim2.new(0.55, 0, 1, 0)
    r_qty_box.Position = UDim2.new(0.45, 0, 0, 0)
    r_qty_box.BackgroundColor3 = INPUT_BG_COLOR
    r_qty_box.Text = tostring(config.quantity)
    r_qty_box.TextColor3 = TEXT_COLOR
    r_qty_box.TextSize = 9
    r_qty_box.FontFace = font_face
    r_qty_box.TextXAlignment = Enum.TextXAlignment.Center
    r_qty_box.ClearTextOnFocus = false
    r_qty_box.Parent = r_amount_row

    local r_qty_c = Instance.new("UICorner")
    r_qty_c.CornerRadius = UDim.new(0, 4)
    r_qty_c.Parent = r_qty_box

    local r_qty_stroke = Instance.new("UIStroke")
    r_qty_stroke.Color = Color3.fromRGB(45, 45, 45)
    r_qty_stroke.Thickness = 1
    r_qty_stroke.Parent = r_qty_box

    r_qty_box.FocusLost:Connect(function()
        local text = r_qty_box.Text
        local val = (text == "") and 0 or (tonumber(text) or config.quantity)
        task.defer(function()
            sync_qty_boxes(val)
        end)
    end)

    -- Refresh Fish Rarity Button
    local r_refresh = Instance.new("TextButton")
    r_refresh.Name = "4_RefreshButton"
    r_refresh.LayoutOrder = 4
    r_refresh.Size = UDim2.new(1, 0, 0, 26)
    r_refresh.BackgroundColor3 = Color3.fromRGB(192, 0, 192)
    r_refresh.Text = "Refresh Fish Rarity"
    r_refresh.TextColor3 = Color3.fromRGB(255, 255, 255)
    r_refresh.TextSize = 9
    r_refresh.FontFace = font_bold
    r_refresh.Active = true
    r_refresh.Parent = rarity_content

    local r_refresh_c = Instance.new("UICorner")
    r_refresh_c.CornerRadius = UDim.new(0, 5)
    r_refresh_c.Parent = r_refresh

    r_refresh.MouseEnter:Connect(function()
        r_refresh.BackgroundColor3 = Color3.fromRGB(240, 50, 240)
    end)
    r_refresh.MouseLeave:Connect(function()
        r_refresh.BackgroundColor3 = Color3.fromRGB(192, 0, 192)
    end)

    r_refresh.MouseButton1Click:Connect(function()
        r_refresh.Text = "Rarity Fish Refreshed!"
        task_wait(1)
        r_refresh.Text = "Refresh Fish Rarity"
    end)

    -- Toggle Row for Trade By Rarity
    rarity_toggle_ctrl = create_toggle(rarity_content, "Start Trade ByRarity", (config.enabled and config.trade_rarity_enabled), function(active)
        if active then
            cache.stats.rarity.success_trades = 0
            cache.stats.rarity.last_items = 0
            cache.stats.rarity.total_items = 0
            cache.stats.rarity.attempts = 0
            cache.stats.rarity.failed = 0
            update_mode_status("rarity")

            config.trade_rarity_enabled = true
            config.enabled = true
            sync_mode_toggles("rarity")
            cache.processed_trades = {}
            run_auto_trade_loop()
        else
            config.enabled = false
            decline_active_trade()
        end
    end)
    rarity_toggle_ctrl.Frame.LayoutOrder = 5
    rarity_toggle_ctrl.Frame.Name = "5_StartTradeToggle"

    rarity_fav_toggle = create_toggle(rarity_content, "Trade Favorite Items", config.trade_favorited, function(active)
        sync_fav_toggles(active)
    end)
    rarity_fav_toggle.Frame.LayoutOrder = 6
    rarity_fav_toggle.Frame.Name = "6_FavToggle"

    -- 4. Trade By Coin
    local coin_content, coin_toggle = create_accordion(settings_panel, "Trade By Coin")
    -- Status Box
    local coin_status_box = Instance.new("Frame")
    coin_status_box.Name = "1_StatusBox"
    coin_status_box.LayoutOrder = 1
    coin_status_box.Size = UDim2.new(1, 0, 0, 50)
    coin_status_box.AutomaticSize = Enum.AutomaticSize.Y
    coin_status_box.BackgroundColor3 = CARD_COLOR
    coin_status_box.BorderSizePixel = 0
    coin_status_box.Parent = coin_content
    
    local coin_status_box_pad = Instance.new("UIPadding")
    coin_status_box_pad.PaddingBottom = UDim.new(0, 4)
    coin_status_box_pad.PaddingRight = UDim.new(0, 10)
    coin_status_box_pad.Parent = coin_status_box
    
    local coin_status_box_c = Instance.new("UICorner")
    coin_status_box_c.CornerRadius = UDim.new(0, 6)
    coin_status_box_c.Parent = coin_status_box
    
    local coin_status_box_stroke = Instance.new("UIStroke")
    coin_status_box_stroke.Color = Color3.fromRGB(35, 35, 35)
    coin_status_box_stroke.Thickness = 1
    coin_status_box_stroke.Parent = coin_status_box

    local coin_status_title = Instance.new("TextLabel")
    coin_status_title.Size = UDim2.new(1, -10, 0, 14)
    coin_status_title.Position = UDim2.new(0, 10, 0, 4)
    coin_status_title.BackgroundTransparency = 1
    coin_status_title.Text = "Status"
    coin_status_title.TextColor3 = ACCENT_COLOR
    coin_status_title.TextSize = 9
    coin_status_title.FontFace = font_bold
    coin_status_title.TextXAlignment = Enum.TextXAlignment.Left
    coin_status_title.Parent = coin_status_box

    coin_status_val_lbl = Instance.new("TextLabel")
    coin_status_val_lbl.Size = UDim2.new(1, -20, 0, 24)
    coin_status_val_lbl.Position = UDim2.new(0, 10, 0, 20)
    coin_status_val_lbl.AutomaticSize = Enum.AutomaticSize.Y
    coin_status_val_lbl.BackgroundTransparency = 1
    coin_status_val_lbl.Text = "Idle"
    coin_status_val_lbl.TextColor3 = TEXT_COLOR
    coin_status_val_lbl.TextSize = 9
    coin_status_val_lbl.FontFace = font_face
    coin_status_val_lbl.TextXAlignment = Enum.TextXAlignment.Left
    coin_status_val_lbl.TextYAlignment = Enum.TextYAlignment.Top
    coin_status_val_lbl.TextWrapped = true
    coin_status_val_lbl.Parent = coin_status_box

    -- Target Coins Row
    local coin_row = Instance.new("Frame")
    coin_row.Name = "2_CoinRow"
    coin_row.LayoutOrder = 2
    coin_row.Size = UDim2.new(1, 0, 0, 22)
    coin_row.BackgroundTransparency = 1
    coin_row.Active = false
    coin_row.Parent = coin_content

    local coin_lbl = Instance.new("TextLabel")
    coin_lbl.Size = UDim2.new(0.45, 0, 1, 0)
    coin_lbl.BackgroundTransparency = 1
    coin_lbl.Text = "Target Coins"
    coin_lbl.TextColor3 = TEXT_COLOR
    coin_lbl.TextSize = 9
    coin_lbl.FontFace = font_bold
    coin_lbl.TextXAlignment = Enum.TextXAlignment.Left
    coin_lbl.Parent = coin_row

    local coin_box = Instance.new("TextBox")
    coin_box.Size = UDim2.new(0.55, 0, 1, 0)
    coin_box.Position = UDim2.new(0.45, 0, 0, 0)
    coin_box.BackgroundColor3 = INPUT_BG_COLOR
    coin_box.Text = tostring(config.target_coin_amount)
    coin_box.TextColor3 = TEXT_COLOR
    coin_box.TextSize = 9
    coin_box.FontFace = font_face
    coin_box.TextXAlignment = Enum.TextXAlignment.Center
    coin_box.ClearTextOnFocus = false
    coin_box.Parent = coin_row

    local coin_box_c = Instance.new("UICorner")
    coin_box_c.CornerRadius = UDim.new(0, 4)
    coin_box_c.Parent = coin_box

    local coin_box_stroke = Instance.new("UIStroke")
    coin_box_stroke.Color = Color3.fromRGB(45, 45, 45)
    coin_box_stroke.Thickness = 1
    coin_box_stroke.Parent = coin_box

    coin_box.FocusLost:Connect(function()
        local text = coin_box.Text
        local val = (text == "") and 0 or (tonumber(text) or config.target_coin_amount)
        config.target_coin_amount = val
        config.trade_coins_enabled = val > 0
        save_config()
        task.defer(function()
            coin_box.Text = tostring(val)
        end)
    end)

    coin_toggle_ctrl = create_toggle(coin_content, "Start Trade ByCoin", (config.enabled and config.trade_coins_enabled), function(active)
        if active then
            cache.stats.coin.success_trades = 0
            cache.stats.coin.last_items = 0
            cache.stats.coin.total_items = 0
            cache.stats.coin.attempts = 0
            cache.stats.coin.failed = 0
            update_mode_status("coin")

            config.trade_coins_enabled = true
            config.enabled = true
            sync_mode_toggles("coin")
            cache.processed_trades = {}
            run_auto_trade_loop()
        else
            config.enabled = false
            decline_active_trade()
        end
    end)
    coin_toggle_ctrl.Frame.LayoutOrder = 3
    coin_toggle_ctrl.Frame.Name = "3_StartTradeToggle"

    coin_fav_toggle = create_toggle(coin_content, "Trade Favorite Items", config.trade_favorited, function(active)
        sync_fav_toggles(active)
    end)
    coin_fav_toggle.Frame.LayoutOrder = 4
    coin_fav_toggle.Frame.Name = "4_FavToggle"

    -- Reset Stats By Coin Button
    local coin_reset = Instance.new("TextButton")
    coin_reset.Name = "5_ResetStatsButton"
    coin_reset.LayoutOrder = 5
    coin_reset.Size = UDim2.new(1, 0, 0, 26)
    coin_reset.BackgroundColor3 = Color3.fromRGB(192, 0, 192)
    coin_reset.Text = "Reset Stats By Coin"
    coin_reset.TextColor3 = Color3.fromRGB(255, 255, 255)
    coin_reset.TextSize = 9
    coin_reset.FontFace = font_bold
    coin_reset.Active = true
    coin_reset.Parent = coin_content

    local coin_reset_c = Instance.new("UICorner")
    coin_reset_c.CornerRadius = UDim.new(0, 5)
    coin_reset_c.Parent = coin_reset

    coin_reset.MouseEnter:Connect(function()
        coin_reset.BackgroundColor3 = Color3.fromRGB(240, 50, 240)
    end)
    coin_reset.MouseLeave:Connect(function()
        coin_reset.BackgroundColor3 = Color3.fromRGB(192, 0, 192)
    end)

    coin_reset.Activated:Connect(function()
        coin_reset.Text = "Stats Reset!"
        cache.processed_trades = {}
        task_wait(1)
        coin_reset.Text = "Reset Stats By Coin"
    end)

    -- 5. Auto Accept Trade
    local accept_content, accept_toggle = create_accordion(settings_panel, "Auto Accept Trade")
    local accept_toggle_ctrl = create_toggle(accept_content, "Enable Auto Accept Trade", config.auto_accept_enabled, function(active)
        config.auto_accept_enabled = active
        toggle_auto_accept(active)
        save_config()
    end)



    -- Set layout canvas sizes initially
    settings_panel.CanvasSize = UDim2.new(0, 0, 0, settings_layout.AbsoluteContentSize.Y + 20)
    settings_layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        settings_panel.CanvasSize = UDim2.new(0, 0, 0, settings_layout.AbsoluteContentSize.Y + 20)
    end)

    ----------------------------------------------------
    -- STATS & CONTROLS SINK LOOP
    ----------------------------------------------------
    task_spawn(function()
        while gui.Parent do

            if sb_status then
                local active_text = "Idle"
                if config.enabled then
                    if config.trade_fish_enabled and cache.fish_status_text ~= "Idle" then
                        active_text = cache.fish_status_text
                    elseif config.trade_enchants_enabled and cache.enchant_status_text ~= "Idle" then
                        active_text = cache.enchant_status_text
                    elseif config.trade_coins_enabled and cache.coin_status_text ~= "Idle" then
                        active_text = cache.coin_status_text
                    elseif config.trade_rarity_enabled and cache.rarity_status_text ~= "Idle" then
                        active_text = cache.rarity_status_text
                    else
                        active_text = "Active"
                    end
                end
                sb_status.Text = "Status:\n" .. active_text
            end
            
            if status_val_lbl then
                if cache.fish_status_details == "" then
                    status_val_lbl.Text = cache.fish_status_text
                else
                    status_val_lbl.Text = cache.fish_status_text .. "\n" .. cache.fish_status_details
                end
            end
            if enchant_status_val_lbl then
                if cache.enchant_status_details == "" then
                    enchant_status_val_lbl.Text = cache.enchant_status_text
                else
                    enchant_status_val_lbl.Text = cache.enchant_status_text .. "\n" .. cache.enchant_status_details
                end
            end
            if coin_status_val_lbl then
                if cache.coin_status_details == "" then
                    coin_status_val_lbl.Text = cache.coin_status_text
                else
                    coin_status_val_lbl.Text = cache.coin_status_text .. "\n" .. cache.coin_status_details
                end
            end
            if rarity_status_val_lbl then
                if cache.rarity_status_details == "" then
                    rarity_status_val_lbl.Text = cache.rarity_status_text
                else
                    rarity_status_val_lbl.Text = cache.rarity_status_text .. "\n" .. cache.rarity_status_details
                end
            end

            if byname_toggle_ctrl then
                byname_toggle_ctrl.set_state(config.enabled and config.trade_fish_enabled)
            end
            if enchant_toggle_ctrl then
                enchant_toggle_ctrl.set_state(config.enabled and config.trade_enchants_enabled)
            end
            if coin_toggle_ctrl then
                coin_toggle_ctrl.set_state(config.enabled and config.trade_coins_enabled)
            end
            if rarity_toggle_ctrl then
                rarity_toggle_ctrl.set_state(config.enabled and config.trade_rarity_enabled)
            end
            if accept_toggle_ctrl then
                accept_toggle_ctrl.set_state(config.auto_accept_enabled)
            end

            task_wait(1)
        end
    end)
end

-- Run initialization
local success, err = pcall(create_ui)
if not success then
    warn("UI Creation Error: " .. tostring(err))
    print("UI Creation Error: " .. tostring(err))
end
pcall(log_inventory_fish)

-- Dismiss any active/leftover trade prompts on startup to clean screen
pcall(function()
    local prompt_gui = local_player.PlayerGui:FindFirstChild("Prompt")
    local blackout = prompt_gui and prompt_gui:FindFirstChild("Blackout")
    local options = blackout and blackout:FindFirstChild("Options")
    local no_btn = options and options:FindFirstChild("No")
    
    -- Check if it's a trade prompt
    local is_trade = false
    if prompt_gui and blackout and blackout.Visible then
        for _, child in ipairs(prompt_gui:GetDescendants()) do
            if child:IsA("TextLabel") then
                local text = child.Text:lower()
                if text:find("trade") or text:find("accept") then
                    is_trade = true
                    break
                end
            end
        end
    end
    if no_btn and is_trade then
        click_gui_button(no_btn)
        print("Noir Debug: Dismissed leftover trade prompt on startup.")
    end
end)

pcall(function()
    toggle_auto_accept(config.auto_accept_enabled)
end)

_G.NoirHub_AutoTrade_Cleanup = function()
    -- Disconnect global event connections
    if auto_accept_conn then pcall(function() auto_accept_conn:Disconnect() end) end
    if trade_started_conn then pcall(function() trade_started_conn:Disconnect() end) end
    if trade_ended_conn then pcall(function() trade_ended_conn:Disconnect() end) end
    
    -- Terminate active auto trade loops
    _G.NoirHub_AutoTrade_ScriptID = nil
    
    -- Destroy old GUI in CoreGui/gethui and PlayerGui
    pcall(function()
        local core = gethui and gethui() or game:GetService("CoreGui")
        local old = core:FindFirstChild("NoirHub_AutoTrade") or core:FindFirstChild("AutoTrade")
        if old then old:Destroy() end
    end)
    pcall(function()
        local pgui = local_player:FindFirstChild("PlayerGui")
        local old = pgui and (pgui:FindFirstChild("NoirHub_AutoTrade") or pgui:FindFirstChild("AutoTrade"))
        if old then old:Destroy() end
    end)
end

print("AutoTrade UI and engine initialized successfully!")
