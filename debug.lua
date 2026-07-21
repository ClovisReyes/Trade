-- NØIR Hub - Simple Fish Price Debugger & Checker
-- Run this in Roblox executor to check exact fish prices and copy to clipboard

local players = game:GetService("Players")
local local_player = players.LocalPlayer
local replicated_storage = game:GetService("ReplicatedStorage")

-- Wait for PlayerGui
local player_gui = local_player:WaitForChild("PlayerGui", 10) or local_player:FindFirstChildOfClass("PlayerGui")
local parent_gui = gethui and gethui() or game:GetService("CoreGui") or player_gui

-- Destroy old UI if exists
local old = parent_gui:FindFirstChild("SimplePriceDebugger")
if old then old:Destroy() end

-- ScreenGui Setup
local gui = Instance.new("ScreenGui")
gui.Name = "SimplePriceDebugger"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2147483647
gui.Parent = parent_gui

-- Main Small Floating Window
local frame = Instance.new("Frame")
frame.Name = "Main"
frame.Size = UDim2.new(0, 380, 0, 260)
frame.Position = UDim2.new(0.5, -190, 0.3, 0)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local frame_corner = Instance.new("UICorner")
frame_corner.CornerRadius = UDim.new(0, 8)
frame_corner.Parent = frame

local frame_stroke = Instance.new("UIStroke")
frame_stroke.Color = Color3.fromRGB(255, 0, 255) -- Magenta Accent
frame_stroke.Thickness = 1.5
frame_stroke.Parent = frame

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 28)
title.Position = UDim2.new(0, 10, 0, 2)
title.BackgroundTransparency = 1
title.Text = "Fish Price Debugger"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 12
title.Font = Enum.Font.SourceSansBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

-- Close Button
local close_btn = Instance.new("TextButton")
close_btn.Size = UDim2.new(0, 20, 0, 20)
close_btn.Position = UDim2.new(1, -25, 0, 5)
close_btn.BackgroundColor3 = Color3.fromRGB(40, 15, 15)
close_btn.Text = "X"
close_btn.TextColor3 = Color3.fromRGB(255, 80, 80)
close_btn.TextSize = 11
close_btn.Font = Enum.Font.SourceSansBold
close_btn.Parent = frame

local close_c = Instance.new("UICorner")
close_c.CornerRadius = UDim.new(0.5, 0)
close_c.Parent = close_btn

close_btn.Activated:Connect(function()
    gui:Destroy()
end)

-- Text Area (MultiLine Output Box)
local text_box = Instance.new("TextBox")
text_box.Size = UDim2.new(1, -20, 0, 175)
text_box.Position = UDim2.new(0, 10, 0, 32)
text_box.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
text_box.Text = "Scanning inventory fish & prices..."
text_box.TextColor3 = Color3.fromRGB(0, 230, 255)
text_box.TextSize = 9
text_box.Font = Enum.Font.Code
text_box.MultiLine = true
text_box.ClearTextOnFocus = false
text_box.TextEditable = false
text_box.TextXAlignment = Enum.TextXAlignment.Left
text_box.TextYAlignment = Enum.TextYAlignment.Top
text_box.Parent = frame

local text_c = Instance.new("UICorner")
text_c.CornerRadius = UDim.new(0, 4)
text_c.Parent = text_box

-- Copy Button
local copy_btn = Instance.new("TextButton")
copy_btn.Size = UDim2.new(1, -20, 0, 35)
copy_btn.Position = UDim2.new(0, 10, 0, 215)
copy_btn.BackgroundColor3 = Color3.fromRGB(255, 0, 255)
copy_btn.Text = "COPY FISH PRICES TO CLIPBOARD"
copy_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
copy_btn.TextSize = 11
copy_btn.Font = Enum.Font.SourceSansBold
copy_btn.Parent = frame

local copy_c = Instance.new("UICorner")
copy_c.CornerRadius = UDim.new(0, 5)
copy_c.Parent = copy_btn

copy_btn.Activated:Connect(function()
    if setclipboard then
        setclipboard(text_box.Text)
        copy_btn.Text = "COPIED SUCCESSFULLY!"
    else
        copy_btn.Text = "FAILED (Select text inside box manually)"
    end
    task.wait(2)
    copy_btn.Text = "COPY FISH PRICES TO CLIPBOARD"
end)

-- Main Logic: Fetch Inventory Fish & Price Information
task.spawn(function()
    local lines = {}
    table.insert(lines, "=== FISH PRICE DEBUG REPORT ===")
    
    local replion_mod, item_utility, vendor_utility
    pcall(function()
        replion_mod = require(replicated_storage:WaitForChild("Packages"):WaitForChild("Replion"))
    end)
    pcall(function()
        item_utility = require(replicated_storage:WaitForChild("Shared"):WaitForChild("ItemUtility"))
    end)
    pcall(function()
        vendor_utility = require(replicated_storage:WaitForChild("Shared"):WaitForChild("VendorUtility"))
    end)

    local player_data
    pcall(function()
        player_data = replion_mod and replion_mod.Client:WaitReplion("Data")
    end)

    if not player_data then
        table.insert(lines, "Error: Player data (Replion) could not be loaded!")
        text_box.Text = table.concat(lines, "\n")
        return
    end

    local inventory = player_data:Get("Inventory")
    local items = inventory and inventory.Items or {}

    local fish_count = 0
    local total_value = 0

    for idx, item in ipairs(items) do
        if item and item.Id then
            local data
            pcall(function()
                data = item_utility and item_utility:GetItemData(item.Id)
            end)

            local item_type = data and data.Data and data.Data.Type
            if item_type == "Fish" then
                fish_count = fish_count + 1
                local fish_name = (data and data.Data and data.Data.Name) or "Unknown Fish"

                -- Test Price Resolution Methods
                local v_price = nil
                pcall(function() v_price = vendor_utility:GetSellPrice(item) end)
                if not v_price then
                    pcall(function() v_price = vendor_utility.GetSellPrice(item) end)
                end

                local base_price = data and data.Data and (data.Data.SellPrice or data.Data.Price) or 0
                local final_price = v_price or base_price or 0

                total_value = total_value + final_price

                -- Comprehensive Mutation & Variant Detection
                local mutation_detected = nil

                if item.Mutation and item.Mutation ~= "" and item.Mutation ~= "None" then
                    mutation_detected = tostring(item.Mutation)
                elseif item.Variant and item.Variant ~= "" and item.Variant ~= "None" then
                    mutation_detected = tostring(item.Variant)
                elseif item.VariantId and item.VariantId ~= "" then
                    mutation_detected = "VariantId: " .. tostring(item.VariantId)
                elseif item.Mutations and type(item.Mutations) == "table" and #item.Mutations > 0 then
                    mutation_detected = table.concat(item.Mutations, ", ")
                end

                local is_shiny = (item.Shiny == true or item.Shiny == 1 or (item.Shiny and tostring(item.Shiny):lower() ~= "false")) and " [Shiny]" or ""
                local is_big = (item.Big == true or item.Big == 1 or (item.Big and tostring(item.Big):lower() ~= "false")) and " [Big]" or ""
                local is_sparkling = (item.Sparkling == true or item.Sparkling == 1) and " [Sparkling]" or ""
                local fav = item.Favorited and " [Fav]" or ""
                local weight = item.Weight and string.format(" (Weight: %.1fkg)", tonumber(item.Weight) or 0) or ""

                -- Full Keys Dump for Deep Inspection
                local item_dump_str = ""
                local dump_ok, dump_res = pcall(function()
                    local http = game:GetService("HttpService")
                    return http:JSONEncode(item)
                end)
                if dump_ok and dump_res then
                    item_dump_str = " | RAW: " .. dump_res
                else
                    local k_list = {}
                    for k, v in pairs(item) do
                        table_insert(k_list, tostring(k) .. "=" .. tostring(v))
                    end
                    item_dump_str = " | KEYS: {" .. table_concat(k_list, ", ") .. "}"
                end

                local mut_str = mutation_detected or "None"

                table.insert(lines, string.format("[%d] %s%s%s%s%s%s | Price: %d (Base: %d) | Mut: %s%s", 
                    fish_count, fish_name, is_shiny, is_big, is_sparkling, fav, weight, final_price, base_price, mut_str, item_dump_str))
            end
        end
    end

    table.insert(lines, "==============================")
    table.insert(lines, string.format("TOTAL FISH: %d | TOTAL ESTIMATED VALUE: %d coins", fish_count, total_value))

    text_box.Text = table.concat(lines, "\n")
end)
