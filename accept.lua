--[[
    NOIR HUB - AUTO ACCEPT TRADE [v6.5]
    Super Ringkas & Bersih (< 220 baris).
    Anti-BAC (Safe UI automation & Countdown lock detection).
    Toggle OFF: Popup lama dibersihkan, popup baru muncul normal di tengah.
]]

local cloneref = cloneref or function(r) return r end
local players  = cloneref(game:GetService("Players"))
local lp       = players.LocalPlayer
local pgui     = cloneref(lp:WaitForChild("PlayerGui"))
local rep      = cloneref(game:GetService("ReplicatedStorage"))
local uis      = cloneref(game:GetService("UserInputService"))
local ts       = cloneref(game:GetService("TweenService"))

if _G.NoirHub_AutoAccept_Cleanup then pcall(_G.NoirHub_AutoAccept_Cleanup) end
local script_id = os.clock()
_G.NoirHub_AutoAccept_ScriptID = script_id

local config = { enabled = true }
local status_lbl, main_gui = nil, nil
local conns = {}

-- 1. Helper: Click GUI Button (Mobile/PC Executor Safe)
local function click_btn(btn)
    if not btn or not btn:IsA("GuiButton") then return end
    btn.Active = true
    if firesignal then
        pcall(firesignal, btn.Activated)
        pcall(firesignal, btn.MouseButton1Click)
    elseif getconnections then
        for _, sig in ipairs({btn.Activated, btn.MouseButton1Click}) do
            for _, c in ipairs(getconnections(sig)) do
                if c.Fire then pcall(function() c:Fire() end) elseif c.Function then pcall(c.Function) end
            end
        end
    end
end

-- 2. Net Remote Resolver (Auto-find sleitnick net)
local remotes = {}
pcall(function()
    local net = rep.Packages._Index["sleitnick_net@0.2.0"].net
    local list = net:GetChildren()
    for i, c in ipairs(list) do
        for _, name in ipairs({"TradeOfferReceived", "TradeStarted", "TradeEnded", "AcceptTradeOffer"}) do
            if string.find(c.Name, name, 1, true) then
                if c:IsA("RemoteEvent") or c:IsA("RemoteFunction") then
                    remotes[name] = c
                else
                    for j = i + 1, math.min(i + 4, #list) do
                        if string.match(list[j].Name, "^R[FE]/") then
                            remotes[name] = list[j]
                            break
                        end
                    end
                end
            end
        end
    end
end)

-- 3. Prompt Management (Sembunyikan saat ON, Bersihkan / Tampilkan saat OFF)
local function set_prompt_clean(is_off_reset)
    local p = pgui:FindFirstChild("Prompt")
    if not p then return end
    local b = p:FindFirstChild("Blackout")
    local f = p:FindFirstChild("Frame")
    if f then f.Visible = false; f.BackgroundTransparency = 1; f.Active = false end
    if b then
        b.AnchorPoint = Vector2.new(0.5, 0.5)
        if is_off_reset then
            -- Tutup prompt lama saat toggle di-off
            b.Position = UDim2.new(0.5, 0, 0.5, 0)
            b.Visible = false
            p.Enabled = false
        elseif not config.enabled then
            -- Munculkan prompt baru di tengah saat offer masuk (Toggle OFF)
            b.Position = UDim2.new(0.5, 0, 0.5, 0)
            b.Visible = true
            p.Enabled = true
        else
            -- Sembunyikan ke luar layar saat Toggle ON
            b.Position = UDim2.new(10, 0, 10, 0)
        end
    end
end

local function suppress_and_accept()
    if not config.enabled then return end
    local p = pgui:FindFirstChild("Prompt")
    local b = p and p:FindFirstChild("Blackout")
    if b then
        b.Position = UDim2.new(10, 0, 10, 0)
        local yes = b:FindFirstChild("Options") and b.Options:FindFirstChild("Yes")
        if yes then click_btn(yes) end
        task.delay(0.05, function() p.Enabled = false end)
    end
end

-- 4. Trade Session Auto-Confirm (Anti-BAC: Safe countdown detection, no spam)
local trade_running = false
local function handle_trade()
    if trade_running or not config.enabled then return end
    trade_running = true
    if status_lbl then status_lbl.Text = "[v6.5] Trade Active! Confirming..." end

    task.spawn(function()
        task.wait(0.5)
        local start = tick()
        while config.enabled and lp:GetAttribute("IsTrading") and (tick() - start < 60) do
            local tg = pgui:FindFirstChild("! Trading") or pgui:FindFirstChild("Trading")
            if tg then
                tg.Enabled = true
                -- Deteksi apakah masih countdown lock (cth: "Ready (3)", "(2s)", dll)
                local in_countdown = false
                for _, d in ipairs(tg:GetDescendants()) do
                    if d:IsA("TextLabel") or d:IsA("TextButton") then
                        local s = string.match(d.Text or "", "%((%d)s?%)") or string.match(d.Text or "", "Countdown: (%d)") or string.match(d.Text or "", "Confirm%s*%(?(%d)%)?")
                        if s and tonumber(s) and tonumber(s) > 0 then
                            in_countdown = true
                            break
                        end
                    end
                end

                -- Tekan Ready
                local ready = tg:FindFirstChild("Ready", true)
                if ready then click_btn(ready) end

                -- Hanya tekan Confirm jika countdown SUDAH SELESAI (Anti-BAC!)
                if not in_countdown then
                    local confirm = tg:FindFirstChild("Confirm", true) or tg:FindFirstChild("Accept", true)
                    if confirm then click_btn(confirm) end
                end
            end
            task.wait(0.6)
        end
        trade_running = false
        if status_lbl then status_lbl.Text = config.enabled and "[v6.5] Status: Listening" or "[v6.5] Status: Disabled" end
    end)
end

-- 5. Event Listeners
if remotes.TradeOfferReceived and remotes.TradeOfferReceived:IsA("RemoteEvent") then
    table.insert(conns, remotes.TradeOfferReceived.OnClientEvent:Connect(function(req)
        if _G.NoirHub_AutoAccept_ScriptID ~= script_id then return end
        if not config.enabled then
            set_prompt_clean(false) -- Munculkan popup baru bersih di tengah
            return
        end
        local req_name = typeof(req) == "Instance" and req.Name or tostring(req)
        if status_lbl then status_lbl.Text = "[v6.5] Accepting: " .. req_name end
        suppress_and_accept()
        if remotes.AcceptTradeOffer then
            pcall(function() remotes.AcceptTradeOffer:InvokeServer(req) end)
        end
    end))
end

if remotes.TradeStarted and remotes.TradeStarted:IsA("RemoteEvent") then
    table.insert(conns, remotes.TradeStarted.OnClientEvent:Connect(handle_trade))
end

table.insert(conns, lp:GetAttributeChangedSignal("IsTrading"):Connect(function()
    if lp:GetAttribute("IsTrading") then handle_trade() end
end))

-- Monitor Prompt GUI
pcall(function()
    local p = pgui:WaitForChild("Prompt", 5)
    if p then
        table.insert(conns, p:GetPropertyChangedSignal("Enabled"):Connect(function()
            if p.Enabled then
                if config.enabled then suppress_and_accept() else set_prompt_clean(false) end
            end
        end))
        local b = p:FindFirstChild("Blackout")
        local opt = b and b:FindFirstChild("Options")
        if opt then
            for _, btn in ipairs({opt:FindFirstChild("Yes"), opt:FindFirstChild("No")}) do
                if btn then
                    table.insert(conns, btn.MouseButton1Click:Connect(function()
                        task.delay(0.1, function() p.Enabled = false end)
                    end))
                end
            end
        end
    end
end)

-- 6. Clean, Compact UI (~80 baris)
local function create_ui()
    local parent = (gethui and gethui()) or game:GetService("CoreGui") or pgui
    main_gui = Instance.new("ScreenGui")
    main_gui.Name = "Noir_AutoAccept"
    main_gui.ResetOnSpawn = false
    main_gui.DisplayOrder = 2147483647
    main_gui.Parent = parent

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 180, 0, 85)
    frame.Position = UDim2.new(0.5, -90, 0.35, 0)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
    frame.Active = true
    frame.Parent = main_gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(200, 0, 200)
    stroke.Thickness = 1

    -- Title / Drag Handle
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -10, 0, 24)
    title.Position = UDim2.new(0, 8, 0, 2)
    title.BackgroundTransparency = 1
    title.Text = "NØIR AutoAccept [v6.5]"
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

    -- Toggle Row
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -16, 0, 22)
    row.Position = UDim2.new(0, 8, 0, 28)
    row.BackgroundTransparency = 1
    row.Parent = frame

    local row_lbl = Instance.new("TextLabel")
    row_lbl.Size = UDim2.new(0.65, 0, 1, 0)
    row_lbl.BackgroundTransparency = 1
    row_lbl.Text = "Auto Accept"
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
        if not config.enabled then set_prompt_clean(true) end
        if status_lbl then status_lbl.Text = config.enabled and "[v6.5] Status: Listening" or "[v6.5] Status: Disabled" end
    end)

    status_lbl = Instance.new("TextLabel")
    status_lbl.Size = UDim2.new(1, -16, 0, 22)
    status_lbl.Position = UDim2.new(0, 8, 0, 54)
    status_lbl.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    status_lbl.Text = "[v6.5] Status: Listening"
    status_lbl.TextColor3 = Color3.fromRGB(0, 255, 170)
    status_lbl.TextSize = 8.5
    status_lbl.Font = Enum.Font.Code
    status_lbl.Parent = frame
    Instance.new("UICorner", status_lbl).CornerRadius = UDim.new(0, 4)
end

-- 7. Init & Cleanup
create_ui()
if config.enabled then suppress_and_accept() end

_G.NoirHub_AutoAccept_Cleanup = function()
    config.enabled = false
    _G.NoirHub_AutoAccept_ScriptID = nil
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    if main_gui then main_gui:Destroy() end
    set_prompt_clean(true)
end

print("[Noir Hub] Auto Accept v6.5 loaded cleanly!")
