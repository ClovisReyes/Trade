-- Fav Debug UI: memantau perubahan data saat ikan di-favorite / un-favorite dan menyediakan tombol Copy.

local RS = game:GetService("ReplicatedStorage")
local Http = game:GetService("HttpService")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Replion = require(RS:WaitForChild("Packages"):WaitForChild("Replion"))
local Data = Replion.Client:WaitReplion("Data")

local copy_fn = setclipboard or toclipboard or set_clipboard or writeclipboard or (Clipboard and Clipboard.set) or (syn and syn.write_clipboard)

local parent_gui = nil
if gethui then
    local ok, res = pcall(gethui)
    if ok and res then parent_gui = res end
end
if not parent_gui then
    local ok, core = pcall(function() return game:GetService("CoreGui") end)
    if ok and core then parent_gui = core end
end
if not parent_gui then
    parent_gui = LocalPlayer:WaitForChild("PlayerGui")
end

pcall(function()
    local old = parent_gui:FindFirstChild("FavDebugUI")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "FavDebugUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 2147483647
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = parent_gui

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 420, 0, 290)
main.Position = UDim2.new(0.5, -210, 0.5, -145)
main.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui
local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0, 8); mc.Parent = main
local ms = Instance.new("UIStroke"); ms.Color = Color3.fromRGB(50, 50, 50); ms.Parent = main

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 28)
header.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
header.BorderSizePixel = 0
header.Parent = main
local hc = Instance.new("UICorner"); hc.CornerRadius = UDim.new(0, 8); hc.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Fav Debug - Favorite & Unfavorite 1 Ikan"
title.TextColor3 = Color3.fromRGB(255, 135, 20)
title.TextSize = 12
title.Font = Enum.Font.SourceSansBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local close_btn = Instance.new("TextButton")
close_btn.Size = UDim2.new(0, 26, 0, 26)
close_btn.Position = UDim2.new(1, -28, 0, 1)
close_btn.BackgroundTransparency = 1
close_btn.Text = "X"
close_btn.TextColor3 = Color3.fromRGB(180, 180, 180)
close_btn.TextSize = 13
close_btn.Font = Enum.Font.SourceSansBold
close_btn.Parent = header

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -16, 1, -76)
scroll.Position = UDim2.new(0, 8, 0, 34)
scroll.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.Parent = main
local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 6); sc.Parent = scroll

local log_box = Instance.new("TextBox")
log_box.Size = UDim2.new(1, -12, 0, 200)
log_box.Position = UDim2.new(0, 6, 0, 4)
log_box.BackgroundTransparency = 1
log_box.TextColor3 = Color3.fromRGB(235, 235, 235)
log_box.TextSize = 11
log_box.Font = Enum.Font.Code
log_box.TextXAlignment = Enum.TextXAlignment.Left
log_box.TextYAlignment = Enum.TextYAlignment.Top
log_box.TextWrapped = true
log_box.MultiLine = true
log_box.ClearTextOnFocus = false
log_box.TextEditable = false
log_box.Text = ""
log_box.Parent = scroll

local btn_row = Instance.new("Frame")
btn_row.Size = UDim2.new(1, -16, 0, 30)
btn_row.Position = UDim2.new(0, 8, 1, -36)
btn_row.BackgroundTransparency = 1
btn_row.Parent = main

local copy_btn = Instance.new("TextButton")
copy_btn.Size = UDim2.new(0.68, -4, 1, 0)
copy_btn.Position = UDim2.new(0, 0, 0, 0)
copy_btn.BackgroundColor3 = Color3.fromRGB(235, 105, 20)
copy_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
copy_btn.TextSize = 13
copy_btn.Font = Enum.Font.SourceSansBold
copy_btn.Text = "Copy Log"
copy_btn.Parent = btn_row
local cbc = Instance.new("UICorner"); cbc.CornerRadius = UDim.new(0, 6); cbc.Parent = copy_btn

local clear_btn = Instance.new("TextButton")
clear_btn.Size = UDim2.new(0.32, 0, 1, 0)
clear_btn.Position = UDim2.new(0.68, 4, 0, 0)
clear_btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
clear_btn.TextColor3 = Color3.fromRGB(230, 230, 230)
clear_btn.TextSize = 12
clear_btn.Font = Enum.Font.SourceSansBold
clear_btn.Text = "Clear"
clear_btn.Parent = btn_row
local clc = Instance.new("UICorner"); clc.CornerRadius = UDim.new(0, 6); clc.Parent = clear_btn

-- Drag header
local dragging, drag_start, start_pos
local drag_conn = UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - drag_start
        main.Position = UDim2.new(start_pos.X.Scale, start_pos.X.Offset + delta.X, start_pos.Y.Scale, start_pos.Y.Offset + delta.Y)
    end
end)
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        drag_start = input.Position
        start_pos = main.Position
        local end_conn
        end_conn = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                if end_conn then end_conn:Disconnect() end
            end
        end)
    end
end)

local running = true
close_btn.MouseButton1Click:Connect(function()
    running = false
    if drag_conn then drag_conn:Disconnect() end
    gui:Destroy()
end)

local lines = {}
local function refresh_ui()
    local full = table.concat(lines, "\n")
    log_box.Text = full
    local h = math.max(200, log_box.TextBounds.Y + 24)
    log_box.Size = UDim2.new(1, -12, 0, h)
    scroll.CanvasSize = UDim2.new(0, 0, 0, h + 10)
    scroll.CanvasPosition = Vector2.new(0, math.max(0, h - scroll.AbsoluteWindowSize.Y))
end

local function log(s)
    s = tostring(s)
    print("[FavDebug] " .. s)
    table.insert(lines, s)
    if #lines > 120 then table.remove(lines, 1) end
    refresh_ui()
end

copy_btn.MouseButton1Click:Connect(function()
    local text = table.concat(lines, "\n")
    pcall(function()
        if makefolder and isfolder and not isfolder("NoirHub") then makefolder("NoirHub") end
        if writefile then writefile("NoirHub/fav_debug.txt", text) end
    end)
    local ok = copy_fn and pcall(copy_fn, text)
    copy_btn.Text = ok and "Copied!" or "Saved (NoirHub/fav_debug.txt)"
    copy_btn.BackgroundColor3 = ok and Color3.fromRGB(40, 165, 85) or Color3.fromRGB(180, 90, 20)
    task.delay(2, function()
        if copy_btn and copy_btn.Parent then
            copy_btn.Text = "Copy Log"
            copy_btn.BackgroundColor3 = Color3.fromRGB(235, 105, 20)
        end
    end)
end)

clear_btn.MouseButton1Click:Connect(function()
    lines = {}
    log("Log dibersihkan. Silakan favorite / un-favorite 1 ikan...")
end)

local function flatten(v, prefix, out, depth)
    if depth > 6 then return end
    if type(v) == "table" then
        for k, c in pairs(v) do
            flatten(c, prefix .. "." .. tostring(k), out, depth + 1)
        end
    else
        out[prefix] = tostring(v)
    end
end

local function get_root()
    if type(Data.Data) == "table" then return Data.Data end
    return { Inventory = Data:Get("Inventory") }
end

local function snapshot()
    local out = {}
    for key, val in pairs(get_root()) do
        if key == "Inventory" and type(val) == "table" then
            for inv_key, inv_val in pairs(val) do
                if type(inv_val) == "table" then
                    for i, it in pairs(inv_val) do
                        local id = type(it) == "table" and (it.UUID or it.uuid) or i
                        flatten(it, "Inventory." .. tostring(inv_key) .. "[" .. tostring(id) .. "]", out, 0)
                    end
                else
                    out["Inventory." .. tostring(inv_key)] = tostring(inv_val)
                end
            end
        else
            flatten(val, tostring(key), out, 0)
        end
    end
    for k, v in pairs(LocalPlayer:GetAttributes()) do
        out["LocalPlayer.Attr." .. tostring(k)] = tostring(v)
    end
    return out
end

local root_keys, inv_keys = {}, {}
for k in pairs(get_root()) do table.insert(root_keys, tostring(k)) end
for k in pairs(Data:Get("Inventory") or {}) do table.insert(inv_keys, tostring(k)) end
log("Data keys: " .. table.concat(root_keys, ", "))
log("Inventory keys: " .. table.concat(inv_keys, ", "))

local items = (Data:Get("Inventory") or {}).Items or {}
if items[1] then
    local ok, json = pcall(Http.JSONEncode, Http, items[1])
    log("Contoh item[1]: " .. (ok and json or "gagal encode"))
end
log("Siap! Silakan favorite lalu un-favorite 1 ikan, lalu klik Copy Log.")

task.spawn(function()
    local prev = snapshot()
    while running and gui.Parent do
        task.wait(0.5)
        local cur = snapshot()
        for path, val in pairs(cur) do
            if prev[path] ~= val then
                log(string.format("CHANGED %s : %s -> %s", path, tostring(prev[path]), val))
            end
        end
        for path, val in pairs(prev) do
            if cur[path] == nil then
                log(string.format("REMOVED %s (was %s)", path, val))
            end
        end
        prev = cur
    end
end)
