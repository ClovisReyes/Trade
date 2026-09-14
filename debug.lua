--[[
    NOIR HUB - TRADE SUPER DEBUG LOGGER & RUNTIME INSPECTOR
    Mencatat seluruh siklus trade dari awal (offer) hingga selesai (complete/cancel).
    100% Pasif & Non-Intrusif: Aman dijalankan bersama script apapun (termasuk script Luraph/Encrypted).
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
    main.Size = UDim2.new(0, 390, 0, 250)
    main.Position = UDim2.new(0.5, -195, 0.55, 0)
    main.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
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
    title.Size = UDim2.new(0.45, 0, 1, 0)
    title.Position = UDim2.new(0, 8, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🕵️ Trade Super Debugger"
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
        btn.Size = UDim2.new(0, 50, 1, 0)
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
    make_filter_btn("PROMPT", "PROMPT")
    make_filter_btn("TRADE", "TRADE")
    make_filter_btn("ACTION", "ACTIONS")

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
    status_indicator.Text = "Status: Idle | IsTrading: false | Watching Remotes & GUI"
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
-- 3. ENVIRONMENT & REMOTES RESOLUTION
-- ==============================================================================
local exec_name = identifyexecutor and identifyexecutor() or "Unknown Executor"
log_entry("INIT", string.format("Super Debugger Started on %s (%s)", local_player.Name, exec_name))

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

local resolved_remotes = {}
pcall(function()
    local net_folder = replicated_storage.Packages._Index["sleitnick_net@0.2.0"].net
    local children = net_folder:GetChildren()
    for i, v in ipairs(children) do
        for _, logical_name in pairs(remote_map) do
            if string.find(v.Name, logical_name, 1, true) then
                for j = i + 1, #children do
                    local next_obj = children[j]
                    if string.match(next_obj.Name, "^RF/") or string.match(next_obj.Name, "^RE/") then
                        resolved_remotes[logical_name] = next_obj
                        log_entry("REMOTE", string.format("Resolved: %s -> %s (%s)", logical_name, next_obj.Name, next_obj.ClassName))
                        break
                    end
                end
                break
            end
        end
    end
end)

-- ==============================================================================
-- 4. DIRECT REMOTE EVENT LISTENERS (Incoming Events)
-- ==============================================================================
-- A. TradeOfferReceived
local r_offer = resolved_remotes["TradeOfferReceived"]
if r_offer and r_offer:IsA("RemoteEvent") then
    r_offer.OnClientEvent:Connect(function(requester, ...)
        local req_name = typeof(requester) == "Instance" and requester.Name or tostring(requester)
        log_entry("TRADE", string.format(">>> [INCOMING OFFER] From: %s | ExtraArgs: %s", req_name, http_service:JSONEncode({...})))
        if status_indicator then
            status_indicator.Text = "Status: Offer Received from " .. req_name
            status_indicator.TextColor3 = Color3.fromRGB(255, 200, 0)
        end
    end)
    log_entry("INIT", "Attached listener to TradeOfferReceived.OnClientEvent")
else
    log_entry("WARN", "TradeOfferReceived remote event not found!")
end

-- B. TradeStarted
local r_started = resolved_remotes["TradeStarted"]
if r_started and r_started:IsA("RemoteEvent") then
    r_started.OnClientEvent:Connect(function(...)
        log_entry("TRADE", string.format(">>> [TRADE STARTED] Trade session is now ACTIVE! Args: %s", http_service:JSONEncode({...})))
        if status_indicator then
            status_indicator.Text = "Status: Trade Active! | IsTrading: " .. tostring(local_player:GetAttribute("IsTrading"))
            status_indicator.TextColor3 = Color3.fromRGB(0, 255, 170)
        end
    end)
    log_entry("INIT", "Attached listener to TradeStarted.OnClientEvent")
end

-- C. TradeEnded
local r_ended = resolved_remotes["TradeEnded"]
if r_ended and r_ended:IsA("RemoteEvent") then
    r_ended.OnClientEvent:Connect(function(...)
        log_entry("TRADE", string.format(">>> [TRADE ENDED] Trade session closed. Args: %s", http_service:JSONEncode({...})))
        if status_indicator then
            status_indicator.Text = "Status: Idle | Trade Ended"
            status_indicator.TextColor3 = Color3.fromRGB(150, 150, 150)
        end
    end)
    log_entry("INIT", "Attached listener to TradeEnded.OnClientEvent")
end

-- ==============================================================================
-- 5. OUTGOING REMOTE SPY (__namecall Hook)
-- ==============================================================================
local g_meta = getrawmetatable and getrawmetatable(game) or nil
if g_meta and setreadonly and hookmetamethod then
    local old_namecall
    old_namecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = { ... }

        if (method == "InvokeServer" or method == "FireServer") and self then
            local self_name = tostring(self.Name)
            local is_trade_call = false

            for logical, remote_obj in pairs(resolved_remotes) do
                if remote_obj == self or self_name == remote_obj.Name then
                    is_trade_call = true
                    local arg_strings = {}
                    for idx, val in ipairs(args) do
                        table.insert(arg_strings, string.format("#%d:%s(%s)", idx, tostring(val), typeof(val)))
                    end
                    log_entry("REMOTE", string.format("<<< [OUTGOING] %s:%s(%s)", logical, method, table.concat(arg_strings, ", ")))
                    break
                end
            end

            if not is_trade_call and (string.find(string.lower(self_name), "trade") or string.find(string.lower(tostring(self.Parent)), "net")) then
                local arg_strings = {}
                for idx, val in ipairs(args) do
                    table.insert(arg_strings, string.format("#%d:%s(%s)", idx, tostring(val), typeof(val)))
                end
                log_entry("REMOTE", string.format("<<< [OUTGOING NET] %s:%s(%s)", self_name, method, table.concat(arg_strings, ", ")))
            end
        end

        return old_namecall(self, ...)
    end)
    log_entry("INIT", "Hooked __namecall for outgoing trade remotes.")
end

-- ==============================================================================
-- 6. ATTRIBUTE SPY (LocalPlayer.IsTrading)
-- ==============================================================================
local_player:GetAttributeChangedSignal("IsTrading"):Connect(function()
    local val = local_player:GetAttribute("IsTrading")
    log_entry("TRADE", string.format("[ATTRIBUTE] LocalPlayer:GetAttribute('IsTrading') = %s", tostring(val)))
    if status_indicator then
        status_indicator.Text = string.format("Status: %s | IsTrading: %s", val and "Trading" or "Idle", tostring(val))
    end
end)
log_entry("INIT", "Monitoring LocalPlayer:GetAttribute('IsTrading') (Current: " .. tostring(local_player:GetAttribute("IsTrading")) .. ")")

-- ==============================================================================
-- 7. PROMPT GUI DEEP SPY (PlayerGui.Prompt)
-- ==============================================================================
local function wire_button_spy(btn, parent_name)
    if not btn or not btn:IsA("GuiButton") then return end
    btn.Activated:Connect(function()
        log_entry("ACTION", string.format("[BUTTON CLICK] %s.%s was ACTIVATED", parent_name, btn.Name))
    end)
    btn.MouseButton1Click:Connect(function()
        log_entry("ACTION", string.format("[BUTTON CLICK] %s.%s received MouseButton1Click", parent_name, btn.Name))
    end)
end

local function monitor_prompt_gui(prompt_gui)
    if not prompt_gui then return end
    log_entry("PROMPT", string.format("Attaching deep spy to %s (Enabled=%s)", prompt_gui.Name, tostring(prompt_gui.Enabled)))

    prompt_gui:GetPropertyChangedSignal("Enabled"):Connect(function()
        log_entry("PROMPT", string.format("[PROMPT GUI] Prompt.Enabled changed -> %s", tostring(prompt_gui.Enabled)))
    end)

    local blackout = prompt_gui:FindFirstChild("Blackout")
    if blackout then
        log_entry("PROMPT", string.format("[BLACKOUT INIT] Visible=%s, Pos=%s, Anchor=%s", 
            tostring(blackout.Visible), tostring(blackout.Position), tostring(blackout.AnchorPoint)))

        blackout:GetPropertyChangedSignal("Visible"):Connect(function()
            log_entry("PROMPT", string.format("[BLACKOUT] Visible changed -> %s", tostring(blackout.Visible)))
        end)

        blackout:GetPropertyChangedSignal("Position"):Connect(function()
            log_entry("PROMPT", string.format("[BLACKOUT] Position changed -> %s", tostring(blackout.Position)))
        end)

        local label = blackout:FindFirstChild("Label")
        if label then
            log_entry("PROMPT", string.format("[LABEL INIT] Text = '%s'", label.Text))
            label:GetPropertyChangedSignal("Text"):Connect(function()
                log_entry("PROMPT", string.format("[LABEL TEXT] Changed -> '%s'", label.Text))
            end)
        end

        local options = blackout:FindFirstChild("Options")
        if options then
            for _, btn_name in ipairs({"Yes", "No", "Decline", "Accept"}) do
                local b = options:FindFirstChild(btn_name)
                if b then wire_button_spy(b, "Blackout.Options") end
            end
        end
    end

    local frame = prompt_gui:FindFirstChild("Frame")
    if frame then
        frame:GetPropertyChangedSignal("Visible"):Connect(function()
            log_entry("PROMPT", string.format("[FRAME OVERLAY] Visible changed -> %s", tostring(frame.Visible)))
        end)
    end

    prompt_gui.DescendantAdded:Connect(function(desc)
        if desc:IsA("TextLabel") and desc.Name == "Label" then
            log_entry("PROMPT", string.format("[DESC ADDED] Label created: '%s'", desc.Text))
            desc:GetPropertyChangedSignal("Text"):Connect(function()
                log_entry("PROMPT", string.format("[LABEL TEXT] Changed -> '%s'", desc.Text))
            end)
        elseif desc:IsA("GuiButton") then
            log_entry("PROMPT", string.format("[DESC ADDED] Button created: %s (%s)", desc.Name, desc.Parent and desc.Parent.Name or "nil"))
            wire_button_spy(desc, desc.Parent and desc.Parent.Name or "Prompt")
        end
    end)
end

local existing_prompt = player_gui:FindFirstChild("Prompt")
if existing_prompt then
    monitor_prompt_gui(existing_prompt)
end

player_gui.ChildAdded:Connect(function(child)
    if child.Name == "Prompt" then
        log_entry("PROMPT", ">>> [GUI CREATED] PlayerGui.Prompt was newly added!")
        monitor_prompt_gui(child)
    elseif child.Name == "! Trading" or child.Name == "Trading" then
        log_entry("TRADE", string.format(">>> [TRADING GUI] %s was added to PlayerGui!", child.Name))
        child:GetPropertyChangedSignal("Enabled"):Connect(function()
            log_entry("TRADE", string.format("[TRADING GUI] %s.Enabled = %s", child.Name, tostring(child.Enabled)))
        end)
    end
end)

-- ==============================================================================
-- 8. TRADING WINDOW DEEP SPY (! Trading)
-- ==============================================================================
local function monitor_trading_gui(t_gui)
    if not t_gui then return end
    log_entry("TRADE", string.format("Monitoring Trading Window (%s) Enabled=%s", t_gui.Name, tostring(t_gui.Enabled)))

    t_gui:GetPropertyChangedSignal("Enabled"):Connect(function()
        log_entry("TRADE", string.format("[TRADING GUI] Enabled -> %s", tostring(t_gui.Enabled)))
    end)

    t_gui.DescendantAdded:Connect(function(desc)
        if desc:IsA("GuiButton") then
            local b_name = string.lower(desc.Name)
            if string.find(b_name, "ready") or string.find(b_name, "confirm") or string.find(b_name, "accept") or string.find(b_name, "close") then
                log_entry("TRADE", string.format("[TRADING BUTTON] Found: %s", desc.Name))
                wire_button_spy(desc, t_gui.Name)
            end
        end
    end)

    for _, desc in ipairs(t_gui:GetDescendants()) do
        if desc:IsA("GuiButton") then
            local b_name = string.lower(desc.Name)
            if string.find(b_name, "ready") or string.find(b_name, "confirm") or string.find(b_name, "accept") or string.find(b_name, "close") then
                wire_button_spy(desc, t_gui.Name)
            end
        end
    end
end

local existing_t = player_gui:FindFirstChild("! Trading") or player_gui:FindFirstChild("Trading")
if existing_t then
    monitor_trading_gui(existing_t)
end

-- ==============================================================================
-- 9. CLEANUP HANDLER
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
    log_entry("CLEANUP", "Trade Super Debugger stopped and cleaned up.")
end

log_entry("READY", "=== Spy is active! Silakan lakukan tes trade sekarang ===")
