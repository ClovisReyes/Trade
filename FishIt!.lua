local ipairs, pairs, tostring, tonumber, pcall, tick, os_clock = ipairs, pairs, tostring, tonumber, pcall, tick, os.clock
local table_find, table_insert, table_remove, table_sort, table_concat = table.find, table.insert, table.remove, table.sort, table.concat
local string_lower, string_find, string_gsub, string_format, string_match, string_sub = string.lower, string.find, string.gsub, string.format, string.match, string.sub
local math_max, math_min, math_floor, math_huge = math.max, math.min, math.floor, math.huge
local task_wait, task_spawn, task_delay = task.wait, task.spawn, task.delay

if _G.NoirHub_AutoTrade_Cleanup then pcall(_G.NoirHub_AutoTrade_Cleanup) end
local script_id = os_clock()
_G.NoirHub_AutoTrade_ScriptID = script_id

local cloneref = cloneref or function(ref) return ref end
local players = cloneref(game:GetService("Players"))
local local_player = players.LocalPlayer
local player_gui = cloneref(local_player:WaitForChild("PlayerGui"))
local user_input_service = cloneref(game:GetService("UserInputService"))
local tween_service = cloneref(game:GetService("TweenService"))
local replicated_storage = cloneref(game:GetService("ReplicatedStorage"))

local variants_folder = replicated_storage:FindFirstChild("Variants")

local variables = {
    replion        = replicated_storage:WaitForChild("Packages"):WaitForChild("Replion"),
    item_utility   = replicated_storage:WaitForChild("Shared"):WaitForChild("ItemUtility"),
    vendor_utility = replicated_storage:WaitForChild("Shared"):WaitForChild("VendorUtility"),
}

local cache, status_labels, toggle_ctrls = nil, {}, {}
local inventory_conn, auto_accept_conn, auto_accept_trade_started_conn, auto_accept_trade_ended_conn
local float_drag_conn, header_drag_conn

local success_replion, replion_mod = pcall(require, variables.replion)
local player_data = success_replion and replion_mod.Client:WaitReplion("Data") or nil
local item_utility = require(variables.item_utility)
local vendor_utility = nil
pcall(function() vendor_utility = require(variables.vendor_utility) end)

local remote_map = {
    SendTradeOffer     = "SendTradeOffer",
    AddItem            = "AddItem",
    SetReady           = "SetReady",
    ConfirmTrade       = "ConfirmTrade",
    TradeOfferReceived = "TradeOfferReceived",
    TradeEnded         = "TradeEnded",
    TradeStarted       = "TradeStarted",
    TradeCompleted     = "TradeCompleted",
    AcceptTradeOffer   = "AcceptTradeOffer",
    CancelTrade        = "CancelTrade",
    DeclineTradeOffer  = "DeclineTradeOffer",
}

local _net_lookup = nil
local function get_net_lookup()
    if _net_lookup then return _net_lookup end
    _net_lookup = {}
    
    -- 1. Ambil remote resmi yang digunakan game dari TradeData.Remotes
    pcall(function()
        local trade_data_mod = replicated_storage:FindFirstChild("Shared") and replicated_storage.Shared:FindFirstChild("Trading") and replicated_storage.Shared.Trading:FindFirstChild("TradeData")
        if trade_data_mod then
            local td = require(trade_data_mod)
            if td and td.Remotes then
                for k, v in pairs(td.Remotes) do
                    _net_lookup[k] = v
                end
            end
        end
    end)

    -- 2. Fallback ke sleitnick_net jika ada yang belum terisi
    pcall(function()
        local net_folder = replicated_storage.Packages._Index["sleitnick_net@0.2.0"].net
        for _, child in ipairs(net_folder:GetChildren()) do
            for logical_name, pattern in pairs(remote_map) do
                if not _net_lookup[logical_name] and string_find(child.Name, pattern, 1, true) then
                    _net_lookup[logical_name] = child
                end
            end
        end
    end)
    return _net_lookup
end

local remote_cache = {}
local trade_remotes = setmetatable({}, {
    __index = function(_, key)
        if remote_cache[key] then return remote_cache[key] end
        local logical_name = remote_map[key]
        if not logical_name then return nil end
        local remote = get_net_lookup()[logical_name]
        if remote then
            local wrapped = setmetatable({
                instance = remote,
                FireServer = function(_, ...) if remote:IsA("RemoteEvent") then remote:FireServer(...) else remote:InvokeServer(...) end end,
                InvokeServer = function(_, ...) if remote:IsA("RemoteFunction") then return remote:InvokeServer(...) else remote:FireServer(...) end end,
                IsA = function(_, className) return remote:IsA(className) end
            }, { __index = function(_, k) return remote[k] end })
            remote_cache[key] = wrapped
            return wrapped
        end
        return nil
    end
})

local config = {
    enabled                = false,
    auto_accept_enabled    = false,
    trade_favorited        = false,
    quantity               = 0,
    target_coin_amount     = 0,
    trade_with             = "",
    trade_fish_enabled     = false,
    trade_enchants_enabled = false,
    trade_coins_enabled    = false,
    trade_rarity_enabled   = false,
    selected_fish          = { "All" },
    selected_tiers         = { "All" },
    selected_mutations     = { "All" },
    selected_items         = { "All" },
}

cache = {
    is_trading_active   = false,
    loop_running        = false,
    processed_trades    = {},
    loaded_fish         = {},
    loaded_enchants     = {},
    loaded_mutations    = {},
    loaded_tiers        = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "SECRET", "Forgotten" },
    loaded_variant_multipliers = {},
    last_failed_offer_time     = nil,
    status_text         = { fish = "Idle", enchant = "Idle", coin = "Idle", rarity = "Idle" },
    status_details      = { fish = "", enchant = "", coin = "", rarity = "" },
    stats = {
        fish    = { success_trades = 0, attempts = 0, failed = 0, last_items = 0, total_items = 0 },
        rarity  = { success_trades = 0, attempts = 0, failed = 0, last_items = 0, total_items = 0 },
        enchant = { success_trades = 0, attempts = 0, failed = 0, last_items = 0, total_items = 0 },
        coin    = { success_trades = 0, attempts = 0, failed = 0, last_items = 0, total_items = 0, total_coins = 0 }
    },
}

_G.AutoTradeConfig = config
_G.AutoTradeCache = cache

local mode_flag_map = {
    fish    = "trade_fish_enabled",
    rarity  = "trade_rarity_enabled",
    enchant = "trade_enchants_enabled",
    coin    = "trade_coins_enabled",
}

local tier_mapping = {
    [1] = "common", [2] = "uncommon", [3] = "rare", [4] = "epic",
    [5] = "legendary", [6] = "mythic", [7] = "secret", [8] = "forgotten",
    [90] = "trophy", [95] = "collectible", [100] = "exclusive", [1000] = "dev"
}

local function load_game_data()
    cache.loaded_tiers = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "SECRET", "Forgotten" }
    cache.loaded_variant_multipliers = {}
    cache.loaded_mutations = {}

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

    if variants_folder then
        for _, variant in ipairs(variants_folder:GetChildren()) do
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
end
pcall(load_game_data)

local function strip_quantity(str) return string_gsub(str, "%s*%(x%d+%)", "") end

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

local function get_item_mutation(item)
    if not item or not item.Metadata then return "None" end
    local v = item.Metadata.VariantId
    if v and v ~= "" and v ~= "None" then return tostring(v) end
    return "None"
end

local function is_item_shiny(item)
    if not item then return false end
    if item.Metadata and item.Metadata.Shiny == true then return true end
    if item.Shiny == true then return true end
    return false
end

local function calculate_fish_coin_value(item)
    if not item or not item.Id then return 0 end
    if vendor_utility then
        local ok, price = pcall(function() return vendor_utility:GetSellPrice(item) end)
        if ok and type(price) == "number" and price > 0 then
            return math_floor(price)
        end
    end

    local item_info = item_utility:GetItemData(item.Id)
    if not item_info or not item_info.Data or item_info.Data.Type ~= "Fish" then
        return 0
    end

    local base_price = tonumber(item_info.SellPrice) or 0
    local mult = 1
    local meta = item.Metadata
    if meta and meta.VariantId and meta.VariantId ~= "" and meta.VariantId ~= "None" then
        local vname = tostring(meta.VariantId)
        local vmult = cache.loaded_variant_multipliers[string_lower(vname)] or cache.loaded_variant_multipliers[vname]
        if vmult then mult = mult * vmult end
    end
    if is_item_shiny(item) then
        mult = mult * (cache.loaded_variant_multipliers["shiny"] or 1.5)
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
            if not is_fav or config.trade_favorited then
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

local function get_inventory_items(type_filter, bypass_favorited)
    local result = {}
    pcall(function()
        if not player_data then return end
        local inv = player_data:Get("Inventory")
        for _, item in ipairs(inv and inv.Items or {}) do
            if item and item.Id then
                local is_fav = (item.Favorited == true or (item.Metadata and item.Metadata.Favorited == true))
                if bypass_favorited or not is_fav or config.trade_favorited then
                    local data = item_utility:GetItemData(item.Id)
                    if data and data.Data then
                        local name = data.Data.Name
                        local item_type = data.Data.Type
                        local match = false
                        if type_filter == "Fish" and item_type == "Fish" then
                            match = true
                        elseif type_filter == "Enchant" and item_type == "Enchant Stones" then
                            match = true
                        end
                        if match then
                            result[name] = (result[name] or 0) + (item.Amount or 1)
                        end
                    end
                end
            end
        end
    end)
    return result
end

local function get_owned_options(type_filter)
    local list, counts = {}, get_inventory_items(type_filter, false)
    for name, qty in pairs(counts) do table_insert(list, name .. " (x" .. qty .. ")") end
    table_sort(list)
    return list
end

local function get_other_players()
    local list = {}
    for _, p in ipairs(players:GetPlayers()) do
        if p ~= local_player then table_insert(list, p.Name) end
    end
    table_sort(list)
    return list
end

local function find_target_player()
    if config.trade_with == "" then return nil end
    local target_clean = string_lower(config.trade_with)
    for _, player in ipairs(players:GetPlayers()) do
        if string_lower(player.Name) == target_clean or string_lower(player.DisplayName) == target_clean then
            return player
        end
    end
    return nil
end

local function should_trade_fish(item_data, inventory_item)
    local is_fav = (inventory_item.Favorited == true or (inventory_item.Metadata and inventory_item.Metadata.Favorited == true))
    if not config.enabled or (is_fav and not config.trade_favorited) then return false end
    local name_match = #config.selected_fish == 0 or table_find(config.selected_fish, "All") ~= nil
    if not name_match then
        local fish_name = string_lower(item_data.Data.Name)
        for _, sel in ipairs(config.selected_fish) do
            if fish_name == string_lower(strip_quantity(sel)) then name_match = true; break end
        end
    end
    local mut_match = #config.selected_mutations == 0 or table_find(config.selected_mutations, "All") ~= nil
    if not mut_match then
        local mut_name = string_lower(get_item_mutation(inventory_item))
        for _, sel in ipairs(config.selected_mutations) do
            if mut_name == string_lower(strip_quantity(sel)) then mut_match = true; break end
        end
    end
    return name_match and mut_match
end

local function should_trade_fish_by_rarity(item_data, inventory_item)
    local is_fav = (inventory_item.Favorited == true or (inventory_item.Metadata and inventory_item.Metadata.Favorited == true))
    if not config.enabled or (is_fav and not config.trade_favorited) then return false end
    local rarity_match = #config.selected_tiers == 0 or table_find(config.selected_tiers, "All") ~= nil
    if not rarity_match then
        local raw_tier = item_data.Data.Tier
        local tier_name = type(raw_tier) == "number" and (tier_mapping[raw_tier] or "") or string_lower(tostring(raw_tier))
        for _, sel in ipairs(config.selected_tiers) do
            if tier_name == string_lower(strip_quantity(sel)) then rarity_match = true; break end
        end
    end
    local mut_match = #config.selected_mutations == 0 or table_find(config.selected_mutations, "All") ~= nil
    if not mut_match then
        local mut_name = string_lower(get_item_mutation(inventory_item))
        for _, sel in ipairs(config.selected_mutations) do
            if mut_name == string_lower(strip_quantity(sel)) then mut_match = true; break end
        end
    end
    return rarity_match and mut_match
end

local function collect_round_robin(items, key_extractor, selected_keys, limit)
    local buckets, bucket_keys, items_to_trade, added = {}, {}, {}, {}
    for _, k in ipairs(selected_keys) do
        local lk = string_lower(strip_quantity(k))
        if lk ~= "all" then buckets[lk] = {}; table_insert(bucket_keys, lk) end
    end
    for _, item in ipairs(items) do
        local k = key_extractor(item)
        if k and buckets[k] then table_insert(buckets[k], item) end
    end
    for pass = 1, 20 do
        if #items_to_trade >= limit then break end
        local added_any = false
        for _, k in ipairs(bucket_keys) do
            if #items_to_trade >= limit then break end
            for _, item in ipairs(buckets[k] or {}) do
                if not added[item.UUID] and not table_find(cache.processed_trades, item.UUID) then
                    added[item.UUID] = true
                    table_insert(items_to_trade, item)
                    added_any = true
                    break
                end
            end
        end
        if not added_any then break end
    end
    return items_to_trade
end

local function get_mode_display_name(mode_name)
    if mode_name == "enchant" then
        if #config.selected_items > 0 and config.selected_items[1] ~= "All" then return table_concat(config.selected_items, "/") end
        return "Enchant Stone"
    elseif mode_name == "fish" then
        if #config.selected_fish > 0 and config.selected_fish[1] ~= "All" then return table_concat(config.selected_fish, "/") end
        return "Fish"
    elseif mode_name == "rarity" then
        if #config.selected_tiers > 0 and config.selected_tiers[1] ~= "All" then
            local names = {}
            for _, tier in ipairs(config.selected_tiers) do
                local t_name = type(tier) == "number" and (tier_mapping[tier] and tier_mapping[tier]:sub(1,1):upper() .. tier_mapping[tier]:sub(2)) or (tostring(tier):sub(1,1):upper() .. tostring(tier):sub(2):lower())
                if t_name and tier ~= "All" then table_insert(names, t_name) end
            end
            if #names > 0 then return table_concat(names, "/") end
        end
        return "Rarity"
    elseif mode_name == "coin" then
        return "Coin"
    end
    return "Items"
end

local function update_status_ui(mode_name)
    local s = cache.stats[mode_name]
    if not s then return end
    local details = ""
    if mode_name == "coin" then
        local target = config.target_coin_amount or 0
        local current = s.total_coins or 0
        local target_str = target == 0 and "∞" or format_number(target)
        details = string_format("Sent: %s / %s Coins (%d fish) | Fails: %d", format_number(current), target_str, s.total_items, s.failed)
    else
        local target = config.quantity
        local current = s.total_items
        local progress = target == 0 and (current .. "/∞") or (current .. "/" .. target)
        details = string_format("Items Sent: %d | Progress: %s | Attempts: %d | Failed: %d", s.total_items, progress, s.attempts, s.failed)
    end
    cache.status_details[mode_name] = details
    local lbl = status_labels[mode_name]
    if lbl then
        lbl.Text = cache.status_details[mode_name] == "" and cache.status_text[mode_name] or (cache.status_text[mode_name] .. "\n" .. cache.status_details[mode_name])
    end
end

local function set_status_msg(mode_name, msg, details_override)
    if msg then cache.status_text[mode_name] = msg end
    if details_override then cache.status_details[mode_name] = details_override end
    update_status_ui(mode_name)
end

local trade_offer_controller = nil
local original_popup = nil
local last_accepted_offer_time = 0

pcall(function()
    local mod = replicated_storage:FindFirstChild("Controllers") and replicated_storage.Controllers:FindFirstChild("Trading") and replicated_storage.Controllers.Trading:FindFirstChild("TradeOfferController")
    if mod then
        trade_offer_controller = require(mod)
        if trade_offer_controller and trade_offer_controller.PopUp then
            original_popup = trade_offer_controller.PopUp
            trade_offer_controller.PopUp = function(self, requester, ...)
                if config.auto_accept_enabled and _G.NoirHub_AutoTrade_ScriptID == script_id then
                    local now = os_clock()
                    if (now - last_accepted_offer_time) >= 2 then
                        last_accepted_offer_time = now
                        pcall(function()
                            if trade_remotes and trade_remotes.AcceptTradeOffer then
                                trade_remotes.AcceptTradeOffer:InvokeServer(requester, true)
                            end
                        end)
                    end
                    return -- Bypass GUI: Mencegah popup [Yes] [No] muncul di layar
                end
                return original_popup(self, requester, ...)
            end
        end
    end
end)

local function close_trading_gui()
    -- Bypass GUI: We don't touch PlayerGui to avoid triggering BAC
end

local auto_accept_active = false
local function toggle_auto_accept(enable)
    if auto_accept_conn then pcall(function() auto_accept_conn:Disconnect() end); auto_accept_conn = nil end
    if auto_accept_trade_started_conn then pcall(function() auto_accept_trade_started_conn:Disconnect() end); auto_accept_trade_started_conn = nil end
    if auto_accept_trade_ended_conn then pcall(function() auto_accept_trade_ended_conn:Disconnect() end); auto_accept_trade_ended_conn = nil end

    config.auto_accept_enabled = enable
    if not trade_remotes or not enable then return end

    auto_accept_conn = trade_remotes.TradeOfferReceived.OnClientEvent:Connect(function(requester)
        if _G.NoirHub_AutoTrade_ScriptID ~= script_id or not config.auto_accept_enabled then return end
        local now = os_clock()
        if (now - last_accepted_offer_time) >= 2 then
            last_accepted_offer_time = now
            pcall(function()
                trade_remotes.AcceptTradeOffer:InvokeServer(requester, true)
            end)
        end
    end)

    auto_accept_trade_ended_conn = trade_remotes.TradeEnded.OnClientEvent:Connect(function()
        if _G.NoirHub_AutoTrade_ScriptID ~= script_id then return end
        auto_accept_active = false
        close_trading_gui()
    end)

    auto_accept_trade_started_conn = trade_remotes.TradeStarted.OnClientEvent:Connect(function()
        if not config.auto_accept_enabled or _G.NoirHub_AutoTrade_ScriptID ~= script_id then return end
        auto_accept_active = true
        task_spawn(function()
            task_wait(0.2)
            if not auto_accept_active or not local_player:GetAttribute("IsTrading") then return end
            pcall(function() trade_remotes.SetReady:InvokeServer(true) end)
            local start_t = tick()
            while config.auto_accept_enabled and auto_accept_active and _G.NoirHub_AutoTrade_ScriptID == script_id and local_player:GetAttribute("IsTrading") and (tick() - start_t) < 45 do
                pcall(function()
                    trade_remotes.ConfirmTrade:InvokeServer()
                    trade_remotes.SetReady:InvokeServer(true)
                end)
                task_wait(0.08)
            end
            close_trading_gui()
        end)
    end)
end

local function listen_for_trade_completion(on_completed)
    local completed, connections = false, {}
    local function trigger_done()
        if completed then return end
        completed = true
        if on_completed then pcall(on_completed) end
    end

    pcall(function()
        local TextChatService = game:GetService("TextChatService")
        if TextChatService then
            table_insert(connections, TextChatService.MessageReceived:Connect(function(msg)
                if not msg or completed then return end
                local lower_t = string_lower(tostring(msg.Text))
                if string_find(lower_t, "completed", 1, true) and (string_find(lower_t, "trade", 1, true) or string_find(lower_t, "with", 1, true)) then
                    trigger_done()
                end
            end))
        end
    end)

    pcall(function()
        if trade_remotes and trade_remotes.TradeCompleted then
            table_insert(connections, trade_remotes.TradeCompleted.OnClientEvent:Connect(trigger_done))
        end
    end)

    pcall(function()
        if trade_remotes and trade_remotes.TradeEnded then
            table_insert(connections, trade_remotes.TradeEnded.OnClientEvent:Connect(trigger_done))
        end
    end)

    return {
        is_completed = function() return completed end,
        disconnect = function() for _, conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end end
    }
end

local function start_trade_session(target_player, mode)
    if not target_player or not trade_remotes then return false, "No remotes" end
    if local_player:GetAttribute("IsTrading") then
        close_trading_gui()
        local clear_start = tick()
        while local_player:GetAttribute("IsTrading") and (tick() - clear_start) < 4 do
            task_wait(0.1)
        end
    end

    if cache.last_failed_offer_time then
        local elapsed = tick() - cache.last_failed_offer_time
        if elapsed < 15 then
            set_status_msg(mode, nil, "Cooldown (" .. string_format("%.1fs", 15 - elapsed) .. ")")
            task_wait(15 - elapsed)
        end
        cache.last_failed_offer_time = nil
    end

    set_status_msg(mode, "Waiting for target to accept offer...")
    
    local success, err = trade_remotes.SendTradeOffer:InvokeServer(target_player)
    if success == false then
        cache.last_failed_offer_time = tick()
        set_status_msg(mode, "Failed: " .. (err or "Declined"))
        return false, err
    end
    

    local start_t = tick()
    while not local_player:GetAttribute("IsTrading") and (tick() - start_t) < 10 do
        task_wait(0.1)
    end
    if not local_player:GetAttribute("IsTrading") then
        cache.last_failed_offer_time = tick()
        set_status_msg(mode, "Trade request timed out")
        return false, "Timeout"
    end
    task_wait(0.3)
    return true
end

local function wait_for_trade_end(mode_name, chat_listener)
    local start_t = tick()
    while local_player:GetAttribute("IsTrading") and tick() - start_t < 30 do
        if _G.NoirHub_AutoTrade_ScriptID ~= script_id or not config.enabled then break end
        if chat_listener and chat_listener.is_completed() then break end
        pcall(function()
            if trade_remotes.SetReady then trade_remotes.SetReady:InvokeServer(true) end
            if trade_remotes.ConfirmTrade then trade_remotes.ConfirmTrade:InvokeServer() end
        end)
        set_status_msg(mode_name, "Accepting & Confirming trade...")
        task_wait(0.08)
    end
end

local function collect_trade_items(mode)
    local inventory = player_data and player_data:Get("Inventory")
    local items = inventory and inventory.Items or {}
    local total_sent = cache.stats[mode].total_items
    local limit = math.min(20, config.quantity > 0 and (config.quantity - total_sent) or 20)
    local items_to_trade = {}

    if mode == "fish" then
        local has_all = #config.selected_fish == 0 or table_find(config.selected_fish, "All") ~= nil
        if #config.selected_fish > 1 and not has_all then
            items_to_trade = collect_round_robin(items, function(it)
                local d = item_utility:GetItemData(it.Id)
                return (d and d.Data and d.Data.Type == "Fish" and should_trade_fish(d, it)) and string_lower(d.Data.Name) or nil
            end, config.selected_fish, limit)
        else
            for _, item in ipairs(items) do
                if #items_to_trade >= limit then break end
                local d = item and item.Id and item_utility:GetItemData(item.Id)
                if d and d.Data and d.Data.Type == "Fish" and should_trade_fish(d, item) then
                    if not table_find(cache.processed_trades, item.UUID) then table_insert(items_to_trade, item) end
                end
            end
        end
    elseif mode == "rarity" then
        local has_all = #config.selected_tiers == 0 or table_find(config.selected_tiers, "All") ~= nil
        if #config.selected_tiers > 1 and not has_all then
            items_to_trade = collect_round_robin(items, function(it)
                local d = item_utility:GetItemData(it.Id)
                if d and d.Data and d.Data.Type == "Fish" and should_trade_fish_by_rarity(d, it) then
                    local raw_tier = d.Data.Tier
                    return type(raw_tier) == "number" and (tier_mapping[raw_tier] or "") or string_lower(tostring(raw_tier))
                end
                return nil
            end, config.selected_tiers, limit)
        else
            for _, item in ipairs(items) do
                if #items_to_trade >= limit then break end
                local d = item and item.Id and item_utility:GetItemData(item.Id)
                if d and d.Data and d.Data.Type == "Fish" and should_trade_fish_by_rarity(d, item) then
                    if not table_find(cache.processed_trades, item.UUID) then table_insert(items_to_trade, item) end
                end
            end
        end
    elseif mode == "enchant" then
        for _, item in ipairs(items) do
            if #items_to_trade >= limit then break end
            if item and item.Id then
                local is_fav = (item.Favorited == true or (item.Metadata and item.Metadata.Favorited == true))
                if not (is_fav and not config.trade_favorited) then
                    local d = item_utility:GetItemData(item.Id)
                    if d and d.Data and d.Data.Type == "Enchant Stones" then
                        local name = d.Data.Name
                        local match = #config.selected_items == 0 or table_find(config.selected_items, "All") ~= nil
                        if not match then
                            for _, sel in ipairs(config.selected_items) do
                                if string_lower(name) == string_lower(strip_quantity(sel)) then match = true; break end
                            end
                        end
                        if match then
                            if not table_find(cache.processed_trades, item.UUID) then table_insert(items_to_trade, item) end
                        end
                    end
                end
            end
        end
    elseif mode == "coin" then
        local target_coins = config.target_coin_amount or 0
        local already_sent = cache.stats.coin.total_coins or 0
        local chosen, _ = select_fish_for_coin_trade(target_coins, already_sent)
        items_to_trade = chosen
    end
    return items_to_trade
end

local function execute_trade(mode)
    cache.processed_trades = {}
    local target_player = find_target_player()
    if not target_player or not player_data then
        set_status_msg(mode, config.trade_with ~= "" and "Waiting: Target player tidak ditemukan di server" or "Waiting: Target player belum dipilih di panel kanan")
        return
    end

    local s = cache.stats[mode]
    if mode == "coin" then
        if config.target_coin_amount > 0 and (s.total_coins or 0) >= config.target_coin_amount then
            config.enabled = false
            config.trade_coins_enabled = false
            if toggle_ctrls.coin then toggle_ctrls.coin.set_state(false) end
            set_status_msg("coin", string_format("Selesai! Berhasil mengirim %s Coins (%d ikan)", format_number(s.total_coins), s.total_items))
            return
        end
    else
        if config.quantity > 0 and s.total_items >= config.quantity then
            config.enabled = false
            local flag_name = mode_flag_map[mode]
            if flag_name then config[flag_name] = false end
            if toggle_ctrls[mode] then toggle_ctrls[mode].set_state(false) end
            set_status_msg(mode, string_format("Selesai! Berhasil mengirim %d/%d item", s.total_items, config.quantity))
            return
        end
    end

    local items_to_trade = collect_trade_items(mode)
    if #items_to_trade == 0 then
        local err_msg = mode == "coin" and "Waiting: Tidak ada ikan yang memenuhi syarat di bag (idle)..." or ("Waiting: Tidak ada " .. get_mode_display_name(mode) .. " yang tersedia di bag (idle)...")
        set_status_msg(mode, err_msg)
        return
    end

    s.attempts = s.attempts + 1
    update_status_ui(mode)

    local success, err = start_trade_session(target_player, mode)
    if not success then s.failed = s.failed + 1; update_status_ui(mode); return end

    local added_items, added_coins = {}, 0
    set_status_msg(mode, "Offer accepted! Adding " .. #items_to_trade .. " item(s)...")
    local category = (mode == "enchant") and "Enchant Stones" or "Fish"
    for idx, item in ipairs(items_to_trade) do
        if not config.enabled or not local_player:GetAttribute("IsTrading") or _G.NoirHub_AutoTrade_ScriptID ~= script_id then break end
        local ok, res = pcall(function() return trade_remotes.AddItem:InvokeServer(category, item.UUID) end)
        if ok and res ~= false then
            table_insert(cache.processed_trades, item.UUID)
            table_insert(added_items, item)
            if mode == "coin" then added_coins = added_coins + calculate_fish_coin_value(item) end
        end
        task_wait(0.08)
    end

    if #added_items > 0 and local_player:GetAttribute("IsTrading") then
        local trade_success = false
        local function mark_success()
            if not trade_success then
                trade_success = true
                s.success_trades = s.success_trades + 1
                s.last_items = #added_items
                s.total_items = s.total_items + #added_items
                if mode == "coin" then
                    local sent_subtotal = 0
                    for _, itm in ipairs(added_items) do
                        sent_subtotal = sent_subtotal + calculate_fish_coin_value(itm)
                    end
                    s.total_coins = (s.total_coins or 0) + sent_subtotal
                end
                update_status_ui(mode)
            end
        end
        local chat_listener = listen_for_trade_completion(mark_success)
        pcall(function() trade_remotes.SetReady:InvokeServer(true) end)
        wait_for_trade_end(mode, chat_listener)
        if chat_listener.is_completed() or (not local_player:GetAttribute("IsTrading") and #added_items > 0) then mark_success() end
        chat_listener.disconnect()
        if not trade_success then
            s.failed = s.failed + 1
            cache.last_failed_offer_time = tick()
            close_trading_gui()
            update_status_ui(mode)
        else
            cache.last_failed_offer_time = nil
            set_status_msg(mode, "Trade done! Syncing inventory...")
            local clear_start = tick()
            while local_player:GetAttribute("IsTrading") and (tick() - clear_start) < 4 do
                task_wait(0.1)
            end
            task_wait(0.4)

            if mode == "coin" then
                if config.target_coin_amount > 0 and (s.total_coins or 0) >= config.target_coin_amount then
                    config.enabled = false
                    config.trade_coins_enabled = false
                    if toggle_ctrls.coin then toggle_ctrls.coin.set_state(false) end
                    set_status_msg("coin", string_format("Selesai! Berhasil mengirim %s Coins (%d ikan)", format_number(s.total_coins), s.total_items))
                end
            else
                if config.quantity > 0 and s.total_items >= config.quantity then
                    config.enabled = false
                    local flag_name = mode_flag_map[mode]
                    if flag_name then config[flag_name] = false end
                    if toggle_ctrls[mode] then toggle_ctrls[mode].set_state(false) end
                    set_status_msg(mode, string_format("Selesai! Berhasil mengirim %d/%d item", s.total_items, config.quantity))
                end
            end
        end
    else
        s.failed = s.failed + 1
        update_status_ui(mode)
    end
end

local function run_auto_trade_loop()
    if cache.loop_running then return end
    cache.loop_running = true
    for _, mode in ipairs({"fish", "rarity", "enchant", "coin"}) do
        task_spawn(function()
            local flag_name = mode_flag_map[mode]
            while _G.NoirHub_AutoTrade_ScriptID == script_id do
                if config.enabled and config[flag_name] then
                    if not cache.is_trading_active then
                        cache.is_trading_active = true
                        pcall(function() execute_trade(mode) end)
                        cache.is_trading_active = false
                    end
                end
                task_wait(3)
            end
        end)
    end
end

local function create_ui()
    local parent_gui = nil
    if gethui then
        local ok, res = pcall(gethui)
        if ok and res then parent_gui = res end
    end
    if not parent_gui then
        local ok, core = pcall(function() return cloneref(game:GetService("CoreGui")) end)
        if ok and core then parent_gui = core end
    end
    if not parent_gui then
        parent_gui = player_gui
    end

    local function clear_old(cont)
        if not cont then return end
        pcall(function()
            for _, c in ipairs(cont:GetChildren()) do
                if c.Name == "NoirHub_AutoTrade" or c.Name == "AutoTrade" then c:Destroy() end
            end
        end)
    end
    clear_old(parent_gui)

    local gui = Instance.new("ScreenGui")
    gui.Name = "AutoTrade"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 2147483647
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = parent_gui

    local BG_COLOR = Color3.fromRGB(15, 15, 15)
    local SIDEBAR_COLOR = Color3.fromRGB(10, 10, 10)
    local ACCENT_COLOR = Color3.fromRGB(255, 0, 255)
    local TEXT_COLOR = Color3.fromRGB(240, 240, 240)
    local MUTED_COLOR = Color3.fromRGB(150, 150, 150)
    local CARD_COLOR = Color3.fromRGB(22, 22, 22)
    local INPUT_BG_COLOR = Color3.fromRGB(28, 28, 28)

    local font_face = Font.fromEnum(Enum.Font.SourceSans)
    local font_bold = Font.fromEnum(Enum.Font.SourceSansBold)
    pcall(function()
        font_face = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
        font_bold = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    end)

    local function create_corner(parent, radius)
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, radius); c.Parent = parent; return c
    end
    local function create_stroke(parent, color, thickness)
        local s = Instance.new("UIStroke"); s.Color = color; s.Thickness = thickness or 1; s.Parent = parent; return s
    end

    local player_panel
    local main = Instance.new("Frame")
    main.Name = "MainFrame"
    main.Size = UDim2.new(0, 250, 0, 200)
    main.Position = UDim2.new(0.5, -178, 0.5, -100)
    main.BackgroundColor3 = BG_COLOR
    main.BackgroundTransparency = 0
    main.BorderSizePixel = 0
    main.Active = true
    main.ZIndex = 1
    main.Parent = gui
    create_corner(main, 10); create_stroke(main, Color3.fromRGB(45, 45, 45))

    local floating_btn = Instance.new("TextButton")
    floating_btn.Name = "FloatingRestore"
    floating_btn.Size = UDim2.new(0, 38, 0, 38)
    floating_btn.Position = UDim2.new(0, 15, 0.5, -19)
    floating_btn.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
    floating_btn.BackgroundTransparency = 0
    floating_btn.Text = "N"
    floating_btn.TextColor3 = ACCENT_COLOR
    floating_btn.TextSize = 22
    floating_btn.FontFace = font_bold
    floating_btn.Visible = false
    floating_btn.ZIndex = 20
    floating_btn.Parent = gui
    create_corner(floating_btn, 9); create_stroke(floating_btn, ACCENT_COLOR, 1.5)

    local float_dragging, float_drag_start, float_start_pos
    floating_btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            float_dragging = true
            float_drag_start = input.Position
            float_start_pos = floating_btn.Position
            local end_conn
            end_conn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    float_dragging = false
                    if end_conn then end_conn:Disconnect(); end_conn = nil end
                    pcall(function()
                        local vp_size = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1920, 1080)
                        local abs_pos = floating_btn.AbsolutePosition
                        local dist_left = abs_pos.X
                        local dist_right = vp_size.X - (abs_pos.X + 40)
                        local dist_bottom = vp_size.Y - (abs_pos.Y + 40)

                        local target_pos
                        if dist_bottom < math.min(dist_left, dist_right) and dist_bottom < 120 then
                            local target_x = math.clamp(abs_pos.X, 15, vp_size.X - 55)
                            local target_y = vp_size.Y - 55
                            target_pos = UDim2.new(0, target_x, 0, target_y)
                        elseif dist_left <= dist_right then
                            local target_x = 15
                            local target_y = math.clamp(abs_pos.Y, 20, vp_size.Y - 60)
                            target_pos = UDim2.new(0, target_x, 0, target_y)
                        else
                            local target_x = vp_size.X - 55
                            local target_y = math.clamp(abs_pos.Y, 20, vp_size.Y - 60)
                            target_pos = UDim2.new(0, target_x, 0, target_y)
                        end

                        tween_service:Create(floating_btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                            Position = target_pos
                        }):Play()
                    end)
                end
            end)
        end
    end)
    float_drag_conn = user_input_service.InputChanged:Connect(function(input)
        if float_dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - float_drag_start
            floating_btn.Position = UDim2.new(float_start_pos.X.Scale, float_start_pos.X.Offset + delta.X, float_start_pos.Y.Scale, float_start_pos.Y.Offset + delta.Y)
        end
    end)
    floating_btn.MouseButton1Click:Connect(function()
        if not float_dragging then main.Visible = true; floating_btn.Visible = false end
    end)

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 24)
    header.BackgroundColor3 = SIDEBAR_COLOR
    header.BackgroundTransparency = 0
    header.ZIndex = 2
    header.Parent = main
    create_corner(header, 10)

    local title_lbl = Instance.new("TextLabel")
    title_lbl.Size = UDim2.new(1, -90, 1, 0)
    title_lbl.Position = UDim2.new(0, 10, 0, 0)
    title_lbl.BackgroundTransparency = 1
    title_lbl.Text = "NØIR Hub"
    title_lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    title_lbl.TextSize = 10
    title_lbl.FontFace = font_bold
    title_lbl.TextXAlignment = Enum.TextXAlignment.Left
    title_lbl.ZIndex = 3
    title_lbl.Parent = header

    local min_btn = Instance.new("TextButton")
    min_btn.Name = "MinimizeBtn"
    min_btn.Size = UDim2.new(0, 22, 0, 22)
    min_btn.Position = UDim2.new(1, -74, 0.5, -11)
    min_btn.BackgroundTransparency = 1
    min_btn.Text = "-"
    min_btn.TextColor3 = MUTED_COLOR
    min_btn.TextSize = 14
    min_btn.Font = Enum.Font.SourceSansBold
    min_btn.ZIndex = 3
    min_btn.Parent = header
    min_btn.MouseEnter:Connect(function() min_btn.TextColor3 = ACCENT_COLOR end)
    min_btn.MouseLeave:Connect(function() min_btn.TextColor3 = MUTED_COLOR end)
    min_btn.MouseButton1Click:Connect(function() main.Visible = false; floating_btn.Visible = true end)

    local is_expanded = false
    local saved_normal_size = UDim2.new(0, 250, 0, 200)
    local saved_normal_pos = UDim2.new(0.5, -178, 0.5, -100)

    local restore_btn = Instance.new("TextButton")
    restore_btn.Name = "RestoreBtn"
    restore_btn.Size = UDim2.new(0, 22, 0, 22)
    restore_btn.Position = UDim2.new(1, -50, 0.5, -11)
    restore_btn.BackgroundTransparency = 1
    restore_btn.Text = "[]"
    restore_btn.TextColor3 = MUTED_COLOR
    restore_btn.TextSize = 10
    restore_btn.Font = Enum.Font.SourceSansBold
    restore_btn.ZIndex = 3
    restore_btn.Parent = header
    restore_btn.MouseEnter:Connect(function() restore_btn.TextColor3 = ACCENT_COLOR end)
    restore_btn.MouseLeave:Connect(function() restore_btn.TextColor3 = MUTED_COLOR end)
    restore_btn.MouseButton1Click:Connect(function()
        is_expanded = not is_expanded
        if is_expanded then
            saved_normal_size = main.Size
            saved_normal_pos = main.Position
            restore_btn.Text = "[-]"
            local target_size = UDim2.new(1, -125, 1 - saved_normal_pos.Y.Scale, -saved_normal_pos.Y.Offset - 10)
            local target_pos = UDim2.new(0, 10, saved_normal_pos.Y.Scale, saved_normal_pos.Y.Offset)
            tween_service:Create(main, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = target_size,
                Position = target_pos
            }):Play()
        else
            restore_btn.Text = "[]"
            tween_service:Create(main, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = saved_normal_size,
                Position = saved_normal_pos
            }):Play()
        end
    end)

    local close_btn = Instance.new("TextButton")
    close_btn.Name = "CloseBtn"
    close_btn.Size = UDim2.new(0, 22, 0, 22)
    close_btn.Position = UDim2.new(1, -26, 0.5, -11)
    close_btn.BackgroundTransparency = 1
    close_btn.Text = "X"
    close_btn.TextColor3 = MUTED_COLOR
    close_btn.TextSize = 12
    close_btn.Font = Enum.Font.SourceSansBold
    close_btn.ZIndex = 3
    close_btn.Parent = header
    close_btn.MouseEnter:Connect(function() close_btn.TextColor3 = Color3.fromRGB(255, 60, 60) end)
    close_btn.MouseLeave:Connect(function() close_btn.TextColor3 = MUTED_COLOR end)
    close_btn.MouseButton1Click:Connect(function()
        pcall(_G.NoirHub_AutoTrade_Cleanup)
    end)

    local dragging, drag_start, start_pos
    local header_end_conn
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, drag_start, start_pos = true, input.Position, main.Position
            if header_end_conn then header_end_conn:Disconnect(); header_end_conn = nil end
            header_end_conn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if header_end_conn then header_end_conn:Disconnect(); header_end_conn = nil end
                    if not is_expanded then
                        saved_normal_pos = main.Position
                    end
                end
            end)
        end
    end)
    header_drag_conn = user_input_service.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - drag_start
            main.Position = UDim2.new(start_pos.X.Scale, start_pos.X.Offset + delta.X, start_pos.Y.Scale, start_pos.Y.Offset + delta.Y)
        end
    end)

    local close_detector = Instance.new("TextButton")
    close_detector.Size = UDim2.new(0, 5000, 0, 5000)
    close_detector.Position = UDim2.new(0.5, -2500, 0.5, -2500)
    close_detector.BackgroundTransparency = 1
    close_detector.Text = ""
    close_detector.ZIndex = 8
    close_detector.Visible = false
    close_detector.Parent = main

    local drawer_panels = {}
    close_detector.MouseButton1Click:Connect(function()
        for _, p in pairs(drawer_panels) do p.Visible = false end
        close_detector.Visible = false
    end)

    local function create_drawer(name)
        local panel = Instance.new("Frame")
        panel.Name = name
        panel.Size = UDim2.new(0, 150, 1, -34)
        panel.Position = UDim2.new(1, -160, 0, 28)
        panel.BackgroundColor3 = BG_COLOR
        panel.BackgroundTransparency = 0
        panel.Visible = false
        panel.ZIndex = 10
        panel.Parent = main
        create_corner(panel, 10); create_stroke(panel, Color3.fromRGB(45, 45, 45))

        local search = Instance.new("TextBox")
        search.Size = UDim2.new(1, -20, 0, 24)
        search.Position = UDim2.new(0, 10, 0, 10)
        search.BackgroundColor3 = INPUT_BG_COLOR
        search.Text = ""
        search.PlaceholderText = "Search..."
        search.PlaceholderColor3 = MUTED_COLOR
        search.TextColor3 = TEXT_COLOR
        search.TextSize = 9
        search.FontFace = font_face
        search.TextXAlignment = Enum.TextXAlignment.Center
        search.ClearTextOnFocus = false
        search.ZIndex = 10
        search.Parent = panel
        create_corner(search, 5); create_stroke(search, Color3.fromRGB(45, 45, 45))

        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, -12, 1, -52)
        scroll.Position = UDim2.new(0, 6, 0, 47)
        scroll.BackgroundTransparency = 1
        scroll.ScrollBarThickness = 3
        scroll.ScrollBarImageColor3 = Color3.fromRGB(45, 45, 45)
        scroll.ZIndex = 10
        scroll.Parent = panel
        local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 2); layout.Parent = scroll
        drawer_panels[name] = panel
        return panel, search, scroll
    end

    local item_panel, item_search, item_scroll = create_drawer("ItemSelectionPanel")
    local enchant_panel, enchant_search, enchant_scroll = create_drawer("EnchantSelectionPanel")
    local rarity_panel, _, rarity_scroll = create_drawer("RaritySelectionPanel")

    local function populate_drawer(scroll, options, selected_list, is_multi, callback, query)
        for _, c in ipairs(scroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        local q = string_lower(query or "")
        local match_count = 0
        local full_opts = { "All" }
        for _, opt in ipairs(options) do table_insert(full_opts, opt) end
        for _, opt in ipairs(full_opts) do
            local clean = strip_quantity(opt)
            if q == "" or string_find(string_lower(clean), q) then
                match_count = match_count + 1
                local is_selected = table_find(selected_list, clean) ~= nil
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, -6, 0, 24)
                btn.BackgroundColor3 = is_selected and Color3.fromRGB(24, 24, 24) or Color3.fromRGB(0, 0, 0)
                btn.BackgroundTransparency = is_selected and 0 or 1
                btn.Text = ""
                btn.ZIndex = 12
                btn.Parent = scroll
                create_corner(btn, 4)

                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(1, -20, 1, 0)
                lbl.Position = UDim2.new(0, 15, 0, 0)
                lbl.BackgroundTransparency = 1
                lbl.Text = opt
                lbl.TextColor3 = is_selected and ACCENT_COLOR or TEXT_COLOR
                lbl.TextSize = 9
                lbl.FontFace = font_face
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.ZIndex = 13
                lbl.Parent = btn

                local ind = Instance.new("Frame")
                ind.Size = UDim2.new(0, 3, 0, 14)
                ind.Position = UDim2.new(0, 5, 0.5, -7)
                ind.BackgroundColor3 = ACCENT_COLOR
                ind.BorderSizePixel = 0
                ind.Visible = is_selected
                ind.ZIndex = 14
                ind.Parent = btn

                btn.MouseButton1Click:Connect(function()
                    if clean == "All" then
                        for k in pairs(selected_list) do selected_list[k] = nil end
                        table_insert(selected_list, "All")
                    else
                        local all_idx = table_find(selected_list, "All")
                        if all_idx then table_remove(selected_list, all_idx) end
                        local idx = table_find(selected_list, clean)
                        if idx then table_remove(selected_list, idx) else table_insert(selected_list, clean) end
                    end
                    callback(selected_list)
                    populate_drawer(scroll, options, selected_list, is_multi, callback, query)
                end)
            end
        end
        scroll.CanvasSize = UDim2.new(0, 0, 0, match_count * 26 + 10)
    end

    player_panel = Instance.new("Frame")
    player_panel.Name = "PlayerPanel"
    player_panel.Size = UDim2.new(0, 100, 1, 0)
    player_panel.Position = UDim2.new(1, 5, 0, 0)
    player_panel.BackgroundColor3 = BG_COLOR
    player_panel.BackgroundTransparency = 0
    player_panel.ZIndex = 10
    player_panel.Parent = main
    create_corner(player_panel, 10); create_stroke(player_panel, Color3.fromRGB(45, 45, 45))

    local ply_refresh = Instance.new("TextButton")
    ply_refresh.Size = UDim2.new(1, -20, 0, 26)
    ply_refresh.Position = UDim2.new(0, 10, 0, 10)
    ply_refresh.BackgroundColor3 = Color3.fromRGB(192, 0, 192)
    ply_refresh.Text = "Refresh"
    ply_refresh.TextColor3 = Color3.fromRGB(255, 255, 255)
    ply_refresh.TextSize = 9
    ply_refresh.FontFace = font_bold
    ply_refresh.ZIndex = 10
    ply_refresh.Parent = player_panel
    create_corner(ply_refresh, 5)

    local target_lbl = Instance.new("TextLabel")
    target_lbl.Size = UDim2.new(1, -12, 0, 20)
    target_lbl.Position = UDim2.new(0, 6, 0, 42)
    target_lbl.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    target_lbl.Text = config.trade_with ~= "" and config.trade_with or "None"
    target_lbl.TextColor3 = ACCENT_COLOR
    target_lbl.TextSize = 9
    target_lbl.FontFace = font_bold
    target_lbl.ZIndex = 10
    target_lbl.Parent = player_panel
    create_corner(target_lbl, 4); create_stroke(target_lbl, Color3.fromRGB(45, 45, 45))

    local p_scroll = Instance.new("ScrollingFrame")
    p_scroll.Size = UDim2.new(1, -12, 1, -78)
    p_scroll.Position = UDim2.new(0, 6, 0, 73)
    p_scroll.BackgroundTransparency = 1
    p_scroll.ScrollBarThickness = 3
    p_scroll.ScrollBarImageColor3 = Color3.fromRGB(45, 45, 45)
    p_scroll.ZIndex = 10
    p_scroll.Parent = player_panel
    local p_layout = Instance.new("UIListLayout"); p_layout.Padding = UDim.new(0, 2); p_layout.Parent = p_scroll

    local function populate_players()
        for _, c in ipairs(p_scroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        local p_list = get_other_players()
        for _, name in ipairs(p_list) do
            local is_selected = config.trade_with == name
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -6, 0, 24)
            btn.BackgroundColor3 = is_selected and Color3.fromRGB(24, 24, 24) or Color3.fromRGB(0, 0, 0)
            btn.BackgroundTransparency = is_selected and 0 or 1
            btn.Text = "  " .. name
            btn.TextColor3 = is_selected and ACCENT_COLOR or TEXT_COLOR
            btn.TextSize = 9
            btn.FontFace = font_face
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.ZIndex = 12
            btn.Parent = p_scroll
            create_corner(btn, 4)
            btn.MouseButton1Click:Connect(function()
                config.trade_with = name
                target_lbl.Text = name
                populate_players()
            end)
        end
        p_scroll.CanvasSize = UDim2.new(0, 0, 0, #p_list * 26 + 10)
    end
    ply_refresh.Activated:Connect(populate_players)
    populate_players()

    local content_scroll = Instance.new("ScrollingFrame")
    content_scroll.Size = UDim2.new(1, -12, 1, -34)
    content_scroll.Position = UDim2.new(0, 6, 0, 28)
    content_scroll.BackgroundTransparency = 1
    content_scroll.ScrollBarThickness = 3
    content_scroll.ScrollBarImageColor3 = Color3.fromRGB(45, 45, 45)
    content_scroll.ZIndex = 2
    content_scroll.CanvasSize = UDim2.new(0, 0, 0, 180)
    content_scroll.Parent = main
    local content_layout = Instance.new("UIListLayout"); content_layout.Padding = UDim.new(0, 6); content_layout.Parent = content_scroll

    local function create_toggle(parent, label_text, default, callback)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 22)
        row.BackgroundTransparency = 1
        row.ZIndex = 3
        row.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.65, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = label_text
        lbl.TextColor3 = TEXT_COLOR
        lbl.TextSize = 9
        lbl.FontFace = font_bold
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 4
        lbl.Parent = row

        local capsule = Instance.new("TextButton")
        capsule.Size = UDim2.new(0, 32, 0, 16)
        capsule.Position = UDim2.new(1, -32, 0.5, -8)
        capsule.BackgroundColor3 = default and ACCENT_COLOR or Color3.fromRGB(45, 45, 45)
        capsule.Text = ""
        capsule.ZIndex = 4
        capsule.Parent = row
        create_corner(capsule, 8); create_stroke(capsule, Color3.fromRGB(35, 35, 35))

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 12, 0, 12)
        knob.Position = default and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
        knob.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
        knob.ZIndex = 5
        knob.Parent = capsule
        create_corner(knob, 6)

        local active = default
        local function update_visual(state)
            tween_service:Create(knob, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Position = state and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6) }):Play()
            tween_service:Create(capsule, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { BackgroundColor3 = state and ACCENT_COLOR or Color3.fromRGB(45, 45, 45) }):Play()
        end
        capsule.MouseButton1Click:Connect(function()
            active = not active
            update_visual(active)
            callback(active)
        end)
        return {
            set_state = function(state)
                if active == state then return end
                active = state
                update_visual(state)
            end,
            Frame = row
        }
    end

    local function create_accordion(title_text)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 26)
        frame.BackgroundColor3 = CARD_COLOR
        frame.BackgroundTransparency = 0
        frame.ClipsDescendants = true
        frame.ZIndex = 2
        frame.Parent = content_scroll
        create_corner(frame, 5); create_stroke(frame, Color3.fromRGB(35, 35, 35))

        local head = Instance.new("TextButton")
        head.Size = UDim2.new(1, 0, 0, 26)
        head.BackgroundTransparency = 1
        head.Text = "  " .. title_text
        head.TextColor3 = TEXT_COLOR
        head.TextSize = 9
        head.FontFace = font_bold
        head.TextXAlignment = Enum.TextXAlignment.Left
        head.ZIndex = 3
        head.Parent = frame

        local chev = Instance.new("TextLabel")
        chev.Size = UDim2.new(0, 20, 1, 0)
        chev.Position = UDim2.new(1, -25, 0, 0)
        chev.BackgroundTransparency = 1
        chev.Text = "v"
        chev.TextColor3 = ACCENT_COLOR
        chev.TextSize = 10
        chev.Font = Enum.Font.SourceSansBold
        chev.ZIndex = 4
        chev.Parent = head

        local inner = Instance.new("Frame")
        inner.Size = UDim2.new(1, -12, 0, 0)
        inner.Position = UDim2.new(0, 6, 0, 28)
        inner.BackgroundTransparency = 1
        inner.ZIndex = 3
        inner.Parent = frame
        local in_layout = Instance.new("UIListLayout"); in_layout.Padding = UDim.new(0, 6); in_layout.Parent = inner

        local expanded = false
        head.MouseButton1Click:Connect(function()
            expanded = not expanded
            chev.Text = expanded and "^" or "v"
            local target_h = expanded and (32 + in_layout.AbsoluteContentSize.Y) or 26
            tween_service:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Size = UDim2.new(1, 0, 0, target_h) }):Play()
            task_wait(0.21)
            content_scroll.CanvasSize = UDim2.new(0, 0, 0, content_layout.AbsoluteContentSize.Y + 20)
        end)
        in_layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            if expanded then frame.Size = UDim2.new(1, 0, 0, 32 + in_layout.AbsoluteContentSize.Y) end
        end)
        return inner
    end

    local function create_stat_box(parent, mode)
        local box = Instance.new("Frame")
        box.Size = UDim2.new(1, 0, 0, 58)
        box.AutomaticSize = Enum.AutomaticSize.Y
        box.BackgroundColor3 = CARD_COLOR
        box.BackgroundTransparency = 0
        box.ZIndex = 3
        box.Parent = parent
        create_corner(box, 6); create_stroke(box, Color3.fromRGB(35, 35, 35))

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -10, 0, 16)
        title.Position = UDim2.new(0, 10, 0, 6)
        title.BackgroundTransparency = 1
        title.Text = "Status"
        title.TextColor3 = ACCENT_COLOR
        title.TextSize = 9
        title.FontFace = font_bold
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.ZIndex = 4
        title.Parent = box

        local val = Instance.new("TextLabel")
        val.Size = UDim2.new(1, -20, 0, 30)
        val.Position = UDim2.new(0, 10, 0, 22)
        val.AutomaticSize = Enum.AutomaticSize.Y
        val.BackgroundTransparency = 1
        val.Text = "Idle"
        val.TextColor3 = TEXT_COLOR
        val.TextSize = 9
        val.FontFace = font_face
        val.TextXAlignment = Enum.TextXAlignment.Left
        val.TextWrapped = true
        val.ZIndex = 4
        val.Parent = box
        status_labels[mode] = val
        return val
    end

    local fav_toggles = {}
    local function sync_fav(active)
        config.trade_favorited = active
        for _, t in pairs(fav_toggles) do t.set_state(active) end
        cache.loaded_fish = get_owned_options("Fish")
        cache.loaded_enchants = get_owned_options("Enchant")
    end

    local qty_inputs = {}
    local function sync_qty(val)
        config.quantity = val
        for _, box in pairs(qty_inputs) do box.Text = tostring(val) end
    end

    local function sync_modes(active_mode)
        for m, flag in pairs(mode_flag_map) do
            if m ~= active_mode then
                if toggle_ctrls[m] then toggle_ctrls[m].set_state(false) end
                config[flag] = false
            end
        end
    end

    -- Tab 1: Trade By Name
    local byname_inner = create_accordion("Trade By Name")
    create_stat_box(byname_inner, "fish")
    local f_row = Instance.new("Frame"); f_row.Size = UDim2.new(1, 0, 0, 22); f_row.BackgroundTransparency = 1; f_row.Parent = byname_inner
    local f_lbl = Instance.new("TextLabel"); f_lbl.Size = UDim2.new(0.45, 0, 1, 0); f_lbl.BackgroundTransparency = 1; f_lbl.Text = "Select Item"; f_lbl.TextColor3 = TEXT_COLOR; f_lbl.TextSize = 9; f_lbl.FontFace = font_bold; f_lbl.TextXAlignment = Enum.TextXAlignment.Left; f_lbl.Parent = f_row
    local f_drop = Instance.new("TextButton"); f_drop.Size = UDim2.new(0.55, 0, 1, 0); f_drop.Position = UDim2.new(0.45, 0, 0, 0); f_drop.BackgroundColor3 = INPUT_BG_COLOR; f_drop.Text = (#config.selected_fish > 0 and table_concat(config.selected_fish, "/") or "All"); f_drop.TextColor3 = TEXT_COLOR; f_drop.TextSize = 9; f_drop.FontFace = font_face; f_drop.Parent = f_row
    create_corner(f_drop, 4); create_stroke(f_drop, Color3.fromRGB(45, 45, 45))
    f_drop.MouseButton1Click:Connect(function()
        item_panel.Visible = not item_panel.Visible
        close_detector.Visible = item_panel.Visible
        if item_panel.Visible then
            cache.loaded_fish = get_owned_options("Fish")
            populate_drawer(item_scroll, cache.loaded_fish, config.selected_fish, true, function(sel)
                f_drop.Text = #sel > 0 and table_concat(sel, "/") or "All"
            end, item_search.Text)
        end
    end)
    item_search:GetPropertyChangedSignal("Text"):Connect(function()
        populate_drawer(item_scroll, cache.loaded_fish, config.selected_fish, true, function(sel)
            f_drop.Text = #sel > 0 and table_concat(sel, "/") or "All"
        end, item_search.Text)
    end)

    local f_amt_row = Instance.new("Frame"); f_amt_row.Size = UDim2.new(1, 0, 0, 22); f_amt_row.BackgroundTransparency = 1; f_amt_row.Parent = byname_inner
    local f_amt_lbl = Instance.new("TextLabel"); f_amt_lbl.Size = UDim2.new(0.45, 0, 1, 0); f_amt_lbl.BackgroundTransparency = 1; f_amt_lbl.Text = "Amount Fish Name"; f_amt_lbl.TextColor3 = TEXT_COLOR; f_amt_lbl.TextSize = 9; f_amt_lbl.FontFace = font_bold; f_amt_lbl.TextXAlignment = Enum.TextXAlignment.Left; f_amt_lbl.Parent = f_amt_row
    local f_qty = Instance.new("TextBox"); f_qty.Size = UDim2.new(0.55, 0, 1, 0); f_qty.Position = UDim2.new(0.45, 0, 0, 0); f_qty.BackgroundColor3 = INPUT_BG_COLOR; f_qty.Text = tostring(config.quantity); f_qty.TextColor3 = TEXT_COLOR; f_qty.TextSize = 9; f_qty.FontFace = font_face; f_qty.Parent = f_amt_row
    create_corner(f_qty, 4); create_stroke(f_qty, Color3.fromRGB(45, 45, 45))
    table_insert(qty_inputs, f_qty)
    f_qty.FocusLost:Connect(function() sync_qty(tonumber(f_qty.Text) or config.quantity) end)

    local f_ref = Instance.new("TextButton"); f_ref.Size = UDim2.new(1, 0, 0, 26); f_ref.BackgroundColor3 = Color3.fromRGB(192, 0, 192); f_ref.Text = "Refresh Fish Items"; f_ref.TextColor3 = Color3.fromRGB(255, 255, 255); f_ref.TextSize = 9; f_ref.FontFace = font_bold; f_ref.Parent = byname_inner
    create_corner(f_ref, 5)
    f_ref.MouseButton1Click:Connect(function()
        f_ref.Text = "Fish Items Refreshed!"
        cache.loaded_fish = get_owned_options("Fish")
        task_wait(1); f_ref.Text = "Refresh Fish Items"
    end)
    toggle_ctrls.fish = create_toggle(byname_inner, "Start Trade ByName", config.enabled and config.trade_fish_enabled, function(active)
        if active then
            if f_qty and f_qty.Text ~= "" then
                local num = tonumber(f_qty.Text)
                if num and num >= 0 then
                    sync_qty(math_floor(num))
                end
            end
            cache.stats.fish = { success_trades = 0, attempts = 0, failed = 0, last_items = 0, total_items = 0 }
            config.trade_fish_enabled = true; config.enabled = true
            sync_modes("fish"); run_auto_trade_loop()
        else
            config.enabled = false; config.trade_fish_enabled = false; set_status_msg("fish", "Idle")
        end
    end)
    fav_toggles.fish = create_toggle(byname_inner, "Trade Favorite Items", config.trade_favorited, sync_fav)

    -- Tab 2: Trade Enchant Stone
    local en_inner = create_accordion("Trade Enchant Stone")
    create_stat_box(en_inner, "enchant")
    local e_row = Instance.new("Frame"); e_row.Size = UDim2.new(1, 0, 0, 22); e_row.BackgroundTransparency = 1; e_row.Parent = en_inner
    local e_lbl = Instance.new("TextLabel"); e_lbl.Size = UDim2.new(0.45, 0, 1, 0); e_lbl.BackgroundTransparency = 1; e_lbl.Text = "Stone Type"; e_lbl.TextColor3 = TEXT_COLOR; e_lbl.TextSize = 9; e_lbl.FontFace = font_bold; e_lbl.TextXAlignment = Enum.TextXAlignment.Left; e_lbl.Parent = e_row
    local e_drop = Instance.new("TextButton"); e_drop.Size = UDim2.new(0.55, 0, 1, 0); e_drop.Position = UDim2.new(0.45, 0, 0, 0); e_drop.BackgroundColor3 = INPUT_BG_COLOR; e_drop.Text = (#config.selected_items > 0 and table_concat(config.selected_items, "/") or "All"); e_drop.TextColor3 = TEXT_COLOR; e_drop.TextSize = 9; e_drop.FontFace = font_face; e_drop.Parent = e_row
    create_corner(e_drop, 4); create_stroke(e_drop, Color3.fromRGB(45, 45, 45))
    e_drop.MouseButton1Click:Connect(function()
        enchant_panel.Visible = not enchant_panel.Visible
        close_detector.Visible = enchant_panel.Visible
        if enchant_panel.Visible then
            cache.loaded_enchants = get_owned_options("Enchant")
            populate_drawer(enchant_scroll, cache.loaded_enchants, config.selected_items, true, function(sel)
                e_drop.Text = #sel > 0 and table_concat(sel, "/") or "All"
            end, enchant_search.Text)
        end
    end)
    enchant_search:GetPropertyChangedSignal("Text"):Connect(function()
        populate_drawer(enchant_scroll, cache.loaded_enchants, config.selected_items, true, function(sel)
            e_drop.Text = #sel > 0 and table_concat(sel, "/") or "All"
        end, enchant_search.Text)
    end)

    local e_amt_row = Instance.new("Frame"); e_amt_row.Size = UDim2.new(1, 0, 0, 22); e_amt_row.BackgroundTransparency = 1; e_amt_row.Parent = en_inner
    local e_amt_lbl = Instance.new("TextLabel"); e_amt_lbl.Size = UDim2.new(0.45, 0, 1, 0); e_amt_lbl.BackgroundTransparency = 1; e_amt_lbl.Text = "Amount Enchant Stone"; e_amt_lbl.TextColor3 = TEXT_COLOR; e_amt_lbl.TextSize = 9; e_amt_lbl.FontFace = font_bold; e_amt_lbl.TextXAlignment = Enum.TextXAlignment.Left; e_amt_lbl.Parent = e_amt_row
    local e_qty = Instance.new("TextBox"); e_qty.Size = UDim2.new(0.55, 0, 1, 0); e_qty.Position = UDim2.new(0.45, 0, 0, 0); e_qty.BackgroundColor3 = INPUT_BG_COLOR; e_qty.Text = tostring(config.quantity); e_qty.TextColor3 = TEXT_COLOR; e_qty.TextSize = 9; e_qty.FontFace = font_face; e_qty.Parent = e_amt_row
    create_corner(e_qty, 4); create_stroke(e_qty, Color3.fromRGB(45, 45, 45))
    table_insert(qty_inputs, e_qty)
    e_qty.FocusLost:Connect(function() sync_qty(tonumber(e_qty.Text) or config.quantity) end)

    local e_ref = Instance.new("TextButton"); e_ref.Size = UDim2.new(1, 0, 0, 26); e_ref.BackgroundColor3 = Color3.fromRGB(192, 0, 192); e_ref.Text = "Check Enchant Stones"; e_ref.TextColor3 = Color3.fromRGB(255, 255, 255); e_ref.TextSize = 9; e_ref.FontFace = font_bold; e_ref.Parent = en_inner
    create_corner(e_ref, 5)
    e_ref.MouseButton1Click:Connect(function()
        e_ref.Text = "Enchant Stones Checked!"
        cache.loaded_enchants = get_owned_options("Enchant")
        task_wait(1); e_ref.Text = "Check Enchant Stones"
    end)
    toggle_ctrls.enchant = create_toggle(en_inner, "Start Trade EnchantStone", config.enabled and config.trade_enchants_enabled, function(active)
        if active then
            if e_qty and e_qty.Text ~= "" then
                local num = tonumber(e_qty.Text)
                if num and num >= 0 then
                    sync_qty(math_floor(num))
                end
            end
            cache.stats.enchant = { success_trades = 0, attempts = 0, failed = 0, last_items = 0, total_items = 0 }
            config.trade_enchants_enabled = true; config.enabled = true
            sync_modes("enchant"); run_auto_trade_loop()
        else
            config.enabled = false; config.trade_enchants_enabled = false; set_status_msg("enchant", "Idle")
        end
    end)

    -- Tab 3: Trade By Rarity
    local r_inner = create_accordion("Trade By Rarity")
    create_stat_box(r_inner, "rarity")
    local r_row = Instance.new("Frame"); r_row.Size = UDim2.new(1, 0, 0, 22); r_row.BackgroundTransparency = 1; r_row.Parent = r_inner
    local r_lbl = Instance.new("TextLabel"); r_lbl.Size = UDim2.new(0.45, 0, 1, 0); r_lbl.BackgroundTransparency = 1; r_lbl.Text = "Select Rarity"; r_lbl.TextColor3 = TEXT_COLOR; r_lbl.TextSize = 9; r_lbl.FontFace = font_bold; r_lbl.TextXAlignment = Enum.TextXAlignment.Left; r_lbl.Parent = r_row
    local r_drop = Instance.new("TextButton"); r_drop.Size = UDim2.new(0.55, 0, 1, 0); r_drop.Position = UDim2.new(0.45, 0, 0, 0); r_drop.BackgroundColor3 = INPUT_BG_COLOR; r_drop.Text = (#config.selected_tiers > 0 and table_concat(config.selected_tiers, "/") or "All"); r_drop.TextColor3 = TEXT_COLOR; r_drop.TextSize = 9; r_drop.FontFace = font_face; r_drop.Parent = r_row
    create_corner(r_drop, 4); create_stroke(r_drop, Color3.fromRGB(45, 45, 45))
    r_drop.MouseButton1Click:Connect(function()
        rarity_panel.Visible = not rarity_panel.Visible
        close_detector.Visible = rarity_panel.Visible
        if rarity_panel.Visible then
            populate_drawer(rarity_scroll, cache.loaded_tiers, config.selected_tiers, true, function(sel)
                r_drop.Text = #sel > 0 and table_concat(sel, "/") or "All"
            end)
        end
    end)

    local r_amt_row = Instance.new("Frame"); r_amt_row.Size = UDim2.new(1, 0, 0, 22); r_amt_row.BackgroundTransparency = 1; r_amt_row.Parent = r_inner
    local r_amt_lbl = Instance.new("TextLabel"); r_amt_lbl.Size = UDim2.new(0.45, 0, 1, 0); r_amt_lbl.BackgroundTransparency = 1; r_amt_lbl.Text = "Amount Fish Rarity"; r_amt_lbl.TextColor3 = TEXT_COLOR; r_amt_lbl.TextSize = 9; r_amt_lbl.FontFace = font_bold; r_amt_lbl.TextXAlignment = Enum.TextXAlignment.Left; r_amt_lbl.Parent = r_amt_row
    local r_qty = Instance.new("TextBox"); r_qty.Size = UDim2.new(0.55, 0, 1, 0); r_qty.Position = UDim2.new(0.45, 0, 0, 0); r_qty.BackgroundColor3 = INPUT_BG_COLOR; r_qty.Text = tostring(config.quantity); r_qty.TextColor3 = TEXT_COLOR; r_qty.TextSize = 9; r_qty.FontFace = font_face; r_qty.Parent = r_amt_row
    create_corner(r_qty, 4); create_stroke(r_qty, Color3.fromRGB(45, 45, 45))
    table_insert(qty_inputs, r_qty)
    r_qty.FocusLost:Connect(function() sync_qty(tonumber(r_qty.Text) or config.quantity) end)

    local r_ref = Instance.new("TextButton"); r_ref.Size = UDim2.new(1, 0, 0, 26); r_ref.BackgroundColor3 = Color3.fromRGB(192, 0, 192); r_ref.Text = "Refresh Fish Rarity"; r_ref.TextColor3 = Color3.fromRGB(255, 255, 255); r_ref.TextSize = 9; r_ref.FontFace = font_bold; r_ref.Parent = r_inner
    create_corner(r_ref, 5)
    r_ref.MouseButton1Click:Connect(function()
        r_ref.Text = "Rarity Fish Refreshed!"
        cache.loaded_fish = get_owned_options("Fish")
        task_wait(1); r_ref.Text = "Refresh Fish Rarity"
    end)
    toggle_ctrls.rarity = create_toggle(r_inner, "Start Trade ByRarity", config.enabled and config.trade_rarity_enabled, function(active)
        if active then
            if r_qty and r_qty.Text ~= "" then
                local num = tonumber(r_qty.Text)
                if num and num >= 0 then
                    sync_qty(math_floor(num))
                end
            end
            cache.stats.rarity = { success_trades = 0, attempts = 0, failed = 0, last_items = 0, total_items = 0 }
            config.trade_rarity_enabled = true; config.enabled = true
            sync_modes("rarity"); run_auto_trade_loop()
        else
            config.enabled = false; config.trade_rarity_enabled = false; set_status_msg("rarity", "Idle")
        end
    end)
    fav_toggles.rarity = create_toggle(r_inner, "Trade Favorite Items", config.trade_favorited, sync_fav)

    -- Tab 4: Trade By Coin
    local c_inner = create_accordion("Trade By Coin")
    create_stat_box(c_inner, "coin")
    local c_row = Instance.new("Frame"); c_row.Size = UDim2.new(1, 0, 0, 22); c_row.BackgroundTransparency = 1; c_row.Parent = c_inner
    local c_lbl = Instance.new("TextLabel"); c_lbl.Size = UDim2.new(0.45, 0, 1, 0); c_lbl.BackgroundTransparency = 1; c_lbl.Text = "Target Coins"; c_lbl.TextColor3 = TEXT_COLOR; c_lbl.TextSize = 9; c_lbl.FontFace = font_bold; c_lbl.TextXAlignment = Enum.TextXAlignment.Left; c_lbl.Parent = c_row
    local c_box = Instance.new("TextBox"); c_box.Size = UDim2.new(0.55, 0, 1, 0); c_box.Position = UDim2.new(0.45, 0, 0, 0); c_box.BackgroundColor3 = INPUT_BG_COLOR; c_box.Text = format_number(config.target_coin_amount); c_box.TextColor3 = TEXT_COLOR; c_box.TextSize = 9; c_box.FontFace = font_face; c_box.ClearTextOnFocus = false; c_box.Parent = c_row
    create_corner(c_box, 4); create_stroke(c_box, Color3.fromRGB(45, 45, 45))
    c_box:GetPropertyChangedSignal("Text"):Connect(function()
        local text = c_box.Text
        local parsed = parse_coin_input(text)
        if parsed and parsed >= 0 then
            config.target_coin_amount = parsed
        elseif text == "" then
            config.target_coin_amount = 0
        end
    end)
    c_box.FocusLost:Connect(function()
        local text = c_box.Text
        local parsed = parse_coin_input(text)
        if parsed and parsed >= 0 then
            config.target_coin_amount = parsed
            c_box.Text = format_number(parsed)
        else
            c_box.Text = format_number(config.target_coin_amount or 0)
        end
    end)

    local coin_check_btn = Instance.new("TextButton")
    coin_check_btn.Size = UDim2.new(1, 0, 0, 26)
    coin_check_btn.BackgroundColor3 = Color3.fromRGB(192, 0, 192)
    coin_check_btn.Text = "Check Bag Coin Worth"
    coin_check_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    coin_check_btn.TextSize = 9
    coin_check_btn.FontFace = font_bold
    coin_check_btn.Parent = c_inner
    create_corner(coin_check_btn, 5)

    coin_check_btn.MouseButton1Click:Connect(function()
        local total_worth = 0
        local total_fish = 0
        local inv = player_data and player_data:Get("Inventory")
        local itms = inv and inv.Items or {}
        for _, itm in ipairs(itms) do
            local is_fav = (itm.Favorited == true or (itm.Metadata and itm.Metadata.Favorited == true))
            if not is_fav or config.trade_favorited then
                local val = calculate_fish_coin_value(itm)
                if val > 0 then
                    total_worth = total_worth + val
                    total_fish = total_fish + 1
                end
            end
        end

        local worth_str = format_number(total_worth)
        coin_check_btn.Text = string_format("Worth: %s Coins (%d)", worth_str, total_fish)
        set_status_msg("coin", string_format("Inventory Worth: %s Coins", worth_str))
        task_delay(4, function()
            if coin_check_btn and coin_check_btn.Parent then
                coin_check_btn.Text = "Check Bag Coin Worth"
            end
        end)
    end)

    toggle_ctrls.coin = create_toggle(c_inner, "Start Trade ByCoin", config.enabled and config.trade_coins_enabled, function(active)
        if active then
            if c_box and c_box.Text ~= "" then
                local parsed = parse_coin_input(c_box.Text)
                if parsed and parsed > 0 then
                    config.target_coin_amount = parsed
                end
            end
            cache.stats.coin = { success_trades = 0, attempts = 0, failed = 0, last_items = 0, total_items = 0, total_coins = 0 }
            config.trade_coins_enabled = true; config.enabled = true
            sync_modes("coin"); run_auto_trade_loop()
        else
            config.enabled = false; config.trade_coins_enabled = false; set_status_msg("coin", "Idle")
        end
    end)
    fav_toggles.coin = create_toggle(c_inner, "Trade Favorite Items", config.trade_favorited, sync_fav)

    local c_reset = Instance.new("TextButton"); c_reset.Size = UDim2.new(1, 0, 0, 26); c_reset.BackgroundColor3 = Color3.fromRGB(192, 0, 192); c_reset.Text = "Reset Stats By Coin"; c_reset.TextColor3 = Color3.fromRGB(255, 255, 255); c_reset.TextSize = 9; c_reset.FontFace = font_bold; c_reset.Parent = c_inner
    create_corner(c_reset, 5)
    c_reset.MouseButton1Click:Connect(function()
        cache.stats.coin = { success_trades = 0, attempts = 0, failed = 0, last_items = 0, total_items = 0, total_coins = 0 }
        update_status_ui("coin")
        c_reset.Text = "Stats Reset!"; task_wait(1); c_reset.Text = "Reset Stats By Coin"
    end)

    -- Tab 5: Auto Accept
    local aa_inner = create_accordion("Auto Accept Trade")
    toggle_ctrls.auto_accept = create_toggle(aa_inner, "Enable Auto Accept", config.auto_accept_enabled, function(state)
        toggle_auto_accept(state)
    end)

    content_scroll.CanvasSize = UDim2.new(0, 0, 0, content_layout.AbsoluteContentSize.Y + 20)
    content_layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        content_scroll.CanvasSize = UDim2.new(0, 0, 0, content_layout.AbsoluteContentSize.Y + 20)
    end)

    task_spawn(function()
        while gui.Parent and _G.NoirHub_AutoTrade_ScriptID == script_id do
            for _, mode in ipairs({"fish", "rarity", "enchant", "coin"}) do
                update_status_ui(mode)
                local flag_name = mode_flag_map[mode]
                if toggle_ctrls[mode] and flag_name then
                    toggle_ctrls[mode].set_state(config.enabled and config[flag_name])
                end
            end
            task_wait(0.5)
        end
    end)
end

pcall(create_ui)
pcall(function() toggle_auto_accept(config.auto_accept_enabled) end)

_G.NoirHub_AutoTrade_Cleanup = function()
    config.enabled = false
    config.trade_fish_enabled = false
    config.trade_enchants_enabled = false
    config.trade_rarity_enabled = false
    config.trade_coins_enabled = false
    config.auto_accept_enabled = false
    _G.NoirHub_AutoTrade_ScriptID = nil
    if float_drag_conn then pcall(function() float_drag_conn:Disconnect() end); float_drag_conn = nil end
    if header_drag_conn then pcall(function() header_drag_conn:Disconnect() end); header_drag_conn = nil end
    if auto_accept_conn then pcall(function() auto_accept_conn:Disconnect() end); auto_accept_conn = nil end
    if auto_accept_trade_started_conn then pcall(function() auto_accept_trade_started_conn:Disconnect() end); auto_accept_trade_started_conn = nil end
    if auto_accept_trade_ended_conn then pcall(function() auto_accept_trade_ended_conn:Disconnect() end); auto_accept_trade_ended_conn = nil end
    if inventory_conn then pcall(function() inventory_conn:Disconnect() end); inventory_conn = nil end
    pcall(function()
        local core = gethui and pcall(gethui) and gethui() or game:GetService("CoreGui")
        local old = core:FindFirstChild("NoirHub_AutoTrade") or core:FindFirstChild("AutoTrade")
        if old then old:Destroy() end
    end)
    pcall(function()
        local pgui = local_player:FindFirstChild("PlayerGui")
        local old = pgui and (pgui:FindFirstChild("NoirHub_AutoTrade") or pgui:FindFirstChild("AutoTrade"))
        if old then old:Destroy() end
    end)
    if trade_offer_controller and original_popup then
        trade_offer_controller.PopUp = original_popup
    end
end
