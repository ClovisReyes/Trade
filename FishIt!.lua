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

local function safe_cloneref(ref)
    if not ref then return ref end
    if typeof and typeof(cloneref) == "function" then
        local ok, res = pcall(cloneref, ref)
        if ok and res then return res end
    end
    return ref
end

--#region Services
local players               = safe_cloneref(game:GetService("Players"))
local local_player          = players and players.LocalPlayer
if not local_player then
    pcall(function() local_player = game:GetService("Players").LocalPlayer end)
end
while not local_player do
    task.wait(0.1)
    pcall(function() local_player = game:GetService("Players").LocalPlayer end)
end

local player_gui = nil
pcall(function()
    player_gui = local_player and (local_player:FindFirstChild("PlayerGui") or local_player:WaitForChild("PlayerGui", 5))
end)

local user_input_service    = safe_cloneref(game:GetService("UserInputService"))
local run_service           = safe_cloneref(game:GetService("RunService"))
local tween_service         = safe_cloneref(game:GetService("TweenService"))
local replicated_storage    = safe_cloneref(game:GetService("ReplicatedStorage"))
local http_service          = safe_cloneref(game:GetService("HttpService"))
--#endregion

--#region Variables
local variables = {
    items                   = replicated_storage:WaitForChild("Items", 5),
    variants                = replicated_storage:WaitForChild("Variants", 5),
}

local success_replion, replion_mod = pcall(function()
    local pkg = replicated_storage:WaitForChild("Packages", 5)
    local rep = pkg and pkg:WaitForChild("Replion", 5)
    return rep and require(rep) or nil
end)

local player_data = nil
if success_replion and replion_mod and replion_mod.Client then
    pcall(function()
        task_spawn(function()
            pcall(function()
                player_data = replion_mod.Client:WaitReplion("Data")
            end)
        end)
    end)
end

local item_utility = nil
pcall(function()
    local shared_folder = replicated_storage:WaitForChild("Shared", 5)
    local iu = shared_folder and shared_folder:WaitForChild("ItemUtility", 5)
    if iu then item_utility = require(iu) end
end)

local vendor_utility = nil
pcall(function()
    local shared_folder = replicated_storage:WaitForChild("Shared", 5)
    local vu = shared_folder and shared_folder:WaitForChild("VendorUtility", 5)
    if vu then vendor_utility = require(vu) end
end)

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

    pcall(function()
        local packages = replicated_storage:FindFirstChild("Packages")
        local index_folder 
