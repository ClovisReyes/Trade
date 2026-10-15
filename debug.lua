--[[
    KEENAN - Trade System Deep Inspector (v3 - Exact Working UI Skeleton)
    Basis sama persis dengan debug_find_expired_ui.lua yang sudah 100% terbukti muncul di CloudPhone:
    - UI Frame 390x270 dengan Draggable Header & Minimize Button (-)
    - Floating Restore Icon (T) yang bisa digeser jika di-minimize
    - Result Box + Tombol "COPY SEMUA LOG KE CLIPBOARD"
    - Tombol "Scan Remotes", "Scan Modules", & "Clear"
    - Deteksi otomatis RemoteEvent/RemoteFunction Trade di ReplicatedStorage
    - Live Hook .OnClientEvent pada setiap remote trade
    - Deteksi TradeData & TradeOfferController
    - Scan ScreenGui trade di PlayerGui beserta tombol close-nya
]]

local cloneref = cloneref or function(ref) return ref end
local players = cloneref(game:GetService("Players"))
local local_player = players.LocalPlayer
local player_gui = cloneref(local_player:WaitForChild("PlayerGui"))
local user_input_service = cloneref(game:GetService("UserInputService"))
local tween_service = cloneref(game:GetService("TweenService"))
local replicated_storage = cloneref(game:GetService("ReplicatedStorage"))
local http_service = cloneref(game:GetService("HttpService"))

local parent_gui = (gethui and gethui()) or game:GetService("CoreGui")
pcall(function()
    local old = parent_gui:FindFirstChild("NoirHub_TradeInspector")
    if old then old:Destroy() end
    local old_alt = player_gui:FindFirstChild("NoirHub_TradeInspector")
    if old_alt then old_alt:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "NoirHub_TradeInspector"
gui.ResetOnSpawn = false
gui.DisplayOrder = 2147483647
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function() gui.Parent = parent_gui end)
if not gui.Parent then
    gui.Parent = player_gui
end

local BG_COLOR       = Color3.fromRGB(15, 15, 15)
local SIDEBAR_COLOR  = Color3.fromRGB(10, 10, 10)
local ACCENT_COLOR   = Color3.fromRGB(255, 125, 0)
local BUTTON_COLOR   = Color3.fromRGB(235, 95, 20)
local GREEN_COLOR    = Color3.fromRGB(65, 215, 125)
local TEXT_COLOR     = Color3.fromRGB(240, 240, 240)
local MUTED_COLOR    = Color3.fromRGB(150, 150, 150)
local CARD_COLOR     = Color3.fromRGB(22, 22, 22)
local INPUT_BG_COLOR = Color3.fromRGB(28, 28, 28)

local font_face = Font.fromEnum(Enum.Font.SourceSans)
local font_bold = Font.fromEnum(Enum.Font.SourceSansBold)

local function create_corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
    return c
end

local function create_stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness or 1
    s.Parent = parent
    return s
end

-- Main Window
local main = Instance.new("Frame")
main.Name = "MainFrame"
main.Size = UDim2.new(0, 390, 0, 270)
main.Position = UDim2.new(0.5, -195, 0.45, -135)
main.BackgroundColor3 = BG_COLOR
main.Active = true
main.Parent = gui
create_corner(main, 9)
create_stroke(main, Color3.fromRGB(48, 48, 48), 1.2)

-- Floating Restore Icon
local floating_btn = Instance.new("TextButton")
floating_btn.Name = "FloatingRestore"
floating_btn.Size = UDim2.new(0, 38, 0, 38)
floating_btn.Position = UDim2.new(0, 15, 0.5, -19)
floating_btn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
floating_btn.BackgroundTransparency = 0
floating_btn.Text = "T"
floating_btn.TextColor3 = ACCENT_COLOR
floating_btn.TextSize = 20
floating_btn.FontFace = font_bold
floating_btn.Visible = false
floating_btn.ZIndex = 100
floating_btn.Parent = gui
create_corner(floating_btn, 9)
create_stroke(floating_btn, ACCENT_COLOR, 1.4)

-- Floating Button Dragging
local float_dragging, float_drag_start, float_start_pos, has_float_dragged = false, nil, nil, false
floating_btn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        float_dragging = true
        has_float_dragged = false
        float_drag_start = input.Position
        float_start_pos = floating_btn.Position
        local end_conn
        end_conn = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                float_dragging = false
                if end_conn then end_conn:Disconnect(); end_conn = nil end
            end
        end)
    end
end)

user_input_service.InputChanged:Connect(function(input)
    if float_dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - float_drag_start
        if delta.Magnitude > 4 then
            has_float_dragged = true
        end
        floating_btn.Position = UDim2.new(float_start_pos.X.Scale, float_start_pos.X.Offset + delta.X, float_start_pos.Y.Scale, float_start_pos.Y.Offset + delta.Y)
    end
end)

floating_btn.MouseButton1Click:Connect(function()
    if not has_float_dragged then
        main.Visible = true
        floating_btn.Visible = false
    end
end)

-- Header
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 28)
header.BackgroundColor3 = SIDEBAR_COLOR
header.Parent = main
create_corner(header, 9)

local title_lbl = Instance.new("TextLabel")
title_lbl.Size = UDim2.new(1, -70, 1, 0)
title_lbl.Position = UDim2.new(0, 10, 0, 0)
title_lbl.BackgroundTransparency = 1
title_lbl.Text = "KEENAN - Trade System Inspector"
title_lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
title_lbl.TextSize = 12
title_lbl.FontFace = font_bold
title_lbl.TextXAlignment = Enum.TextXAlignment.Left
title_lbl.Parent = header

-- Minimize Button
local min_btn = Instance.new("TextButton")
min_btn.Name = "MinimizeBtn"
min_btn.Size = UDim2.new(0, 22, 0, 22)
min_btn.Position = UDim2.new(1, -50, 0.5, -11)
min_btn.BackgroundTransparency = 1
min_btn.Text = "-"
min_btn.TextColor3 = MUTED_COLOR
min_btn.TextSize = 15
min_btn.Font = Enum.Font.SourceSansBold
min_btn.Parent = header
min_btn.MouseEnter:Connect(function() min_btn.TextColor3 = ACCENT_COLOR end)
min_btn.MouseLeave:Connect(function() min_btn.TextColor3 = MUTED_COLOR end)
min_btn.MouseButton1Click:Connect(function()
    main.Visible = false
    floating_btn.Visible = true
end)

-- Close Button
local close_btn = Instance.new("TextButton")
close_btn.Name = "CloseBtn"
close_btn.Size = UDim2.new(0, 22, 0, 22)
close_btn.Position = UDim2.new(1, -26, 0.5, -11)
close_btn.BackgroundTransparency = 1
close_btn.Text = "X"
close_btn.TextColor3 = MUTED_COLOR
close_btn.TextSize = 12
close_btn.Font = Enum.Font.SourceSansBold
close_btn.Parent = header
close_btn.MouseEnter:Connect(function() close_btn.TextColor3 = Color3.fromRGB(255, 75, 75) end)
close_btn.MouseLeave:Connect(function() close_btn.TextColor3 = MUTED_COLOR end)
close_btn.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

-- Header Dragging
local main_dragging, main_drag_start, main_start_pos = false, nil, nil
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        main_dragging = true
        main_drag_start = input.Position
        main_start_pos = main.Position
        local end_conn
        end_conn = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                main_dragging = false
                if end_conn then end_conn:Disconnect(); end_conn = nil end
            end
        end)
    end
end)

user_input_service.InputChanged:Connect(function(input)
    if main_dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - main_drag_start
        main.Position = UDim2.new(main_start_pos.X.Scale, main_start_pos.X.Offset + delta.X, main_start_pos.Y.Scale, main_start_pos.Y.Offset + delta.Y)
    end
end)

-- Status Bar
local status_card = Instance.new("Frame")
status_card.Size = UDim2.new(1, -16, 0, 24)
status_card.Position = UDim2.new(0, 8, 0, 34)
status_card.BackgroundColor3 = CARD_COLOR
status_card.Parent = main
create_corner(status_card, 5)
create_stroke(status_card, Color3.fromRGB(35, 35, 35))

local status_dot = Instance.new("Frame")
status_dot.Size = UDim2.new(0, 8, 0, 8)
status_dot.Position = UDim2.new(0, 8, 0.5, -4)
status_dot.BackgroundColor3 = GREEN_COLOR
status_dot.BorderSizePixel = 0
status_dot.Parent = status_card
create_corner(status_dot, 4)

local status_lbl = Instance.new("TextLabel")
status_lbl.Size = UDim2.new(1, -26, 1, 0)
status_lbl.Position = UDim2.new(0, 22, 0, 0)
status_lbl.BackgroundTransparency = 1
status_lbl.Text = "Standby. Mendengarkan event trade..."
status_lbl.TextColor3 = TEXT_COLOR
status_lbl.TextSize = 10
status_lbl.FontFace = font_face
status_lbl.TextXAlignment = Enum.TextXAlignment.Left
status_lbl.Parent = status_card

-- Latest Result Card
local latest_card = Instance.new("Frame")
latest_card.Size = UDim2.new(1, -16, 0, 78)
latest_card.Position = UDim2.new(0, 8, 0, 64)
latest_card.BackgroundColor3 = CARD_COLOR
latest_card.Parent = main
create_corner(latest_card, 6)
create_stroke(latest_card, Color3.fromRGB(45, 45, 45))

local path_title = Instance.new("TextLabel")
path_title.Size = UDim2.new(1, -16, 0, 14)
path_title.Position = UDim2.new(0, 8, 0, 6)
path_title.BackgroundTransparency = 1
path_title.Text = "EVENT TERAKHIR / STATUS TRADE:"
path_title.TextColor3 = ACCENT_COLOR
path_title.TextSize = 10
path_title.FontFace = font_bold
path_title.TextXAlignment = Enum.TextXAlignment.Left
path_title.Parent = latest_card

local latest_box = Instance.new("TextBox")
latest_box.Size = UDim2.new(1, -16, 0, 24)
latest_box.Position = UDim2.new(0, 8, 0, 22)
latest_box.BackgroundColor3 = INPUT_BG_COLOR
latest_box.Text = "Belum ada event trade terdeteksi..."
latest_box.TextColor3 = MUTED_COLOR
latest_box.TextSize = 10
latest_box.FontFace = font_face
latest_box.TextXAlignment = Enum.TextXAlignment.Left
latest_box.ClearTextOnFocus = false
latest_box.Parent = latest_card
create_corner(latest_box, 4)
create_stroke(latest_box, Color3.fromRGB(40, 40, 40))

local copy_all_btn = Instance.new("TextButton")
copy_all_btn.Size = UDim2.new(1, -16, 0, 22)
copy_all_btn.Position = UDim2.new(0, 8, 0, 50)
copy_all_btn.BackgroundColor3 = BUTTON_COLOR
copy_all_btn.Text = "COPY SEMUA LOG KE CLIPBOARD"
copy_all_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
copy_all_btn.TextSize = 10
copy_all_btn.FontFace = font_bold
copy_all_btn.Parent = latest_card
create_corner(copy_all_btn, 4)

-- Log Section Header & Buttons
local log_header = Instance.new("Frame")
log_header.Size = UDim2.new(1, -16, 0, 20)
log_header.Position = UDim2.new(0, 8, 0, 148)
log_header.BackgroundTransparency = 1
log_header.Parent = main

local log_title = Instance.new("TextLabel")
log_title.Size = UDim2.new(0.35, 0, 1, 0)
log_title.BackgroundTransparency = 1
log_title.Text = "Log Inspector:"
log_title.TextColor3 = MUTED_COLOR
log_title.TextSize = 10
log_title.FontFace = font_bold
log_title.TextXAlignment = Enum.TextXAlignment.Left
log_title.Parent = log_header

local scan_remotes_btn = Instance.new("TextButton")
scan_remotes_btn.Size = UDim2.new(0, 80, 1, 0)
scan_remotes_btn.Position = UDim2.new(1, -210, 0, 0)
scan_remotes_btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
scan_remotes_btn.Text = "Scan Remotes"
scan_remotes_btn.TextColor3 = TEXT_COLOR
scan_remotes_btn.TextSize = 9
scan_remotes_btn.FontFace = font_face
scan_remotes_btn.Parent = log_header
create_corner(scan_remotes_btn, 4)

local scan_mods_btn = Instance.new("TextButton")
scan_mods_btn.Size = UDim2.new(0, 75, 1, 0)
scan_mods_btn.Position = UDim2.new(1, -125, 0, 0)
scan_mods_btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
scan_mods_btn.Text = "Scan Modules"
scan_mods_btn.TextColor3 = TEXT_COLOR
scan_mods_btn.TextSize = 9
scan_mods_btn.FontFace = font_face
scan_mods_btn.Parent = log_header
create_corner(scan_mods_btn, 4)

local clear_btn = Instance.new("TextButton")
clear_btn.Size = UDim2.new(0, 45, 1, 0)
clear_btn.Position = UDim2.new(1, -45, 0, 0)
clear_btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
clear_btn.Text = "Clear"
clear_btn.TextColor3 = TEXT_COLOR
clear_btn.TextSize = 9
clear_btn.FontFace = font_face
clear_btn.Parent = log_header
create_corner(clear_btn, 4)

-- Scrolling Log List
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -16, 1, -176)
scroll.Position = UDim2.new(0, 8, 0, 170)
scroll.BackgroundColor3 = INPUT_BG_COLOR
scroll.ScrollBarThickness = 3
scroll.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.Parent = main
create_corner(scroll, 5)
create_stroke(scroll, Color3.fromRGB(35, 35, 35))

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 3)
layout.Parent = scroll

local all_logs = {}
local log_count = 0

local function add_log(category, text, is_highlight)
    local line = string.format("[%s] %s", category, text)
    table.insert(all_logs, line)
    pcall(function() print("[INSPECTOR] " .. line) end)

    log_count = log_count + 1
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -6, 0, 22)
    row.BackgroundColor3 = CARD_COLOR
    row.Parent = scroll
    create_corner(row, 4)

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, -55, 1, 0)
    txt.Position = UDim2.new(0, 6, 0, 0)
    txt.BackgroundTransparency = 1
    txt.Text = line
    txt.TextColor3 = is_highlight and ACCENT_COLOR or TEXT_COLOR
    txt.TextSize = 9
    txt.FontFace = font_face
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.TextTruncate = Enum.TextTruncate.AtEnd
    txt.Parent = row

    local row_copy = Instance.new("TextButton")
    row_copy.Size = UDim2.new(0, 45, 0, 16)
    row_copy.Position = UDim2.new(1, -48, 0.5, -8)
    row_copy.BackgroundColor3 = is_highlight and BUTTON_COLOR or Color3.fromRGB(45, 45, 45)
    row_copy.Text = "Copy"
    row_copy.TextColor3 = Color3.fromRGB(255, 255, 255)
    row_copy.TextSize = 9
    row_copy.FontFace = font_bold
    row_copy.Parent = row
    create_corner(row_copy, 3)

    row_copy.MouseButton1Click:Connect(function()
        local copy_fn = setclipboard or toclipboard or set_clipboard
        if copy_fn then
            pcall(function() copy_fn(line) end)
        end
        row_copy.Text = "Done"
        task.delay(1, function()
            if row_copy and row_copy.Parent then row_copy.Text = "Copy" end
        end)
    end)

    scroll.CanvasSize = UDim2.new(0, 0, 0, log_count * 25 + 10)
    scroll.CanvasPosition = Vector2.new(0, scroll.CanvasSize.Y.Offset)
end

clear_btn.MouseButton1Click:Connect(function()
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    all_logs = {}
    log_count = 0
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
end)

local function copy_all_to_clipboard()
    local text = table.concat(all_logs, "\n")
    local copy_fn = setclipboard or toclipboard or set_clipboard
    if copy_fn and text ~= "" then
        pcall(function() copy_fn(text) end)
        local old_t = copy_all_btn.Text
        copy_all_btn.Text = "BERHASIL DISALIN (ALL COPIED)!"
        copy_all_btn.BackgroundColor3 = GREEN_COLOR
        title_lbl.TextColor3 = GREEN_COLOR
        title_lbl.Text = "KEENAN - Report Disalin!"
        task.delay(1.5, function()
            if copy_all_btn and copy_all_btn.Parent then
                copy_all_btn.Text = old_t
                copy_all_btn.BackgroundColor3 = BUTTON_COLOR
            end
            if title_lbl and title_lbl.Parent then
                title_lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
                title_lbl.Text = "KEENAN - Trade System Inspector"
            end
        end)
    end
end
copy_all_btn.MouseButton1Click:Connect(copy_all_to_clipboard)

-- ================= SCANNER LOGIC =================

local hooked_remotes = {}

local function scan_trade_remotes()
    add_log("SCAN", "Mencari RemoteEvent / RemoteFunction Trade...", true)
    local found = 0
    local all_desc = replicated_storage:GetDescendants()
    for idx, desc in ipairs(all_desc) do
        if idx % 150 == 0 then task.wait() end
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
            local ln = string.lower(desc.Name)
            if string.find(ln, "trade") or string.find(ln, "offer") then
                found = found + 1
                add_log("REMOTE", string.format("%s: %s (%s)", desc.ClassName, desc.Name, desc:GetFullName()), true)

                if desc:IsA("RemoteEvent") and not hooked_remotes[desc] then
                    hooked_remotes[desc] = true
                    desc.OnClientEvent:Connect(function(...)
                        local args_str = ""
                        pcall(function() args_str = http_service:JSONEncode({...}) end)
                        local summary = string.format("%s -> %s", desc.Name, args_str)
                        latest_box.Text = summary
                        latest_box.TextColor3 = GREEN_COLOR
                        status_lbl.Text = "Event Fire: " .. desc.Name
                        add_log("EVENT FIRE", summary, true)

                        if string.find(ln, "complete") or string.find(ln, "end") then
                            add_log("DONE", "Trade selesai terdeteksi! Menyalin report...", true)
                            copy_all_to_clipboard()
                        end
                    end)
                end
            end
        end
    end
    if found == 0 then
        add_log("SCAN", "Tidak ditemukan remote dengan kata 'Trade'/'Offer'.", false)
    else
        add_log("SCAN", string.format("Selesai scan: %d remote ditemukan & di-hook.", found), true)
    end
end

local function scan_modules()
    add_log("SCAN", "Memeriksa TradeData & TradeOfferController...", true)
    pcall(function()
        local td_mod = replicated_storage:FindFirstChild("Shared") and replicated_storage.Shared:FindFirstChild("Trading") and replicated_storage.Shared.Trading:FindFirstChild("TradeData")
        if td_mod then
            local ok, td = pcall(require, td_mod)
            if ok and td then
                add_log("TRADEDATA", "TradeData module berhasil di-require!", true)
                if td.Remotes then
                    for k, v in pairs(td.Remotes) do
                        add_log("TD.REMOTES", string.format("['%s'] = %s (%s)", tostring(k), tostring(v), typeof(v)), false)
                    end
                end
            else
                add_log("TRADEDATA", "Gagal require: " .. tostring(td), false)
            end
        else
            add_log("TRADEDATA", "Module tidak ditemukan di Shared.Trading.TradeData", false)
        end
    end)

    pcall(function()
        local toc_mod = replicated_storage:FindFirstChild("Controllers") and replicated_storage.Controllers:FindFirstChild("Trading") and replicated_storage.Controllers.Trading:FindFirstChild("TradeOfferController")
        if toc_mod then
            local ok, toc = pcall(require, toc_mod)
            if ok and type(toc) == "table" then
                add_log("CONTROLLER", "TradeOfferController berhasil di-require!", true)
                for k, v in pairs(toc) do
                    add_log("TOC.METHOD", string.format("%s (%s)", tostring(k), typeof(v)), false)
                end
            end
        end
    end)
end

local function scan_trade_gui()
    pcall(function()
        for _, sc in ipairs(player_gui:GetChildren()) do
            if sc:IsA("ScreenGui") then
                local ln = string.lower(sc.Name)
                if string.find(ln, "trade") or string.find(ln, "offer") then
                    add_log("GUI", string.format("ScreenGui: '%s' (Enabled: %s)", sc.Name, tostring(sc.Enabled)), true)
                    for _, d in ipairs(sc:GetDescendants()) do
                        if d:IsA("TextButton") or d:IsA("ImageButton") then
                            local bn = string.lower(d.Name)
                            if string.find(bn, "close") or string.find(bn, "exit") or string.find(bn, "cancel") or string.find(bn, "x") then
                                add_log("CLOSE BTN", string.format("%s (%s)", d:GetFullName(), d.ClassName), true)
                            end
                        end
                    end
                end
            end
        end
    end)
end

scan_remotes_btn.MouseButton1Click:Connect(function()
    task.spawn(scan_trade_remotes)
end)

scan_mods_btn.MouseButton1Click:Connect(function()
    task.spawn(scan_modules)
end)

-- Pantau Attributes IsTrading
local last_is_trading = nil
task.spawn(function()
    while gui and gui.Parent do
        local is_t = nil
        pcall(function() is_t = local_player:GetAttribute("IsTrading") end)
        if is_t ~= last_is_trading then
            last_is_trading = is_t
            add_log("ATTR", "Player IsTrading = " .. tostring(is_t), true)
            if is_t == true then
                task.delay(0.5, scan_trade_gui)
            end
        end
        task.wait(0.5)
    end
end)

-- Pantau GUI Baru saat trade terbuka
player_gui.ChildAdded:Connect(function(child)
    if child:IsA("ScreenGui") then
        local ln = string.lower(child.Name)
        if string.find(ln, "trade") or string.find(ln, "offer") then
            add_log("GUI BARU", "ScreenGui muncul: " .. child.Name, true)
            task.delay(0.3, scan_trade_gui)
        end
    end
end)

-- Tampilkan log sambutan awal seketika
add_log("STATUS", "Inspector Aktif! UI Berhasil Terbuka.", true)
add_log("INFO", "Parent: " .. (gui.Parent and gui.Parent:GetFullName() or "Unknown"), false)

-- Jalankan scan awal di latar belakang
task.spawn(function()
    task.wait(0.2)
    scan_trade_remotes()
    scan_modules()
    scan_trade_gui()
end)
