--[[
    NOIR HUB - AUTO ACCEPT TRADE (STANDALONE)
    Extracted directly from working AutoTrade logic
]]

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

local string_lower  = string.lower
local string_find   = string.find
local string_gsub   = string.gsub
local string_format = string.format
local string_match  = string.match

local task_wait     = task.wait
local task_spawn    = task.spawn

-- Cleanup previous instance
if _G.NoirHub_AutoAccept_Cleanup then
    pcall(_G.NoirHub_AutoAccept_Cleanup)
end

local script_id = os_clock()
_G.NoirHub_AutoAccept_ScriptID = script_id

local cloneref = cloneref or function(ref) return ref end

local players            = cloneref(game:GetService("Players"))
local local_player       = players.LocalPlayer
local player_gui         = cloneref(local_player:WaitForChild("PlayerGui"))
local user_input_service = cloneref(game:GetService("UserInputService"))
local tween_service      = cloneref(game:GetService("TweenService"))
local replicated_storage = cloneref(game:GetService("ReplicatedStorage"))
local http_service       = cloneref(game:GetService("HttpService"))

-- Remote Mapping
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

    local success, net_folder = pcall(function()
        return replicated_storage.Packages._Index["sleitnick_net@0.2.0"].net
    end)

    if success and net_folder then
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

local config = {
    auto_accept_enabled = true,
    auto_confirm        = true
}

local auto_accept_conn = nil
local auto_accept_trade_started_conn = nil
local auto_accept_trade_ended_conn = nil
local auto_accept_active = false
local status_label = nil

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

local function is_trade_prompt(prompt_gui)
    if not prompt_gui then return false end
    local is_trade = false
    pcall(function()
        for _, desc in ipairs(prompt_gui:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Text then
                local text = string_lower(desc.Text)
                if string_find(text, "trade request", 1, true) or (string_find(text, "trade", 1, true) and string_find(text, "accept", 1, true)) then
                    is_trade = true
                    break
                end
            end
        end
    end)
    return is_trade
end

local function dismiss_trade_prompt()
    pcall(function()
        local prompt_gui = player_gui:FindFirstChild("Prompt")
        if prompt_gui then
            local blackout = prompt_gui:FindFirstChild("Blackout")
            local frame = prompt_gui:FindFirstChild("Frame")

            for _, desc in ipairs(prompt_gui:GetDescendants()) do
                if desc:IsA("GuiButton") and (desc.Name == "No" or desc.Name == "Cancel" or desc.Name == "Decline") then
                    click_gui_button(desc)
                end
            end

            for _, child in ipairs(prompt_gui:GetChildren()) do
                if child.Name ~= "Blackout" and child.Name ~= "Frame" and child.Name ~= "UIListLayout" and child.Name ~= "UIGridLayout" then
                    pcall(function() child:Destroy() end)
                end
            end

            if blackout then blackout.Visible = false end
            if frame then frame.Visible = false end
        end
    end)
end

local function apply_prompt_visibility()
    pcall(function()
        local prompt_gui = player_gui:FindFirstChild("Prompt")
        if prompt_gui then
            local blackout = prompt_gui:FindFirstChild("Blackout")
            local frame = prompt_gui:FindFirstChild("Frame")

            if config.auto_accept_enabled then
                prompt_gui.Enabled = false
                if blackout then blackout.Visible = false end
                if frame then frame.Visible = false end
            else
                prompt_gui.Enabled = true
            end
        end
    end)
end

local function close_trading_gui()
    auto_accept_active = false
    pcall(function()
        local t_gui = player_gui:FindFirstChild("! Trading") or player_gui:FindFirstChild("Trading")
        if t_gui then
            t_gui.Enabled = false
            local frame = t_gui:FindFirstChild("Frame") or t_gui:FindFirstChild("Container")
            if frame then frame.Visible = false end

            for _, btn_name in ipairs({"Close", "Decline", "X"}) do
                local btn = t_gui:FindFirstChild(btn_name, true)
                if btn and btn:IsA("GuiButton") then
                    click_gui_button(btn)
                end
            end
        end
    end)
    if status_label then
        status_label.Text = config.auto_accept_enabled and "Status: Idle (Listening)" or "Status: Disabled"
    end
end

local function set_game_trade_listeners(enable)
    pcall(function()
        local raw_remote = get_net_lookup()["TradeOfferReceived"]
        if raw_remote and raw_remote:IsA("RemoteEvent") and getconnections then
            for _, conn in ipairs(getconnections(raw_remote.OnClientEvent)) do
                -- Jangan matikan koneksi handler auto accept kita sendiri
                local is_our_conn = (auto_accept_conn and conn.Function == auto_accept_conn.Function)
                if not is_our_conn then
                    if enable then
                        pcall(function() conn:Enable() end)
                    else
                        pcall(function() conn:Disable() end)
                    end
                end
            end
        end
    end)
end

local function toggle_auto_accept(enable)
    if auto_accept_conn then pcall(function() auto_accept_conn:Disconnect() end); auto_accept_conn = nil end
    if auto_accept_trade_started_conn then pcall(function() auto_accept_trade_started_conn:Disconnect() end); auto_accept_trade_started_conn = nil end
    if auto_accept_trade_ended_conn then pcall(function() auto_accept_trade_ended_conn:Disconnect() end); auto_accept_trade_ended_conn = nil end

    config.auto_accept_enabled = enable

    if not enable then
        dismiss_trade_prompt()
        apply_prompt_visibility()
        set_game_trade_listeners(true) -- Aktifkan kembali prompt normal bawaan game
    else
        apply_prompt_visibility()
    end

    if status_label then
        status_label.Text = enable and "Status: Idle (Listening)" or "Status: Disabled"
    end

    if not trade_remotes then return end

    -- 1. TradeOfferReceived Listener
    auto_accept_conn = trade_remotes.TradeOfferReceived.OnClientEvent:Connect(function(requester)
        if _G.NoirHub_AutoAccept_ScriptID ~= script_id then return end

        if not config.auto_accept_enabled then
            return
        end

        if status_label then
            status_label.Text = "Status: Accepting Offer from " .. tostring(requester.Name or requester)
        end

        pcall(function()
            trade_remotes.AcceptTradeOffer:InvokeServer(requester, true)
        end)
        apply_prompt_visibility()
        task_wait(0.05)
        dismiss_trade_prompt()
    end)

    -- Matikan listener game agar game tidak memunculkan prompt sama sekali saat ON
    if enable then
        set_game_trade_listeners(false)
    end

    -- 2. TradeEnded Listener
    auto_accept_trade_ended_conn = trade_remotes.TradeEnded.OnClientEvent:Connect(function()
        if _G.NoirHub_AutoAccept_ScriptID ~= script_id then return end
        close_trading_gui()
        dismiss_trade_prompt()
    end)

    if not enable then return end

    -- 3. TradeStarted Listener
    auto_accept_trade_started_conn = trade_remotes.TradeStarted.OnClientEvent:Connect(function()
        if not config.auto_accept_enabled or _G.NoirHub_AutoAccept_ScriptID ~= script_id then return end
        auto_accept_active = true

        if status_label then
            status_label.Text = "Status: Trade Active! Showing GUI..."
        end

        pcall(function()
            local t_gui = player_gui:FindFirstChild("! Trading") or player_gui:FindFirstChild("Trading")
            if t_gui then
                t_gui.Enabled = true
                local frame = t_gui:FindFirstChild("Frame") or t_gui:FindFirstChild("Container")
                if frame then
                    frame.Visible = true
                end
            end
        end)

        if config.auto_confirm then
            task_spawn(function()
                task_wait(0.5)
                if not auto_accept_active or not local_player:GetAttribute("IsTrading") then return end

                pcall(function()
                    trade_remotes.SetReady:InvokeServer(true)
                end)

                local start_time = tick()
                while config.auto_accept_enabled and auto_accept_active and local_player:GetAttribute("IsTrading") and (tick() - start_time) < 60 do
                    pcall(function()
                        local t_gui = player_gui:FindFirstChild("! Trading") or player_gui:FindFirstChild("Trading")
                        if t_gui then
                            t_gui.Enabled = true
                            local frame = t_gui:FindFirstChild("Frame") or t_gui:FindFirstChild("Container")
                            if frame then frame.Visible = true end
                        end
                    end)

                    pcall(function()
                        trade_remotes.ConfirmTrade:InvokeServer()
                    end)
                    pcall(function()
                        trade_remotes.SetReady:InvokeServer(true)
                    end)

                    pcall(function()
                        local t_gui = player_gui:FindFirstChild("! Trading") or player_gui:FindFirstChild("Trading")
                        if t_gui then
                            for _, btn_name in ipairs({"Accept", "Confirm", "Ready"}) do
                                local btn = t_gui:FindFirstChild(btn_name, true)
                                if btn and btn:IsA("GuiButton") then
                                    click_gui_button(btn)
                                end
                            end
                        end
                    end)

                    task_wait(0.4)
                end

                close_trading_gui()
            end)
        end
    end)
end

-- UI CREATION
local function create_ui()
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

    local gui = Instance.new("ScreenGui")
    gui.Name = "NoirHub_AutoAccept"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 2147483647
    gui.Parent = parent_gui

    local BG_COLOR = Color3.fromRGB(15, 15, 15)
    local SIDEBAR_COLOR = Color3.fromRGB(10, 10, 10)
    local ACCENT_COLOR = Color3.fromRGB(255, 0, 255)
    local TEXT_COLOR = Color3.fromRGB(240, 240, 240)
    local MUTED_COLOR = Color3.fromRGB(150, 150, 150)
    local TOGGLE_ON_COLOR = Color3.fromRGB(255, 0, 255)

    local font_face = Font.fromEnum(Enum.Font.SourceSans)
    local font_bold = Font.fromEnum(Enum.Font.SourceSansBold)
    pcall(function()
        font_face = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
        font_bold = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
    end)

    local main = Instance.new("Frame")
    main.Name = "MainFrame"
    main.Size = UDim2.new(0, 210, 0, 140)
    main.Position = UDim2.new(0.5, -105, 0.35, 0)
    main.BackgroundColor3 = BG_COLOR
    main.BackgroundTransparency = 0.2
    main.BorderSizePixel = 0
    main.Active = true
    main.ZIndex = 10
    main.Parent = gui

    local main_stroke = Instance.new("UIStroke")
    main_stroke.Color = Color3.fromRGB(50, 50, 50)
    main_stroke.Thickness = 1
    main_stroke.Parent = main

    local main_corner = Instance.new("UICorner")
    main_corner.CornerRadius = UDim.new(0, 8)
    main_corner.Parent = main

    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 26)
    header.BackgroundColor3 = SIDEBAR_COLOR
    header.BackgroundTransparency = 0.2
    header.BorderSizePixel = 0
    header.ZIndex = 11
    header.Parent = main

    local header_corner = Instance.new("UICorner")
    header_corner.CornerRadius = UDim.new(0, 8)
    header_corner.Parent = header

    local title_lbl = Instance.new("TextLabel")
    title_lbl.Size = UDim2.new(1, -30, 1, 0)
    title_lbl.Position = UDim2.new(0, 8, 0, 0)
    title_lbl.BackgroundTransparency = 1
    title_lbl.Text = "NØIR - Auto Accept"
    title_lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    title_lbl.TextSize = 10
    title_lbl.FontFace = font_bold
    title_lbl.TextXAlignment = Enum.TextXAlignment.Left
    title_lbl.ZIndex = 12
    title_lbl.Parent = header

    -- Minimize Button
    local min_btn = Instance.new("TextButton")
    min_btn.Size = UDim2.new(0, 20, 0, 20)
    min_btn.Position = UDim2.new(1, -24, 0.5, -10)
    min_btn.BackgroundTransparency = 1
    min_btn.Text = "─"
    min_btn.TextColor3 = MUTED_COLOR
    min_btn.TextSize = 11
    min_btn.FontFace = font_bold
    min_btn.ZIndex = 12
    min_btn.Parent = header

    -- Floating Icon
    local floating_btn = Instance.new("TextButton")
    floating_btn.Size = UDim2.new(0, 36, 0, 36)
    floating_btn.Position = UDim2.new(0, 15, 0.5, -18)
    floating_btn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    floating_btn.Text = "⚡"
    floating_btn.TextColor3 = ACCENT_COLOR
    floating_btn.TextSize = 16
    floating_btn.Visible = false
    floating_btn.ZIndex = 20
    floating_btn.Parent = gui

    local float_corner = Instance.new("UICorner")
    float_corner.CornerRadius = UDim.new(0, 8)
    float_corner.Parent = floating_btn

    local float_stroke = Instance.new("UIStroke")
    float_stroke.Color = ACCENT_COLOR
    float_stroke.Thickness = 1.5
    float_stroke.Parent = floating_btn

    min_btn.MouseButton1Click:Connect(function()
        main.Visible = false
        floating_btn.Visible = true
    end)

    floating_btn.MouseButton1Click:Connect(function()
        main.Visible = true
        floating_btn.Visible = false
    end)

    -- Draggable
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

    -- Content Body
    local body = Instance.new("Frame")
    body.Size = UDim2.new(1, -16, 1, -34)
    body.Position = UDim2.new(0, 8, 0, 30)
    body.BackgroundTransparency = 1
    body.ZIndex = 11
    body.Parent = main

    local body_layout = Instance.new("UIListLayout")
    body_layout.Padding = UDim.new(0, 6)
    body_layout.Parent = body

    -- Helper: Toggle row
    local function create_toggle_row(labelText, defaultState, onToggle)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 22)
        row.BackgroundTransparency = 1
        row.ZIndex = 12
        row.Parent = body

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.65, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = TEXT_COLOR
        lbl.TextSize = 9
        lbl.FontFace = font_bold
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 12
        lbl.Parent = row

        local capsule = Instance.new("TextButton")
        capsule.Size = UDim2.new(0, 32, 0, 16)
        capsule.Position = UDim2.new(1, -32, 0.5, -8)
        capsule.BackgroundColor3 = defaultState and TOGGLE_ON_COLOR or Color3.fromRGB(45, 45, 45)
        capsule.Text = ""
        capsule.AutoButtonColor = false
        capsule.ZIndex = 12
        capsule.Parent = row

        local cap_c = Instance.new("UICorner")
        cap_c.CornerRadius = UDim.new(0.5, 0)
        cap_c.Parent = capsule

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 12, 0, 12)
        knob.Position = defaultState and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
        knob.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
        knob.BorderSizePixel = 0
        knob.ZIndex = 13
        knob.Parent = capsule

        local knob_c = Instance.new("UICorner")
        knob_c.CornerRadius = UDim.new(0.5, 0)
        knob_c.Parent = knob

        local active = defaultState
        capsule.MouseButton1Click:Connect(function()
            active = not active
            local target_pos = active and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
            local target_color = active and TOGGLE_ON_COLOR or Color3.fromRGB(45, 45, 45)
            tween_service:Create(knob, TweenInfo.new(0.12), { Position = target_pos }):Play()
            tween_service:Create(capsule, TweenInfo.new(0.12), { BackgroundColor3 = target_color }):Play()
            onToggle(active)
        end)

        return row
    end

    create_toggle_row("Auto Accept Trade", config.auto_accept_enabled, function(active)
        toggle_auto_accept(active)
    end)

    create_toggle_row("Auto Confirm/Ready", config.auto_confirm, function(active)
        config.auto_confirm = active
    end)

    status_label = Instance.new("TextLabel")
    status_label.Size = UDim2.new(1, 0, 0, 28)
    status_label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    status_label.BackgroundTransparency = 0.4
    status_label.Text = config.auto_accept_enabled and "Status: Idle (Listening)" or "Status: Disabled"
    status_label.TextColor3 = Color3.fromRGB(0, 255, 170)
    status_label.TextSize = 8
    status_label.FontFace = font_face
    status_label.TextWrapped = true
    status_label.ZIndex = 12
    status_label.Parent = body

    local stat_c = Instance.new("UICorner")
    stat_c.CornerRadius = UDim.new(0, 4)
    stat_c.Parent = status_label
end

-- Initialize UI & Auto Accept
pcall(create_ui)
pcall(function() toggle_auto_accept(config.auto_accept_enabled) end)

_G.NoirHub_AutoAccept_Cleanup = function()
    pcall(function() toggle_auto_accept(false) end)
    _G.NoirHub_AutoAccept_ScriptID = nil
    pcall(function()
        local core = gethui and gethui() or game:GetService("CoreGui")
        local old = core:FindFirstChild("NoirHub_AutoAccept")
        if old then old:Destroy() end
    end)
    pcall(function()
        local pgui = local_player:FindFirstChild("PlayerGui")
        local old = pgui and pgui:FindFirstChild("NoirHub_AutoAccept")
        if old then old:Destroy() end
    end)
end

print("[Noir Hub] Auto Accept standalone loaded successfully!")
