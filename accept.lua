--[[
    NOIR HUB - AUTO ACCEPT TRADE [v7.0]
    Arsitektur 100% Direct-Remote (Bypass GUI 100%):
    1. Instant Accept: Menangkap event TradeOfferReceived & langsung panggil AcceptTradeOffer (8ms).
    2. Server-Driven Polling: SetReady dipanggil tiap 0.4s (12x attempt -> 5s backoff).
    3. Auto Confirm: Begitu server merespon Ready [true], langsung panggil ConfirmTrade.
    4. Tanpa Deteksi Slot / Tanpa Klik GUI / Anti-BAC & Ringkas (~160 baris).
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

-- ==============================================================================
-- 1. REMOTE DISCOVERY (sleitnick_net direct & hash resolver)
-- ==============================================================================
local remotes = {}
pcall(function()
    local net = rep:WaitForChild("Packages", 5)._Index["sleitnick_net@0.2.0"].net
    local children = net:GetChildren()
    local target_names = {
        "TradeOfferReceived",
        "AcceptTradeOffer",
        "SetReady",
        "ConfirmTrade",
        "TradeStarted",
        "TradeEnded"
    }

    for i, child in ipairs(children) do
        for _, name in ipairs(target_names) do
            if string.find(child.Name, name, 1, true) then
                if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                    remotes[name] = child
                else
                    for j = i + 1, math.min(i + 4, #children) do
                        local next_c = children[j]
                        if string.sub(next_c.Name, 1, 3) == "RF/" or string.sub(next_c.Name, 1, 3) == "RE/" then
                            remotes[name] = next_c
                            break
                        end
                    end
                end
            end
        end
    end
end)

local function call_remote(remote, ...)
    if not remote then return false, "No remote" end
    if remote:IsA("RemoteFunction") then
        return remote:InvokeServer(...)
    elseif remote:IsA("RemoteEvent") then
        remote:FireServer(...)
        return true
    end
    return false, "Invalid remote"
end

local function update_status(text, color)
    if status_lbl and status_lbl.Parent then
        status_lbl.Text = "[v7.0] " .. tostring(text)
        if color then status_lbl.TextColor3 = color end
    end
end

-- ==============================================================================
-- 2. CORE ENGINE (Pure Direct-Remote Reverse-Engineered System)
-- ==============================================================================

-- 1. Instant Offer Accept
if remotes.TradeOfferReceived and remotes.TradeOfferReceived:IsA("RemoteEvent") then
    table.insert(conns, remotes.TradeOfferReceived.OnClientEvent:Connect(function(req)
        if _G.NoirHub_AutoAccept_ScriptID ~= script_id or not config.enabled then return end
        local sender_name = typeof(req) == "Instance" and req.Name or tostring(req)
        update_status("Accepting: " .. sender_name, Color3.fromRGB(255, 200, 0))

        -- Langsung panggil remote AcceptTradeOffer seketika
        pcall(call_remote, remotes.AcceptTradeOffer, req)

        -- Sembunyikan dialog Prompt game agar layar bersih
        pcall(function()
            local p = pgui:FindFirstChild("Prompt")
            if p then p.Enabled = false end
        end)
    end))
end

-- 2. Polling Ready & Instant Confirm Loop
local function on_trading_changed()
    if _G.NoirHub_AutoAccept_ScriptID ~= script_id then return end
    local is_trading = lp:GetAttribute("IsTrading")

    if is_trading and config.enabled then
        if trade_thread then return end
        trade_thread = task.spawn(function()
            update_status("Trade Active! Polling Ready...", Color3.fromRGB(255, 170, 0))
            local attempts = 0

            while config.enabled and lp:GetAttribute("IsTrading") do
                local ok, res = pcall(call_remote, remotes.SetReady, true)
                if ok and res == true then
                    update_status("Ready OK! Confirming...", Color3.fromRGB(0, 229, 255))
                    break
                end

                attempts = attempts + 1
                if attempts >= 12 then
                    update_status("Waiting items (Cooldown 5s)...", Color3.fromRGB(255, 120, 120))
                    task.wait(5)
                    attempts = 0
                else
                    task.wait(0.4)
                end
            end

            -- Begitu status Ready diterima server, langsung kunci Confirm
            if config.enabled and lp:GetAttribute("IsTrading") then
                task.wait(0.5)
                pcall(call_remote, remotes.ConfirmTrade)
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

table.insert(conns, lp:GetAttributeChangedSignal("IsTrading"):Connect(on_trading_changed))

if remotes.TradeStarted and remotes.TradeStarted:IsA("RemoteEvent") then
    table.insert(conns, remotes.TradeStarted.OnClientEvent:Connect(function()
        task.defer(on_trading_changed)
    end))
end

-- ==============================================================================
-- 3. MINIMAL & SLEEK UI
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
    title.Text = "⚡ NØIR AutoAccept [v7.0]"
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
        if not config.enabled and trade_thread then
            task.cancel(trade_thread)
            trade_thread = nil
        end
    end)

    -- Status Badge
    status_lbl = Instance.new("TextLabel")
    status_lbl.Size = UDim2.new(1, -16, 0, 22)
    status_lbl.Position = UDim2.new(0, 8, 0, 50)
    status_lbl.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    status_lbl.Text = "[v7.0] Status: Listening..."
    status_lbl.TextColor3 = Color3.fromRGB(0, 255, 170)
    status_lbl.TextSize = 8.5
    status_lbl.Font = Enum.Font.Code
    status_lbl.Parent = frame
    Instance.new("UICorner", status_lbl).CornerRadius = UDim.new(0, 4)
end

-- ==============================================================================
-- 4. INITIALIZE & CLEANUP EXPORT
-- ==============================================================================
create_ui()

if lp:GetAttribute("IsTrading") then
    on_trading_changed()
end

_G.NoirHub_AutoAccept_Cleanup = function()
    config.enabled = false
    _G.NoirHub_AutoAccept_ScriptID = nil
    if trade_thread then task.cancel(trade_thread); trade_thread = nil end
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    if main_gui then pcall(function() main_gui:Destroy() end) end
end

print("[NØIR Hub] Auto Accept [v7.0] Direct-Remote Engine initialized!")
