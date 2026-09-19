--[[
    Fish It - 7-Point Environment & Data Structure Debugger
    Script ini memeriksa ke-7 poin secara non-blocking (aman, tidak akan freeze/hang).
    UI langsung muncul dengan tombol Copy dan Re-Dump.
--]]

local cloneref = cloneref or function(ref) return ref end
local players = cloneref(game:GetService("Players"))
local replicated_storage = cloneref(game:GetService("ReplicatedStorage"))
local user_input_service = cloneref(game:GetService("UserInputService"))
local tween_service = cloneref(game:GetService("TweenService"))

local text_chat_service = nil
pcall(function() text_chat_service = cloneref(game:GetService("TextChatService")) end)

local local_player = players.LocalPlayer
if not local_player then
    pcall(function()
        local_player = players.LocalPlayer or players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    end)
end

local logs = {}
local function log(str)
    table.insert(logs, tostring(str))
end

local function safe_serialize(val, indent, max_depth, seen)
    indent = indent or 0
    max_depth = max_depth or 3
    seen = seen or {}
    local spaces = string.rep("  ", indent)

    local vtype = type(val)
    if vtype == "string" then
        return string.format("%q", val)
    elseif vtype == "number" or vtype == "boolean" or vtype == "nil" then
        return tostring(val)
    elseif typeof and typeof(val) == "Instance" then
        return string.format("<Instance: %s (%s)>", val.Name, val.ClassName)
    elseif vtype == "table" then
        if seen[val] then return "<Cycle Table>" end
        seen[val] = true
        if indent >= max_depth then return "{ ... }" end

        local lines = {}
        local count = 0
        for k, v in pairs(val) do
            count = count + 1
            if count > 40 then
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
        return string.format("<%s: %s>", vtype, tostring(val))
    end
end

local function run_inspection()
    logs = {}
    log("==================================================")
    log("       FISH IT 7-POINT COMPREHENSIVE DEBUG DUMP   ")
    log("       Player: " .. (local_player and local_player.Name or "Unknown"))
    log("       Time: " .. os.date("!%Y-%m-%d %H:%M:%SZ"))
    log("==================================================\n")

    -- Setup Module Requires safely
    local replion_mod = nil
    pcall(function()
        local replion_pkg = (replicated_storage:FindFirstChild("Packages") and replicated_storage.Packages:FindFirstChild("Replion"))
            or replicated_storage:FindFirstChild("Replion", true)
        if replion_pkg then
            replion_mod = require(replion_pkg)
        end
    end)

    local player_data = nil
    if replion_mod and replion_mod.Client then
        pcall(function()
            if replion_mod.Client.GetReplion then
                player_data = replion_mod.Client:GetReplion("Data") or replion_mod.Client:GetReplion("PlayerData")
            end
            if not player_data and replion_mod.Client.Replions then
                player_data = replion_mod.Client.Replions["Data"] or replion_mod.Client.Replions["PlayerData"]
            end
        end)
    end

    local item_utility = nil
    pcall(function()
        local iu_pkg = (replicated_storage:FindFirstChild("Shared") and replicated_storage.Shared:FindFirstChild("ItemUtility"))
            or replicated_storage:FindFirstChild("ItemUtility", true)
        if iu_pkg then item_utility = require(iu_pkg) end
    end)

    local vendor_utility = nil
    pcall(function()
        local vu_pkg = (replicated_storage:FindFirstChild("Shared") and replicated_storage.Shared:FindFirstChild("VendorUtility"))
            or replicated_storage:FindFirstChild("VendorUtility", true)
        if vu_pkg then vendor_utility = require(vu_pkg) end
    end)

    local inventory = nil
    if player_data then
        pcall(function() inventory = player_data:Get("Inventory") end)
    end
    local items = (inventory and inventory.Items) or {}
    log(string.format("PlayerData Replion Found: %s | Total Bag Items: %d", tostring(player_data ~= nil), #items))

    -------------------------------------------------------
    -- [POINT 1] HARGA JUAL KOIN IKAN (ItemUtility & VendorUtility)
    -------------------------------------------------------
    log("\n==================================================")
    log("[POINT 1] HARGA JUAL KOIN IKAN (ItemUtility & VendorUtility)")
    log("==================================================")
    log("ItemUtility Available: " .. tostring(item_utility ~= nil))
    log("VendorUtility Available: " .. tostring(vendor_utility ~= nil))
    if vendor_utility then
        log("VendorUtility Methods: " .. safe_serialize(vendor_utility, 1, 2))
    end

    local fish_tested = 0
    for _, itm in ipairs(items) do
        local data = item_utility and itm.Id and item_utility:GetItemData(itm.Id)
        if data and data.Data and data.Data.Type == "Fish" then
            fish_tested = fish_tested + 1
            log(string.format("\n--- Sample Fish #%d: %s (UUID: %s) ---", fish_tested, tostring(data.Data.Name), tostring(itm.UUID)))
            log("Inventory Item Data: " .. safe_serialize(itm, 1, 3))
            log("ItemUtility:GetItemData(Id): " .. safe_serialize(data, 1, 3))
            if vendor_utility then
                local ok1, val1 = pcall(function() return vendor_utility:GetSellPrice(itm) end)
                local ok2, val2 = pcall(function() return vendor_utility.GetSellPrice(itm) end)
                local ok3, val3 = pcall(function() return vendor_utility:GetPrice(itm) end)
                log(string.format("  vendor_utility:GetSellPrice(itm) => ok:%s, val:%s", tostring(ok1), tostring(val1)))
                log(string.format("  vendor_utility.GetSellPrice(itm)  => ok:%s, val:%s", tostring(ok2), tostring(val2)))
                log(string.format("  vendor_utility:GetPrice(itm)     => ok:%s, val:%s", tostring(ok3), tostring(val3)))
            end
            if fish_tested >= 3 then break end
        end
    end
    if fish_tested == 0 then log("No fish found in bag to test price calculation.") end

    -------------------------------------------------------
    -- [POINT 2] REMOTES & KATEGORI AddItem
    -------------------------------------------------------
    log("\n==================================================")
    log("[POINT 2] REMOTES & KATEGORI AddItem")
    log("==================================================")
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
        log("Net Folder Path: " .. net_folder:GetFullName())
        for _, child in ipairs(net_folder:GetChildren()) do
            local lname = string.lower(child.Name)
            if string.find(lname, "trade", 1, true) or string.find(child.Name, "AddItem", 1, true) or string.find(child.Name, "SetReady", 1, true) or string.find(child.Name, "Confirm", 1, true) then
                log(string.format("  Remote: %s [%s]", child.Name, child.ClassName))
            end
        end
    else
        log("Net Folder: NOT FOUND")
    end

    -------------------------------------------------------
    -- [POINT 3] METADATA MUTASI / VARIAN IKAN
    -------------------------------------------------------
    log("\n==================================================")
    log("[POINT 3] METADATA MUTASI / VARIAN IKAN")
    log("==================================================")
    local variants_folder = replicated_storage:FindFirstChild("Variants")
    if variants_folder then
        log("Variants Folder Found with " .. #variants_folder:GetChildren() .. " variant modules:")
        local var_names = {}
        local sample_vars = {}
        for idx, v in ipairs(variants_folder:GetChildren()) do
            table.insert(var_names, v.Name)
            if idx <= 3 and v:IsA("ModuleScript") then
                local ok, d = pcall(require, v)
                if ok then sample_vars[v.Name] = d end
            end
        end
        log("All Variant Names: " .. table.concat(var_names, ", "))
        log("Sample Variant Modules (First 3): " .. safe_serialize(sample_vars, 1, 3))
    else
        log("Variants Folder: NOT FOUND")
    end

    local tiers_mod = replicated_storage:FindFirstChild("Tiers")
    if tiers_mod and tiers_mod:IsA("ModuleScript") then
        local ok, data = pcall(require, tiers_mod)
        log("Tiers Module: " .. (ok and safe_serialize(data, 1, 3) or "Error: " .. tostring(data)))
    else
        log("Tiers Module: NOT FOUND")
    end

    local metadata_keys = {}
    for _, itm in ipairs(items) do
        if itm.Metadata and type(itm.Metadata) == "table" then
            for k, _ in pairs(itm.Metadata) do
                metadata_keys[k] = (metadata_keys[k] or 0) + 1
            end
        end
    end
    log("All Metadata Keys in Current Bag Items: " .. safe_serialize(metadata_keys, 1, 2))

    -------------------------------------------------------
    -- [POINT 4] METADATA SHINY & BIG / GIANT / SPARKLING
    -------------------------------------------------------
    log("\n==================================================")
    log("[POINT 4] METADATA SHINY & BIG / GIANT / SPARKLING")
    log("==================================================")
    local shiny_list = {}
    local big_list = {}
    for _, itm in ipairs(items) do
        local is_s = itm.Shiny or (itm.Metadata and (itm.Metadata.Shiny or (itm.Metadata.VariantId and string.find(string.lower(tostring(itm.Metadata.VariantId)), "shiny"))))
        local is_b = itm.Big or itm.Giant or (itm.Metadata and (itm.Metadata.Big or itm.Metadata.Giant or (itm.Metadata.VariantId and string.find(string.lower(tostring(itm.Metadata.VariantId)), "big"))))
        if is_s and #shiny_list < 2 then table.insert(shiny_list, itm) end
        if is_b and #big_list < 2 then table.insert(big_list, itm) end
    end
    log("Sample Shiny Items in Bag: " .. safe_serialize(shiny_list, 1, 3))
    log("Sample Big/Giant Items in Bag: " .. safe_serialize(big_list, 1, 3))

    -------------------------------------------------------
    -- [POINT 5] TIPE ENCHANT STONES
    -------------------------------------------------------
    log("\n==================================================")
    log("[POINT 5] TIPE ENCHANT STONES (Data.Type & Item Names)")
    log("==================================================")
    local enchant_list = {}
    for _, itm in ipairs(items) do
        local data = item_utility and itm.Id and item_utility:GetItemData(itm.Id)
        if data and data.Data then
            local name = tostring(data.Data.Name)
            local itype = tostring(data.Data.Type)
            if string.find(name, "Enchant") or string.find(itype, "Enchant") then
                table.insert(enchant_list, {
                    Id = itm.Id,
                    UUID = itm.UUID,
                    Name = name,
                    Type = itype,
                    Data = data.Data
                })
                if #enchant_list >= 3 then break end
            end
        end
    end
    log("Sample Enchant Stones in Bag: " .. safe_serialize(enchant_list, 1, 3))

    -------------------------------------------------------
    -- [POINT 6] TARGET PLAYER RESOLUTION (Username vs DisplayName)
    -------------------------------------------------------
    log("\n==================================================")
    log("[POINT 6] TARGET PLAYER RESOLUTION (Players in Server)")
    log("==================================================")
    local ply_list = {}
    for _, p in ipairs(players:GetPlayers()) do
        table.insert(ply_list, {
            Name = p.Name,
            DisplayName = p.DisplayName,
            UserId = p.UserId,
            IsLocalPlayer = (p == local_player)
        })
    end
    log("Players in Server: " .. safe_serialize(ply_list, 1, 3))

    -------------------------------------------------------
    -- [POINT 7] DETEKSI TRADE COMPLETION & CHAT / ATTRIBUTES
    -------------------------------------------------------
    log("\n==================================================")
    log("[POINT 7] DETEKSI TRADE COMPLETION & CHAT / ATTRIBUTES")
    log("==================================================")
    log("LocalPlayer Attributes: " .. safe_serialize(local_player:GetAttributes(), 1, 2))
    log("TextChatService Available: " .. tostring(text_chat_service ~= nil))
    if text_chat_service then
        local channels = text_chat_service:FindFirstChild("TextChannels")
        if channels then
            local ch_names = {}
            for _, c in ipairs(channels:GetChildren()) do table.insert(ch_names, c.Name) end
            log("TextChannels List: " .. table.concat(ch_names, ", "))
        end
    end
    local legacy_chat = replicated_storage:FindFirstChild("DefaultChatSystemChatEvents")
    log("Legacy Chat Events Available: " .. tostring(legacy_chat ~= nil))

    log("\n==================================================")
    log("               END OF 7-POINT DUMP                ")
    log("==================================================")

    return table.concat(logs, "\n")
end

-- UI CREATION
local function create_ui()
    local parent_gui = (gethui and pcall(gethui) and gethui()) or game:GetService("CoreGui") or local_player:WaitForChild("PlayerGui")
    local old = parent_gui:FindFirstChild("FishIt_DebugDump")
    if old then pcall(function() old:Destroy() end) end

    local gui = Instance.new("ScreenGui")
    gui.Name = "FishIt_DebugDump"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 2147483647
    gui.Parent = parent_gui

    -- Main Container Frame
    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 600, 0, 460)
    frame.Position = UDim2.new(0.5, -300, 0.5, -230)
    frame.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
    frame.BackgroundTransparency = 0
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.ZIndex = 10
    frame.Parent = gui

    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 8); corner.Parent = frame
    local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(168, 85, 247); stroke.Thickness = 1.5; stroke.Parent = frame

    -- Top Header Bar
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 34)
    header.BackgroundColor3 = Color3.fromRGB(15, 16, 20)
    header.BorderSizePixel = 0
    header.ZIndex = 11
    header.Parent = frame

    local h_corner = Instance.new("UICorner"); h_corner.CornerRadius = UDim.new(0, 8); h_corner.Parent = header

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -100, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Fish It 7-Point Environment & Data Debugger"
    title.TextColor3 = Color3.fromRGB(240, 240, 240)
    title.TextSize = 13
    title.Font = Enum.Font.SourceSansBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 12
    title.Parent = header

    -- Header Dragging
    local dragging, drag_start, start_pos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; drag_start = input.Position; start_pos = frame.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    user_input_service.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - drag_start
            frame.Position = UDim2.new(start_pos.X.Scale, start_pos.X.Offset + delta.X, start_pos.Y.Scale, start_pos.Y.Offset + delta.Y)
        end
    end)

    -- Close Button
    local close_btn = Instance.new("TextButton")
    close_btn.Size = UDim2.new(0, 26, 0, 26)
    close_btn.Position = UDim2.new(1, -30, 0.5, -13)
    close_btn.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
    close_btn.Text = "✕"
    close_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    close_btn.TextSize = 12
    close_btn.Font = Enum.Font.SourceSansBold
    close_btn.ZIndex = 12
    close_btn.Parent = header
    local cb_corner = Instance.new("UICorner"); cb_corner.CornerRadius = UDim.new(0, 4); cb_corner.Parent = close_btn
    close_btn.MouseButton1Click:Connect(function() gui:Destroy() end)

    -- Scrolling Frame for Output
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "OutputScroll"
    scroll.Size = UDim2.new(1, -20, 1, -90)
    scroll.Position = UDim2.new(0, 10, 0, 42)
    scroll.BackgroundColor3 = Color3.fromRGB(12, 13, 16)
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 6
    scroll.ScrollBarImageColor3 = Color3.fromRGB(168, 85, 247)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticCanvasSize.Y
    scroll.ZIndex = 11
    scroll.Parent = frame

    local s_corner = Instance.new("UICorner"); s_corner.CornerRadius = UDim.new(0, 6); s_corner.Parent = scroll
    local s_stroke = Instance.new("UIStroke"); s_stroke.Color = Color3.fromRGB(45, 48, 55); s_stroke.Thickness = 1; s_stroke.Parent = scroll

    local text_box = Instance.new("TextBox")
    text_box.Name = "OutputTextBox"
    text_box.Size = UDim2.new(1, -16, 1, -16)
    text_box.Position = UDim2.new(0, 8, 0, 8)
    text_box.BackgroundTransparency = 1
    text_box.TextColor3 = Color3.fromRGB(220, 225, 235)
    text_box.TextSize = 11
    text_box.Font = Enum.Font.Code
    text_box.TextXAlignment = Enum.TextXAlignment.Left
    text_box.TextYAlignment = Enum.TextYAlignment.Top
    text_box.ClearTextOnFocus = false
    text_box.TextEditable = false
    text_box.MultiLine = true
    text_box.TextWrapped = false
    text_box.AutomaticSize = Enum.AutomaticSize.XY
    text_box.Text = "Please wait, scanning game data..."
    text_box.ZIndex = 12
    text_box.Parent = scroll

    -- Bottom Button Bar
    local btn_container = Instance.new("Frame")
    btn_container.Name = "ButtonContainer"
    btn_container.Size = UDim2.new(1, -20, 0, 36)
    btn_container.Position = UDim2.new(0, 10, 1, -42)
    btn_container.BackgroundTransparency = 1
    btn_container.ZIndex = 11
    btn_container.Parent = frame

    local copy_btn = Instance.new("TextButton")
    copy_btn.Name = "CopyButton"
    copy_btn.Size = UDim2.new(0.68, -6, 1, 0)
    copy_btn.Position = UDim2.new(0, 0, 0, 0)
    copy_btn.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
    copy_btn.Text = "📋 Copy Output to Clipboard"
    copy_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    copy_btn.TextSize = 13
    copy_btn.Font = Enum.Font.SourceSansBold
    copy_btn.ZIndex = 12
    copy_btn.Parent = btn_container
    local cp_corner = Instance.new("UICorner"); cp_corner.CornerRadius = UDim.new(0, 6); cp_corner.Parent = copy_btn

    local refresh_btn = Instance.new("TextButton")
    refresh_btn.Name = "RefreshButton"
    refresh_btn.Size = UDim2.new(0.32, -6, 1, 0)
    refresh_btn.Position = UDim2.new(0.68, 6, 0, 0)
    refresh_btn.BackgroundColor3 = Color3.fromRGB(45, 50, 60)
    refresh_btn.Text = "🔄 Re-Dump"
    refresh_btn.TextColor3 = Color3.fromRGB(230, 235, 245)
    refresh_btn.TextSize = 13
    refresh_btn.Font = Enum.Font.SourceSansBold
    refresh_btn.ZIndex = 12
    refresh_btn.Parent = btn_container
    local rf_corner = Instance.new("UICorner"); rf_corner.CornerRadius = UDim.new(0, 6); rf_corner.Parent = refresh_btn

    local current_output = ""
    local is_dumping = false

    local function execute_dump()
        if is_dumping then return end
        is_dumping = true
        text_box.Text = "Scanning all 7 points in environment & inventory..."
        copy_btn.Text = "⏳ Scanning data..."
        task.wait(0.1)

        task.spawn(function()
            local success, result = pcall(run_inspection)
            if success and result then
                current_output = result
                text_box.Text = current_output
                copy_btn.Text = "📋 Copy Output to Clipboard"
                -- Auto copy immediately for convenience
                if setclipboard then pcall(setclipboard, current_output) end
            else
                current_output = "Error during inspection: " .. tostring(result)
                text_box.Text = current_output
                copy_btn.Text = "⚠️ Error - Click to Retry"
            end
            is_dumping = false
        end)
    end

    copy_btn.MouseButton1Click:Connect(function()
        if current_output == "" or is_dumping then return end
        if setclipboard then
            pcall(setclipboard, current_output)
            copy_btn.Text = "✅ Copied to Clipboard!"
        elseif toclipboard then
            pcall(toclipboard, current_output)
            copy_btn.Text = "✅ Copied to Clipboard!"
        else
            copy_btn.Text = "⚠️ setclipboard not available"
        end
        task.delay(2.5, function()
            if copy_btn and copy_btn.Parent then
                copy_btn.Text = "📋 Copy Output to Clipboard"
            end
        end)
    end)

    refresh_btn.MouseButton1Click:Connect(function()
        execute_dump()
    end)

    -- Run initial dump asynchronously
    task.spawn(execute_dump)
end

pcall(create_ui)
