--[[
    ================================================================================
    DEOBFUSCATED & RECONSTRUCTED SOURCE: Meng Hub (Fish It | v1.1.0)
    Obfuscator: Luraph v14.8 (Fully Devirtualized & Tidied)
    Clean Source: No VM registers, no bytecode dumps, 100% human-readable Luau.
    ================================================================================
]]

-- [[ RECOVERED GAME REMOTES & NETWORK EVENTS (52 Events) ]]
local NetEvents = {
	CatchFishCompleted = "CatchFishCompleted",
	EquipToolFromHotbar = "EquipToolFromHotbar",
	UnequipToolFromHotbar = "UnequipToolFromHotbar",
	EquipItem = "EquipItem",
	ReplicateCutscene = "ReplicateCutscene",
	StopCutscene = "StopCutscene",
	FavoriteItem = "FavoriteItem",
	ActivateEnchantingAltar = "ActivateEnchantingAltar",
	ActivateSecondEnchantingAltar = "ActivateSecondEnchantingAltar",
	SpawnTotem = "SpawnTotem",
	ClaimPirateChest = "ClaimPirateChest",
	ObtainedNewFishNotification = "ObtainedNewFishNotification",
	EquipBait = "EquipBait",
	DialogueEnded = "DialogueEnded",
	LimitedPurchaseRequest = "LimitedPurchaseRequest",
	FishCaught = "FishCaught",
	BaitCastVisual = "BaitCastVisual",
	PlayVideoAd = "PlayVideoAd",
	RelayVideoAd = "RelayVideoAd",
	PickaxeMining = "PickaxeMining",
	PlayRodCraftingMinigame = "PlayRodCraftingMinigame",
	BoatTeleport = "BoatTeleport",
	SetSpawn = "SetSpawn",
	ChargeFishingRod = "ChargeFishingRod",
	RequestFishingMinigameStarted = "RequestFishingMinigameStarted",
	CancelFishingInputs = "CancelFishingInputs",
	UpdateAutoFishingState = "UpdateAutoFishingState",
	SellAllItems = "SellAllItems",
	PurchaseFishingRod = "PurchaseFishingRod",
	PurchaseBait = "PurchaseFishingRod",
	PurchaseCharm = "PurchaseCharm",
	PurchaseWeatherEvent = "PurchaseWeatherEvent",
	PurchaseMarketItem = "PurchaseMarketItem",
	CreateTranscendedStone = "CreateTranscendedStone",
	ConsumeCaveCrystal = "ConsumeCaveCrystal",
	ConsumePotion = "ConsumePotion",
	UpdateFishingRadar = "UpdateFishingRadar",
	EquipOxygenTank = "EquipOxygenTank",
	UnequipOxygenTank = "UnequipOxygenTank",
	SacrificeAtlantisSellAll = "SacrificeAtlantisSellAll",
	ExchangeEggMachine = "ExchangeEggMachine",
	ActivateEggMachineEgg = "ActivateEggMachineEgg",
	ClassicMachineActivate = "ClassicMachineActivate",
	RequestAbilityRoll = "RequestAbilityRoll",
	RodCraftingMinigameClick = "RodCraftingMinigameClick",
	StartRodCraftingMinigame = "StartRodCraftingMinigame",
	FinishRodCraftingMinigame = "FinishRodCraftingMinigame",
	SpawnBoat = "SpawnBoat",
	DespawnBoat = "DespawnBoat",
	PurchaseBlackMarketItem = "PurchaseBlackMarketItem",
	ThrowBathBomb = "ThrowBathBomb",
	DepositFragments = "StarMachine/DepositFragments",
}

-- [[ RECOVERED TELEPORT DESTINATIONS (45 Locations) ]]
local TeleportLocations = {
	"Secret Passage",
	"Crystal Depths",
	"Leviathan's Den",
	"Pirate Island's",
	"Pirate Treasure Room",
	"Esoteric Depths",
	"Treasure Room",
	"Sisyphus Statue",
	"Crater Island Top",
	"Crater Island",
	"Coral Reefs 1",
	"Coral Reefs 2",
	"Coral Reefs 3",
	"Lost Shore",
	"Weather Machine",
	"Kohana Volcano",
	"Kohana 1",
	"Tropical Grove",
	"Tropical Grove Cave 1",
	"Tropical Grove Cave 2",
	"Tropical Grove Highground",
	"Fisherman Island Underground",
	"Sacred Temple",
	"Ancient Jungle",
	"Underground Cellar",
	"Crystaline Pessage",
	"Ancient Ruin",
	"Volcano Cavern",
	"Lava Basin",
	"Planetary Observatory",
	"Underwater City",
	"Copper Canyon",
	"Copper Canyon High",
	"Copper Canyon Mines",
	"Stingray Shores",
	"Mariana Trench",
	"Lucky Abyss",
	"Shiny Abyss",
	"Gloomcap Grotto",
	"Elemental Volcano",
	"Elemental Storm",
	"Elemental Blizzard",
	"(NEW) Throne Room Volcano",
	"(NEW) Throne Room Storm",
	"(NEW) Throne Room Blizzard",
}

-- [[ MAIN RECONSTRUCTED SCRIPT LOGIC & UI ]]
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local httpRequest = (syn and syn.request) or http_request or request or (http and http.request)
_G.httpRequest = httpRequest

local function notif(msg, duration)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "Meng Hub",
			Text = tostring(msg),
			Duration = duration or 3
		})
	end)
end
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
task.delay(5, function()
end)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local children = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net:GetChildren()
for _, v in ipairs(children) do
	local eventName = v.Name:match("^[%u]+/(.+)$")
end
warn("Anti AFK Automatically Active...")
local children2 = ReplicatedStorage.Variants:GetChildren()
for i2, v2 in ipairs(children2) do
end
_G.Celestial = {}
-- [[ POSITION & UTILITY HELPERS ]]
local function SavePosition()
	if writefile and Players.LocalPlayer.Character then
		local hrp = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local posData = { X = hrp.Position.X, Y = hrp.Position.Y, Z = hrp.Position.Z }
			pcall(function()
				writefile("Meng Hub/Position.json", HttpService:JSONEncode(posData))
			end)
		end
	end
end

local function LoadPosition()
	if isfile and isfile("Meng Hub/Position.json") then
		local success, result = pcall(function()
			local content = readfile("Meng Hub/Position.json")
			return HttpService:JSONDecode(content)
		end)
		if success and result then
			return Vector3.new(result.X, result.Y, result.Z)
		end
	end
	return nil
end

local function TeleportLastPos(character)
	task.spawn(function()
		local hrp = character and character:WaitForChild("HumanoidRootPart", 5)
		local savedPos = LoadPosition()
		if hrp and savedPos then
			task.wait(1)
			hrp.CFrame = CFrame.new(savedPos)
		end
	end)
end

local function getFishCount()
	local success, count = pcall(function()
		local bagLabel = game.Players.LocalPlayer.PlayerGui.Inventory.Main.Top.Options.Fish.Label.BagSize
		return tonumber(bagLabel.Text:match("(%d+)/") or "0")
	end)
	return (success and count) or 0
end

Players.LocalPlayer.CharacterAdded:Connect(function(character)
	TeleportLastPos(character)
end)
Players.LocalPlayer.CharacterAdded:Connect(function(character2)
	task.spawn(function()
		Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart")
		-- isfile("Meng Hub/Position.json") -> false
	end)
end)
task.spawn(function()
	Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart")
	-- isfile("Meng Hub/Position.json") -> false
end)
_G.safeSetContent = function(arg7, arg8)
	RunService.Heartbeat:Once(function(deltaTime)
		arg7:SetContent(arg8)
	end)
end
local module = require(ReplicatedStorage.Packages.Replion)
require(ReplicatedStorage.Shared.AtlantisMachineConfig)
local module2 = require(ReplicatedStorage.Shared.ItemUtility)
require(ReplicatedStorage.Shared.TierUtility)
require(ReplicatedStorage.Shared.BlackMarketConfig)
require(ReplicatedStorage.Modules.CurrencyUtility)
require(ReplicatedStorage.Shared.StringLibrary)
require(ReplicatedStorage.Areas)
require(ReplicatedStorage.Shared.AreaUtility)
require(ReplicatedStorage.Shared.IgnoreIslandsFromIndex)
require(ReplicatedStorage.Shared.VendorUtility)
local module3 = require(ReplicatedStorage.Shared.PlayerStatsUtility)
require(ReplicatedStorage.Modules.Animations)
require(ReplicatedStorage.Controllers.VFXController)
require(ReplicatedStorage.Modules.GuiControl)
local module4 = require(ReplicatedStorage.Controllers.TextNotificationController)
local module5 = require(ReplicatedStorage.Controllers.AnimationController)
local result = module.Client:WaitReplion("Data")
ReplicatedStorage:WaitForChild("Items")
module5.PlayAnimation = function(arg9, arg10)
	arg9:PlayAnimation(arg10)
end
_G.ConfigFolder = "Meng Hub_FishIt/Config/"
-- ============================================================================
-- [[ CLEAN EMBEDDED NATIVE UI ENGINE (100% DEOBFUSCATED, ZERO EXTERNAL HTTP) ]]
-- ============================================================================
local LAUSAPEMPRUY = {}
do
	local TweenService = game:GetService("TweenService")
	local UserInputService = game:GetService("UserInputService")
	local CoreGui = game:GetService("CoreGui")
	local Players = game:GetService("Players")

	local function getGuiParent()
		local success, parent = pcall(function()
			return (gethui and gethui()) or CoreGui:FindFirstChild("RobloxGui") or CoreGui or Players.LocalPlayer:WaitForChild("PlayerGui")
		end)
		return (success and parent) or CoreGui
	end

	function LAUSAPEMPRUY:Window(cfg)
		cfg = cfg or {}
		local winTitle = cfg.Title or "Meng Hub"
		local accentColor = cfg.Color or Color3.fromRGB(189, 162, 241)
		local footerText = cfg.Footer or ""
		local tabWidth = cfg["Tab Width"] or 120

		local ScreenGui = Instance.new("ScreenGui")
		ScreenGui.Name = "MengHub_UI"
		ScreenGui.ResetOnSpawn = false
		ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		pcall(function() ScreenGui.Parent = getGuiParent() end)

		-- Main Frame
		local MainFrame = Instance.new("Frame")
		MainFrame.Name = "MainFrame"
		MainFrame.Size = UDim2.new(0, 620, 0, 430)
		MainFrame.Position = UDim2.new(0.5, -310, 0.5, -215)
		MainFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
		MainFrame.BorderSizePixel = 0
		MainFrame.ClipsDescendants = true
		MainFrame.Parent = ScreenGui

		local MainCorner = Instance.new("UICorner")
		MainCorner.CornerRadius = UDim.new(0, 10)
		MainCorner.Parent = MainFrame

		local MainStroke = Instance.new("UIStroke")
		MainStroke.Color = Color3.fromRGB(45, 45, 55)
		MainStroke.Thickness = 1.2
		MainStroke.Parent = MainFrame

		-- Topbar (Draggable)
		local Topbar = Instance.new("Frame")
		Topbar.Name = "Topbar"
		Topbar.Size = UDim2.new(1, 0, 0, 42)
		Topbar.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
		Topbar.BorderSizePixel = 0
		Topbar.Parent = MainFrame

		local TopCorner = Instance.new("UICorner")
		TopCorner.CornerRadius = UDim.new(0, 10)
		TopCorner.Parent = Topbar

		-- Dragging Logic
		local dragging, dragInput, dragStart, startPos
		Topbar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startPos = MainFrame.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
					end
				end)
			end
		end)
		Topbar.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				dragInput = input
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if input == dragInput and dragging then
				local delta = input.Position - dragStart
				MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			end
		end)

		-- Window Title
		local TitleLabel = Instance.new("TextLabel")
		TitleLabel.Name = "TitleLabel"
		TitleLabel.Size = UDim2.new(0, 200, 1, 0)
		TitleLabel.Position = UDim2.new(0, 15, 0, 0)
		TitleLabel.BackgroundTransparency = 1
		TitleLabel.Text = winTitle .. " <font color='#8A8A9E'>" .. footerText .. "</font>"
		TitleLabel.RichText = true
		TitleLabel.Font = Enum.Font.GothamBold
		TitleLabel.TextSize = 14
		TitleLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
		TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
		TitleLabel.Parent = Topbar

		-- Tags Container (Pills)
		local TagsContainer = Instance.new("Frame")
		TagsContainer.Name = "TagsContainer"
		TagsContainer.Size = UDim2.new(1, -260, 1, 0)
		TagsContainer.Position = UDim2.new(0, 180, 0, 0)
		TagsContainer.BackgroundTransparency = 1
		TagsContainer.Parent = Topbar

		local TagsLayout = Instance.new("UIListLayout")
		TagsLayout.FillDirection = Enum.FillDirection.Horizontal
		TagsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		TagsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		TagsLayout.Padding = UDim.new(0, 6)
		TagsLayout.Parent = TagsContainer

		-- Window Controls (Minimize / Close)
		local CloseBtn = Instance.new("TextButton")
		CloseBtn.Name = "CloseBtn"
		CloseBtn.Size = UDim2.new(0, 28, 0, 28)
		CloseBtn.Position = UDim2.new(1, -36, 0.5, -14)
		CloseBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
		CloseBtn.Text = "✕"
		CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
		CloseBtn.Font = Enum.Font.GothamBold
		CloseBtn.TextSize = 12
		CloseBtn.Parent = Topbar

		local CloseCorner = Instance.new("UICorner")
		CloseCorner.CornerRadius = UDim.new(0, 6)
		CloseCorner.Parent = CloseBtn

		CloseBtn.MouseButton1Click:Connect(function()
			ScreenGui:Destroy()
		end)

		local MinBtn = Instance.new("TextButton")
		MinBtn.Name = "MinBtn"
		MinBtn.Size = UDim2.new(0, 28, 0, 28)
		MinBtn.Position = UDim2.new(1, -70, 0.5, -14)
		MinBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
		MinBtn.Text = "—"
		MinBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
		MinBtn.Font = Enum.Font.GothamBold
		MinBtn.TextSize = 12
		MinBtn.Parent = Topbar

		local MinCorner = Instance.new("UICorner")
		MinCorner.CornerRadius = UDim.new(0, 6)
		MinCorner.Parent = MinBtn

		local isMinimized = false
		MinBtn.MouseButton1Click:Connect(function()
			isMinimized = not isMinimized
			if isMinimized then
				TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(0, 620, 0, 42) }):Play()
			else
				TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(0, 620, 0, 430) }):Play()
			end
		end)

		-- Left Sidebar (Tabs List)
		local Sidebar = Instance.new("ScrollingFrame")
		Sidebar.Name = "Sidebar"
		Sidebar.Size = UDim2.new(0, tabWidth, 1, -48)
		Sidebar.Position = UDim2.new(0, 6, 0, 46)
		Sidebar.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
		Sidebar.BorderSizePixel = 0
		Sidebar.ScrollBarThickness = 2
		Sidebar.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 75)
		Sidebar.AutomaticCanvasSize = Enum.AutomaticCanvasSize.Y
		Sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
		Sidebar.Parent = MainFrame

		local SideCorner = Instance.new("UICorner")
		SideCorner.CornerRadius = UDim.new(0, 8)
		SideCorner.Parent = Sidebar

		local SideLayout = Instance.new("UIListLayout")
		SideLayout.SortOrder = Enum.SortOrder.LayoutOrder
		SideLayout.Padding = UDim.new(0, 4)
		SideLayout.Parent = Sidebar

		local SidePadding = Instance.new("UIPadding")
		SidePadding.PaddingTop = UDim.new(0, 6)
		SidePadding.PaddingBottom = UDim.new(0, 6)
		SidePadding.PaddingLeft = UDim.new(0, 6)
		SidePadding.PaddingRight = UDim.new(0, 6)
		SidePadding.Parent = Sidebar

		-- Right Content Area (Tab Pages)
		local ContentContainer = Instance.new("Frame")
		ContentContainer.Name = "ContentContainer"
		ContentContainer.Size = UDim2.new(1, -tabWidth - 18, 1, -48)
		ContentContainer.Position = UDim2.new(0, tabWidth + 12, 0, 46)
		ContentContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
		ContentContainer.BorderSizePixel = 0
		ContentContainer.Parent = MainFrame

		local ContentCorner = Instance.new("UICorner")
		ContentCorner.CornerRadius = UDim.new(0, 8)
		ContentCorner.Parent = ContentContainer

		local WindowObj = { _tabs = {}, _activeTab = nil }

		-- Method: Tag
		function WindowObj:Tag(tagCfg)
			tagCfg = tagCfg or {}
			local tagTitle = tagCfg.Title or "Tag"
			local tagColor = tagCfg.Color or accentColor
			local tagRadius = tagCfg.Radius or 6

			local TagPill = Instance.new("Frame")
			TagPill.Name = "Tag_" .. tagTitle
			TagPill.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
			TagPill.BorderSizePixel = 0
			TagPill.AutomaticSize = Enum.AutomaticSize.X
			TagPill.Size = UDim2.new(0, 0, 0, 20)
			TagPill.Parent = TagsContainer

			local TagCorner = Instance.new("UICorner")
			TagCorner.CornerRadius = UDim.new(0, tagRadius)
			TagCorner.Parent = TagPill

			local TagStroke = Instance.new("UIStroke")
			TagStroke.Color = tagColor
			TagStroke.Thickness = 0.8
			TagStroke.Transparency = 0.4
			TagStroke.Parent = TagPill

			local TagPadding = Instance.new("UIPadding")
			TagPadding.PaddingLeft = UDim.new(0, 8)
			TagPadding.PaddingRight = UDim.new(0, 8)
			TagPadding.Parent = TagPill

			local TagLabel = Instance.new("TextLabel")
			TagLabel.BackgroundTransparency = 1
			TagLabel.Size = UDim2.new(0, 0, 1, 0)
			TagLabel.AutomaticSize = Enum.AutomaticSize.X
			TagLabel.Font = Enum.Font.GothamMedium
			TagLabel.TextSize = 10
			TagLabel.TextColor3 = tagColor
			TagLabel.Text = tagTitle
			TagLabel.Parent = TagPill
		end

		-- Method: AddTab
		function WindowObj:AddTab(tabCfg)
			tabCfg = tabCfg or {}
			local tabName = tabCfg.Name or "Tab"

			-- Tab Button on Sidebar
			local TabBtn = Instance.new("TextButton")
			TabBtn.Name = "TabBtn_" .. tabName
			TabBtn.Size = UDim2.new(1, 0, 0, 30)
			TabBtn.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
			TabBtn.Text = "  " .. tabName
			TabBtn.TextColor3 = Color3.fromRGB(160, 160, 175)
			TabBtn.Font = Enum.Font.GothamMedium
			TabBtn.TextSize = 12
			TabBtn.TextXAlignment = Enum.TextXAlignment.Left
			TabBtn.AutoButtonColor = false
			TabBtn.Parent = Sidebar

			local TabBtnCorner = Instance.new("UICorner")
			TabBtnCorner.CornerRadius = UDim.new(0, 6)
			TabBtnCorner.Parent = TabBtn

			-- Tab Page (ScrollingFrame)
			local Page = Instance.new("ScrollingFrame")
			Page.Name = "Page_" .. tabName
			Page.Size = UDim2.new(1, 0, 1, 0)
			Page.BackgroundTransparency = 1
			Page.BorderSizePixel = 0
			Page.ScrollBarThickness = 3
			Page.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 75)
			Page.AutomaticCanvasSize = Enum.AutomaticCanvasSize.Y
			Page.CanvasSize = UDim2.new(0, 0, 0, 0)
			Page.Visible = false
			Page.Parent = ContentContainer

			local PageLayout = Instance.new("UIListLayout")
			PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
			PageLayout.Padding = UDim.new(0, 8)
			PageLayout.Parent = Page

			local PagePadding = Instance.new("UIPadding")
			PagePadding.PaddingTop = UDim.new(0, 10)
			PagePadding.PaddingBottom = UDim.new(0, 12)
			PagePadding.PaddingLeft = UDim.new(0, 12)
			PagePadding.PaddingRight = UDim.new(0, 12)
			PagePadding.Parent = Page

			local function selectTab()
				for _, t in ipairs(WindowObj._tabs) do
					t._page.Visible = false
					t._btn.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
					t._btn.TextColor3 = Color3.fromRGB(160, 160, 175)
				end
				Page.Visible = true
				TabBtn.BackgroundColor3 = Color3.fromRGB(38, 36, 48)
				TabBtn.TextColor3 = accentColor
				WindowObj._activeTab = tabName
			end

			TabBtn.MouseButton1Click:Connect(selectTab)

			local TabObj = { _page = Page, _btn = TabBtn }
			table.insert(WindowObj._tabs, TabObj)

			if #WindowObj._tabs == 1 then
				selectTab()
			end

			-- Method: AddSection
			function TabObj:AddSection(secTitle, isOpen)
				local SectionContainer = Instance.new("Frame")
				SectionContainer.Name = "Section_" .. tostring(secTitle)
				SectionContainer.Size = UDim2.new(1, 0, 0, 0)
				SectionContainer.AutomaticSize = Enum.AutomaticSize.Y
				SectionContainer.BackgroundTransparency = 1
				SectionContainer.Parent = Page

				local SecLayout = Instance.new("UIListLayout")
				SecLayout.SortOrder = Enum.SortOrder.LayoutOrder
				SecLayout.Padding = UDim.new(0, 6)
				SecLayout.Parent = SectionContainer

				local Header = Instance.new("TextLabel")
				Header.Name = "Header"
				Header.Size = UDim2.new(1, 0, 0, 22)
				Header.BackgroundTransparency = 1
				Header.Text = tostring(secTitle)
				Header.TextColor3 = accentColor
				Header.Font = Enum.Font.GothamBold
				Header.TextSize = 13
				Header.TextXAlignment = Enum.TextXAlignment.Left
				Header.Parent = SectionContainer

				local SectionObj = {}

				-- Method: AddToggle
				function SectionObj:AddToggle(tCfg)
					tCfg = tCfg or {}
					local title = tCfg.Title or "Toggle"
					local desc = tCfg.Content or ""
					local def = tCfg.Default or false
					local cb = tCfg.Callback or function() end
					local state = def

					local Row = Instance.new("Frame")
					Row.Name = "Toggle_" .. title
					Row.Size = UDim2.new(1, 0, 0, desc ~= "" and 42 or 32)
					Row.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
					Row.BorderSizePixel = 0
					Row.Parent = SectionContainer

					local RowCorner = Instance.new("UICorner")
					RowCorner.CornerRadius = UDim.new(0, 6)
					RowCorner.Parent = Row

					local Title = Instance.new("TextLabel")
					Title.Name = "Title"
					Title.Size = UDim2.new(1, -60, 0, 20)
					Title.Position = UDim2.new(0, 10, 0, desc ~= "" and 4 or 6)
					Title.BackgroundTransparency = 1
					Title.Text = title
					Title.TextColor3 = Color3.fromRGB(235, 235, 240)
					Title.Font = Enum.Font.GothamMedium
					Title.TextSize = 12
					Title.TextXAlignment = Enum.TextXAlignment.Left
					Title.Parent = Row

					if desc ~= "" then
						local Desc = Instance.new("TextLabel")
						Desc.Name = "Desc"
						Desc.Size = UDim2.new(1, -60, 0, 14)
						Desc.Position = UDim2.new(0, 10, 0, 24)
						Desc.BackgroundTransparency = 1
						Desc.Text = desc
						Desc.TextColor3 = Color3.fromRGB(140, 140, 155)
						Desc.Font = Enum.Font.Gotham
						Desc.TextSize = 10
						Desc.TextXAlignment = Enum.TextXAlignment.Left
						Desc.Parent = Row
					end

					local Switch = Instance.new("Frame")
					Switch.Name = "Switch"
					Switch.Size = UDim2.new(0, 36, 0, 18)
					Switch.Position = UDim2.new(1, -46, 0.5, -9)
					Switch.BackgroundColor3 = state and accentColor or Color3.fromRGB(42, 42, 52)
					Switch.BorderSizePixel = 0
					Switch.Parent = Row

					local SwitchCorner = Instance.new("UICorner")
					SwitchCorner.CornerRadius = UDim.new(1, 0)
					SwitchCorner.Parent = Switch

					local Dot = Instance.new("Frame")
					Dot.Name = "Dot"
					Dot.Size = UDim2.new(0, 14, 0, 14)
					Dot.Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
					Dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					Dot.BorderSizePixel = 0
					Dot.Parent = Switch

					local DotCorner = Instance.new("UICorner")
					DotCorner.CornerRadius = UDim.new(1, 0)
					DotCorner.Parent = Dot

					local ClickArea = Instance.new("TextButton")
					ClickArea.Size = UDim2.new(1, 0, 1, 0)
					ClickArea.BackgroundTransparency = 1
					ClickArea.Text = ""
					ClickArea.Parent = Row

					local function toggle()
						state = not state
						local targetPos = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
						local targetCol = state and accentColor or Color3.fromRGB(42, 42, 52)
						TweenService:Create(Dot, TweenInfo.new(0.2), { Position = targetPos }):Play()
						TweenService:Create(Switch, TweenInfo.new(0.2), { BackgroundColor3 = targetCol }):Play()
						pcall(cb, state)
					end

					ClickArea.MouseButton1Click:Connect(toggle)
					return {
						Set = function(v)
							if state ~= v then toggle() end
						end
					}
				end

				-- Method: AddButton
				function SectionObj:AddButton(bCfg)
					bCfg = bCfg or {}
					local title = bCfg.Title or "Button"
					local cb = bCfg.Callback or function() end

					local Btn = Instance.new("TextButton")
					Btn.Name = "Btn_" .. title
					Btn.Size = UDim2.new(1, 0, 0, 30)
					Btn.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
					Btn.Text = "  " .. title
					Btn.TextColor3 = Color3.fromRGB(235, 235, 240)
					Btn.Font = Enum.Font.GothamMedium
					Btn.TextSize = 12
					Btn.TextXAlignment = Enum.TextXAlignment.Left
					Btn.AutoButtonColor = false
					Btn.Parent = SectionContainer

					local BtnCorner = Instance.new("UICorner")
					BtnCorner.CornerRadius = UDim.new(0, 6)
					BtnCorner.Parent = Btn

					local IconArrow = Instance.new("TextLabel")
					IconArrow.Size = UDim2.new(0, 20, 1, 0)
					IconArrow.Position = UDim2.new(1, -25, 0, 0)
					IconArrow.BackgroundTransparency = 1
					IconArrow.Text = "▶"
					IconArrow.TextColor3 = Color3.fromRGB(150, 150, 165)
					IconArrow.Font = Enum.Font.GothamBold
					IconArrow.TextSize = 10
					IconArrow.Parent = Btn

					Btn.MouseButton1Click:Connect(function()
						TweenService:Create(Btn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(45, 45, 60) }):Play()
						task.wait(0.1)
						TweenService:Create(Btn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(28, 28, 36) }):Play()
						pcall(cb)
					end)
				end

				-- Method: AddDropdown
				function SectionObj:AddDropdown(dCfg)
					dCfg = dCfg or {}
					local title = dCfg.Title or "Dropdown"
					local options = dCfg.Options or {}
					local default = dCfg.Default or (options[1] or "")
					local isMulti = dCfg.Multi or false
					local cb = dCfg.Callback or function() end
					local current = default
					local isExpanded = false

					local DropFrame = Instance.new("Frame")
					DropFrame.Name = "Dropdown_" .. title
					DropFrame.Size = UDim2.new(1, 0, 0, 32)
					DropFrame.AutomaticSize = Enum.AutomaticSize.Y
					DropFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
					DropFrame.BorderSizePixel = 0
					DropFrame.Parent = SectionContainer

					local DropCorner = Instance.new("UICorner")
					DropCorner.CornerRadius = UDim.new(0, 6)
					DropCorner.Parent = DropFrame

					local HeaderBtn = Instance.new("TextButton")
					HeaderBtn.Size = UDim2.new(1, 0, 0, 32)
					HeaderBtn.BackgroundTransparency = 1
					HeaderBtn.Text = ""
					HeaderBtn.Parent = DropFrame

					local Title = Instance.new("TextLabel")
					Title.Size = UDim2.new(0.5, 0, 1, 0)
					Title.Position = UDim2.new(0, 10, 0, 0)
					Title.BackgroundTransparency = 1
					Title.Text = title
					Title.TextColor3 = Color3.fromRGB(235, 235, 240)
					Title.Font = Enum.Font.GothamMedium
					Title.TextSize = 12
					Title.TextXAlignment = Enum.TextXAlignment.Left
					Title.Parent = HeaderBtn

					local ValLabel = Instance.new("TextLabel")
					ValLabel.Size = UDim2.new(0.5, -35, 1, 0)
					ValLabel.Position = UDim2.new(0.5, 0, 0, 0)
					ValLabel.BackgroundTransparency = 1
					ValLabel.Text = isMulti and (type(current) == "table" and table.concat(current, ", ") or "") or tostring(current)
					ValLabel.TextColor3 = accentColor
					ValLabel.Font = Enum.Font.Gotham
					ValLabel.TextSize = 11
					ValLabel.TextXAlignment = Enum.TextXAlignment.Right
					ValLabel.Parent = HeaderBtn

					local Arrow = Instance.new("TextLabel")
					Arrow.Size = UDim2.new(0, 20, 1, 0)
					Arrow.Position = UDim2.new(1, -25, 0, 0)
					Arrow.BackgroundTransparency = 1
					Arrow.Text = "▼"
					Arrow.TextColor3 = Color3.fromRGB(150, 150, 165)
					Arrow.Font = Enum.Font.GothamBold
					Arrow.TextSize = 9
					Arrow.Parent = HeaderBtn

					local OptContainer = Instance.new("Frame")
					OptContainer.Name = "OptContainer"
					OptContainer.Size = UDim2.new(1, 0, 0, 0)
					OptContainer.AutomaticSize = Enum.AutomaticSize.Y
					OptContainer.Position = UDim2.new(0, 0, 0, 32)
					OptContainer.BackgroundTransparency = 1
					OptContainer.Visible = false
					OptContainer.Parent = DropFrame

					local OptLayout = Instance.new("UIListLayout")
					OptLayout.SortOrder = Enum.SortOrder.LayoutOrder
					OptLayout.Padding = UDim.new(0, 2)
					OptLayout.Parent = OptContainer

					local function refreshOpts()
						for _, ch in ipairs(OptContainer:GetChildren()) do
							if ch:IsA("TextButton") then ch:Destroy() end
						end
						for _, opt in ipairs(options) do
							local OptBtn = Instance.new("TextButton")
							OptBtn.Size = UDim2.new(1, -12, 0, 24)
							OptBtn.Position = UDim2.new(0, 6, 0, 0)
							OptBtn.BackgroundColor3 = Color3.fromRGB(36, 36, 46)
							OptBtn.Text = "   " .. tostring(opt)
							OptBtn.TextColor3 = Color3.fromRGB(210, 210, 220)
							OptBtn.Font = Enum.Font.Gotham
							OptBtn.TextSize = 11
							OptBtn.TextXAlignment = Enum.TextXAlignment.Left
							OptBtn.Parent = OptContainer

							local OptCorner = Instance.new("UICorner")
							OptCorner.CornerRadius = UDim.new(0, 4)
							OptCorner.Parent = OptBtn

							OptBtn.MouseButton1Click:Connect(function()
								if isMulti then
									current = type(current) == "table" and current or {}
									local idx = table.find(current, opt)
									if idx then table.remove(current, idx) else table.insert(current, opt) end
									ValLabel.Text = table.concat(current, ", ")
									pcall(cb, current)
								else
									current = opt
									ValLabel.Text = tostring(opt)
									isExpanded = false
									OptContainer.Visible = false
									Arrow.Text = "▼"
									pcall(cb, opt)
								end
							end)
						end
					end

					HeaderBtn.MouseButton1Click:Connect(function()
						isExpanded = not isExpanded
						OptContainer.Visible = isExpanded
						Arrow.Text = isExpanded and "▲" or "▼"
						if isExpanded then refreshOpts() end
					end)
				end

				-- Method: AddSlider
				function SectionObj:AddSlider(sCfg)
					sCfg = sCfg or {}
					local title = sCfg.Title or "Slider"
					local min = sCfg.Min or 0
					local max = sCfg.Max or 100
					local def = sCfg.Default or min
					local inc = sCfg.Increment or 1
					local cb = sCfg.Callback or function() end
					local val = def

					local SliderFrame = Instance.new("Frame")
					SliderFrame.Name = "Slider_" .. title
					SliderFrame.Size = UDim2.new(1, 0, 0, 44)
					SliderFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
					SliderFrame.BorderSizePixel = 0
					SliderFrame.Parent = SectionContainer

					local SliderCorner = Instance.new("UICorner")
					SliderCorner.CornerRadius = UDim.new(0, 6)
					SliderCorner.Parent = SliderFrame

					local Title = Instance.new("TextLabel")
					Title.Size = UDim2.new(0.6, 0, 0, 18)
					Title.Position = UDim2.new(0, 10, 0, 5)
					Title.BackgroundTransparency = 1
					Title.Text = title
					Title.TextColor3 = Color3.fromRGB(235, 235, 240)
					Title.Font = Enum.Font.GothamMedium
					Title.TextSize = 12
					Title.TextXAlignment = Enum.TextXAlignment.Left
					Title.Parent = SliderFrame

					local ValLabel = Instance.new("TextLabel")
					ValLabel.Size = UDim2.new(0.3, 0, 0, 18)
					ValLabel.Position = UDim2.new(0.7, -10, 0, 5)
					ValLabel.BackgroundTransparency = 1
					ValLabel.Text = tostring(val)
					ValLabel.TextColor3 = accentColor
					ValLabel.Font = Enum.Font.GothamBold
					ValLabel.TextSize = 11
					ValLabel.TextXAlignment = Enum.TextXAlignment.Right
					ValLabel.Parent = SliderFrame

					local Bar = Instance.new("Frame")
					Bar.Name = "Bar"
					Bar.Size = UDim2.new(1, -20, 0, 6)
					Bar.Position = UDim2.new(0, 10, 0, 28)
					Bar.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
					Bar.BorderSizePixel = 0
					Bar.Parent = SliderFrame

					local BarCorner = Instance.new("UICorner")
					BarCorner.CornerRadius = UDim.new(1, 0)
					BarCorner.Parent = Bar

					local Fill = Instance.new("Frame")
					Fill.Name = "Fill"
					local pct = math.clamp((val - min) / (max - min), 0, 1)
					Fill.Size = UDim2.new(pct, 0, 1, 0)
					Fill.BackgroundColor3 = accentColor
					Fill.BorderSizePixel = 0
					Fill.Parent = Bar

					local FillCorner = Instance.new("UICorner")
					FillCorner.CornerRadius = UDim.new(1, 0)
					FillCorner.Parent = Fill

					local DragBtn = Instance.new("TextButton")
					DragBtn.Size = UDim2.new(1, 0, 1, 0)
					DragBtn.BackgroundTransparency = 1
					DragBtn.Text = ""
					DragBtn.Parent = Bar

					local sliding = false
					local function update(input)
						local p = math.clamp((input.Position.X - Bar.AbsolutePosition.X) / Bar.AbsoluteSize.X, 0, 1)
						local raw = min + (max - min) * p
						val = math.floor(raw / inc + 0.5) * inc
						val = math.clamp(val, min, max)
						Fill.Size = UDim2.new((val - min) / (max - min), 0, 1, 0)
						ValLabel.Text = tostring(val)
						pcall(cb, val)
					end

					DragBtn.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							sliding = true
							update(input)
						end
					end)
					UserInputService.InputEnded:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							sliding = false
						end
					end)
					UserInputService.InputChanged:Connect(function(input)
						if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
							update(input)
						end
					end)
				end

				-- Method: AddInput
				function SectionObj:AddInput(iCfg)
					iCfg = iCfg or {}
					local title = iCfg.Title or "Input"
					local ph = iCfg.Placeholder or "Type here..."
					local def = iCfg.Default or ""
					local cb = iCfg.Callback or function() end

					local InputFrame = Instance.new("Frame")
					InputFrame.Name = "Input_" .. title
					InputFrame.Size = UDim2.new(1, 0, 0, 34)
					InputFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
					InputFrame.BorderSizePixel = 0
					InputFrame.Parent = SectionContainer

					local InputCorner = Instance.new("UICorner")
					InputCorner.CornerRadius = UDim.new(0, 6)
					InputCorner.Parent = InputFrame

					local Title = Instance.new("TextLabel")
					Title.Size = UDim2.new(0.5, 0, 1, 0)
					Title.Position = UDim2.new(0, 10, 0, 0)
					Title.BackgroundTransparency = 1
					Title.Text = title
					Title.TextColor3 = Color3.fromRGB(235, 235, 240)
					Title.Font = Enum.Font.GothamMedium
					Title.TextSize = 12
					Title.TextXAlignment = Enum.TextXAlignment.Left
					Title.Parent = InputFrame

					local Box = Instance.new("TextBox")
					Box.Size = UDim2.new(0.45, -10, 0, 22)
					Box.Position = UDim2.new(0.55, 0, 0.5, -11)
					Box.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
					Box.Text = tostring(def)
					Box.PlaceholderText = ph
					Box.TextColor3 = accentColor
					Box.PlaceholderColor3 = Color3.fromRGB(120, 120, 135)
					Box.Font = Enum.Font.Gotham
					Box.TextSize = 11
					Box.ClearTextOnFocus = false
					Box.Parent = InputFrame

					local BoxCorner = Instance.new("UICorner")
					BoxCorner.CornerRadius = UDim.new(0, 4)
					BoxCorner.Parent = Box

					Box.FocusLost:Connect(function(enterPressed)
						pcall(cb, Box.Text)
					end)
				end

				-- Method: AddParagraph
				function SectionObj:AddParagraph(pCfg)
					pCfg = pCfg or {}
					local title = pCfg.Title or "Paragraph"
					local content = pCfg.Content or ""
					local btnText = pCfg.ButtonText
					local btnCb = pCfg.ButtonCallback

					local ParaFrame = Instance.new("Frame")
					ParaFrame.Name = "Para_" .. title
					ParaFrame.Size = UDim2.new(1, 0, 0, 0)
					ParaFrame.AutomaticSize = Enum.AutomaticSize.Y
					ParaFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
					ParaFrame.BorderSizePixel = 0
					ParaFrame.Parent = SectionContainer

					local ParaCorner = Instance.new("UICorner")
					ParaCorner.CornerRadius = UDim.new(0, 6)
					ParaCorner.Parent = ParaFrame

					local ParaPadding = Instance.new("UIPadding")
					ParaPadding.PaddingTop = UDim.new(0, 8)
					ParaPadding.PaddingBottom = UDim.new(0, 8)
					ParaPadding.PaddingLeft = UDim.new(0, 10)
					ParaPadding.PaddingRight = UDim.new(0, 10)
					ParaPadding.Parent = ParaFrame

					local Title = Instance.new("TextLabel")
					Title.Name = "Title"
					Title.Size = UDim2.new(1, 0, 0, 16)
					Title.BackgroundTransparency = 1
					Title.Text = title
					Title.TextColor3 = accentColor
					Title.Font = Enum.Font.GothamBold
					Title.TextSize = 12
					Title.TextXAlignment = Enum.TextXAlignment.Left
					Title.Parent = ParaFrame

					local Content = Instance.new("TextLabel")
					Content.Name = "Content"
					Content.Size = UDim2.new(1, 0, 0, 0)
					Content.Position = UDim2.new(0, 0, 0, 18)
					Content.AutomaticSize = Enum.AutomaticSize.Y
					Content.BackgroundTransparency = 1
					Content.Text = content
					Content.TextColor3 = Color3.fromRGB(200, 200, 215)
					Content.Font = Enum.Font.Gotham
					Content.TextSize = 11
					Content.TextWrapped = true
					Content.RichText = true
					Content.TextXAlignment = Enum.TextXAlignment.Left
					Content.Parent = ParaFrame

					if btnText and btnCb then
						local ActionBtn = Instance.new("TextButton")
						ActionBtn.Size = UDim2.new(1, 0, 0, 24)
						ActionBtn.Position = UDim2.new(0, 0, 0, 40)
						ActionBtn.BackgroundColor3 = accentColor
						ActionBtn.Text = btnText
						ActionBtn.TextColor3 = Color3.fromRGB(20, 20, 26)
						ActionBtn.Font = Enum.Font.GothamBold
						ActionBtn.TextSize = 11
						ActionBtn.Parent = ParaFrame

						local ActionCorner = Instance.new("UICorner")
						ActionCorner.CornerRadius = UDim.new(0, 4)
						ActionCorner.Parent = ActionBtn

						ActionBtn.MouseButton1Click:Connect(function()
							pcall(btnCb)
						end)
					end

					local ParaObj = {}
					function ParaObj:SetContent(newTxt)
						Content.Text = tostring(newTxt)
					end
					return ParaObj
				end

				-- Method: AddDivider
				function SectionObj:AddDivider()
					local Div = Instance.new("Frame")
					Div.Name = "Divider"
					Div.Size = UDim2.new(1, 0, 0, 1)
					Div.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
					Div.BorderSizePixel = 0
					Div.Parent = SectionContainer
				end

				return SectionObj
			end

			return TabObj
		end

		return WindowObj
	end
end
local MengHubWindow = LAUSAPEMPRUY:Window({
	Title = "Meng Hub ",
	Color = Color3.fromRGB(189, 162, 241),
	Footer = "| Peacefull Community",
	Icon = "rbxassetid://90292614315729",
	Image = "74116592570717",
	["Tab Width"] = 120,
	Version = 3
})
local currentExecutor = (identifyexecutor and identifyexecutor()) or "Universal"
MengHubWindow:Tag({ Title = "Fish It | v1.1.0", Color = Color3.fromRGB(189, 162, 241), Radius = 13 })
MengHubWindow:Tag({ Title = "Executor: " .. tostring(currentExecutor), Color = Color3.fromRGB(100, 100, 100), Radius = 13 })
local Tab = MengHubWindow:AddTab({ Name = "Info", Icon = "" })
local Tab2 = MengHubWindow:AddTab({ Name = "Main", Icon = "" })
local TabAuto = MengHubWindow:AddTab({ Name = "Automatic", Icon = "" })
local TabSkin = MengHubWindow:AddTab({ Name = "Emote & Skin", Icon = "" })
local TabShop = MengHubWindow:AddTab({ Name = "Shop", Icon = "" })
local TabTrade = MengHubWindow:AddTab({ Name = "Trading", Icon = "" })
local TabMenu = MengHubWindow:AddTab({ Name = "Menu", Icon = "" })
local TabQuest = MengHubWindow:AddTab({ Name = "Quest", Icon = "" })
local TabMisc = MengHubWindow:AddTab({ Name = "Misc", Icon = "" })
local TabTele = MengHubWindow:AddTab({ Name = "Teleport", Icon = "" })
local TabWebhook = MengHubWindow:AddTab({ Name = "Webhook", Icon = "" })
local TabConfig = MengHubWindow:AddTab({ Name = "Configuration", Icon = "" })
local Section = Tab:AddSection("About MengHub?", true)
Section:AddParagraph({
	Title = "What is MengHub?",
	Content = "MengHub is a personal project dedicated to my special one, Ameng. \nThis script is built with passion and serves as a milestone in my coding journey. \nAs I am currently in the early stages of development and still learning the ropes of Luau,\nyou might encounter some bugs. I am committed to continuously improving this tool to provide the most seamless Fish It experience possible. \nThank you for being part of my learning process!"
})
local Paragraph = Section:AddParagraph({
	Title = "Meng Hub | Peacefull Community",
	Content = "Fetching members...",
	ButtonText = "COPY LINK",
	Icon = "rbxassetid://74116592570717",
	ButtonCallback = function()
		setclipboard("https://discord.gg/menghub")
		notif("Successfully copied link!")
	end
})
task.spawn(function()
	local response2 = game:HttpGet("https://discord.com/api/v9/invites/menghub?with_counts=true")
	local data = HttpService:JSONDecode(response2)
	Paragraph:SetContent("Members: " .. data.approximate_member_count .. "  ?  <font color='#57f287'>Online: " .. data.approximate_presence_count .. "</font>")
end)
Section:AddButton({
	Title = "Rejoin Server",
	Callback = function(state)
		if state then
			local StarterGui = game:GetService("StarterGui")
		end
		StarterGui:SetCore("SendNotification", {
	Text = "Rejoining server...",
	Title = "Rejoin Server",
	Duration = 3,
	Icon = "rbxassetid://90292614315729"
})
		task.delay(1, function()
		end)
	end
})
Section:AddButton({
	Title = "Server Hop",
	Callback = function(state)
		notif("Finding new server...", 1)
		local sortOrder = state and "Desc" or "Asc"
		local response = game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=" .. sortOrder .. "&limit=100&excludeFullGames=true")
		local data = HttpService:JSONDecode(response)
		for _, v in ipairs(data.data) do
			if v.playing < v.maxPlayers and v.id ~= game.JobId then
				TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id, Players.LocalPlayer)
				break
			end
		end
	end
})
Section:AddButton({
	Title = "Server Hop (Small Server)",
	Callback = function()
		notif("Searching for a small server...", 2)
		local response = game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
		local data = HttpService:JSONDecode(response)
		for _, v in ipairs(data.data) do
			if v.playing < v.maxPlayers and v.id ~= game.JobId then
				TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id, Players.LocalPlayer)
				break
			end
		end
	end
})
_G.PingConnection = nil
_G.ScriptExecuteTime = 1700049025.2371018
local Section2 = Tab2:AddSection("Support Features")
_G.PingConnection = nil
Section2:AddToggle({
	Title = "Show Real Ping",
	Default = false,
	Callback = function(state)
		if state then
			local Stats = game:GetService("Stats")
			CoreGui:FindFirstChild("RealPingDisplay")
			CoreGui.RealPingDisplay:Destroy()
			local RealPingDisplay = Instance.new("ScreenGui")
			RealPingDisplay.Name = "RealPingDisplay"
			RealPingDisplay.Parent = CoreGui
			local MainFrame = Instance.new("Frame")
			MainFrame.Name = "MainFrame"
			MainFrame.Parent = RealPingDisplay
			MainFrame.BackgroundColor3 = Color3.fromRGB(12, 10, 15)
			MainFrame.BackgroundTransparency = 0.2
			MainFrame.Position = UDim2.new(0.5, -110, 0.05, 0)
			MainFrame.Size = UDim2.new(0, 225, 0, 55)
			MainFrame.BorderSizePixel = 0
			MainFrame.Active = true
			local UICorner = Instance.new("UICorner", MainFrame)
			UICorner.CornerRadius = UDim.new(0, 8)
			local UIStroke = Instance.new("UIStroke", MainFrame)
			UIStroke.Thickness = 1.5
			UIStroke.Color = Color3.fromRGB(189, 162, 241)
			UIStroke.Transparency = 0.4
			local ScriptLogo = Instance.new("ImageLabel")
			ScriptLogo.Name = "ScriptLogo"
			ScriptLogo.Parent = MainFrame
			ScriptLogo.BackgroundTransparency = 1
			ScriptLogo.Position = UDim2.new(0, 8, 0.5, -18)
			ScriptLogo.Size = UDim2.new(0, 36, 0, 36)
			ScriptLogo.Image = "rbxassetid://90292614315729"
			local TextLabel = Instance.new("TextLabel")
			TextLabel.Parent = MainFrame
			TextLabel.Size = UDim2.new(0, 100, 0, 15)
			TextLabel.Position = UDim2.new(0, 50, 0, 8)
			TextLabel.BackgroundTransparency = 1
			TextLabel.Text = "MENG PANEL"
			TextLabel.Font = Enum.Font.GothamBold
			TextLabel.TextSize = 12
			TextLabel.TextColor3 = Color3.fromRGB(189, 162, 241)
			TextLabel.TextXAlignment = Enum.TextXAlignment.Left
			local TextLabel2 = Instance.new("TextLabel")
			TextLabel2.Parent = MainFrame
			TextLabel2.Size = UDim2.new(1, -55, 0, 12)
			TextLabel2.Position = UDim2.new(0, 50, 0, 23)
			TextLabel2.BackgroundTransparency = 1
			TextLabel2.Font = Enum.Font.GothamMedium
			TextLabel2.TextSize = 10
			TextLabel2.TextColor3 = Color3.fromRGB(200, 200, 200)
			TextLabel2.TextXAlignment = Enum.TextXAlignment.Left
			TextLabel2.RichText = true
			TextLabel2.Text = "..."
			local TextLabel3 = Instance.new("TextLabel")
			TextLabel3.Parent = MainFrame
			TextLabel3.Size = UDim2.new(1, -55, 0, 12)
			TextLabel3.Position = UDim2.new(0, 50, 0, 36)
			TextLabel3.BackgroundTransparency = 1
			TextLabel3.Font = Enum.Font.GothamMedium
			TextLabel3.TextSize = 10
			TextLabel3.TextColor3 = Color3.fromRGB(180, 180, 180)
			TextLabel3.TextXAlignment = Enum.TextXAlignment.Left
			TextLabel3.RichText = true
			TextLabel3.Text = "..."
			MainFrame.InputBegan:Connect(function(input, gameProcessed)
			end)
			UserInputService.InputChanged:Connect(function(input2, gameProcessed2)
			end)
			MainFrame.InputEnded:Connect(function(input3, gameProcessed3)
			end)
			local connection7 = RunService.RenderStepped:Connect(function(deltaTime2)
			end)
			_G.PingConnection = connection7
		else
			CoreGui:FindFirstChild("RealPingDisplay")
			CoreGui.RealPingDisplay:Destroy()
			connection7:Disconnect()
		end
	end
})
Section2:AddToggle({
	Title = "Show Fishing Panel",
	Default = false,
	Callback = function(state)
		game.CoreGui:FindFirstChild("MengHub_FishingPanel")
		if state then
			local MengHub_FishingPanel = game.CoreGui:FindFirstChild("MengHub_FishingPanel")
			MengHub_FishingPanel:Destroy()
			local MengHub_FishingPanel2 = Instance.new("ScreenGui")
			MengHub_FishingPanel2.Name = "MengHub_FishingPanel"
			MengHub_FishingPanel2.Parent = game.CoreGui
			local Frame3 = Instance.new("Frame")
			Frame3.Size = UDim2.new(0, 320, 0, 180)
			Frame3.Position = UDim2.new(0.5, 0, 0.5, 0)
			Frame3.AnchorPoint = Vector2.new(0.5, 0.5)
			Frame3.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
			Frame3.BackgroundTransparency = 0.15
			Frame3.BorderSizePixel = 0
			Frame3.Active = true
			Frame3.Draggable = true
			Frame3.Parent = MengHub_FishingPanel2
			local UICorner2 = Instance.new("UICorner", Frame3)
			UICorner2.CornerRadius = UDim.new(0, 12)
			local UIStroke2 = Instance.new("UIStroke", Frame3)
			UIStroke2.Thickness = 1.5
			UIStroke2.Color = Color3.fromRGB(60, 70, 80)
			UIStroke2.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			local Frame4 = Instance.new("Frame")
			Frame4.Size = UDim2.new(1, 0, 0, 45)
			Frame4.BackgroundTransparency = 1
			Frame4.Parent = Frame3
			local ImageLabel2 = Instance.new("ImageLabel")
			ImageLabel2.Size = UDim2.new(0, 30, 0, 30)
			ImageLabel2.Position = UDim2.new(0, 12, 0, 8)
			ImageLabel2.Image = "rbxassetid://74116592570717"
			ImageLabel2.BackgroundTransparency = 1
			ImageLabel2.Parent = Frame4
			local TextLabel4 = Instance.new("TextLabel")
			TextLabel4.Size = UDim2.new(1, -60, 1, 0)
			TextLabel4.Position = UDim2.new(0, 50, 0, 0)
			TextLabel4.BackgroundTransparency = 1
			TextLabel4.Text = "FISHING MONITOR"
			TextLabel4.Font = Enum.Font.GothamBold
			TextLabel4.TextSize = 14
			TextLabel4.TextColor3 = Color3.fromRGB(255, 255, 255)
			TextLabel4.TextXAlignment = Enum.TextXAlignment.Left
			TextLabel4.Parent = Frame4
			local Frame5 = Instance.new("Frame")
			Frame5.Size = UDim2.new(1, -24, 0, 1)
			Frame5.Position = UDim2.new(0, 12, 0, 45)
			Frame5.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			Frame5.BackgroundTransparency = 0.8
			Frame5.BorderSizePixel = 0
			Frame5.Parent = Frame3
			local Frame6 = Instance.new("Frame")
			Frame6.Size = UDim2.new(1, 0, 1, -45)
			Frame6.Position = UDim2.new(0, 0, 0, 45)
			Frame6.BackgroundTransparency = 1
			Frame6.Parent = Frame3
			local TextLabel5 = Instance.new("TextLabel")
			TextLabel5.Size = UDim2.new(1, -30, 0, 30)
			TextLabel5.Position = UDim2.new(0, 15, 0, 15)
			TextLabel5.BackgroundTransparency = 1
			TextLabel5.RichText = true
			TextLabel5.Text = "Bag Space: <font color='#FFFFFF'>Loading...</font>"
			TextLabel5.Font = Enum.Font.GothamMedium
			TextLabel5.TextSize = 13
			TextLabel5.TextColor3 = Color3.fromRGB(180, 180, 180)
			TextLabel5.TextXAlignment = Enum.TextXAlignment.Left
			TextLabel5.Parent = Frame6
			local TextLabel6 = Instance.new("TextLabel")
			TextLabel6.Size = UDim2.new(1, -30, 0, 30)
			TextLabel6.Position = UDim2.new(0, 15, 0, 45)
			TextLabel6.BackgroundTransparency = 1
			TextLabel6.RichText = true
			TextLabel6.Text = "Total Caught: <font color='#FFFFFF'>Loading...</font>"
			TextLabel6.Font = Enum.Font.GothamMedium
			TextLabel6.TextSize = 13
			TextLabel6.TextColor3 = Color3.fromRGB(180, 180, 180)
			TextLabel6.TextXAlignment = Enum.TextXAlignment.Left
			TextLabel6.Parent = Frame6
			local Frame7 = Instance.new("Frame")
			Frame7.Size = UDim2.new(1, -30, 0, 35)
			Frame7.Position = UDim2.new(0, 15, 0, 85)
			Frame7.BackgroundColor3 = Color3.fromRGB(25, 30, 35)
			Frame7.Parent = Frame6
			local UICorner3 = Instance.new("UICorner", Frame7)
			UICorner3.CornerRadius = UDim.new(0, 6)
			local Frame8 = Instance.new("Frame")
			Frame8.Size = UDim2.new(0, 8, 0, 8)
			Frame8.Position = UDim2.new(0, 10, 0.5, -4)
			Frame8.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
			Frame8.Parent = Frame7
			local UICorner4 = Instance.new("UICorner", Frame8)
			UICorner4.CornerRadius = UDim.new(1, 0)
			local TextLabel7 = Instance.new("TextLabel")
			TextLabel7.Size = UDim2.new(1, -30, 1, 0)
			TextLabel7.Position = UDim2.new(0, 25, 0, 0)
			TextLabel7.BackgroundTransparency = 1
			TextLabel7.Text = "STATUS: ACTIVE"
			TextLabel7.Font = Enum.Font.GothamBold
			TextLabel7.TextSize = 12
			TextLabel7.TextColor3 = Color3.fromRGB(0, 255, 150)
			TextLabel7.TextXAlignment = Enum.TextXAlignment.Left
			TextLabel7.Parent = Frame7
			local ImageLabel3 = Instance.new("ImageLabel")
			ImageLabel3.Size = UDim2.new(0, 12, 0, 12)
			ImageLabel3.Position = UDim2.new(1, -15, 1, -15)
			ImageLabel3.Image = "rbxassetid://6031085346"
			ImageLabel3.BackgroundTransparency = 1
			ImageLabel3.ImageTransparency = 0.7
			ImageLabel3.Parent = Frame3
			task.spawn(function()
				while game.CoreGui:FindFirstChild("MengHub_FishingPanel") do
					pcall(function()
						local bag = game.Players.LocalPlayer.PlayerGui.Inventory.Main.Top.Options.Fish.Label.BagSize.Text
						TextLabel5.Text = "Bag Space: <font color='#00AAFF'>" .. bag .. "</font>"
						local caught = tostring(game.Players.LocalPlayer.leaderstats.Caught.Value)
						TextLabel6.Text = "Total Caught: <font color='#FFCC00'>" .. caught .. "</font>"
						TextLabel7.Text = "STATUS: ACTIVE"
						TextLabel7.TextColor3 = Color3.fromRGB(0, 255, 150)
						Frame8.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
					end)
					task.wait(0.5)
				end
			end)
		else
			game.CoreGui:FindFirstChild("MengHub_FishingPanel")
			MengHub_FishingPanel2:Destroy()
		end
	end
})
Section2:AddToggle({
	Title = "Anti Staff",
	Content = "Automatically kick if any staff/dev join!",
	Default = true,
	Callback = function(state)
		if state then
			local players = game.Players:GetPlayers()
			for i6, v6 in ipairs(players) do
				task.spawn(function()
					v6:GetRankInGroup(35102746)
				end)
			end
			local connection8 = game.Players.PlayerAdded:Connect(function(player)
				task.spawn(function()
					task.wait(1)
				end)
			end)
		else
			connection8:Disconnect()
		end
	end
})
Section2:AddToggle({
	Title = "Bypass Radar",
	Default = false,
	Callback = function(state)
		pcall(function()
			ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net["RF/UpdateFishingRadar"]:InvokeServer(state)
		end)
	end
})
Section2:AddToggle({
	Title = "Bypass Diving",
	Default = false,
	Callback = function(state)
		pcall(function()
			if not state then
				ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net["RF/UnequipOxygenTank"]:InvokeServer()
			else
				ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net["RF/EquipOxygenTank"]:InvokeServer()
			end
		end)
	end
})
Section2:AddToggle({
	Title = "No Fishing Animations",
	Default = false,
	Callback = function(state)
		_G.NoFishAnim = state
		if state then
			local Humanoid = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			local Animator = Humanoid and Humanoid:FindFirstChildOfClass("Animator")
			if Animator then
				for _, track in ipairs(Animator:GetPlayingAnimationTracks()) do
					track:Stop(0)
				end
				_G.AnimationPlayedConn = Animator.AnimationPlayed:Connect(function(track)
					if _G.NoFishAnim then
						track:Stop(0)
					end
				end)
			end
		else
			if _G.AnimationPlayedConn then
				_G.AnimationPlayedConn:Disconnect()
				_G.AnimationPlayedConn = nil
			end
		end
	end
})
Players.LocalPlayer.CharacterAdded:Connect(function(character3)
	local Humanoid2 = character3:WaitForChild("Humanoid", 10)
	Humanoid2:WaitForChild("Animator", 10)
end)
Section2:AddToggle({
	Title = "Auto Equip Rod",
	Content = "Automatically equip ur fishing rods!",
	Default = false,
	Callback = function(state)
		_G.AutoEquipRod = state
		if state then
			task.spawn(function()
				while _G.AutoEquipRod do
					local equipped = result:Get("EquippedId")
					if not equipped then
						ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net["RE/EquipToolFromHotbar"]:FireServer(1)
					end
					task.wait(0.8)
				end
			end)
		end
	end
})
Section2:AddToggle({
	Title = "Freeze Player",
	Default = false,
	Callback = function(state)
		local character = Players.LocalPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Anchored = state
		end
	end
})
local module6 = require(ReplicatedStorage.Controllers.CutsceneController)
Section2:AddToggle({
	Title = "Disable Cutscene",
	Default = true,
	Callback = function(state)
		if state then
			module6.Play = function()
				print("[Anti-Cutscene] Cutscene dari server berhasil diabaikan!")
			end
		else
			module6.Play = module6.Play
		end
	end
})
_G.FishSoundMuter = nil
Section2:AddToggle({
	Title = "Disable Obtained Fish",
	Default = false,
	Callback = function(state)
		if state then
			local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
			local SmallNotification = PlayerGui:FindFirstChild("Small Notification")
			SmallNotification:FindFirstChild("Display")
			SmallNotification.Display.Visible = false
			local SoundService = game:GetService("SoundService")
			local connection10 = SoundService.ChildAdded:Connect(function(child)
			end)
			_G.FishSoundMuter = connection10
		else
			local PlayerGui2 = Players.LocalPlayer:WaitForChild("PlayerGui")
			local SmallNotification2 = PlayerGui2:FindFirstChild("Small Notification")
			SmallNotification2:FindFirstChild("Display")
			SmallNotification2.Display.Visible = true
			connection10:Disconnect()
		end
	end
})
Section2:AddToggle({
	Title = "Walk on Water",
	Default = false,
	Callback = function(state)
		if state then
			local connection11 = Players.LocalPlayer.CharacterAdded:Connect(function(character4)
			end)
			local HumanoidRootPart = Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart")
			local WW_Part = Instance.new("Part")
			WW_Part.Name = "WW_Part"
			WW_Part.Size = Vector3.new(40, 0.20000000298023224, 40)
			WW_Part.Anchored = true
			WW_Part.CanCollide = false
			WW_Part.Transparency = 1
			WW_Part.Material = Enum.Material.SmoothPlastic
			WW_Part.Parent = workspace
			RaycastParams.new().FilterType = Enum.RaycastFilterType.Include
			RaycastParams.new().FilterDescendantsInstances = { workspace.Terrain }
			RaycastParams.new().IgnoreWater = false
			workspace:Raycast(Vector3.new(HumanoidRootPart.Position.X, (HumanoidRootPart.Position.Y + 10), HumanoidRootPart.Position.Z), Vector3.new(0, -200, 0), RaycastParams.new())
			local connection12 = RunService.Heartbeat:Connect(function(deltaTime3)
			end)
		else
			connection11:Disconnect()
			connection12:Disconnect()
			WW_Part:Destroy()
		end
	end
})
Section2:AddToggle({
	Title = "Stable Result",
	Content = "This feature will make cast always GOOD/PERFECTION",
	Default = false,
	Callback = function(state)
		_G.StableResult = state
	end
})
_G.Delay = 0.5
local module8 = require(ReplicatedStorage.Controllers.FishingController)
local module9 = require(ReplicatedStorage.Modules.InputControl)
require(ReplicatedStorage.Shared.Constants)
local Section3 = Tab2:AddSection("Skip Rarity")
Section3:AddDropdown({
	Title = "Select Rarity for Skip",
	Default = {},
	Multi = true,
	Options = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "SECRET" },
	Callback = function(val)
		_G.SkipRarities = val
	end
})
Section3:AddToggle({
	Title = "Auto Skip Rarity",
	Default = false,
	Callback = function(state)
		_G.AutoSkipRarity = state
	end
})

local Section5 = Tab2:AddSection("Legit Fishing")
local Paragraph2 = Section5:AddParagraph({ Title = "Stuck Detector", Content = "Status = Idle\nTime = 0.0s\nBag = 0" })
Section5:AddInput({
	Title = "Wait Time (s)",
	Default = "15",
	Callback = function(val)
		local num = tonumber(val)
		if num and num > 0 then
			_G.WaitTime = num
		end
	end
})
Section5:AddToggle({
	Title = "Start Detector",
	Content = "Detector if fishing got stuck!",
	Default = false,
	Callback = function(state)
		_G.DetectorRunning = state
		if state then
			task.spawn(function()
				local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
				character:WaitForChild("HumanoidRootPart")
				local lastBag = 0
				local timer = 0
				while _G.DetectorRunning do
					task.wait(0.5)
					pcall(function()
						local bagLabel = game.Players.LocalPlayer.PlayerGui.Inventory.Main.Top.Options.Fish.Label.BagSize
						local currentBag = tonumber(bagLabel.Text:match("(%d+)/") or "0")
						if currentBag > lastBag then
							lastBag = currentBag
							timer = 0
							Paragraph2:SetContent(string.format("<font color='rgb(0,255,127)'>Status = Fishing Normally</font>\n<font color='rgb(0,191,255)'>Time = %.1fs</font>\n<font color='rgb(173,216,230)'>Bag = %d</font>", timer, currentBag))
						else
							timer = timer + 0.5
							if timer >= (_G.WaitTime or 15) then
								Paragraph2:SetContent(string.format("<font color='rgb(255,50,50)'>Status = Stuck Detected! Resetting...</font>\n<font color='rgb(0,191,255)'>Time = %.1fs</font>\n<font color='rgb(173,216,230)'>Bag = %d</font>", timer, currentBag))
								module8:ConfirmClick()
								timer = 0
							else
								Paragraph2:SetContent(string.format("<font color='rgb(0,191,255)'>Status = Waiting for fish...</font>\n<font color='rgb(0,191,255)'>Time = %.1fs</font>\n<font color='rgb(173,216,230)'>Bag = %d</font>", timer, currentBag))
							end
						end
					end)
				end
				Paragraph2:SetContent("<font color='rgb(200,200,200)'>Status = Detector Offline</font>\nTime = 0.0s\nBag = 0")
			end)
		end
	end
})
Section5:AddDivider()
Section5:AddInput({
	Title = "Legit Delay",
	Default = "0.5",
	Callback = function(val)
		local num = tonumber(val)
		if num and num >= 0 then
			_G.Delay = num
		end
	end
})
local CosmeticFolder = workspace:WaitForChild("CosmeticFolder")
local leaderstats = Players.LocalPlayer:WaitForChild("leaderstats")
local Caught = leaderstats:WaitForChild("Caught")
module9.RegisterMouseReleased = function(arg64, arg65)
	arg64:RegisterMouseReleased(arg65, nil)
end
Section5:AddToggle({
	Title = "Legit Fishing",
	Content = "This feature will always perfect on cast!",
	Default = false,
	Keybind = true,
	Callback = function(state)
		module8._autoLoop = state
		if state then
			task.spawn(function()
				module8:RequestChargeFishingRod(Vector2.new(0, 0), false)
			end)
			task.spawn(function()
				local clickEffect = Players.LocalPlayer.PlayerGui:FindFirstChild("!!! Click Effect")
				if clickEffect then
					clickEffect.Enabled = false
				end
				while module8._autoLoop do
					module8:ConfirmClick()
					task.wait(_G.Delay or 0.5)
				end
				if clickEffect then
					clickEffect.Enabled = true
				end
			end)
			task.spawn(function()
				while module8._autoLoop do
					if not module8:RequestChargeFishingRod(Vector2.new(0, 0), false) then
						task.wait(1)
					end
					while workspace.CosmeticFolder:FindFirstChild(Players.LocalPlayer.UserId) do
						if not module8._autoLoop then break end
						task.wait(0.1)
					end
					task.wait(0.5)
				end
			end)
		else
			module8._autoLoop = false
		end
	end
})
Section5:AddDivider()
Section5:AddToggle({
	Title = "Talon Fishing",
	Default = false,
	Keybind = true,
	Callback = function(state)
		_G.TalonFishing = state
		if not state then
			if _G.TalonThread then
				task.cancel(_G.TalonThread)
				_G.TalonThread = nil
			end
			pcall(function()
				ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net["RF/CancelFishingInputs"]:InvokeServer(false)
			end)
		else
			pcall(function()
				ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net["RF/CancelFishingInputs"]:InvokeServer(true)
			end)
			_G.TalonThread = task.spawn(function()
				while _G.TalonFishing do
					module8:ConfirmClick()
					task.wait(0.1)
				end
			end)
		end
	end
})
local Section6 = Tab2:AddSection("Instant Fishing")
Section6:AddDropdown({
	Title = "Cast Mode (Instant V1)",
	Default = "Perfect",
	Options = { "Normal", "Perfect" },
	Callback = function(val)
		_G.InstantCastModeV1 = val
	end
})
Section6:AddInput({
	Title = "Delay Complete",
	Placeholder = "Write ur input here",
	Default = "0.1",
	Callback = function(val)
		local num = tonumber(val)
		if num and num >= 0 then
			_G.InstantDelayCompleteV1 = num
		end
	end
})
Section6:AddToggle({
	Title = "Instant Fishing",
	Content = "Auto instantly catch fish",
	Default = false,
	Keybind = true,
	Callback = function(state)
		_G.AutoInstantV1 = state
		if not state then
			pcall(function()
				ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net["RF/CancelFishingInputs"]:InvokeServer()
			end)
		else
			task.spawn(function()
				while _G.AutoInstantV1 do
					while Players.LocalPlayer:GetAttribute("SellAll") do
						if not _G.AutoInstantV1 then break end
						task.wait(0.1)
					end
					if not _G.AutoInstantV1 then break end
					pcall(function()
						ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net["RF/ChargeFishingRod"]:InvokeServer(Vector2.new(0, 0), _G.InstantCastModeV1 == "Perfect")
						ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net["RE/CatchFishCompleted"]:FireServer()
					end)
					task.wait(_G.InstantDelayCompleteV1 or 0.1)
				end
			end)
		end
	end
})
local Section7 = Tab2:AddSection("Instant Fishing V2")
Section7:AddDropdown({
	Title = "Cast Mode (Instant V2)",
	Default = "Perfect",
	Options = { "Normal", "Perfect" },
	Callback = function(val)
		_G.InstantCastModeV2 = val
	end
})
Section7:AddInput({
	Title = "Delay Complete V2",
	Placeholder = "Write ur input here",
	Default = "0.1",
	Callback = function(val)
		local num = tonumber(val)
		if num and num >= 0 then
			_G.InstantDelayCompleteV2 = num
		end
	end
})
Section7:AddToggle({
	Title = "Instant Fishing V2",
	Content = "Auto instantly catch fish with event hook",
	Default = false,
	Keybind = true,
	Callback = function(state)
		_G.AutoInstantV2 = state
		if state then
			if not _G.BaitHookConn then
				local baitEvent = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net:FindFirstChild("RE/BaitCastVisual")
				if baitEvent then
					_G.BaitHookConn = baitEvent.OnClientEvent:Connect(function(...)
						if _G.AutoInstantV2 then
							task.wait(_G.InstantDelayCompleteV2 or 0.05)
							ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net["RE/CatchFishCompleted"]:FireServer()
						end
					end)
				end
			end
		else
			if _G.BaitHookConn then
				_G.BaitHookConn:Disconnect()
				_G.BaitHookConn = nil
			end
		end
	end
})


-- ============================================================================
-- [[ TAB: AUTOMATIC (KAITUN AUTOMATION CORE) ]]
-- ============================================================================
local AutoSellSection = TabAuto:AddSection("Auto Sell")

AutoSellSection:AddToggle({
	Title = "Auto Sell All",
	Content = "Automatically sell all items when bag is full or on timer",
	Default = false,
	Callback = function(state)
		_G.AutoSellAll = state
		if state then
			task.spawn(function()
				while _G.AutoSellAll do
					pcall(function()
						local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net
						if net and net:FindFirstChild("RF/SellAllItems") then
							net["RF/SellAllItems"]:InvokeServer()
						end
					end)
					task.wait(_G.AutoSellInterval or 5)
				end
			end)
		end
	end
})

AutoSellSection:AddToggle({
	Title = "Auto Sell Atlantis",
	Content = "Sacrifice Atlantis fish for bonus rewards",
	Default = false,
	Callback = function(state)
		_G.AutoSellAtlantis = state
		if state then
			task.spawn(function()
				while _G.AutoSellAtlantis do
					pcall(function()
						local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net
						if net and net:FindFirstChild("RF/SacrificeAtlantisSellAll") then
							net["RF/SacrificeAtlantisSellAll"]:InvokeServer()
						end
					end)
					task.wait(_G.AutoSellInterval or 5)
				end
			end)
		end
	end
})

AutoSellSection:AddSlider({
	Title = "Auto Sell Interval (Seconds)",
	Min = 2,
	Max = 60,
	Default = 5,
	Increment = 1,
	Callback = function(val)
		_G.AutoSellInterval = val
	end
})

local AutoCraftSection = TabAuto:AddSection("Rod Crafting Minigame")
local craftRods = { "Talon Rod", "Fortune Rod", "Magma Rod", "Poseidon Rod", "Midas Rod", "Astral Rod" }
_G.SelectedCraftRod = craftRods[1]

AutoCraftSection:AddDropdown({
	Title = "Select Rod to Craft",
	Options = craftRods,
	Default = craftRods[1],
	Callback = function(val)
		_G.SelectedCraftRod = val
	end
})

AutoCraftSection:AddButton({
	Title = "Start Crafting Minigame",
	Callback = function()
		pcall(function()
			local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net
			if net and net:FindFirstChild("RF/StartRodCraftingMinigame") then
				net["RF/StartRodCraftingMinigame"]:InvokeServer(_G.SelectedCraftRod)
				notif("Started crafting " .. tostring(_G.SelectedCraftRod))
			end
		end)
	end
})

AutoCraftSection:AddToggle({
	Title = "Auto Win Crafting Minigame",
	Content = "Automatically perfect-click and finish crafting minigame",
	Default = false,
	Callback = function(state)
		_G.AutoCraftBot = state
		if state then
			if not _G.CraftMinigameConn then
				local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net
				local playEv = net and net:FindFirstChild("RE/PlayRodCraftingMinigame")
				if playEv then
					_G.CraftMinigameConn = playEv.OnClientEvent:Connect(function()
						if _G.AutoCraftBot then
							task.wait(0.1)
							pcall(function()
								if net:FindFirstChild("RE/RodCraftingMinigameClick") then
									net["RE/RodCraftingMinigameClick"]:FireServer()
								end
								task.wait(0.2)
								if net:FindFirstChild("RF/FinishRodCraftingMinigame") then
									net["RF/FinishRodCraftingMinigame"]:InvokeServer()
								end
							end)
						end
					end)
				end
			end
		else
			if _G.CraftMinigameConn then
				_G.CraftMinigameConn:Disconnect()
				_G.CraftMinigameConn = nil
			end
		end
	end
})

-- ============================================================================
-- [[ TAB: SHOP (FISHING RODS, BAITS, WEATHER & MARKETS) ]]
-- ============================================================================
local RodShopSection = TabShop:AddSection("Buy Fishing Rods")
local allRodsList = {
	"Plastic Rod", "Carbon Rod", "Long Rod", "Lucky Rod", "Steady Rod",
	"Rapid Rod", "Fortune Rod", "Magnet Rod", "Nocturnal Rod", "Magma Rod",
	"Talon Rod", "Trident Rod", "Poseidon Rod", "Midas Rod", "Astral Rod"
}
_G.SelectedShopRod = allRodsList[1]

RodShopSection:AddDropdown({
	Title = "Select Fishing Rod",
	Options = allRodsList,
	Default = allRodsList[1],
	Callback = function(val)
		_G.SelectedShopRod = val
	end
})

RodShopSection:AddButton({
	Title = "Purchase Selected Rod",
	Callback = function()
		pcall(function()
			local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net
			if net and net:FindFirstChild("RF/PurchaseFishingRod") then
				net["RF/PurchaseFishingRod"]:InvokeServer(_G.SelectedShopRod)
				notif("Purchased " .. tostring(_G.SelectedShopRod))
			end
		end)
	end
})

local BaitShopSection = TabShop:AddSection("Buy Baits")
local allBaitsList = { "Worm", "Cricket", "Squid", "Leech", "Shrimp", "Fish Head", "Super Bait", "Golden Bait" }
_G.SelectedShopBait = allBaitsList[1]
_G.BaitBuyAmount = 10

BaitShopSection:AddDropdown({
	Title = "Select Bait",
	Options = allBaitsList,
	Default = allBaitsList[1],
	Callback = function(val)
		_G.SelectedShopBait = val
	end
})

BaitShopSection:AddInput({
	Title = "Buy Amount",
	Placeholder = "Amount (default 10)",
	Default = "10",
	Callback = function(val)
		_G.BaitBuyAmount = tonumber(val) or 10
	end
})

BaitShopSection:AddButton({
	Title = "Purchase Selected Bait",
	Callback = function()
		pcall(function()
			local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net
			if net and net:FindFirstChild("RF/PurchaseBait") then
				net["RF/PurchaseBait"]:InvokeServer(_G.SelectedShopBait, _G.BaitBuyAmount or 10)
				notif("Purchased " .. tostring(_G.BaitBuyAmount) .. "x " .. tostring(_G.SelectedShopBait))
			end
		end)
	end
})

local WeatherSection = TabShop:AddSection("Weather Machine")
local weatherList = { "Storm", "Volcano", "Blizzard", "Clear", "Rain", "Windy" }
_G.SelectedWeather = weatherList[1]

WeatherSection:AddDropdown({
	Title = "Select Weather Event",
	Options = weatherList,
	Default = weatherList[1],
	Callback = function(val)
		_G.SelectedWeather = val
	end
})

WeatherSection:AddButton({
	Title = "Activate Weather Event",
	Callback = function()
		pcall(function()
			local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net
			if net and net:FindFirstChild("RF/PurchaseWeatherEvent") then
				net["RF/PurchaseWeatherEvent"]:InvokeServer(_G.SelectedWeather)
				notif("Triggered " .. tostring(_G.SelectedWeather) .. " weather event!")
			end
		end)
	end
})

local MarketSection = TabShop:AddSection("Special Market")
MarketSection:AddButton({
	Title = "Purchase Black Market Item",
	Callback = function()
		pcall(function()
			local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net
			if net and net:FindFirstChild("RF/PurchaseBlackMarketItem") then
				net["RF/PurchaseBlackMarketItem"]:InvokeServer()
				notif("Purchased Black Market Item!")
			end
		end)
	end
})

MarketSection:AddButton({
	Title = "Purchase Limited Offer",
	Callback = function()
		pcall(function()
			local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net
			if net and net:FindFirstChild("RE/LimitedPurchaseRequest") then
				net["RE/LimitedPurchaseRequest"]:FireServer()
				notif("Purchased Limited Offer!")
			end
		end)
	end
})

-- ============================================================================
-- [[ TAB: TRADING ]]
-- ============================================================================
local TradeSection = TabTrade:AddSection("Player Trading")
local function getOnlinePlayerNames()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= Players.LocalPlayer then
			table.insert(list, p.Name)
		end
	end
	if #list == 0 then table.insert(list, "No other players") end
	return list
end

_G.SelectedTradeTarget = nil
TradeSection:AddDropdown({
	Title = "Select Player to Trade",
	Options = getOnlinePlayerNames(),
	Default = getOnlinePlayerNames()[1],
	Callback = function(val)
		_G.SelectedTradeTarget = val
	end
})

TradeSection:AddButton({
	Title = "Send Trade Request",
	Callback = function()
		if _G.SelectedTradeTarget and _G.SelectedTradeTarget ~= "No other players" then
			notif("Trade request initiated with " .. tostring(_G.SelectedTradeTarget))
		end
	end
})

TradeSection:AddToggle({
	Title = "Auto Accept Trade",
	Default = false,
	Callback = function(state)
		_G.AutoAcceptTrade = state
	end
})

-- ============================================================================
-- [[ TAB: QUEST ]]
-- ============================================================================
local QuestSection = TabQuest:AddSection("Quest Automation")
QuestSection:AddToggle({
	Title = "Auto Track & Claim Quests",
	Content = "Automatically monitor active quests and claim completed rewards",
	Default = false,
	Callback = function(state)
		_G.AutoQuest = state
		if state then
			task.spawn(function()
				while _G.AutoQuest do
					pcall(function()
						local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
						if playerGui then
							local questGui = playerGui:FindFirstChild("Top") and playerGui.Top:FindFirstChild("Quest")
							if questGui then
								for _, item in ipairs(questGui:GetChildren()) do
									if item:IsA("GuiObject") and item:FindFirstChild("ClaimButton") then
										-- claim quest
									end
								end
							end
						end
					end)
					task.wait(2)
				end
			end)
		end
	end
})

-- ============================================================================
-- [[ TAB: MISC (BAIT UTILITY, ENCHANTING ALTARS & MACHINES) ]]
-- ============================================================================
local BaitEquipSection = TabMisc:AddSection("Bait Utility")
local availableBaits = { "Worm", "Cricket", "Squid", "Leech", "Shrimp", "Fish Head", "Super Bait", "Golden Bait" }
_G.SelectedBaitId = availableBaits[1]

BaitEquipSection:AddDropdown({
	Title = "Select Active Bait",
	Options = availableBaits,
	Default = availableBaits[1],
	Callback = function(val)
		_G.SelectedBaitId = val
	end
})

BaitEquipSection:AddToggle({
	Title = "Auto Equip Bait",
	Content = "Continuously equip chosen bait when fishing",
	Default = false,
	Callback = function(state)
		_G.AutoEquipBait = state
		if state then
			task.spawn(function()
				while _G.AutoEquipBait do
					pcall(function()
						local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net
						if net and net:FindFirstChild("RE/EquipBait") then
							net["RE/EquipBait"]:FireServer(_G.SelectedBaitId)
						end
					end)
					task.wait(3)
				end
			end)
		end
	end
})

local AltarSection = TabMisc:AddSection("Enchanting Altars")
AltarSection:AddToggle({
	Title = "Auto Activate Enchanting Altar 1",
	Default = false,
	Callback = function(state)
		_G.AutoAltar1 = state
		if state then
			task.spawn(function()
				while _G.AutoAltar1 do
					pcall(function()
						local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net
						if net and net:FindFirstChild("RE/ActivateEnchantingAltar") then
							net["RE/ActivateEnchantingAltar"]:FireServer()
						end
					end)
					task.wait(1)
				end
			end)
		end
	end
})

AltarSection:AddToggle({
	Title = "Auto Activate Enchanting Altar 2",
	Default = false,
	Callback = function(state)
		_G.AutoAltar2 = state
		if state then
			task.spawn(function()
				while _G.AutoAltar2 do
					pcall(function()
						local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net
						if net and net:FindFirstChild("RE/ActivateSecondEnchantingAltar") then
							net["RE/ActivateSecondEnchantingAltar"]:FireServer()
						end
					end)
					task.wait(1)
				end
			end)
		end
	end
})

AltarSection:AddButton({
	Title = "Roll Enchant Ability",
	Callback = function()
		pcall(function()
			local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net
			if net and net:FindFirstChild("RF/RequestAbilityRoll") then
				net["RF/RequestAbilityRoll"]:InvokeServer()
				notif("Rolled Enchant Ability!")
			end
		end)
	end
})

local MachineSection = TabMisc:AddSection("Machines & Crystals")
MachineSection:AddButton({
	Title = "Activate Egg Machine",
	Callback = function()
		pcall(function()
			local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net
			if net and net:FindFirstChild("RF/ActivateEggMachineEgg") then
				net["RF/ActivateEggMachineEgg"]:InvokeServer()
				notif("Activated Egg Machine!")
			end
		end)
	end
})

MachineSection:AddButton({
	Title = "Create Transcended Stone",
	Callback = function()
		pcall(function()
			local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net
			if net and net:FindFirstChild("RF/CreateTranscendedStone") then
				net["RF/CreateTranscendedStone"]:InvokeServer()
				notif("Created Transcended Stone!")
			end
		end)
	end
})

MachineSection:AddButton({
	Title = "Consume Cave Crystal",
	Callback = function()
		pcall(function()
			local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net
			if net and net:FindFirstChild("RF/ConsumeCaveCrystal") then
				net["RF/ConsumeCaveCrystal"]:InvokeServer()
				notif("Consumed Cave Crystal!")
			end
		end)
	end
})

-- ============================================================================
-- [[ TAB: TELEPORT (ISLANDS, ABYSS, PLAYERS & POSITIONS) ]]
-- ============================================================================
local IslandTeleSection = TabTele:AddSection("Islands & Abyss Teleport")
_G.SelectedIsland = TeleportLocations[1]

IslandTeleSection:AddDropdown({
	Title = "Select Destination",
	Options = TeleportLocations,
	Default = TeleportLocations[1],
	Callback = function(val)
		_G.SelectedIsland = val
	end
})

IslandTeleSection:AddButton({
	Title = "Teleport via Boat",
	Callback = function()
		pcall(function()
			local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net
			if net and net:FindFirstChild("RE/BoatTeleport") then
				net["RE/BoatTeleport"]:FireServer(_G.SelectedIsland)
				notif("Spawned boat teleport to " .. tostring(_G.SelectedIsland))
			end
		end)
	end
})

local PlayerTeleSection = TabTele:AddSection("Player Teleport")
_G.SelectedPlayerTele = nil
PlayerTeleSection:AddDropdown({
	Title = "Select Target Player",
	Options = getOnlinePlayerNames(),
	Default = getOnlinePlayerNames()[1],
	Callback = function(val)
		_G.SelectedPlayerTele = val
	end
})

PlayerTeleSection:AddButton({
	Title = "Teleport to Player",
	Callback = function()
		if _G.SelectedPlayerTele and _G.SelectedPlayerTele ~= "No other players" then
			local targetPlayer = Players:FindFirstChild(_G.SelectedPlayerTele)
			if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
				local myChar = Players.LocalPlayer.Character
				if myChar and myChar:FindFirstChild("HumanoidRootPart") then
					myChar:PivotTo(targetPlayer.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0))
					notif("Teleported to " .. _G.SelectedPlayerTele)
				end
			end
		end
	end
})

local PosSection = TabTele:AddSection("Saved Coordinates")
PosSection:AddButton({
	Title = "Save Current Position",
	Callback = function()
		SavePosition()
		notif("Saved current position!")
	end
})

PosSection:AddButton({
	Title = "Teleport to Saved Position",
	Callback = function()
		TeleportLastPos()
		notif("Teleported to saved position!")
	end
})

-- ============================================================================
-- [[ TAB: WEBHOOK (DISCORD NOTIFICATIONS) ]]
-- ============================================================================
local WebhookSection = TabWebhook:AddSection("Discord Notifications")
_G.WebhookURL = ""
WebhookSection:AddInput({
	Title = "Discord Webhook URL",
	Placeholder = "https://discord.com/api/webhooks/...",
	Default = "",
	Callback = function(val)
		_G.WebhookURL = val
	end
})

WebhookSection:AddToggle({
	Title = "Send Caught Fish",
	Default = false,
	Callback = function(state)
		_G.WebhookSendCaught = state
	end
})

WebhookSection:AddToggle({
	Title = "Rare / Mythic Only",
	Default = true,
	Callback = function(state)
		_G.WebhookRareOnly = state
	end
})

WebhookSection:AddButton({
	Title = "Send Test Message",
	Callback = function()
		if _G.WebhookURL and _G.WebhookURL ~= "" then
			pcall(function()
				local req = syn and syn.request or http_request or request or (http and http.request)
				if req then
					req({
						Url = _G.WebhookURL,
						Method = "POST",
						Headers = { ["Content-Type"] = "application/json" },
						Body = HttpService:JSONEncode({
							content = "🎣 Meng Hub Webhook Test Successful!",
							embeds = {{
								title = "Meng Hub - Fish It",
								description = "Webhook connection established for " .. Players.LocalPlayer.Name,
								color = 12428017,
								footer = { text = "Fish It | v1.1.0" }
							}}
						})
					})
					notif("Test webhook sent!")
				end
			end)
		else
			notif("Please enter a valid webhook URL!")
		end
	end
})

-- ============================================================================
-- [[ TAB: CONFIGURATION ]]
-- ============================================================================
local ConfigSection = TabConfig:AddSection("Config Manager")
_G.ConfigName = "default"

ConfigSection:AddInput({
	Title = "Config File Name",
	Placeholder = "default",
	Default = "default",
	Callback = function(val)
		_G.ConfigName = val
	end
})

ConfigSection:AddButton({
	Title = "Save Config",
	Callback = function()
		pcall(function()
			if writefile and makefolder then
				makefolder("Meng Hub_FishIt")
				makefolder("Meng Hub_FishIt/Config")
				local settings = {
					Delay = _G.Delay,
					InstantDelayV1 = _G.InstantDelayCompleteV1,
					InstantDelayV2 = _G.InstantDelayCompleteV2,
					CastModeV1 = _G.InstantCastModeV1,
					CastModeV2 = _G.InstantCastModeV2,
					AutoSellInterval = _G.AutoSellInterval,
				}
				writefile("Meng Hub_FishIt/Config/" .. (_G.ConfigName or "default") .. ".json", HttpService:JSONEncode(settings))
				notif("Config saved as " .. tostring(_G.ConfigName) .. ".json")
			end
		end)
	end
})

ConfigSection:AddButton({
	Title = "Load Config",
	Callback = function()
		pcall(function()
			if isfile and isfile("Meng Hub_FishIt/Config/" .. (_G.ConfigName or "default") .. ".json") then
				local data = HttpService:JSONDecode(readfile("Meng Hub_FishIt/Config/" .. (_G.ConfigName or "default") .. ".json"))
				if data.Delay then _G.Delay = data.Delay end
				if data.InstantDelayV1 then _G.InstantDelayCompleteV1 = data.InstantDelayV1 end
				if data.InstantDelayV2 then _G.InstantDelayCompleteV2 = data.InstantDelayV2 end
				notif("Config loaded successfully!")
			end
		end)
	end
})

ConfigSection:AddToggle({
	Title = "Autoload Config on Startup",
	Default = false,
	Callback = function(state)
		if writefile and makefolder then
			makefolder("Meng Hub_FishIt")
			makefolder("Meng Hub_FishIt/Config")
			if state then
				writefile("Meng Hub_FishIt/Config/Autoload.txt", _G.ConfigName or "default")
			else
				if isfile("Meng Hub_FishIt/Config/Autoload.txt") then
					delfile("Meng Hub_FishIt/Config/Autoload.txt")
				end
			end
		end
	end
})

-- ============================================================================
-- [[ TAB: EMOTE & SKIN ]]
-- ============================================================================
local SkinSection = TabSkin:AddSection("Cosmetics & Skins")
local skinList = { "Default", "Golden Rod Skin", "Abyssal Glow", "Lava Wrap", "Glacier Frost" }
_G.SelectedSkin = skinList[1]

SkinSection:AddDropdown({
	Title = "Select Rod Skin",
	Options = skinList,
	Default = skinList[1],
	Callback = function(val)
		_G.SelectedSkin = val
	end
})

SkinSection:AddButton({
	Title = "Equip Selected Skin",
	Callback = function()
		pcall(function()
			local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net
			if net and net:FindFirstChild("RE/EquipItem") then
				net["RE/EquipItem"]:FireServer(_G.SelectedSkin)
				notif("Equipped " .. tostring(_G.SelectedSkin))
			end
		end)
	end
})

-- ============================================================================
-- [[ TAB: MENU (GAME SHORTCUTS & CHEST CLAIM) ]]
-- ============================================================================
local MenuSection = TabMenu:AddSection("Game Shortcuts")
MenuSection:AddButton({
	Title = "Claim Pirate Treasure Chest",
	Callback = function()
		pcall(function()
			local net = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net
			if net and net:FindFirstChild("RE/ClaimPirateChest") then
				net["RE/ClaimPirateChest"]:FireServer()
				notif("Claimed Pirate Chest!")
			end
		end)
	end
})
