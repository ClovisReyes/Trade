-- NØIR Hub - Debug Path Finder
-- Standalone Debug Tool

local players = game:GetService("Players")
local local_player = players.LocalPlayer
while not local_player do
    task.wait(0.1)
    local_player = players.LocalPlayer
end

-- Safe Time Retrieval Fallback System (Guards against executor os.date crashes)
local function get_time_string()
    local success_time, result = pcall(function()
        return DateTime.now():FormatLocalTime("HH:mm:ss", "en-us")
    end)
    if success_time and result then return result end
    
    local success_os, result_os = pcall(function()
        return os.date("%X")
    end)
    if success_os and result_os then return result_os end
    
    local t = tick()
    local hours = math.floor(t / 3600) % 24
    local mins = math.floor(t / 60) % 60
    local secs = math.floor(t) % 60
    return string.format("%02d:%02d:%02d", hours, mins, secs)
end

local success, err = pcall(function()
    -- WaitForChild ensures the PlayerGui folder is fully initialized before accessing
    local player_gui = local_player:WaitForChild("PlayerGui", 10)
    if not player_gui then
        player_gui = local_player:FindFirstChildOfClass("PlayerGui")
    end
    if not player_gui then
        error("PlayerGui folder could not be found or loaded!")
    end

    -- Clean up any existing debug UI
    local old_gui = player_gui:FindFirstChild("NoirNotifDebugger")
    if old_gui then old_gui:Destroy() end

    -- ScreenGui Setup
    local gui = Instance.new("ScreenGui")
    gui.Name = "NoirNotifDebugger"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 2147483647
    gui.Parent = player_gui

    -- Main Container
    local main_frame = Instance.new("Frame")
    main_frame.Name = "MainFrame"
    main_frame.Size = UDim2.new(0, 480, 0, 360)
    main_frame.Position = UDim2.new(0.5, -240, 0.2, 0)
    main_frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    main_frame.Active = true
    main_frame.Draggable = true
    main_frame.Parent = gui

    local main_corner = Instance.new("UICorner")
    main_corner.CornerRadius = UDim.new(0, 8)
    main_corner.Parent = main_frame

    local main_stroke = Instance.new("UIStroke")
    main_stroke.Color = Color3.fromRGB(192, 0, 192) -- Pink Accent
    main_stroke.Thickness = 1.5
    main_stroke.Parent = main_frame

    -- Title Bar
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundTransparency = 1
    title.Text = "  NØIR Hub - Debug Path Finder"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 12
    title.Font = Enum.Font.SourceSansBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = main_frame

    -- Close Button
    local close_btn = Instance.new("TextButton")
    close_btn.Size = UDim2.new(0, 24, 0, 24)
    close_btn.Position = UDim2.new(1, -28, 0, 3)
    close_btn.BackgroundColor3 = Color3.fromRGB(30, 15, 15)
    close_btn.Text = "X"
    close_btn.TextColor3 = Color3.fromRGB(240, 70, 70)
    close_btn.TextSize = 12
    close_btn.Font = Enum.Font.SourceSansBold
    close_btn.Parent = main_frame

    local close_c = Instance.new("UICorner")
    close_c.CornerRadius = UDim.new(0.5, 0)
    close_c.Parent = close_btn

    close_btn.Activated:Connect(function()
        gui:Destroy()
    end)

    -- Status Label
    local status_lbl = Instance.new("TextLabel")
    status_lbl.Size = UDim2.new(1, -20, 0, 30)
    status_lbl.Position = UDim2.new(0, 10, 0, 35)
    status_lbl.BackgroundTransparency = 1
    status_lbl.Text = "Status: Click any button or wait for notifications..."
    status_lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    status_lbl.TextSize = 10
    status_lbl.Font = Enum.Font.SourceSans
    status_lbl.TextXAlignment = Enum.TextXAlignment.Left
    status_lbl.TextWrapped = true
    status_lbl.Parent = main_frame

    -- Path TextBox (for easy copying/viewing)
    local path_box = Instance.new("TextBox")
    path_box.Size = UDim2.new(1, -20, 0, 235)
    path_box.Position = UDim2.new(0, 10, 0, 70)
    path_box.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    path_box.Text = "History is empty. Click any elements..."
    path_box.TextColor3 = Color3.fromRGB(150, 150, 150)
    path_box.TextSize = 9
    path_box.Font = Enum.Font.Code
    path_box.TextWrapped = true
    path_box.ClearTextOnFocus = false
    path_box.TextEditable = false
    path_box.MultiLine = true
    path_box.TextXAlignment = Enum.TextXAlignment.Left
    path_box.TextYAlignment = Enum.TextYAlignment.Top
    path_box.Parent = main_frame

    local path_c = Instance.new("UICorner")
    path_c.CornerRadius = UDim.new(0, 4)
    path_c.Parent = path_box

    local path_stroke = Instance.new("UIStroke")
    path_stroke.Color = Color3.fromRGB(45, 45, 45)
    path_stroke.Thickness = 1
    path_stroke.Parent = path_box

    -- Copy Button
    local copy_btn = Instance.new("TextButton")
    copy_btn.Size = UDim2.new(1, -20, 0, 30)
    copy_btn.Position = UDim2.new(0, 10, 0, 315)
    copy_btn.BackgroundColor3 = Color3.fromRGB(192, 0, 192)
    copy_btn.Text = "Copy Path to Clipboard"
    copy_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    copy_btn.TextSize = 10
    copy_btn.Font = Enum.Font.SourceSansBold
    copy_btn.Parent = main_frame

    local copy_c = Instance.new("UICorner")
    copy_c.CornerRadius = UDim.new(0, 4)
    copy_c.Parent = copy_btn

    -- Dynamic Button Effects
    copy_btn.MouseEnter:Connect(function()
        copy_btn.BackgroundColor3 = Color3.fromRGB(240, 50, 240)
    end)
    copy_btn.MouseLeave:Connect(function()
        copy_btn.BackgroundColor3 = Color3.fromRGB(192, 0, 192)
    end)

    copy_btn.Activated:Connect(function()
        local current_path = path_box.Text
        if current_path ~= "History is empty. Click any elements..." and current_path ~= "Searching..." then
            local copy_success = pcall(function()
                setclipboard(current_path)
            end)
            if copy_success then
                copy_btn.Text = "Copied successfully!"
            else
                copy_btn.Text = "Failed to auto-copy. Please select text inside box above."
            end
            task.wait(2)
            copy_btn.Text = "Copy Path to Clipboard"
        end
    end)

    -- History Log Registry
    local click_history = {}
    local max_history = 15

    local function update_history_display(success_color)
        if #click_history == 0 then
            path_box.Text = "History is empty. Click any elements..."
            path_box.TextColor3 = Color3.fromRGB(150, 150, 150)
            return
        end
        path_box.Text = table.concat(click_history, "\n\n========================\n\n")
        path_box.TextColor3 = success_color or Color3.fromRGB(0, 191, 255)
    end

    -- Startup Scan: Scan ReplicatedStorage for 'Trade' remotes and log to history box
    pcall(function()
        local found_remotes = {}
        for _, v in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
            if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                if v.Name:lower():find("trade") then
                    table.insert(found_remotes, string.format("  - %s (%s)\n    Path: %s", v.Name, v.ClassName, v:GetFullName()))
                end
            end
        end
        if #found_remotes > 0 then
            local startup_log = string.format("[STARTUP] Found %d Trade Remotes:\n%s", #found_remotes, table.concat(found_remotes, "\n\n"))
            table.insert(click_history, startup_log)
        else
            table.insert(click_history, "[STARTUP] No 'Trade' remotes found in ReplicatedStorage.")
        end
    end)
    update_history_display(Color3.fromRGB(200, 200, 200))

    -- Remote Interception Hooks (Captures exact game-passed arguments in memory)
    pcall(function()
        local function log_remote_call(remote_obj, args)
            local arg_strings = {}
            for i, v in ipairs(args) do
                table.insert(arg_strings, string.format("  Arg %d: %s (%s)", i, tostring(v), type(v)))
            end
            local log_entry = string.format("[%s] Hooked %s (%s):\n%s", get_time_string(), remote_obj:GetFullName(), remote_obj.ClassName, table.concat(arg_strings, "\n"))
            table.insert(click_history, 1, log_entry)
            if #click_history > max_history then table.remove(click_history) end
            update_history_display()
        end

        -- Method 1: hookmetamethod (standard executor hook)
        if hookmetamethod then
            local old_namecall
            old_namecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                if method == "InvokeServer" or method == "FireServer" then
                    local name = self.Name
                    if name:find("AcceptTradeOffer") or name:find("SendTradeOffer") or name:find("InitiateTrade") then
                        log_remote_call(self, {...})
                    end
                end
                return old_namecall(self, ...)
            end)
            table.insert(click_history, 1, "[HOOK] hookmetamethod registered successfully!")
        else
            -- Method 2: hookfunction on RemoteFunction/RemoteEvent methods
            local old_invoke
            if hookfunction and Instance.new("RemoteFunction").InvokeServer then
                old_invoke = hookfunction(Instance.new("RemoteFunction").InvokeServer, function(self, ...)
                    local name = self.Name
                    if name:find("AcceptTradeOffer") or name:find("SendTradeOffer") or name:find("InitiateTrade") then
                        log_remote_call(self, {...})
                    end
                    return old_invoke(self, ...)
                end)
                table.insert(click_history, 1, "[HOOK] hookfunction registered successfully!")
            else
                table.insert(click_history, 1, "[HOOK] hookmetamethod/hookfunction not supported on this executor.")
            end
        end
    end)
    update_history_display(Color3.fromRGB(200, 200, 200))

    -- Notification Scanning Logic
    local function check_descendant(desc)
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            local text = desc.Text or ""
            if text:lower():find("completed!") and (text:lower():find("trade with") or text:lower():find("trade completed")) then
                local full_path = desc:GetFullName()
                local time_str = get_time_string()
                local log_entry = string.format("[%s] Notification Detected:\n  - %s (%s)\n  Text: \"%s\"", time_str, full_path, desc.ClassName, text)
                
                table.insert(click_history, 1, log_entry)
                if #click_history > max_history then
                    table.remove(click_history)
                end
                update_history_display(Color3.fromRGB(0, 255, 127))
                
                status_lbl.Text = "Status: Notification Detected! Path copied."
                status_lbl.TextColor3 = Color3.fromRGB(0, 255, 127)
                
                pcall(function()
                    local clone = desc:Clone()
                    clone.Name = "Noir_Notification_Debug"
                    clone.Parent = workspace
                end)
                
                pcall(function()
                    setclipboard(full_path)
                end)
            end
        end
    end

    -- Scan PlayerGui for notifications
    for _, desc in ipairs(player_gui:GetDescendants()) do
        check_descendant(desc)
    end

    -- Connections Registry for Cleanup
    local connections = {}

    -- Notification Connection
    local playergui_conn = player_gui.DescendantAdded:Connect(check_descendant)
    table.insert(connections, playergui_conn)

    -- Single Global Mouse Click / Touch Tap Listener (High Performance, 0% CPU Overhead)
    local user_input_service = game:GetService("UserInputService")
    local click_conn = user_input_service.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local pos = input.Position
            
            -- Get all GUI elements at click position under PlayerGui
            local gui_objects = player_gui:GetGuiObjectsAtPosition(pos.X, pos.Y)
            
            -- Check if we clicked our own debugger UI first
            local clicked_self = false
            for _, obj in ipairs(gui_objects) do
                if obj:IsDescendantOf(gui) then
                    clicked_self = true
                    break
                end
            end
            
            if clicked_self then
                return -- Ignore clicks on the debugger UI itself
            end
            
            local clicked_paths = {}
            local count = 0
            for _, obj in ipairs(gui_objects) do
                if not obj:IsDescendantOf(gui) then
                    count = count + 1
                    table.insert(clicked_paths, string.format("  %d. %s (%s)", count, obj:GetFullName(), obj.ClassName))
                end
            end
            
            if count > 0 then
                local time_str = get_time_string()
                local log_entry = string.format("[%s] Coordinates Click:\n%s", time_str, table.concat(clicked_paths, "\n"))
                
                table.insert(click_history, 1, log_entry)
                if #click_history > max_history then
                    table.remove(click_history)
                end
                update_history_display(Color3.fromRGB(0, 191, 255))
                
                status_lbl.Text = "Status: " .. count .. " element(s) logged under cursor!"
                status_lbl.TextColor3 = Color3.fromRGB(0, 191, 255)
                
                -- Copy the topmost clicked element path to clipboard
                local topmost_obj = nil
                for _, obj in ipairs(gui_objects) do
                    if not obj:IsDescendantOf(gui) then
                        topmost_obj = obj
                        break
                    end
                end
                if topmost_obj then
                    pcall(function()
                        setclipboard(topmost_obj:GetFullName())
                    end)
                end
            else
                local time_str = get_time_string()
                local log_entry = string.format("[%s] Coordinates Click:\n  - No elements found at clicked position.", time_str)
                
                table.insert(click_history, 1, log_entry)
                if #click_history > max_history then
                    table.remove(click_history)
                end
                update_history_display(Color3.fromRGB(150, 150, 150))
                
                status_lbl.Text = "Status: Click registered but no element found."
                status_lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        end
    end)
    table.insert(connections, click_conn)

    -- Clean up connections when UI is destroyed
    gui.Destroying:Connect(function()
        for _, conn in ipairs(connections) do
            pcall(function() conn:Disconnect() end)
        end
    end)
end)

if not success then
    warn("Noir Debugger Startup Error: " .. tostring(err))
    print("Noir Debugger Startup Error: " .. tostring(err))
end
