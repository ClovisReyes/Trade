--[[
    NOIR HUB - AUTO ACCEPT TRADE [v7.2]
    Dual-Engine Hybrid (Direct-Remote + Prompt Suppressor & Auto-Clicker):
    1. Instant Off-Screen Prompt Suppressor: Memindahkan Blackout ke (10, 0, 10, 0) & klik YES seketika.
       Dijamin pop-up TIDAK AKAN PERNAH menutupi layar lagi!
    2. Direct-Remote Accept: Mendengarkan TradeOfferReceived (baik nama asli maupun Hash RE/) & panggil AcceptTradeOffer.
    3. Trade Window Enabler: Membuka jendela "! Trading" dan Container agar terlihat jelas.
    4. Auto Ready & Confirm: Polling SetReady tiap 0.4s (12x attempt -> 5s backoff) + auto-click tombol ACCEPT/Ready/Confirm.
    5. Clean Draggable Mini-UI dengan Toggle ON/OFF.
]]

local cloneref = cloneref or function(r) return r end
local players  = cloneref(game:GetService("Players"))
local lp       = players.LocalPlayer
local pgui     = cloneref(lp:WaitForChild("PlayerGui"))
local rep      = cloneref(game:GetService("ReplicatedStorage"))
local uis      = cloneref(game:GetService("UserInputService"))
local ts       = cloneref(game:GetService("TweenService"))

-- Cleanup previous running instances
if _G.NoirHub_AutoAccept_Cleanup then
    pcall(_G.NoirHub_AutoAccept_Cleanup)
end
local script_id = os.clock()
_G.NoirHub_AutoAccept_ScriptID = script_id

local config = { enabled = true }
local status_lbl = nil
local main_gui = nil
local conns = {}
local trade_thread = nil

local function update_status(text, color)
    if status_lbl and status_lbl.Parent then
        status_lbl.Text = "[v7.2] " .. tostring(text)
        if color then status_lbl.TextColor3 = color end
    end
end

-- ==============================================================================
-- 1. HELPER: ROBUST GUI BUTTON CLICKER (Mobile/PC Executor Safe)
-- ==============================================================================
local function click_gui_button(btn)
    if not btn or not btn:IsA("GuiButton") then return end
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

-- ==============================================================================
-- 2. PROMPT SUPPRESSOR & WINDOW MANAGER (Menghilangkan Pop-up Total)
-- ==============================================================================
local function hide_prompt()
    pcall(function()
        local prompt_gui = pgui:FindFirstChild("Prompt")
        if prompt_gui then
            local blackout = prompt_gui:FindFirstChild("Blackout")
            if blackout then
                blackout.Position = UDim2.new(10, 0, 10, 0)
                blackout.Visible = false
            end
            local frame = prompt_gui:FindFirstChild("Frame")
            if frame then
                frame.Visible = false
                frame.Active = false
            end
            prompt_gui.Enabled = false
        end

        local modules = rep:FindFirstChild("Modules")
        local gc = modules and modules:FindFirstChild("GuiControl") and require(modules.GuiControl)
        if gc then
            pcall(function() gc.Close("Prompt") end)
            pcall(function() gc:Close("Prompt") end)
        end
    end)
end

local function restore_prompt_defaults()
    pcall(function()
        local prompt_gui = pgui:FindFirstChild("Prompt")
        if prompt_gui then
            local blackout = prompt_gui:FindFirstChild("Blackout")
            if blackout then
                blackout.AnchorPoint = Vector2.new(0.5, 0.5)
                blackout.Position = UDim2.new(0.5, 0, 0.5, 0)
                blackout.Visible = false
            end
            prompt_gui.Enabled = false
        end
    end)
end

local function ensure_trade_window_open()
    pcall(function()
        local t_gui = pgui:FindFirstChild("! Trading") or pgui:FindFirstChild("Trading") or pgui:FindFirstChild("Trade")
        if t_gui then
            t_gui.Enabled = true
            local container = t_gui:FindFirstChild("Frame") or t_gui:FindFirstChild("Container") or t_gui:FindFirstChild("Main")
            if container then container.Visible = true end
        end
    end)
end

local function check_and_accept_prompt()
    if not config.enabled then return end
    pcall(function()
        local prompt_gui = pgui:FindFirstChild("Prompt")
        if not prompt_gui then return end

        local blackout = prompt_gui:FindFirstChild("Blackout")
        if not blackout then return end

        local label = blackout:FindFirstChild("Label")
        local text = label and label.Text or ""
        local lower = string.lower(text)

        local is_trade = string.find(lower, "trade", 1, true)
            or string.find(lower, "accept", 1, true)
            or string.find(lower, "request", 1, true)
            or string.find(lower, "offer", 1, true)

        if is_trade or prompt_gui.Enabled then
            local options = blackout:FindFirstChild("Options")
            local yes_btn = options and options:FindFirstChild("Yes")

            if yes_btn then
                -- 1. Pindahkan Blackout seketika ke luar layar agar tidak menghalangi!
                blackout.Position = UDim2.new(10, 0, 10, 0)
                
                -- 2. Klik YES virtual
                click_gui_button(yes_btn)
                update_status("Trade Accepted!", Color3.fromRGB(0, 255, 170))

                task.spawn(function()
                    task.wait(0.04)
                    hide_prompt()
                    ensure_trade_window_open()
                end)
            end
        end
    end)
end

-- ==============================================================================
-- 3. REMOTE RESOLVER & HASH DICTIONARY (Sleitnick Net)
-- ==============================================================================
local trade_remote_names = {
    SendTradeOffer     = true,
    AcceptTradeOffer   = true,
    TradeOfferReceived = true,
    TradeStarted       = true,
    TradeEnded         = true,
    SetReady           = true,
    ConfirmTrade       = true,
}

local discovered_remotes = {}

local function resolve_all_remotes()
    pcall(function()
        local net_folder = nil
        pcall(function()
            net_folder = rep.Packages._Index["sleitnick_net@0.2.0"].net
        end)
        if not net_folder then
            pcall(function()
                for _, d in ipairs(rep:GetDescendants()) do
                    if d.Name == "net" and d.Parent and string.find(string.lower(d.Parent.Name), "sleitnick", 1, true) then
                        net_folder = d
                        break
                    end
                end
            end)
        end

        if not net_folder then return end

        local children = net_folder:GetChildren()
        for i, child in ipairs(children) do
            for key, _ in pairs(trade_remote_names) do
                if string.find(child.Name, key, 1, true) then
                    discovered_remotes[key] = child

                    -- Sibling hash lookup (RF/ or RE/)
                    for j = i + 1, math.min(i + 4, #children) do
                        local next_c = children[j]
                        local n_name = next_c.Name
                        if string.sub(n_name, 1, 3) == "RF/" or string.sub(n_name, 1, 3) == "RE/" then
                            discovered_remotes[key .. "_hash"] = next_c
                            break
                        end
                    end
                end
            end
        end
    end)
end

resolve_all_remotes()

local function call_remote(key, ...)
    local target = discovered_remotes[key .. "_hash"] or discovered_remotes[key]
    if not target then return false, "Remote not found: " .. tostring(key) end

    if target:IsA("RemoteFunction") then
        return target:InvokeServer(...)
    elseif target:IsA("RemoteEvent") then
        target:FireServer(...)
        return true
    end
    return false, "Invalid remote instance"
end

local function connect_inbound(key, callback)
    pcall(function()
        local r = discovered_remotes[key]
        if r and r:IsA("RemoteEvent") then
            table.insert(conns, r.OnClientEvent:Connect(callback))
        end
        local r_hash = discovered_remotes[key .. "_hash"]
        if r_hash and r_hash:IsA("RemoteEvent") and r_hash ~= r then
            table.insert(conns, r_hash.OnClientEvent:Connect(callback))
        end
    end)
end

-- Inbound event listener untuk offer masuk
connect_inbound("TradeOfferReceived", function(requester, ...)
    if _G.NoirHub_AutoAccept_ScriptID ~= script_id or not config.enabled then return end
    local req_name = typeof(requester) == "Instance" and requester.Name or tostring(requester)
    update_status("Accepting: " .. req_name, Color3.fromRGB(255, 200, 0))

    -- 1. Sembunyikan Prompt & Klik YES
    check_and_accept_prompt()
    hide_prompt()

    -- 2. Panggil remote AcceptTradeOffer langsung
    pcall(call_remote, "AcceptTradeOffer", requester)

    task.delay(0.2, ensure_trade_window_open)
end)

-- ==============================================================================
-- 4. TRADING SESSION (Polling SetReady 0.4s + Click ACCEPT + Auto-Confirm)
-- ==============================================================================
local function click_trade_action_button()
    pcall(function()
        local t_gui = pgui:FindFirstChild("! Trading") or pgui:FindFirstChild("Trading") or pgui:FindFirstChild("Trade")
        if not t_gui then return end
        -- Cari tombol aksi di panel trade (ACCEPT, Ready, Confirm)
        for _, name in ipairs({"Accept", "accept", "ACCEPT", "Ready", "ready", "Confirm", "confirm"}) do
            local btn = t_gui:FindFirstChild(name, true)
            if btn and btn:IsA("GuiButton") then
                click_gui_button(btn)
            end
        end
    end)
end

local function on_trading_state_changed()
    if _G.NoirHub_AutoAccept_ScriptID ~= script_id then return end
    local is_trading = lp:GetAttribute("IsTrading")

    if is_trading and config.enabled then
        hide_prompt()
        ensure_trade_window_open()
        if trade_thread then return end

        trade_thread = task.spawn(function()
            update_status("Trade Active! Polling Ready...", Color3.fromRGB(255, 170, 0))
            local attempts = 0

            while config.enabled and lp:GetAttribute("IsTrading") do
                hide_prompt() -- Pastikan pop-up prompt tidak pernah muncul saat sesi trade
                ensure_trade_window_open()

                -- 1. Panggil Remote SetReady
                local ok, res = pcall(call_remote, "SetReady", true)

                -- 2. Klik tombol ACCEPT / Ready di GUI
                click_trade_action_button()

                if ok and res == true then
                    update_status("Ready OK! Confirming...", Color3.fromRGB(0, 229, 255))
                    break
                end

                attempts = attempts + 1
                if attempts >= 12 then
                    update_status("Waiting items (5s)...", Color3.fromRGB(255, 120, 120))
                    task.wait(5)
                    attempts = 0
                else
                    task.wait(0.4)
                end
            end

            -- Begitu Ready berhasil, langsung kunci Confirm
            if config.enabled and lp:GetAttribute("IsTrading") then
                task.wait(0.5)
                pcall(call_remote, "ConfirmTrade")
                click_trade_action_button()
                update_status("Confirmed! Finalizing...", Color3.fromRGB(0, 255, 170))
            end

            trade_thread = nil
        end)
    else
        if trade_thread then
            task.cancel(trade_thread)
            trade_thread = nil
        end
        update_status(config.enabled and "Listening..." or "Disabled", config.enabled and Color3.fromRGB(0, 255, 170) or Color3.fromRGB(150, 150, 150))
    end
end

table.insert(conns, lp:GetAttributeChangedSignal("IsTrading"):Connect(on_trading_state_changed))

connect_inbound("TradeStarted", function(...)
    hide_prompt()
    ensure_trade_window_open()
    task.defer(on_trading_state_changed)
end)

connect_inbound("TradeEnded", function(...)
    if trade_thread then
        task.cancel(trade_thread)
        trade_thread = nil
    end
    update_status(config.enabled and "Listening..." or "Disabled", config.enabled and Color3.fromRGB(0, 255, 170) or Color3.fromRGB(150, 150, 150))
end)

-- Pantau GUI Prompt secara real-time
pcall(function()
    local prompt_gui = pgui:FindFirstChild("Prompt") or pgui:WaitForChild("Prompt", 5)
    if prompt_gui then
        table.insert(conns, prompt_gui:GetPropertyChangedSignal("Enabled"):Connect(function()
            if prompt_gui.Enabled and config.enabled then
                check_and_accept_prompt()
            end
        end))

        local blackout = prompt_gui:FindFirstChild("Blackout")
        if blackout then
            table.insert(conns, blackout:GetPropertyChangedSignal("Visible"):Connect(function()
                if blackout.Visible and config.enabled then
                    check_and_accept_prompt()
                end
            end))
            local label = blackout:FindFirstChild("Label")
            if label then
                table.insert(conns, label:GetPropertyChangedSignal("Text"):Connect(function()
                    if config.enabled then check_and_accept_prompt() end
                end))
            end
        end
    end
end)

-- ==============================================================================
-- 5. MINIMAL & SLEEK DRAGGABLE UI
-- ==============================================================================
local function create_ui()
    local parent = (gethui and gethui()) or game:GetService("CoreGui") or pgui
    main_gui = Instance.new("ScreenGui")
    main_gui.Name = "Noir_AutoAccept"
    main_gui.ResetOnSpawn = false
    main_gui.DisplayOrder = 2147483647
    main_gui.Parent = parent

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 185, 0, 80)
    frame.Position = UDim2.new(0.5, -92, 0.35, 0)
    frame.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
    frame.Active = true
    frame.Parent = main_gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(200, 0, 200)
    stroke.Thickness = 1.2

    -- Title & Drag Handle
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -10, 0, 22)
    title.Position = UDim2.new(0, 8, 0, 2)
    title.BackgroundTransparency = 1
    title.Text = "⚡ NØIR AutoAccept [v7.2]"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 10
    title.Font = Enum.Font.SourceSansBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local drag_toggle, drag_start, start_pos
    title.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag_toggle = true; drag_start = i.Position; start_pos = frame.Position
            i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then drag_toggle = false end end)
        end
    end)
    uis.InputChanged:Connect(function(i)
        if drag_toggle and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - drag_start
            frame.Position = UDim2.new(start_pos.X.Scale, start_pos.X.Offset + d.X, start_pos.Y.Scale, start_pos.Y.Offset + d.Y)
        end
    end)

    -- Toggle Switch Row
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -16, 0, 20)
    row.Position = UDim2.new(0, 8, 0, 26)
    row.BackgroundTransparency = 1
    row.Parent = frame

    local row_lbl = Instance.new("TextLabel")
    row_lbl.Size = UDim2.new(0.65, 0, 1, 0)
    row_lbl.BackgroundTransparency = 1
    row_lbl.Text = "Auto Trade System"
    row_lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    row_lbl.TextSize = 9
    row_lbl.Font = Enum.Font.SourceSansBold
    row_lbl.TextXAlignment = Enum.TextXAlignment.Left
    row_lbl.Parent = row

    local cap = Instance.new("TextButton")
    cap.Size = UDim2.new(0, 32, 0, 16)
    cap.Position = UDim2.new(1, -32, 0.5, -8)
    cap.BackgroundColor3 = Color3.fromRGB(255, 0, 255)
    cap.Text = ""
    cap.AutoButtonColor = false
    cap.Parent = row
    Instance.new("UICorner", cap).CornerRadius = UDim.new(0.5, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.Position = UDim2.new(1, -14, 0.5, -6)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = cap
    Instance.new("UICorner", knob).CornerRadius = UDim.new(0.5, 0)

    cap.MouseButton1Click:Connect(function()
        config.enabled = not config.enabled
        ts:Create(knob, TweenInfo.new(0.12), { Position = config.enabled and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6) }):Play()
        ts:Create(cap, TweenInfo.new(0.12), { BackgroundColor3 = config.enabled and Color3.fromRGB(255, 0, 255) or Color3.fromRGB(50, 50, 50) }):Play()
        update_status(config.enabled and "Listening..." or "Disabled", config.enabled and Color3.fromRGB(0, 255, 170) or Color3.fromRGB(150, 150, 150))
        if not config.enabled then
            if trade_thread then
                task.cancel(trade_thread)
                trade_thread = nil
            end
            restore_prompt_defaults()
        else
            check_and_accept_prompt()
        end
    end)

    -- Status Badge
    status_lbl = Instance.new("TextLabel")
    status_lbl.Size = UDim2.new(1, -16, 0, 22)
    status_lbl.Position = UDim2.new(0, 8, 0, 50)
    status_lbl.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    status_lbl.Text = "[v7.2] Status: Listening..."
    status_lbl.TextColor3 = Color3.fromRGB(0, 255, 170)
    status_lbl.TextSize = 8.5
    status_lbl.Font = Enum.Font.Code
    status_lbl.Parent = frame
    Instance.new("UICorner", status_lbl).CornerRadius = UDim.new(0, 4)
end

-- ==============================================================================
-- 6. INITIALIZE & CLEANUP
-- ==============================================================================
create_ui()

-- Bersihkan pop-up seketika saat dieksekusi
check_and_accept_prompt()

if lp:GetAttribute("IsTrading") then
    hide_prompt()
    on_trading_state_changed()
end

_G.NoirHub_AutoAccept_Cleanup = function()
    config.enabled = false
    _G.NoirHub_AutoAccept_ScriptID = nil
    if trade_thread then task.cancel(trade_thread); trade_thread = nil end
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    if main_gui then pcall(function() main_gui:Destroy() end) end
    restore_prompt_defaults()
end

print("[NØIR Hub] Auto Accept [v7.2] Ready & Clean!")
