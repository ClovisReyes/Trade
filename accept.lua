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

local GuiControl = nil
local function get_gui_control()
    if GuiControl then return GuiControl end
    pcall(function()
        local rep = game:GetService("ReplicatedStorage")
        local modules = rep:FindFirstChild("Modules") or rep:WaitForChild("Modules", 3)
        if modules and modules:FindFirstChild("GuiControl") then
            GuiControl = require(modules.GuiControl)
        end
    end)
    return GuiControl
end
get_gui_control()

local config = {
    auto_accept_enabled = true,
    auto_confirm        = true
}

local auto_accept_conn = nil
local auto_accept_trade_started_conn = nil
local auto_accept_trade_ended_conn = nil
local auto_accept_active = false
local status_label = nil
local last_trade_offer_time = 0
local prompt_watcher_conns = {}

local function click_gui_button(btn)
    if not btn then return end
    pcall(function()
        btn.Active = true
        if firesignal then
            pcall(firesignal, btn.Activated)
            pcall(firesignal, btn.MouseButton1Click)
            pcall(firesignal, btn.MouseButton1Down)
            pcall(firesignal, btn.MouseButton1Up)
        end
        if getconnections then
            for _, sig in ipairs({btn.Activated, btn.MouseButton1Click, btn.MouseButton1Down, btn.MouseButton1Up}) do
                pcall(function()
                    for _, conn in ipairs(getconnections(sig)) do
                        if type(conn.Fire) == "function" then
                            pcall(function() conn:Fire() end)
                        elseif type(conn.fire) == "function" then
                            pcall(function() conn:fire() end)
                        end
                        if type(conn.Function) == "function" then
                            pcall(conn.Function)
                        end
                    end
                end)
            end
        end
    end)
end

local function cleanup_prompt_watcher()
    for _, c in ipairs(prompt_watcher_conns) do
        pcall(function() c:Disconnect() end)
    end
    prompt_watcher_conns = {}
end

local function kill_all_blackouts()
    pcall(function()
        local prompt_gui = player_gui:FindFirstChild("Prompt")
        if prompt_gui then
            local frame = prompt_gui:FindFirstChild("Frame")
            if frame then
                frame.Visible = false
                frame.BackgroundTransparency = 1
                frame.Active = false
            end
        end
    end)

    pcall(function()
        local psb = player_gui:FindFirstChild("PurchaseScreenBlackout")
        if psb then
            psb.Enabled = false
            for _, d in ipairs(psb:GetDescendants()) do
                if d:IsA("Frame") or d:IsA("ImageLabel") then
                    d.Visible = false
                    d.BackgroundTransparency = 1
                    d.Active = false
                end
            end
        end
    end)

    pcall(function()
        for _, gui in ipairs(player_gui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Name ~= "NoirHub_AutoTrade" and gui.Name ~= "NoirHub_AutoAccept" and gui.Name ~= "KeenanTrade" and gui.Name ~= "KeenanTradeDebugger" then
                local g_lower = string_lower(gui.Name)
                if string_find(g_lower, "blackout", 1, true) or string_find(g_lower, "fade", 1, true) then
                    gui.Enabled = false
                end
            end
        end
    end)
end

local function restore_hud()
    local gc = get_gui_control()
    if gc then
        pcall(function() gc.RestoreHUD() end)
        pcall(function() gc:RestoreHUD() end)
        pcall(function() gc.SetHUDVisibility(true) end)
        pcall(function() gc:SetHUDVisibility(true) end)
        pcall(function() gc.Unlock() end)
        pcall(function() gc:Unlock() end)
        if config and config.auto_accept_enabled then
            pcall(function() gc.Close("Prompt") end)
            pcall(function() gc:Close("Prompt") end)
        end
    end

    pcall(function()
        for _, gui_name in ipairs({"HUD", "! HUD", "MainHUD", "GameHUD", "TopBar", "CoreHUD"}) do
            local h = player_gui:FindFirstChild(gui_name)
            if h and h:IsA("ScreenGui") then
                h.Enabled = true
            end
        end
    end)

    kill_all_blackouts()
end

local function suppress_trade_prompt()
    if not (config and config.auto_accept_enabled) then return end
    pcall(function()
        local prompt_gui = player_gui:FindFirstChild("Prompt")
        if not prompt_gui then return end
        local blackout = prompt_gui:FindFirstChild("Blackout")
        if not blackout then return end

        local label = blackout:FindFirstChild("Label")
        local text = label and label.Text or ""
        local lower = string_lower(text)

        local is_trade = string_find(lower, "trade", 1, true)
            or string_find(lower, "accept", 1, true)
            or string_find(lower, "request", 1, true)
            or string_find(lower, "offer", 1, true)
            or auto_accept_active
            or (tick() - last_trade_offer_time < 4)

        if is_trade then
            -- 1. Pindahkan Blackout keluar layar agar tidak terlihat, tapi biarkan aktif agar klik terdaftar
            blackout.Position = UDim2.new(10, 0, 10, 0)

            -- 2. Hilangkan background hitam
            local frame = prompt_gui:FindFirstChild("Frame")
            if frame then
                frame.Visible = false
                frame.BackgroundTransparency = 1
                frame.Active = false
            end
            kill_all_blackouts()

            -- 3. Klik tombol YES
            local options = blackout:FindFirstChild("Options")
            if options then
                local yes_btn = options:FindFirstChild("Yes")
                if yes_btn then
                    click_gui_button(yes_btn)
                    task_spawn(function()
                        task_wait(0.05)
                        blackout.Visible = false
                        prompt_gui.Enabled = false
                        local gc = get_gui_control()
                        if gc then
                            pcall(function() gc.Close("Prompt") end)
                            pcall(function() gc:Close("Prompt") end)
                        end
                    end)
                end
            end
        end
    end)
end

local function wire_prompt_buttons(blackout, prompt_gui)
    if not blackout or not prompt_gui then return end
    local options = blackout:FindFirstChild("Options")
    if not options then return end

    local function setup_btn(btn)
        if not btn then return end
        local function on_dismiss()
            task_spawn(function()
                task_wait(0.05)
                pcall(function()
                    blackout.Visible = false
                    prompt_gui.Enabled = false
                end)
            end)
        end
        table.insert(prompt_watcher_conns, btn.Activated:Connect(on_dismiss))
        table.insert(prompt_watcher_conns, btn.MouseButton1Click:Connect(on_dismiss))
        if btn.InputBegan then
            table.insert(prompt_watcher_conns, btn.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                    on_dismiss()
                end
            end))
        end
    end

    setup_btn(options:FindFirstChild("Yes"))
    setup_btn(options:FindFirstChild("No"))
end

local function init_prompt_watcher()
    cleanup_prompt_watcher()
    kill_all_blackouts()

    pcall(function()
        local prompt_gui = player_gui:FindFirstChild("Prompt") or player_gui:WaitForChild("Prompt", 5)
        if not prompt_gui then return end

        local blackout = prompt_gui:FindFirstChild("Blackout") or prompt_gui:WaitForChild("Blackout", 5)
        if blackout then
            local label = blackout:FindFirstChild("Label")
            if label then
                table.insert(prompt_watcher_conns, label:GetPropertyChangedSignal("Text"):Connect(function()
                    if config and config.auto_accept_enabled then
                        suppress_trade_prompt()
                    end
                end))
            end
            wire_prompt_buttons(blackout, prompt_gui)
        end

        local frame = prompt_gui:FindFirstChild("Frame")
        if frame then
            frame.Visible = false
            frame.BackgroundTransparency = 1
            frame.Active = false
            table.insert(prompt_watcher_conns, frame:GetPropertyChangedSignal("Visible"):Connect(function()
                if frame.Visible then
                    frame.Visible = false
                    frame.BackgroundTransparency = 1
                    frame.Active = false
                end
            end))
            table.insert(prompt_watcher_conns, frame:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
                if frame.BackgroundTransparency < 1 then
                    frame.BackgroundTransparency = 1
                end
            end))
        end

        table.insert(prompt_watcher_conns, prompt_gui.DescendantAdded:Connect(function(desc)
            if desc:IsA("TextLabel") and desc.Name == "Label" and desc.Parent and desc.Parent.Name == "Blackout" then
                table.insert(prompt_watcher_conns, desc:GetPropertyChangedSignal("Text"):Connect(function()
                    if config and config.auto_accept_enabled then
                        suppress_trade_prompt()
                    end
                end))
                if config and config.auto_accept_enabled then
                    suppress_trade_prompt()
                end
            elseif desc:IsA("GuiButton") and desc.Parent and desc.Parent.Name == "Options" then
                local b = desc.Parent.Parent
                if b and b.Name == "Blackout" then
                    wire_prompt_buttons(b, prompt_gui)
                end
            end
        end))

        table.insert(prompt_watcher_conns, prompt_gui:GetPropertyChangedSignal("Enabled"):Connect(function()
            if config and config.auto_accept_enabled then
                if prompt_gui.Enabled then
                    suppress_trade_prompt()
                end
            else
                -- Toggle OFF: ketika game mengaktifkan Prompt untuk offer BARU, tampilkan Blackout di tengah layar
                local f = prompt_gui:FindFirstChild("Frame")
                if f then
                    f.Visible = false
                    f.BackgroundTransparency = 1
                    f.Active = false
                end
                kill_all_blackouts()
                if prompt_gui.Enabled then
                    local b = prompt_gui:FindFirstChild("Blackout")
                    if b then
                        b.AnchorPoint = Vector2.new(0.5, 0.5)
                        b.Position = UDim2.new(0.5, 0, 0.5, 0)
                        b.Visible = true
                        wire_prompt_buttons(b, prompt_gui)
                    end
                end
            end
        end))

        if prompt_gui.Enabled and blackout then
            if config and config.auto_accept_enabled then
                suppress_trade_prompt()
            else
                wire_prompt_buttons(blackout, prompt_gui)
            end
        end
    end)
end

local function close_trading_gui()
    auto_accept_active = false
    pcall(function()
        local gc = get_gui_control()
        if gc then
            pcall(function() gc.Close("! Trading") end)
            pcall(function() gc:Close("! Trading") end)
        end
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
    pcall(function()
        local prompt_gui = player_gui:FindFirstChild("Prompt")
        if prompt_gui then
            prompt_gui.Enabled = false
            local frame = prompt_gui:FindFirstChild("Frame")
            if frame then
                frame.Visible = false
                frame.BackgroundTransparency = 1
                frame.Active = false
            end
            local blackout = prompt_gui:FindFirstChild("Blackout")
            if blackout then
                blackout.Visible = false
                blackout.Position = UDim2.new(0.5, 0, 0.5, 0)
                blackout.AnchorPoint = Vector2.new(0.5, 0.5)
            end
        end
        local psb = player_gui:FindFirstChild("PurchaseScreenBlackout")
        if psb then psb.Enabled = false end
    end)
    kill_all_blackouts()
    restore_hud()
    if status_label then
        status_label.Text = config.auto_accept_enabled and "[v5.0] Status: Idle (Listening)" or "[v5.0] Status: Disabled"
    end
end

local function toggle_auto_accept(enable)
    if auto_accept_conn then pcall(function() auto_accept_conn:Disconnect() end); auto_accept_conn = nil end
    if auto_accept_trade_started_conn then pcall(function() auto_accept_trade_started_conn:Disconnect() end); auto_accept_trade_started_conn = nil end
    if auto_accept_trade_ended_conn then pcall(function() auto_accept_trade_ended_conn:Disconnect() end); auto_accept_trade_ended_conn = nil end

    config.auto_accept_enabled = enable
    auto_accept_active = false

    if not enable then
        -- Toggle OFF: Tutup prompt lama secara bersih & sembunyikan agar tidak ada sisa popup lama
        pcall(function()
            local prompt_gui = player_gui:FindFirstChild("Prompt")
            if prompt_gui then
                prompt_gui.Enabled = false
                local blackout = prompt_gui:FindFirstChild("Blackout")
                if blackout then
                    blackout.Visible = false
                    blackout.Position = UDim2.new(0.5, 0, 0.5, 0)
                    blackout.AnchorPoint = Vector2.new(0.5, 0.5)
                end
                local frame = prompt_gui:FindFirstChild("Frame")
                if frame then
                    frame.Visible = false
                    frame.BackgroundTransparency = 1
                    frame.Active = false
                end
            end
            local psb = player_gui:FindFirstChild("PurchaseScreenBlackout")
            if psb then psb.Enabled = false end
        end)

        kill_all_blackouts()
        restore_hud()

        if status_label then
            status_label.Text = "[v5.0] Status: Disabled"
        end
        return
    end

    if status_label then
        status_label.Text = "[v5.0] Status: Idle (Listening)"
    end

    if not trade_remotes then return end

    -- 1. TradeOfferReceived Listener
    auto_accept_conn = trade_remotes.TradeOfferReceived.OnClientEvent:Connect(function(requester)
        if _G.NoirHub_AutoAccept_ScriptID ~= script_id then return end
        if not config.auto_accept_enabled then return end

        last_trade_offer_time = tick()

        if status_label then
            status_label.Text = "[v5.0] Status: Accepting Offer from " .. tostring(requester.Name or requester)
        end

        suppress_trade_prompt()

        pcall(function()
            trade_remotes.AcceptTradeOffer:InvokeServer(requester, true)
        end)
        pcall(function()
            trade_remotes.AcceptTradeOffer:InvokeServer(requester)
        end)

        task_spawn(function()
            task_wait(0.05)
            suppress_trade_prompt()
        end)
        task_spawn(function()
            task_wait(0.1)
            suppress_trade_prompt()
        end)

        task_spawn(function()
            for _ = 1, 20 do
                if not config.auto_accept_enabled then break end
                local p = player_gui:FindFirstChild("Prompt")
                local b = p and p:FindFirstChild("Blackout")
                if b then
                    b.Position = UDim2.new(10, 0, 10, 0)
                    local opt = b:FindFirstChild("Options")
                    local y = opt and opt:FindFirstChild("Yes")
                    if y then
                        click_gui_button(y)
                        task_spawn(function()
                            task_wait(0.05)
                            b.Visible = false
                            p.Enabled = false
                        end)
                        break
                    end
                end
                task_wait(0.05)
            end
        end)
    end)

    -- 2. TradeEnded Listener
    auto_accept_trade_ended_conn = trade_remotes.TradeEnded.OnClientEvent:Connect(function()
        if _G.NoirHub_AutoAccept_ScriptID ~= script_id then return end
        close_trading_gui()
    end)

    -- 3. TradeStarted Listener
    auto_accept_trade_started_conn = trade_remotes.TradeStarted.OnClientEvent:Connect(function()
        if not config.auto_accept_enabled or _G.NoirHub_AutoAccept_ScriptID ~= script_id then return end
        auto_accept_active = true

        pcall(function()
            local prompt_gui = player_gui:FindFirstChild("Prompt")
            if prompt_gui then
                prompt_gui.Enabled = false
                local frame = prompt_gui:FindFirstChild("Frame")
                if frame then
                    frame.Visible = false
                    frame.BackgroundTransparency = 1
                    frame.Active = false
                end
                local blackout = prompt_gui:FindFirstChild("Blackout")
                if blackout then
                    blackout.Visible = false
                    blackout.Position = UDim2.new(10, 0, 10, 0)
                end
            end
            local psb = player_gui:FindFirstChild("PurchaseScreenBlackout")
            if psb then psb.Enabled = false end
        end)
        kill_all_blackouts()
        restore_hud()

        if status_label then
            status_label.Text = "[v5.0] Status: Trade Active! Showing GUI..."
        end

        pcall(function()
            local gc = get_gui_control()
            if gc then
                pcall(function() gc.Open("! Trading") end)
                pcall(function() gc:Open("! Trading") end)
                pcall(function() gc.Open("Trading") end)
                pcall(function() gc:Open("Trading") end)
            end
            local t_gui = player_gui:FindFirstChild("! Trading") or player_gui:FindFirstChild("Trading")
            if t_gui then
                t_gui.Enabled = true
                local frame = t_gui:FindFirstChild("Frame") or t_gui:FindFirstChildWhichIsA("Frame")
                if frame then
                    frame.Visible = true
                end
            end
        end)

        task_spawn(function()
            task_wait(0.3)
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
                        local frame = t_gui:FindFirstChild("Frame") or t_gui:FindFirstChildWhichIsA("Frame")
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
    title_lbl.Text = "NØIR AutoAccept [v5.0]"
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

    status_label = Instance.new("TextLabel")
    status_label.Size = UDim2.new(1, 0, 0, 28)
    status_label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    status_label.BackgroundTransparency = 0.4
    status_label.Text = config.auto_accept_enabled and "[v5.0] Status: Idle (Listening)" or "[v5.0] Status: Disabled"
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

-- Initialize UI & Prompt Watcher & Auto Accept
init_prompt_watcher()
pcall(create_ui)
pcall(function() toggle_auto_accept(config.auto_accept_enabled) end)

_G.NoirHub_AutoAccept_Cleanup = function()
    pcall(function() toggle_auto_accept(false) end)
    pcall(cleanup_prompt_watcher)
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
