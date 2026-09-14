--[[
    NOIR HUB - TRADE SUPER DEBUGGER [v6.2]
    Merekam 100% data trade: Remote Masuk/Keluar, GUI Prompt, Window Trading, Klik Tombol, Attribute IsTrading.
    Ringan, stabil di mobile/Android executor, tidak spam/freeze.
]]

local cloneref = cloneref or function(ref) return ref end

local players            = cloneref(game:GetService("Players"))
local local_player       = players.LocalPlayer
local player_gui         = cloneref(local_player:WaitForChild("PlayerGui"))
local replicated_storage = cloneref(game:GetService("ReplicatedStorage"))
local user_input_service = cloneref(game:GetService("UserInputService"))
local http_service       = cloneref(game:GetService("HttpService"))

-- Cleanup previous spy
if _G.NoirHub_TradeSpy_Cleanup then
    pcall(_G.NoirHub_TradeSpy_Cleanup)
end

local spy_active = true
local script_id = os.clock()
_G.NoirHub_TradeSpy_ScriptID = script_id

-- ==============================================================================
-- 1. LOG STORAGE & CONSOLE ENGINE
-- ==============================================================================
local all_logs = {}
local active_filter = "ALL"
local log_text_box = nil
local log_scroll = nil
local status_indicator = nil

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
-- 2. IN-GAME UI CONSOLE
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
    main.Size = UDim2.new(0, 420, 0, 260)
    main.Position = UDim2.new(0.5, -210, 0.5, 0)
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
    title.Text = "🕵️ Trade Debugger [v6.2]"
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

    local min_c = Instance.new("UICorner")
    min_c.CornerRadius = UDim.new(0, 4)
    min_c.Parent = min_btn

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

    local clr_c = Instance.new("UICorner")
    clr_c.CornerRadius = UDim.new(0, 4)
    clr_c.Parent = clear_btn

    -- Copy All Button
    local copy_btn = Instance.new("TextButton")
    copy_btn.Size = UDim2.new(0, 62, 0, 20)
    copy_btn.Position = UDim2.new(1, -140, 0.5, -10)
    copy_btn.BackgroundColor3 = Color3.fromRGB(0, 160, 110)
    copy_btn.Text = "📋 Copy"
    copy_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    copy_btn.TextSize = 9
    copy_btn.Font = Enum.Font.SourceSansBold
    copy_btn.ZIndex = 102
    copy_btn.Parent = header

    local cpy_c = Instance.new("UICorner")
    cpy_c.CornerRadius = UDim.new(0, 4)
    cpy_c.Parent = copy_btn

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

    local flt_c = Instance.new("UICorner")
    flt_c.CornerRadius = UDim.new(0, 8)
    flt_c.Parent = floating_btn

    local flt_s = Instance.new("UIStroke")
    flt_s.Color = Color3.fromRGB(0, 255, 170)
    flt_s.Thickness = 1.5
    flt_s.Parent = floating_btn

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
        local full = {}
        for _, item in ipairs(all_logs) do
            table.insert(full, item.line)
        end
        local content = table.concat(full, "\n")
        local success = false
        if setclipboard then pcall(function() setclipboard(content); success = true end) end
        if not success and toclipboard then pcall(function() toclipboard(content); success = true end) end
        
        copy_btn.Text = success and "✅ Copied!" or "Select Text"
        task.delay(1.5, function() copy_btn.Text = "📋 Copy" end)
    end)

    -- Filter Bar
    local filter_bar = Instance.new("Frame")
    filter_bar.Size = UDim2.new(1, -12, 0, 20)
    filter_bar.Position = UDim2.new(0, 6, 0, 32)
    filter_bar.BackgroundTransparency = 1
    filter_bar.ZIndex = 101
    filter_bar.Parent = main

    local filter_layout = Instance.new("UIListLayout")
    filter_layout.FillDirection = Enum.FillDirection.Horizontal
    filter_layout.Padding = UDim.new(0, 4)
    filter_layout.Parent = filter_bar

    local filter_buttons = {}
    local function make_filter_btn(tag_name, label)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 52, 1, 0)
        btn.BackgroundColor3 = (active_filter == tag_name) and Color3.fromRGB(0, 170, 115) or Color3.fromRGB(25, 25, 30)
        btn.Text = label
        btn.TextColor3 = Color3.fromRGB(240, 240, 240)
        btn.TextSize = 8
        btn.Font = Enum.Font.SourceSansBold
        btn.ZIndex = 102
        btn.Parent = filter_bar

        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 4)
        bc.Parent = btn

        filter_buttons[tag_name] = btn

        btn.MouseButton1Click:Connect(function()
            active_filter = tag_name
            for k, b in pairs(filter_buttons) do
                b.BackgroundColor3 = (k == active_filter) and Color3.fromRGB(0, 170, 115) or Color3.fromRGB(25, 25, 30)
            end
            refresh_log_display()
        end)
    end

    make_filter_btn("ALL", "ALL")
    make_filter_btn("REMOTE", "REMOTES")
    make_filter_btn("TRADE", "TRADE")
    make_filter_btn("PROMPT", "PROMPT")
    make_filter_btn("GUI", "GUI/BTNS")

    -- Log Scroll & Text Box
    log_scroll = Instance.new("ScrollingFrame")
    log_scroll.Size = UDim2.new(1, -12, 1, -78)
    log_scroll.Position = UDim2.new(0, 6, 0, 56)
    log_scroll.BackgroundColor3 = Color3.fromRGB(6, 6, 8)
    log_scroll.BackgroundTransparency = 0.2
    log_scroll.BorderSizePixel = 0
    log_scroll.ScrollBarThickness = 5
    log_scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 170)
    log_scroll.Active = true
    log_scroll.ZIndex = 101
    log_scroll.Parent = main

    local sc_c = Instance.new("UICorner")
    sc_c.CornerRadius = UDim.new(0, 4)
    sc_c.Parent = log_scroll

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
    status_indicator.Text = "Status: Idle | IsTrading: false | Remotes Hooked"
    status_indicator.TextColor3 = Color3.fromRGB(150, 150, 150)
    status_indicator.TextSize = 8
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
-- 3. ENVIRONMENT & REMOTES RESOLUTION (Targeted & Hashed Resolution)
-- ==============================================================================
local exec_name = identifyexecutor and identifyexecutor() or "Unknown Executor"
log_entry("INIT", string.format("Trade Debugger [v6.2] Started on %s (%s)", local_player.Name, exec_name))

local trade_remote_names = {
    SendTradeOffer     = true,
    AcceptTradeOffer   = true,
    TradeOfferReceived = true,
    TradeStarted       = true,
    TradeEnded         = true,
    AddItem            = true,
    SetReady           = true,
    ConfirmTrade       = true,
}

local discovered_remotes = {}  -- [logical_name] = RemoteInstance
local discovered_hashes  = {}  -- [hash_name] = logical_name
local discovered_objects = {}  -- [RemoteInstance] = logical_name

local function resolve_trade_remotes()
    pcall(function()
        local net_folder = nil
        pcall(function()
            net_folder = replicated_storage.Packages._Index["sleitnick_net@0.2.0"].net
        end)
        if not net_folder then
            local rep_packages = replicated_storage:FindFirstChild("Packages")
            local index_folder = rep_packages and rep_packages:FindFirstChild("_Index")
            if index_folder then
                for _, folder in ipairs(index_folder:GetChildren()) do
                    if string.find(folder.Name, "sleitnick_net", 1, true) then
                        net_folder = folder:FindFirstChild("net")
                        if net_folder then break end
                    end
                end
            end
        end

        if not net_folder then
            log_entry("WARN", "Could not locate sleitnick_net folder in ReplicatedStorage!")
            return
        end

        local children = net_folder:GetChildren()
        for i, child in ipairs(children) do
            for key, _ in pairs(trade_remote_names) do
                if string.find(child.Name, key, 1, true) then
                    discovered_remotes[key] = child
                    discovered_objects[child] = key

                    -- Check if next sibling is a hashed remote (RF/ or RE/)
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

resolve_trade_remotes()

local remote_summary = {}
for k, obj in pairs(discovered_remotes) do
    table.insert(remote_summary, string.format("%s->%s(%s)", k, obj.Name, obj.ClassName))
end
log_entry("INIT", string.format("Found %d trade remote references: [%s]", #remote_summary, table.concat(remote_summary, ", ")))

-- Inbound Event Listeners
local function attach_inbound_listener(key, callback)
    local attached = false
    local r = discovered_remotes[key]
    if r and r:IsA("RemoteEvent") then
        r.OnClientEvent:Connect(callback)
        attached = true
    end
    local r_hash = discovered_remotes[key .. "_hash"]
    if r_hash and r_hash:IsA("RemoteEvent") and r_hash ~= r then
        r_hash.OnClientEvent:Connect(callback)
        attached = true
    end
    return attached
end

local r_offer_ok = attach_inbound_listener("TradeOfferReceived", function(requester, ...)
    local req_name = typeof(requester) == "Instance" and requester.Name or tostring(requester)
    log_entry("TRADE", string.format(">>> [INCOMING OFFER] From: %s | Extra: %s", req_name, safe_serialize({...})))
    if status_indicator then
        status_indicator.Text = "Status: Offer Received from " .. req_name
        status_indicator.TextColor3 = Color3.fromRGB(255, 200, 0)
    end
end)
if r_offer_ok then
    log_entry("INIT", "Targeted listener connected: TradeOfferReceived")
else
    log_entry("WARN", "Could not attach to TradeOfferReceived")
end

local r_start_ok = attach_inbound_listener("TradeStarted", function(...)
    log_entry("TRADE", string.format(">>> [TRADE STARTED] Session active! Args: %s", safe_serialize({...})))
    if status_indicator then
        status_indicator.Text = "Status: Trade Active! | IsTrading: " .. tostring(local_player:GetAttribute("IsTrading"))
        status_indicator.TextColor3 = Color3.fromRGB(0, 255, 170)
    end
end)
if r_start_ok then
    log_entry("INIT", "Targeted listener connected: TradeStarted")
end

local r_end_ok = attach_inbound_listener("TradeEnded", function(...)
    log_entry("TRADE", string.format(">>> [TRADE ENDED] Session closed. Args: %s", safe_serialize({...})))
    if status_indicator then
        status_indicator.Text = "Status: Idle | Trade Ended"
        status_indicator.TextColor3 = Color3.fromRGB(150, 150, 150)
    end
end)
if r_end_ok then
    log_entry("INIT", "Targeted listener connected: TradeEnded")
end

-- ==============================================================================
-- 4. OUTGOING REMOTE SPY (Dual-Mode: hookmetamethod + Direct hookfunction)
-- ==============================================================================
local namecall_hooked = false
if hookmetamethod then
    local old_namecall
    local success, err = pcall(function()
        old_namecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if (method == "InvokeServer" or method == "FireServer") and typeof(self) == "Instance" then
                local self_name = tostring(self.Name)
                local self_lower = string.lower(self_name)
                local p = self.Parent
                local p_name = p and tostring(p.Name) or ""
                local p_lower = string.lower(p_name)
                
                local is_net = string.find(p_lower, "net", 1, true) or (p and p.Parent and string.find(string.lower(tostring(p.Parent.Name)), "sleitnick", 1, true))
                local is_hash = string.sub(self_name, 1, 3) == "RF/" or string.sub(self_name, 1, 3) == "RE/"
                local is_trade_kw = string.find(self_lower, "trade", 1, true)
                    or string.find(self_lower, "offer", 1, true)
                    or string.find(self_lower, "ready", 1, true)
                    or string.find(self_lower, "confirm", 1, true)
                    or string.find(self_lower, "item", 1, true)
                    or string.find(self_lower, "accept", 1, true)
                    or string.find(self_lower, "decline", 1, true)
                
                local alias = discovered_hashes[self_name] or discovered_objects[self]
                
                if alias or is_trade_kw or (is_net and is_hash) then
                    local display_tag = alias and string.format("%s (%s)", alias, self_name) or self_name
                    local args = { ... }
                    local s_args = {}
                    for idx, val in ipairs(args) do
                        table.insert(s_args, string.format("#%d:%s", idx, safe_serialize(val)))
                    end
                    log_entry("REMOTE", string.format("<<< [OUTGOING] %s:%s([%s])", display_tag, method, table.concat(s_args, ", ")))
                end
            end
            return old_namecall(self, ...)
        end)
    end)
    if success then
        namecall_hooked = true
        log_entry("INIT", "✅ Hooked __namecall (Global outgoing trade/net calls intercepted)")
    else
        log_entry("WARN", "hookmetamethod __namecall failed: " .. tostring(err))
    end
end

-- Direct hook on discovered RemoteFunctions / RemoteEvents
if hookfunction then
    local hooked_count = 0
    for key, robj in pairs(discovered_remotes) do
        if typeof(robj) == "Instance" then
            pcall(function()
                if robj:IsA("RemoteFunction") and robj.InvokeServer then
                    local old_inv
                    old_inv = hookfunction(robj.InvokeServer, function(self, ...)
                        if not namecall_hooked then
                            local args = { ... }
                            local s_args = {}
                            for idx, val in ipairs(args) do
                                table.insert(s_args, string.format("#%d:%s", idx, safe_serialize(val)))
                            end
                            log_entry("REMOTE", string.format("<<< [OUTGOING DIRECT] %s (%s):InvokeServer([%s])", key, robj.Name, table.concat(s_args, ", ")))
                        end
                        return old_inv(self, ...)
                    end)
                    hooked_count = hooked_count + 1
                elseif robj:IsA("RemoteEvent") and robj.FireServer then
                    local old_fire
                    old_fire = hookfunction(robj.FireServer, function(self, ...)
                        if not namecall_hooked then
                            local args = { ... }
                            local s_args = {}
                            for idx, val in ipairs(args) do
                                table.insert(s_args, string.format("#%d:%s", idx, safe_serialize(val)))
                            end
                            log_entry("REMOTE", string.format("<<< [OUTGOING DIRECT] %s (%s):FireServer([%s])", key, robj.Name, table.concat(s_args, ", ")))
                        end
                        return old_fire(self, ...)
                    end)
                    hooked_count = hooked_count + 1
                end
            end)
        end
    end
    if hooked_count > 0 then
        log_entry("INIT", string.format("✅ Direct hookfunction attached to %d targeted remotes", hooked_count))
    end
end

-- ==============================================================================
-- 5. ATTRIBUTE SPY (LocalPlayer.IsTrading)
-- ==============================================================================
local_player:GetAttributeChangedSignal("IsTrading"):Connect(function()
    local val = local_player:GetAttribute("IsTrading")
    log_entry("TRADE", string.format("[ATTRIBUTE] LocalPlayer:GetAttribute('IsTrading') -> %s", tostring(val)))
    if status_indicator then
        status_indicator.Text = string.format("Status: %s | IsTrading: %s", val and "Trading Active" or "Idle", tostring(val))
        status_indicator.TextColor3 = val and Color3.fromRGB(0, 255, 170) or Color3.fromRGB(150, 150, 150)
    end
end)

-- ==============================================================================
-- 6. PROXIMITY PROMPT & INTERACTION SPY
-- ==============================================================================
pcall(function()
    local proximity_prompt_service = cloneref(game:GetService("ProximityPromptService"))
    proximity_prompt_service.PromptTriggered:Connect(function(prompt, player)
        local act = tostring(prompt.ActionText or "")
        local obj = tostring(prompt.ObjectText or "")
        log_entry("INTERACT", string.format("[PROXIMITY PROMPT] Action: '%s' | Target: '%s' | By: %s", act, obj, tostring(player and player.Name or "Unknown")))
    end)
    proximity_prompt_service.PromptButtonHoldBegan:Connect(function(prompt, player)
        local act = tostring(prompt.ActionText or "")
        local obj = tostring(prompt.ObjectText or "")
        log_entry("INTERACT", string.format("[PROMPT HOLD BEGAN] '%s' on '%s' by %s", act, obj, tostring(player and player.Name or "Unknown")))
    end)
    log_entry("INIT", "ProximityPromptService spy connected.")
end)

-- ==============================================================================
-- 7. BUTTON & INTERACTION LOGGER (Deep & Global)
-- ==============================================================================
local spied_buttons = {}
local function spy_on_button(btn, path)
    if not btn or not btn:IsA("GuiButton") or spied_buttons[btn] then return end
    spied_buttons[btn] = true

    local btn_text = (btn:IsA("TextButton") and btn.Text ~= "") and string.format(" ('%s')", btn.Text) or ""

    btn.Activated:Connect(function()
        log_entry("GUI", string.format("[CLICK Activated] %s%s", path, btn_text))
    end)
    btn.MouseButton1Click:Connect(function()
        log_entry("GUI", string.format("[CLICK Mouse1] %s%s", path, btn_text))
    end)
end

local function check_and_spy_button(btn)
    if not btn or not btn:IsA("GuiButton") or spied_buttons[btn] then return end
    local name_l = string.lower(btn.Name)
    local text_l = (btn:IsA("TextButton") and string.lower(btn.Text)) or ""
    
    local is_relevant = string.find(name_l, "trade", 1, true)
        or string.find(name_l, "offer", 1, true)
        or string.find(name_l, "accept", 1, true)
        or string.find(name_l, "decline", 1, true)
        or string.find(name_l, "yes", 1, true)
        or string.find(name_l, "no", 1, true)
        or string.find(name_l, "close", 1, true)
        or string.find(name_l, "ready", 1, true)
        or string.find(name_l, "confirm", 1, true)
        or string.find(text_l, "trade", 1, true)
        or string.find(text_l, "offer", 1, true)
        or string.find(text_l, "accept", 1, true)
        or string.find(text_l, "yes", 1, true)
        or string.find(text_l, "no", 1, true)
        or string.find(text_l, "ready", 1, true)
        or string.find(text_l, "confirm", 1, true)
        or (btn.Parent and (btn.Parent.Name == "Options" or btn.Parent.Name == "Blackout" or string.find(string.lower(btn.Parent.Name), "trade", 1, true)))

    if is_relevant then
        spy_on_button(btn, btn.Name)
    end
end

-- Scan all existing GUI buttons in PlayerGui
for _, desc in ipairs(player_gui:GetDescendants()) do
    check_and_spy_button(desc)
end

player_gui.DescendantAdded:Connect(function(desc)
    check_and_spy_button(desc)
end)

-- ==============================================================================
-- 8. PROMPT GUI DEEP SPY (PlayerGui.Prompt)
-- ==============================================================================
local function monitor_prompt_gui(prompt_gui)
    if not prompt_gui then return end
    log_entry("PROMPT", string.format("Monitoring %s (Enabled=%s)", prompt_gui.Name, tostring(prompt_gui.Enabled)))

    prompt_gui:GetPropertyChangedSignal("Enabled"):Connect(function()
        log_entry("PROMPT", string.format("[PROMPT GUI] Enabled -> %s", tostring(prompt_gui.Enabled)))
    end)

    local blackout = prompt_gui:FindFirstChild("Blackout")
    if blackout then
        blackout:GetPropertyChangedSignal("Visible"):Connect(function()
            log_entry("PROMPT", string.format("[BLACKOUT] Visible -> %s", tostring(blackout.Visible)))
        end)
        blackout:GetPropertyChangedSignal("Position"):Connect(function()
            log_entry("PROMPT", string.format("[BLACKOUT] Position -> %s", tostring(blackout.Position)))
        end)

        local label = blackout:FindFirstChild("Label")
        if label then
            log_entry("PROMPT", string.format("[LABEL CURRENT] Text = '%s'", label.Text))
            label:GetPropertyChangedSignal("Text"):Connect(function()
                log_entry("PROMPT", string.format("[LABEL TEXT] -> '%s'", label.Text))
            end)
        end

        for _, desc in ipairs(blackout:GetDescendants()) do
            if desc:IsA("GuiButton") then
                spy_on_button(desc, "Prompt.Blackout." .. desc.Name)
            end
        end
    end

    prompt_gui.DescendantAdded:Connect(function(desc)
        if desc:IsA("TextLabel") and desc.Name == "Label" then
            log_entry("PROMPT", string.format("[NEW LABEL] Text: '%s'", desc.Text))
            desc:GetPropertyChangedSignal("Text"):Connect(function()
                log_entry("PROMPT", string.format("[LABEL TEXT] -> '%s'", desc.Text))
            end)
        elseif desc:IsA("GuiButton") then
            log_entry("PROMPT", string.format("[NEW BUTTON] %s", desc.Name))
            spy_on_button(desc, "Prompt." .. desc.Name)
        end
    end)
end

-- ==============================================================================
-- 9. TRADING WINDOW DEEP SPY (! Trading / Trading)
-- ==============================================================================
local function monitor_trading_gui(t_gui)
    if not t_gui then return end
    log_entry("TRADE", string.format(">>> Monitoring Trading Window: %s (Enabled=%s)", t_gui.Name, tostring(t_gui.Enabled)))

    t_gui:GetPropertyChangedSignal("Enabled"):Connect(function()
        log_entry("TRADE", string.format("[TRADING WINDOW] Enabled -> %s", tostring(t_gui.Enabled)))
    end)

    local function wire_elem(item)
        if item:IsA("GuiButton") then
            spy_on_button(item, t_gui.Name .. "." .. item.Name)
        elseif item:IsA("TextLabel") then
            local lower_name = string.lower(item.Name)
            if string.find(lower_name, "status", 1, true) or string.find(lower_name, "ready", 1, true) or string.find(lower_name, "confirm", 1, true) or string.find(lower_name, "partner", 1, true) then
                log_entry("TRADE", string.format("[TRADE LABEL] %s = '%s'", item.Name, item.Text))
                item:GetPropertyChangedSignal("Text"):Connect(function()
                    log_entry("TRADE", string.format("[TRADE LABEL] %s -> '%s'", item.Name, item.Text))
                end)
            end
        end
    end

    for _, desc in ipairs(t_gui:GetDescendants()) do
        wire_elem(desc)
    end

    t_gui.DescendantAdded:Connect(function(desc)
        wire_elem(desc)
    end)
end

-- Scan existing GUIs
local existing_prompt = player_gui:FindFirstChild("Prompt")
if existing_prompt then monitor_prompt_gui(existing_prompt) end

local existing_trade = player_gui:FindFirstChild("! Trading") or player_gui:FindFirstChild("Trading")
if existing_trade then monitor_trading_gui(existing_trade) end

-- Watch PlayerGui dynamically
player_gui.ChildAdded:Connect(function(child)
    if child.Name == "Prompt" then
        log_entry("PROMPT", ">>> [GUI ADDED] PlayerGui.Prompt")
        monitor_prompt_gui(child)
    elseif child.Name == "! Trading" or child.Name == "Trading" then
        log_entry("TRADE", string.format(">>> [TRADING WINDOW OPENED] %s added to PlayerGui!", child.Name))
        monitor_trading_gui(child)
    end
end)

player_gui.ChildRemoved:Connect(function(child)
    if child.Name == "Prompt" or child.Name == "! Trading" or child.Name == "Trading" then
        log_entry("GUI", string.format("<<< [GUI REMOVED] %s removed from PlayerGui", child.Name))
    end
end)

-- ==============================================================================
-- 10. CLEANUP HANDLER
-- ==============================================================================
_G.NoirHub_TradeSpy_Cleanup = function()
    spy_active = false
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
    log_entry("CLEANUP", "Trade Debugger stopped.")
end

log_entry("READY", "=== Trade Debugger [v6.2] Active! Silakan lakukan tes trade ===")
