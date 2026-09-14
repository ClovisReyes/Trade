--[[
    NOIR HUB - TRADE SUPER DEBUGGER [v6.4]
    Merekam 100% Seluruh Siklus & Aktivitas Trade:
    1. Offer: SendTradeOffer / TradeOfferReceived / Prompt GUI (Yes/No)
    2. Start: TradeStarted / IsTrading attribute / Partner Name
    3. Items: AddItem (dengan auto-resolve nama item, rarity, mutation dari inventory) + Return value
    4. Window GUI: Slots grid update (My items & Partner items)
    5. Ready & Confirm: SetReady / Countdown lock timer / ConfirmTrade / Button clicks
    6. End & Verifikasi: TradeEnded / System chat verification / Summary session report
]]

local cloneref = cloneref or function(ref) return ref end

local players            = cloneref(game:GetService("Players"))
local local_player       = players.LocalPlayer
local player_gui         = cloneref(local_player:WaitForChild("PlayerGui"))
local replicated_storage = cloneref(game:GetService("ReplicatedStorage"))
local user_input_service = cloneref(game:GetService("UserInputService"))
local http_service       = cloneref(game:GetService("HttpService"))
local text_chat_service  = cloneref(game:GetService("TextChatService"))

-- Cleanup previous spy instance
if _G.NoirHub_TradeSpy_Cleanup then
    pcall(_G.NoirHub_TradeSpy_Cleanup)
end

local script_id = os.clock()
_G.NoirHub_TradeSpy_ScriptID = script_id

-- ==============================================================================
-- 1. LOG ENGINE & PERSISTENCE
-- ==============================================================================
local all_logs = {}
local active_filter = "ALL"
local log_text_box = nil
local log_scroll = nil
local status_indicator = nil

local current_session = {
    active = false,
    partner = "Unknown",
    start_time = 0,
    items_sent = {},
    items_received = {},
}

local function get_timestamp()
    local now = os.clock()
    local ms = math.floor((now % 1) * 1000)
    return string.format("%s.%03d", os.date("%H:%M:%S"), ms)
end

local function safe_serialize(val)
    local t = typeof(val)
    if t == "Instance" then
        return string.format("%s(%s)", val.Name, val.ClassName)
    elseif t == "table" then
        local s, res = pcall(function() return http_service:JSONEncode(val) end)
        if s and res then return res end
        local parts = {}
        for k, v in pairs(val) do
            table.insert(parts, string.format("%s=%s", tostring(k), tostring(v)))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    else
        return tostring(val)
    end
end

local function refresh_log_display()
    if not log_text_box or not log_scroll then return end
    
    local filtered = {}
    for _, item in ipairs(all_logs) do
        if active_filter == "ALL" or item.tag == active_filter then
            table.insert(filtered, item.line)
        end
    end

    local full_text = table.concat(filtered, "\n")
    log_text_box.Text = full_text
    log_text_box.Size = UDim2.new(1, -10, 0, math.max(#filtered * 15 + 20, 160))
    log_scroll.CanvasSize = UDim2.new(0, 0, 0, math.max(#filtered * 15 + 30, 170))
    log_scroll.CanvasPosition = Vector2.new(0, log_scroll.CanvasSize.Y.Offset)
end

local function log_entry(tag, message)
    local ts = get_timestamp()
    local line = string.format("[%s] [%s] %s", ts, tag, tostring(message))
    table.insert(all_logs, { tag = tag, line = line })
    
    print(line)

    pcall(function()
        if active_filter == "ALL" or active_filter == tag then
            refresh_log_display()
        end
    end)

    pcall(function()
        if writefile then
            local lines = {}
            for _, item in ipairs(all_logs) do
                table.insert(lines, item.line)
            end
            writefile("trade_super_debug.txt", table.concat(lines, "\n"))
        end
    end)
end

-- ==============================================================================
-- 2. ITEM & INVENTORY RESOLVER (Metadata Lookup)
-- ==============================================================================
local item_utility = nil
local player_data = nil

pcall(function()
    local rep = game:GetService("ReplicatedStorage")
    local packages = rep:FindFirstChild("Packages")
    local replion_pkg = packages and packages:FindFirstChild("Replion")
    if replion_pkg then
        local success, replion_mod = pcall(require, replion_pkg)
        if success and replion_mod and replion_mod.Client then
            pcall(function()
                player_data = replion_mod.Client:GetReplion("Data") or replion_mod.Client:WaitReplion("Data", 3)
            end)
        end
    end

    local shared = rep:FindFirstChild("Shared")
    local iu = shared and shared:FindFirstChild("ItemUtility")
    if iu then
        pcall(function() item_utility = require(iu) end)
    end
end)

local function resolve_item_info(uuid)
    if not uuid or uuid == "" then return nil end
    if player_data then
        local inv = nil
        pcall(function() inv = player_data:Get("Inventory") end)
        local items = inv and inv.Items
        if items then
            for _, it in ipairs(items) do
                if it and it.UUID == uuid then
                    local name = "Item_" .. tostring(it.Id or "Unknown")
                    local tier = ""
                    local mut = {}

                    if it.Id and item_utility then
                        local data = nil
                        pcall(function() data = item_utility:GetItemData(it.Id) end)
                        if data and data.Data then
                            name = data.Data.Name or name
                            tier = data.Data.Tier and tostring(data.Data.Tier) or ""
                        end
                    end

                    if it.Mutation then table.insert(mut, tostring(it.Mutation)) end
                    if it.Shiny then table.insert(mut, "Shiny") end
                    if it.Sparkling then table.insert(mut, "Sparkling") end
                    if it.Big then table.insert(mut, "Giant") end

                    local mut_str = #mut > 0 and table.concat(mut, ", ") or "Normal"
                    local weight_str = it.Weight and string.format("%.1fkg", it.Weight) or nil

                    return {
                        name = name,
                        tier = tier ~= "" and tier or "Common",
                        mutation = mut_str,
                        weight = weight_str,
                        uuid = uuid
                    }
                end
            end
        end
    end
    return nil
end

-- ==============================================================================
-- 3. IN-GAME UI CONSOLE
-- ==============================================================================
local function create_spy_gui()
    local parent_gui = nil
    if gethui then pcall(function() parent_gui = gethui() end) end
    if not parent_gui then
        pcall(function()
            local test = Instance.new("ScreenGui")
            test.Parent = game:GetService("CoreGui")
            test:Destroy()
            parent_gui = game:GetService("CoreGui")
        end)
    end
    if not parent_gui then parent_gui = player_gui end

    local old = parent_gui:FindFirstChild("NoirHub_TradeSpyConsole")
    if old then pcall(function() old:Destroy() end) end

    local gui = Instance.new("ScreenGui")
    gui.Name = "NoirHub_TradeSpyConsole"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 2147483647
    gui.Parent = parent_gui

    -- Main Window
    local main = Instance.new("Frame")
    main.Name = "ConsoleFrame"
    main.Size = UDim2.new(0, 440, 0, 270)
    main.Position = UDim2.new(0.5, -220, 0.45, 0)
    main.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
    main.BackgroundTransparency = 0.1
    main.BorderSizePixel = 0
    main.Active = true
    main.ZIndex = 100
    main.Parent = gui

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 255, 170)
    stroke.Thickness = 1.5
    stroke.Parent = main

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = main

    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 28)
    header.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
    header.ZIndex = 101
    header.Parent = main

    local h_corner = Instance.new("UICorner")
    h_corner.CornerRadius = UDim.new(0, 8)
    h_corner.Parent = header

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.50, 0, 1, 0)
    title.Position = UDim2.new(0, 8, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🕵️ Trade Super Debugger [v6.4]"
    title.TextColor3 = Color3.fromRGB(0, 255, 170)
    title.TextSize = 10
    title.Font = Enum.Font.SourceSansBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 102
    title.Parent = header

    -- Minimize Button
    local min_btn = Instance.new("TextButton")
    min_btn.Size = UDim2.new(0, 20, 0, 20)
    min_btn.Position = UDim2.new(1, -24, 0.5, -10)
    min_btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    min_btn.Text = "─"
    min_btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    min_btn.TextSize = 11
    min_btn.Font = Enum.Font.SourceSansBold
    min_btn.ZIndex = 102
    min_btn.Parent = header
    Instance.new("UICorner", min_btn).CornerRadius = UDim.new(0, 4)

    -- Clear Button
    local clear_btn = Instance.new("TextButton")
    clear_btn.Size = UDim2.new(0, 42, 0, 20)
    clear_btn.Position = UDim2.new(1, -72, 0.5, -10)
    clear_btn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    clear_btn.Text = "Clear"
    clear_btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    clear_btn.TextSize = 9
    clear_btn.Font = Enum.Font.SourceSansBold
    clear_btn.ZIndex = 102
    clear_btn.Parent = header
    Instance.new("UICorner", clear_btn).CornerRadius = UDim.new(0, 4)

    -- Copy All Button
    local copy_btn = Instance.new("TextButton")
    copy_btn.Size = UDim2.new(0, 56, 0, 20)
    copy_btn.Position = UDim2.new(1, -134, 0.5, -10)
    copy_btn.BackgroundColor3 = Color3.fromRGB(0, 160, 110)
    copy_btn.Text = "📋 Copy"
    copy_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    copy_btn.TextSize = 9
    copy_btn.Font = Enum.Font.SourceSansBold
    copy_btn.ZIndex = 102
    copy_btn.Parent = header
    Instance.new("UICorner", copy_btn).CornerRadius = UDim.new(0, 4)

    -- Floating Icon
    local floating_btn = Instance.new("TextButton")
    floating_btn.Size = UDim2.new(0, 38, 0, 38)
    floating_btn.Position = UDim2.new(0, 15, 0.5, 30)
    floating_btn.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    floating_btn.Text = "🕵️"
    floating_btn.TextSize = 18
    floating_btn.Visible = false
    floating_btn.ZIndex = 200
    floating_btn.Parent = gui
    Instance.new("UICorner", floating_btn).CornerRadius = UDim.new(0, 8)
    local flt_s = Instance.new("UIStroke", floating_btn)
    flt_s.Color = Color3.fromRGB(0, 255, 170)
    flt_s.Thickness = 1.5

    min_btn.MouseButton1Click:Connect(function()
        main.Visible = false
        floating_btn.Visible = true
    end)

    floating_btn.MouseButton1Click:Connect(function()
        main.Visible = true
        floating_btn.Visible = false
    end)

    clear_btn.MouseButton1Click:Connect(function()
        all_logs = {}
        log_entry("LOG", "Console logs cleared.")
        refresh_log_display()
    end)

    copy_btn.MouseButton1Click:Connect(function()
        if setclipboard then
            local lines = {}
            for _, item in ipairs(all_logs) do table.insert(lines, item.line) end
            setclipboard(table.concat(lines, "\n"))
            copy_btn.Text = "✅ Copied"
            task.delay(1.5, function() copy_btn.Text = "📋 Copy" end)
        else
            copy_btn.Text = "No Clip"
            task.delay(1.5, function() copy_btn.Text = "📋 Copy" end)
        end
    end)

    -- Filter Bar
    local filter_bar = Instance.new("Frame")
    filter_bar.Size = UDim2.new(1, -12, 0, 22)
    filter_bar.Position = UDim2.new(0, 6, 0, 32)
    filter_bar.BackgroundTransparency = 1
    filter_bar.ZIndex = 101
    filter_bar.Parent = main

    local filter_layout = Instance.new("UIListLayout")
    filter_layout.FillDirection = Enum.FillDirection.Horizontal
    filter_layout.Padding = UDim.new(0, 4)
    filter_layout.Parent = filter_bar

    local filter_buttons = {}
    local function make_filter_btn(tag, label_text)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 52, 1, 0)
        btn.BackgroundColor3 = active_filter == tag and Color3.fromRGB(0, 200, 130) or Color3.fromRGB(25, 25, 30)
        btn.Text = label_text
        btn.TextColor3 = active_filter == tag and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(200, 200, 200)
        btn.TextSize = 8.5
        btn.Font = Enum.Font.SourceSansBold
        btn.ZIndex = 102
        btn.Parent = filter_bar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

        filter_buttons[tag] = btn

        btn.MouseButton1Click:Connect(function()
            active_filter = tag
            for t, b in pairs(filter_buttons) do
                b.BackgroundColor3 = (t == active_filter) and Color3.fromRGB(0, 200, 130) or Color3.fromRGB(25, 25, 30)
                b.TextColor3 = (t == active_filter) and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(200, 200, 200)
            end
            refresh_log_display()
        end)
    end

    make_filter_btn("ALL", "ALL")
    make_filter_btn("TRADE", "FLOW")
    make_filter_btn("ITEM", "ITEMS")
    make_filter_btn("REMOTE", "NET")
    make_filter_btn("PROMPT", "PROMPT")
    make_filter_btn("GUI", "BUTTONS")
    make_filter_btn("CHAT", "CHAT")

    -- Log Scroll & Text Box
    log_scroll = Instance.new("ScrollingFrame")
    log_scroll.Size = UDim2.new(1, -12, 1, -80)
    log_scroll.Position = UDim2.new(0, 6, 0, 58)
    log_scroll.BackgroundColor3 = Color3.fromRGB(6, 6, 8)
    log_scroll.BackgroundTransparency = 0.2
    log_scroll.BorderSizePixel = 0
    log_scroll.ScrollBarThickness = 5
    log_scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 170)
    log_scroll.Active = true
    log_scroll.ZIndex = 101
    log_scroll.Parent = main
    Instance.new("UICorner", log_scroll).CornerRadius = UDim.new(0, 4)

    log_text_box = Instance.new("TextBox")
    log_text_box.Size = UDim2.new(1, -10, 1, 0)
    log_text_box.Position = UDim2.new(0, 5, 0, 2)
    log_text_box.BackgroundTransparency = 1
    log_text_box.Text = ""
    log_text_box.TextColor3 = Color3.fromRGB(200, 255, 230)
    log_text_box.TextSize = 8.5
    log_text_box.Font = Enum.Font.Code
    log_text_box.TextXAlignment = Enum.TextXAlignment.Left
    log_text_box.TextYAlignment = Enum.TextYAlignment.Top
    log_text_box.ClearTextOnFocus = false
    log_text_box.TextEditable = false
    log_text_box.ZIndex = 102
    log_text_box.Parent = log_scroll

    -- Bottom Status Bar
    status_indicator = Instance.new("TextLabel")
    status_indicator.Size = UDim2.new(1, -12, 0, 16)
    status_indicator.Position = UDim2.new(0, 6, 1, -18)
    status_indicator.BackgroundTransparency = 1
    status_indicator.Text = "Status: Idle | IsTrading: false"
    status_indicator.TextColor3 = Color3.fromRGB(150, 150, 150)
    status_indicator.TextSize = 8.5
    status_indicator.Font = Enum.Font.SourceSans
    status_indicator.TextXAlignment = Enum.TextXAlignment.Left
    status_indicator.ZIndex = 102
    status_indicator.Parent = main

    -- Dragging
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
end

create_spy_gui()

-- ==============================================================================
-- 4. REMOTE RESOLVER & HASH DICTIONARY
-- ==============================================================================
local trade_remote_names = {
    SendTradeOffer     = true,
    AcceptTradeOffer   = true,
    DeclineTradeOffer  = true,
    TradeOfferReceived = true,
    TradeStarted       = true,
    TradeEnded         = true,
    AddItem            = true,
    RemoveItem         = true,
    SetReady           = true,
    ConfirmTrade       = true,
    CancelTrade        = true,
}

local discovered_remotes = {}  -- [key] = RemoteInstance
local discovered_hashes  = {}  -- [hash_name] = key
local discovered_objects = {}  -- [Instance] = key

local function resolve_all_remotes()
    pcall(function()
        local net_folder = nil
        pcall(function()
            net_folder = replicated_storage.Packages._Index["sleitnick_net@0.2.0"].net
        end)
        if not net_folder then
            pcall(function()
                for _, d in ipairs(replicated_storage:GetDescendants()) do
                    if d.Name == "net" and d.Parent and string.find(string.lower(d.Parent.Name), "sleitnick", 1, true) then
                        net_folder = d
                        break
                    end
                end
            end)
        end

        if not net_folder then
            log_entry("WARN", "Tidak dapat menemukan folder sleitnick_net!")
            return
        end

        local children = net_folder:GetChildren()
        for i, child in ipairs(children) do
            for key, _ in pairs(trade_remote_names) do
                if string.find(child.Name, key, 1, true) then
                    discovered_remotes[key] = child
                    discovered_objects[child] = key

                    -- Sibling hash lookup (RF/ or RE/)
                    for j = i + 1, math.min(i + 4, #children) do
                        local next_c = children[j]
                        local n_name = next_c.Name
                        if string.sub(n_name, 1, 3) == "RF/" or string.sub(n_name, 1, 3) == "RE/" then
                            discovered_remotes[key .. "_hash"] = next_c
                            discovered_hashes[n_name] = key
                            discovered_objects[next_c] = key
                            break
                        end
                    end
                end
            end
        end
    end)
end

resolve_all_remotes()

local remote_summary = {}
for k, obj in pairs(discovered_remotes) do
    table.insert(remote_summary, string.format("%s->%s", k, obj.Name))
end
log_entry("INIT", string.format("Detected %d Trade Remotes: [%s]", #remote_summary, table.concat(remote_summary, ", ")))

-- ==============================================================================
-- 5. INBOUND EVENT SPY (TradeOfferReceived, TradeStarted, TradeEnded)
-- ==============================================================================
local function connect_inbound(key, callback)
    pcall(function()
        local r = discovered_remotes[key]
        if r and r:IsA("RemoteEvent") then r.OnClientEvent:Connect(callback) end
        local r_hash = discovered_remotes[key .. "_hash"]
        if r_hash and r_hash:IsA("RemoteEvent") and r_hash ~= r then r_hash.OnClientEvent:Connect(callback) end
    end)
end

connect_inbound("TradeOfferReceived", function(requester, ...)
    local req_name = typeof(requester) == "Instance" and requester.Name or tostring(requester)
    log_entry("TRADE", string.format("📩 [OFFER RECEIVED] Masuk dari: %s | Extra: %s", req_name, safe_serialize({...})))
    if status_indicator then
        status_indicator.Text = "Status: Offer dari " .. req_name
        status_indicator.TextColor3 = Color3.fromRGB(255, 200, 0)
    end
end)

connect_inbound("TradeStarted", function(...)
    local args = { ... }
    local session_id = args[1] or "Unknown"
    current_session.active = true
    current_session.start_time = tick()
    current_session.items_sent = {}
    current_session.items_received = {}

    log_entry("TRADE", string.format("🚀 [TRADE STARTED] Sesi aktif! Session ID: %s | FullArgs: %s", tostring(session_id), safe_serialize(args)))
    if status_indicator then
        status_indicator.Text = "Status: Trade Aktif! (Session: " .. tostring(session_id) .. ")"
        status_indicator.TextColor3 = Color3.fromRGB(0, 255, 170)
    end
end)

connect_inbound("TradeEnded", function(...)
    local args = { ... }
    local elapsed = current_session.active and (tick() - current_session.start_time) or 0
    current_session.active = false

    log_entry("TRADE", string.format("🏁 [TRADE ENDED] Sesi selesai setelah %.1fs! Args: %s", elapsed, safe_serialize(args)))
    if status_indicator then
        status_indicator.Text = "Status: Idle | Trade Selesai"
        status_indicator.TextColor3 = Color3.fromRGB(150, 150, 150)
    end

    -- Session Recap
    local items_count = #current_session.items_sent
    log_entry("TRADE", string.format("📊 [RECAP] Total Item Terkirim: %d | Partner: %s | Durasi: %.1fs", items_count, current_session.partner, elapsed))
end)

-- ==============================================================================
-- 6. OUTGOING REMOTE SPY (namecall + Return Value Interception)
-- ==============================================================================
local function process_outgoing_call(remote_obj, method, args)
    local obj_name = tostring(remote_obj.Name)
    local obj_lower = string.lower(obj_name)
    local logical = discovered_hashes[obj_name] or discovered_objects[remote_obj]

    local is_hash = string.sub(obj_name, 1, 3) == "RF/" or string.sub(obj_name, 1, 3) == "RE/"
    local is_relevant = logical ~= nil or is_hash
        or string.find(obj_lower, "trade", 1, true)
        or string.find(obj_lower, "offer", 1, true)
        or string.find(obj_lower, "item", 1, true)
        or string.find(obj_lower, "ready", 1, true)
        or string.find(obj_lower, "confirm", 1, true)

    if not is_relevant then return nil end

    local action_name = logical or obj_name
    local tag = "REMOTE"
    local formatted_msg = ""

    if action_name == "SendTradeOffer" then
        tag = "TRADE"
        local target = args[1]
        local t_name = typeof(target) == "Instance" and target.Name or tostring(target)
        current_session.partner = t_name
        formatted_msg = string.format("📤 [SEND OFFER] Mengirim tawaran trade ke: %s", t_name)

    elseif action_name == "AcceptTradeOffer" then
        tag = "TRADE"
        local req = args[1]
        local r_name = typeof(req) == "Instance" and req.Name or tostring(req)
        current_session.partner = r_name
        formatted_msg = string.format("🤝 [ACCEPT OFFER] Menerima tawaran trade dari: %s", r_name)

    elseif action_name == "AddItem" then
        tag = "ITEM"
        local category = tostring(args[1] or "Unknown")
        local uuid = tostring(args[2] or "Unknown")
        local meta = resolve_item_info(uuid)

        if meta then
            table.insert(current_session.items_sent, meta.name)
            formatted_msg = string.format("📦 [ADD ITEM] %s: \"%s\" (Tier: %s | Mutasi: %s%s)", 
                category, meta.name, meta.tier, meta.mutation, meta.weight and (" | " .. meta.weight) or "")
        else
            formatted_msg = string.format("📦 [ADD ITEM] %s (UUID: %s)", category, uuid)
        end

    elseif action_name == "RemoveItem" then
        tag = "ITEM"
        local uuid = tostring(args[1] or "Unknown")
        local meta = resolve_item_info(uuid)
        formatted_msg = string.format("🗑️ [REMOVE ITEM] %s (UUID: %s)", meta and meta.name or "Item", uuid)

    elseif action_name == "SetReady" then
        tag = "TRADE"
        local is_ready = tostring(args[1])
        formatted_msg = string.format("🚦 [SET READY] Status Ready diubah -> %s", is_ready)

    elseif action_name == "ConfirmTrade" then
        tag = "TRADE"
        formatted_msg = "🔒 [CONFIRM TRADE] Menekan Konfirmasi Trade (Mengunci Transaksi)!"

    else
        local s_args = {}
        for idx, v in ipairs(args) do
            table.insert(s_args, string.format("#%d:%s", idx, safe_serialize(v)))
        end
        formatted_msg = string.format("<<< [OUTGOING] %s:%s([%s])", action_name, method, table.concat(s_args, ", "))
    end

    return tag, formatted_msg
end

-- Hook __namecall
if hookmetamethod then
    local old_namecall
    pcall(function()
        old_namecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if (method == "InvokeServer" or method == "FireServer") and typeof(self) == "Instance" then
                local args = { ... }
                local tag, msg = process_outgoing_call(self, method, args)
                if tag and msg then
                    log_entry(tag, msg)
                end
            end
            return old_namecall(self, ...)
        end)
    end)
end

-- Direct hookfunction on discovered RemoteFunctions (to capture return values!)
if hookfunction then
    for key, robj in pairs(discovered_remotes) do
        if typeof(robj) == "Instance" and robj:IsA("RemoteFunction") then
            pcall(function()
                local old_invoke
                old_invoke = hookfunction(robj.InvokeServer, function(self, ...)
                    local args = { ... }
                    local tag, msg = process_outgoing_call(self, "InvokeServer", args)
                    if tag and msg and not hookmetamethod then
                        log_entry(tag, msg)
                    end
                    local results = { old_invoke(self, ...) }
                    if tag == "ITEM" or tag == "TRADE" then
                        log_entry("REMOTE", string.format("↩️ [RETURN %s] -> %s", key, safe_serialize(results)))
                    end
                    return unpack(results)
                end)
            end)
        end
    end
end

-- ==============================================================================
-- 7. ATTRIBUTE & PLAYER STATE SPY
-- ==============================================================================
local_player:GetAttributeChangedSignal("IsTrading"):Connect(function()
    local val = local_player:GetAttribute("IsTrading")
    log_entry("TRADE", string.format("🏷️ [ATTRIBUTE] LocalPlayer:GetAttribute('IsTrading') -> %s", tostring(val)))
    if status_indicator then
        status_indicator.Text = string.format("Status: %s | IsTrading: %s", val and "Trade Aktif" or "Idle", tostring(val))
        status_indicator.TextColor3 = val and Color3.fromRGB(0, 255, 170) or Color3.fromRGB(150, 150, 150)
    end
end)

-- ==============================================================================
-- 8. GUI BUTTONS & USER INTERACTION SPY
-- ==============================================================================
local spied_buttons = {}
local function attach_button_spy(btn, path)
    if not btn or not btn:IsA("GuiButton") or spied_buttons[btn] then return end
    spied_buttons[btn] = true

    local btn_text = (btn:IsA("TextButton") and btn.Text ~= "") and string.format(" ('%s')", btn.Text) or ""

    btn.Activated:Connect(function()
        log_entry("GUI", string.format("👆 [BUTTON CLICK: Activated] %s%s", path, btn_text))
    end)
    btn.MouseButton1Click:Connect(function()
        log_entry("GUI", string.format("👆 [BUTTON CLICK: Mouse1] %s%s", path, btn_text))
    end)
end

local function scan_and_attach_btn(btn)
    if not btn or not btn:IsA("GuiButton") or spied_buttons[btn] then return end
    local name_l = string.lower(btn.Name)
    local text_l = (btn:IsA("TextButton") and string.lower(btn.Text)) or ""

    local is_relevant = string.find(name_l, "trade", 1, true)
        or string.find(name_l, "offer", 1, true)
        or string.find(name_l, "accept", 1, true)
        or string.find(name_l, "decline", 1, true)
        or string.find(name_l, "yes", 1, true)
        or string.find(name_l, "no", 1, true)
        or string.find(name_l, "ready", 1, true)
        or string.find(name_l, "confirm", 1, true)
        or string.find(text_l, "ready", 1, true)
        or string.find(text_l, "confirm", 1, true)
        or (btn.Parent and (btn.Parent.Name == "Options" or btn.Parent.Name == "Buttons"))

    if is_relevant then
        attach_button_spy(btn, btn.Name)
    end
end

for _, desc in ipairs(player_gui:GetDescendants()) do scan_and_attach_btn(desc) end
player_gui.DescendantAdded:Connect(scan_and_attach_btn)

-- ==============================================================================
-- 9. PROMPT GUI SPY (PlayerGui.Prompt)
-- ==============================================================================
local function monitor_prompt(p_gui)
    if not p_gui then return end
    log_entry("PROMPT", string.format("🔔 [PROMPT DETECTED] %s (Enabled: %s)", p_gui.Name, tostring(p_gui.Enabled)))

    p_gui:GetPropertyChangedSignal("Enabled"):Connect(function()
        log_entry("PROMPT", string.format("🔔 [PROMPT GUI] Enabled -> %s", tostring(p_gui.Enabled)))
    end)

    local blackout = p_gui:FindFirstChild("Blackout")
    if blackout then
        blackout:GetPropertyChangedSignal("Visible"):Connect(function()
            log_entry("PROMPT", string.format("👁️ [BLACKOUT] Visible -> %s", tostring(blackout.Visible)))
        end)
        blackout:GetPropertyChangedSignal("Position"):Connect(function()
            log_entry("PROMPT", string.format("📍 [BLACKOUT] Position -> %s", tostring(blackout.Position)))
        end)

        local label = blackout:FindFirstChild("Label")
        if label then
            log_entry("PROMPT", string.format("💬 [PROMPT TEXT] '%s'", label.Text))
            label:GetPropertyChangedSignal("Text"):Connect(function()
                log_entry("PROMPT", string.format("💬 [PROMPT TEXT] -> '%s'", label.Text))
            end)
        end

        local options = blackout:FindFirstChild("Options")
        if options then
            for _, b in ipairs(options:GetChildren()) do
                if b:IsA("GuiButton") then attach_button_spy(b, "Prompt.Options." .. b.Name) end
            end
        end
    end
end

-- ==============================================================================
-- 10. TRADING WINDOW DEEP SPY (Slots, Countdown, Partner Status)
-- ==============================================================================
local function monitor_trading_window(t_gui)
    if not t_gui then return end
    log_entry("TRADE", string.format("🪟 [TRADING WINDOW OPEN] %s (Enabled: %s)", t_gui.Name, tostring(t_gui.Enabled)))

    t_gui:GetPropertyChangedSignal("Enabled"):Connect(function()
        log_entry("TRADE", string.format("🪟 [TRADING WINDOW] Enabled -> %s", tostring(t_gui.Enabled)))
    end)

    local function wire_element(elem)
        if elem:IsA("GuiButton") then
            attach_button_spy(elem, t_gui.Name .. "." .. elem.Name)
        elseif elem:IsA("TextLabel") then
            local l_text = elem.Text or ""
            local l_name = string.lower(elem.Name)

            -- Countdown detection
            local sec = string.match(l_text, "%((%d)s?%)") or string.match(l_text, "Countdown: (%d)") or string.match(l_text, "Confirm%s*%(?(%d)%)?")
            if sec then
                log_entry("TRADE", string.format("⏱️ [COUNTDOWN] Timer aktif: %ss", sec))
            end

            elem:GetPropertyChangedSignal("Text"):Connect(function()
                local new_t = elem.Text or ""
                local s = string.match(new_t, "%((%d)s?%)") or string.match(new_t, "Countdown: (%d)") or string.match(new_t, "Confirm%s*%(?(%d)%)?")
                if s then
                    log_entry("TRADE", string.format("⏱️ [COUNTDOWN] Timer: %ss (%s)", s, elem.Name))
                elseif string.find(l_name, "status", 1, true) or string.find(l_name, "ready", 1, true) or string.find(l_name, "partner", 1, true) then
                    log_entry("TRADE", string.format("ℹ️ [STATUS TEXT] %s -> '%s'", elem.Name, new_t))
                end
            end)
        elseif elem:IsA("Frame") or elem:IsA("ImageLabel") then
            -- Item slot grid change detection
            local p = elem.Parent
            if p and (string.find(string.lower(p.Name), "slot", 1, true) or string.find(string.lower(p.Name), "grid", 1, true) or string.find(string.lower(p.Name), "left", 1, true) or string.find(string.lower(p.Name), "right", 1, true)) then
                log_entry("ITEM", string.format("🧩 [SLOT UPDATE] Elemen baru di slot trade: %s (Parent: %s)", elem.Name, p.Name))
            end
        end
    end

    for _, desc in ipairs(t_gui:GetDescendants()) do wire_element(desc) end
    t_gui.DescendantAdded:Connect(wire_element)
end

-- Scan existing GUIs
local existing_prompt = player_gui:FindFirstChild("Prompt")
if existing_prompt then monitor_prompt(existing_prompt) end

local existing_trade = player_gui:FindFirstChild("! Trading") or player_gui:FindFirstChild("Trading")
if existing_trade then monitor_trading_window(existing_trade) end

player_gui.ChildAdded:Connect(function(child)
    if child.Name == "Prompt" then
        monitor_prompt(child)
    elseif child.Name == "! Trading" or child.Name == "Trading" then
        monitor_trading_window(child)
    end
end)

-- ==============================================================================
-- 11. CHAT SPY (Trade Completion Verification)
-- ==============================================================================
local function process_chat_message(sender_name, msg_text)
    if not msg_text then return end
    local lower = string.lower(msg_text)
    if string.find(lower, "trade", 1, true) or string.find(lower, "completed", 1, true) or string.find(lower, "declined", 1, true) or string.find(lower, "cancelled", 1, true) then
        log_entry("CHAT", string.format("💬 [CHAT MSG] [%s]: %s", tostring(sender_name or "System"), msg_text))
        if string.find(lower, "completed", 1, true) then
            log_entry("TRADE", "🎉 [TRADE VERIFIED SUCCESSFUL] Transaksi trade tercatat SUKSES di log chat server!")
        end
    end
end

pcall(function()
    if text_chat_service then
        text_chat_service.MessageReceived:Connect(function(msg)
            if msg and msg.Text then
                local s_name = msg.TextSource and msg.TextSource.Name or "System"
                process_chat_message(s_name, msg.Text)
            end
        end)
    end
end)

pcall(function()
    local chat_events = replicated_storage:FindFirstChild("DefaultChatSystemChatEvents")
    if chat_events then
        local on_msg = chat_events:FindFirstChild("OnMessageDoneFiltering")
        if on_msg then
            on_msg.OnClientEvent:Connect(function(data)
                if data and data.Message then
                    process_chat_message(data.FromSpeaker, data.Message)
                end
            end)
        end
    end
end)

-- ==============================================================================
-- 12. CLEANUP HANDLER
-- ==============================================================================
_G.NoirHub_TradeSpy_Cleanup = function()
    _G.NoirHub_TradeSpy_ScriptID = nil
    pcall(function()
        local core = gethui and gethui() or game:GetService("CoreGui")
        local old = core:FindFirstChild("NoirHub_TradeSpyConsole")
        if old then old:Destroy() end
    end)
    pcall(function()
        local old = player_gui:FindFirstChild("NoirHub_TradeSpyConsole")
        if old then old:Destroy() end
    end)
    log_entry("CLEANUP", "Trade Debugger dihentikan.")
end

log_entry("READY", "=== Trade Super Debugger [v6.4] Siap! Melacak SendOffer -> AddItem -> Countdown -> Confirm -> Selesai ===")
