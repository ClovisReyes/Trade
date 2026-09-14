-- ==============================================================================
-- NOIR HUB - TRADE RUNTIME SPY WITH IN-GAME COPYABLE CONSOLE
-- Run this script FIRST before running your Luraph / Encrypted script!
-- Displays live logs on screen with 1-click "COPY ALL" button to clipboard.
-- ==============================================================================

local players = game:GetService("Players")
local local_player = players.LocalPlayer
local player_gui = local_player:WaitForChild("PlayerGui")
local replicated_storage = game:GetService("ReplicatedStorage")
local user_input_service = game:GetService("UserInputService")

local log_lines = {}
local log_text_box = nil
local log_scroll = nil

local function update_gui_console(line)
    if log_text_box and log_scroll then
        log_text_box.Text = table.concat(log_lines, "\n")
        log_text_box.Size = UDim2.new(1, -10, 0, #log_lines * 16 + 20)
        log_scroll.CanvasSize = UDim2.new(0, 0, 0, #log_lines * 16 + 25)
        log_scroll.CanvasPosition = Vector2.new(0, #log_lines * 16 + 25)
    end
end

local function log_entry(tag, message)
    local ts = os.date("%H:%M:%S")
    local line = string.format("[%s] [%s] %s", ts, tag, tostring(message))
    table.insert(log_lines, line)
    print(line)
    
    pcall(update_gui_console, line)

    pcall(function()
        if writefile then
            writefile("trade_spy_output.txt", table.concat(log_lines, "\n"))
        end
    end)
end

-- ==============================================================================
-- IN-GAME CONSOLE GUI
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

    pcall(function()
        local old = parent_gui:FindFirstChild("NoirHub_SpyConsole")
        if old then old:Destroy() end
    end)

    local gui = Instance.new("ScreenGui")
    gui.Name = "NoirHub_SpyConsole"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 2147483647
    gui.Parent = parent_gui

    local main = Instance.new("Frame")
    main.Name = "ConsoleFrame"
    main.Size = UDim2.new(0, 360, 0, 220)
    main.Position = UDim2.new(0.5, -180, 0.6, 0)
    main.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
    main.BackgroundTransparency = 0.15
    main.BorderSizePixel = 0
    main.Active = true
    main.ZIndex = 100
    main.Parent = gui

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 255, 180)
    stroke.Thickness = 1.5
    stroke.Parent = main

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = main

    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 28)
    header.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    header.ZIndex = 101
    header.Parent = main

    local h_corner = Instance.new("UICorner")
    h_corner.CornerRadius = UDim.new(0, 8)
    h_corner.Parent = header

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -140, 1, 0)
    title.Position = UDim2.new(0, 8, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🕵️ Trade Runtime Spy Console"
    title.TextColor3 = Color3.fromRGB(0, 255, 180)
    title.TextSize = 10
    title.Font = Enum.Font.SourceSansBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 102
    title.Parent = header

    -- Copy Button
    local copy_btn = Instance.new("TextButton")
    copy_btn.Size = UDim2.new(0, 70, 0, 20)
    copy_btn.Position = UDim2.new(1, -125, 0.5, -10)
    copy_btn.BackgroundColor3 = Color3.fromRGB(0, 180, 120)
    copy_btn.Text = "📋 Copy All"
    copy_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    copy_btn.TextSize = 9
    copy_btn.Font = Enum.Font.SourceSansBold
    copy_btn.ZIndex = 102
    copy_btn.Parent = header

    local copy_c = Instance.new("UICorner")
    copy_c.CornerRadius = UDim.new(0, 4)
    copy_c.Parent = copy_btn

    copy_btn.MouseButton1Click:Connect(function()
        local full_text = table.concat(log_lines, "\n")
        if setclipboard then
            setclipboard(full_text)
            copy_btn.Text = "✅ Copied!"
        elseif toclipboard then
            toclipboard(full_text)
            copy_btn.Text = "✅ Copied!"
        else
            copy_btn.Text = "Select All Text"
        end
        task.delay(1.5, function()
            copy_btn.Text = "📋 Copy All"
        end)
    end)

    -- Clear Button
    local clear_btn = Instance.new("TextButton")
    clear_btn.Size = UDim2.new(0, 45, 0, 20)
    clear_btn.Position = UDim2.new(1, -50, 0.5, -10)
    clear_btn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    clear_btn.Text = "Clear"
    clear_btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    clear_btn.TextSize = 9
    clear_btn.Font = Enum.Font.SourceSansBold
    clear_btn.ZIndex = 102
    clear_btn.Parent = header

    local clear_c = Instance.new("UICorner")
    clear_c.CornerRadius = UDim.new(0, 4)
    clear_c.Parent = clear_btn

    clear_btn.MouseButton1Click:Connect(function()
        log_lines = {}
        log_entry("SPY_CLEARED", "Console logs cleared.")
    end)

    -- Log Scroll & TextBox
    log_scroll = Instance.new("ScrollingFrame")
    log_scroll.Size = UDim2.new(1, -12, 1, -36)
    log_scroll.Position = UDim2.new(0, 6, 0, 32)
    log_scroll.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
    log_scroll.BackgroundTransparency = 0.3
    log_scroll.BorderSizePixel = 0
    log_scroll.ScrollBarThickness = 4
    log_scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 180)
    log_scroll.Active = true
    log_scroll.ZIndex = 101
    log_scroll.Parent = main

    local sc_corner = Instance.new("UICorner")
    sc_corner.CornerRadius = UDim.new(0, 4)
    sc_corner.Parent = log_scroll

    log_text_box = Instance.new("TextBox")
    log_text_box.Size = UDim2.new(1, -10, 1, 0)
    log_text_box.Position = UDim2.new(0, 5, 0, 2)
    log_text_box.BackgroundTransparency = 1
    log_text_box.Text = table.concat(log_lines, "\n")
    log_text_box.TextColor3 = Color3.fromRGB(220, 255, 240)
    log_text_box.TextSize = 8.5
    log_text_box.Font = Enum.Font.Code
    log_text_box.TextXAlignment = Enum.TextXAlignment.Left
    log_text_box.TextYAlignment = Enum.TextYAlignment.Top
    log_text_box.ClearTextOnFocus = false
    log_text_box.TextEditable = false
    log_text_box.ZIndex = 102
    log_text_box.Parent = log_scroll

    -- Drag logic
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

pcall(create_spy_gui)

-- ==============================================================================
-- RUNTIME SPY / HOOKS
-- ==============================================================================
log_entry("SPY_INIT", "=== Trade Runtime Spy Started ===")
log_entry("SPY_INFO", "Silakan jalankan script Luraph kamu & lakukan test trade.")

-- 1. REMOTE SPY (__namecall Hook)
local g_meta = getrawmetatable and getrawmetatable(game) or nil
if g_meta and setreadonly and hookmetamethod then
    local old_namecall
    old_namecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = { ... }

        if (method == "InvokeServer" or method == "FireServer") and self then
            local self_name = tostring(self.Name)
            local self_parent = tostring(self.Parent and self.Parent.Name or "nil")
            
            -- Filter trade remotes or Sleitnick Net remotes
            if string.find(string.lower(self_name), "trade") or string.find(string.lower(self_name), "r") or string.find(string.lower(self_parent), "net") then
                local formatted_args = {}
                for i, v in ipairs(args) do
                    table.insert(formatted_args, string.format("arg[%d]=%s (%s)", i, tostring(v), typeof(v)))
                end
                log_entry("REMOTE", string.format("%s:%s([%s])", self_name, method, table.concat(formatted_args, ", ")))
            end
        end

        return old_namecall(self, ...)
    end)
    log_entry("HOOK", "Successfully hooked game.__namecall")
end

-- 2. GUI PROPERTY SPY (PlayerGui.Prompt)
local prompt_gui = player_gui:WaitForChild("Prompt", 5)
if prompt_gui then
    log_entry("GUI", "Monitoring PlayerGui.Prompt...")

    prompt_gui:GetPropertyChangedSignal("Enabled"):Connect(function()
        log_entry("PROMPT", "Prompt.Enabled = " .. tostring(prompt_gui.Enabled))
    end)

    local blackout = prompt_gui:FindFirstChild("Blackout")
    if blackout then
        blackout:GetPropertyChangedSignal("Visible"):Connect(function()
            log_entry("BLACKOUT", "Blackout.Visible = " .. tostring(blackout.Visible))
        end)
    end

    local frame = prompt_gui:FindFirstChild("Frame")
    if frame then
        frame:GetPropertyChangedSignal("Visible"):Connect(function()
            log_entry("FRAME", "Frame.Visible = " .. tostring(frame.Visible))
        end)
    end

    prompt_gui.DescendantAdded:Connect(function(desc)
        log_entry("ADDED", string.format("Descendant: %s (%s)", desc.Name, desc.ClassName))
    end)
end

-- 3. TRADING GUI SPY
task_spawn(function()
    local t_gui = player_gui:WaitForChild("! Trading", 10) or player_gui:WaitForChild("Trading", 10)
    if t_gui then
        log_entry("GUI", "Monitoring Trading GUI (" .. t_gui.Name .. ")...")
        t_gui:GetPropertyChangedSignal("Enabled"):Connect(function()
            log_entry("TRADING", t_gui.Name .. ".Enabled = " .. tostring(t_gui.Enabled))
        end)
    end
end)

log_entry("READY", "Spy is actively listening...")
