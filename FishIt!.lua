-- Keenan Trade Script
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
local math_huge     = math.huge

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

if _G.KeenanHub_AutoTrade_Cleanup then
    pcall(_G.KeenanHub_AutoTrade_Cleanup)
end
if _G.NoirHub_AutoTrade_Cleanup then
    pcall(_G.NoirHub_AutoTrade_Cleanup)
end

local is_running = true
local script_id = os_clock()
_G.KeenanHub_AutoTrade_ScriptID = script_id

local script_connections = {}
local function track_conn(conn)
    if conn then
        table_insert(script_connections, conn)
    end
    return conn
end

local cloneref = cloneref or function(ref) return ref end

local players               = cloneref(game:GetService("Players"))
local local_player          = players.LocalPlayer
local player_gui            = cloneref(local_player:WaitForChild("PlayerGui"))
local user_input_service    = cloneref(game:GetService("UserInputService"))
local tween_service         = cloneref(game:GetService("TweenService"))
local replicated_storage    = cloneref(game:GetService("ReplicatedStorage"))
local http_service          = cloneref(game:GetService("HttpService"))
local text_chat_service     = pcall(function() return cloneref(game:GetService("TextChatService")) end) and cloneref(game:GetService("TextChatService")) or nil
local core_gui              = pcall(function() return cloneref(game:GetService("CoreGui")) end) and cloneref(game:GetService("CoreGui")) or nil

local variables = {
    items                   = replicated_storage:WaitForChild("Items"),
    variants                = replicated_storage:WaitForChild("Variants"),
    replion                 = replicated_storage:WaitForChild("Packages"):WaitForChild("Replion"),
    item_utility            = replicated_storage:WaitForChild("Shared"):WaitForChild("ItemUtility")
}

local success_replion, replion_mod = pcall(require, variables.replion)
local player_data = success_replion and replion_mod.Client:WaitReplion("Data") or nil
local success_iu, item_utility = pcall(require, variables.item_utility)
if not success_iu or not item_utility then
    item_utility = {
        GetItemData = function(_, id) return nil end
    }
end

-- Remotes
local remote_map = {
    SendTradeOffer     = "SendTradeOffer",
    AddItem            = "AddItem",
    SetReady           = "SetReady",
    ConfirmTrade       = "ConfirmTrade",
    TradeEnded         = "TradeEnded",
}

local _net_lookup = nil
local function get_net_lookup()
    if _net_lookup then return _net_lookup end
    _net_lookup = {}

    pcall(function()
        local net_folder = nil
        local index = replicated_storage.Packages:FindFirstChild("_Index")
        if index then
            for _, child in ipairs(index:GetChildren()) do
                if string_find(child.Name, "sleitnick_net", 1, true) then
                    net_folder = child:FindFirstChild("net")
                    if net_folder then break end
                end
            end
        end
        if not net_folder and replicated_storage.Packages:FindFirstChild("_Index") and replicated_storage.Packages._Index:FindFirstChild("sleitnick_net@0.2.0") then
            net_folder = replicated_storage.Packages._Index["sleitnick_net@0.2.0"]:FindFirstChild("net")
        end

        if net_folder then
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
        end
    end)

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

-- Config & State
local config = {
    enabled             = false,
    trade_favorited     = false,
    quantity            = 0,
    trade_with          = "",

    trade_fish_enabled  = false,
    trade_enchants_enabled = false,
    trade_rarity_enabled = false,
    trade_coin_enabled  = false,
    trade_coin_target   = 8000000,

    selected_fish       = {},
    selected_tiers      = { "All" },
    selected_mutations  = { "All" },
    selected_items      = {},
}

local cache = {
    processed_trades    = {},
    loaded_fish         = {},
    loaded_mutations    = {},
    loaded_enchants     = {},
    loaded_tiers        = {},
    loaded_variant_multipliers = {},
    is_trading_active   = false,
    loop_running        = false,
    last_trade_time     = nil,
    fish_status_text    = "Idle",
    fish_status_details = "",
    enchant_status_text = "Idle",
    enchant_status_details = "",
    rarity_status_text  = "Idle",
    rarity_status_details = "",
    coin_status_text    = "Idle",
    coin_status_details = "",
    stats = {
        fish = { success_trades = 0, attempts = 0, failed = 0, last_items = 0, total_items = 0 },
        rarity = { success_trades = 0, attempts = 0, failed = 0, last_items = 0, total_items = 0 },
        enchant = { success_trades = 0, attempts = 0, failed = 0, last_items = 0, total_items = 0 },
        coin = { success_trades = 0, attempts = 0, failed = 0, last_items = 0, total_items = 0, total_coins = 0, target_coins = 0 }
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
            temp_config.trade_rarity_enabled = false
            temp_config.trade_coin_enabled = false

            local data = http_service:JSONEncode(temp_config)
            writefile("Keenan_AutoTrade_Config.json", data)
        end
    end)
end

local function load_config()
    pcall(function()
        if isfile and readfile and http_service then
            local filename = "Keenan_AutoTrade_Config.json"
            if not isfile(filename) and isfile("NoirHub_AutoTrade_Config.json") then
                filename = "NoirHub_AutoTrade_Config.json"
            end
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

local active_modes = 0
if config.trade_fish_enabled then active_modes = active_modes + 1 end
if config.trade_enchants_enabled then active_modes = active_modes + 1 end
if config.trade_rarity_enabled then active_modes = active_modes + 1 end
if config.trade_coin_enabled then active_modes = active_modes + 1 end

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
    if config.trade_coin_enabled then
        if found then config.trade_coin_enabled = false end
    end
    save_config()
end

-- Helpers
local function click_gui_button(btn)
    if not btn then return end
    pcall(function()
        if firesignal then
            firesignal(btn.MouseButton1Click)
            firesignal(btn.Activated)
        elseif getconnections then
            for _, conn in ipairs(getconnections(btn.MouseButton1Click)) do
                conn:Fire()
            end
        end
    end)
end

local function get_inventory_enchants(bypass_favorited)
    local enchants = {}
    local success, err = pcall(function()
        if player_data then
            local inventory = player_data:Get("Inventory")
            local items = inventory and inventory.Items or {}
            for _, item in ipairs(items) do
                if item.Id then
                    local is_fav = (item.Favorited == true or (item.Metadata and item.Metadata.Favorited == true))
                    local include_item = true
                    if not bypass_favorited and is_fav and not config.trade_favorited then
                        include_item = false
                    end

                    if include_item then
                        local data = item_utility:GetItemData(item.Id)
                        if data and data.Data then
                            local name = data.Data.Name
                            local is_enchant = (data.Data.Type == "Enchant Stones") or string_find(name, "Enchant", 1, true)
                            if is_enchant then
                                enchants[name] = (enchants[name] or 0) + (item.Amount or 1)
                            end
                        end
                    end
                end
            end
        end
    end)
    return enchants
end

local function strip_quantity(str)
    return string_gsub(str, "%s*%(x%d+%)", "")
end

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

-- Filters
local tier_mapping = {
    [1] = "common",
    [2] = "uncommon",
    [3] = "rare",
    [4] = "epic",
    [5] = "legendary",
    [6] = "mythic",
    [7] = "secret",
    [8] = "forgotten",
    [90] = "trophy",
    [95] = "collectible",
    [100] = "exclusive",
    [1000] = "dev"
}

local function load_game_data()
    cache.loaded_tiers = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "SECRET", "Forgotten" }
    cache.loaded_variant_multipliers = {}

    local tiers_mod = replicated_storage:FindFirstChild("Tiers")
    if tiers_mod and tiers_mod:IsA("ModuleScript") then
        local success, tiers_data = pcall(require, tiers_mod)
        if success and type(tiers_data) == "table" then
            for tier_num, info in pairs(tiers_data) do
                if type(info) == "table" and info.Name then
                    tier_mapping[tier_num] = string_lower(info.Name)
                end
            end
        end
    end

    if variables.variants then
        for _, variant in ipairs(variables.variants:GetChildren()) do
            if variant:IsA("ModuleScript") then
                local success, data = pcall(require, variant)
                if success and type(data) == "table" then
                    local mult = tonumber(data.SellMultiplier or (data.Data and data.Data.SellMultiplier)) or 1
                    local name = (data.Data and data.Data.Name) or variant.Name
                    if name then
                        table_insert(cache.loaded_mutations, name)
                        cache.loaded_variant_multipliers[string_lower(name)] = mult
                        cache.loaded_variant_multipliers[name] = mult
                    end
                    if data.Data and data.Data.Id then
                        cache.loaded_variant_multipliers[data.Data.Id] = mult
                    end
                end
            end
        end
    end
    if not table_find(cache.loaded_mutations, "Shiny") then
        table_insert(cache.loaded_mutations, "Shiny")
    end
    if not cache.loaded_variant_multipliers["shiny"] then
        cache.loaded_variant_multipliers["shiny"] = 1.5
    end
    table_sort(cache.loaded_mutations)

    if variables.items then
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
end
pcall(load_game_data)

-- Player Target
local function find_target_player()
    if config.trade_with == "" then return nil end
    for _, player in ipairs(players:GetPlayers()) do
        if player.Name == config.trade_with or player.DisplayName == config.trade_with then
            return player
        end
    end
    return nil
end

local function get_item_mutation(item)
    if not item then return "None" end
    local meta = item.Metadata
    if meta then
        if meta.VariantId and meta.VariantId ~= "" and meta.VariantId ~= "None" then
            return tostring(meta.VariantId)
        end
        if meta.Mutation and meta.Mutation ~= "" and meta.Mutation ~= "None" then
            return tostring(meta.Mutation)
        end
        if meta.Variant and meta.Variant ~= "" and meta.Variant ~= "None" then
            return tostring(meta.Variant)
        end
    end
    if item.Mutation and item.Mutation ~= "" and item.Mutation ~= "None" then
        return tostring(item.Mutation)
    end
    if item.Variant and item.Variant ~= "" and item.Variant ~= "None" then
        return tostring(item.Variant)
    end
    return "None"
end

local function is_item_shiny(item)
    if not item then return false end
    local meta = item.Metadata
    if meta then
        if meta.Shiny == true or meta.Shiny == 1 or (type(meta.Shiny) == "string" and string_lower(meta.Shiny) == "true") then return true end
    end
    if item.Shiny == true or item.Shiny == 1 or (type(item.Shiny) == "string" and string_lower(item.Shiny) == "true") then return true end
    local mut = string_lower(get_item_mutation(item))
    return string_find(mut, "shiny") ~= nil
end

local function is_item_big(item)
    if not item then return false end
    local meta = item.Metadata
    if meta then
        if meta.Big == true or meta.Big == 1 or meta.Giant == true or meta.Giant == 1 then return true end
        if type(meta.Big) == "string" and string_lower(meta.Big) == "true" then return true end
    end
    if item.Big == true or item.Big == 1 or item.Giant == true or item.Giant == 1 then return true end
    if type(item.Big) == "string" and string_lower(item.Big) == "true" then return true end
    local mut = string_lower(get_item_mutation(item))
    return string_find(mut, "big") ~= nil or string_find(mut, "giant") ~= nil
end

local function calculate_fish_coin_value(item)
    if not item or not item.Id then return 0 end
    local item_info = item_utility:GetItemData(item.Id)
    if not item_info or not item_info.Data or item_info.Data.Type ~= "Fish" then
        return 0
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
            local vmult = cache.loaded_variant_multipliers[string_lower(vname)] or cache.loaded_variant_multipliers[vname]
            if vmult then
                mult = mult * vmult
            end
        end
        if is_item_shiny(item) then
            if not meta.VariantId or string_lower(tostring(meta.VariantId)) ~= "shiny" then
                mult = mult * (cache.loaded_variant_multipliers["shiny"] or 1.5)
            end
        end
        if is_item_big(item) then
            mult = mult * 1.5
        end
    end

    return math_floor(base_price * mult)
end

local function select_fish_for_coin_trade(target_coins, already_sent_coins)
    if not player_data then return {}, 0 end
    local remaining_deficit = target_coins - already_sent_coins
    if remaining_deficit <= 0 then return {}, 0 end

    local inventory = player_data:Get("Inventory")
    local items = inventory and inventory.Items or {}

    local candidate_pool = {}
    for _, itm in ipairs(items) do
        if itm and itm.Id and not table_find(cache.processed_trades, itm.UUID) then
            local is_fav = (itm.Favorited == true or (itm.Metadata and itm.Metadata.Favorited == true))
            if not is_fav then
                local val = calculate_fish_coin_value(itm)
                if val > 0 then
                    table_insert(candidate_pool, {
                        item = itm,
                        value = val
                    })
                end
            end
        end
    end

    if #candidate_pool == 0 then return {}, 0 end

    table_sort(candidate_pool, function(a, b) return a.value > b.value end)

    local chosen = {}
    local current_sum = 0
    local used_indices = {}

    for i, entry in ipairs(candidate_pool) do
        if #chosen >= 20 then break end
        if current_sum + entry.value <= remaining_deficit then
            table_insert(chosen, entry.item)
            current_sum = current_sum + entry.value
            used_indices[i] = true
            if current_sum == remaining_deficit then break end
        end
    end

    if current_sum < remaining_deficit and #chosen < 20 then
        local deficit_left = remaining_deficit - current_sum
        local best_single_idx = nil
        local best_single_val = math_huge

        for i, entry in ipairs(candidate_pool) do
            if not used_indices[i] then
                if entry.value >= deficit_left and entry.value < best_single_val then
                    best_single_val = entry.value
                    best_single_idx = i
                end
            end
        end

        if best_single_idx then
            table_insert(chosen, candidate_pool[best_single_idx].item)
            current_sum = current_sum + candidate_pool[best_single_idx].value
            used_indices[best_single_idx] = true
        else
            local remaining_small = {}
            for i, entry in ipairs(candidate_pool) do
                if not used_indices[i] then
                    table_insert(remaining_small, { idx = i, entry = entry })
                end
            end
            table_sort(remaining_small, function(a, b) return a.entry.value < b.entry.value end)

            for _, s_entry in ipairs(remaining_small) do
                if #chosen >= 20 then break end
                table_insert(chosen, s_entry.entry.item)
                current_sum = current_sum + s_entry.entry.value
                used_indices[s_entry.idx] = true
                if current_sum >= remaining_deficit then break end
            end
        end
    end

    return chosen, current_sum
end

local function should_trade_fish(item_data, inventory_item)
    if not config.enabled then return false end

    local name_match = false
    local mutation_match = false

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

    local has_all_mutation = table_find(config.selected_mutations, "All") ~= nil
    if #config.selected_mutations == 0 or has_all_mutation then
        mutation_match = true
    else
        local mutation_name = get_item_mutation(inventory_item)
        if mutation_name and mutation_name ~= "None" then
            for _, selected_mutation in ipairs(config.selected_mutations) do
                if string_lower(mutation_name) == string_lower(selected_mutation) then
                    mutation_match = true
                    break
                end
            end
        end
    end

    local should_trade = name_match and mutation_match

    local is_fav = (inventory_item.Favorited == true or (inventory_item.Metadata and inventory_item.Metadata.Favorited == true))
    if is_fav and not config.trade_favorited then
        should_trade = false
    end

    return should_trade
end

local function should_trade_fish_by_rarity(item_data, inventory_item)
    if not config.enabled then return false end

    local rarity_match = false
    local mutation_match = false

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

    local has_all_mutation = table_find(config.selected_mutations, "All") ~= nil
    if #config.selected_mutations == 0 or has_all_mutation then
        mutation_match = true
    else
        local mutation_name = get_item_mutation(inventory_item)
        if mutation_name and mutation_name ~= "None" then
            for _, selected_mutation in ipairs(config.selected_mutations) do
                if string_lower(mutation_name) == string_lower(selected_mutation) then
                    mutation_match = true
                    break
                end
            end
        end
    end

    local should_trade = rarity_match and mutation_match

    local is_fav = (inventory_item.Favorited == true or (inventory_item.Metadata and inventory_item.Metadata.Favorited == true))
    if is_fav and not config.trade_favorited then
        should_trade = false
    end

    return should_trade
end

-- Round Robin Selection
local function collect_round_robin_rarity(player_data_items, selected_tiers, limit)
    local buckets = {}
    local bucket_keys = {}

    for _, tier in ipairs(selected_tiers) do
        local t_lower = string_lower(tier)
        if t_lower ~= "all" then
            buckets[t_lower] = {}
            table_insert(bucket_keys, t_lower)
        end
    end

    for _, fish_item in ipairs(player_data_items) do
        if fish_item and fish_item.Id then
            local fish_data = item_utility:GetItemData(fish_item.Id)
            if fish_data and fish_data.Data and fish_data.Data.Type == "Fish" then
                if should_trade_fish_by_rarity(fish_data, fish_item) then
                    local raw_tier = fish_data.Data.Tier
                    local tier_name = ""
                    if type(raw_tier) == "number" then
                        tier_name = tier_mapping[raw_tier] or ""
                    elseif type(raw_tier) == "string" then
                        tier_name = string_lower(raw_tier)
                    end
                    if buckets[tier_name] then
                        table_insert(buckets[tier_name], fish_item)
                    end
                end
            end
        end
    end

    local items_to_trade = {}
    local added_uuids = {}
    local max_pass = 20

    for pass = 1, max_pass do
        if #items_to_trade >= limit then break end
        local added_any = false

        for _, key in ipairs(bucket_keys) do
            if #items_to_trade >= limit then break end
            local bucket = buckets[key]
            if bucket then
                for i = 1, #bucket do
                    local item = bucket[i]
                    if not added_uuids[item.UUID] and not table_find(cache.processed_trades, item.UUID) then
                        added_uuids[item.UUID] = true
                        table_insert(items_to_trade, item)
                        added_any = true
                        break
                    end
                end
            end
        end

        if not added_any then break end
    end

    return items_to_trade
end

local function collect_round_robin_names(player_data_items, selected_fish, limit)
    local buckets = {}
    local bucket_keys = {}

    for _, f_name in ipairs(selected_fish) do
        local n_lower = string_lower(f_name)
        if n_lower ~= "all" then
            buckets[n_lower] = {}
            table_insert(bucket_keys, n_lower)
        end
    end

    for _, fish_item in ipairs(player_data_items) do
        if fish_item and fish_item.Id then
            local fish_data = item_utility:GetItemData(fish_item.Id)
            if fish_data and fish_data.Data and fish_data.Data.Type == "Fish" then
                if should_trade_fish(fish_data, fish_item) then
                    local name_lower = string_lower(fish_data.Data.Name)
                    if buckets[name_lower] then
                        table_insert(buckets[name_lower], fish_item)
                    end
                end
            end
        end
    end

    local items_to_trade = {}
    local added_uuids = {}
    local max_pass = 20

    for pass = 1, max_pass do
        if #items_to_trade >= limit then break end
        local added_any = false

        for _, key in ipairs(bucket_keys) do
            if #items_to_trade >= limit then break end
            local bucket = buckets[key]
            if bucket then
                for i = 1, #bucket do
                    local item = bucket[i]
                    if not added_uuids[item.UUID] and not table_find(cache.processed_trades, item.UUID) then
                        added_uuids[item.UUID] = true
                        table_insert(items_to_trade, item)
                        added_any = true
                        break
                    end
                end
            end
        end

        if not added_any then break end
    end

    return items_to_trade
end

-- Trade Handlers
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

local function is_trade_active()
    local attr = local_player:GetAttribute("IsTrading")
    if attr == true then return true end
    local pgui = local_player:FindFirstChild("PlayerGui")
    if pgui then
        for _, name in ipairs({"! Trading", "Trading", "Trade"}) do
            local t_gui = pgui:FindFirstChild(name)
            if t_gui and t_gui.Enabled then return true end
        end
    end
    return false
end

local function verify_items_sent(added_items)
    if not player_data or not added_items or #added_items == 0 then
        return #added_items
    end
    local inventory = player_data:Get("Inventory")
    local current_items = inventory and inventory.Items or {}
    local current_uuids = {}
    for _, item in ipairs(current_items) do
        if item.UUID then
            current_uuids[item.UUID] = true
        end
    end
    local sent_count = 0
    for _, item in ipairs(added_items) do
        if not current_uuids[item.UUID] then
            sent_count = sent_count + 1
        end
    end
    return sent_count
end

local function listen_for_trade_completion(on_completed)
    local completed = false
    local connections = {}

    local function check_text(text)
        if not text or completed then return end
        local lower = string_lower(tostring(text))
        if (string_find(lower, "completed", 1, true) or string_find(lower, "complete", 1, true) or string_find(lower, "success", 1, true) or string_find(lower, "berhasil", 1, true)) and (string_find(lower, "trade", 1, true) or string_find(lower, "with", 1, true)) then
            completed = true
            if on_completed then
                pcall(on_completed)
            end
        end
    end

    pcall(function()
        if text_chat_service then
            local conn = text_chat_service.MessageReceived:Connect(function(msg)
                if msg then check_text(msg.Text) end
            end)
            table_insert(connections, conn)
        end
    end)

    pcall(function()
        if replicated_storage then
            local chat_events = replicated_storage:FindFirstChild("DefaultChatSystemChatEvents")
            if chat_events then
                local msg_event = chat_events:FindFirstChild("OnMessageDoneFiltering")
                if msg_event then
                    local conn = msg_event.OnClientEvent:Connect(function(data)
                        if data and data.Message then
                            check_text(data.Message)
                        end
                    end)
                    table_insert(connections, conn)
                end
            end
        end
    end)

    pcall(function()
        if trade_remotes and trade_remotes.TradeEnded then
            local conn = trade_remotes.TradeEnded.OnClientEvent:Connect(function()
                if not completed then
                    completed = true
                    if on_completed then
                        pcall(on_completed)
                    end
                end
            end)
            table_insert(connections, conn)
        end
    end)

    return {
        is_completed = function()
            return completed
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
            local names = {}
            for _, item in ipairs(config.selected_items) do
                table_insert(names, item)
            end
            if #names > 0 then return table_concat(names, "/") end
        end
        return "Enchant Stone"
    elseif mode_name == "fish" then
        if #config.selected_fish > 0 and config.selected_fish[1] ~= "All" then
            local names = {}
            for _, fish in ipairs(config.selected_fish) do
                table_insert(names, fish)
            end
            if #names > 0 then return table_concat(names, "/") end
        end
        return "Fish"
    elseif mode_name == "rarity" then
        if #config.selected_tiers > 0 and config.selected_tiers[1] ~= "All" then
            local names = {}
            for _, tier in ipairs(config.selected_tiers) do
                local t_name = (type(tier) == "number" and tier_mapping[tier]) or tostring(tier)
                if t_name and t_name ~= "" then
                    table_insert(names, (string_upper(string_sub(t_name, 1, 1)) .. string_sub(t_name, 2)))
                end
            end
            if #names > 0 then return table_concat(names, "/") end
        end
        return "Rarity"
    elseif mode_name == "coin" then
        return "Coin Value (" .. format_number(config.trade_coin_target or 8000000) .. ")"
    end
    return "Items"
end

local function set_status_msg(mode_name, msg, details_override)
    local s = cache.stats[mode_name]
    if not s then return end

    local target = config.quantity
    local progress_str = (target == 0) and (s.total_items .. "/∞") or (s.total_items .. "/" .. target)
    local details = details_override or string_format("Items Sent: %d | Progress: %s | Attempts: %d | Failed: %d", s.total_items, progress_str, s.attempts, s.failed)

    if mode_name == "fish" then
        if msg then cache.fish_status_text = msg end
        cache.fish_status_details = details
        if status_val_lbl then
            status_val_lbl.Text = cache.fish_status_details == "" and cache.fish_status_text or (cache.fish_status_text .. "\n" .. cache.fish_status_details)
        end
    elseif mode_name == "rarity" then
        if msg then cache.rarity_status_text = msg end
        cache.rarity_status_details = details
        if rarity_status_val_lbl then
            rarity_status_val_lbl.Text = cache.rarity_status_details == "" and cache.rarity_status_text or (cache.rarity_status_text .. "\n" .. cache.rarity_status_details)
        end
    elseif mode_name == "enchant" then
        if msg then cache.enchant_status_text = msg end
        cache.enchant_status_details = details
        if enchant_status_val_lbl then
            enchant_status_val_lbl.Text = cache.enchant_status_details == "" and cache.enchant_status_text or (cache.enchant_status_text .. "\n" .. cache.enchant_status_details)
        end
    elseif mode_name == "coin" then
        if msg then cache.coin_status_text = msg end
        local coin_target = config.trade_coin_target or 8000000
        local total_c = s.total_coins or 0
        local progress_pct = coin_target > 0 and string_format(" (%.1f%%)", (total_c / coin_target) * 100) or ""
        local c_details = details_override or string_format("Coins Sent: %s / %s%s | Fish Sent: %d | Trades: %d | Failed: %d", format_number(total_c), format_number(coin_target), progress_pct, s.total_items, s.success_trades, s.failed)
        cache.coin_status_details = c_details
        if coin_status_val_lbl then
            coin_status_val_lbl.Text = cache.coin_status_details == "" and cache.coin_status_text or (cache.coin_status_text .. "\n" .. cache.coin_status_details)
        end
    end
end

local function wait_for_trade_end(mode_name, chat_listener)
    local start_t = tick()
    while is_trade_active() and tick() - start_t < 90 do
        if chat_listener and chat_listener.is_completed() then
            break
        end

        local stage = "Waiting PlayersReady..."

        pcall(function()
            if trade_remotes then
                if trade_remotes.SetReady then pcall(function() trade_remotes.SetReady:InvokeServer(true) end) end
                if trade_remotes.ConfirmTrade then pcall(function() trade_remotes.ConfirmTrade:InvokeServer() end) end
            end
        end)

        pcall(function()
            local pgui = local_player:FindFirstChild("PlayerGui")
            if pgui then
                local t_gui = pgui:FindFirstChild("! Trading") or pgui:FindFirstChild("Trading") or pgui:FindFirstChild("Trade")
                if t_gui then
                    local frame = t_gui:FindFirstChild("Frame") or t_gui:FindFirstChild("Container") or t_gui:FindFirstChild("Main")
                    local interior = frame and (frame:FindFirstChild("Interior") or frame)
                    local buttons = interior and interior:FindFirstChild("Buttons")
                    if buttons then
                        for _, child in ipairs(buttons:GetChildren()) do
                            if child:IsA("GuiButton") and child.Name ~= "Decline" then
                                click_gui_button(child)
                            end
                        end
                    end

                    for _, btn_name in ipairs({"Accept", "Confirm", "Ready"}) do
                        local btn = t_gui:FindFirstChild(btn_name, true)
                        if btn and btn:IsA("GuiButton") then
                            click_gui_button(btn)
                        end
                    end
                end
            end
        end)

        pcall(function()
            local pgui = local_player:FindFirstChild("PlayerGui")
            if pgui then
                local t_gui = pgui:FindFirstChild("! Trading") or pgui:FindFirstChild("Trading") or pgui:FindFirstChild("Trade")
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
                        stage = "Waiting lock countdown (" .. seconds .. "s)..."
                    else
                        stage = "Accepting & Confirming trade..."
                    end
                end
            end
        end)

        if not (chat_listener and chat_listener.is_completed()) then
            set_status_msg(mode_name, stage)
        end
        task_wait(0.12)
    end
end

local function start_trade_session(target_player, mode)
    if not target_player or not trade_remotes then return false, "No remotes" end

    if not is_trade_active() then
        if cache.last_trade_time then
            local elapsed = tick() - cache.last_trade_time
            if elapsed < 5 then
                set_status_msg(mode, nil, "Cooldown (" .. string_format("%.1fs", 5 - elapsed) .. ")")
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
        while not is_trade_active() and tick() - start_time < 12 do
            task_wait(0.1)
        end

        if not is_trade_active() then
            cache.last_trade_time = tick()
            set_status_msg(mode, "Trade request timed out")
            return false, "Timeout"
        end

        pcall(function()
            local pgui = local_player:FindFirstChild("PlayerGui")
            if pgui then
                local t_gui = pgui:FindFirstChild("! Trading") or pgui:FindFirstChild("Trading") or pgui:FindFirstChild("Trade")
                if t_gui then
                    t_gui.Enabled = true
                    local container = t_gui:FindFirstChild("Frame") or t_gui:FindFirstChild("Container") or t_gui:FindFirstChild("Main")
                    if container then container.Visible = true end
                end
            end
        end)

        task_wait(0.5)
    end

    return true
end

local function update_mode_status(mode_name)
    local s = cache.stats[mode_name]
    if not s then return end

    local target = config.quantity
    local progress_str = (target == 0) and (s.total_items .. "/∞") or (s.total_items .. "/" .. target)
    local display_name = get_mode_display_name(mode_name)
    local text
    if target > 0 and s.total_items >= target then
        text = string_format("Completed! %d/%d items sent", s.total_items, target)
    elseif (s.attempts or 0) == 0 and (s.success_trades or 0) == 0 then
        text = string_format("Starting Trade: %s (%s)", display_name, progress_str)
    elseif (s.success_trades or 0) > 0 then
        text = string_format("Active: %s - %d items sent (%s)", display_name, s.total_items, progress_str)
    else
        text = string_format("Trading: %s (%s)", display_name, progress_str)
    end

    local details = string_format("Items Sent: %d | Progress: %s | Attempts: %d | Failed: %d", s.total_items, progress_str, s.attempts, s.failed)

    if mode_name == "fish" then
        cache.fish_status_text = text
        cache.fish_status_details = details
        if status_val_lbl then
            status_val_lbl.Text = cache.fish_status_details == "" and cache.fish_status_text or (cache.fish_status_text .. "\n" .. cache.fish_status_details)
        end
    elseif mode_name == "rarity" then
        cache.rarity_status_text = text
        cache.rarity_status_details = details
        if rarity_status_val_lbl then
            rarity_status_val_lbl.Text = cache.rarity_status_details == "" and cache.rarity_status_text or (cache.rarity_status_text .. "\n" .. cache.rarity_status_details)
        end
    elseif mode_name == "enchant" then
        cache.enchant_status_text = text
        cache.enchant_status_details = details
        if enchant_status_val_lbl then
            enchant_status_val_lbl.Text = cache.enchant_status_details == "" and cache.enchant_status_text or (cache.enchant_status_text .. "\n" .. cache.enchant_status_details)
        end
    elseif mode_name == "coin" then
        local coin_target = config.trade_coin_target or 8000000
        local total_c = s.total_coins or 0
        if coin_target > 0 and total_c >= coin_target then
            text = string_format("Target Reached! %s / %s Coins sent", format_number(total_c), format_number(coin_target))
        elseif (s.attempts or 0) == 0 and (s.success_trades or 0) == 0 then
            text = string_format("Starting Trade: %s Coins target", format_number(coin_target))
        elseif (s.success_trades or 0) > 0 then
            text = string_format("Active: %s Coins sent so far", format_number(total_c))
        else
            text = string_format("Trading towards %s Coins", format_number(coin_target))
        end

        local progress_pct = coin_target > 0 and string_format(" (%.1f%%)", (total_c / coin_target) * 100) or ""
        local c_details = string_format("Coins Sent: %s / %s%s | Fish Sent: %d | Trades: %d | Failed: %d", format_number(total_c), format_number(coin_target), progress_pct, s.total_items, s.success_trades, s.failed)

        cache.coin_status_text = text
        cache.coin_status_details = c_details
        if coin_status_val_lbl then
            coin_status_val_lbl.Text = cache.coin_status_details == "" and cache.coin_status_text or (cache.coin_status_text .. "\n" .. cache.coin_status_details)
        end
    end
end

-- Trade by Name
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
        config.trade_fish_enabled = false
        if byname_toggle_ctrl then
            byname_toggle_ctrl.set_state(false)
        end
        save_config()
        return
    end

    local inventory = player_data:Get("Inventory")
    local player_data_items = inventory and inventory.Items or {}

    local items_to_trade = {}
    local limit = math_min(20, config.quantity > 0 and (config.quantity - total_sent) or 20)

    local has_all_fish = table_find(config.selected_fish, "All") ~= nil
    if #config.selected_fish > 1 and not has_all_fish then
        items_to_trade = collect_round_robin_names(player_data_items, config.selected_fish, limit)
    else
        for _, fish_item in ipairs(player_data_items) do
            if #items_to_trade >= limit then break end
            if fish_item and fish_item.Id then
                local fish_data = item_utility:GetItemData(fish_item.Id)
                if fish_data and fish_data.Data and fish_data.Data.Type == "Fish" then
                    if should_trade_fish(fish_data, fish_item) then
                        if not table_find(cache.processed_trades, fish_item.UUID) then
                            table_insert(items_to_trade, fish_item)
                        end
                    end
                end
            end
        end
    end

    if #items_to_trade == 0 then
        local item_name = get_mode_display_name("fish")
        set_status_msg("fish", "Error: Tidak ada lagi " .. item_name .. " di inventory")
        config.enabled = false
        config.trade_fish_enabled = false
        if byname_toggle_ctrl then
            byname_toggle_ctrl.set_state(false)
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
        if not config.enabled or not is_trade_active() then break end

        local add_success = false
        for attempt = 1, 2 do
            local ok, res = pcall(function()
                return trade_remotes.AddItem:InvokeServer("Fish", item.UUID)
            end)
            if ok and res ~= false then
                add_success = true
                break
            end
            task_wait(0.04)
        end

        if add_success then
            table_insert(cache.processed_trades, item.UUID)
            table_insert(added_items, item)
        end
        task_wait(0.03)
    end

    if #added_items > 0 and is_trade_active() then
        local trade_success = false
        local function mark_success(count)
            if not trade_success then
                trade_success = true
                count = count or #added_items
                cache.stats.fish.success_trades = cache.stats.fish.success_trades + 1
                cache.stats.fish.last_items = count
                cache.stats.fish.total_items = cache.stats.fish.total_items + count
                update_mode_status("fish")
            end
        end

        local chat_listener = listen_for_trade_completion(function()
            mark_success()
        end)

        pcall(function()
            trade_remotes.SetReady:InvokeServer(true)
        end)

        wait_for_trade_end("fish", chat_listener)
        task_wait(0.6)

        local sent_count = verify_items_sent(added_items)
        local is_chat_done = (chat_listener and chat_listener.is_completed())

        if sent_count > 0 or is_chat_done or (not is_trade_active() and #added_items > 0) then
            local count = (sent_count > 0) and sent_count or #added_items
            mark_success(count)
        end

        chat_listener.disconnect()

        if trade_success then
            cache.last_trade_time = tick()
            if config.quantity > 0 and cache.stats.fish.total_items >= config.quantity then
                config.enabled = false
                config.trade_fish_enabled = false
                if byname_toggle_ctrl then
                    byname_toggle_ctrl.set_state(false)
                end
                save_config()
                set_status_msg("fish", string_format("Selesai! Berhasil mengirim %d/%d item", cache.stats.fish.total_items, config.quantity))
                return
            end
        else
            cache.stats.fish.failed = cache.stats.fish.failed + 1
            update_mode_status("fish")
        end
    else
        cache.stats.fish.failed = cache.stats.fish.failed + 1
        update_mode_status("fish")
    end
end

-- Trade by Rarity
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
        config.trade_rarity_enabled = false
        if rarity_toggle_ctrl then
            rarity_toggle_ctrl.set_state(false)
        end
        save_config()
        return
    end

    local inventory = player_data:Get("Inventory")
    local player_data_items = inventory and inventory.Items or {}

    local items_to_trade = {}
    local limit = math_min(20, config.quantity > 0 and (config.quantity - total_sent) or 20)

    local has_all_tier = table_find(config.selected_tiers, "All") ~= nil
    if #config.selected_tiers > 1 and not has_all_tier then
        items_to_trade = collect_round_robin_rarity(player_data_items, config.selected_tiers, limit)
    else
        for _, fish_item in ipairs(player_data_items) do
            if #items_to_trade >= limit then break end
            if fish_item and fish_item.Id then
                local fish_data = item_utility:GetItemData(fish_item.Id)
                if fish_data and fish_data.Data and fish_data.Data.Type == "Fish" then
                    if should_trade_fish_by_rarity(fish_data, fish_item) then
                        if not table_find(cache.processed_trades, fish_item.UUID) then
                            table_insert(items_to_trade, fish_item)
                        end
                    end
                end
            end
        end
    end

    if #items_to_trade == 0 then
        local rarity_name = get_mode_display_name("rarity")
        set_status_msg("rarity", "Error: Tidak ada lagi " .. rarity_name .. " di inventory")
        config.enabled = false
        config.trade_rarity_enabled = false
        if rarity_toggle_ctrl then
            rarity_toggle_ctrl.set_state(false)
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
        if not config.enabled or not is_trade_active() then break end

        local add_success = false
        for attempt = 1, 2 do
            local ok, res = pcall(function()
                return trade_remotes.AddItem:InvokeServer("Fish", item.UUID)
            end)
            if ok and res ~= false then
                add_success = true
                break
            end
            task_wait(0.04)
        end

        if add_success then
            table_insert(cache.processed_trades, item.UUID)
            table_insert(added_items, item)
        end
        task_wait(0.03)
    end

    if #added_items > 0 and is_trade_active() then
        local trade_success = false
        local function mark_success(count)
            if not trade_success then
                trade_success = true
                count = count or #added_items
                cache.stats.rarity.success_trades = cache.stats.rarity.success_trades + 1
                cache.stats.rarity.last_items = count
                cache.stats.rarity.total_items = cache.stats.rarity.total_items + count
                update_mode_status("rarity")
            end
        end

        local chat_listener = listen_for_trade_completion(function()
            mark_success()
        end)

        pcall(function()
            trade_remotes.SetReady:InvokeServer(true)
        end)

        wait_for_trade_end("rarity", chat_listener)
        task_wait(0.6)

        local sent_count = verify_items_sent(added_items)
        local is_chat_done = (chat_listener and chat_listener.is_completed())

        if sent_count > 0 or is_chat_done or (not is_trade_active() and #added_items > 0) then
            local count = (sent_count > 0) and sent_count or #added_items
            mark_success(count)
        end

        chat_listener.disconnect()

        if trade_success then
            cache.last_trade_time = tick()
            if config.quantity > 0 and cache.stats.rarity.total_items >= config.quantity then
                config.enabled = false
                config.trade_rarity_enabled = false
                if rarity_toggle_ctrl then
                    rarity_toggle_ctrl.set_state(false)
                end
                save_config()
                set_status_msg("rarity", string_format("Selesai! Berhasil mengirim %d/%d item", cache.stats.rarity.total_items, config.quantity))
                return
            end
        else
            cache.stats.rarity.failed = cache.stats.rarity.failed + 1
            update_mode_status("rarity")
        end
    else
        cache.stats.rarity.failed = cache.stats.rarity.failed + 1
        update_mode_status("rarity")
    end
end

-- Trade Enchants
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
        config.trade_enchants_enabled = false
        if enchant_toggle_ctrl then
            enchant_toggle_ctrl.set_state(false)
        end
        save_config()
        return
    end

    local inventory = player_data:Get("Inventory")
    local player_data_items = inventory and inventory.Items or {}

    local items_to_trade = {}
    local limit = math_min(20, config.quantity > 0 and (config.quantity - total_sent) or 20)
    for _, item in ipairs(player_data_items) do
        if #items_to_trade >= limit then
            break
        end

        if item and item.Id then
            local is_fav = (item.Favorited == true or (item.Metadata and item.Metadata.Favorited == true))
            if not (is_fav and not config.trade_favorited) then
                local item_data = item_utility:GetItemData(item.Id)
                if item_data and item_data.Data and item_data.Data.Type == "Enchant Stones" then
                    local has_all_enchant = table_find(config.selected_items, "All") ~= nil
                    if has_all_enchant or table_find(config.selected_items, item_data.Data.Name) then
                        if not table_find(cache.processed_trades, item.UUID) then
                            table_insert(items_to_trade, item)
                        end
                    end
                end
            end
        end
    end

    if #items_to_trade == 0 then
        local item_name = get_mode_display_name("enchant")
        set_status_msg("enchant", "Error: Tidak ada lagi " .. item_name .. " di inventory")
        config.enabled = false
        config.trade_enchants_enabled = false
        if enchant_toggle_ctrl then
            enchant_toggle_ctrl.set_state(false)
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
        if not config.enabled or not is_trade_active() then break end

        local item_data = item_utility:GetItemData(item.Id)
        local add_success = false
        for attempt = 1, 2 do
            local pref_type = (item_data and item_data.Data and item_data.Data.Type) or "Items"
            for _, cat_type in ipairs({pref_type, "Items", "Item", "Fish"}) do
                local ok, res = pcall(function()
                    return trade_remotes.AddItem:InvokeServer(cat_type, item.UUID)
                end)
                if ok and res ~= false then
                    add_success = true
                    break
                end
            end
            if add_success then break end
            task_wait(0.04)
        end

        if add_success then
            table_insert(cache.processed_trades, item.UUID)
            table_insert(added_items, item)
        end
        task_wait(0.03)
    end

    if #added_items > 0 and is_trade_active() then
        local trade_success = false
        local function mark_success(count)
            if not trade_success then
                trade_success = true
                count = count or #added_items
                cache.stats.enchant.success_trades = cache.stats.enchant.success_trades + 1
                cache.stats.enchant.last_items = count
                cache.stats.enchant.total_items = cache.stats.enchant.total_items + count
                update_mode_status("enchant")
            end
        end

        local chat_listener = listen_for_trade_completion(function()
            mark_success()
        end)

        pcall(function()
            trade_remotes.SetReady:InvokeServer(true)
        end)

        wait_for_trade_end("enchant", chat_listener)
        task_wait(0.6)

        local sent_count = verify_items_sent(added_items)
        local is_chat_done = (chat_listener and chat_listener.is_completed())

        if sent_count > 0 or is_chat_done or (not is_trade_active() and #added_items > 0) then
            local count = (sent_count > 0) and sent_count or #added_items
            mark_success(count)
        end

        chat_listener.disconnect()

        if trade_success then
            cache.last_trade_time = tick()
            if config.quantity > 0 and cache.stats.enchant.total_items >= config.quantity then
                config.enabled = false
                config.trade_enchants_enabled = false
                if enchant_toggle_ctrl then
                    enchant_toggle_ctrl.set_state(false)
                end
                save_config()
                set_status_msg("enchant", string_format("Selesai! Berhasil mengirim %d/%d enchant stone", cache.stats.enchant.total_items, config.quantity))
                return
            end
        else
            cache.stats.enchant.failed = cache.stats.enchant.failed + 1
            update_mode_status("enchant")
        end
    else
        cache.stats.enchant.failed = cache.stats.enchant.failed + 1
        update_mode_status("enchant")
    end
end

-- Trade by Coin Target
local function try_trade_coin()
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

    local target_coins = config.trade_coin_target or 8000000
    local already_sent = cache.stats.coin.total_coins or 0

    if target_coins > 0 and already_sent >= target_coins then
        config.enabled = false
        config.trade_coin_enabled = false
        if coin_toggle_ctrl then
            coin_toggle_ctrl.set_state(false)
        end
        save_config()
        set_status_msg("coin", string_format("Selesai! Berhasil mengirim %s/%s Coins", format_number(already_sent), format_number(target_coins)))
        return
    end

    local items_to_trade, batch_value = select_fish_for_coin_trade(target_coins, already_sent)

    if #items_to_trade == 0 then
        set_status_msg("coin", "Error: Tidak ada lagi ikan yang tersedia di inventory")
        config.enabled = false
        config.trade_coin_enabled = false
        if coin_toggle_ctrl then
            coin_toggle_ctrl.set_state(false)
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
    set_status_msg("coin", "Offer accepted! Adding " .. #items_to_trade .. " fish (~" .. format_number(batch_value) .. " Coins)...")
    for _, item in ipairs(items_to_trade) do
        if not config.enabled or not is_trade_active() then break end

        local add_success = false
        for attempt = 1, 2 do
            for _, cat_type in ipairs({"Fish", "Items", "Item"}) do
                local ok, res = pcall(function()
                    return trade_remotes.AddItem:InvokeServer(cat_type, item.UUID)
                end)
                if ok and res ~= false then
                    add_success = true
                    break
                end
            end
            if add_success then break end
            task_wait(0.04)
        end

        if add_success then
            table_insert(cache.processed_trades, item.UUID)
            table_insert(added_items, item)
        end
        task_wait(0.03)
    end

    if #added_items > 0 and is_trade_active() then
        local trade_success = false
        local function mark_success(count)
            if not trade_success then
                trade_success = true
                count = count or #added_items

                local sent_coin_subtotal = 0
                for _, itm in ipairs(added_items) do
                    sent_coin_subtotal = sent_coin_subtotal + calculate_fish_coin_value(itm)
                end

                cache.stats.coin.success_trades = cache.stats.coin.success_trades + 1
                cache.stats.coin.last_items = count
                cache.stats.coin.total_items = cache.stats.coin.total_items + count
                cache.stats.coin.total_coins = cache.stats.coin.total_coins + sent_coin_subtotal
                update_mode_status("coin")
            end
        end

        local chat_listener = listen_for_trade_completion(function()
            mark_success()
        end)

        pcall(function()
            trade_remotes.SetReady:InvokeServer(true)
        end)

        wait_for_trade_end("coin", chat_listener)
        task_wait(0.6)

        local sent_count = verify_items_sent(added_items)
        local is_chat_done = (chat_listener and chat_listener.is_completed())

        if sent_count > 0 or is_chat_done or (not is_trade_active() and #added_items > 0) then
            local count = (sent_count > 0) and sent_count or #added_items
            mark_success(count)
        end

        chat_listener.disconnect()

        if trade_success then
            cache.last_trade_time = tick()
            if config.trade_coin_target > 0 and cache.stats.coin.total_coins >= config.trade_coin_target then
                config.enabled = false
                config.trade_coin_enabled = false
                if coin_toggle_ctrl then
                    coin_toggle_ctrl.set_state(false)
                end
                save_config()
                set_status_msg("coin", string_format("Selesai! Berhasil mengirim %s Coins (%d ikan)", format_number(cache.stats.coin.total_coins), cache.stats.coin.total_items))
                return
            end
        else
            cache.stats.coin.failed = cache.stats.coin.failed + 1
            update_mode_status("coin")
        end
    else
        cache.stats.coin.failed = cache.stats.coin.failed + 1
        update_mode_status("coin")
    end
end

-- Auto Trade Loop
local function run_auto_trade_loop()
    if cache.loop_running then return end
    cache.loop_running = true

    task_spawn(function()
        while is_running and _G.KeenanHub_AutoTrade_ScriptID == script_id do
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

    task_spawn(function()
        while is_running and _G.KeenanHub_AutoTrade_ScriptID == script_id do
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

    task_spawn(function()
        while is_running and _G.KeenanHub_AutoTrade_ScriptID == script_id do
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

    task_spawn(function()
        while is_running and _G.KeenanHub_AutoTrade_ScriptID == script_id do
            if config.enabled and config.trade_coin_enabled then
                if not cache.is_trading_active then
                    cache.is_trading_active = true
                    pcall(try_trade_coin)
                    cache.is_trading_active = false
                end
            end
            task_wait(3)
        end
    end)
end
_G.run_auto_trade_loop = run_auto_trade_loop

local trade_ended_conn = nil
pcall(function()
    if trade_remotes and trade_remotes.TradeEnded then
        trade_ended_conn = trade_remotes.TradeEnded.OnClientEvent:Connect(function()
            cache.last_trade_time = tick()
        end)
        track_conn(trade_ended_conn)
    end
end)

-- UI Setup
local function create_ui()
    local parent_gui = nil
    if gethui then
        pcall(function() parent_gui = gethui() end)
    end
    if not parent_gui and core_gui then
        pcall(function()
            local test_gui = Instance_new("ScreenGui")
            test_gui.Parent = core_gui
            test_gui:Destroy()
            parent_gui = core_gui
        end)
    end
    if not parent_gui then
        parent_gui = local_player:WaitForChild("PlayerGui")
    end

    local function clear_old_guis(container)
        if not container then return end
        pcall(function()
            for _, child in ipairs(container:GetChildren()) do
                if child.Name == "KeenanHub_AutoTrade" or child.Name == "NoirHub_AutoTrade" or child.Name == "AutoTrade" then
                    pcall(function() child:Destroy() end)
                end
            end
        end)
    end

    clear_old_guis(parent_gui)
    clear_old_guis(local_player:FindFirstChild("PlayerGui"))
    if gethui then clear_old_guis(gethui()) end
    if core_gui then clear_old_guis(core_gui) end

    local gui = Instance_new("ScreenGui")
    gui.Name = "KeenanHub_AutoTrade"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 2147483647

    local success_parent = pcall(function()
        gui.Parent = parent_gui
    end)
    if not success_parent then
        parent_gui = local_player:WaitForChild("PlayerGui")
        gui.Parent = parent_gui
    end

    task_spawn(function()
        while is_running and _G.KeenanHub_AutoTrade_ScriptID == script_id do
            task_wait(1)
            pcall(function()
                if gui and gui.Parent then
                    gui.Enabled = true
                    gui.DisplayOrder = 2147483647
                end
            end)
        end
    end)

    local byname_fav_toggle = nil
    local enchant_fav_toggle = nil
    local rarity_fav_toggle = nil

    local function sync_fav_toggles(active)
        config.trade_favorited = active
        save_config()
        if byname_fav_toggle then byname_fav_toggle.set_state(active) end
        if enchant_fav_toggle then enchant_fav_toggle.set_state(active) end
        if rarity_fav_toggle then rarity_fav_toggle.set_state(active) end

        cache.loaded_fish = get_owned_fish_options()
        cache.loaded_enchants = get_owned_enchant_options()

        if item_panel and item_panel.Visible and populate_items_panel and fish_dropdown_btn then
            pcall(function() populate_items_panel(fish_dropdown_btn) end)
        end
        if enchant_panel and enchant_panel.Visible and populate_enchants_panel and enchant_dropdown_btn then
            pcall(function() populate_enchants_panel(enchant_dropdown_btn) end)
        end
    end

    local function sync_qty_boxes(val)
        val = math_max(0, math_floor(tonumber(val) or 0))
        config.quantity = val
        save_config()
        if qty_box and qty_box.Text ~= tostring(val) then qty_box.Text = tostring(val) end
        if es_qty_box and es_qty_box.Text ~= tostring(val) then es_qty_box.Text = tostring(val) end
        if r_qty_box and r_qty_box.Text ~= tostring(val) then r_qty_box.Text = tostring(val) end
    end

    local function truncate_string(str, max_len)
        if #str > max_len then
            return string_sub(str, 1, max_len - 2) .. ".."
        end
        return str
    end

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
                for _, item in ipairs(items) do
                    if item.Id then
                        local is_fav = (item.Favorited == true or (item.Metadata and item.Metadata.Favorited == true))
                        local include_item = true
                        if is_fav and not config.trade_favorited then
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
            end
        end)
        for name, qty in pairs(counts) do
            table_insert(list, name .. " (x" .. qty .. ")")
        end
        table_sort(list)
        return list
    end

    cache.loaded_fish = get_owned_fish_options()
    cache.loaded_enchants = get_owned_enchant_options()

    local BG_COLOR = Color3_fromRGB(28, 30, 34)
    local SIDEBAR_COLOR = Color3_fromRGB(20, 22, 25)
    local ACCENT_COLOR = Color3_fromRGB(250, 204, 21)
    local ACCENT_HOVER = Color3_fromRGB(253, 224, 71)
    local TEXT_COLOR = Color3_fromRGB(235, 238, 242)
    local MUTED_COLOR = Color3_fromRGB(140, 146, 158)
    local CARD_COLOR = Color3_fromRGB(36, 39, 44)
    local TOGGLE_ON_COLOR = Color3_fromRGB(250, 204, 21)
    local INPUT_BG_COLOR = Color3_fromRGB(18, 20, 23)
    local BORDER_COLOR = Color3_fromRGB(58, 63, 72)
    local BTN_BG_COLOR = Color3_fromRGB(46, 50, 58)
    local BTN_HOVER_COLOR = Color3_fromRGB(60, 66, 76)

    local font_face = Font.fromEnum(Enum.Font.SourceSans)
    local font_bold = Font.fromEnum(Enum.Font.SourceSans)

    local target_lbl
    local fish_dropdown_btn
    local enchant_dropdown_btn
    local rarity_dropdown_btn
    local close_detector
    local player_panel
    local item_panel
    local enchant_panel
    local rarity_panel
    local status_val_lbl = nil
    local enchant_status_val_lbl = nil
    local rarity_status_val_lbl = nil
    local coin_status_val_lbl = nil
    local populate_items_panel
    local populate_enchants_panel
    local qty_box
    local es_qty_box
    local r_qty_box

    local main = Instance_new("Frame")
    main.Name = "MainFrame"
    main.Size = UDim2_new(0, 250, 0, 200)
    main.Position = UDim2_new(0.5, -178, 0.5, -100)
    main.BackgroundColor3 = BG_COLOR
    main.BackgroundTransparency = 0
    main.BorderSizePixel = 0
    main.Active = true
    main.ZIndex = 10
    main.Parent = gui

    local main_stroke = Instance_new("UIStroke")
    main_stroke.Color = BORDER_COLOR
    main_stroke.Thickness = 1
    main_stroke.Parent = main

    local main_corner = Instance_new("UICorner")
    main_corner.CornerRadius = UDim_new(0, 6)
    main_corner.Parent = main

    close_detector = Instance_new("TextButton")
    close_detector.Name = "CloseDetector"
    close_detector.Size = UDim2_new(0, 5000, 0, 5000)
    close_detector.Position = UDim2_new(0.5, -2500, 0.5, -2500)
    close_detector.BackgroundTransparency = 0.99
    close_detector.BackgroundColor3 = Color3_fromRGB(0, 0, 0)
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
            close_detector.Visible = false
        end
    end)

    player_panel = Instance_new("Frame")
    player_panel.Name = "PlayerSelectionPanel"
    player_panel.Size = UDim2_new(0, 100, 1, 0)
    player_panel.Position = UDim2_new(1, 5, 0, 0)
    player_panel.BackgroundColor3 = SIDEBAR_COLOR
    player_panel.BackgroundTransparency = 0
    player_panel.BorderSizePixel = 0
    player_panel.Active = true
    player_panel.Visible = true
    player_panel.ZIndex = 10
    player_panel.Parent = main

    local p_stroke = Instance_new("UIStroke")
    p_stroke.Color = BORDER_COLOR
    p_stroke.Thickness = 1
    p_stroke.Parent = player_panel

    local p_corner = Instance_new("UICorner")
    p_corner.CornerRadius = UDim_new(0, 6)
    p_corner.Parent = player_panel

    local ply_refresh = Instance_new("TextButton")
    ply_refresh.Size = UDim2_new(1, -20, 0, 26)
    ply_refresh.Position = UDim2_new(0, 10, 0, 10)
    ply_refresh.BackgroundColor3 = BTN_BG_COLOR
    ply_refresh.Text = "Refresh"
    ply_refresh.TextColor3 = ACCENT_COLOR
    ply_refresh.TextSize = 10
    ply_refresh.FontFace = font_bold
    ply_refresh.Active = true
    ply_refresh.ZIndex = 10
    ply_refresh.Parent = player_panel

    local ply_refresh_c = Instance_new("UICorner")
    ply_refresh_c.CornerRadius = UDim_new(0, 4)
    ply_refresh_c.Parent = ply_refresh

    local ply_refresh_stroke = Instance_new("UIStroke")
    ply_refresh_stroke.Color = BORDER_COLOR
    ply_refresh_stroke.Thickness = 1
    ply_refresh_stroke.Parent = ply_refresh

    ply_refresh.MouseEnter:Connect(function()
        ply_refresh.BackgroundColor3 = BTN_HOVER_COLOR
    end)
    ply_refresh.MouseLeave:Connect(function()
        ply_refresh.BackgroundColor3 = BTN_BG_COLOR
    end)

    target_lbl = Instance_new("TextLabel")
    target_lbl.Size = UDim2_new(1, -12, 0, 20)
    target_lbl.Position = UDim2_new(0, 6, 0, 42)
    target_lbl.BackgroundColor3 = INPUT_BG_COLOR
    target_lbl.BackgroundTransparency = 0
    target_lbl.Text = truncate_string(config.trade_with ~= "" and config.trade_with or "None", 10)
    target_lbl.TextColor3 = ACCENT_COLOR
    target_lbl.TextSize = 10
    target_lbl.FontFace = font_bold
    target_lbl.TextXAlignment = Enum.TextXAlignment.Center
    target_lbl.ZIndex = 10
    target_lbl.Parent = player_panel

    local target_lbl_corner = Instance_new("UICorner")
    target_lbl_corner.CornerRadius = UDim_new(0, 4)
    target_lbl_corner.Parent = target_lbl

    local target_lbl_stroke = Instance_new("UIStroke")
    target_lbl_stroke.Color = BORDER_COLOR
    target_lbl_stroke.Thickness = 1
    target_lbl_stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    target_lbl_stroke.Parent = target_lbl

    local p_sep = Instance_new("Frame")
    p_sep.Size = UDim2_new(1, 0, 0, 1)
    p_sep.Position = UDim2_new(0, 0, 0, 68)
    p_sep.BackgroundColor3 = BORDER_COLOR
    p_sep.BorderSizePixel = 0
    p_sep.ZIndex = 10
    p_sep.Parent = player_panel

    local p_scroll = Instance_new("ScrollingFrame")
    p_scroll.Size = UDim2_new(1, -12, 1, -78)
    p_scroll.Position = UDim2_new(0, 6, 0, 73)
    p_scroll.BackgroundTransparency = 1
    p_scroll.BorderSizePixel = 0
    p_scroll.ScrollBarThickness = 3
    p_scroll.ScrollBarImageColor3 = BORDER_COLOR
    p_scroll.Active = true
    p_scroll.ZIndex = 10
    safe_set_scroll(p_scroll)
    p_scroll.CanvasSize = UDim2_new(0, 0, 0, 0)
    p_scroll.Parent = player_panel

    local p_layout = Instance_new("UIListLayout")
    p_layout.Padding = UDim_new(0, 2)
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
                local opt_btn = Instance_new("TextButton")
                opt_btn.Size = UDim2_new(1, -6, 0, 24)
                opt_btn.BackgroundTransparency = is_selected and 0 or 1
                opt_btn.BackgroundColor3 = CARD_COLOR
                opt_btn.Text = ""
                opt_btn.Active = true
                opt_btn.ZIndex = 12
                opt_btn.Parent = p_scroll

                local opt_corner = Instance_new("UICorner")
                opt_corner.CornerRadius = UDim_new(0, 4)
                opt_corner.Parent = opt_btn

                local opt_lbl = Instance_new("TextLabel")
                opt_lbl.Size = UDim2_new(1, -20, 1, 0)
                opt_lbl.Position = UDim2_new(0, 15, 0, 0)
                opt_lbl.BackgroundTransparency = 1
                opt_lbl.Text = truncate_string(name, 10)
                opt_lbl.TextColor3 = is_selected and ACCENT_COLOR or TEXT_COLOR
                opt_lbl.TextSize = 10
                opt_lbl.FontFace = font_face
                opt_lbl.TextXAlignment = Enum.TextXAlignment.Left
                opt_lbl.ZIndex = 13
                opt_lbl.Parent = opt_btn

                local indicator = Instance_new("Frame")
                indicator.Size = UDim2_new(0, 3, 0, 14)
                indicator.Position = UDim2_new(0, 5, 0.5, -7)
                indicator.BackgroundColor3 = ACCENT_COLOR
                indicator.BorderSizePixel = 0
                indicator.ZIndex = 14
                indicator.Visible = is_selected
                indicator.Parent = opt_btn

                opt_btn.MouseEnter:Connect(function()
                    if not is_selected then
                        opt_btn.BackgroundTransparency = 0
                        opt_btn.BackgroundColor3 = BTN_HOVER_COLOR
                    end
                end)
                opt_btn.MouseLeave:Connect(function()
                    if not is_selected then
                        opt_btn.BackgroundTransparency = 1
                    else
                        opt_btn.BackgroundColor3 = CARD_COLOR
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

            p_scroll.CanvasSize = UDim2_new(0, 0, 0, match_count * 26 + 10)
        end)
    end

    ply_refresh.Activated:Connect(function()
        ply_refresh.Text = "Refreshed!"
        populate_players_panel()
        task_wait(1)
        ply_refresh.Text = "Refresh"
    end)

    populate_players_panel()

    item_panel = Instance_new("Frame")
    item_panel.Name = "ItemSelectionPanel"
    item_panel.Size = UDim2_new(0, 150, 1, -34)
    item_panel.Position = UDim2_new(1, -160, 0, 28)
    item_panel.BackgroundColor3 = SIDEBAR_COLOR
    item_panel.BackgroundTransparency = 0
    item_panel.BorderSizePixel = 0
    item_panel.Active = true
    item_panel.Visible = false
    item_panel.ZIndex = 10
    item_panel.Parent = main

    local i_stroke = Instance_new("UIStroke")
    i_stroke.Color = BORDER_COLOR
    i_stroke.Thickness = 1
    i_stroke.Parent = item_panel

    local i_corner = Instance_new("UICorner")
    i_corner.CornerRadius = UDim_new(0, 6)
    i_corner.Parent = item_panel

    local item_search_box = Instance_new("TextBox")
    item_search_box.Size = UDim2_new(1, -20, 0, 24)
    item_search_box.Position = UDim2_new(0, 10, 0, 10)
    item_search_box.BackgroundColor3 = INPUT_BG_COLOR
    item_search_box.Text = ""
    item_search_box.PlaceholderText = "Search..."
    item_search_box.PlaceholderColor3 = MUTED_COLOR
    item_search_box.TextColor3 = TEXT_COLOR
    item_search_box.TextSize = 10
    item_search_box.FontFace = font_face
    item_search_box.TextXAlignment = Enum.TextXAlignment.Center
    item_search_box.Active = true
    item_search_box.ZIndex = 10
    item_search_box.Parent = item_panel

    local isb_c = Instance_new("UICorner")
    isb_c.CornerRadius = UDim_new(0, 5)
    isb_c.Parent = item_search_box

    local isb_stroke = Instance_new("UIStroke")
    isb_stroke.Color = Color3_fromRGB(45, 45, 45)
    isb_stroke.Thickness = 1
    isb_stroke.Parent = item_search_box

    local isb_padding = Instance_new("UIPadding")
    isb_padding.PaddingLeft = UDim_new(0, 8)
    isb_padding.PaddingRight = UDim_new(0, 8)
    isb_padding.Parent = item_search_box

    local i_sep = Instance_new("Frame")
    i_sep.Size = UDim2_new(1, 0, 0, 1)
    i_sep.Position = UDim2_new(0, 0, 0, 42)
    i_sep.BackgroundColor3 = BORDER_COLOR
    i_sep.BorderSizePixel = 0
    i_sep.ZIndex = 10
    i_sep.Parent = item_panel

    local i_scroll = Instance_new("ScrollingFrame")
    i_scroll.Size = UDim2_new(1, -12, 1, -52)
    i_scroll.Position = UDim2_new(0, 6, 0, 47)
    i_scroll.BackgroundTransparency = 1
    i_scroll.BorderSizePixel = 0
    i_scroll.ScrollBarThickness = 3
    i_scroll.ScrollBarImageColor3 = BORDER_COLOR
    i_scroll.Active = true
    i_scroll.ZIndex = 10
    safe_set_scroll(i_scroll)
    i_scroll.CanvasSize = UDim2_new(0, 0, 0, 0)
    i_scroll.Parent = item_panel

    local i_layout = Instance_new("UIListLayout")
    i_layout.Padding = UDim_new(0, 2)
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
                    local opt_btn = Instance_new("TextButton")
                    opt_btn.Size = UDim2_new(1, -6, 0, 24)
                    opt_btn.BackgroundTransparency = is_selected and 0 or 1
                    opt_btn.BackgroundColor3 = CARD_COLOR
                    opt_btn.Text = ""
                    opt_btn.Active = true
                    opt_btn.ZIndex = 12
                    opt_btn.Parent = i_scroll

                    local opt_corner = Instance_new("UICorner")
                    opt_corner.CornerRadius = UDim_new(0, 4)
                    opt_corner.Parent = opt_btn

                    local opt_lbl = Instance_new("TextLabel")
                    opt_lbl.Size = UDim2_new(1, -20, 1, 0)
                    opt_lbl.Position = UDim2_new(0, 15, 0, 0)
                    opt_lbl.BackgroundTransparency = 1
                    opt_lbl.Text = opt
                    opt_lbl.TextColor3 = is_selected and ACCENT_COLOR or TEXT_COLOR
                    opt_lbl.TextSize = 10
                    opt_lbl.FontFace = font_face
                    opt_lbl.TextXAlignment = Enum.TextXAlignment.Left
                    opt_lbl.ZIndex = 13
                    opt_lbl.Parent = opt_btn

                    local indicator = Instance_new("Frame")
                    indicator.Size = UDim2_new(0, 3, 0, 14)
                    indicator.Position = UDim2_new(0, 5, 0.5, -7)
                    indicator.BackgroundColor3 = ACCENT_COLOR
                    indicator.BorderSizePixel = 0
                    indicator.ZIndex = 14
                    indicator.Visible = is_selected
                    indicator.Parent = opt_btn

                    opt_btn.MouseEnter:Connect(function()
                        if not is_selected then
                            opt_btn.BackgroundTransparency = 0
                            opt_btn.BackgroundColor3 = BTN_HOVER_COLOR
                        end
                    end)
                    opt_btn.MouseLeave:Connect(function()
                        if not is_selected then
                            opt_btn.BackgroundTransparency = 1
                        else
                            opt_btn.BackgroundColor3 = CARD_COLOR
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

            i_scroll.CanvasSize = UDim2_new(0, 0, 0, match_count * 26 + 10)
        end)
    end

    local item_search_thread = nil
    item_search_box:GetPropertyChangedSignal("Text"):Connect(function()
        if item_search_thread then pcall(function() task_cancel(item_search_thread) end) end
        item_search_thread = task_delay(0.12, function()
            if fish_dropdown_btn then
                populate_items_panel(fish_dropdown_btn)
            end
        end)
    end)

    enchant_panel = Instance_new("Frame")
    enchant_panel.Name = "EnchantSelectionPanel"
    enchant_panel.Size = UDim2_new(0, 150, 1, -34)
    enchant_panel.Position = UDim2_new(1, -160, 0, 28)
    enchant_panel.BackgroundColor3 = SIDEBAR_COLOR
    enchant_panel.BackgroundTransparency = 0
    enchant_panel.BorderSizePixel = 0
    enchant_panel.Active = true
    enchant_panel.Visible = false
    enchant_panel.ZIndex = 10
    enchant_panel.Parent = main

    local en_stroke = Instance_new("UIStroke")
    en_stroke.Color = BORDER_COLOR
    en_stroke.Thickness = 1
    en_stroke.Parent = enchant_panel

    local en_corner = Instance_new("UICorner")
    en_corner.CornerRadius = UDim_new(0, 6)
    en_corner.Parent = enchant_panel

    local enchant_search_box = Instance_new("TextBox")
    enchant_search_box.Size = UDim2_new(1, -20, 0, 24)
    enchant_search_box.Position = UDim2_new(0, 10, 0, 10)
    enchant_search_box.BackgroundColor3 = INPUT_BG_COLOR
    enchant_search_box.Text = ""
    enchant_search_box.PlaceholderText = "Search..."
    enchant_search_box.PlaceholderColor3 = MUTED_COLOR
    enchant_search_box.TextColor3 = TEXT_COLOR
    enchant_search_box.TextSize = 10
    enchant_search_box.FontFace = font_face
    enchant_search_box.TextXAlignment = Enum.TextXAlignment.Center
    enchant_search_box.Active = true
    enchant_search_box.ZIndex = 10
    enchant_search_box.Parent = enchant_panel

    local esb_c = Instance_new("UICorner")
    esb_c.CornerRadius = UDim_new(0, 5)
    esb_c.Parent = enchant_search_box

    local esb_stroke = Instance_new("UIStroke")
    esb_stroke.Color = Color3_fromRGB(45, 45, 45)
    esb_stroke.Thickness = 1
    esb_stroke.Parent = enchant_search_box

    local esb_padding = Instance_new("UIPadding")
    esb_padding.PaddingLeft = UDim_new(0, 8)
    esb_padding.PaddingRight = UDim_new(0, 8)
    esb_padding.Parent = enchant_search_box

    local en_sep = Instance_new("Frame")
    en_sep.Size = UDim2_new(1, 0, 0, 1)
    en_sep.Position = UDim2_new(0, 0, 0, 42)
    en_sep.BackgroundColor3 = BORDER_COLOR
    en_sep.BorderSizePixel = 0
    en_sep.ZIndex = 10
    en_sep.Parent = enchant_panel

    local en_scroll = Instance_new("ScrollingFrame")
    en_scroll.Size = UDim2_new(1, -12, 1, -52)
    en_scroll.Position = UDim2_new(0, 6, 0, 47)
    en_scroll.BackgroundTransparency = 1
    en_scroll.BorderSizePixel = 0
    en_scroll.ScrollBarThickness = 3
    en_scroll.ScrollBarImageColor3 = BORDER_COLOR
    en_scroll.Active = true
    en_scroll.ZIndex = 10
    safe_set_scroll(en_scroll)
    en_scroll.CanvasSize = UDim2_new(0, 0, 0, 0)
    en_scroll.Parent = enchant_panel

    local en_layout = Instance_new("UIListLayout")
    en_layout.Padding = UDim_new(0, 2)
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

                    local opt_btn = Instance_new("TextButton")
                    opt_btn.Size = UDim2_new(1, -6, 0, 24)
                    opt_btn.BackgroundTransparency = is_selected and 0 or 1
                    opt_btn.BackgroundColor3 = CARD_COLOR
                    opt_btn.Text = ""
                    opt_btn.Active = true
                    opt_btn.ZIndex = 12
                    opt_btn.Parent = en_scroll

                    local opt_corner = Instance_new("UICorner")
                    opt_corner.CornerRadius = UDim_new(0, 4)
                    opt_corner.Parent = opt_btn

                    local opt_lbl = Instance_new("TextLabel")
                    opt_lbl.Size = UDim2_new(1, -20, 1, 0)
                    opt_lbl.Position = UDim2_new(0, 15, 0, 0)
                    opt_lbl.BackgroundTransparency = 1
                    opt_lbl.Text = opt
                    opt_lbl.TextColor3 = is_selected and ACCENT_COLOR or TEXT_COLOR
                    opt_lbl.TextSize = 10
                    opt_lbl.FontFace = font_face
                    opt_lbl.TextXAlignment = Enum.TextXAlignment.Left
                    opt_lbl.ZIndex = 13
                    opt_lbl.Parent = opt_btn

                    local indicator = Instance_new("Frame")
                    indicator.Size = UDim2_new(0, 3, 0, 14)
                    indicator.Position = UDim2_new(0, 5, 0.5, -7)
                    indicator.BackgroundColor3 = ACCENT_COLOR
                    indicator.BorderSizePixel = 0
                    indicator.ZIndex = 14
                    indicator.Visible = is_selected
                    indicator.Parent = opt_btn

                    opt_btn.MouseEnter:Connect(function()
                        if not is_selected then
                            opt_btn.BackgroundTransparency = 0
                            opt_btn.BackgroundColor3 = BTN_HOVER_COLOR
                        end
                    end)
                    opt_btn.MouseLeave:Connect(function()
                        if not is_selected then
                            opt_btn.BackgroundTransparency = 1
                        else
                            opt_btn.BackgroundColor3 = CARD_COLOR
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

            en_scroll.CanvasSize = UDim2_new(0, 0, 0, match_count * 26 + 10)
        end)
    end

    local enchant_search_thread = nil
    enchant_search_box:GetPropertyChangedSignal("Text"):Connect(function()
        if enchant_search_thread then pcall(function() task_cancel(enchant_search_thread) end) end
        enchant_search_thread = task_delay(0.12, function()
            if enchant_dropdown_btn then
                populate_enchants_panel(enchant_dropdown_btn)
            end
        end)
    end)

    rarity_panel = Instance_new("Frame")
    rarity_panel.Name = "RaritySelectionPanel"
    rarity_panel.Size = UDim2_new(0, 150, 1, -34)
    rarity_panel.Position = UDim2_new(1, -160, 0, 28)
    rarity_panel.BackgroundColor3 = SIDEBAR_COLOR
    rarity_panel.BackgroundTransparency = 0
    rarity_panel.BorderSizePixel = 0
    rarity_panel.Active = true
    rarity_panel.Visible = false
    rarity_panel.ZIndex = 10
    rarity_panel.Parent = main

    local r_stroke = Instance_new("UIStroke")
    r_stroke.Color = BORDER_COLOR
    r_stroke.Thickness = 1
    r_stroke.Parent = rarity_panel

    local r_corner = Instance_new("UICorner")
    r_corner.CornerRadius = UDim_new(0, 6)
    r_corner.Parent = rarity_panel

    local r_title = Instance_new("TextLabel")
    r_title.Size = UDim2_new(1, -20, 0, 24)
    r_title.Position = UDim2_new(0, 10, 0, 10)
    r_title.BackgroundTransparency = 1
    r_title.Text = "Select Rarity"
    r_title.TextColor3 = ACCENT_COLOR
    r_title.TextSize = 10
    r_title.FontFace = font_bold
    r_title.TextXAlignment = Enum.TextXAlignment.Center
    r_title.ZIndex = 10
    r_title.Parent = rarity_panel

    local r_sep = Instance_new("Frame")
    r_sep.Size = UDim2_new(1, 0, 0, 1)
    r_sep.Position = UDim2_new(0, 0, 0, 42)
    r_sep.BackgroundColor3 = BORDER_COLOR
    r_sep.BorderSizePixel = 0
    r_sep.ZIndex = 10
    r_sep.Parent = rarity_panel

    local r_scroll = Instance_new("ScrollingFrame")
    r_scroll.Size = UDim2_new(1, -12, 1, -52)
    r_scroll.Position = UDim2_new(0, 6, 0, 47)
    r_scroll.BackgroundTransparency = 1
    r_scroll.BorderSizePixel = 0
    r_scroll.ScrollBarThickness = 3
    r_scroll.ScrollBarImageColor3 = BORDER_COLOR
    r_scroll.Active = true
    r_scroll.ZIndex = 10
    safe_set_scroll(r_scroll)
    r_scroll.CanvasSize = UDim2_new(0, 0, 0, 0)
    r_scroll.Parent = rarity_panel

    local r_layout = Instance_new("UIListLayout")
    r_layout.Padding = UDim_new(0, 2)
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
                local opt_btn = Instance_new("TextButton")
                opt_btn.Size = UDim2_new(1, -6, 0, 24)
                opt_btn.BackgroundTransparency = is_selected and 0 or 1
                opt_btn.BackgroundColor3 = CARD_COLOR
                opt_btn.Text = ""
                opt_btn.Active = true
                opt_btn.ZIndex = 12
                opt_btn.Parent = r_scroll

                local opt_corner = Instance_new("UICorner")
                opt_corner.CornerRadius = UDim_new(0, 4)
                opt_corner.Parent = opt_btn

                local opt_lbl = Instance_new("TextLabel")
                opt_lbl.Size = UDim2_new(1, -20, 1, 0)
                opt_lbl.Position = UDim2_new(0, 15, 0, 0)
                opt_lbl.BackgroundTransparency = 1
                opt_lbl.Text = opt
                opt_lbl.TextColor3 = is_selected and ACCENT_COLOR or TEXT_COLOR
                opt_lbl.TextSize = 10
                opt_lbl.FontFace = font_face
                opt_lbl.TextXAlignment = Enum.TextXAlignment.Left
                opt_lbl.ZIndex = 13
                opt_lbl.Parent = opt_btn

                local indicator = Instance_new("Frame")
                indicator.Size = UDim2_new(0, 3, 0, 14)
                indicator.Position = UDim2_new(0, 5, 0.5, -7)
                indicator.BackgroundColor3 = ACCENT_COLOR
                indicator.BorderSizePixel = 0
                indicator.ZIndex = 14
                indicator.Visible = is_selected
                indicator.Parent = opt_btn

                opt_btn.MouseEnter:Connect(function()
                    if not is_selected then
                        opt_btn.BackgroundTransparency = 0
                        opt_btn.BackgroundColor3 = BTN_HOVER_COLOR
                    end
                end)
                opt_btn.MouseLeave:Connect(function()
                    if not is_selected then
                        opt_btn.BackgroundTransparency = 1
                    else
                        opt_btn.BackgroundColor3 = CARD_COLOR
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

            r_scroll.CanvasSize = UDim2_new(0, 0, 0, match_count * 26 + 10)
        end)
    end

    local header = Instance_new("Frame")
    header.Name = "HeaderBar"
    header.Size = UDim2_new(1, 0, 0, 24)
    header.BackgroundColor3 = SIDEBAR_COLOR
    header.BackgroundTransparency = 0
    header.BorderSizePixel = 0
    header.Active = true
    header.ZIndex = 25
    header.Parent = main

    local header_corner = Instance_new("UICorner")
    header_corner.CornerRadius = UDim_new(0, 6)
    header_corner.Parent = header

    local header_cover = Instance_new("Frame")
    header_cover.Size = UDim2_new(1, 0, 0, 6)
    header_cover.Position = UDim2_new(0, 0, 1, -6)
    header_cover.BackgroundColor3 = SIDEBAR_COLOR
    header_cover.BackgroundTransparency = 0
    header_cover.BorderSizePixel = 0
    header_cover.ZIndex = 25
    header_cover.Parent = header

    local header_div = Instance_new("Frame")
    header_div.Size = UDim2_new(1, 0, 0, 1)
    header_div.Position = UDim2_new(0, 0, 1, 0)
    header_div.BackgroundColor3 = BORDER_COLOR
    header_div.BorderSizePixel = 0
    header_div.ZIndex = 25
    header_div.Parent = header

    local title_lbl = Instance_new("TextLabel")
    title_lbl.Size = UDim2_new(1, -85, 1, 0)
    title_lbl.Position = UDim2_new(0, 8, 0, 0)
    title_lbl.BackgroundTransparency = 1
    title_lbl.Text = "Keenan Trade Script"
    title_lbl.TextColor3 = ACCENT_COLOR
    title_lbl.TextSize = 11
    title_lbl.FontFace = font_bold
    title_lbl.TextXAlignment = Enum.TextXAlignment.Left
    title_lbl.ZIndex = 26
    title_lbl.Parent = header

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

    local floating_btn = Instance_new("TextButton")
    floating_btn.Name = "FloatingRestore"
    floating_btn.Size = UDim2_new(0, 42, 0, 42)
    floating_btn.Position = UDim2_new(0, 15, 0.5, -21)
    floating_btn.BackgroundColor3 = SIDEBAR_COLOR
    floating_btn.BackgroundTransparency = 0
    floating_btn.Text = ""
    floating_btn.Active = true
    floating_btn.Modal = true
    floating_btn.ZIndex = 20
    floating_btn.Visible = false
    floating_btn.Parent = gui

    local float_corner = Instance_new("UICorner")
    float_corner.CornerRadius = UDim_new(0, 6)
    float_corner.Parent = floating_btn

    local float_stroke = Instance_new("UIStroke")
    float_stroke.Color = ACCENT_COLOR
    float_stroke.Thickness = 1.5
    float_stroke.Parent = floating_btn

    local icon_lbl = Instance_new("TextLabel")
    icon_lbl.Name = "FloatingIcon"
    icon_lbl.Size = UDim2_new(1, 0, 1, 0)
    icon_lbl.Position = UDim2_new(0, 0, 0, 0)
    icon_lbl.BackgroundTransparency = 1
    icon_lbl.Text = "K"
    icon_lbl.TextColor3 = ACCENT_COLOR
    icon_lbl.TextSize = 22
    icon_lbl.FontFace = font_bold
    icon_lbl.ZIndex = 21
    icon_lbl.Visible = true
    icon_lbl.Parent = floating_btn

    local f_dragging, f_drag_input, f_drag_start, f_start_pos
    floating_btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            f_dragging, f_drag_start, f_start_pos = false, input.Position, floating_btn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    f_dragging = false
                    f_drag_start = nil
                end
            end)
        end
    end)
    floating_btn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            f_drag_input = input
        end
    end)

    track_conn(user_input_service.InputChanged:Connect(function(input)
        if input == drag_input and dragging and start_pos then
            local delta = input.Position - drag_start
            main.Position = UDim2_new(start_pos.X.Scale, start_pos.X.Offset + delta.X, start_pos.Y.Scale, start_pos.Y.Offset + delta.Y)
        elseif input == f_drag_input and f_drag_start and f_start_pos then
            local delta = input.Position - f_drag_start
            if delta.Magnitude > 5 then
                f_dragging = true
                floating_btn.Position = UDim2_new(f_start_pos.X.Scale, f_start_pos.X.Offset + delta.X, f_start_pos.Y.Scale, f_start_pos.Y.Offset + delta.Y)
            end
        end
    end))

    floating_btn.MouseEnter:Connect(function()
        float_stroke.Thickness = 2
        float_stroke.Color = ACCENT_HOVER
    end)
    floating_btn.MouseLeave:Connect(function()
        float_stroke.Thickness = 1.5
        float_stroke.Color = ACCENT_COLOR
    end)

    floating_btn.MouseButton1Click:Connect(function()
        if not f_dragging then
            main.Visible = true
            floating_btn.Visible = false
        end
    end)

    local min_btn = Instance_new("TextButton")
    min_btn.Name = "MinimizeBtn"
    min_btn.Size = UDim2_new(0, 18, 0, 18)
    min_btn.Position = UDim2_new(1, -66, 0.5, -9)
    min_btn.BackgroundTransparency = 1
    min_btn.BorderSizePixel = 0
    min_btn.Text = ""
    min_btn.Active = true
    min_btn.Modal = true
    min_btn.ZIndex = 27
    min_btn.Parent = header

    local min_line = Instance_new("Frame")
    min_line.Name = "MinLine"
    min_line.Size = UDim2_new(0, 9, 0, 1.5)
    min_line.Position = UDim2_new(0.5, -4, 0.5, 0)
    min_line.BackgroundColor3 = MUTED_COLOR
    min_line.BorderSizePixel = 0
    min_line.ZIndex = 28
    min_line.Parent = min_btn

    min_btn.MouseEnter:Connect(function()
        min_line.BackgroundColor3 = ACCENT_COLOR
    end)
    min_btn.MouseLeave:Connect(function()
        min_line.BackgroundColor3 = MUTED_COLOR
    end)

    min_btn.MouseButton1Click:Connect(function()
        main.Visible = false
        floating_btn.Visible = true
    end)

    local is_maximized = false
    local saved_pos = nil
    local saved_size = nil

    local restore_btn = Instance_new("TextButton")
    restore_btn.Name = "RestoreBtn"
    restore_btn.Size = UDim2_new(0, 18, 0, 18)
    restore_btn.Position = UDim2_new(1, -44, 0.5, -9)
    restore_btn.BackgroundTransparency = 1
    restore_btn.BorderSizePixel = 0
    restore_btn.Text = ""
    restore_btn.Active = true
    restore_btn.Modal = true
    restore_btn.ZIndex = 27
    restore_btn.Parent = header

    local max_box = Instance_new("Frame")
    max_box.Name = "MaxBox"
    max_box.Size = UDim2_new(0, 9, 0, 9)
    max_box.Position = UDim2_new(0.5, -4, 0.5, -4)
    max_box.BackgroundTransparency = 1
    max_box.BorderSizePixel = 0
    max_box.ZIndex = 28
    max_box.Parent = restore_btn

    local max_box_stroke = Instance_new("UIStroke")
    max_box_stroke.Color = MUTED_COLOR
    max_box_stroke.Thickness = 1.2
    max_box_stroke.Parent = max_box

    local res_box_back = Instance_new("Frame")
    res_box_back.Name = "ResBoxBack"
    res_box_back.Size = UDim2_new(0, 7, 0, 7)
    res_box_back.Position = UDim2_new(0.5, -2, 0.5, -5)
    res_box_back.BackgroundTransparency = 1
    res_box_back.BorderSizePixel = 0
    res_box_back.ZIndex = 28
    res_box_back.Visible = false
    res_box_back.Parent = restore_btn

    local res_stroke_back = Instance_new("UIStroke")
    res_stroke_back.Color = MUTED_COLOR
    res_stroke_back.Thickness = 1.2
    res_stroke_back.Parent = res_box_back

    local res_box_front = Instance_new("Frame")
    res_box_front.Name = "ResBoxFront"
    res_box_front.Size = UDim2_new(0, 7, 0, 7)
    res_box_front.Position = UDim2_new(0.5, -5, 0.5, -2)
    res_box_front.BackgroundColor3 = SIDEBAR_COLOR
    res_box_front.BackgroundTransparency = 0
    res_box_front.BorderSizePixel = 0
    res_box_front.ZIndex = 29
    res_box_front.Visible = false
    res_box_front.Parent = restore_btn

    local res_stroke_front = Instance_new("UIStroke")
    res_stroke_front.Color = MUTED_COLOR
    res_stroke_front.Thickness = 1.2
    res_stroke_front.Parent = res_box_front

    local function update_restore_icon_color(color)
        max_box_stroke.Color = color
        res_stroke_back.Color = color
        res_stroke_front.Color = color
    end

    restore_btn.MouseEnter:Connect(function()
        update_restore_icon_color(ACCENT_COLOR)
    end)
    restore_btn.MouseLeave:Connect(function()
        update_restore_icon_color(MUTED_COLOR)
    end)

    restore_btn.MouseButton1Click:Connect(function()
        if not is_maximized then
            saved_pos = main.Position
            saved_size = main.Size
            local top_y = main.Position.Y
            main.Position = UDim2_new(0, 10, top_y.Scale, top_y.Offset)
            main.Size = UDim2_new(1, -125, 1 - top_y.Scale, -top_y.Offset - 10)
            is_maximized = true
            max_box.Visible = false
            res_box_back.Visible = true
            res_box_front.Visible = true
        else
            if saved_pos and saved_size then
                main.Position = saved_pos
                main.Size = saved_size
            else
                main.Position = UDim2_new(0.5, -178, 0.5, -100)
                main.Size = UDim2_new(0, 250, 0, 200)
            end
            is_maximized = false
            max_box.Visible = true
            res_box_back.Visible = false
            res_box_front.Visible = false
        end
    end)

    local close_btn = Instance_new("TextButton")
    close_btn.Name = "CloseBtn"
    close_btn.Size = UDim2_new(0, 18, 0, 18)
    close_btn.Position = UDim2_new(1, -22, 0.5, -9)
    close_btn.BackgroundTransparency = 1
    close_btn.BorderSizePixel = 0
    close_btn.Text = "X"
    close_btn.TextColor3 = MUTED_COLOR
    close_btn.TextSize = 11
    close_btn.FontFace = font_face
    close_btn.Active = true
    close_btn.Modal = true
    close_btn.ZIndex = 27
    close_btn.Parent = header

    close_btn.MouseEnter:Connect(function()
        close_btn.TextColor3 = Color3_fromRGB(239, 68, 68)
    end)
    close_btn.MouseLeave:Connect(function()
        close_btn.TextColor3 = MUTED_COLOR
    end)

    close_btn.MouseButton1Click:Connect(function()
        if _G.KeenanHub_AutoTrade_Cleanup then
            pcall(_G.KeenanHub_AutoTrade_Cleanup)
        end
    end)

    local container = Instance_new("Frame")
    container.Name = "Content"
    container.Size = UDim2_new(1, -12, 1, -34)
    container.Position = UDim2_new(0, 6, 0, 28)
    container.BackgroundTransparency = 1
    container.Active = false
    container.ZIndex = 2
    container.Parent = main

    local settings_panel = Instance_new("ScrollingFrame")
    settings_panel.Name = "SettingsPanel"
    settings_panel.Size = UDim2_new(1, 0, 1, 0)
    settings_panel.Position = UDim2_new(0, 0, 0, 0)
    settings_panel.BackgroundTransparency = 1
    settings_panel.BorderSizePixel = 0
    settings_panel.ScrollBarThickness = 3
    settings_panel.ScrollBarImageColor3 = BORDER_COLOR
    settings_panel.Active = true
    safe_set_scroll(settings_panel)
    settings_panel.Parent = container

    local settings_pad = Instance_new("UIPadding")
    settings_pad.PaddingLeft = UDim_new(0, 6)
    settings_pad.PaddingRight = UDim_new(0, 10)
    settings_pad.PaddingTop = UDim_new(0, 6)
    settings_pad.PaddingBottom = UDim_new(0, 6)
    settings_pad.Parent = settings_panel

    local settings_layout = Instance_new("UIListLayout")
    settings_layout.Padding = UDim_new(0, 6)
    settings_layout.Parent = settings_panel

    -- UI Builders
    local function create_accordion(parent, title_text)
        local item_frame = Instance_new("Frame")
        item_frame.Size = UDim2_new(1, 0, 0, 26)
        item_frame.BackgroundColor3 = CARD_COLOR
        item_frame.BackgroundTransparency = 0
        item_frame.BorderSizePixel = 0
        item_frame.ClipsDescendants = true
        item_frame.Active = false
        item_frame.Parent = parent

        local accordion_stroke = Instance_new("UIStroke")
        accordion_stroke.Color = BORDER_COLOR
        accordion_stroke.Thickness = 1
        accordion_stroke.Parent = item_frame

        local accordion_corner = Instance_new("UICorner")
        accordion_corner.CornerRadius = UDim_new(0, 5)
        accordion_corner.Parent = item_frame

        local header = Instance_new("TextButton")
        header.Size = UDim2_new(1, 0, 0, 26)
        header.BackgroundTransparency = 1
        header.Text = "  " .. title_text
        header.TextColor3 = TEXT_COLOR
        header.TextSize = 10
        header.FontFace = font_bold
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.Active = true
        header.Modal = true
        header.Parent = item_frame

        local chevron = Instance_new("TextLabel")
        chevron.Size = UDim2_new(0, 20, 1, 0)
        chevron.Position = UDim2_new(1, -25, 0, 0)
        chevron.BackgroundTransparency = 1
        chevron.Text = "▼"
        chevron.TextColor3 = ACCENT_COLOR
        chevron.TextSize = 10
        chevron.FontFace = font_face
        chevron.TextXAlignment = Enum.TextXAlignment.Right
        chevron.Parent = header

        local content = Instance_new("Frame")
        content.Name = "Content"
        content.Size = UDim2_new(1, -12, 0, 0)
        content.Position = UDim2_new(0, 6, 0, 28)
        content.BackgroundTransparency = 1
        content.Active = false
        content.Parent = item_frame

        local content_layout = Instance_new("UIListLayout")
        content_layout.Padding = UDim_new(0, 6)
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

            tween_service:Create(item_frame, TweenInfo_new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2_new(1, 0, 0, target_height)
            }):Play()

            task_wait(0.21)
            parent.CanvasSize = UDim2_new(0, 0, 0, settings_layout.AbsoluteContentSize.Y + 20)
        end

        content_layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            if expanded then
                item_frame.Size = UDim2_new(1, 0, 0, 32 + content_layout.AbsoluteContentSize.Y)
            end
        end)

        header.MouseButton1Click:Connect(toggle_expand)

        return content
    end

    local function create_toggle(parent, label_text, default, callback)
        local row = Instance_new("Frame")
        row.Size = UDim2_new(1, 0, 0, 22)
        row.BackgroundTransparency = 1
        row.Active = true
        row.Parent = parent

        local lbl = Instance_new("TextLabel")
        lbl.Size = UDim2_new(0.65, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = label_text
        lbl.TextColor3 = TEXT_COLOR
        lbl.TextSize = 10
        lbl.FontFace = font_bold
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        local capsule = Instance_new("TextButton")
        capsule.Size = UDim2_new(0, 32, 0, 16)
        capsule.Position = UDim2_new(1, -32, 0.5, -8)
        capsule.BackgroundColor3 = default and TOGGLE_ON_COLOR or Color3_fromRGB(40, 44, 50)
        capsule.Text = ""
        capsule.AutoButtonColor = false
        capsule.Active = true
        capsule.Parent = row

        local cap_c = Instance_new("UICorner")
        cap_c.CornerRadius = UDim_new(0.5, 0)
        cap_c.Parent = capsule

        local cap_stroke = Instance_new("UIStroke")
        cap_stroke.Color = BORDER_COLOR
        cap_stroke.Thickness = 1
        cap_stroke.Parent = capsule

        local knob = Instance_new("Frame")
        knob.Size = UDim2_new(0, 12, 0, 12)
        knob.Position = default and UDim2_new(1, -14, 0.5, -6) or UDim2_new(0, 2, 0.5, -6)
        knob.BackgroundColor3 = Color3_fromRGB(240, 240, 240)
        knob.BorderSizePixel = 0
        knob.Parent = capsule

        local knob_c = Instance_new("UICorner")
        knob_c.CornerRadius = UDim_new(0.5, 0)
        knob_c.Parent = knob

        local active = default
        local function update_visual(state, instant)
            local target_pos = state and UDim2_new(1, -14, 0.5, -6) or UDim2_new(0, 2, 0.5, -6)
            local target_color = state and TOGGLE_ON_COLOR or Color3_fromRGB(40, 44, 50)
            if instant then
                knob.Position = target_pos
                capsule.BackgroundColor3 = target_color
            else
                tween_service:Create(knob, TweenInfo_new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Position = target_pos
                }):Play()
                tween_service:Create(capsule, TweenInfo_new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
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
            config.trade_coin_enabled = false
        end
        save_config()
    end

    -- Panel: Trade By Name
    local byname_content = create_accordion(settings_panel, "Trade By Name")
    local status_box = Instance_new("Frame")
    status_box.Name = "1_StatusBox"
    status_box.LayoutOrder = 1
    status_box.Size = UDim2_new(1, 0, 0, 58)
    status_box.AutomaticSize = Enum.AutomaticSize.Y
    status_box.BackgroundColor3 = CARD_COLOR
    status_box.BackgroundTransparency = 0
    status_box.BorderSizePixel = 0
    status_box.Parent = byname_content

    local status_box_pad = Instance_new("UIPadding")
    status_box_pad.PaddingBottom = UDim_new(0, 6)
    status_box_pad.PaddingRight = UDim_new(0, 10)
    status_box_pad.Parent = status_box

    local status_box_c = Instance_new("UICorner")
    status_box_c.CornerRadius = UDim_new(0, 6)
    status_box_c.Parent = status_box

    local status_box_stroke = Instance_new("UIStroke")
    status_box_stroke.Color = BORDER_COLOR
    status_box_stroke.Thickness = 1
    status_box_stroke.Parent = status_box

    local status_title = Instance_new("TextLabel")
    status_title.Size = UDim2_new(1, -10, 0, 16)
    status_title.Position = UDim2_new(0, 10, 0, 6)
    status_title.BackgroundTransparency = 1
    status_title.Text = "Status"
    status_title.TextColor3 = ACCENT_COLOR
    status_title.TextSize = 10
    status_title.FontFace = font_bold
    status_title.TextXAlignment = Enum.TextXAlignment.Left
    status_title.Parent = status_box

    status_val_lbl = Instance_new("TextLabel")
    status_val_lbl.Size = UDim2_new(1, -20, 0, 30)
    status_val_lbl.Position = UDim2_new(0, 10, 0, 22)
    status_val_lbl.AutomaticSize = Enum.AutomaticSize.Y
    status_val_lbl.BackgroundTransparency = 1
    status_val_lbl.Text = "Idle"
    status_val_lbl.TextColor3 = TEXT_COLOR
    status_val_lbl.TextSize = 10
    status_val_lbl.FontFace = font_face
    status_val_lbl.TextXAlignment = Enum.TextXAlignment.Left
    status_val_lbl.TextYAlignment = Enum.TextYAlignment.Top
    status_val_lbl.TextWrapped = true
    status_val_lbl.Parent = status_box

    local item_row = Instance_new("Frame")
    item_row.Name = "2_ItemRow"
    item_row.LayoutOrder = 2
    item_row.Size = UDim2_new(1, 0, 0, 22)
    item_row.BackgroundTransparency = 1
    item_row.Active = false
    item_row.Parent = byname_content

    local item_lbl = Instance_new("TextLabel")
    item_lbl.Size = UDim2_new(0.45, 0, 1, 0)
    item_lbl.BackgroundTransparency = 1
    item_lbl.Text = "Select Item"
    item_lbl.TextColor3 = TEXT_COLOR
    item_lbl.TextSize = 10
    item_lbl.FontFace = font_bold
    item_lbl.TextXAlignment = Enum.TextXAlignment.Left
    item_lbl.Parent = item_row

    fish_dropdown_btn = Instance_new("TextButton")
    fish_dropdown_btn.Size = UDim2_new(0.55, 0, 1, 0)
    fish_dropdown_btn.Position = UDim2_new(0.45, 0, 0, 0)
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
    fish_dropdown_btn.TextSize = 10
    fish_dropdown_btn.FontFace = font_face
    fish_dropdown_btn.TextXAlignment = Enum.TextXAlignment.Left
    fish_dropdown_btn.Active = true
    fish_dropdown_btn.Parent = item_row

    local fish_dropdown_c = Instance_new("UICorner")
    fish_dropdown_c.CornerRadius = UDim_new(0, 4)
    fish_dropdown_c.Parent = fish_dropdown_btn

    local fish_dropdown_stroke = Instance_new("UIStroke")
    fish_dropdown_stroke.Color = BORDER_COLOR
    fish_dropdown_stroke.Thickness = 1
    fish_dropdown_stroke.Parent = fish_dropdown_btn

    local fish_dropdown_pad = Instance_new("UIPadding")
    fish_dropdown_pad.PaddingLeft = UDim_new(0, 8)
    fish_dropdown_pad.PaddingRight = UDim_new(0, 8)
    fish_dropdown_pad.Parent = fish_dropdown_btn

    local fish_chevron = Instance_new("TextLabel")
    fish_chevron.Size = UDim2_new(0, 20, 1, 0)
    fish_chevron.Position = UDim2_new(1, -12, 0, 0)
    fish_chevron.BackgroundTransparency = 1
    fish_chevron.Text = "▼"
    fish_chevron.TextColor3 = ACCENT_COLOR
    fish_chevron.TextSize = 7
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

    local amount_row = Instance_new("Frame")
    amount_row.Name = "3_AmountRow"
    amount_row.LayoutOrder = 3
    amount_row.Size = UDim2_new(1, 0, 0, 22)
    amount_row.BackgroundTransparency = 1
    amount_row.Active = false
    amount_row.Parent = byname_content

    local amount_lbl = Instance_new("TextLabel")
    amount_lbl.Size = UDim2_new(0.45, 0, 1, 0)
    amount_lbl.BackgroundTransparency = 1
    amount_lbl.Text = "Amount Fish Name"
    amount_lbl.TextColor3 = TEXT_COLOR
    amount_lbl.TextSize = 10
    amount_lbl.FontFace = font_bold
    amount_lbl.TextXAlignment = Enum.TextXAlignment.Left
    amount_lbl.Parent = amount_row

    qty_box = Instance_new("TextBox")
    qty_box.Size = UDim2_new(0.55, 0, 1, 0)
    qty_box.Position = UDim2_new(0.45, 0, 0, 0)
    qty_box.BackgroundColor3 = INPUT_BG_COLOR
    qty_box.Text = tostring(config.quantity)
    qty_box.TextColor3 = TEXT_COLOR
    qty_box.TextSize = 10
    qty_box.FontFace = font_face
    qty_box.TextXAlignment = Enum.TextXAlignment.Center
    qty_box.ClearTextOnFocus = false
    qty_box.Parent = amount_row

    local qty_c = Instance_new("UICorner")
    qty_c.CornerRadius = UDim_new(0, 4)
    qty_c.Parent = qty_box

    local qty_stroke = Instance_new("UIStroke")
    qty_stroke.Color = BORDER_COLOR
    qty_stroke.Thickness = 1
    qty_stroke.Parent = qty_box

    qty_box:GetPropertyChangedSignal("Text"):Connect(function()
        local text = qty_box.Text
        local val = tonumber(text)
        if val and val >= 0 then
            config.quantity = math_floor(val)
            save_config()
        elseif text == "" then
            config.quantity = 0
            save_config()
        end
    end)

    qty_box.FocusLost:Connect(function()
        local text = qty_box.Text
        local val = (text == "") and 0 or (tonumber(text) or config.quantity)
        task_defer(function()
            sync_qty_boxes(val)
        end)
    end)

    local refresh_btn = Instance_new("TextButton")
    refresh_btn.Name = "4_RefreshButton"
    refresh_btn.LayoutOrder = 4
    refresh_btn.Size = UDim2_new(1, 0, 0, 26)
    refresh_btn.BackgroundColor3 = BTN_BG_COLOR
    refresh_btn.Text = "Refresh Fish Items"
    refresh_btn.TextColor3 = ACCENT_COLOR
    refresh_btn.TextSize = 10
    refresh_btn.FontFace = font_bold
    refresh_btn.Active = true
    refresh_btn.Parent = byname_content

    local refresh_btn_c = Instance_new("UICorner")
    refresh_btn_c.CornerRadius = UDim_new(0, 5)
    refresh_btn_c.Parent = refresh_btn

    local refresh_btn_stroke = Instance_new("UIStroke")
    refresh_btn_stroke.Color = BORDER_COLOR
    refresh_btn_stroke.Thickness = 1
    refresh_btn_stroke.Parent = refresh_btn

    refresh_btn.MouseEnter:Connect(function()
        refresh_btn.BackgroundColor3 = BTN_HOVER_COLOR
    end)
    refresh_btn.MouseLeave:Connect(function()
        refresh_btn.BackgroundColor3 = BTN_BG_COLOR
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

    byname_toggle_ctrl = create_toggle(byname_content, "Start Trade ByName", (config.enabled and config.trade_fish_enabled), function(active)
        if active then
            if qty_box and qty_box.Text ~= "" then
                local num = tonumber(qty_box.Text)
                if num and num >= 0 then
                    sync_qty_boxes(math_floor(num))
                end
            end
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
            cache.fish_status_text = "Idle"
            cache.fish_status_details = ""
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

    -- Panel: Trade Enchant Stone
    local enchant_content = create_accordion(settings_panel, "Trade Enchant Stone")
    local enchant_status_box = Instance_new("Frame")
    enchant_status_box.Name = "1_StatusBox"
    enchant_status_box.LayoutOrder = 1
    enchant_status_box.Size = UDim2_new(1, 0, 0, 58)
    enchant_status_box.AutomaticSize = Enum.AutomaticSize.Y
    enchant_status_box.BackgroundColor3 = CARD_COLOR
    enchant_status_box.BackgroundTransparency = 0
    enchant_status_box.BorderSizePixel = 0
    enchant_status_box.Parent = enchant_content

    local enchant_status_box_pad = Instance_new("UIPadding")
    enchant_status_box_pad.PaddingBottom = UDim_new(0, 6)
    enchant_status_box_pad.PaddingRight = UDim_new(0, 10)
    enchant_status_box_pad.Parent = enchant_status_box

    local enchant_status_box_c = Instance_new("UICorner")
    enchant_status_box_c.CornerRadius = UDim_new(0, 6)
    enchant_status_box_c.Parent = enchant_status_box

    local enchant_status_box_stroke = Instance_new("UIStroke")
    enchant_status_box_stroke.Color = BORDER_COLOR
    enchant_status_box_stroke.Thickness = 1
    enchant_status_box_stroke.Parent = enchant_status_box

    local enchant_status_title = Instance_new("TextLabel")
    enchant_status_title.Size = UDim2_new(1, -10, 0, 16)
    enchant_status_title.Position = UDim2_new(0, 10, 0, 6)
    enchant_status_title.BackgroundTransparency = 1
    enchant_status_title.Text = "Status"
    enchant_status_title.TextColor3 = ACCENT_COLOR
    enchant_status_title.TextSize = 10
    enchant_status_title.FontFace = font_bold
    enchant_status_title.TextXAlignment = Enum.TextXAlignment.Left
    enchant_status_title.Parent = enchant_status_box

    enchant_status_val_lbl = Instance_new("TextLabel")
    enchant_status_val_lbl.Size = UDim2_new(1, -20, 0, 30)
    enchant_status_val_lbl.Position = UDim2_new(0, 10, 0, 22)
    enchant_status_val_lbl.AutomaticSize = Enum.AutomaticSize.Y
    enchant_status_val_lbl.BackgroundTransparency = 1
    enchant_status_val_lbl.Text = "Idle"
    enchant_status_val_lbl.TextColor3 = TEXT_COLOR
    enchant_status_val_lbl.TextSize = 10
    enchant_status_val_lbl.FontFace = font_face
    enchant_status_val_lbl.TextXAlignment = Enum.TextXAlignment.Left
    enchant_status_val_lbl.TextYAlignment = Enum.TextYAlignment.Top
    enchant_status_val_lbl.TextWrapped = true
    enchant_status_val_lbl.Parent = enchant_status_box

    local stone_row = Instance_new("Frame")
    stone_row.Name = "2_StoneRow"
    stone_row.LayoutOrder = 2
    stone_row.Size = UDim2_new(1, 0, 0, 22)
    stone_row.BackgroundTransparency = 1
    stone_row.Active = false
    stone_row.Parent = enchant_content

    local stone_lbl = Instance_new("TextLabel")
    stone_lbl.Size = UDim2_new(0.45, 0, 1, 0)
    stone_lbl.BackgroundTransparency = 1
    stone_lbl.Text = "Stone Type"
    stone_lbl.TextColor3 = TEXT_COLOR
    stone_lbl.TextSize = 10
    stone_lbl.FontFace = font_bold
    stone_lbl.TextXAlignment = Enum.TextXAlignment.Left
    stone_lbl.Parent = stone_row

    enchant_dropdown_btn = Instance_new("TextButton")
    enchant_dropdown_btn.Size = UDim2_new(0.55, 0, 1, 0)
    enchant_dropdown_btn.Position = UDim2_new(0.45, 0, 0, 0)
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
    enchant_dropdown_btn.TextSize = 10
    enchant_dropdown_btn.FontFace = font_face
    enchant_dropdown_btn.TextXAlignment = Enum.TextXAlignment.Left
    enchant_dropdown_btn.Active = true
    enchant_dropdown_btn.Parent = stone_row

    local enchant_dropdown_c = Instance_new("UICorner")
    enchant_dropdown_c.CornerRadius = UDim_new(0, 4)
    enchant_dropdown_c.Parent = enchant_dropdown_btn

    local enchant_dropdown_stroke = Instance_new("UIStroke")
    enchant_dropdown_stroke.Color = BORDER_COLOR
    enchant_dropdown_stroke.Thickness = 1
    enchant_dropdown_stroke.Parent = enchant_dropdown_btn

    local enchant_dropdown_pad = Instance_new("UIPadding")
    enchant_dropdown_pad.PaddingLeft = UDim_new(0, 8)
    enchant_dropdown_pad.PaddingRight = UDim_new(0, 8)
    enchant_dropdown_pad.Parent = enchant_dropdown_btn

    local enchant_chevron = Instance_new("TextLabel")
    enchant_chevron.Size = UDim2_new(0, 20, 1, 0)
    enchant_chevron.Position = UDim2_new(1, -12, 0, 0)
    enchant_chevron.BackgroundTransparency = 1
    enchant_chevron.Text = "▼"
    enchant_chevron.TextColor3 = ACCENT_COLOR
    enchant_chevron.TextSize = 7
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

    local es_amount_row = Instance_new("Frame")
    es_amount_row.Name = "3_AmountRow"
    es_amount_row.LayoutOrder = 3
    es_amount_row.Size = UDim2_new(1, 0, 0, 22)
    es_amount_row.BackgroundTransparency = 1
    es_amount_row.Active = false
    es_amount_row.Parent = enchant_content

    local es_amount_lbl = Instance_new("TextLabel")
    es_amount_lbl.Size = UDim2_new(0.45, 0, 1, 0)
    es_amount_lbl.BackgroundTransparency = 1
    es_amount_lbl.Text = "Amount Enchant Stone"
    es_amount_lbl.TextColor3 = TEXT_COLOR
    es_amount_lbl.TextSize = 10
    es_amount_lbl.FontFace = font_bold
    es_amount_lbl.TextXAlignment = Enum.TextXAlignment.Left
    es_amount_lbl.Parent = es_amount_row

    es_qty_box = Instance_new("TextBox")
    es_qty_box.Size = UDim2_new(0.55, 0, 1, 0)
    es_qty_box.Position = UDim2_new(0.45, 0, 0, 0)
    es_qty_box.BackgroundColor3 = INPUT_BG_COLOR
    es_qty_box.Text = tostring(config.quantity)
    es_qty_box.TextColor3 = TEXT_COLOR
    es_qty_box.TextSize = 10
    es_qty_box.FontFace = font_face
    es_qty_box.TextXAlignment = Enum.TextXAlignment.Center
    es_qty_box.ClearTextOnFocus = false
    es_qty_box.Parent = es_amount_row

    local es_qty_c = Instance_new("UICorner")
    es_qty_c.CornerRadius = UDim_new(0, 4)
    es_qty_c.Parent = es_qty_box

    local es_qty_stroke = Instance_new("UIStroke")
    es_qty_stroke.Color = BORDER_COLOR
    es_qty_stroke.Thickness = 1
    es_qty_stroke.Parent = es_qty_box

    es_qty_box:GetPropertyChangedSignal("Text"):Connect(function()
        local text = es_qty_box.Text
        local val = tonumber(text)
        if val and val >= 0 then
            config.quantity = math_floor(val)
            save_config()
        elseif text == "" then
            config.quantity = 0
            save_config()
        end
    end)

    es_qty_box.FocusLost:Connect(function()
        local text = es_qty_box.Text
        local val = (text == "") and 0 or (tonumber(text) or config.quantity)
        task_defer(function()
            sync_qty_boxes(val)
        end)
    end)

    local es_refresh = Instance_new("TextButton")
    es_refresh.Name = "4_RefreshButton"
    es_refresh.LayoutOrder = 4
    es_refresh.Size = UDim2_new(1, 0, 0, 26)
    es_refresh.BackgroundColor3 = BTN_BG_COLOR
    es_refresh.Text = "Check Enchant Stones"
    es_refresh.TextColor3 = ACCENT_COLOR
    es_refresh.TextSize = 10
    es_refresh.FontFace = font_bold
    es_refresh.Active = true
    es_refresh.Parent = enchant_content

    local es_refresh_c = Instance_new("UICorner")
    es_refresh_c.CornerRadius = UDim_new(0, 5)
    es_refresh_c.Parent = es_refresh

    local es_refresh_stroke = Instance_new("UIStroke")
    es_refresh_stroke.Color = BORDER_COLOR
    es_refresh_stroke.Thickness = 1
    es_refresh_stroke.Parent = es_refresh

    es_refresh.MouseEnter:Connect(function()
        es_refresh.BackgroundColor3 = BTN_HOVER_COLOR
    end)
    es_refresh.MouseLeave:Connect(function()
        es_refresh.BackgroundColor3 = BTN_BG_COLOR
    end)

    es_refresh.MouseButton1Click:Connect(function()
        es_refresh.Text = "Enchant Stones Checked!"
        cache.loaded_enchants = get_owned_enchant_options()
        if enchant_panel.Visible then
            populate_enchants_panel(enchant_dropdown_btn)
        end

        local counts = get_inventory_enchants(true)
        local status_lines = { "Inventory:" }
        local sorted_names = {}
        for name, _ in pairs(counts) do
            table_insert(sorted_names, name)
        end
        table_sort(sorted_names)

        for _, name in ipairs(sorted_names) do
            local qty = counts[name]
            local short_name = string_gsub(name, "%s*Enchant%s*Stone", "")
            if short_name == "" then
                short_name = "Enchant Stone"
            end
            table_insert(status_lines, short_name .. " x" .. qty)
        end

        cache.enchant_status_text = table_concat(status_lines, "\n")
        cache.enchant_status_details = ""
        if enchant_status_val_lbl then
            enchant_status_val_lbl.Text = cache.enchant_status_text
        end

        task_wait(1)
        es_refresh.Text = "Check Enchant Stones"
    end)

    enchant_toggle_ctrl = create_toggle(enchant_content, "Start Trade EnchantStone", (config.enabled and config.trade_enchants_enabled), function(active)
        if active then
            if es_qty_box and es_qty_box.Text ~= "" then
                local num = tonumber(es_qty_box.Text)
                if num and num >= 0 then
                    sync_qty_boxes(math_floor(num))
                end
            end
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
            cache.enchant_status_text = "Idle"
            cache.enchant_status_details = ""
            decline_active_trade()
        end
    end)
    enchant_toggle_ctrl.Frame.LayoutOrder = 5
    enchant_toggle_ctrl.Frame.Name = "5_StartTradeToggle"

    -- Panel: Trade By Rarity
    local rarity_content = create_accordion(settings_panel, "Trade By Rarity")
    local rarity_status_box = Instance_new("Frame")
    rarity_status_box.Name = "1_StatusBox"
    rarity_status_box.LayoutOrder = 1
    rarity_status_box.Size = UDim2_new(1, 0, 0, 58)
    rarity_status_box.AutomaticSize = Enum.AutomaticSize.Y
    rarity_status_box.BackgroundColor3 = CARD_COLOR
    rarity_status_box.BackgroundTransparency = 0
    rarity_status_box.BorderSizePixel = 0
    rarity_status_box.Parent = rarity_content

    local rarity_status_box_pad = Instance_new("UIPadding")
    rarity_status_box_pad.PaddingBottom = UDim_new(0, 6)
    rarity_status_box_pad.PaddingRight = UDim_new(0, 10)
    rarity_status_box_pad.Parent = rarity_status_box

    local rarity_status_box_c = Instance_new("UICorner")
    rarity_status_box_c.CornerRadius = UDim_new(0, 6)
    rarity_status_box_c.Parent = rarity_status_box

    local rarity_status_box_stroke = Instance_new("UIStroke")
    rarity_status_box_stroke.Color = BORDER_COLOR
    rarity_status_box_stroke.Thickness = 1
    rarity_status_box_stroke.Parent = rarity_status_box

    local rarity_status_title = Instance_new("TextLabel")
    rarity_status_title.Size = UDim2_new(1, -10, 0, 16)
    rarity_status_title.Position = UDim2_new(0, 10, 0, 6)
    rarity_status_title.BackgroundTransparency = 1
    rarity_status_title.Text = "Status"
    rarity_status_title.TextColor3 = ACCENT_COLOR
    rarity_status_title.TextSize = 10
    rarity_status_title.FontFace = font_bold
    rarity_status_title.TextXAlignment = Enum.TextXAlignment.Left
    rarity_status_title.Parent = rarity_status_box

    rarity_status_val_lbl = Instance_new("TextLabel")
    rarity_status_val_lbl.Size = UDim2_new(1, -20, 0, 30)
    rarity_status_val_lbl.Position = UDim2_new(0, 10, 0, 22)
    rarity_status_val_lbl.AutomaticSize = Enum.AutomaticSize.Y
    rarity_status_val_lbl.BackgroundTransparency = 1
    rarity_status_val_lbl.Text = "Idle"
    rarity_status_val_lbl.TextColor3 = TEXT_COLOR
    rarity_status_val_lbl.TextSize = 10
    rarity_status_val_lbl.FontFace = font_face
    rarity_status_val_lbl.TextXAlignment = Enum.TextXAlignment.Left
    rarity_status_val_lbl.TextYAlignment = Enum.TextYAlignment.Top
    rarity_status_val_lbl.TextWrapped = true
    rarity_status_val_lbl.Parent = rarity_status_box

    local r_row = Instance_new("Frame")
    r_row.Name = "2_RarityRow"
    r_row.LayoutOrder = 2
    r_row.Size = UDim2_new(1, 0, 0, 22)
    r_row.BackgroundTransparency = 1
    r_row.Active = false
    r_row.Parent = rarity_content

    local r_lbl = Instance_new("TextLabel")
    r_lbl.Size = UDim2_new(0.45, 0, 1, 0)
    r_lbl.BackgroundTransparency = 1
    r_lbl.Text = "Select Rarity"
    r_lbl.TextColor3 = TEXT_COLOR
    r_lbl.TextSize = 10
    r_lbl.FontFace = font_bold
    r_lbl.TextXAlignment = Enum.TextXAlignment.Left
    r_lbl.Parent = r_row

    rarity_dropdown_btn = Instance_new("TextButton")
    rarity_dropdown_btn.Size = UDim2_new(0.55, 0, 1, 0)
    rarity_dropdown_btn.Position = UDim2_new(0.45, 0, 0, 0)
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
    rarity_dropdown_btn.TextSize = 10
    rarity_dropdown_btn.FontFace = font_face
    rarity_dropdown_btn.TextXAlignment = Enum.TextXAlignment.Left
    rarity_dropdown_btn.Active = true
    rarity_dropdown_btn.Parent = r_row

    local rarity_dropdown_c = Instance_new("UICorner")
    rarity_dropdown_c.CornerRadius = UDim_new(0, 4)
    rarity_dropdown_c.Parent = rarity_dropdown_btn

    local rarity_dropdown_stroke = Instance_new("UIStroke")
    rarity_dropdown_stroke.Color = BORDER_COLOR
    rarity_dropdown_stroke.Thickness = 1
    rarity_dropdown_stroke.Parent = rarity_dropdown_btn

    local rarity_dropdown_pad = Instance_new("UIPadding")
    rarity_dropdown_pad.PaddingLeft = UDim_new(0, 8)
    rarity_dropdown_pad.PaddingRight = UDim_new(0, 8)
    rarity_dropdown_pad.Parent = rarity_dropdown_btn

    local rarity_chevron = Instance_new("TextLabel")
    rarity_chevron.Size = UDim2_new(0, 20, 1, 0)
    rarity_chevron.Position = UDim2_new(1, -12, 0, 0)
    rarity_chevron.BackgroundTransparency = 1
    rarity_chevron.Text = "▼"
    rarity_chevron.TextColor3 = ACCENT_COLOR
    rarity_chevron.TextSize = 7
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

    local r_amount_row = Instance_new("Frame")
    r_amount_row.Name = "3_AmountRow"
    r_amount_row.LayoutOrder = 3
    r_amount_row.Size = UDim2_new(1, 0, 0, 22)
    r_amount_row.BackgroundTransparency = 1
    r_amount_row.Active = false
    r_amount_row.Parent = rarity_content

    local r_amount_lbl = Instance_new("TextLabel")
    r_amount_lbl.Size = UDim2_new(0.45, 0, 1, 0)
    r_amount_lbl.BackgroundTransparency = 1
    r_amount_lbl.Text = "Amount Fish Rarity"
    r_amount_lbl.TextColor3 = TEXT_COLOR
    r_amount_lbl.TextSize = 10
    r_amount_lbl.FontFace = font_bold
    r_amount_lbl.TextXAlignment = Enum.TextXAlignment.Left
    r_amount_lbl.Parent = r_amount_row

    r_qty_box = Instance_new("TextBox")
    r_qty_box.Size = UDim2_new(0.55, 0, 1, 0)
    r_qty_box.Position = UDim2_new(0.45, 0, 0, 0)
    r_qty_box.BackgroundColor3 = INPUT_BG_COLOR
    r_qty_box.Text = tostring(config.quantity)
    r_qty_box.TextColor3 = TEXT_COLOR
    r_qty_box.TextSize = 10
    r_qty_box.FontFace = font_face
    r_qty_box.TextXAlignment = Enum.TextXAlignment.Center
    r_qty_box.ClearTextOnFocus = false
    r_qty_box.Parent = r_amount_row

    local r_qty_c = Instance_new("UICorner")
    r_qty_c.CornerRadius = UDim_new(0, 4)
    r_qty_c.Parent = r_qty_box

    local r_qty_stroke = Instance_new("UIStroke")
    r_qty_stroke.Color = BORDER_COLOR
    r_qty_stroke.Thickness = 1
    r_qty_stroke.Parent = r_qty_box

    r_qty_box:GetPropertyChangedSignal("Text"):Connect(function()
        local text = r_qty_box.Text
        local val = tonumber(text)
        if val and val >= 0 then
            config.quantity = math_floor(val)
            save_config()
        elseif text == "" then
            config.quantity = 0
            save_config()
        end
    end)

    r_qty_box.FocusLost:Connect(function()
        local text = r_qty_box.Text
        local val = (text == "") and 0 or (tonumber(text) or config.quantity)
        task_defer(function()
            sync_qty_boxes(val)
        end)
    end)

    local r_refresh = Instance_new("TextButton")
    r_refresh.Name = "4_RefreshButton"
    r_refresh.LayoutOrder = 4
    r_refresh.Size = UDim2_new(1, 0, 0, 26)
    r_refresh.BackgroundColor3 = BTN_BG_COLOR
    r_refresh.Text = "Refresh Fish Rarity"
    r_refresh.TextColor3 = ACCENT_COLOR
    r_refresh.TextSize = 10
    r_refresh.FontFace = font_bold
    r_refresh.Active = true
    r_refresh.Parent = rarity_content

    local r_refresh_c = Instance_new("UICorner")
    r_refresh_c.CornerRadius = UDim_new(0, 5)
    r_refresh_c.Parent = r_refresh

    local r_refresh_stroke = Instance_new("UIStroke")
    r_refresh_stroke.Color = BORDER_COLOR
    r_refresh_stroke.Thickness = 1
    r_refresh_stroke.Parent = r_refresh

    r_refresh.MouseEnter:Connect(function()
        r_refresh.BackgroundColor3 = BTN_HOVER_COLOR
    end)
    r_refresh.MouseLeave:Connect(function()
        r_refresh.BackgroundColor3 = BTN_BG_COLOR
    end)

    r_refresh.MouseButton1Click:Connect(function()
        r_refresh.Text = "Rarity Fish Refreshed!"
        task_wait(1)
        r_refresh.Text = "Refresh Fish Rarity"
    end)

    rarity_toggle_ctrl = create_toggle(rarity_content, "Start Trade ByRarity", (config.enabled and config.trade_rarity_enabled), function(active)
        if active then
            if r_qty_box and r_qty_box.Text ~= "" then
                local num = tonumber(r_qty_box.Text)
                if num and num >= 0 then
                    sync_qty_boxes(math_floor(num))
                end
            end
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
            cache.rarity_status_text = "Idle"
            cache.rarity_status_details = ""
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

    -- Panel: Trade By Coin
    local coin_content = create_accordion(settings_panel, "Trade By Coin")
    local coin_status_box = Instance_new("Frame")
    coin_status_box.Name = "1_StatusBox"
    coin_status_box.LayoutOrder = 1
    coin_status_box.Size = UDim2_new(1, 0, 0, 58)
    coin_status_box.AutomaticSize = Enum.AutomaticSize.Y
    coin_status_box.BackgroundColor3 = CARD_COLOR
    coin_status_box.BackgroundTransparency = 0
    coin_status_box.BorderSizePixel = 0
    coin_status_box.Parent = coin_content

    local coin_status_box_pad = Instance_new("UIPadding")
    coin_status_box_pad.PaddingBottom = UDim_new(0, 6)
    coin_status_box_pad.PaddingRight = UDim_new(0, 10)
    coin_status_box_pad.Parent = coin_status_box

    local coin_status_box_c = Instance_new("UICorner")
    coin_status_box_c.CornerRadius = UDim_new(0, 6)
    coin_status_box_c.Parent = coin_status_box

    local coin_status_box_stroke = Instance_new("UIStroke")
    coin_status_box_stroke.Color = BORDER_COLOR
    coin_status_box_stroke.Thickness = 1
    coin_status_box_stroke.Parent = coin_status_box

    local coin_status_title = Instance_new("TextLabel")
    coin_status_title.Size = UDim2_new(1, -10, 0, 16)
    coin_status_title.Position = UDim2_new(0, 10, 0, 6)
    coin_status_title.BackgroundTransparency = 1
    coin_status_title.Text = "Status"
    coin_status_title.TextColor3 = ACCENT_COLOR
    coin_status_title.TextSize = 10
    coin_status_title.FontFace = font_bold
    coin_status_title.TextXAlignment = Enum.TextXAlignment.Left
    coin_status_title.Parent = coin_status_box

    coin_status_val_lbl = Instance_new("TextLabel")
    coin_status_val_lbl.Size = UDim2_new(1, -20, 0, 30)
    coin_status_val_lbl.Position = UDim2_new(0, 10, 0, 22)
    coin_status_val_lbl.AutomaticSize = Enum.AutomaticSize.Y
    coin_status_val_lbl.BackgroundTransparency = 1
    coin_status_val_lbl.Text = "Idle"
    coin_status_val_lbl.TextColor3 = TEXT_COLOR
    coin_status_val_lbl.TextSize = 10
    coin_status_val_lbl.FontFace = font_face
    coin_status_val_lbl.TextXAlignment = Enum.TextXAlignment.Left
    coin_status_val_lbl.TextYAlignment = Enum.TextYAlignment.Top
    coin_status_val_lbl.TextWrapped = true
    coin_status_val_lbl.Parent = coin_status_box

    local coin_target_row = Instance_new("Frame")
    coin_target_row.Name = "2_CoinTargetRow"
    coin_target_row.LayoutOrder = 2
    coin_target_row.Size = UDim2_new(1, 0, 0, 22)
    coin_target_row.BackgroundTransparency = 1
    coin_target_row.Active = false
    coin_target_row.Parent = coin_content

    local coin_target_lbl = Instance_new("TextLabel")
    coin_target_lbl.Size = UDim2_new(0.45, 0, 1, 0)
    coin_target_lbl.BackgroundTransparency = 1
    coin_target_lbl.Text = "Target Coin Value"
    coin_target_lbl.TextColor3 = TEXT_COLOR
    coin_target_lbl.TextSize = 10
    coin_target_lbl.FontFace = font_bold
    coin_target_lbl.TextXAlignment = Enum.TextXAlignment.Left
    coin_target_lbl.Parent = coin_target_row

    local coin_target_box = Instance_new("TextBox")
    coin_target_box.Size = UDim2_new(0.55, 0, 1, 0)
    coin_target_box.Position = UDim2_new(0.45, 0, 0, 0)
    coin_target_box.BackgroundColor3 = INPUT_BG_COLOR
    coin_target_box.Text = format_number(config.trade_coin_target or 8000000)
    coin_target_box.TextColor3 = TEXT_COLOR
    coin_target_box.TextSize = 10
    coin_target_box.FontFace = font_face
    coin_target_box.TextXAlignment = Enum.TextXAlignment.Center
    coin_target_box.ClearTextOnFocus = false
    coin_target_box.Parent = coin_target_row

    local coin_target_c = Instance_new("UICorner")
    coin_target_c.CornerRadius = UDim_new(0, 4)
    coin_target_c.Parent = coin_target_box

    local coin_target_stroke = Instance_new("UIStroke")
    coin_target_stroke.Color = BORDER_COLOR
    coin_target_stroke.Thickness = 1
    coin_target_stroke.Parent = coin_target_box

    coin_target_box:GetPropertyChangedSignal("Text"):Connect(function()
        local text = coin_target_box.Text
        local parsed = parse_coin_input(text)
        if parsed and parsed > 0 then
            config.trade_coin_target = parsed
            save_config()
        end
    end)

    coin_target_box.FocusLost:Connect(function()
        local text = coin_target_box.Text
        local parsed = parse_coin_input(text)
        if parsed and parsed > 0 then
            config.trade_coin_target = parsed
            coin_target_box.Text = format_number(parsed)
            save_config()
        else
            coin_target_box.Text = format_number(config.trade_coin_target or 8000000)
        end
    end)

    local coin_check_btn = Instance_new("TextButton")
    coin_check_btn.Name = "3_CheckWorthButton"
    coin_check_btn.LayoutOrder = 3
    coin_check_btn.Size = UDim2_new(1, 0, 0, 26)
    coin_check_btn.BackgroundColor3 = BTN_BG_COLOR
    coin_check_btn.Text = "Check Bag Coin Worth"
    coin_check_btn.TextColor3 = ACCENT_COLOR
    coin_check_btn.TextSize = 10
    coin_check_btn.FontFace = font_bold
    coin_check_btn.Active = true
    coin_check_btn.Parent = coin_content

    local coin_check_c = Instance_new("UICorner")
    coin_check_c.CornerRadius = UDim_new(0, 5)
    coin_check_c.Parent = coin_check_btn

    local coin_check_stroke = Instance_new("UIStroke")
    coin_check_stroke.Color = BORDER_COLOR
    coin_check_stroke.Thickness = 1
    coin_check_stroke.Parent = coin_check_btn

    coin_check_btn.MouseEnter:Connect(function()
        coin_check_btn.BackgroundColor3 = BTN_HOVER_COLOR
    end)
    coin_check_btn.MouseLeave:Connect(function()
        coin_check_btn.BackgroundColor3 = BTN_BG_COLOR
    end)

    coin_check_btn.MouseButton1Click:Connect(function()
        local total_worth = 0
        local total_fish = 0
        local inv = player_data and player_data:Get("Inventory")
        local itms = inv and inv.Items or {}
        for _, itm in ipairs(itms) do
            local is_fav = (itm.Favorited == true or (itm.Metadata and itm.Metadata.Favorited == true))
            if not is_fav then
                local val = calculate_fish_coin_value(itm)
                if val > 0 then
                    total_worth = total_worth + val
                    total_fish = total_fish + 1
                end
            end
        end

        local worth_str = format_number(total_worth)
        coin_check_btn.Text = string_format("Bag: %d Fish = %s Coins", total_fish, worth_str)
        set_status_msg("coin", string_format("Bag Inventory Worth: %s Coins across %d fish", worth_str, total_fish))
        task_delay(4, function()
            if coin_check_btn and coin_check_btn.Parent then
                coin_check_btn.Text = "Check Bag Coin Worth"
            end
        end)
    end)

    coin_toggle_ctrl = create_toggle(coin_content, "Start Trade By Coin", (config.enabled and config.trade_coin_enabled), function(active)
        if active then
            if coin_target_box and coin_target_box.Text ~= "" then
                local parsed = parse_coin_input(coin_target_box.Text)
                if parsed and parsed > 0 then
                    config.trade_coin_target = parsed
                    save_config()
                end
            end
            cache.stats.coin.success_trades = 0
            cache.stats.coin.last_items = 0
            cache.stats.coin.total_items = 0
            cache.stats.coin.total_coins = 0
            cache.stats.coin.attempts = 0
            cache.stats.coin.failed = 0
            update_mode_status("coin")

            config.trade_coin_enabled = true
            config.enabled = true
            sync_mode_toggles("coin")
            cache.processed_trades = {}
            run_auto_trade_loop()
        else
            config.enabled = false
            config.trade_coin_enabled = false
            cache.coin_status_text = "Idle"
            cache.coin_status_details = ""
            decline_active_trade()
        end
    end)
    coin_toggle_ctrl.Frame.LayoutOrder = 4
    coin_toggle_ctrl.Frame.Name = "4_StartTradeToggle"

    settings_panel.CanvasSize = UDim2_new(0, 0, 0, settings_layout.AbsoluteContentSize.Y + 20)
    settings_layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        settings_panel.CanvasSize = UDim2_new(0, 0, 0, settings_layout.AbsoluteContentSize.Y + 20)
    end)

    -- Status Update Loop
    task_spawn(function()
        while is_running and gui and gui.Parent do
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
            if rarity_status_val_lbl then
                if cache.rarity_status_details == "" then
                    rarity_status_val_lbl.Text = cache.rarity_status_text
                else
                    rarity_status_val_lbl.Text = cache.rarity_status_text .. "\n" .. cache.rarity_status_details
                end
            end
            if coin_status_val_lbl then
                if cache.coin_status_details == "" then
                    coin_status_val_lbl.Text = cache.coin_status_text
                else
                    coin_status_val_lbl.Text = cache.coin_status_text .. "\n" .. cache.coin_status_details
                end
            end

            if byname_toggle_ctrl then
                byname_toggle_ctrl.set_state(config.enabled and config.trade_fish_enabled)
            end
            if enchant_toggle_ctrl then
                enchant_toggle_ctrl.set_state(config.enabled and config.trade_enchants_enabled)
            end
            if rarity_toggle_ctrl then
                rarity_toggle_ctrl.set_state(config.enabled and config.trade_rarity_enabled)
            end
            if coin_toggle_ctrl then
                coin_toggle_ctrl.set_state(config.enabled and config.trade_coin_enabled)
            end

            task_wait(0.5)
        end
    end)
end

-- Cleanup & Init
local function cleanup_all()
    is_running = false
    config.enabled = false
    config.trade_fish_enabled = false
    config.trade_enchants_enabled = false
    config.trade_rarity_enabled = false
    config.trade_coin_enabled = false
    cache.is_trading_active = false
    cache.loop_running = false

    if decline_active_trade then
        pcall(decline_active_trade)
    end

    _G.KeenanHub_AutoTrade_ScriptID = nil
    script_id = nil

    if trade_ended_conn then
        pcall(function() trade_ended_conn:Disconnect() end)
        trade_ended_conn = nil
    end

    for _, c in ipairs(script_connections) do
        pcall(function()
            if typeof(c) == "RBXScriptConnection" or (type(c) == "table" and c.Disconnect) then
                c:Disconnect()
            elseif type(c) == "table" and c.Destroy then
                c:Destroy()
            elseif type(c) == "function" then
                c()
            end
        end)
    end
    script_connections = {}

    pcall(function()
        local core = gethui and gethui() or core_gui
        local old = core:FindFirstChild("KeenanHub_AutoTrade") or core:FindFirstChild("NoirHub_AutoTrade") or core:FindFirstChild("AutoTrade")
        if old then old:Destroy() end
    end)
    pcall(function()
        local pgui = local_player:FindFirstChild("PlayerGui")
        local old = pgui and (pgui:FindFirstChild("KeenanHub_AutoTrade") or pgui:FindFirstChild("NoirHub_AutoTrade") or pgui:FindFirstChild("AutoTrade"))
        if old then old:Destroy() end
    end)

    _G.AutoTradeConfig = nil
    _G.AutoTradeCache = nil
    _G.run_auto_trade_loop = nil
    _G.KeenanHub_AutoTrade_Cleanup = nil
    _G.NoirHub_AutoTrade_Cleanup = nil
end

_G.KeenanHub_AutoTrade_Cleanup = cleanup_all
_G.NoirHub_AutoTrade_Cleanup = cleanup_all

pcall(create_ui)
