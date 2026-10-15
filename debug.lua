local ipairs, pairs, tostring, tonumber, pcall = ipairs, pairs, tostring, tonumber, pcall
local table_insert, table_concat, table_sort = table.insert, table.concat, table.sort
local string_format = string.format
local task_wait, task_spawn = task.wait, task.spawn

local cloneref = cloneref or function(ref) return ref end
local players = cloneref(game:GetService("Players"))
local local_player = players.LocalPlayer
local user_input_service = cloneref(game:GetService("UserInputService"))
local replicated_storage = cloneref(game:GetService("ReplicatedStorage"))
local http_service = cloneref(game:GetService("HttpService"))
local teleport_service = cloneref(game:GetService("TeleportService"))

local parent_gui = (gethui and gethui()) or game:GetService("CoreGui")
pcall(function()
    local old = parent_gui:FindFirstChild("FishIt_TradeInspector")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "FishIt_TradeInspector"
gui.ResetOnSpawn = false
gui.DisplayOrder = 2147483647
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = parent_gui

local BG_COLOR       = Color3.fromRGB(15, 15, 15)
local SIDEBAR_COLOR  = Color3.fromRGB(10, 10, 10)
local BUTTON_COLOR   = Color3.fromRGB(235, 95, 20)
local TEXT_COLOR     = Color3.fromRGB(240, 240, 240)
local MUTED_COLOR    = Color3.fromRGB(150, 150, 150)
local CARD_COLOR     = Color3.fromRGB(22, 22, 22)
local GREEN_COLOR    = Color3.fromRGB(65, 215, 125)
local RED_COLOR      = Color3.fromRGB(255, 75, 75)

local font_face = Font.fromEnum(Enum.Font.SourceSans)
local font_bold = Font.fromEnum(Enum.Font.SourceSansBold)

local function create_corner(parent, radius)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, radius); c.Parent = parent; return c
end
local function create_stroke(parent, color, thickness)
    local s = Instance.new("UIStroke"); s.Color = color; s.Thickness = thickness or 1; s.Parent = parent; return s
end

local main = Instance.new("Frame")
main.Name = "MainFrame"
main.Size = UDim2.new(0, 420, 0, 360)
main.Position = UDim2.new(0.5, -210, 0.45, -180)
main.BackgroundColor3 = BG_COLOR
main.Active = true
main.Parent = gui
create_corner(main, 9); create_stroke(main, Color3.fromRGB(48, 48, 48), 1.2)

local floating_btn = Instance.new("TextButton")
floating_btn.Name = "FloatingRestore"
floating_btn.Size = UDim2.new(0, 36, 0, 36)
floating_btn.Position = UDim2.new(0, 15, 0.5, -18)
floating_btn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
floating_btn.BackgroundTransparency = 0
floating_btn.Text = "T"
floating_btn.TextColor3 = BUTTON_COLOR
floating_btn.TextSize = 18
floating_btn.FontFace = font_bold
floating_btn.Visible = false
floating_btn.ZIndex = 100
floating_btn.Parent = gui
create_corner(floating_btn, 9); create_stroke(floating_btn, BUTTON_COLOR, 1.4)

local float_dragging = false
local float_drag_start = nil
local float_start_pos = nil
local has_float_dragged = false

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

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 28)
header.BackgroundColor3 = SIDEBAR_COLOR
header.Parent = main
create_corner(header, 9)

local title_lbl = Instance.new("TextLabel")
title_lbl.Size = UDim2.new(1, -65, 1, 0)
title_lbl.Position = UDim2.new(0, 10, 0, 0)
title_lbl.BackgroundTransparency = 1
title_lbl.Text = "KEENAN - Trade System Inspector"
title_lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
title_lbl.TextSize = 12
title_lbl.FontFace = font_bold
title_lbl.TextXAlignment = Enum.TextXAlignment.Left
title_lbl.Parent = header

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
min_btn.MouseEnter:Connect(function() min_btn.TextColor3 = BUTTON_COLOR end)
min_btn.MouseLeave:Connect(function() min_btn.TextColor3 = MUTED_COLOR end)
min_btn.MouseButton1Click:Connect(function()
    main.Visible = false
    floating_btn.Visible = true
end)

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
close_btn.MouseEnter:Connect(function() close_btn.TextColor3 = RED_COLOR end)
close_btn.MouseLeave:Connect(function() close_btn.TextColor3 = MUTED_COLOR end)
close_btn.MouseButton1Click:Connect(function() gui:Destroy() end)

local dragging, drag_start, start_pos
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging, drag_start, start_pos = true, input.Position, main.Position
        local end_conn
        end_conn = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                if end_conn then end_conn:Disconnect(); end_conn = nil end
            end
        end)
    end
end)
user_input_service.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - drag_start
        main.Position = UDim2.new(start_pos.X.Scale, start_pos.X.Offset + delta.X, start_pos.Y.Scale, start_pos.Y.Offset + delta.Y)
    end
end)

-- Action / Filter Row (Persis seperti Trade Lock Scan)
local filter_row = Instance.new("Frame")
filter_row.Size = UDim2.new(1, -20, 0, 24)
filter_row.Position = UDim2.new(0, 10, 0, 34)
filter_row.BackgroundTransparency = 1
filter_row.Parent = main

local function create_action_btn(name, x_scale, width_scale, bg_color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(width_scale, 0, 1, 0)
    btn.Position = UDim2.new(x_scale, 0, 0, 0)
    btn.BackgroundColor3 = bg_color or CARD_COLOR
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 10.5
    btn.FontFace = font_bold
    btn.Parent = filter_row
    create_corner(btn, 5); create_stroke(btn, Color3.fromRGB(45, 45, 45))
    return btn
end

local btn_remotes = create_action_btn("Scan Remotes", 0, 0.32, BUTTON_COLOR)
local btn_modules = create_action_btn("Scan Modules", 0.34, 0.32, CARD_COLOR)
local btn_clear   = create_action_btn("Clear Logs", 0.68, 0.32, CARD_COLOR)

-- Stats Row (Persis seperti Trade Lock Scan)
local stats_row = Instance.new("Frame")
stats_row.Size = UDim2.new(1, -20, 0, 38)
stats_row.Position = UDim2.new(0, 10, 0, 64)
stats_row.BackgroundTransparency = 1
stats_row.Parent = main

local function create_stat_card(parent, pos, size, label, val_color)
    local card = Instance.new("Frame")
    card.Position = pos
    card.Size = size
    card.BackgroundColor3 = CARD_COLOR
    card.Parent = parent
    create_corner(card, 5); create_stroke(card, Color3.fromRGB(38, 38, 38))

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -10, 0, 12)
    lbl.Position = UDim2.new(0, 6, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = MUTED_COLOR
    lbl.TextSize = 8.5
    lbl.FontFace = font_bold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = card

    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(1, -10, 0, 18)
    val.Position = UDim2.new(0, 6, 0, 16)
    val.BackgroundTransparency = 1
    val.Text = "-"
    val.TextColor3 = val_color
    val.TextSize = 12
    val.FontFace = font_bold
    val.TextXAlignment = Enum.TextXAlignment.Left
    val.Parent = card

    return val
end

local stat_remotes_val = create_stat_card(stats_row, UDim2.new(0, 0, 0, 0), UDim2.new(0.32, 0, 1, 0), "REMOTES FOUND", TEXT_COLOR)
local stat_events_val  = create_stat_card(stats_row, UDim2.new(0.34, 0, 0, 0), UDim2.new(0.32, 0, 1, 0), "EVENTS FIRED", GREEN_COLOR)
local stat_status_val  = create_stat_card(stats_row, UDim2.new(0.68, 0, 0, 0), UDim2.new(0.32, 0, 1, 0), "STATUS", BUTTON_COLOR)

stat_remotes_val.Text = "0"
stat_events_val.Text = "0"
stat_status_val.Text = "Ready"

-- Scrolling Container (Persis seperti Trade Lock Scan)
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -148)
scroll.Position = UDim2.new(0, 10, 0, 108)
scroll.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 70)
scroll.Parent = main
create_corner(scroll, 6); create_stroke(scroll, Color3.fromRGB(32, 32, 32))

local scroll_layout = Instance.new("UIListLayout")
scroll_layout.Padding = UDim.new(0, 4)
scroll_layout.Parent = scroll

local scroll_padding = Instance.new("UIPadding")
scroll_padding.PaddingLeft = UDim.new(0, 4)
scroll_padding.PaddingRight = UDim.new(0, 4)
scroll_padding.PaddingTop = UDim.new(0, 4)
scroll_padding.PaddingBottom = UDim.new(0, 4)
scroll_padding.Parent = scroll

-- Bottom Buttons (Persis seperti Start Scan & Unlock di Trade Lock Scan)
local copy_btn = Instance.new("TextButton")
copy_btn.Size = UDim2.new(0.5, -13, 0, 28)
copy_btn.Position = UDim2.new(0, 10, 1, -34)
copy_btn.BackgroundColor3 = BUTTON_COLOR
copy_btn.Text = "Copy Full Report"
copy_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
copy_btn.TextSize = 11.5
copy_btn.FontFace = font_bold
copy_btn.Parent = main
create_corner(copy_btn, 4)

local rescan_btn = Instance.new("TextButton")
rescan_btn.Size = UDim2.new(0.5, -13, 0, 28)
rescan_btn.Position = UDim2.new(0.5, 3, 1, -34)
rescan_btn.BackgroundColor3 = Color3.fromRGB(35, 150, 75)
rescan_btn.Text = "Scan Ulang Semua"
rescan_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
rescan_btn.TextSize = 11.5
rescan_btn.FontFace = font_bold
rescan_btn.Parent = main
create_corner(rescan_btn, 4)

-- Log Data & Card Rendering
local all_raw_logs = {}
local total_events = 0
local total_remotes = 0
local card_count = 0

local function add_log_card(category, title_text, detail_text, is_highlight)
    local raw_line = string_format("[%s] %s | %s", category, title_text, detail_text or "")
    table_insert(all_raw_logs, raw_line)
    pcall(function() print("[INSPECTOR] " .. raw_line) end)

    card_count = card_count + 1

    local card_frame = Instance.new("Frame")
    card_frame.Size = UDim2.new(1, 0, 0, 48)
    card_frame.BackgroundColor3 = is_highlight and Color3.fromRGB(32, 22, 16) or CARD_COLOR
    card_frame.Parent = scroll
    create_corner(card_frame, 5)
    create_stroke(card_frame, is_highlight and Color3.fromRGB(150, 65, 20) or Color3.fromRGB(38, 38, 38))

    local cat_badge = Instance.new("Frame")
    cat_badge.Size = UDim2.new(0, 75, 0, 16)
    cat_badge.Position = UDim2.new(0, 6, 0, 4)
    cat_badge.BackgroundColor3 = is_highlight and BUTTON_COLOR or Color3.fromRGB(40, 40, 40)
    cat_badge.Parent = card_frame
    create_corner(cat_badge, 3)

    local cat_lbl = Instance.new("TextLabel")
    cat_lbl.Size = UDim2.new(1, 0, 1, 0)
    cat_lbl.BackgroundTransparency = 1
    cat_lbl.Text = category
    cat_lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    cat_lbl.TextSize = 8.5
    cat_lbl.FontFace = font_bold
    cat_lbl.Parent = cat_badge

    local name_lbl = Instance.new("TextLabel")
    name_lbl.Size = UDim2.new(1, -145, 0, 16)
    name_lbl.Position = UDim2.new(0, 86, 0, 4)
    name_lbl.BackgroundTransparency = 1
    name_lbl.Text = title_text
    name_lbl.TextColor3 = is_highlight and Color3.fromRGB(255, 200, 120) or TEXT_COLOR
    name_lbl.TextSize = 10
    name_lbl.FontFace = font_bold
    name_lbl.TextXAlignment = Enum.TextXAlignment.Left
    name_lbl.TextTruncate = Enum.TextTruncate.AtEnd
    name_lbl.Parent = card_frame

    local detail_lbl = Instance.new("TextLabel")
    detail_lbl.Size = UDim2.new(1, -65, 0, 20)
    detail_lbl.Position = UDim2.new(0, 6, 0, 24)
    detail_lbl.BackgroundTransparency = 1
    detail_lbl.Text = detail_text or ""
    detail_lbl.TextColor3 = MUTED_COLOR
    detail_lbl.TextSize = 9
    detail_lbl.FontFace = font_face
    detail_lbl.TextXAlignment = Enum.TextXAlignment.Left
    detail_lbl.TextTruncate = Enum.TextTruncate.AtEnd
    detail_lbl.Parent = card_frame

    local single_copy = Instance.new("TextButton")
    single_copy.Size = UDim2.new(0, 48, 0, 20)
    single_copy.Position = UDim2.new(1, -54, 0.5, -10)
    single_copy.BackgroundColor3 = is_highlight and BUTTON_COLOR or Color3.fromRGB(35, 35, 35)
    single_copy.Text = "Copy"
    single_copy.TextColor3 = Color3.fromRGB(255, 255, 255)
    single_copy.TextSize = 9
    single_copy.FontFace = font_bold
    single_copy.Parent = card_frame
    create_corner(single_copy, 3)

    single_copy.MouseButton1Click:Connect(function()
        local fn = setclipboard or toclipboard or set_clipboard
        if fn then pcall(function() fn(raw_line) end) end
        single_copy.Text = "Done"
        task.delay(1, function()
            if single_copy and single_copy.Parent then single_copy.Text = "Copy" end
        end)
    end)

    scroll.CanvasSize = UDim2.new(0, 0, 0, card_count * 52 + 10)
    scroll.CanvasPosition = Vector2.new(0, scroll.CanvasSize.Y.Offset)
end

local function copy_all_report()
    local text = table_concat(all_raw_logs, "\n")
    local fn = setclipboard or toclipboard or set_clipboard
    if fn and text ~= "" then
        pcall(function() fn(text) end)
        local orig = copy_btn.Text
        copy_btn.Text = "Report Disalin (Copied)!"
        copy_btn.BackgroundColor3 = GREEN_COLOR
        task.delay(1.5, function()
            if copy_btn and copy_btn.Parent then
                copy_btn.Text = orig
                copy_btn.BackgroundColor3 = BUTTON_COLOR
            end
        end)
    end
end
copy_btn.MouseButton1Click:Connect(copy_all_report)

btn_clear.MouseButton1Click:Connect(function()
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    all_raw_logs = {}
    card_count = 0
    total_events = 0
    stat_events_val.Text = "0"
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
end)

-- ================= SCANNER FUNCTIONS =================
local connected_events = {}

local function scan_remotes()
    stat_status_val.Text = "Scanning..."
    local found = 0
    local all_desc = replicated_storage:GetDescendants()
    for idx, desc in ipairs(all_desc) do
        if idx % 120 == 0 then task_wait() end
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
            local ln = string.lower(desc.Name)
            if string.find(ln, "trade") or string.find(ln, "offer") then
                found = found + 1
                total_remotes = total_remotes + 1
                stat_remotes_val.Text = tostring(total_remotes)
                add_log_card("REMOTE", desc.Name, string_format("[%s] %s", desc.ClassName, desc:GetFullName()), true)

                if desc:IsA("RemoteEvent") and not connected_events[desc] then
                    connected_events[desc] = true
                    desc.OnClientEvent:Connect(function(...)
                        total_events = total_events + 1
                        stat_events_val.Text = tostring(total_events)
                        local payload = ""
                        pcall(function() payload = http_service:JSONEncode({...}) end)
                        add_log_card("FIRE!", desc.Name, payload, true)

                        if string.find(ln, "complete") or string.find(ln, "end") then
                            add_log_card("DONE", "Trade Selesai Terdeteksi!", "Auto-copying report...", true)
                            copy_all_report()
                        end
                    end)
                end
            end
        end
    end
    stat_status_val.Text = "Ready (" .. found .. " Rmt)"
end

local function scan_modules()
    stat_status_val.Text = "Scanning..."
    pcall(function()
        local td_mod = replicated_storage:FindFirstChild("Shared") and replicated_storage.Shared:FindFirstChild("Trading") and replicated_storage.Shared.Trading:FindFirstChild("TradeData")
        if td_mod then
            local ok, td = pcall(require, td_mod)
            if ok and td then
                add_log_card("MODULE", "TradeData", "Require berhasil!", true)
                if td.Remotes then
                    for k, v in pairs(td.Remotes) do
                        add_log_card("TD.REMOTE", tostring(k), string_format("%s (%s)", tostring(v), typeof(v)), false)
                    end
                end
            else
                add_log_card("MODULE", "TradeData", "Gagal require: " .. tostring(td), false)
            end
        else
            add_log_card("MODULE", "TradeData", "Module tidak ditemukan di Shared.Trading", false)
        end
    end)

    pcall(function()
        local toc_mod = replicated_storage:FindFirstChild("Controllers") and replicated_storage.Controllers:FindFirstChild("Trading") and replicated_storage.Controllers.Trading:FindFirstChild("TradeOfferController")
        if toc_mod then
            local ok, toc = pcall(require, toc_mod)
            if ok and type(toc) == "table" then
                add_log_card("CONTROLLER", "TradeOfferController", "Require berhasil!", true)
                for k, v in pairs(toc) do
                    add_log_card("TOC.METHOD", tostring(k), typeof(v), false)
                end
            end
        end
    end)
    stat_status_val.Text = "Ready"
end

local function run_full_scan()
    scan_remotes()
    scan_modules()
end

btn_remotes.MouseButton1Click:Connect(function()
    task_spawn(scan_remotes)
end)

btn_modules.MouseButton1Click:Connect(function()
    task_spawn(scan_modules)
end)

rescan_btn.MouseButton1Click:Connect(function()
    task_spawn(run_full_scan)
end)

-- Kartu Awal Sambutan
add_log_card("INIT", "Trade System Inspector Siap", "Basis Trade Lock Scan. Silakan lakukan trade.", true)

-- Jalankan scan latar belakang
task_spawn(function()
    task_wait(0.2)
    run_full_scan()
end)
