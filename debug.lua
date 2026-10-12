local ipairs, pairs, tostring, tonumber, pcall = ipairs, pairs, tostring, tonumber, pcall
local table_insert, table_concat, table_sort = table.insert, table.concat, table.sort
local string_format = string.format
local task_wait, task_spawn = task.wait, task.spawn

local cloneref = cloneref or function(ref) return ref end
local players = cloneref(game:GetService("Players"))
local local_player = players.LocalPlayer
local user_input_service = cloneref(game:GetService("UserInputService"))
local replicated_storage = cloneref(game:GetService("ReplicatedStorage"))

local variables = {
    replion      = replicated_storage:WaitForChild("Packages"):WaitForChild("Replion"),
    item_utility = replicated_storage:WaitForChild("Shared"):WaitForChild("ItemUtility"),
}

local success_replion, replion_mod = pcall(require, variables.replion)
local player_data = success_replion and replion_mod.Client:WaitReplion("Data") or nil
local item_utility = require(variables.item_utility)

local function evaluate_item_lock(item)
    if not item or type(item) ~= "table" then return false, "Tradable", {} end

    local meta = type(item.Metadata) == "table" and item.Metadata or {}
    local is_locked = false
    local reasons = {}

    if item.Locked == true or meta.Locked == true then
        is_locked = true
        table_insert(reasons, "Locked")
    end

    local now = os.time()
    if meta.TradeLock ~= nil then
        local tl = meta.TradeLock
        local lock_time = nil

        if type(tl) == "table" and tl.Time then
            lock_time = tonumber(tl.Time)
        elseif type(tl) == "number" then
            lock_time = tl
        elseif type(tl) == "boolean" and tl == true then
            is_locked = true
            table_insert(reasons, "TradeLock")
        end

        if lock_time then
            local tl_sec = lock_time > 1000000000000 and math.floor(lock_time / 1000) or lock_time
            local diff = tl_sec - now
            if diff > 0 then
                is_locked = true
                local rem_m = math.floor(diff / 60)
                local rem_s = diff % 60
                table_insert(reasons, string.format("TradeLock (%dm %ds)", rem_m, rem_s))
            else

                is_locked = true
                table_insert(reasons, "TradeLock (0:0)")
            end
        end
    end

    local lock_type = is_locked and "Locked" or "Tradable"
    return is_locked, lock_type, reasons
end

_G.IsItemTradeLocked = evaluate_item_lock

local function perform_inventory_scan(filter_mode)
    if not player_data then
        return nil, "Player Data not ready! Ensure character is loaded into the game."
    end

    local inv = player_data:Get("Inventory")
    local items = inv and inv.Items or {}

    local total_count = 0
    local locked_count = 0
    local unlocked_count = 0
    local all_item_keys = {}
    local all_meta_keys = {}

    local groups = {}
    local group_order = {}

    for _, itm in ipairs(items) do
        if itm and itm.Id then
            local item_info = item_utility and item_utility:GetItemData(itm.Id)
            local item_data = item_info and item_info.Data or {}
            local item_type = item_data.Type or "Item"

            local is_match = false
            if filter_mode == "Fish" then
                is_match = (item_type == "Fish")
            elseif filter_mode == "Enchant" then
                is_match = (item_type == "Enchant Stones")
            else
                is_match = true
            end

            if is_match then
                total_count = total_count + 1

                for k in pairs(itm) do all_item_keys[tostring(k)] = true end
                if type(itm.Metadata) == "table" then
                    for k in pairs(itm.Metadata) do all_meta_keys[tostring(k)] = true end
                end

                local is_locked, l_type, reasons = evaluate_item_lock(itm)

                local name = item_data.Name or ("Item #" .. tostring(itm.Id))
                local meta = itm.Metadata or {}
                local var_name = nil
                if meta.VariantId and item_utility and item_utility.GetVariantData then
                    pcall(function()
                        local v = item_utility.GetVariantData(tonumber(meta.VariantId))
                        if v and v.Data and v.Data.Name then var_name = v.Data.Name end
                    end)
                end

                if is_locked then
                    locked_count = locked_count + 1
                else
                    unlocked_count = unlocked_count + 1
                end

                local qty = itm.Quantity or itm.Amount or 1
                local group_key = name .. "_" .. (var_name or "") .. "_" .. tostring(is_locked)

                if not groups[group_key] then
                    groups[group_key] = {
                        name = name,
                        variant = var_name,
                        category = item_type,
                        id = itm.Id,
                        uuid = itm.UUID or "No-UUID",
                        is_locked = is_locked,
                        lock_type = l_type,
                        reasons = reasons,
                        quantity = 0,
                        sample_meta = itm.Metadata,
                    }
                    table_insert(group_order, group_key)
                end
                groups[group_key].quantity = groups[group_key].quantity + qty
            end
        end
    end

    local item_key_list = {}
    for k in pairs(all_item_keys) do table_insert(item_key_list, k) end
    table_sort(item_key_list)

    local meta_key_list = {}
    for k in pairs(all_meta_keys) do table_insert(meta_key_list, k) end
    table_sort(meta_key_list)

    local cards_data = {}
    for _, g_key in ipairs(group_order) do
        table_insert(cards_data, groups[g_key])
    end

    table_sort(cards_data, function(a, b)
        if a.is_locked ~= b.is_locked then
            return a.is_locked == true
        end
        return a.name < b.name
    end)

    return {
        target = filter_mode,
        total = total_count,
        locked_count = locked_count,
        unlocked_count = unlocked_count,
        cards = cards_data,
        item_keys = item_key_list,
        metadata_keys = meta_key_list,
    }
end

local parent_gui = (gethui and gethui()) or game:GetService("CoreGui")
pcall(function()
    local old = parent_gui:FindFirstChild("FishIt_LockInspector")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "FishIt_LockInspector"
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
floating_btn.Text = "K"
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
title_lbl.Text = "KEENAN - Trade Lock Scan"
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

local filter_row = Instance.new("Frame")
filter_row.Size = UDim2.new(1, -20, 0, 24)
filter_row.Position = UDim2.new(0, 10, 0, 34)
filter_row.BackgroundTransparency = 1
filter_row.Parent = main

local current_filter = "Fish"
local filter_buttons = {}

local function create_filter_btn(name, target_key, x_scale, width_scale)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(width_scale, 0, 1, 0)
    btn.Position = UDim2.new(x_scale, 0, 0, 0)
    btn.BackgroundColor3 = (current_filter == target_key) and BUTTON_COLOR or CARD_COLOR
    btn.Text = name
    btn.TextColor3 = (current_filter == target_key) and Color3.fromRGB(255, 255, 255) or MUTED_COLOR
    btn.TextSize = 10.5
    btn.FontFace = font_bold
    btn.Parent = filter_row
    create_corner(btn, 5); create_stroke(btn, Color3.fromRGB(45, 45, 45))
    filter_buttons[target_key] = btn
    return btn
end

local btn_fish    = create_filter_btn("Fish", "Fish", 0, 0.32)
local btn_enchant = create_filter_btn("Enchant Stones", "Enchant", 0.34, 0.32)
local btn_all     = create_filter_btn("All", "All", 0.68, 0.32)

local function update_filter_ui(target_key)
    current_filter = target_key
    for k, btn in pairs(filter_buttons) do
        local is_active = (k == current_filter)
        btn.BackgroundColor3 = is_active and BUTTON_COLOR or CARD_COLOR
        btn.TextColor3 = is_active and Color3.fromRGB(255, 255, 255) or MUTED_COLOR
    end
end

btn_fish.MouseButton1Click:Connect(function() update_filter_ui("Fish") end)
btn_enchant.MouseButton1Click:Connect(function() update_filter_ui("Enchant") end)
btn_all.MouseButton1Click:Connect(function() update_filter_ui("All") end)

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
    val.TextSize = 13
    val.FontFace = font_bold
    val.TextXAlignment = Enum.TextXAlignment.Left
    val.Parent = card

    return val
end

local stat_total_val    = create_stat_card(stats_row, UDim2.new(0, 0, 0, 0), UDim2.new(0.32, 0, 1, 0), "TOTAL ITEMS", TEXT_COLOR)
local stat_locked_val   = create_stat_card(stats_row, UDim2.new(0.34, 0, 0, 0), UDim2.new(0.32, 0, 1, 0), "LOCKED", RED_COLOR)
local stat_tradable_val = create_stat_card(stats_row, UDim2.new(0.68, 0, 0, 0), UDim2.new(0.32, 0, 1, 0), "TRADABLE", GREEN_COLOR)

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

local empty_placeholder = Instance.new("TextLabel")
empty_placeholder.Size = UDim2.new(1, -10, 1, -10)
empty_placeholder.Position = UDim2.new(0, 5, 0, 5)
empty_placeholder.BackgroundTransparency = 1
empty_placeholder.Text = "Select a category above (Fish / Enchant Stones / All),\nthen click [Start Scan] below to inspect trade lock status."
empty_placeholder.TextColor3 = MUTED_COLOR
empty_placeholder.TextSize = 10.5
empty_placeholder.FontFace = font_face
empty_placeholder.TextYAlignment = Enum.TextYAlignment.Center
empty_placeholder.Parent = scroll

local scan_btn = Instance.new("TextButton")
scan_btn.Size = UDim2.new(1, -20, 0, 28)
scan_btn.Position = UDim2.new(0, 10, 1, -34)
scan_btn.BackgroundColor3 = BUTTON_COLOR
scan_btn.Text = "Start Scan"
scan_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
scan_btn.TextSize = 11.5
scan_btn.FontFace = font_bold
scan_btn.Parent = main
create_corner(scan_btn, 4)

local last_scan_data = nil

local function render_item_cards()
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    if not last_scan_data or not last_scan_data.cards or #last_scan_data.cards == 0 then
        local empty_lbl = Instance.new("TextLabel")
        empty_lbl.Size = UDim2.new(1, 0, 0, 60)
        empty_lbl.BackgroundTransparency = 1
        empty_lbl.Text = "No items found for this category."
        empty_lbl.TextColor3 = MUTED_COLOR
        empty_lbl.TextSize = 11
        empty_lbl.FontFace = font_bold
        empty_lbl.Parent = scroll
        scroll.CanvasSize = UDim2.new(0, 0, 0, 60)
        return
    end

    local rendered_count = 0

    for idx, card_info in ipairs(last_scan_data.cards) do
        rendered_count = rendered_count + 1

        local card_frame = Instance.new("Frame")
            card_frame.Size = UDim2.new(1, 0, 0, 48)
            card_frame.BackgroundColor3 = card_info.is_locked and Color3.fromRGB(28, 18, 20) or CARD_COLOR
            card_frame.Parent = scroll
            create_corner(card_frame, 5)
            create_stroke(card_frame, card_info.is_locked and Color3.fromRGB(110, 35, 40) or Color3.fromRGB(38, 38, 38))

            local display_title = card_info.name .. (card_info.variant and (" [" .. card_info.variant .. "]") or "")
            local name_lbl = Instance.new("TextLabel")
            name_lbl.Size = UDim2.new(1, -125, 0, 16)
            name_lbl.Position = UDim2.new(0, 8, 0, 3)
            name_lbl.BackgroundTransparency = 1
            name_lbl.Text = display_title
            name_lbl.TextColor3 = card_info.is_locked and Color3.fromRGB(255, 180, 180) or TEXT_COLOR
            name_lbl.TextSize = 10.5
            name_lbl.FontFace = font_bold
            name_lbl.TextXAlignment = Enum.TextXAlignment.Left
            name_lbl.TextTruncate = Enum.TextTruncate.AtEnd
            name_lbl.Parent = card_frame

            local sub_lbl = Instance.new("TextLabel")
            sub_lbl.Size = UDim2.new(1, -125, 0, 14)
            sub_lbl.Position = UDim2.new(0, 8, 0, 18)
            sub_lbl.BackgroundTransparency = 1
            local reason_desc = #card_info.reasons > 0 and (" (" .. table_concat(card_info.reasons, ", ") .. ")") or ""
            sub_lbl.Text = string_format("ID: %s • %s • Qty: x%d%s", tostring(card_info.id), card_info.category, card_info.quantity, reason_desc)
            sub_lbl.TextColor3 = card_info.is_locked and RED_COLOR or MUTED_COLOR
            sub_lbl.TextSize = 9
            sub_lbl.FontFace = font_face
            sub_lbl.TextXAlignment = Enum.TextXAlignment.Left
            sub_lbl.TextTruncate = Enum.TextTruncate.AtEnd
            sub_lbl.Parent = card_frame

            local meta_lbl = Instance.new("TextLabel")
            meta_lbl.Size = UDim2.new(1, -125, 0, 12)
            meta_lbl.Position = UDim2.new(0, 8, 0, 32)
            meta_lbl.BackgroundTransparency = 1
            local meta_parts = {}
            if type(card_info.sample_meta) == "table" then
                for k, v in pairs(card_info.sample_meta) do
                    local str_val = tostring(v)
                    if k == "TradeLock" and type(v) == "table" and v.Time then
                        str_val = string_format("{Time=%s}", tostring(v.Time))
                    end
                    table_insert(meta_parts, tostring(k) .. ": " .. str_val)
                end
            end
            meta_lbl.Text = #meta_parts > 0 and ("Meta: " .. table_concat(meta_parts, ", ")) or "Meta: (None)"
            meta_lbl.TextColor3 = Color3.fromRGB(130, 130, 130)
            meta_lbl.TextSize = 8.5
            meta_lbl.FontFace = font_face
            meta_lbl.TextXAlignment = Enum.TextXAlignment.Left
            meta_lbl.TextTruncate = Enum.TextTruncate.AtEnd
            meta_lbl.Parent = card_frame

            local badge_pill = Instance.new("Frame")
            badge_pill.Size = UDim2.new(0, 105, 0, 22)
            badge_pill.Position = UDim2.new(1, -112, 0.5, -11)
            badge_pill.BackgroundColor3 = card_info.is_locked and Color3.fromRGB(60, 20, 25) or Color3.fromRGB(18, 48, 28)
            badge_pill.Parent = card_frame
            create_corner(badge_pill, 4)
            create_stroke(badge_pill, card_info.is_locked and Color3.fromRGB(130, 35, 45) or Color3.fromRGB(30, 95, 50))

            local badge_lbl = Instance.new("TextLabel")
            badge_lbl.Size = UDim2.new(1, -4, 1, 0)
            badge_lbl.Position = UDim2.new(0, 2, 0, 0)
            badge_lbl.BackgroundTransparency = 1
            if card_info.is_locked then
                badge_lbl.Text = "LOCKED"
                badge_lbl.TextColor3 = RED_COLOR
            else
                badge_lbl.Text = "TRADABLE"
                badge_lbl.TextColor3 = GREEN_COLOR
            end
            badge_lbl.TextSize = 9.5
            badge_lbl.FontFace = font_bold
            badge_lbl.TextTruncate = Enum.TextTruncate.AtEnd
            badge_lbl.Parent = badge_pill
    end

    scroll.CanvasSize = UDim2.new(0, 0, 0, rendered_count * 52 + 10)
end

local function execute_scan()
    task_spawn(function()
        scan_btn.Text = "Scanning..."
        scan_btn.BackgroundColor3 = Color3.fromRGB(160, 60, 15)
        task_wait(0.05)

        local data, err = perform_inventory_scan(current_filter)
        if not data then
            scan_btn.Text = "Failed: " .. tostring(err)
            task_wait(2)
            scan_btn.Text = "Start Scan"
            scan_btn.BackgroundColor3 = BUTTON_COLOR
            return
        end

        last_scan_data = data

        stat_total_val.Text = tostring(data.total)
        stat_locked_val.Text = tostring(data.locked_count)
        stat_locked_val.TextColor3 = data.locked_count > 0 and RED_COLOR or MUTED_COLOR
        stat_tradable_val.Text = tostring(data.unlocked_count)

        render_item_cards()

        scan_btn.Text = "Start Scan"
        scan_btn.BackgroundColor3 = BUTTON_COLOR
    end)
end

scan_btn.MouseButton1Click:Connect(execute_scan)
