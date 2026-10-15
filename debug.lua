--[[
    KEENAN - Trade System Deep Inspector (v2 - Bulletproof Auto Scanner)
    Mendeteksi SEMUA sistem trade di game secara agresif:
    1. Scan seluruh ReplicatedStorage untuk RemoteEvent & RemoteFunction bertema "Trade"
    2. Hook otomatis ke .OnClientEvent SEMUA remote trade yang ditemukan
    3. Require TradeData & TradeOfferController dengan pcall aman + print error jika gagal
    4. Pantau perubahan PlayerGui & Player Attributes secara real-time
    5. Setiap log muncul di UI dan Console (F9) + Auto Copy saat event selesai
]]

local cloneref = cloneref or function(ref) return ref end
local players = cloneref(game:GetService("Players"))
local local_player = players.LocalPlayer
local player_gui = cloneref(local_player:WaitForChild("PlayerGui"))
local replicated_storage = cloneref(game:GetService("ReplicatedStorage"))
local user_input_service = cloneref(game:GetService("UserInputService"))
local http_service = cloneref(game:GetService("HttpService"))

local parent_gui = (gethui and gethui()) or game:GetService("CoreGui")
pcall(function()
    local old = parent_gui:FindFirstChild("KEENAN_TradeInspector")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "KEENAN_TradeInspector"
gui.ResetOnSpawn = false
gui.DisplayOrder = 2147483647
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = parent_gui

local BG_COLOR       = Color3.fromRGB(15, 15, 15)
local SIDEBAR_COLOR  = Color3.fromRGB(10, 10, 10)
local ACCENT_COLOR   = Color3.fromRGB(255, 125, 0)
local BUTTON_COLOR   = Color3.fromRGB(235, 95, 20)
local GREEN_COLOR    = Color3.fromRGB(65, 215, 125)
local TEXT_COLOR     = Color3.fromRGB(240, 240, 240)
local MUTED_COLOR    = Color3.fromRGB(150, 150, 150)
local CARD_COLOR     = Color3.fromRGB(22, 22, 22)
local INPUT_BG_COLOR = Color3.fromRGB(25, 25, 25)

local font_face = Font.fromEnum(Enum.Font.SourceSans)
local font_bold = Font.fromEnum(Enum.Font.SourceSansBold)

local function create_corner(parent, radius)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, radius); c.Parent = parent; return c
end
local function create_stroke(parent, color, thickness)
    local s = Instance.new("UIStroke"); s.Color = color; s.Thickness = thickness or 1; s.Parent = parent; return s
end

-- Main Frame
local main = Instance.new("Frame")
main.Name = "MainFrame"
main.Size = UDim2.new(0, 440, 0, 310)
main.Position = UDim2.new(0.5, -220, 0.45, -155)
main.BackgroundColor3 = BG_COLOR
main.Active = true
main.Parent = gui
create_corner(main, 9); create_stroke(main, Color3.fromRGB(48, 48, 48), 1.2)

-- Floating Restore Button
local floating_btn = Instance.new("TextButton")
floating_btn.Name = "FloatingRestore"
floating_btn.Size = UDim2.new(0, 38, 0, 38)
floating_btn.Position = UDim2.new(0, 15, 0.5, -19)
floating_btn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
floating_btn.Text = "T"
floating_btn.TextColor3 = ACCENT_COLOR
floating_btn.TextSize = 20
floating_btn.FontFace = font_bold
floating_btn.Visible = false
floating_btn.ZIndex = 100
floating_btn.Parent = gui
create_corner(floating_btn, 9); create_stroke(floating_btn, ACCENT_COLOR, 1.4)

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
        if delta.Magnitude > 4 then has_float_dragged = true end
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
title_lbl.Text = "KEENAN - Trade System Deep Inspector"
title_lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
title_lbl.TextSize = 12
title_lbl.FontFace = font_bold
title_lbl.TextXAlignment = Enum.TextXAlignment.Left
title_lbl.Parent = header

local min_btn = Instance.new("TextButton")
min_btn.Size = UDim2.new(0, 22, 0, 22)
min_btn.Position = UDim2.new(1, -50, 0.5, -11)
min_btn.BackgroundTransparency = 1
min_btn.Text = "-"
min_btn.TextColor3 = MUTED_COLOR
min_btn.TextSize = 15
min_btn.Font = Enum.Font.SourceSansBold
min_btn.Parent = header
min_btn.MouseButton1Click:Connect(function()
    main.Visible = false
    floating_btn.Visible = true
end)

local close_btn = Instance.new("TextButton")
close_btn.Size = UDim2.new(0, 22, 0, 22)
close_btn.Position = UDim2.new(1, -26, 0.5, -11)
close_btn.BackgroundTransparency = 1
close_btn.Text = "X"
close_btn.TextColor3 = MUTED_COLOR
close_btn.TextSize = 12
close_btn.Font = Enum.Font.SourceSansBold
close_btn.Parent = header
close_btn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- Header Drag
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

-- Action Buttons Row
local btn_row = Instance.new("Frame")
btn_row.Size = UDim2.new(1, -16, 0, 26)
btn_row.Position = UDim2.new(0, 8, 0, 34)
btn_row.BackgroundTransparency = 1
btn_row.Parent = main
local btn_layout = Instance.new("UIListLayout"); btn_layout.FillDirection = Enum.FillDirection.Horizontal; btn_layout.Padding = UDim.new(0, 6); btn_layout.Parent = btn_row

local function make_action_btn(text, width, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, width, 1, 0)
    b.BackgroundColor3 = color or BUTTON_COLOR
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 10
    b.FontFace = font_bold
    b.Parent = btn_row
    create_corner(b, 4)
    return b
end

local rescan_btn   = make_action_btn("Scan Ulang", 85, BUTTON_COLOR)
local copy_all_btn = make_action_btn("Copy Report", 110, GREEN_COLOR)
local clear_btn    = make_action_btn("Clear", 65, Color3.fromRGB(45, 45, 45))

-- Scrolling Log Container
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -16, 1, -70)
scroll.Position = UDim2.new(0, 8, 0, 64)
scroll.BackgroundColor3 = INPUT_BG_COLOR
scroll.ScrollBarThickness = 3
scroll.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.Parent = main
create_corner(scroll, 5); create_stroke(scroll, Color3.fromRGB(35, 35, 35))

local log_layout = Instance.new("UIListLayout")
log_layout.Padding = UDim.new(0, 2)
log_layout.Parent = scroll

local all_raw_logs = {}
local total_lines = 0

local function append_log(txt, is_highlight)
    table.insert(all_raw_logs, txt)
    print("[INSPECTOR] " .. txt)

    total_lines = total_lines + 1
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -10, 0, 16)
    lbl.Position = UDim2.new(0, 5, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = txt
    lbl.TextColor3 = is_highlight and ACCENT_COLOR or TEXT_COLOR
    lbl.TextSize = 10
    lbl.FontFace = font_face
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.None
    lbl.TextWrapped = true
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.Parent = scroll

    scroll.CanvasSize = UDim2.new(0, 0, 0, log_layout.AbsoluteContentSize.Y + 30)
    scroll.CanvasPosition = Vector2.new(0, math.max(0, scroll.CanvasSize.Y.Offset))
end

clear_btn.MouseButton1Click:Connect(function()
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    all_raw_logs = {}
    total_lines = 0
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
end)

local function copy_to_clipboard()
    local text = table.concat(all_raw_logs, "\n")
    if setclipboard and text ~= "" then
        pcall(function() setclipboard(text) end)
        copy_all_btn.Text = "REPORT COPIED!"
        copy_all_btn.BackgroundColor3 = Color3.fromRGB(40, 180, 90)
        title_lbl.TextColor3 = GREEN_COLOR
        title_lbl.Text = "KEENAN - Report Copied to Clipboard!"
        task.delay(2, function()
            if copy_all_btn and copy_all_btn.Parent then
                copy_all_btn.Text = "Copy Report"
                copy_all_btn.BackgroundColor3 = GREEN_COLOR
            end
        end)
    end
end
copy_all_btn.MouseButton1Click:Connect(copy_to_clipboard)

-- ================= SCANNER FUNCTIONS =================

local connected_remotes = {}

local function scan_remotes()
    append_log("--- [MEMINDAI REPLICATEDSTORAGE UNTUK TRADE REMOTES] ---", true)
    local found_count = 0
    for _, desc in ipairs(replicated_storage:GetDescendants()) do
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
            local lower_n = string.lower(desc.Name)
            if string.find(lower_n, "trade") or string.find(lower_n, "offer") then
                found_count = found_count + 1
                append_log(string.format("[%s] %s (%s)", desc.ClassName, desc.Name, desc:GetFullName()))

                -- Hook ke RemoteEvent jika belum terhubung
                if desc:IsA("RemoteEvent") and not connected_remotes[desc] then
                    connected_remotes[desc] = true
                    desc.OnClientEvent:Connect(function(...)
                        local args_str = ""
                        pcall(function() args_str = http_service:JSONEncode({...}) end)
                        append_log(string.format("[EVENT FIRE!] %s | Data: %s", desc.Name, args_str), true)

                        local ln = string.lower(desc.Name)
                        if string.find(ln, "complete") or string.find(ln, "end") then
                            append_log("[DONE] Trade Event Terdeteksi Selesai! Auto-copying report...", true)
                            copy_to_clipboard()
                        end
                    end)
                end
            end
        end
    end
    if found_count == 0 then
        append_log("Tidak ditemukan Remote dengan nama 'Trade'/'Offer' di ReplicatedStorage.")
    end
    append_log("")
end

local function scan_trade_data_module()
    append_log("--- [MEMERIKSA TRADEDATA & CONTROLLERS] ---", true)
    pcall(function()
        local td_mod = replicated_storage:FindFirstChild("Shared") and replicated_storage.Shared:FindFirstChild("Trading") and replicated_storage.Shared.Trading:FindFirstChild("TradeData")
        if not td_mod then
            td_mod = replicated_storage:WaitForChild("Shared", 2) and replicated_storage.Shared:WaitForChild("Trading", 2) and replicated_storage.Shared.Trading:WaitForChild("TradeData", 2)
        end
        if td_mod then
            local success, td = pcall(require, td_mod)
            if success and td then
                append_log("TradeData module berhasil di-require!")
                if td.Remotes then
                    append_log("Isi td.Remotes:")
                    for k, v in pairs(td.Remotes) do
                        append_log(string.format("  -> td.Remotes['%s'] = %s (%s)", tostring(k), tostring(v), typeof(v) == "Instance" and v.ClassName or typeof(v)))
                    end
                end
            else
                append_log("Gagal require TradeData: " .. tostring(td))
            end
        else
            append_log("TradeData ModuleScript tidak ditemukan di ReplicatedStorage.Shared.Trading.")
        end
    end)

    pcall(function()
        local toc_mod = replicated_storage:FindFirstChild("Controllers") and replicated_storage.Controllers:FindFirstChild("Trading") and replicated_storage.Controllers.Trading:FindFirstChild("TradeOfferController")
        if toc_mod then
            local success, toc = pcall(require, toc_mod)
            if success and type(toc) == "table" then
                append_log("TradeOfferController methods:")
                for k, v in pairs(toc) do
                    append_log(string.format("  -> toc['%s'] (%s)", tostring(k), typeof(v)))
                end
            end
        end
    end)
    append_log("")
end

local function scan_trade_gui()
    append_log("--- [MEMINDAI PLAYERGUI UNTUK TRADING SCREEN] ---", true)
    local found_gui = false
    for _, screen in ipairs(player_gui:GetChildren()) do
        if screen:IsA("ScreenGui") then
            local lower_n = string.lower(screen.Name)
            if string.find(lower_n, "trade") or string.find(lower_n, "offer") then
                found_gui = true
                append_log(string.format("ScreenGui Ditemukan: '%s' [Enabled: %s]", screen.Name, tostring(screen.Enabled)), true)
                for _, desc in ipairs(screen:GetDescendants()) do
                    if desc:IsA("TextButton") or desc:IsA("ImageButton") then
                        local b_name = string.lower(desc.Name)
                        if string.find(b_name, "close") or string.find(b_name, "cancel") or string.find(b_name, "exit") or string.find(b_name, "x") then
                            append_log(string.format("  [Tombol Tutup] %s (%s)", desc:GetFullName(), desc.ClassName))
                        end
                    end
                end
            end
        end
    end
    if not found_gui then
        append_log("Belum ada ScreenGui Trade aktif saat ini.")
    end
    append_log("")
end

local function run_full_scan()
    append_log("=== MEMULAI PEMINDAIAN SISTEM TRADE ===", true)
    scan_remotes()
    scan_trade_data_module()
    scan_trade_gui()
    append_log("Scanner siap! Silakan buka sesi trade.")
    append_log("--------------------------------------------------")
end

rescan_btn.MouseButton1Click:Connect(run_full_scan)

-- Pantau Attributes Player
local last_is_trading = nil
task_spawn(function()
    while gui.Parent do
        local is_t = local_player:GetAttribute("IsTrading")
        if is_t ~= last_is_trading then
            last_is_trading = is_t
            append_log(string.format("[ATTRIBUTE] Player IsTrading = %s", tostring(is_t)), true)
            if is_t == true then
                task.delay(0.5, scan_trade_gui)
            end
        end
        task.wait(0.3)
    end
end)

-- Pantau GUI baru di PlayerGui saat trade terbuka
player_gui.ChildAdded:Connect(function(child)
    if child:IsA("ScreenGui") then
        local lower_n = string.lower(child.Name)
        if string.find(lower_n, "trade") or string.find(lower_n, "offer") then
            append_log(string.format("[GUI BARU] '%s' muncul di PlayerGui!", child.Name), true)
            task.delay(0.3, scan_trade_gui)
        end
    end
end)

-- AUTO RUN AWAL
task.spawn(run_full_scan)
