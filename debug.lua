--[[
    Fish It - 7-Point Environment & Data Debugger (Bulletproof Auto-Copier)
    Fitur:
    1. Langsung jalan otomatis saat di-execute.
    2. Auto-copy output ke clipboard (setclipboard / toclipboard).
    3. Auto-save ke file 'fishit_debug_dump.txt' jika executor support writefile.
    4. Print ke console executor.
    5. UI simpel, stabil, ada tombol COPY dan status jelas.
--]]

local cloneref = cloneref or function(ref) return ref end
local players = cloneref(game:GetService("Players"))
local replicated_storage = cloneref(game:GetService("ReplicatedStorage"))
local user_input_service = cloneref(game:GetService("UserInputService"))

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
            if count > 25 then
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
        if replion_pkg then replion_mod = require(replion_pkg) end
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
                log(string.format("  Net Remote: %s [%s]", child.Name, child.ClassName))
            end
        end
    else
        log("Net Folder: NOT FOUND")
    end

    -- Scan seluruh ReplicatedStorage untuk Remote Trade apapun
    log("\n--- Seluruh Remote Terkait Trade di ReplicatedStorage ---")
    local found_remotes = 0
    pcall(function()
        for _, obj in ipairs(replicated_storage:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent") then
                local lname = string.lower(obj.Name)
                if string.find(lname, "trade") or string.find(lname, "offer") or string.find(lname, "invite") then
                    found_remotes = found_remotes + 1
                    log(string.format("  [%s] %s -> %s", obj.ClassName, obj.Name, obj:GetFullName()))
                end
            end
        end
    end)
    if found_remotes == 0 then log("  Tidak ada remote lain bertuliskan trade/offer/invite di luar Net.") end

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

    local final_str = table.concat(logs, "\n")

    -- AUTO-COPY KE CLIPBOARD
    pcall(function()
        if setclipboard then
            setclipboard(final_str)
        elseif toclipboard then
            toclipboard(final_str)
        end
    end)

    -- AUTO-SAVE KE FILE JIKA BISA
    pcall(function()
        if writefile then
            writefile("fishit_debug_dump.txt", final_str)
        end
    end)

    -- PRINT KE EXECUTOR CONSOLE
    pcall(function()
        print(final_str)
    end)

    return final_str
end

local live_text_label = nil

-- UI Builder
local function build_gui()
    local parent_gui = nil
    if gethui then pcall(function() parent_gui = gethui() end) end
    if not parent_gui and game:GetService("CoreGui") then pcall(function() parent_gui = game:GetService("CoreGui") end) end
    if not parent_gui and local_player then
        parent_gui = local_player:FindFirstChild("PlayerGui") or local_player:WaitForChild("PlayerGui", 3)
    end
    if not parent_gui then return end

    pcall(function()
        for _, c in ipairs(parent_gui:GetChildren()) do
            if c.Name == "FishIt_DebugDump" then c:Destroy() end
        end
    end)

    local gui = Instance.new("ScreenGui")
    gui.Name = "FishIt_DebugDump"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 2147483647
    gui.Parent = parent_gui

    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 520, 0, 360)
    frame.Position = UDim2.new(0.5, -260, 0.5, -180)
    frame.BackgroundColor3 = Color3.fromRGB(18, 20, 24)
    frame.BorderSizePixel = 2
    frame.BorderColor3 = Color3.fromRGB(168, 85, 247)
    frame.Active = true
    frame.Parent = gui

    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 32)
    header.BackgroundColor3 = Color3.fromRGB(10, 12, 15)
    header.BorderSizePixel = 0
    header.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "⚡ Fish It 7-Point Auto-Debugger"
    title.TextColor3 = Color3.fromRGB(240, 240, 240)
    title.TextSize = 13
    title.Font = Enum.Font.SourceSansBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local close_btn = Instance.new("TextButton")
    close_btn.Size = UDim2.new(0, 28, 0, 24)
    close_btn.Position = UDim2.new(1, -32, 0, 4)
    close_btn.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
    close_btn.Text = "X"
    close_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    close_btn.TextSize = 12
    close_btn.Font = Enum.Font.SourceSansBold
    close_btn.Parent = header
    close_btn.MouseButton1Click:Connect(function() gui:Destroy() end)

    local minimize_btn = Instance.new("TextButton")
    minimize_btn.Size = UDim2.new(0, 28, 0, 24)
    minimize_btn.Position = UDim2.new(1, -64, 0, 4)
    minimize_btn.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
    minimize_btn.Text = "-"
    minimize_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minimize_btn.TextSize = 14
    minimize_btn.Font = Enum.Font.SourceSansBold
    minimize_btn.Parent = header

    -- Action Bar (TOP)
    local action_frame = Instance.new("Frame")
    action_frame.Size = UDim2.new(1, -16, 0, 36)
    action_frame.Position = UDim2.new(0, 8, 0, 38)
    action_frame.BackgroundTransparency = 1
    action_frame.Parent = frame

    local test_btn = Instance.new("TextButton")
    test_btn.Size = UDim2.new(0.35, -4, 1, 0)
    test_btn.Position = UDim2.new(0, 0, 0, 0)
    test_btn.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
    test_btn.Text = "🚀 TEST KIRIM OFFER"
    test_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    test_btn.TextSize = 11
    test_btn.Font = Enum.Font.SourceSansBold
    test_btn.Parent = action_frame

    local copy_btn = Instance.new("TextButton")
    copy_btn.Size = UDim2.new(0.42, -4, 1, 0)
    copy_btn.Position = UDim2.new(0.35, 4, 0, 0)
    copy_btn.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
    copy_btn.Text = "📋 COPY OUTPUT"
    copy_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    copy_btn.TextSize = 11
    copy_btn.Font = Enum.Font.SourceSansBold
    copy_btn.Parent = action_frame

    local refresh_btn = Instance.new("TextButton")
    refresh_btn.Size = UDim2.new(0.23, -4, 1, 0)
    refresh_btn.Position = UDim2.new(0.77, 4, 0, 0)
    refresh_btn.BackgroundColor3 = Color3.fromRGB(45, 50, 60)
    refresh_btn.Text = "🔄 SCAN"
    refresh_btn.TextColor3 = Color3.fromRGB(240, 240, 240)
    refresh_btn.TextSize = 11
    refresh_btn.Font = Enum.Font.SourceSansBold
    refresh_btn.Parent = action_frame

    -- Scroll Box
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -16, 1, -82)
    scroll.Position = UDim2.new(0, 8, 0, 78)
    scroll.BackgroundColor3 = Color3.fromRGB(10, 11, 14)
    scroll.BorderSizePixel = 1
    scroll.BorderColor3 = Color3.fromRGB(35, 38, 45)
    scroll.ScrollBarThickness = 6
    scroll.CanvasSize = UDim2.new(0, 0, 0, 12000)
    scroll.Parent = frame

    local text_lbl = Instance.new("TextLabel")
    text_lbl.Size = UDim2.new(1, -10, 1, 0)
    text_lbl.Position = UDim2.new(0, 5, 0, 5)
    text_lbl.BackgroundTransparency = 1
    text_lbl.TextColor3 = Color3.fromRGB(220, 225, 235)
    text_lbl.TextSize = 11
    text_lbl.Font = Enum.Font.SourceSans
    text_lbl.TextXAlignment = Enum.TextXAlignment.Left
    text_lbl.TextYAlignment = Enum.TextYAlignment.Top
    text_lbl.TextWrapped = true
    text_lbl.Text = "🟢 LIVE SPY AKTIF & STANDBY\n--------------------------------------------------\nScript sedang standby dan diam.\n\nSilakan buka menu Trade di Roblox dan lakukan trade manual.\nSetiap Remote yang dipanggil akan otomatis tercatat di bawah ini secara real-time!\n--------------------------------------------------"
    text_lbl.Parent = scroll
    live_text_label = text_lbl
    
    local is_minimized = false
    minimize_btn.MouseButton1Click:Connect(function()
        is_minimized = not is_minimized
        if is_minimized then
            frame.Size = UDim2.new(0, 520, 0, 32)
            action_frame.Visible = false
            scroll.Visible = false
            minimize_btn.Text = "+"
        else
            frame.Size = UDim2.new(0, 520, 0, 360)
            action_frame.Visible = true
            scroll.Visible = true
            minimize_btn.Text = "-"
        end
    end)

    local current_text = ""

    local function copy_action()
        local full_out = (#spy_logs > 0 and table.concat(spy_logs, "\n\n") or current_text)
        if full_out == "" then full_out = text_lbl.Text end
        local done = false
        pcall(function()
            if setclipboard then setclipboard(full_out); done = true end
            if not done and toclipboard then toclipboard(full_out); done = true end
        end)
        if done then
            copy_btn.Text = "✅ BERHASIL DI-COPY!"
            copy_btn.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
        else
            copy_btn.Text = "⚠️ Gagal API Clipboard"
        end
        task.delay(2.5, function()
            if copy_btn and copy_btn.Parent then
                copy_btn.Text = "📋 COPY OUTPUT"
                copy_btn.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
            end
        end)
    end

    local function execute_scan()
        text_lbl.Text = "⏳ Sedang menjalankan scan data 7-point..."
        refresh_btn.Text = "⏳ Scan..."
        task.spawn(function()
            local ok, res = pcall(run_inspection)
            if ok and res then
                current_text = res
                text_lbl.Text = current_text
                refresh_btn.Text = "✅ SELESAI"
                refresh_btn.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
                pcall(function()
                    if setclipboard then setclipboard(current_text)
                    elseif toclipboard then toclipboard(current_text) end
                end)
                task.delay(3, function()
                    if refresh_btn and refresh_btn.Parent then
                        refresh_btn.Text = "🔄 SCAN DATA"
                        refresh_btn.BackgroundColor3 = Color3.fromRGB(45, 50, 60)
                    end
                end)
            else
                current_text = "Error saat dump: " .. tostring(res)
                text_lbl.Text = current_text
                refresh_btn.Text = "❌ Gagal"
            end
        end)
    end

    local function execute_remote_test()
        text_lbl.Text = "🧪 SEDANG MENGETES SEMUA REMOTE TRADE...\n"
        test_btn.Text = "⏳ Testing..."
        task.spawn(function()
            local target_p = nil
            for _, p in ipairs(players:GetPlayers()) do
                if p ~= local_player then target_p = p; break end
            end
            if not target_p then
                local msg = "❌ Gagal Test: Tidak ada player lain di server!"
                text_lbl.Text = msg
                test_btn.Text = "❌ No Player"
                return
            end

            local test_logs = {}
            local function tlog(s) table.insert(test_logs, tostring(s)) end
            tlog("==========================================")
            tlog(string.format("🧪 HASIL TEST REMOTE KE: %s (%d)", target_p.Name, target_p.UserId))
            tlog("==========================================")

            local net = nil
            pcall(function()
                net = replicated_storage.Packages._Index["sleitnick_net@0.2.0"].net
            end)

            -- 1. Test Remote Asli dari TradeData.Remotes
            tlog("\n🎯 MENGETES REMOTE ASLI DARI TradeData.Remotes:")
            local trade_data_mod = replicated_storage:FindFirstChild("Shared") and replicated_storage.Shared:FindFirstChild("Trading") and replicated_storage.Shared.Trading:FindFirstChild("TradeData")
            local trade_data = nil
            if trade_data_mod then
                local ok, td = pcall(require, trade_data_mod)
                if ok and type(td) == "table" then trade_data = td end
            end

            if trade_data and trade_data.Remotes and trade_data.Remotes.SendTradeOffer then
                local real_send_offer = trade_data.Remotes.SendTradeOffer
                tlog("  Real SendTradeOffer Remote: " .. real_send_offer.Name .. " (" .. real_send_offer:GetFullName() .. ")")
                
                -- Test panggil remote asli dengan target_p
                local ok, res = pcall(function() return real_send_offer:InvokeServer(target_p) end)
                tlog(string.format("  👉 HASIL INVOKE REMOTE ASLI: ok=%s, result=%s", tostring(ok), safe_serialize(res, 1, 2)))
                if ok and res ~= false then
                    tlog("  ✅ BERHASIL MENGIRIM! CEK POPUP DI AKUN TARGET SEKARANG!")
                end
            else
                tlog("  ❌ TradeData.Remotes.SendTradeOffer tidak ditemukan!")
            end

            -- 4. Deep Inspection pada TradeData & TradeOfferController
            tlog("\n==========================================")
            tlog("🔍 DEEP INSPECTION: TradeData & Controllers")
            tlog("==========================================")
            
            local trade_data_mod = replicated_storage:FindFirstChild("Shared") and replicated_storage.Shared:FindFirstChild("Trading") and replicated_storage.Shared.Trading:FindFirstChild("TradeData")
            if trade_data_mod then
                local ok, td = pcall(require, trade_data_mod)
                if ok and type(td) == "table" then
                    tlog("TradeData Contents: " .. safe_serialize(td, 1, 2))
                    if td.Remotes then
                        tlog("TradeData.Remotes: " .. safe_serialize(td.Remotes, 1, 2))
                    end
                    if td.CanTradeEachother then
                        local ok_c, res_c = pcall(function() return td.CanTradeEachother(local_player, target_p) end)
                        tlog(string.format("TradeData.CanTradeEachother(Local, Target) => ok:%s, result:%s", tostring(ok_c), safe_serialize(res_c, 1, 2)))
                    end
                end
            end

            -- 4. Deep Inspection pada TradeOfferController & Popup
            tlog("\n==========================================")
            tlog("🔍 DEEP INSPECTION: TradeOfferController & PopUp")
            tlog("==========================================")
            
            local offer_ctrl_mod = replicated_storage:FindFirstChild("Controllers") and replicated_storage.Controllers:FindFirstChild("Trading") and replicated_storage.Controllers.Trading:FindFirstChild("TradeOfferController")
            if offer_ctrl_mod then
                local ok, toc = pcall(require, offer_ctrl_mod)
                if ok and type(toc) == "table" then
                    tlog("TradeOfferController Keys: " .. safe_serialize(toc, 1, 2))
                    
                    for fname, fval in pairs(toc) do
                        if type(fval) == "function" then
                            local consts = getconstants and getconstants(fval) or {}
                            local upvals = getupvalues and getupvalues(fval) or {}
                            tlog(string.format("\n  ▶ Function: %s", fname))
                            tlog(string.format("     Constants: %s", safe_serialize(consts, 1, 4)))
                            tlog(string.format("     Upvalues:  %s", safe_serialize(upvals, 1, 4)))
                        end
                    end

                    -- Test jalankan PopUp langsung untuk melihat respon
                    tlog("\n  👉 TEST PANGGIL TradeOfferController:PopUp(Target):")
                    local ok_pop, res_pop = pcall(function()
                        if toc.PopUp then return toc:PopUp(target_p) end
                    end)
                    tlog(string.format("     Result => ok:%s, res:%s", tostring(ok_pop), safe_serialize(res_pop, 1, 2)))
                else
                    tlog("❌ Gagal require TradeOfferController: " .. tostring(toc))
                end
            else
                tlog("❌ TradeOfferController ModuleScript NOT FOUND")
            end

            -- 5. Scan Seluruh PlayerGui mencari Popup [Yes] / [No] / "Trade request"
            tlog("\n--- Pencarian Dialog Popup di PlayerGui ---")
            local pgui = local_player:FindFirstChild("PlayerGui")
            local found_popups = 0
            if pgui then
                for _, obj in ipairs(pgui:GetDescendants()) do
                    if obj:IsA("GuiObject") then
                        local text = (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Text or ""
                        local lower_t = string.lower(text)
                        local lower_n = string.lower(obj.Name)
                        if string.find(lower_t, "trade request") or string.find(lower_t, "accept") or string.find(lower_n, "popup") or string.find(lower_n, "prompt") or text == "Yes" or text == "No" then
                            found_popups = found_popups + 1
                            tlog(string.format("  Popup Element #%d: %s [%s] -> Parent: %s | Visible: %s", found_popups, obj.Name, obj.ClassName, obj.Parent and obj.Parent:GetFullName() or "None", tostring(obj.Visible)))
                            if text ~= "" then tlog(string.format("    Text: %q", text)) end
                            if obj:IsA("GuiButton") and getconnections then
                                local c_click = getconnections(obj.MouseButton1Click)
                                local c_act = getconnections(obj.Activated)
                                tlog(string.format("    Connections: MouseButton1Click=%d, Activated=%d", #c_click, #c_act))
                                for i, c in ipairs(c_act) do
                                    if c.Function and getconstants then
                                        tlog(string.format("      Activated #%d Constants: %s", i, safe_serialize(getconstants(c.Function), 1, 2)))
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if found_popups == 0 then tlog("  Tidak ada dialog popup yang sedang aktif di PlayerGui.") end

            tlog("\n[Cek Akun Target]: Apakah popup trade request muncul di akun target saat tombol ini ditekan?")
            tlog("==========================================")

            local res_text = table.concat(test_logs, "\n")
            current_text = res_text
            text_lbl.Text = res_text
            test_btn.Text = "✅ TEST SELESAI"
            test_btn.BackgroundColor3 = Color3.fromRGB(34, 197, 94)

            pcall(function()
                if setclipboard then setclipboard(res_text)
                elseif toclipboard then toclipboard(res_text) end
            end)

            task.delay(3, function()
                if test_btn and test_btn.Parent then
                    test_btn.Text = "🚀 TEST KIRIM OFFER"
                    test_btn.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
                end
            end)
        end)
    end

    test_btn.MouseButton1Click:Connect(execute_remote_test)
    copy_btn.MouseButton1Click:Connect(copy_action)
    refresh_btn.MouseButton1Click:Connect(execute_scan)

    -- Listen to Incoming Trade Events directly
    pcall(function()
        local net = replicated_storage.Packages._Index["sleitnick_net@0.2.0"].net
        for _, child in ipairs(net:GetChildren()) do
            if child:IsA("RemoteEvent") and (string.find(string.lower(child.Name), "trade") or string.find(string.lower(child.Name), "offer")) then
                child.OnClientEvent:Connect(function(...)
                    local ev_args = {...}
                    task.spawn(function()
                        local time_str = os.date("%H:%M:%S")
                        local log_msg = string.format("[%s] 📥 [INCOMING EVENT] %s\nArgs: %s\n--------------------------------------------------", time_str, child.Name, safe_serialize(ev_args, 1, 2))
                        print(log_msg)
                        table.insert(spy_logs, 1, log_msg)
                        if live_text_label and live_text_label.Parent then
                            live_text_label.Text = log_msg .. "\n\n" .. live_text_label.Text
                        end
                    end)
                end)
            end
        end
    end)
end

local spy_logs = {}

-- Handler Log Umum
local function log_remote_call(self, method, args)
    task.spawn(function()
        pcall(function()
            local self_name = tostring(self)
            local lower_name = string.lower(self_name)
            if string.find(lower_name, "trade") or string.find(lower_name, "offer") or string.find(lower_name, "send") or string.find(lower_name, "invite") or string.find(lower_name, "additem") or string.find(lower_name, "setready") or string.find(lower_name, "confirm") or string.find(lower_name, "initiate") then
                local time_str = os.date("%H:%M:%S")
                local log_msg = string.format("[%s] 🎯 [CAPTURED CALL] %s (%s)\nArgs: %s\n--------------------------------------------------", time_str, self_name, method, safe_serialize(args, 1, 2))
                print(log_msg)
                table.insert(spy_logs, 1, log_msg)
                if live_text_label and live_text_label.Parent then
                    live_text_label.Text = log_msg .. "\n\n" .. live_text_label.Text
                end
                pcall(function()
                    if setclipboard then setclipboard(log_msg)
                    elseif toclipboard then toclipboard(log_msg) end
                end)
            end
        end)
    end)
end

-- 1. Hook __namecall (Tanpa batasan checkcaller)
pcall(function()
    if not hookmetamethod or not getnamecallmethod then return end
    local old_namecall
    local nc_handler = function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if (method == "InvokeServer" or method == "FireServer") then
            log_remote_call(self, method, args)
        end
        if setnamecallmethod then setnamecallmethod(method) end
        return old_namecall(self, ...)
    end
    if newcclosure then
        old_namecall = hookmetamethod(game, "__namecall", newcclosure(nc_handler))
    else
        old_namecall = hookmetamethod(game, "__namecall", nc_handler)
    end
end)

-- 2. Hook Direct Function (InvokeServer & FireServer)
pcall(function()
    if not hookfunction then return end
    local old_inv
    old_inv = hookfunction(Instance.new("RemoteFunction").InvokeServer, newcclosure(function(self, ...)
        log_remote_call(self, "InvokeServer_Direct", {...})
        return old_inv(self, ...)
    end))
    local old_fire
    old_fire = hookfunction(Instance.new("RemoteEvent").FireServer, newcclosure(function(self, ...)
        log_remote_call(self, "FireServer_Direct", {...})
        return old_fire(self, ...)
    end))
end)

-- Run GUI safely (Standby mode, zero initial dump)
pcall(build_gui)
