--[[
    NOIR HUB - AUTO ACCEPT TRADE [v6.2]
    Refactored to be clean, lightweight, and 100% reliable.
]]

local cloneref = cloneref or function(ref) return ref end

local players            = cloneref(game:GetService("Players"))
local local_player       = players.LocalPlayer
local player_gui         = cloneref(local_player:WaitForChild("PlayerGui"))
local user_input_service = cloneref(game:GetService("UserInputService"))
local tween_service      = cloneref(game:GetService("TweenService"))
local replicated_storage = cloneref(game:GetService("ReplicatedStorage"))

-- Cleanup previous instance
if _G.NoirHub_AutoAccept_Cleanup then
    pcall(_G.NoirHub_AutoAccept_Cleanup)
end

local script_id = os.clock()
_G.NoirHub_AutoAccept_ScriptID = script_id

-- 1. REMOTE RESOLVER (Dual-Format Sleitnick Net)
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

local discovered_remotes = {}
local discovered_hashes  = {}

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

        if not net_folder then return end

        local children = net_folder:GetChildren()
        for i, child in ipairs(children) do
            for key, _ in pairs(trade_remote_names) do
                if string.find(child.Name, key, 1, true) then
                    discovered_remotes[key] = child

                    -- Also check if next sibling is a hashed remote (RF/ or RE/)
                    for j = i + 1, math.min(i + 4, #children) do
                        local next_c = children[j]
                        local n_name = next_c.Name
                        if string.sub(n_name, 1, 3) == "RF/" or string.sub(n_name, 1, 3) == "RE/" then
                            discovered_remotes[key .. "_hash"] = next_c
                            discovered_hashes[n_name] = key
                            break
                        end
                    end
                end
            end
        end
    end)
end

resolve_trade_remotes()

local function call_trade_remote(key, ...)
    local args = { ... }
    local r = discovered_remotes[key]
    if r then
        pcall(function()
            if r:IsA("RemoteFunction") then
                r:InvokeServer(unpack(args))
            elseif r:IsA("RemoteEvent") then
                r:FireServer(unpack(args))
            end
        end)
    end
    local r_hash = discovered_remotes[key .. "_hash"]
    if r_hash and r_hash ~= r then
        pcall(function()
            if r_hash:IsA("RemoteFunction") then
                r_hash:InvokeServer(unpack(args))
            elseif r_hash:IsA("RemoteEvent") then
                r_hash:FireServer(unpack(args))
            end
        end)
    end
end

local function listen_trade_event(key, handler)
    local conns = {}
    local r = discovered_remotes[key]
    if r and r:IsA("RemoteEvent") then
        local ok, c = pcall(function() return r.OnClientEvent:Connect(handler) end)
        if ok and c then table.insert(conns, c) end
    end
    local r_hash = discovered_remotes[key .. "_hash"]
    if r_hash and r_hash:IsA("RemoteEvent") and r_hash ~= r then
        local ok, c = pcall(function() return r_hash.OnClientEvent:Connect(handler) end)
        if ok and c then table.insert(conns, c) end
    end
    return conns
end

-- 2. BUTTON CLICKER
local function click_gui_button(btn)
    if not btn then return end
    pcall(function()
        btn.Active = true
        if firesignal then
            pcall(firesignal, btn.Activated)
            pcall(firesignal, btn.MouseButton1Click)
            pcall(firesignal, btn.MouseButton1Up)
        end
        if getconnections then
            for _, sig in ipairs({btn.Activated, btn.MouseButton1Click, btn.MouseButton1Up}) do
                pcall(function()
                    for _, c in ipairs(getconnections(sig)) do
                        if c.Fire then pcall(function() c:Fire() end) end
                        if c.Function then pcall(c.Function) end
                    end
                end)
            end
        end
    end)
end

-- 3. PROMPT STATE MANAGER
local function reset_prompt_defaults()
    pcall(function()
        local prompt_gui = player_gui:FindFirstChild("Prompt")
        if prompt_gui then
            prompt_gui.Enabled = false
            local blackout = prompt_gui:FindFirstChild("Blackout")
            if blackout then
                blackout.AnchorPoint = Vector2.new(0.5, 0.5)
                blackout.Position = UDim2.new(0.5, 0, 0.5, 0)
                blackout.Visible = true
            end
        end
    end)
end

reset_prompt_defaults()

-- 4. STATE & TRADE ENGINE
local config = {
    auto_accept_enabled = true
}

local active_connections = {}
local is_trading = false
local is_confirming = false
local status_label = nil

local function disconnect_all()
    for _, conn in ipairs(active_connections) do
        pcall(function() conn:Disconnect() end)
    end
    active_connections = {}
end

local function close_trading_window()
    is_trading = false
    is_confirming = false
    pcall(function()
        local t_gui = player_gui:FindFirstChild("! Trading") or player_gui:FindFirstChild("Trading")
        if t_gui then
            t_gui.Enabled = false
            local frame = t_gui:FindFirstChild("Frame") or t_gui:FindFirstChildWhichIsA("Frame")
            if frame then frame.Visible = false end
        end
    end)
    reset_prompt_defaults()
end

local function handle_trade_offer(requester)
    if not config.auto_accept_enabled or _G.NoirHub_AutoAccept_ScriptID ~= script_id then return end

    local req_name = typeof(requester) == "Instance" and requester.Name or tostring(requester)
    if status_label then
        status_label.Text = "[v6.2] Accepting: " .. req_name
    end

    -- Sembunyikan prompt instan & klik yes jika sudah ada
    pcall(function()
        local prompt_gui = player_gui:FindFirstChild("Prompt")
        if prompt_gui then
            local blackout = prompt_gui:FindFirstChild("Blackout")
            local options = blackout and blackout:FindFirstChild("Options")
            local yes_btn = options and options:FindFirstChild("Yes")
            if yes_btn then click_gui_button(yes_btn) end
            prompt_gui.Enabled = false
        end
    end)

    -- Invoke Server untuk accept trade (baik dengan true maupun tanpa argumen)
    call_trade_remote("AcceptTradeOffer", requester, true)
    call_trade_remote("AcceptTradeOffer", requester)
end

local function handle_trade_started()
    if not config.auto_accept_enabled or _G.NoirHub_AutoAccept_ScriptID ~= script_id then return end
    if is_confirming then return end
    is_confirming = true
    is_trading = true

    if status_label then
        status_label.Text = "[v6.2] Trade Active! Confirming..."
    end

    -- Pastikan prompt tertutup
    pcall(function()
        local prompt_gui = player_gui:FindFirstChild("Prompt")
        if prompt_gui then prompt_gui.Enabled = false end
    end)

    -- Tampilkan GUI Trading
    pcall(function()
        local t_gui = player_gui:FindFirstChild("! Trading") or player_gui:FindFirstChild("Trading")
        if t_gui then
            t_gui.Enabled = true
            local frame = t_gui:FindFirstChild("Frame") or t_gui:FindFirstChildWhichIsA("Frame")
            if frame then frame.Visible = true end
        end
    end)

    -- Auto Ready & Confirm loop
    task.spawn(function()
        task.wait(0.25)
        local start_t = tick()
        while config.auto_accept_enabled and local_player:GetAttribute("IsTrading") and (tick() - start_t < 45) do
            -- 1. Call SetReady & ConfirmTrade remotes
            call_trade_remote("SetReady", true)
            call_trade_remote("ConfirmTrade")

            -- 2. Click buttons in Trading GUI
            pcall(function()
                local t_gui = player_gui:FindFirstChild("! Trading") or player_gui:FindFirstChild("Trading")
                if t_gui then
                    local frame = t_gui:FindFirstChild("Frame")
                    local interior = frame and frame:FindFirstChild("Interior")
                    local buttons = interior and interior:FindFirstChild("Buttons")
                    if buttons then
                        for _, child in ipairs(buttons:GetChildren()) do
                            if child:IsA("GuiButton") and child.Name ~= "Decline" and child.Name ~= "Close" then
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
            end)

            task.wait(0.35)
        end

        is_confirming = false
        close_trading_window()
        if status_label then
            status_label.Text = config.auto_accept_enabled and "[v6.2] Status: Idle (Listening)" or "[v6.2] Status: Disabled"
        end
    end)
end

local function set_auto_accept(enable)
    config.auto_accept_enabled = enable
    is_trading = false
    is_confirming = false

    disconnect_all()

    if not enable then
        -- TOGGLE OFF:
        -- Kembalikan state prompt ke normal tanpa memaksa Enabled = true
        reset_prompt_defaults()
        if status_label then
            status_label.Text = "[v6.2] Status: Disabled"
        end
        return
    end

    -- TOGGLE ON:
    reset_prompt_defaults()
    if status_label then
        status_label.Text = "[v6.2] Status: Idle (Listening)"
    end

    -- 1. Listen for TradeOfferReceived (both named & hash remotes)
    local offer_conns = listen_trade_event("TradeOfferReceived", handle_trade_offer)
    for _, c in ipairs(offer_conns) do table.insert(active_connections, c) end

    -- 2. Listen for TradeStarted (both named & hash remotes)
    local start_conns = listen_trade_event("TradeStarted", handle_trade_started)
    for _, c in ipairs(start_conns) do table.insert(active_connections, c) end

    -- 3. Listen for TradeEnded (both named & hash remotes)
    local end_conns = listen_trade_event("TradeEnded", function()
        close_trading_window()
        if status_label then
            status_label.Text = config.auto_accept_enabled and "[v6.2] Status: Idle (Listening)" or "[v6.2] Status: Disabled"
        end
    end)
    for _, c in ipairs(end_conns) do table.insert(active_connections, c) end

    -- 4. Listen to LocalPlayer:GetAttributeChangedSignal("IsTrading") - FOOLPROOF GUARANTEE
    local attr_conn = local_player:GetAttributeChangedSignal("IsTrading"):Connect(function()
        if not config.auto_accept_enabled then return end
        local is_tr = local_player:GetAttribute("IsTrading")
        if is_tr then
            handle_trade_started()
        else
            close_trading_window()
        end
    end)
    table.insert(active_connections, attr_conn)

    if local_player:GetAttribute("IsTrading") then
        handle_trade_started()
    end

    -- 5. Watcher cadangan: Jika Prompt game terbuka saat toggle ON, langsung auto klik Yes & tutup
    pcall(function()
        local prompt_gui = player_gui:FindFirstChild("Prompt") or player_gui:WaitForChild("Prompt", 3)
        if prompt_gui then
            local p_conn = prompt_gui:GetPropertyChangedSignal("Enabled"):Connect(function()
                if not config.auto_accept_enabled then return end
                if prompt_gui.Enabled then
                    local blackout = prompt_gui:FindFirstChild("Blackout")
                    local label = blackout and blackout:FindFirstChild("Label")
                    local txt = label and string.lower(label.Text) or ""
                    if string.find(txt, "trade", 1, true) or string.find(txt, "accept", 1, true) then
                        local options = blackout and blackout:FindFirstChild("Options")
                        local yes_btn = options and options:FindFirstChild("Yes")
                        if yes_btn then click_gui_button(yes_btn) end
                        prompt_gui.Enabled = false
                    end
                end
            end)
            table.insert(active_connections, p_conn)
        end
    end)
end

-- 5. UI CREATION
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
    main.Size = UDim2.new(0, 200, 0, 105)
    main.Position = UDim2.new(0.5, -100, 0.35, 0)
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
    title_lbl.Text = "NØIR AutoAccept [v6.2]"
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

    -- Body
    local body = Instance.new("Frame")
    body.Size = UDim2.new(1, -16, 1, -34)
    body.Position = UDim2.new(0, 8, 0, 30)
    body.BackgroundTransparency = 1
    body.ZIndex = 11
    body.Parent = main

    local body_layout = Instance.new("UIListLayout")
    body_layout.Padding = UDim.new(0, 6)
    body_layout.Parent = body

    -- Toggle row
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 22)
    row.BackgroundTransparency = 1
    row.ZIndex = 12
    row.Parent = body

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.65, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "Auto Accept Trade"
    lbl.TextColor3 = TEXT_COLOR
    lbl.TextSize = 9
    lbl.FontFace = font_bold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 12
    lbl.Parent = row

    local capsule = Instance.new("TextButton")
    capsule.Size = UDim2.new(0, 32, 0, 16)
    capsule.Position = UDim2.new(1, -32, 0.5, -8)
    capsule.BackgroundColor3 = config.auto_accept_enabled and TOGGLE_ON_COLOR or Color3.fromRGB(45, 45, 45)
    capsule.Text = ""
    capsule.AutoButtonColor = false
    capsule.ZIndex = 12
    capsule.Parent = row

    local cap_c = Instance.new("UICorner")
    cap_c.CornerRadius = UDim.new(0.5, 0)
    cap_c.Parent = capsule

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.Position = config.auto_accept_enabled and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
    knob.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
    knob.BorderSizePixel = 0
    knob.ZIndex = 13
    knob.Parent = capsule

    local knob_c = Instance.new("UICorner")
    knob_c.CornerRadius = UDim.new(0.5, 0)
    knob_c.Parent = knob

    local active = config.auto_accept_enabled
    capsule.MouseButton1Click:Connect(function()
        active = not active
        local target_pos = active and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
        local target_color = active and TOGGLE_ON_COLOR or Color3.fromRGB(45, 45, 45)
        tween_service:Create(knob, TweenInfo.new(0.12), { Position = target_pos }):Play()
        tween_service:Create(capsule, TweenInfo.new(0.12), { BackgroundColor3 = target_color }):Play()
        set_auto_accept(active)
    end)

    status_label = Instance.new("TextLabel")
    status_label.Size = UDim2.new(1, 0, 0, 28)
    status_label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    status_label.BackgroundTransparency = 0.4
    status_label.Text = config.auto_accept_enabled and "[v6.2] Status: Idle (Listening)" or "[v6.2] Status: Disabled"
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

-- 6. STARTUP & CLEANUP
pcall(create_ui)
pcall(function() set_auto_accept(config.auto_accept_enabled) end)

_G.NoirHub_AutoAccept_Cleanup = function()
    pcall(function() set_auto_accept(false) end)
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
    reset_prompt_defaults()
end

print("[Noir Hub] Auto Accept v6.2 (Clean Rewrite) loaded successfully!")
