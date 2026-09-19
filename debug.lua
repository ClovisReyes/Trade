--[[
    ====================================================================================
    🐟 FISH IT - PURE PASSIVE TRADE SPY & PACKET LOGGER 🕵️‍♂️ (NON-BLOCKING)
    ====================================================================================
    Tujuan:
    Merekam aktivitas RemoteFunction & RemoteEvent trade secara 100% pasif (asynchronous),
    TANPA memblokir popup trade, TANPA memotong data return server, dan TANPA lag.

    Prinsip Kerja:
    1. 100% Non-Blocking:
       - Pemanggilan `old_namecall(self, ...)` dieksekusi langsung tanpa pcall / modifikasi.
       - Logging diproses di background (`task.spawn`) sehingga game/script berjalan normal.
    2. Scoped Focus (Trade Only):
       - Hanya mendengarkan remote bertema Trading (`RF/Trading/*`, `RE/Trading/*`).
       - Remote game lain (gerakan, prompt, kamera, popup GUI) tidak disentuh sama sekali.
    3. UI Responsif & Draggable:
       - Touch & Mouse draggable, tombol Copy Logs & Save File.
    ====================================================================================
--]]

local cloneref = cloneref or function(ref) return ref end
local players = cloneref(game:GetService("Players"))
local replicated_storage = cloneref(game:GetService("ReplicatedStorage"))
local user_input_service = cloneref(game:GetService("UserInputService"))

local local_player = players.LocalPlayer
if not local_player then
    pcall(function()
        local_player = players.LocalPlayer or players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    end)
end

-- State
local logs_list = {}
local is_capturing = true
local start_time = os.clock()
local last_log_time = os.clock()

-- Safe Serializer
local function safe_serialize(val, indent, max_depth, seen)
    indent = indent or 0
    max_depth = max_depth or 3
    seen = seen or {}
    local spaces = string.rep("  ", indent)
    
    if val == nil then return "nil" end
    local raw_t = type(val)
    local luau_t = (typeof and typeof(val)) or raw_t

    if raw_t == "string" then
        return string.format("%q", val)
    elseif raw_t == "number" or raw_t == "boolean" then
        return tostring(val)
    elseif luau_t == "Instance" then
        local name, cname = "Unknown", "Instance"
        pcall(function() name = val.Name; cname = val.ClassName end)
        return string.format("<Instance: %s (%s)>", name, cname)
    elseif raw_t == "table" then
        if seen[val] then return "<Cycle Table>" end
        seen[val] = true
        if indent >= max_depth then return "{ ... }" end

        local lines = {}
        local count = 0
        local is_array = true
        local max_idx = 0

        for k, _ in pairs(val) do
            count = count + 1
            if type(k) ~= "number" or k <= 0 or math.floor(k) ~= k then
                is_array = false
            else
                if k > max_idx then max_idx = k end
            end
        end

        if is_array and max_idx == count and count > 0 then
            local items = {}
            for i = 1, count do
                if i > 20 then
                    table.insert(items, "... (+" .. (count - 20) .. " items)")
                    break
                end
                table.insert(items, safe_serialize(val[i], indent + 1, max_depth, seen))
            end
            return "[" .. table.concat(items, ", ") .. "]"
        end

        local c = 0
        for k, v in pairs(val) do
            c = c + 1
            if c > 25 then
                table.insert(lines, spaces .. "  ... (truncated)")
                break
            end
            local key_str = type(k) == "string" and k or ("[" .. tostring(k) .. "]")
            local val_str = safe_serialize(v, indent + 1, max_depth, seen)
            table.insert(lines, string.format("%s  %s = %s,", spaces, key_str, val_str))
        end
        if #lines == 0 then return "{}" end
        return "{\n" .. table.concat(lines, "\n") .. "\n" .. spaces .. "}"
    else
        return string.format("<%s: %s>", luau_t, tostring(val))
    end
end

-- UI Callback forward declaration
local add_log_entry = function(...) end

local function record_log(tag, remote_name, details, color)
    if not is_capturing then return end
    
    local now = os.clock()
    local delta_total = now - start_time
    local delta_last = now - last_log_time
    last_log_time = now

    local time_str = string.format("[+%.3fs | Δ%.3fs]", delta_total, delta_last)
    local full_entry = {
        time_str = time_str,
        tag = tag,
        name = remote_name,
        details = details,
        color = color or Color3.fromRGB(220, 220, 220),
        raw_text = string.format("%s [%s] %s\n%s\n", time_str, tag, remote_name, details)
    }

    table.insert(logs_list, full_entry)
    if #logs_list > 500 then
        table.remove(logs_list, 1)
    end

    add_log_entry(full_entry)
end

-- Check if remote is related to Trading
local function is_trade_remote(instance)
    if not instance or typeof(instance) ~= "Instance" then return false end
    local name = instance.Name
    local parent = instance.Parent
    local parent_name = parent and parent.Name or ""

    if string.find(name, "Trading", 1, true) or 
       string.find(name, "Trade", 1, true) or 
       string.find(parent_name, "Trading", 1, true) then
        return true
    end

    return false
end

----------------------------------------------------------------------
-- 1. PURE PASSIVE ASYNC METAMETHOD HOOK
----------------------------------------------------------------------
local function setup_passive_hook()
    local newcclosure = newcclosure or function(f) return f end
    local getnamecallmethod = getnamecallmethod or get_namecall_method
    local getcallingscript = getcallingscript or function() return nil end

    if not hookmetamethod then return end

    local old_namecall
    old_namecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()

        if is_capturing and self and typeof(self) == "Instance" then
            local is_invoke = (method == "InvokeServer" and self:IsA("RemoteFunction"))
            local is_fire = (method == "FireServer" and self:IsA("RemoteEvent"))

            if (is_invoke or is_fire) and is_trade_remote(self) then
                local args = {...}
                local caller = getcallingscript()
                local caller_name = caller and caller:GetFullName() or "External/Script"

                -- Asynchronous logging (Zero impact on game execution)
                task.spawn(function()
                    local arg_dump = {}
                    for i, v in ipairs(args) do
                        table.insert(arg_dump, string.format("  Arg #%d: %s", i, safe_serialize(v, 1, 3)))
                    end
                    local arg_str = #arg_dump > 0 and table.concat(arg_dump, "\n") or "  (No Arguments)"

                    if is_invoke then
                        local detail = string.format("Caller: %s\n[SENT ARGS]:\n%s", caller_name, arg_str)
                        record_log("OUT RF", self.Name, detail, Color3.fromRGB(56, 189, 248))
                    else
                        local detail = string.format("Caller: %s\n[SENT ARGS]:\n%s", caller_name, arg_str)
                        record_log("OUT RE", self.Name, detail, Color3.fromRGB(168, 85, 247))
                    end
                end)
            end
        end

        -- 100% UNTOUCHED ORIGINAL EXECUTION
        return old_namecall(self, ...)
    end))
end

----------------------------------------------------------------------
-- 2. TARGETED INCOMING EVENT SNIFFER (Trade Events Only)
----------------------------------------------------------------------
local attached_events = {}

local function attach_listener(rem)
    if not rem or not rem:IsA("RemoteEvent") or attached_events[rem] then return end
    attached_events[rem] = true

    pcall(function()
        rem.OnClientEvent:Connect(function(...)
            if not is_capturing then return end
            local args = {...}
            
            task.spawn(function()
                local arg_dump = {}
                for i, v in ipairs(args) do
                    table.insert(arg_dump, string.format("  Param #%d: %s", i, safe_serialize(v, 1, 3)))
                end
                local arg_str = #arg_dump > 0 and table.concat(arg_dump, "\n") or "  (No Arguments)"
                local detail = string.format("Path: %s\n[PAYLOAD RECEIVED]:\n%s", rem:GetFullName(), arg_str)

                record_log("IN RE", rem.Name, detail, Color3.fromRGB(34, 197, 94))
            end)
        end)
    end)
end

local function setup_trade_event_listeners()
    -- Scan net folder specifically
    local net_folder = nil
    pcall(function()
        local index = replicated_storage:FindFirstChild("Packages") and replicated_storage.Packages:FindFirstChild("_Index")
        if index then
            for _, child in ipairs(index:GetChildren()) do
                if string.find(child.Name, "sleitnick_net", 1, true) then
                    net_folder = child:FindFirstChild("net")
                    if net_folder then break end
                end
            end
        end
        if not net_folder and replicated_storage:FindFirstChild("Packages") and replicated_storage.Packages:FindFirstChild("_Index") and replicated_storage.Packages._Index:FindFirstChild("sleitnick_net@0.2.0") then
            net_folder = replicated_storage.Packages._Index["sleitnick_net@0.2.0"]:FindFirstChild("net")
        end
    end)

    if net_folder then
        for _, child in ipairs(net_folder:GetChildren()) do
            if child:IsA("RemoteEvent") and is_trade_remote(child) then
                attach_listener(child)
            end
        end
        net_folder.ChildAdded:Connect(function(child)
            if child:IsA("RemoteEvent") and is_trade_remote(child) then
                attach_listener(child)
            end
        end)
    end
end

----------------------------------------------------------------------
-- 3. LOCALPLAYER ATTRIBUTE MONITOR
----------------------------------------------------------------------
local function setup_attribute_watchers()
    if not local_player then return end
    pcall(function()
        local_player.AttributeChanged:Connect(function(attr_name)
            if string.find(string.lower(attr_name), "trade", 1, true) or attr_name == "IsTrading" then
                local val = local_player:GetAttribute(attr_name)
                local detail = string.format("Attribute '%s' = %s", attr_name, safe_serialize(val, 0, 2))
                record_log("STATE ATTR", "LocalPlayer." .. attr_name, detail, Color3.fromRGB(234, 179, 8))
            end
        end)
    end)
end

----------------------------------------------------------------------
-- 4. UNIVERSAL DRAGGABLE GUI
----------------------------------------------------------------------
local function make_draggable(frame, drag_handle)
    drag_handle = drag_handle or frame
    local dragging = false
    local drag_start = nil
    local start_pos = nil

    drag_handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            drag_start = input.Position
            start_pos = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    user_input_service.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - drag_start
            frame.Position = UDim2.new(
                start_pos.X.Scale,
                start_pos.X.Offset + delta.X,
                start_pos.Y.Scale,
                start_pos.Y.Offset + delta.Y
            )
        end
    end)
end

local function build_spy_gui()
    local parent_gui = nil
    if gethui then pcall(function() parent_gui = gethui() end) end
    if not parent_gui and game:GetService("CoreGui") then pcall(function() parent_gui = game:GetService("CoreGui") end) end
    if not parent_gui and local_player then
        parent_gui = local_player:FindFirstChild("PlayerGui") or local_player:WaitForChild("PlayerGui", 3)
    end
    if not parent_gui then return end

    pcall(function()
        for _, c in ipairs(parent_gui:GetChildren()) do
            if c.Name == "FishIt_TradeSpy" then c:Destroy() end
        end
    end)

    local gui = Instance.new("ScreenGui")
    gui.Name = "FishIt_TradeSpy"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 2147483647
    gui.Parent = parent_gui

    -- Main Window
    local main = Instance.new("Frame")
    main.Name = "SpyWindow"
    main.Size = UDim2.new(0, 520, 0, 360)
    main.Position = UDim2.new(0.5, -260, 0.5, -180)
    main.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
    main.BackgroundTransparency = 0
    main.BorderSizePixel = 2
    main.BorderColor3 = Color3.fromRGB(168, 85, 247)
    main.Active = true
    main.Parent = gui

    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 32)
    header.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
    header.BackgroundTransparency = 0
    header.BorderSizePixel = 0
    header.Parent = main

    make_draggable(main, header)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -45, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🕵️‍♂️ Fish It - Passive Trade Spy (Non-Blocking)"
    title.TextColor3 = Color3.fromRGB(245, 245, 245)
    title.TextSize = 13
    title.Font = Enum.Font.SourceSansBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local close_btn = Instance.new("TextButton")
    close_btn.Size = UDim2.new(0, 26, 0, 22)
    close_btn.Position = UDim2.new(1, -30, 0, 5)
    close_btn.BackgroundColor3 = Color3.fromRGB(220, 38, 38)
    close_btn.BackgroundTransparency = 0
    close_btn.Text = "X"
    close_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    close_btn.TextSize = 12
    close_btn.Font = Enum.Font.SourceSansBold
    close_btn.Parent = header
    close_btn.MouseButton1Click:Connect(function() gui:Destroy() end)

    -- Control Bar (Top)
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -16, 0, 32)
    bar.Position = UDim2.new(0, 8, 0, 36)
    bar.BackgroundTransparency = 1
    bar.Parent = main

    local pause_btn = Instance.new("TextButton")
    pause_btn.Size = UDim2.new(0.32, -4, 1, 0)
    pause_btn.Position = UDim2.new(0, 0, 0, 0)
    pause_btn.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
    pause_btn.BackgroundTransparency = 0
    pause_btn.Text = "🟢 REC"
    pause_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    pause_btn.TextSize = 11
    pause_btn.Font = Enum.Font.SourceSansBold
    pause_btn.Parent = bar

    local copy_btn = Instance.new("TextButton")
    copy_btn.Size = UDim2.new(0.38, -4, 1, 0)
    copy_btn.Position = UDim2.new(0.32, 4, 0, 0)
    copy_btn.BackgroundColor3 = Color3.fromRGB(59, 130, 246)
    copy_btn.BackgroundTransparency = 0
    copy_btn.Text = "📋 COPY LOGS"
    copy_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    copy_btn.TextSize = 11
    copy_btn.Font = Enum.Font.SourceSansBold
    copy_btn.Parent = bar

    local clear_btn = Instance.new("TextButton")
    clear_btn.Size = UDim2.new(0.30, -4, 1, 0)
    clear_btn.Position = UDim2.new(0.70, 4, 0, 0)
    clear_btn.BackgroundColor3 = Color3.fromRGB(75, 85, 99)
    clear_btn.BackgroundTransparency = 0
    clear_btn.Text = "🗑️ CLEAR"
    clear_btn.TextColor3 = Color3.fromRGB(240, 240, 240)
    clear_btn.TextSize = 11
    clear_btn.Font = Enum.Font.SourceSansBold
    clear_btn.Parent = bar

    -- Scroll Area
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -16, 1, -76)
    scroll.Position = UDim2.new(0, 8, 0, 72)
    scroll.BackgroundColor3 = Color3.fromRGB(10, 11, 15)
    scroll.BackgroundTransparency = 0
    scroll.BorderSizePixel = 1
    scroll.BorderColor3 = Color3.fromRGB(30, 35, 45)
    scroll.ScrollBarThickness = 5
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = main

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 3)
    layout.Parent = scroll

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 4)
    padding.PaddingLeft = UDim.new(0, 4)
    padding.PaddingRight = UDim.new(0, 4)
    padding.Parent = scroll

    local card_count = 0
    add_log_entry = function(entry)
        if not scroll or not scroll.Parent then return end

        card_count = card_count + 1
        if card_count > 120 then
            local first = scroll:FindFirstChildWhichIsA("Frame")
            if first then first:Destroy(); card_count = card_count - 1 end
        end

        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, -4, 0, 0)
        card.AutomaticSize = Enum.AutomaticSize.Y
        card.BackgroundColor3 = Color3.fromRGB(18, 21, 28)
        card.BackgroundTransparency = 0
        card.BorderSizePixel = 1
        card.BorderColor3 = Color3.fromRGB(35, 40, 52)
        card.Parent = scroll

        local card_pad = Instance.new("UIPadding")
        card_pad.PaddingTop = UDim.new(0, 3)
        card_pad.PaddingBottom = UDim.new(0, 3)
        card_pad.PaddingLeft = UDim.new(0, 5)
        card_pad.PaddingRight = UDim.new(0, 5)
        card_pad.Parent = card

        local header_txt = Instance.new("TextLabel")
        header_txt.Size = UDim2.new(1, 0, 0, 16)
        header_txt.BackgroundTransparency = 1
        header_txt.Font = Enum.Font.SourceSansBold
        header_txt.TextSize = 11
        header_txt.TextXAlignment = Enum.TextXAlignment.Left
        header_txt.TextColor3 = entry.color
        header_txt.Text = string.format("%s [%s] %s", entry.time_str, entry.tag, entry.name)
        header_txt.Parent = card

        local body_txt = Instance.new("TextLabel")
        body_txt.Size = UDim2.new(1, 0, 0, 0)
        body_txt.Position = UDim2.new(0, 0, 0, 16)
        body_txt.AutomaticSize = Enum.AutomaticSize.Y
        body_txt.BackgroundTransparency = 1
        body_txt.Font = Enum.Font.Code
        body_txt.TextSize = 10
        body_txt.TextXAlignment = Enum.TextXAlignment.Left
        body_txt.TextYAlignment = Enum.TextYAlignment.Top
        body_txt.TextColor3 = Color3.fromRGB(205, 210, 220)
        body_txt.TextWrapped = true
        body_txt.Text = entry.details
        body_txt.Parent = card

        task.defer(function()
            scroll.CanvasPosition = Vector2.new(0, 999999)
        end)
    end

    -- Button handlers
    pause_btn.MouseButton1Click:Connect(function()
        is_capturing = not is_capturing
        if is_capturing then
            pause_btn.Text = "🟢 REC"
            pause_btn.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
        else
            pause_btn.Text = "⏸️ PAUSE"
            pause_btn.BackgroundColor3 = Color3.fromRGB(234, 179, 8)
        end
    end)

    copy_btn.MouseButton1Click:Connect(function()
        local all_lines = {
            "==================================================",
            "       FISH IT TRADE BEHAVIOR CAPTURE LOG",
            "       Total Events Recorded: " .. #logs_list,
            "==================================================\n"
        }
        for _, entry in ipairs(logs_list) do
            table.insert(all_lines, entry.raw_text)
            table.insert(all_lines, "--------------------------------------------------")
        end
        local full_text = table.concat(all_lines, "\n")
        
        local success = false
        pcall(function()
            if setclipboard then setclipboard(full_text); success = true end
            if not success and toclipboard then toclipboard(full_text); success = true end
        end)
        pcall(function()
            if writefile then writefile("fishit_trade_spy_dump.txt", full_text) end
        end)

        if success then
            copy_btn.Text = "✅ COPIED!"
            copy_btn.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
        else
            copy_btn.Text = "⚠️ FAILED (SAVED FILE)"
        end
        task.delay(2, function()
            if copy_btn and copy_btn.Parent then
                copy_btn.Text = "📋 COPY LOGS"
                copy_btn.BackgroundColor3 = Color3.fromRGB(59, 130, 246)
            end
        end)
    end)

    clear_btn.MouseButton1Click:Connect(function()
        logs_list = {}
        card_count = 0
        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
        start_time = os.clock()
        last_log_time = os.clock()
    end)

    record_log("SYSTEM", "Spy Active", "Passive Trade Spy aktif.\nSilakan jalankan script Luraph Anda dan lakukan trade.", Color3.fromRGB(240, 240, 240))
end

-- Start cleanly
pcall(setup_passive_hook)
pcall(setup_trade_event_listeners)
pcall(setup_attribute_watchers)
pcall(build_spy_gui)
