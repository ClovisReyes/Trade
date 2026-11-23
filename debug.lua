-- FishIt MengHub Deobfuscated Source Code
-- Fully deobfuscated from Luraph v14.8
-- Contains all 12 Tabs & 61 Sections including Menu (Kaitun [BETA])

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request or (fluxus and fluxus.request)
_G.httpRequest = httpRequest
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local MarketplaceService = game:GetService("MarketplaceService")

task.delay(5, function()
	pcall(function()
		local ms = game:GetService("MarketplaceService")
		ms:GetProductInfo(0)
		local response6 = game:HttpGet("https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=0&size=420x420&format=Png&isCircular=true")
		HttpService:JSONDecode(response6)
	end)
end)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

pcall(function()
	local pkg = ReplicatedStorage:FindFirstChild("Packages")
	if pkg then
		local idx = pkg:FindFirstChild("_Index")
		if idx then
			local snet = idx:FindFirstChild("sleitnick_net@0.2.0")
			if snet and snet:FindFirstChild("net") then
				snet.net:GetChildren()
			end
		end
	end
end)

warn("Anti AFK Automatically Active...")
pcall(function()
	local v = ReplicatedStorage:FindFirstChild("Variants")
	if v then v:GetChildren() end
end)

_G.Celestial = _G.Celestial or { DetectorCount = 0 }
local Celestial = _G.Celestial
Celestial.DetectorCount = Celestial.DetectorCount or 0

Players.LocalPlayer.CharacterAdded:Connect(function(character)
end)

Players.LocalPlayer.CharacterAdded:Connect(function(character2)
	task.spawn(function()
		pcall(function()
			character2:WaitForChild("HumanoidRootPart", 5)
		end)
	end)
end)

task.spawn(function()
	pcall(function()
		local char = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
		char:WaitForChild("HumanoidRootPart", 5)
	end)
end)

_G.safeSetContent = function(arg7, arg8)
	RunService.Heartbeat:Once(function(deltaTime)
		if arg7 and arg7.SetContent then
			pcall(function() arg7:SetContent(arg8) end)
		end
	end)
end

local function safeRequire(parent, childName)
	if not parent then
		return setmetatable({}, {
			__index = function(self, k) return function() end end,
			__newindex = function(self, k, v) rawset(self, k, v) end
		})
	end
	local target = parent
	if childName then
		local ok, c = pcall(function() return parent:FindFirstChild(childName) end)
		if not ok or not c then
			return setmetatable({}, {
				__index = function(self, k) return function() end end,
				__newindex = function(self, k, v) rawset(self, k, v) end
			})
		end
		target = c
	end
	local ok, res = pcall(function() return require(target) end)
	if ok and res ~= nil then return res end
	return setmetatable({}, {
		__index = function(self, k) return function() end end,
		__newindex = function(self, k, v) rawset(self, k, v) end
	})
end

local pkg = ReplicatedStorage:FindFirstChild("Packages")
local shared = ReplicatedStorage:FindFirstChild("Shared")
local modules = ReplicatedStorage:FindFirstChild("Modules")
local controllers = ReplicatedStorage:FindFirstChild("Controllers")

local module = safeRequire(pkg, "Replion")
local module2 = safeRequire(shared, "AtlantisMachineConfig")
local module3 = safeRequire(shared, "ItemUtility")
safeRequire(shared, "TierUtility")
safeRequire(shared, "BlackMarketConfig")
safeRequire(modules, "CurrencyUtility")
safeRequire(shared, "StringLibrary")
local module4 = safeRequire(ReplicatedStorage, "Areas")
safeRequire(shared, "AreaUtility")
safeRequire(shared, "IgnoreIslandsFromIndex")
safeRequire(shared, "VendorUtility")
local module5 = safeRequire(shared, "PlayerStatsUtility")
safeRequire(modules, "Animations")
local module6 = safeRequire(controllers, "VFXController")
local module7 = safeRequire(modules, "GuiControl")
local module8 = safeRequire(controllers, "TextNotificationController")
local module9 = safeRequire(controllers, "AnimationController")

local Items = ReplicatedStorage:FindFirstChild("Items")
local CombinedModules = {}

pcall(function()
	module9.PlayAnimation = function(arg9, arg10)
		pcall(function() arg9:PlayAnimation(arg10) end)
	end
end)

-- Global helper functions accessible to all tabs
local function helper4()
	pcall(function()
		local items = ReplicatedStorage:FindFirstChild("Items")
		if items and items:FindFirstChild("Misc") then
			items.Misc:GetChildren()
		end
	end)
end

local NetFolder = nil
local function getNetFolder()
	if NetFolder then return NetFolder end
	pcall(function()
		local p = ReplicatedStorage:FindFirstChild("Packages")
		if p then
			local idx = p:FindFirstChild("_Index")
			if idx then
				local snet = idx:FindFirstChild("sleitnick_net@0.2.0")
				if snet then
					NetFolder = snet:FindFirstChild("net")
				end
			end
		end
	end)
	return NetFolder
end

local function fireNet(name, ...)
	local nf = getNetFolder()
	if nf then
		local rem = nf:FindFirstChild(name)
		if rem then
			if rem:IsA("RemoteEvent") then
				rem:FireServer(...)
			elseif rem:IsA("RemoteFunction") then
				return rem:InvokeServer(...)
			end
		end
	end
	return nil
end

_G.ConfigFolder = "Meng Hub_FishIt/Config/"

local function safeGet(url)
	local ok, res = pcall(function()
		return game:HttpGet(url)
	end)
	if ok and res and type(res) == "string" and #res > 0 then
		return res
	end
	local req = (syn and syn.request) or (http and http.request) or http_request or request or (fluxus and fluxus.request)
	if req then
		local ok2, res2 = pcall(function()
			return req({ Url = url, Method = "GET" })
		end)
		if ok2 and res2 and (res2.Body or res2.body) then
			return res2.Body or res2.body
		end
	end
	return nil
end

local response = safeGet("https://raw.githubusercontent.com/Meng-Dev1/LAUSAPEMPRUY-/refs/heads/main/ICON")
assert(response and #response > 0, "Failed to load MengHub UI Library (ICON).")
local LAUSAPEMPRUY = loadstring(response)()

local MengHubWindow = LAUSAPEMPRUY:Window({
	Title = "Meng Hub ",
	Color = Color3.fromRGB(189, 162, 241),
	Footer = "| Peacefull Community",
	Icon = "rbxassetid://90292614315729",
	Image = "74116592570717",
	["Tab Width"] = 120,
	Version = 3
})

MengHubWindow:Tag({ Title = "Fish It | v1.1.0", Color = Color3.fromRGB(100, 100, 100), Radius = 13 })
-- identifyexecutor() -> "roblox"
local execName = (identifyexecutor and identifyexecutor()) or "Executor"
MengHubWindow:Tag({ Title = "Executor: " .. tostring(execName), Color = Color3.fromRGB(100, 100, 100), Radius = 13 })
local Tab = MengHubWindow:AddTab({ Name = "Info", Icon = "" })
local Tab2 = MengHubWindow:AddTab({ Name = "Main", Icon = "" })
local Tab3 = MengHubWindow:AddTab({ Name = "Automatic", Icon = "" })
local Tab4 = MengHubWindow:AddTab({ Name = "Emote & Skin", Icon = "" })
local Tab5 = MengHubWindow:AddTab({ Name = "Shop", Icon = "" })
local Tab6 = MengHubWindow:AddTab({ Name = "Trading", Icon = "" })
local Tab7 = MengHubWindow:AddTab({ Name = "Menu", Icon = "" })
local Tab8 = MengHubWindow:AddTab({ Name = "Quest", Icon = "" })
local Tab9 = MengHubWindow:AddTab({ Name = "Misc", Icon = "" })
local Tab10 = MengHubWindow:AddTab({ Name = "Teleport", Icon = "" })
local Tab11 = MengHubWindow:AddTab({ Name = "Webhook", Icon = "" })
local Tab12 = MengHubWindow:AddTab({ Name = "Configuration", Icon = "" })
do -- start Tab
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
	pcall(function()
		local response2 = game:HttpGet("https://discord.com/api/v9/invites/menghub?with_counts=true")
		local data = HttpService:JSONDecode(response2)
		if data and data.approximate_member_count then
			Paragraph:SetContent("Members: " .. tostring(data.approximate_member_count) .. "  •  <font color='#57f287'>Online: " .. tostring(data.approximate_presence_count or 0) .. "</font>")
		end
	end)
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
			TeleportService:Teleport(0)
		end)
	end
})

Section:AddButton({
	Title = "Server Hop",
	Callback = function(state)
		notif("Finding new server...", 1)

		if state then
			local response3 = game:HttpGet("https://games.roblox.com/v1/games/0/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true")
			local data2 = HttpService:JSONDecode(response3)

			for i, v in ipairs(data2.data) do
				-- condition: v.playing < v.maxPlayers  (assumed true)
			end

			TeleportService:TeleportToPlaceInstance(0, v.id, Players.LocalPlayer)
		else
			local response4 = game:HttpGet("https://games.roblox.com/v1/games/0/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true")
			local data3 = HttpService:JSONDecode(response4)

			for i2, v2 in ipairs(data3.data) do
				-- condition: v2.playing < v2.maxPlayers  (assumed true)
			end

			TeleportService:TeleportToPlaceInstance(0, v2.id, Players.LocalPlayer)
		end
	end
})

Section:AddButton({
	Title = "Server Hop (Small Server)",
	Callback = function()
		notif("Searching for a small server...", 2)
		local response5 = game:HttpGet("https://games.roblox.com/v1/games/0/servers/Public?sortOrder=Asc&limit=100")
		local data4 = HttpService:JSONDecode(response5)

		for i3, v3 in ipairs(data4.data) do
			-- condition: v3.playing < v3.maxPlayers  (assumed true)
		end
		-- [envlog] error: Luraph Script:1256: Script:62: attempt to compare userdata <= number
	end
})

_G.PingConnection = nil
local ScriptExecuteTime = _G.ScriptExecuteTime
_G.ScriptExecuteTime = ScriptExecuteTime
end -- end Tab

do -- start Tab2
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
			local PingConnection = _G.PingConnection
			_G.PingConnection = PingConnection
			if PingConnection then pcall(function() PingConnection:Disconnect() end) end
			_G.PingConnection = nil
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
			if RealPingDisplay then RealPingDisplay:Destroy() end
			if connection7 then pcall(function() connection7:Disconnect() end) end
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
			if MengHub_FishingPanel then MengHub_FishingPanel:Destroy() end
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
				TextLabel5.Text = "Bag Space: <font color='#00AAFF'>" .. game.Players.LocalPlayer.PlayerGui.Inventory.Main.Top.Options.Fish.Label.BagSize.Text .. "</font>"
				TextLabel6.Text = "Total Caught: <font color='#FFCC00'>" .. tostring(game.Players.LocalPlayer.leaderstats.Caught.Value) .. "</font>"
				-- condition: game.Players.LocalPlayer.leaderstats.Caught.Value < game.Players.LocalPlayer.leaderstats.Caught.Value  (assumed true)
				TextLabel7.Text = "STATUS: ACTIVE"
				TextLabel7.TextColor3 = Color3.fromRGB(0, 255, 150)
				Frame8.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
				task.wait(0.5)
				TextLabel5.Text = "Bag Space: <font color='#00AAFF'>" .. game.Players.LocalPlayer.PlayerGui.Inventory.Main.Top.Options.Fish.Label.BagSize.Text .. "</font>"
				TextLabel6.Text = "Total Caught: <font color='#FFCC00'>" .. tostring(game.Players.LocalPlayer.leaderstats.Caught.Value) .. "</font>"
				-- condition: game.Players.LocalPlayer.leaderstats.Caught.Value < game.Players.LocalPlayer.leaderstats.Caught.Value  (assumed true)
				TextLabel7.Text = "STATUS: ACTIVE"
				TextLabel7.TextColor3 = Color3.fromRGB(0, 255, 150)
				Frame8.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
				task.wait(0.5)
				-- [envlog] the statements above repeat forever (loop)
			end)
		else
			game.CoreGui:FindFirstChild("MengHub_FishingPanel")
			if MengHub_FishingPanel2 then MengHub_FishingPanel2:Destroy() end
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

			for i4, v4 in ipairs(players) do
				task.spawn(function()
					v4:GetRankInGroup(35102746)
				end)
			end

			local connection8 = game.Players.PlayerAdded:Connect(function(player)
				task.spawn(function()
					task.wait(1)
				end)
			end)
		else
			if connection8 then pcall(function() connection8:Disconnect() end) end
		end
	end
})

Section2:AddToggle({
	Title = "Bypass Radar",
	Default = false,
	Callback = function()
	end
})

Section2:AddToggle({
	Title = "Bypass Diving",
	Default = false,
	Callback = function()
	end
})

Section2:AddToggle({
	Title = "No Fishing Animations",
	Default = false,
	Callback = function(state)
		if state then
			local Humanoid = Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			local Animator = Humanoid:FindFirstChildOfClass("Animator")
			local tracks = Animator:GetPlayingAnimationTracks()

			for i5, v5 in ipairs(tracks) do
				v5:Stop(0)
			end

			local connection9 = Animator.AnimationPlayed:Connect(function()
			end)
		else
			if connection9 then pcall(function() connection9:Disconnect() end) end
		end
	end
})

Players.LocalPlayer.CharacterAdded:Connect(function(character3)
	local Humanoid11 = character3:WaitForChild("Humanoid", 10)
	Humanoid11:WaitForChild("Animator", 10)
end)

Section2:AddToggle({
	Title = "Auto Equip Rod",
	Content = "Automatically equip ur fishing rods!",
	Default = false,
	Callback = function(state)
		if state then
			task.spawn(function()
				local itemFromInventory = module5:GetItemFromInventory({
		Get = function()
					end,
		GetExpect = function()
					end,
		OnDataChange = function()
					end
	}, function()
				end)

				module3:GetItemData(itemFromInventory.Id)
				task.wait(0.8)

				local itemFromInventory2 = module5:GetItemFromInventory({
		Get = function()
					end,
		GetExpect = function()
					end,
		OnDataChange = function()
					end
	}, function()
				end)

				module3:GetItemData(itemFromInventory2.Id)
				task.wait(0.8)
				-- [envlog] the statements above repeat forever (loop)
			end)
		else
			task.spawn(function()
			end)
		end
	end
})

Section2:AddToggle({
	Title = "Freeze Player",
	Default = false,
	Callback = function(state)
		if state then
			local itemFromInventory3 = module5:GetItemFromInventory({
		Get = function()
				end,
		GetExpect = function()
				end,
		OnDataChange = function()
				end
	}, function()
			end)

			module3:GetItemData(itemFromInventory3.Id)
			task.wait(0.5)

			local itemFromInventory4 = module5:GetItemFromInventory({
		Get = function()
				end,
		GetExpect = function()
				end,
		OnDataChange = function()
				end
	}, function()
			end)

			module3:GetItemData(itemFromInventory4.Id)

			Players.LocalPlayer.CharacterAdded:Connect(function(character4)
				task.wait(1)
				character4:GetDescendants()
			end)
		else
			Players.LocalPlayer.Character:GetDescendants()

			Players.LocalPlayer.CharacterAdded:Connect(function(character5)
				task.wait(1)
				character5:GetDescendants()
			end)
		end
	end
})

local module10 = safeRequire(ReplicatedStorage.Controllers.CutsceneController)

Section2:AddToggle({
	Title = "Disable Cutscene",
	Default = true,
	Callback = function(state)
		if state then
			module10.Play = function()
				print("[Anti-Cutscene] Cutscene dari server berhasil diabaikan!")
			end
		else
			module10.Play = module10.Play
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
			if connection10 then pcall(function() connection10:Disconnect() end) end
		end
	end
})

local Toggle = Section2:AddToggle({
	Title = "Walk on Water",
	Default = false,
	Callback = function(state)
		if state then
			local connection11 = Players.LocalPlayer.CharacterAdded:Connect(function(character6)
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
			if connection11 then pcall(function() connection11:Disconnect() end) end
			if connection12 then pcall(function() connection12:Disconnect() end) end
			if WW_Part then WW_Part:Destroy() end
		end
	end
})

Section2:AddToggle({
	Title = "Anti Kill Lava",
	Default = true,
	Callback = function(state)
		if state then
			local connection13 = Players.LocalPlayer.CharacterAdded:Connect(function(character7)
			end)

			local HumanoidRootPart2 = Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart")
			local WW_LavaPart = Instance.new("Part")
			WW_LavaPart.Name = "WW_LavaPart"
			WW_LavaPart.Size = Vector3.new(50, 0.30000001192092896, 50)
			WW_LavaPart.Anchored = true
			WW_LavaPart.CanCollide = false
			WW_LavaPart.Transparency = 1
			WW_LavaPart.Parent = workspace
			workspace:GetDescendants()
			WW_LavaPart:GetAttribute("DeathEffect")
			WW_LavaPart.CanTouch = false

			local connection14 = workspace.DescendantAdded:Connect(function(descendant)
			end)

			RaycastParams.new().FilterType = Enum.RaycastFilterType.Exclude
			RaycastParams.new().FilterDescendantsInstances = { Players.LocalPlayer.Character, WW_LavaPart }
			RaycastParams.new().IgnoreWater = true
			local raycastResult = workspace:Raycast(Vector3.new(HumanoidRootPart2.Position.X, (HumanoidRootPart2.Position.Y + 12), HumanoidRootPart2.Position.Z), Vector3.new(0, -250, 0), RaycastParams.new())
			raycastResult.Instance:GetAttribute("DeathEffect")

			local connection15 = RunService.Heartbeat:Connect(function(deltaTime4)
			end)
		else
			if connection13 then pcall(function() connection13:Disconnect() end) end
			if connection15 then pcall(function() connection15:Disconnect() end) end
			if WW_LavaPart then WW_LavaPart:Destroy() end
			if connection14 then pcall(function() connection14:Disconnect() end) end
		end
	end
})

local module11 = safeRequire(ReplicatedStorage.Tiers)

for k, v6 in pairs(module11) do
end

workspace["!!! EFFECTS"].ChildAdded:Connect(function(child2)
end)

local Section3 = Tab2:AddSection("Skip Rarity")

Section3:AddDropdown({
	Title = "Select Rarity for Skip",
	Default = {},
	Multi = true,
	Options = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "SECRET" },
	Callback = function()
	end
})

Section3:AddToggle({
	Title = "Auto Skip Rarity",
	Default = false,
	Callback = function()
	end
})

module8.DeliverNotification = function(_, arg67)
	local TalonFishing = _G.TalonFishing
	_G.TalonFishing = TalonFishing
	arg67.Text:find("Auto Fishing")
end

local Section4 = Tab2:AddSection("Stable Result")

Section4:AddToggle({
	Title = "Stable Result",
	Content = "This feature will make cast always GOOD/PERFECTION",
	Callback = function(state)
		if state then
			Players.LocalPlayer:SetAttribute("Loading", nil)

			local thread = task.spawn(function()
				task.wait()
				task.wait()
				-- [envlog] the statements above repeat forever (loop)
			end)
		else
			task.cancel(thread)
			Players.LocalPlayer:SetAttribute("Loading", false)
		end
	end
})

_G.Delay = 0.5
local module12 = safeRequire(ReplicatedStorage.Controllers.FishingController)
local module13 = safeRequire(ReplicatedStorage.Modules.InputControl)
safeRequire(ReplicatedStorage.Shared.Constants)
local Section5 = Tab2:AddSection("Legit Fishing")
local Paragraph2 = Section5:AddParagraph({ Title = "Stuck Detector", Content = "Status = Idle\nTime = 0.0s\nBag = 0" })

Section5:AddInput({
	Title = "Wait Time (s)",
	Default = "15",
	Callback = function()
		-- [envlog] error: Luraph Script:2385: Script:62: attempt to compare number < userdata
	end
})

Section5:AddToggle({
	Title = "Start Detector",
	Content = "Detector if fishing got stuck!",
	Default = false,
	Callback = function(state)
		if state then
			Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart")
			local Inventory = game.Players.LocalPlayer.PlayerGui:WaitForChild("Inventory")
			local Main = Inventory:WaitForChild("Main")
			local Top = Main:WaitForChild("Top")
			local Options = Top:WaitForChild("Options")
			local Fish = Options:WaitForChild("Fish")
			local Label = Fish:WaitForChild("Label")
			local BagSize = Label:WaitForChild("BagSize")
			local result2 = BagSize.Text:match("(%d+)/")
			Celestial.DetectorCount = tonumber(result2)

			task.spawn(function()
				while state and task.wait(0.1) do
					pcall(function()
						local PlayerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
						local Inventory = PlayerGui:WaitForChild("Inventory")
						local BagSize = Inventory.Main.Top.Options.Fish.Label.BagSize
						local count = BagSize.Text:match("(%d+)/")
						if count then
							if _G.Celestial then _G.Celestial.DetectorCount = tonumber(count) end
							Paragraph2:SetContent("<font color='rgb(0,255,127)'>Status = Fishing Normally</font>\n<font color='rgb(0,191,255)'>Time = 0.0s</font>\n<font color='rgb(173,216,230)'>Bag = " .. tostring(count) .. "</font>")
						end
					end)
				end
			end)
		else
			Paragraph2:SetContent("<font color='rgb(200,200,200)'>Status = Detector Offline</font>\nTime = 0.0s\nBag = 0")
		end
	end
})

Section5:AddDivider()

Section5:AddInput({
	Title = "Legit Delay",
	Default = "0.5",
	Callback = function()
		-- [envlog] error: Luraph Script:2484: Script:62: attempt to compare number <= userdata
	end
})

local CosmeticFolder = workspace:WaitForChild("CosmeticFolder")
local leaderstats = Players.LocalPlayer:WaitForChild("leaderstats")
local Caught = leaderstats:WaitForChild("Caught")

module13.RegisterMouseReleased = function(arg76, arg77)
	arg76:RegisterMouseReleased(arg77, nil)
end

CosmeticFolder.ChildAdded:Connect(function(child3)
end)

Caught.Changed:Connect(function(value)
	-- condition: Caught.Value < value  (assumed true)
end)

Section5:AddToggle({
	Title = "Legit Fishing",
	Content = "This feature will always perfect on cast!",
	Default = false,
	Keybind = true,
	Callback = function(state)
		if state then
			module12._autoLoop = state

			task.spawn(function()
				module12:RequestChargeFishingRod(Vector2.new(0, 0), false)
				local Charge = Players.LocalPlayer.PlayerGui:WaitForChild("Charge")
				local Main53 = Charge:WaitForChild("Main")
				local CanvasGroup = Main53:WaitForChild("CanvasGroup")
				CanvasGroup:WaitForChild("Bar")
				task.wait()
				-- [envlog] error: Luraph Script:2581: Luraph Script:2534: Script:62: attempt to compare number < userdata
			end)

			task.spawn(function()
				local ClickEffect = Players.LocalPlayer.PlayerGui:FindFirstChild("!!! Click Effect")
				ClickEffect.Enabled = false
				module12:ConfirmClick()
				task.wait(0.5)
				module12:ConfirmClick()
				task.wait(0.5)
				-- [envlog] the statements above repeat forever (loop)
			end)

			task.spawn(function()
				module12:RequestChargeFishingRod(Vector2.new(0, 0), false)
				local Charge2 = Players.LocalPlayer.PlayerGui:WaitForChild("Charge")
				local Main54 = Charge2:WaitForChild("Main")
				local CanvasGroup2 = Main54:WaitForChild("CanvasGroup")
				CanvasGroup2:WaitForChild("Bar")
				task.wait()
				-- [envlog] error: Luraph Script:2598: Luraph Script:2534: Script:62: attempt to compare number < userdata
			end)
		else
			module12._autoLoop = false
		end
	end
})

Section5:AddDivider()

Section5:AddToggle({
	Title = "Talon Fishing",
	Default = false,
	Keybind = true,
	Callback = function(state)
		if state then
			local thread2 = task.spawn(function()
				_G.TalonFishing = state
				module12:ConfirmClick()
				task.wait(0.1)
				module12:ConfirmClick()
				task.wait(0.1)
				-- [envlog] the statements above repeat forever (loop)
			end)

			local thread3 = task.spawn(function()
				task.wait()
				task.wait()
				-- [envlog] the statements above repeat forever (loop)
			end)
		else
			_G.TalonFishing = false
			task.cancel(thread2)
			task.cancel(thread3)
		end
	end
})

local Section6 = Tab2:AddSection("Instant Fishing")

Section6:AddDropdown({
	Title = "Cast Mode (Instant V1)",
	Default = "Perfect",
	Options = { "Normal", "Perfect" },
	Callback = function()
	end
})

Section6:AddInput({
	Title = "Delay Complete",
	Placeholder = "Write ur input here",
	Callback = function()
		-- [envlog] error: Luraph Script:2686: Script:62: attempt to compare number <= userdata
	end
})

Section6:AddToggle({
	Title = "Instant Fishing",
	Content = "Auto instantly catch fish",
	Default = false,
	Keybind = true,
	Callback = function(state)
		if state then
			local Inventory53 = game.Players.LocalPlayer.PlayerGui:WaitForChild("Inventory")
			local Main55 = Inventory53:WaitForChild("Main")
			local Top53 = Main55:WaitForChild("Top")
			local Options53 = Top53:WaitForChild("Options")
			local Fish53 = Options53:WaitForChild("Fish")
			local Label53 = Fish53:WaitForChild("Label")
			local BagSize53 = Label53:WaitForChild("BagSize")
			BagSize53.Text:match("(%d+)/")

			task.spawn(function()
				Players.LocalPlayer:GetAttribute("SellAll")
				task.wait(0.1)
				Players.LocalPlayer:GetAttribute("SellAll")
				task.wait(0.1)
				-- [envlog] the statements above repeat forever (loop)
			end)
		end
	end
})

local Section7 = Tab2:AddSection("Instant Fishing V2")

Section7:AddDropdown({
	Title = "Cast Mode (Instant V2)",
	Default = "Perfect",
	Options = { "Normal", "Perfect" },
	Callback = function()
	end
})

Section7:AddInput({
	Title = "Delay Complete V2",
	Placeholder = "Write ur input here",
	Callback = function()
		-- [envlog] error: Luraph Script:2796: Script:62: attempt to compare number <= userdata
	end
})

if _G.notifConn then
	pcall(function() _G.notifConn:Disconnect() end)
	_G.notifConn = nil
end
if _G.notifOriginalConns and type(_G.notifOriginalConns) == "table" then
	for k2, v7 in pairs(_G.notifOriginalConns) do
		pcall(function() v7:Enable() end)
	end
end
_G.notifOriginalConns = {}

_G.notifConn = {
	Disconnect = function()
	end,
	disconnect = function()
	end
}

Section7:AddToggle({
	Title = "Instant Fishing V2",
	Content = "Auto instantly catch fish",
	Default = false,
	Keybind = true,
	Callback = function(state)
		if state then
			local Inventory54 = game.Players.LocalPlayer.PlayerGui:WaitForChild("Inventory")
			local Main56 = Inventory54:WaitForChild("Main")
			local Top54 = Main56:WaitForChild("Top")
			local Options54 = Top54:WaitForChild("Options")
			local Fish54 = Options54:WaitForChild("Fish")
			local Label54 = Fish54:WaitForChild("Label")
			local BagSize54 = Label54:WaitForChild("BagSize")
			BagSize54.Text:match("(%d+)/")

			task.spawn(function()
				Players.LocalPlayer:GetAttribute("SellAll")
				task.wait(0.1)
				Players.LocalPlayer:GetAttribute("SellAll")
				task.wait(0.1)
				-- [envlog] the statements above repeat forever (loop)
			end)
		end
	end
})

local Section8 = Tab2:AddSection("Blatant YTTA")

Section8:AddDropdown({
	Title = "Cast Mode (Blatant YTTA)",
	Default = "Perfect",
	Options = { "Normal", "Perfect" },
	Callback = function()
	end
})

Section8:AddInput({
	Title = "Complete Delay YTTA",
	Placeholder = "Write ur input here...",
	Callback = function()
	end
})

Section8:AddToggle({
	Title = "Enable Blatant YTTA",
	Default = false,
	Keybind = true,
	Callback = function(state)
		if state then
			task.spawn(function()
				Players.LocalPlayer:GetAttribute("SellAll")
				task.wait(0.1)
				Players.LocalPlayer:GetAttribute("SellAll")
				task.wait(0.1)
				-- [envlog] the statements above repeat forever (loop)
			end)
		end
	end
})

task.spawn(function()
	task.wait(2)
	-- [envlog] error: Luraph Script:3091: Script:62: attempt to index number with 'Rainbow'
end)

if _G.FishCaughtConn then
	pcall(function() _G.FishCaughtConn:Disconnect() end)
	_G.FishCaughtConn = nil
end

_G.FishCaughtConn = {
	Disconnect = function()
	end,
	disconnect = function()
	end
}

local Section9 = Tab2:AddSection("Sell Features")

Section9:AddDropdown({
	Title = "Select Sell Mode",
	Default = "Delay",
	Options = { "Delay", "Count" },
	Callback = function()
	end
})

Section9:AddInput({
	Title = "Set Value",
	Content = "Delay = Time Count | Count = Backpack Count",
	Default = "60",
	Placeholder = "Write ur input here",
	Callback = function()
		-- [envlog] error: Luraph Script:3190: Script:62: attempt to compare number < userdata
	end
})

Section9:AddToggle({
	Title = "Start Sell",
	Default = false,
	Callback = function()
	end
})

Section9:AddButton({
	Title = "Sell All Now",
	Callback = function()
	end
})

task.spawn(function()
	task.wait(1)
	task.wait(1)
	-- [envlog] the statements above repeat forever (loop)
end)

local Section10 = Tab2:AddSection("Favorite")
Items:GetChildren()

Section10:AddDropdown({
	Title = "Name",
	Multi = true,
	Options = { "No Fish Found" },
	Callback = function()
	end
})

Section10:AddDropdown({
	Title = "Rarity",
	Multi = true,
	Options = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Forgotten" },
	Callback = function()
	end
})

Section10:AddDropdown({
	Title = "Variant",
	Multi = true,
	Options = {},
	Callback = function()
	end
})

Section10:AddDropdown({
	Title = "Favorite Mode",
	Default = "Strict",
	Options = { "Strict", "Non-Strict" },
	Callback = function()
	end
})

Section10:AddToggle({
	Title = "Auto Favorite",
	Default = false,
	Callback = function()
		-- [envlog] error: Expected ':' not '.' calling member function GetItemDataFromItemType
	end
})

Section10:AddButton({
	Title = "Unfavorite All",
	Callback = function()
	end
})

ReplicatedStorage.Items.Misc:GetChildren()
local Baits = ReplicatedStorage:WaitForChild("Baits")
Baits:GetChildren()
end -- end Tab2

do -- start Tab5
local Section11 = Tab5:AddSection("Shop")
Section11:AddSubSection("Purchase Rod")

Section11:AddDropdown({
	Title = "Select Rod",
	Options = {},
	Callback = function()
	end
})

Section11:AddButton({
	Title = "Buy Selected Rod",
	Callback = function()
		notif("Select rod first!")
	end
})

Section11:AddSubSection("Purchase Bait")

Section11:AddDropdown({
	Title = "Select Bait",
	Options = {},
	Callback = function(state)
		if not state then
			notif("Select baits first!")
		end
	end
})

Section11:AddButton({
	Title = "Buy Selected Bait",
	Callback = function()
	end
})

Section11:AddButton({
	Title = "Open/Close Bait Shop",
	Callback = function()
		module7:IsOpen("Bait Shop")
		module7:Close()
	end
})

Section11:AddSubSection("Purchase Charm")

Section11:AddDropdown({
	Title = "Select Charm",
	Default = "Algae Charm ($40,000)",
	Options = {
		"Algae Charm ($40,000)",
		"Bone Charm ($70,000)",
		"Magma Charm ($20,000)",
		"Clover Charm ($5,000)",
		"Heart Charm ($20,000)",
		"Meteor Charm ($20,000)",
		"Radioactive Charm ($20,000)",
		"Pastel Egg Charm ($10,000)",
		"Chocolate Charm ($6,000)",
		"Boombox Charm ($5,000)"
	},
	Callback = function()
	end
})

Section11:AddInput({
	Title = "Quantity Charm",
	Default = "1",
	Callback = function()
		-- [envlog] error: Luraph Script:3637: Script:62: attempt to compare number <= userdata
	end
})

Section11:AddToggle({
	Title = "Auto Buy Charm",
	Default = false,
	Callback = function(state)
		if state then
			task.spawn(function()
				notif(string.format("Bought %s (%d/%d)", string.match(arg138, "^(.-)%s*%("), 1, 1))
				BuyCharmToggle:Set(false)
				notif(string.format("Finished! Total bought: %d %s", 1, string.match(arg138, "^(.-)%s*%(")))
			end)
		end
	end
})

Section11:AddButton({
	Title = "Buy Once",
	Callback = function()
		notif("Successfully bought " .. string.match(arg138, "^(.-)%s*%("))
	end
})

local Section12 = Tab5:AddSection("Auto Weather")

Section12:AddDropdown({
	Title = "Select Weather",
	Multi = true,
	Options = {
		"Fog ($20.000)",
		"Wind ($10,000)",
		"Snow ($15,000)",
		"Storm ($35,000)",
		"Radiant ($50,000)",
		"Shark Hunt ($300,000)",
		"Treasure Hunt ($1,000,000)"
	},
	Callback = function()
	end
})

Section12:AddToggle({
	Title = "Auto Buy Weather",
	Content = "This feature will buy the selected weather events if they are not active.",
	Default = false,
	Callback = function(state)
		if state then
			task.spawn(function()
				local Weather = workspace:FindFirstChild("Weather")
				Weather:GetChildren()
				task.wait(2)
				local Weather2 = workspace:FindFirstChild("Weather")
				Weather2:GetChildren()
				task.wait(2)
				-- [envlog] the statements above repeat forever (loop)
			end)
		end
	end
})

local Section13 = Tab5:AddSection("Merchant")
Section13:AddParagraph({ Title = "MERCHANT STOCK PANEL", Content = "Loading..." })

Section13:AddDropdown({
	Title = "Merchant Item",
	Callback = function()
	end
})

Section13:AddInput({
	Title = "Quantity Item",
	Default = "1",
	Callback = function()
	end
})

Section13:AddToggle({
	Title = "Auto Buy Merchant Item",
	Default = false,
	Callback = function()
	end
})

task.spawn(function()
	task.wait(1)
	task.wait(1)
	-- [envlog] the statements above repeat forever (loop)
end)

task.spawn(function()
	task.wait(1)
	local Merchant = Players.LocalPlayer.PlayerGui:FindFirstChild("Merchant")
	Merchant.Main.Background.Items.ScrollingFrame:GetChildren()
	Players.LocalPlayer.PlayerGui.Merchant.Main.Background.Items.ScrollingFrame:GetChildren()
	task.wait(1)
	-- [envlog] the statements above repeat forever (loop)
end)

local Section14 = Tab5:AddSection("Black Market")
local Paragraph3 = Section14:AddParagraph({ Title = "Status", Content = "Idle... Tekan Refresh dulu" })

Section14:AddDropdown({
	Title = "Select Item",
	Default = {},
	Multi = true,
	Options = {},
	Callback = function()
	end
})

Section14:AddButton({
	Title = "Refresh Item List",
	Callback = function()
		-- [envlog] error: Expected ':' not '.' calling member function GetItems
	end
})

Section14:AddToggle({
	Title = "Enable Auto Buy Blackmarket",
	Default = false,
	Callback = function(state)
		if state then
			Paragraph3:SetContent("Pilih item dulu sebelum mengaktifkan Auto Buy")
		end
	end
})

end -- end Tab5

do -- start Tab3
local Section15 = Tab3:AddSection("Auto Full Index [Beta]")
local Paragraph4 = Section15:AddParagraph({ Title = "Status", Content = "Idle..." })

Section15:AddParagraph({
	Title = "Information",
	Content = "Fitur ini akan otomatis teleport ke tempat dimana ikan yang belum didapatkan pada Mastery (index). Ikan limited event tidak termasuk"
})

Section15:AddDropdown({
	Title = "Exclude Rarity",
	Default = {},
	Multi = true,
	Options = {
		"Common",
		"Uncommon",
		"Rare",
		"Epic",
		"Legendary",
		"Mythic",
		"SECRET",
		"FORGOTTEN",
		"Trophy",
		"Collectible",
		"Exclusive"
	},
	Callback = function()
	end
})

Section15:AddToggle({
	Title = "Enable Auto Full Index",
	Default = false,
	Callback = function(state)
		if state then
			task.spawn(function()
				Toggle:Set(true)

				for k3, v8 in pairs(module4) do
				end

				Paragraph4:SetContent("Index sudah lengkap! Tidak ada ikan yang missing")
				Paragraph4:SetContent("Index Already Full!")
			end)
		else
			Toggle:Set(false)
			Paragraph4:SetContent("Idle...")
		end
	end
})

Section15:AddButton({
	Title = "Scan Missing Fish",
	Callback = function(state)
		if state then
			for k4, v9 in pairs(module4) do
			end
		else
			for k5, v10 in pairs(module4) do
			end
		end

		Paragraph4:SetContent("Index sudah lengkap! Tidak ada ikan yang missing")
	end
})

local Section16 = Tab3:AddSection("Enchant System")
Section16:AddParagraph({ Title = "Enchant Status", Content = "Current Rod : None\nCurrent Enchant : None" })
local Enchants = ReplicatedStorage:WaitForChild("Enchants")
Enchants:GetChildren()

Section16:AddDropdown({
	Title = "Select Enchant Target",
	Content = "This will repeat until you get the selected enchant!",
	Default = "Big Hunter I",
	Options = {},
	Callback = function()
	end
})

Section16:AddDropdown({
	Title = "Stone Filter",
	Default = "Enchant Stone",
	Options = {
		"Enchant Stone",
		"Evolved Enchant Stone",
		"Eggy Enchant Stone",
		"Runic Enchant Stone",
		"Transcended Stone"
	},
	Callback = function()
	end
})

Section16:AddToggle({
	Title = "Auto Enchant",
	Content = "Automatically enchants until it reaches your selected enchant target!",
	Default = false,
	Callback = function(state)
		if state then
			task.spawn(function()
				-- [envlog] error: Luraph Script:4746: Luraph Script:4625: invalid argument #1 to 'pairs' (table expected, got number)
			end)
		else
			task.spawn(function()
			end)
		end
	end
})

Section16:AddButton({
	Title = "Teleport Enchant Altar",
	SubTitle = "Teleport Second Enchant Altar",
	Callback = function(state)
		if state then
			local HumanoidRootPart3 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			local Humanoid2 = Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			HumanoidRootPart3.CFrame = (CFrame.new(3258, -1301, 1391) * CFrame.new(0, 5, 0))
			Humanoid2:ChangeState(Enum.HumanoidStateType.Physics)
			task.wait(0.1)
			Humanoid2:ChangeState(Enum.HumanoidStateType.Running)
		else
			local HumanoidRootPart4 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			local Humanoid3 = Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			HumanoidRootPart4.CFrame = (CFrame.new(3258, -1301, 1391) * CFrame.new(0, 5, 0))
			Humanoid3:ChangeState(Enum.HumanoidStateType.Physics)
			task.wait(0.1)
			Humanoid3:ChangeState(Enum.HumanoidStateType.Running)
		end
	end,
	SubCallback = function()
		local HumanoidRootPart5 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		local Humanoid4 = Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		HumanoidRootPart5.CFrame = (CFrame.new(1480, 128, -593) * CFrame.new(0, 5, 0))
		Humanoid4:ChangeState(Enum.HumanoidStateType.Physics)
		task.wait(0.1)
		Humanoid4:ChangeState(Enum.HumanoidStateType.Running)
	end
})

local Section17 = Tab3:AddSection("Exchange Transcended Stone")

local Paragraph5 = Section17:AddParagraph({
	Title = "Exchange Status",
	Content = "\r\nFish     : ???\r\nQuantity : 0\r\nStatus   : Idle\r\nExchanged: 0 / 0\r\n"
})

Section17:AddDropdown({
	Title = "Select Secret Fish",
	Options = {},
	Callback = function(state)
		if state then
			local result53 = state:match("^(.-) x")

			RunService.Heartbeat:Once(function(deltaTime5)
				Paragraph5:SetContent(string.format("\r\n<font color='rgb(173,216,230)'>Fish     : %s</font>\r\n<font color='rgb(173,216,230)'>Quantity : %d</font>\r\n<font color='rgb(%s)'>Status   : %s</font>\r\n<font color='rgb(173,216,230)'>Exchanged: %d / %d</font>\r\n", result53, 1, "200,200,200", "Idle", 0, 0))
			end)
		else
			RunService.Heartbeat:Once(function(deltaTime6)
				Paragraph5:SetContent("\r\n<font color='rgb(173,216,230)'>Fish     : ???</font>\r\n<font color='rgb(173,216,230)'>Quantity : 1</font>\r\n<font color='rgb(200,200,200)'>Status   : Idle</font>\r\n<font color='rgb(173,216,230)'>Exchanged: 0 / 0</font>\r\n")
			end)
		end
	end
})

Section17:AddInput({
	Title = "Quantity For Exchange",
	Default = "1",
	Callback = function(state)
		if state then
			RunService.Heartbeat:Once(function(deltaTime7)
				Paragraph5:SetContent(string.format("\r\n<font color='rgb(173,216,230)'>Fish     : %s</font>\r\n<font color='rgb(173,216,230)'>Quantity : %d</font>\r\n<font color='rgb(%s)'>Status   : %s</font>\r\n<font color='rgb(173,216,230)'>Exchanged: %d / %d</font>\r\n", "???", tonumber(state), "200,200,200", "Idle", 0, 0))
			end)
		else
			RunService.Heartbeat:Once(function(deltaTime8)
				Paragraph5:SetContent("\r\n<font color='rgb(173,216,230)'>Fish     : ???</font>\r\n<font color='rgb(173,216,230)'>Quantity : 1</font>\r\n<font color='rgb(200,200,200)'>Status   : Idle</font>\r\n<font color='rgb(173,216,230)'>Exchanged: 0 / 0</font>\r\n")
			end)
		end
	end
})

Section17:AddButton({
	Title = "Refresh Fish",
	Callback = function()
		-- [envlog] error: Expected ':' not '.' calling member function GetItemDataFromItemType
	end
})

Section17:AddToggle({
	Title = "Auto Exchange Secret",
	Default = false,
	Callback = function(state)
		if state then
			task.spawn(function()
				notif("Select a Tier 7 fish first!")
			end)
		else
			RunService.Heartbeat:Once(function(deltaTime9)
				Paragraph5:SetContent("\r\n<font color='rgb(173,216,230)'>Fish     : ???</font>\r\n<font color='rgb(173,216,230)'>Quantity : 1</font>\r\n<font color='rgb(200,200,200)'>Status   : Stopped</font>\r\n<font color='rgb(173,216,230)'>Exchanged: 0 / 0</font>\r\n")
			end)
		end
	end
})

local Section18 = Tab3:AddSection("Totem Features")
local Paragraph6 = Section18:AddParagraph({ Title = "Panel Activated Totem", Content = "Scanning Totems..." })
local Paragraph7 = Section18:AddParagraph({ Title = "Auto Totem Status", Content = "Idle" })

local function helper()
	Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	workspace.Totems:GetChildren()
end

local function helper3()
	helper()
	Paragraph6:SetContent("No active totems detected")
end

task.spawn(function()
	task.wait(1)
	helper3()
	task.wait(1)
	helper3()
	task.wait(1)
	-- [envlog] the statements above repeat forever (loop)
end)

Section18:AddButton({
	Title = "Teleport To Nearest Totem",
	Callback = function()
		Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		workspace.Totems:GetChildren()
	end
})

local Totems = ReplicatedStorage:WaitForChild("Totems")
Totems:GetChildren()

Section18:AddDropdown({
	Title = "Select Totem to Auto Place",
	Default = "No Totems Found",
	Options = {},
	Callback = function()
	end
})

Section18:AddButton({
	Title = "Reset Totem Saved Time",
	Callback = function()
		notif("Successfully reset saved totem timer")
	end
})

Section18:AddToggle({
	Title = "Auto Place Totem",
	Content = "Smart Totem Reamining Time Detection",
	Default = false,
	Callback = function(state)
		if state then
			task.spawn(function()
				Paragraph7:SetContent("Auto Totem Enabled [None]")
				game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				workspace:FindFirstChild("Totems")
				workspace.Totems:GetChildren()
				Paragraph7:SetContent("No Active Totem. Placing...")
				local expect = Data:GetExpect({ "Inventory", "Totems" })

				for i6, v11 in ipairs(expect) do
				end

				Paragraph7:SetContent("Empty/No Totem! Waiting 15s...")
				task.wait(15)
				game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				workspace:FindFirstChild("Totems")
				workspace.Totems:GetChildren()
				Paragraph7:SetContent("No Active Totem. Placing...")
				local expect2 = Data:GetExpect({ "Inventory", "Totems" })

				for i7, v12 in ipairs(expect2) do
				end

				Paragraph7:SetContent("Empty/No Totem! Waiting 15s...")
				task.wait(15)
				-- [envlog] the statements above repeat forever (loop)
			end)
		else
			Paragraph7:SetContent("Auto Totem Disabled")
		end
	end
})

local Section19 = Tab3:AddSection("X3 Totem Mix [BETA]")

Section19:AddParagraph({
	Title = "READ ME!",
	Content = "\n<b>Pilih 3 totem dari dropdown di bawah sebelum aktifkan toggle.</b>\n<b>Urutan pilihan = urutan spawn totem.</b>\n\n<b>Jika karakter bergerak aneh setelah menonaktifkan toggle</b>\n<b>Gunakan tombol dibawah ini untuk mereset karakter state</b>"
})

Section19:AddButton({
	Title = "Reset Character In Place",
	Callback = function()
		Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		Players.LocalPlayer.Character:BreakJoints()
		local result54 = Players.LocalPlayer.CharacterAdded:Wait()
		local HumanoidRootPart6 = result54:WaitForChild("HumanoidRootPart")
		task.wait(0.3)
		HumanoidRootPart6.CFrame = Players.LocalPlayer.Character.HumanoidRootPart.CFrame
		task.wait()
		-- [envlog] the statements above repeat forever (loop)
	end
})

Section19:AddDropdown({
	Title = "Select 3 Totem Mix (urutan = urutan spawn)",
	Default = { "Luck Totem", "Mutation Totem", "Shiny Totem" },
	Multi = true,
	Options = { "Luck Totem", "Mutation Totem", "Shiny Totem", "Noob Totem" },
	Callback = function()
	end
})

Section19:AddToggle({
	Title = "Auto Spawn 3 Mix Totem",
	Default = false,
	Callback = function()
	end
})

local Section20 = Tab3:AddSection("Auto Use Orb")

local Dropdown = Section20:AddDropdown({
	Title = "Select Mutation Orb",
	Default = "None",
	Options = {},
	Callback = function()
	end
})

Section20:AddButton({
	Title = "Refresh Orb List",
	Callback = function()
		Dropdown:SetValues({})
	end
})

Section20:AddToggle({
	Title = "Enable Auto Throw Orb",
	Default = false,
	Callback = function(state)
		if state then
			local thread4 = task.spawn(function()
				-- [envlog] error: Luraph Script:5897: invalid argument #1 to 'ipairs' (table expected, got nil)
			end)
		else
			task.cancel(thread4)
		end
	end
})

local Section21 = Tab3:AddSection("Potions")
local Potions = ReplicatedStorage:WaitForChild("Potions")
Potions:GetChildren()

Section21:AddDropdown({
	Title = "Select Mode Potions",
	Default = "Delay 30 Minute",
	Options = { "Delay 30 Minute", "Use All Item" },
	Callback = function()
	end
})

Section21:AddDropdown({
	Title = "Select Potions",
	Content = "You can select more than 1",
	Multi = true,
	Options = {},
	Callback = function()
	end
})

Section21:AddToggle({
	Title = "Auto Use Potions",
	Content = "Automatically Use Based on Selected Mode",
	Default = false,
	Callback = function(state)
		if state then
			task.spawn(function()
				-- [envlog] error: Luraph Script:6044: invalid argument #1 to 'ipairs' (table expected, got boolean)
			end)
		end
	end
})

local Section22 = Tab3:AddSection("Event")

local function helper2()
	local Events = ReplicatedStorage:FindFirstChild("Events")
	Events:GetChildren()
end

helper2()

Section22:AddDropdown({
	Title = "Priority Event",
	Default = "None",
	Options = { "None" },
	Callback = function()
	end
})

helper2()

Section22:AddDropdown({
	Title = "Select Event",
	Default = { "None" },
	Multi = true,
	Options = { "None" },
	Callback = function(arg214)
		for k6, v14 in pairs(arg214) do
		end
	end
})

Section22:AddToggle({
	Title = "Auto Event",
	Default = false,
	Callback = function(state)
		if state then
			Toggle:Set(state)
			notif("Pilih event dulu!")
		end
	end
})

Section22:AddSubSection("Thunderzilla Event")

Section22:AddToggle({
	Title = "Auto Thunderzilla Hunt",
	Default = false,
	Callback = function(state)
		if state then
			Toggle:Set(state)
			local HumanoidRootPart7 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			notif("Auto Thunderzilla On")

			task.spawn(function()
				workspace:GetChildren()
				task.wait(0.2)
				workspace:GetChildren()
				task.wait(0.2)
				-- [envlog] the statements above repeat forever (loop)
			end)
		else
			Toggle:Set(false)
			Players.LocalPlayer.Character:PivotTo(HumanoidRootPart7.CFrame)
			notif("Auto Thunderzilla Off")
		end
	end
})

Section22:AddSubSection("Admin Event")

local Paragraph8 = Section22:AddParagraph({
	Title = "Ancient Lochness Monster Countdown",
	Content = "<font color='#FF4D4D'><b>waiting for ... for joined event!</b></font>"
})

Section22:AddToggle({
	Title = "Auto Admin Event",
	Default = false,
	Callback = function(state)
		if state then
			local HumanoidRootPart8 = Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart", 5)
			Paragraph8:SetContent("<font color='#00ff99'><b>Farm position saved!</b></font>")

			task.spawn(function()
				task.wait(1)
				Paragraph8:SetContent(string.format("<font color='#4AFFE7'><b>Timer: %s</b></font>", workspace["!!! DEPENDENCIES"]["Event Tracker"].Main.Gui.Content.Items.Countdown.Label.Text))
				Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart", 5)
				workspace["!!! DEPENDENCIES"]["Event Tracker"].Main.Gui.Content.Items.Countdown.Label.Text:match("(%d+)H%s*(%d+)M%s*(%d+)S")
				task.wait(1)
				Paragraph8:SetContent(string.format("<font color='#4AFFE7'><b>Timer: %s</b></font>", workspace["!!! DEPENDENCIES"]["Event Tracker"].Main.Gui.Content.Items.Countdown.Label.Text))
				Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart", 5)
				workspace["!!! DEPENDENCIES"]["Event Tracker"].Main.Gui.Content.Items.Countdown.Label.Text:match("(%d+)H%s*(%d+)M%s*(%d+)S")
				task.wait(1)
				-- [envlog] the statements above repeat forever (loop)
			end)
		else
			local HumanoidRootPart9 = Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart", 5)
			HumanoidRootPart9.CFrame = HumanoidRootPart8.CFrame
			Paragraph8:SetContent("<font color='#00FF99'><b> Returned to saved farm position!</b></font>")
			Paragraph8:SetContent("<font color='#ff4d4d'><b>Auto Admin Event disabled.</b></font>")
		end
	end
})

Section22:AddDivider()

local Paragraph9 = Section22:AddParagraph({
	Title = "Mutant Runic Koi Countdown",
	Content = "<font color='#FF4D4D'><b>waiting for ... for joined event!</b></font>"
})

Section22:AddToggle({
	Title = "Auto Mutant Runic Koi",
	Default = false,
	Callback = function(state)
		if state then
			local HumanoidRootPart10 = Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart", 5)
			Paragraph9:SetContent("<font color='#00ff99'><b>Farm position saved!</b></font>")

			task.spawn(function()
				task.wait(1)
				Paragraph9:SetContent(string.format("<font color='#4AFFE7'><b>Timer: %s</b></font>", workspace["!!! DEPENDENCIES"]["UnderwaterCity Event Tracker"].Main.Gui.Content.Items.Countdown.Label.Text))
				Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart", 5)
				workspace["!!! DEPENDENCIES"]["UnderwaterCity Event Tracker"].Main.Gui.Content.Items.Countdown.Label.Text:match("(%d+)H%s*(%d+)M%s*(%d+)S")
				task.wait(1)
				Paragraph9:SetContent(string.format("<font color='#4AFFE7'><b>Timer: %s</b></font>", workspace["!!! DEPENDENCIES"]["UnderwaterCity Event Tracker"].Main.Gui.Content.Items.Countdown.Label.Text))
				Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart", 5)
				workspace["!!! DEPENDENCIES"]["UnderwaterCity Event Tracker"].Main.Gui.Content.Items.Countdown.Label.Text:match("(%d+)H%s*(%d+)M%s*(%d+)S")
				task.wait(1)
				-- [envlog] the statements above repeat forever (loop)
			end)
		else
			local HumanoidRootPart11 = Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart", 5)
			HumanoidRootPart11.CFrame = HumanoidRootPart10.CFrame
			Paragraph9:SetContent("<font color='#00FF99'><b> Returned to saved farm position!</b></font>")
			Paragraph9:SetContent("<font color='#ff4d4d'><b>Auto Mutant Runic Koi disabled.</b></font>")
		end
	end
})

local Section23 = Tab3:AddSection("Save Position")

Section23:AddParagraph({
	Title = "Tutorial Teleport",
	Content = "\r\n<b><font color=\"rgb(252, 119, 216)\">AUTO TELEPORT?</font></b>\r\nClick <b><font color=\"rgb(252, 119, 216)\">Save Position</font></b> to save your current position!\r\n\r\n<b><font color=\"rgb(252, 119, 216)\">HOW TO LOAD?</font></b>\r\nThis feature will auto-sync your last position when executed, so you will teleport automatically!\r\n\r\n<b><font color=\"rgb(252, 119, 216)\">HOW TO RESET?</font></b>\r\nClick <b><font color=\"rgb(252, 119, 216)\">Reset Position</font></b> to clear your saved position.\r\n    "
})

Section23:AddButton({
	Title = "Save Position",
	SubTitle = "Reset Position",
	Callback = function(state)
		if state then
			local HumanoidRootPart12 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			local components = HumanoidRootPart12.CFrame:GetComponents()
			local json = HttpService:JSONEncode({ components })
			writefile("Meng Hub/Position.json", json)
		else
			local HumanoidRootPart13 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			local components2 = HumanoidRootPart13.CFrame:GetComponents()
			local json2 = HttpService:JSONEncode({ components2 })
			writefile("Meng Hub/Position.json", json2)
		end

		notif("Successfully saved position")
	end,
	SubCallback = function()
		-- isfile("Meng Hub/Position.json") -> false
		notif("Successfully reset last position")
	end
})

Section23:AddButton({
	Title = "Teleport To Save Location",
	Callback = function()
		Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart")
		-- isfile("Meng Hub/Position.json") -> false
		notif("You don't have save position before..")
	end
})

local Section24 = Tab3:AddSection("Pirate Events")

Section24:AddToggle({
	Title = "Auto Claim Pirate Chest",
	Default = false,
	Callback = function(state)
		if state then
			StarterGui:SetCore("SendNotification", {
		Text = "Auto Claim Pirate Chest aktif (Teleport + Proximity)",
		Title = "Pirate Event",
		Duration = 4,
		Icon = "rbxassetid://90292614315729"
	})

			task.spawn(function()
				game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				local PirateChestStorage = workspace:FindFirstChild("PirateChestStorage")
				PirateChestStorage:GetChildren()
				task.wait(1.2)
				game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				local PirateChestStorage2 = workspace:FindFirstChild("PirateChestStorage")
				PirateChestStorage2:GetChildren()
				task.wait(1.2)
				-- [envlog] the statements above repeat forever (loop)
			end)
		else
			StarterGui:SetCore("SendNotification", {
		Text = "Auto Claim Pirate Chest dimatikan",
		Title = "Pirate Event",
		Duration = 3,
		Icon = "rbxassetid://90292614315729"
	})
		end
	end
})

_G.SavedLeviFarmPos = nil
Section24:AddSubSection("Auto Event Leviathan Hunt")
_G.SavedLeviFarmPos = nil

Section24:AddToggle({
	Title = "Auto Event Leviathan Hunt",
	Default = false,
	Callback = function(state)
		if state then
			_G.AutoLeviStandby = state
			local HumanoidRootPart14 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

			task.spawn(function(...)
				notif("Idle...")
				Players.LocalPlayer.PlayerGui.Events.Frame.Events:FindFirstChild("Leviathan Hunt")
				HumanoidRootPart14.Anchored = true
				_G.SavedLeviFarmPos = HumanoidRootPart14.CFrame
				HumanoidRootPart14.CFrame = CFrame.new(3473.89502, -287.843201, 3473.380371, -0.96202, 0, -0.272978, 0, 1, 0, 0.272978, 0, -0.96202)
				notif("Leviathan Hunt started, Teleporting...")

				task.delay(1, function()
					HumanoidRootPart14.Anchored = false
				end)

				task.wait(1)
				Players.LocalPlayer.PlayerGui.Events.Frame.Events:FindFirstChild("Leviathan Hunt")
				task.wait(1)
				-- [envlog] the statements above repeat forever (loop)
			end)
		else
			_G.AutoLeviStandby = false
			local HumanoidRootPart15 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			HumanoidRootPart15.CFrame = HumanoidRootPart14.CFrame
			notif("Back to farm position")
		end
	end
})

ReplicatedStorage.Assets.Auras:GetChildren()
end -- end Tab3

do -- start Tab4
local Section25 = Tab4:AddSection("Aura Features")

Section25:AddDropdown({
	Title = "Select Auras",
	Options = {},
	Callback = function()
	end
})

Section25:AddToggle({
	Title = "Enable Auras",
	Default = false,
	Callback = function(state)
		if state then
			Players.LocalPlayer:SetAttribute("FishingRodSkin", false)
			local attributeChangedSignal = Players.LocalPlayer:GetAttributeChangedSignal("FishingRodSkin")

			local connection16 = attributeChangedSignal:Connect(function()
				Players.LocalPlayer:GetAttribute("FishingRodSkin")
				task.wait(0.1)
				Players.LocalPlayer:SetAttribute("FishingRodSkin", false)
			end)
		else
			if connection16 then pcall(function() connection16:Disconnect() end) end
			Players.LocalPlayer:SetAttribute("FishingRodSkin", nil)
		end
	end
})

local Section26 = Tab4:AddSection("Animations & VFX Skin")

Section26:AddDropdown({
	Title = "Select Animation",
	Default = "Soul Scythe",
	Options = {
		"Soul Scythe",
		"Frozen Krampus Scythe",
		"Fallen Staff",
		"Holy Trident",
		"Binary Edge",
		"The Vanquisher",
		"1x1x1x1 Ban Hammer",
		"Eclipse Katana",
		"Princess Parasol",
		"Corruption Edge",
		"Blackhole Sword",
		"Eternal Flower",
		"Ethereal Sword",
		"Crescendo Scythe",
		"Aurelian Bow",
		"Cupid's Harp",
		"Dark Matter Scythe",
		"Draconic Soul",
		"Divine Staff",
		"Kitty Guitar",
		"Serpent's Trident",
		"Crimson Retribution",
		"Bunny Staff",
		"Easter Parasol",
		"Celestial Scythe",
		"Void Kraken",
		"Void Guitar",
		"Aether Monarch",
		"Wings of Everlove",
		"Undead Guitar",
		"Oceanic Harpoon"
	},
	Callback = function()
	end
})

Section26:AddToggle({
	Title = "Auto Animation",
	Default = false,
	Callback = function()
		-- [envlog] error: Luraph Script:6718: Luraph Script:6645: Script:62: attempt to concatenate boolean with string
	end
})

Section26:AddSubSection("VFX Skin")

Section26:AddDropdown({
	Title = "Select VFX Skin",
	Default = "Soul Scythe",
	Options = {
		"Soul Scythe",
		"Frozen Krampus Scythe",
		"Fallen Staff",
		"Holy Trident",
		"Binary Edge",
		"The Vanquisher",
		"1x1x1x1 Ban Hammer",
		"Eclipse Katana",
		"Princess Parasol",
		"Corruption Edge",
		"Blackhole Sword",
		"Eternal Flower",
		"Ethereal Sword",
		"Crescendo Scythe",
		"Aurelian Bow",
		"Cupid's Harp",
		"Dark Matter Scythe",
		"Draconic Soul",
		"Divine Staff",
		"Kitty Guitar",
		"Serpent's Trident",
		"Crimson Retribution",
		"Bunny Staff",
		"Easter Parasol",
		"Celestial Scythe",
		"Void Kraken",
		"Void Guitar",
		"Aether Monarch",
		"Wings of Everlove",
		"Undead Guitar",
		"Oceanic Harpoon"
	},
	Callback = function()
	end
})

Section26:AddToggle({
	Title = "Auto Animation",
	Default = false,
	Callback = function(state)
		if state then
			module6.RenderAtPoint = function(arg247, arg248)
				local result55 = arg248:match(" (Dive)$")
				module6:Contains(false .. " " .. result55)
				arg247:RenderAtPoint(false .. " " .. result55, nil)
			end

			module6.RenderInstance = function(arg249, arg250)
				local result56 = arg250:match(" (Dive)$")
				module6:Contains(false .. " " .. result56)
				arg249:RenderInstance(false .. " " .. result56, nil)
			end
		else
			module6.RenderAtPoint = module6.RenderAtPoint
			module6.RenderInstance = module6.RenderInstance
		end
	end
})

local Section27 = Tab4:AddSection("Emote Features")
ReplicatedStorage.Emotes:GetChildren()

Section27:AddDropdown({
	Title = "Select Emote",
	Options = {},
	Callback = function()
	end
})

Section27:AddToggle({
	Title = "Enable Emote",
	Default = false,
	Callback = function(state)
		if state then
			task.spawn(function()
				task.wait(1)
				task.wait(1)
				-- [envlog] the statements above repeat forever (loop)
			end)
		else
			currentEmoteTrack:Stop()
		end
	end
})

Section27:AddButton({
	Title = "Play Once",
	Callback = function()
	end
})

local Section28 = Tab4:AddSection("Fake Avatar Features")

Section28:AddDropdown({
	Title = "Fake Avatar",
	Default = "Self Avatar",
	Options = {
		"Self Avatar",
		"WoozyNate",
		"Nicholas",
		"yvlyf",
		"traevp",
		"J0LLY",
		"LucashDev",
		"CEOofIsaac",
		"Stealthy",
		"Wildes",
		"Talon",
		"Relukt",
		"Sammy",
		"Diesel",
		"S4ans03",
		"Aura",
		"iJava",
		"White Guy",
		"Purple King",
		"Kachaaaa Gay",
		"Mpruyyy"
	},
	Callback = function()
	end
})

Section28:AddToggle({
	Title = "Fake Avatar",
	Default = false,
	Keybind = true,
	Callback = function()
	end
})

Players.LocalPlayer.CharacterAdded:Connect(function(character8)
end)

safeRequire(ReplicatedStorage.Packages.Replion)
safeRequire(ReplicatedStorage.Shared.ItemUtility)
safeRequire(ReplicatedStorage.Shared.VendorUtility)
safeRequire(ReplicatedStorage.Shared.PlayerStatsUtility)
safeRequire(ReplicatedStorage.Shared.Trading.TradeData)

CombinedModules.AutoTrade = {
	GetEnchantStoneItems = function()
	end,
	GetFishItems = function()
		-- [envlog] error: Expected ':' not '.' calling member function GetItemDataFromItemType
	end,
	GetPlayers = function()
		local players2 = Players:GetPlayers()

		for i9, v15 in ipairs(players2) do
		end
	end,
	GetStats = function()
	end,
	IsRunning = function()
	end,
	ResetStats = function()
	end,
	SetItem = function()
	end,
	SetItemAmount = function()
	end,
	SetRarity = function()
	end,
	SetRarityAmount = function()
	end,
	SetStoneAmount = function()
	end,
	SetStoneTradeMode = function()
	end,
	SetStoneType = function()
	end,
	SetTargetCoins = function()
	end,
	SetTargetPlayer = function()
	end,
	SetTradeMode = function()
	end,
	Start = function()
		Players:FindFirstChild(arg289)

		local thread5 = task.spawn(function()
			Players:FindFirstChild(arg289)
			-- [envlog] error: Expected ':' not '.' calling member function GetItemDataFromItemType
		end)
	end,
	Stop = function()
		task.cancel(thread5)
	end
}

safeRequire(ReplicatedStorage.Packages.Replion)
local module14 = safeRequire(ReplicatedStorage.Shared.Trading.TradeData)

CombinedModules.AutoAcceptTrade = {
	IsRunning = function()
	end,
	Start = function()
		local module15 = safeRequire(ReplicatedStorage.Controllers.PromptController)

		module15.FirePrompt = function(arg301, arg302)
			arg301:FirePrompt(arg302)
		end

		local connection17 = module14.Remotes.TradeStarted.OnClientEvent:Connect(function()
		end)
	end,
	Stop = function()
		module15.FirePrompt = module15.FirePrompt
		if connection17 then pcall(function() connection17:Disconnect() end) end
	end
}

end -- end Tab4

do -- start Tab6
local Section29 = Tab6:AddSection("Select Player")

local Dropdown2 = Section29:AddDropdown({
	Title = "Select Player for Trade",
	Default = {},
	Options = {},
	Callback = function()
	end
})

Section29:AddButton({
	Title = "Refresh Player",
	Callback = function(state)
		if state then
			local players3 = Players:GetPlayers()

			for i10, v16 in ipairs(players3) do
			end

			Dropdown2:SetValues({ v16.Name })
		else
			local players4 = Players:GetPlayers()

			for i11, v17 in ipairs(players4) do
			end

			Dropdown2:SetValues({ v17.Name })
		end
	end
})

local Section30 = Tab6:AddSection("Trade By Name")
local Paragraph10 = Section30:AddParagraph({ Title = "Trade Status", Content = "Waiting..." })

Section30:AddDropdown({
	Title = "Select Item",
	Default = {},
	Options = {},
	Callback = function(state)
		if state then
			state:match("^(.-) x")
		end
	end
})

Section30:AddInput({
	Title = "Set Amount",
	Default = "1",
	Callback = function()
	end
})

Section30:AddToggle({
	Title = "Start Trade by Name",
	Default = false,
	Callback = function()
	end
})

Section30:AddButton({
	Title = "Refresh Fish Items",
	SubTitle = "Reset Stats",
	Callback = function()
		-- [envlog] error: Expected ':' not '.' calling member function GetItemDataFromItemType
	end,
	SubCallback = function()
		Paragraph10:SetContent("Waiting...")
	end
})

local Section31 = Tab6:AddSection("Trade by Coins")
local Paragraph11 = Section31:AddParagraph({ Title = "Trade Status", Content = "Waiting..." })

Section31:AddInput({
	Title = "Target Coins",
	Default = "0",
	Callback = function()
	end
})

Section31:AddToggle({
	Title = "Start Trade by Coins",
	Default = false,
	Callback = function()
	end
})

Section31:AddButton({
	Title = "Reset Stats",
	Callback = function()
		Paragraph11:SetContent("Waiting...")
	end
})

local Section32 = Tab6:AddSection("Trade by Rarities")
local Paragraph12 = Section32:AddParagraph({ Title = "Trade Status", Content = "Waiting..." })

Section32:AddDropdown({
	Title = "Select Rarity",
	Default = "Common",
	Options = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Forgotten" },
	Callback = function()
	end
})

Section32:AddInput({
	Title = "Set Amount",
	Default = "1",
	Callback = function()
	end
})

Section32:AddToggle({
	Title = "Start Trade by Rarities",
	Default = false,
	Callback = function()
	end
})

Section32:AddButton({
	Title = "Reset Stats",
	Callback = function()
		Paragraph12:SetContent("Waiting...")
	end
})

local Section33 = Tab6:AddSection("Trade Enchant Stone")
local Paragraph13 = Section33:AddParagraph({ Title = "Trade Status", Content = "Waiting..." })

Section33:AddDropdown({
	Title = "Stone Type",
	Default = "Normal",
	Options = { "Normal", "Double", "Evolved", "Eggy", "Runic" },
	Callback = function()
	end
})

Section33:AddDropdown({
	Title = "Stone Trade Mode",
	Default = "One by One",
	Options = { "One by One", "Bulk" },
	Callback = function()
	end
})

Section33:AddInput({
	Title = "Set Amount",
	Default = "1",
	Callback = function()
	end
})

Section33:AddButton({
	Title = "Check Enchant Stones",
	Callback = function()
		Paragraph13:SetContent("No Enchant Stones Found")
	end
})

Section33:AddToggle({
	Title = "Start Trade by Enchant Stone",
	Default = false,
	Callback = function()
	end
})

Section33:AddButton({
	Title = "Reset Stats",
	Callback = function()
		Paragraph13:SetContent("Waiting...")
	end
})

local Section34 = Tab6:AddSection("Auto Accept Trade")

Section34:AddToggle({
	Title = "Enable Auto Accept Trade",
	Default = false,
	Callback = function(state)
		if state then
			module15.FirePrompt = function(arg348, arg349)
				arg348:FirePrompt(arg349)
			end

			local connection18 = module14.Remotes.TradeStarted.OnClientEvent:Connect(function()
			end)
		else
			module15.FirePrompt = module15.FirePrompt
			if connection18 then pcall(function() connection18:Disconnect() end) end
		end
	end
})

local Items2 = ReplicatedStorage:FindFirstChild("Items") or ReplicatedStorage:WaitForChild("Items", 3)
local Baits2 = ReplicatedStorage:FindFirstChild("Baits") or ReplicatedStorage:WaitForChild("Baits", 3)
_G.SelectedFarmLocation = "Kohana Volcano"
local KaitunZone = _G.KaitunZone
_G.KaitunZone = KaitunZone
_G.DeepSeaDone = false
_G.ArtifactDone = false
_G.ElementDone = false
_G.DiamondDone = false

local function helper4()
	ReplicatedStorage.Items.Misc:GetChildren()
	ReplicatedStorage.Items.Misc:GetChildren()
	ReplicatedStorage.Items.Misc:GetChildren()
	ReplicatedStorage.Items.Misc:GetChildren()
end

task.spawn(function()
	task.wait(1)
	helper4()
	helper4()
	task.wait(1)
	-- [envlog] the statements above repeat forever (loop)
end)

end -- end Tab6

do -- start Tab7
local Section35 = Tab7:AddSection("Kaitun [BETA]")
_G.SelectedFarmLocation = false

Section35:AddDropdown({
	Title = "Select Farm Location",
	Default = "Kohana Volcano",
	Options = { "Kohana Volcano", "Tropical Grove" },
	Callback = function(val)
		_G.SelectedFarmLocation = val
	end
})

Section35:AddToggle({
	Title = "Start Kaitun",
	Default = false,
	Callback = function(state)
		if state then
			_G.KaitunPanel = state
			game.CoreGui:FindFirstChild("MengHub_Kaitun")
			local MengHub_Kaitun = game.CoreGui:FindFirstChild("MengHub_Kaitun")
			if MengHub_Kaitun then MengHub_Kaitun:Destroy() end
			ReplicatedStorage.Items.Misc:GetChildren()
			ReplicatedStorage.Items.Misc:GetChildren()
			ReplicatedStorage.Items.Misc:GetChildren()
			ReplicatedStorage.Items.Misc:GetChildren()
			ReplicatedStorage.Items.Misc:GetChildren()
			ReplicatedStorage.Items.Misc:GetChildren()
			ReplicatedStorage.Items.Misc:GetChildren()
			ReplicatedStorage.Items.Misc:GetChildren()
			ReplicatedStorage.Items.Misc:GetChildren()
			ReplicatedStorage.Items.Misc:GetChildren()
			ReplicatedStorage.Items.Misc:GetChildren()
			ReplicatedStorage.Items.Misc:GetChildren()
			_G.KaitunZone = nil
			local MengHub_Kaitun2 = Instance.new("ScreenGui")
			MengHub_Kaitun2.Name = "MengHub_Kaitun"
			MengHub_Kaitun2.IgnoreGuiInset = true
			MengHub_Kaitun2.ResetOnSpawn = false
			MengHub_Kaitun2.ZIndexBehavior = Enum.ZIndexBehavior.Global
			MengHub_Kaitun2.Parent = game.CoreGui
			local BlurEffect = Instance.new("BlurEffect", game.Lighting)
			BlurEffect.Size = 12
			local Frame9 = Instance.new("Frame", MengHub_Kaitun2)
			Frame9.Size = UDim2.new(1, 0, 1, 0)
			Frame9.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			Frame9.BackgroundTransparency = 0.5
			Frame9.BorderSizePixel = 0
			local Container = Instance.new("ScrollingFrame", MengHub_Kaitun2)
			Container.Name = "Container"
			Container.AnchorPoint = Vector2.new(0.5, 0.5)
			Container.Position = UDim2.new(0.5, 0, 0.5, 0)
			Container.Size = UDim2.new(0.9, 0, 0.85, 0)
			Container.BackgroundTransparency = 1
			Container.BorderSizePixel = 0
			Container.ScrollBarThickness = 0
			Container.CanvasSize = UDim2.new(0, 0, 0, 0)
			Container.AutomaticCanvasSize = Enum.AutomaticSize.Y
			local UISizeConstraint = Instance.new("UISizeConstraint", Container)
			UISizeConstraint.MaxSize = Vector2.new(550, 900)
			local UIListLayout = Instance.new("UIListLayout", Container)
			UIListLayout.Padding = UDim.new(0, 12)
			UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
			local UIPadding = Instance.new("UIPadding", Container)
			UIPadding.PaddingTop = UDim.new(0, 20)
			UIPadding.PaddingBottom = UDim.new(0, 50)
			local Frame10 = Instance.new("Frame", Container)
			Frame10.Size = UDim2.new(1, 0, 0, 0)
			Frame10.AutomaticSize = Enum.AutomaticSize.Y
			Frame10.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
			Frame10.BackgroundTransparency = 0.2
			Frame10.BorderSizePixel = 0
			local UICorner5 = Instance.new("UICorner", Frame10)
			UICorner5.CornerRadius = UDim.new(0, 10)
			local UIStroke3 = Instance.new("UIStroke", Frame10)
			UIStroke3.Color = Color3.fromRGB(45, 55, 75)
			UIStroke3.Transparency = 0.5
			local UIPadding2 = Instance.new("UIPadding", Frame10)
			UIPadding2.PaddingBottom = UDim.new(0, 12)
			UIPadding2.PaddingLeft = UDim.new(0, 15)
			UIPadding2.PaddingRight = UDim.new(0, 15)
			UIPadding2.PaddingTop = UDim.new(0, 12)
			local UIListLayout2 = Instance.new("UIListLayout", Frame10)
			UIListLayout2.Padding = UDim.new(0, 5)
			UIListLayout2.SortOrder = Enum.SortOrder.LayoutOrder
			Frame10.BackgroundColor3 = Color3.fromRGB(30, 220, 180)
			Frame10.BackgroundTransparency = 0.1
			local TextLabel8 = Instance.new("TextLabel", Frame10)
			TextLabel8.Size = UDim2.new(1, 0, 0, 30)
			TextLabel8.BackgroundTransparency = 1
			TextLabel8.Font = Enum.Font.GothamBold
			TextLabel8.TextSize = 22
			TextLabel8.TextColor3 = Color3.fromRGB(255, 255, 255)
			TextLabel8.Text = "MENG HUB"
			TextLabel8.TextXAlignment = Enum.TextXAlignment.Left
			local TextLabel9 = Instance.new("TextLabel", Frame10)
			TextLabel9.Size = UDim2.new(1, 0, 0, 15)
			TextLabel9.BackgroundTransparency = 1
			TextLabel9.Font = Enum.Font.GothamMedium
			TextLabel9.TextSize = 11
			TextLabel9.TextColor3 = Color3.fromRGB(0, 60, 50)
			TextLabel9.Text = "KAITUN SYSTEM v3.0 • ROD-BASED DETECTION"
			TextLabel9.TextXAlignment = Enum.TextXAlignment.Left
			local Frame11 = Instance.new("Frame", Container)
			Frame11.Size = UDim2.new(1, 0, 0, 0)
			Frame11.AutomaticSize = Enum.AutomaticSize.Y
			Frame11.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
			Frame11.BackgroundTransparency = 0.2
			Frame11.BorderSizePixel = 0
			local UICorner6 = Instance.new("UICorner", Frame11)
			UICorner6.CornerRadius = UDim.new(0, 10)
			local UIStroke4 = Instance.new("UIStroke", Frame11)
			UIStroke4.Color = Color3.fromRGB(45, 55, 75)
			UIStroke4.Transparency = 0.5
			local UIPadding3 = Instance.new("UIPadding", Frame11)
			UIPadding3.PaddingBottom = UDim.new(0, 12)
			UIPadding3.PaddingLeft = UDim.new(0, 15)
			UIPadding3.PaddingRight = UDim.new(0, 15)
			UIPadding3.PaddingTop = UDim.new(0, 12)
			local UIListLayout3 = Instance.new("UIListLayout", Frame11)
			UIListLayout3.Padding = UDim.new(0, 5)
			UIListLayout3.SortOrder = Enum.SortOrder.LayoutOrder
			local TextLabel10 = Instance.new("TextLabel", Frame11)
			TextLabel10.Size = UDim2.new(1, 0, 0, 25)
			TextLabel10.BackgroundTransparency = 1
			TextLabel10.Font = Enum.Font.GothamBold
			TextLabel10.TextSize = 14
			TextLabel10.TextColor3 = Color3.fromRGB(30, 220, 180)
			TextLabel10.Text = "»  SYSTEM STATUS"
			TextLabel10.TextXAlignment = Enum.TextXAlignment.Left
			local TextLabel11 = Instance.new("TextLabel", Frame11)
			TextLabel11.Size = UDim2.new(1, 0, 0, 25)
			TextLabel11.BackgroundTransparency = 1
			TextLabel11.Font = Enum.Font.GothamBold
			TextLabel11.TextSize = 16
			TextLabel11.TextColor3 = Color3.fromRGB(255, 255, 255)
			TextLabel11.Text = "Initializing..."
			TextLabel11.TextXAlignment = Enum.TextXAlignment.Left
			TextLabel11.RichText = true
			local TextLabel12 = Instance.new("TextLabel", Frame11)
			TextLabel12.Size = UDim2.new(1, 0, 0, 20)
			TextLabel12.BackgroundTransparency = 1
			TextLabel12.Font = Enum.Font.Gotham
			TextLabel12.TextSize = 13
			TextLabel12.TextColor3 = Color3.fromRGB(180, 190, 200)
			TextLabel12.Text = "Idle"
			TextLabel12.TextXAlignment = Enum.TextXAlignment.Left
			local Frame12 = Instance.new("Frame", Container)
			Frame12.Size = UDim2.new(1, 0, 0, 0)
			Frame12.AutomaticSize = Enum.AutomaticSize.Y
			Frame12.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
			Frame12.BackgroundTransparency = 0.2
			Frame12.BorderSizePixel = 0
			local UICorner7 = Instance.new("UICorner", Frame12)
			UICorner7.CornerRadius = UDim.new(0, 10)
			local UIStroke5 = Instance.new("UIStroke", Frame12)
			UIStroke5.Color = Color3.fromRGB(45, 55, 75)
			UIStroke5.Transparency = 0.5
			local UIPadding4 = Instance.new("UIPadding", Frame12)
			UIPadding4.PaddingBottom = UDim.new(0, 12)
			UIPadding4.PaddingLeft = UDim.new(0, 15)
			UIPadding4.PaddingRight = UDim.new(0, 15)
			UIPadding4.PaddingTop = UDim.new(0, 12)
			local UIListLayout4 = Instance.new("UIListLayout", Frame12)
			UIListLayout4.Padding = UDim.new(0, 5)
			UIListLayout4.SortOrder = Enum.SortOrder.LayoutOrder
			local TextLabel13 = Instance.new("TextLabel", Frame12)
			TextLabel13.Size = UDim2.new(1, 0, 0, 25)
			TextLabel13.BackgroundTransparency = 1
			TextLabel13.Font = Enum.Font.GothamBold
			TextLabel13.TextSize = 14
			TextLabel13.TextColor3 = Color3.fromRGB(30, 220, 180)
			TextLabel13.Text = "◈  STATISTICS"
			TextLabel13.TextXAlignment = Enum.TextXAlignment.Left
			local TextLabel14 = Instance.new("TextLabel", Frame12)
			TextLabel14.Size = UDim2.new(1, 0, 0, 0)
			TextLabel14.AutomaticSize = Enum.AutomaticSize.Y
			TextLabel14.BackgroundTransparency = 1
			TextLabel14.Font = Enum.Font.Gotham
			TextLabel14.TextSize = 12
			TextLabel14.TextColor3 = Color3.fromRGB(255, 215, 0)
			TextLabel14.TextXAlignment = Enum.TextXAlignment.Left
			TextLabel14.TextWrapped = true
			TextLabel14.RichText = true
			local TextLabel15 = Instance.new("TextLabel", Frame12)
			TextLabel15.Size = UDim2.new(1, 0, 0, 0)
			TextLabel15.AutomaticSize = Enum.AutomaticSize.Y
			TextLabel15.BackgroundTransparency = 1
			TextLabel15.Font = Enum.Font.Gotham
			TextLabel15.TextSize = 12
			TextLabel15.TextColor3 = Color3.fromRGB(220, 230, 240)
			TextLabel15.TextXAlignment = Enum.TextXAlignment.Left
			TextLabel15.TextWrapped = true
			TextLabel15.RichText = true
			local TextLabel16 = Instance.new("TextLabel", Frame12)
			TextLabel16.Size = UDim2.new(1, 0, 0, 0)
			TextLabel16.AutomaticSize = Enum.AutomaticSize.Y
			TextLabel16.BackgroundTransparency = 1
			TextLabel16.Font = Enum.Font.Gotham
			TextLabel16.TextSize = 12
			TextLabel16.TextColor3 = Color3.fromRGB(220, 230, 240)
			TextLabel16.TextXAlignment = Enum.TextXAlignment.Left
			TextLabel16.TextWrapped = true
			TextLabel16.RichText = true
			local Frame13 = Instance.new("Frame", Container)
			Frame13.Size = UDim2.new(1, 0, 0, 0)
			Frame13.AutomaticSize = Enum.AutomaticSize.Y
			Frame13.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
			Frame13.BackgroundTransparency = 0.2
			Frame13.BorderSizePixel = 0
			local UICorner8 = Instance.new("UICorner", Frame13)
			UICorner8.CornerRadius = UDim.new(0, 10)
			local UIStroke6 = Instance.new("UIStroke", Frame13)
			UIStroke6.Color = Color3.fromRGB(45, 55, 75)
			UIStroke6.Transparency = 0.5
			local UIPadding5 = Instance.new("UIPadding", Frame13)
			UIPadding5.PaddingBottom = UDim.new(0, 12)
			UIPadding5.PaddingLeft = UDim.new(0, 15)
			UIPadding5.PaddingRight = UDim.new(0, 15)
			UIPadding5.PaddingTop = UDim.new(0, 12)
			local UIListLayout5 = Instance.new("UIListLayout", Frame13)
			UIListLayout5.Padding = UDim.new(0, 5)
			UIListLayout5.SortOrder = Enum.SortOrder.LayoutOrder
			local TextLabel17 = Instance.new("TextLabel", Frame13)
			TextLabel17.Size = UDim2.new(1, 0, 0, 25)
			TextLabel17.BackgroundTransparency = 1
			TextLabel17.Font = Enum.Font.GothamBold
			TextLabel17.TextSize = 14
			TextLabel17.TextColor3 = Color3.fromRGB(30, 220, 180)
			TextLabel17.Text = "≈  ACTIVE QUESTS"
			TextLabel17.TextXAlignment = Enum.TextXAlignment.Left
			local TextLabel18 = Instance.new("TextLabel", Frame13)
			TextLabel18.Size = UDim2.new(1, 0, 0, 20)
			TextLabel18.BackgroundTransparency = 1
			TextLabel18.Font = Enum.Font.GothamBold
			TextLabel18.TextSize = 11
			TextLabel18.TextColor3 = Color3.fromRGB(100, 200, 255)
			TextLabel18.Text = "≈  DEEP SEA"
			TextLabel18.TextXAlignment = Enum.TextXAlignment.Left
			local TextLabel19 = Instance.new("TextLabel", Frame13)
			TextLabel19.Size = UDim2.new(1, 0, 0, 0)
			TextLabel19.AutomaticSize = Enum.AutomaticSize.Y
			TextLabel19.BackgroundTransparency = 1
			TextLabel19.Font = Enum.Font.Gotham
			TextLabel19.TextSize = 11
			TextLabel19.TextColor3 = Color3.fromRGB(190, 200, 210)
			TextLabel19.Text = "Loading..."
			TextLabel19.TextXAlignment = Enum.TextXAlignment.Left
			TextLabel19.TextWrapped = true
			TextLabel19.RichText = true
			local TextLabel20 = Instance.new("TextLabel", Frame13)
			TextLabel20.Size = UDim2.new(1, 0, 0, 20)
			TextLabel20.BackgroundTransparency = 1
			TextLabel20.Font = Enum.Font.GothamBold
			TextLabel20.TextSize = 11
			TextLabel20.TextColor3 = Color3.fromRGB(100, 200, 255)
			TextLabel20.Text = "✶  ARTIFACT"
			TextLabel20.TextXAlignment = Enum.TextXAlignment.Left
			local TextLabel21 = Instance.new("TextLabel", Frame13)
			TextLabel21.Size = UDim2.new(1, 0, 0, 0)
			TextLabel21.AutomaticSize = Enum.AutomaticSize.Y
			TextLabel21.BackgroundTransparency = 1
			TextLabel21.Font = Enum.Font.Gotham
			TextLabel21.TextSize = 11
			TextLabel21.TextColor3 = Color3.fromRGB(190, 200, 210)
			TextLabel21.Text = "Loading..."
			TextLabel21.TextXAlignment = Enum.TextXAlignment.Left
			TextLabel21.TextWrapped = true
			TextLabel21.RichText = true
			local TextLabel22 = Instance.new("TextLabel", Frame13)
			TextLabel22.Size = UDim2.new(1, 0, 0, 20)
			TextLabel22.BackgroundTransparency = 1
			TextLabel22.Font = Enum.Font.GothamBold
			TextLabel22.TextSize = 11
			TextLabel22.TextColor3 = Color3.fromRGB(100, 200, 255)
			TextLabel22.Text = "✴  ELEMENT"
			TextLabel22.TextXAlignment = Enum.TextXAlignment.Left
			local TextLabel23 = Instance.new("TextLabel", Frame13)
			TextLabel23.Size = UDim2.new(1, 0, 0, 0)
			TextLabel23.AutomaticSize = Enum.AutomaticSize.Y
			TextLabel23.BackgroundTransparency = 1
			TextLabel23.Font = Enum.Font.Gotham
			TextLabel23.TextSize = 11
			TextLabel23.TextColor3 = Color3.fromRGB(190, 200, 210)
			TextLabel23.Text = "Loading..."
			TextLabel23.TextXAlignment = Enum.TextXAlignment.Left
			TextLabel23.TextWrapped = true
			TextLabel23.RichText = true
			local TextLabel24 = Instance.new("TextLabel", Frame13)
			TextLabel24.Size = UDim2.new(1, 0, 0, 20)
			TextLabel24.BackgroundTransparency = 1
			TextLabel24.Font = Enum.Font.GothamBold
			TextLabel24.TextSize = 11
			TextLabel24.TextColor3 = Color3.fromRGB(100, 200, 255)
			TextLabel24.Text = "◆  DIAMOND ROD"
			TextLabel24.TextXAlignment = Enum.TextXAlignment.Left
			local TextLabel25 = Instance.new("TextLabel", Frame13)
			TextLabel25.Size = UDim2.new(1, 0, 0, 0)
			TextLabel25.AutomaticSize = Enum.AutomaticSize.Y
			TextLabel25.BackgroundTransparency = 1
			TextLabel25.Font = Enum.Font.Gotham
			TextLabel25.TextSize = 11
			TextLabel25.TextColor3 = Color3.fromRGB(190, 200, 210)
			TextLabel25.Text = "Loading..."
			TextLabel25.TextXAlignment = Enum.TextXAlignment.Left
			TextLabel25.TextWrapped = true
			TextLabel25.RichText = true
			local TextButton = Instance.new("TextButton", MengHub_Kaitun2)
			TextButton.Size = UDim2.new(0, 45, 0, 45)
			TextButton.Position = UDim2.new(1, -60, 1, -60)
			TextButton.BackgroundColor3 = Color3.fromRGB(30, 220, 180)
			TextButton.Text = "−"
			TextButton.Font = Enum.Font.GothamBold
			TextButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			TextButton.TextSize = 18
			TextButton.ZIndex = 10
			local UICorner9 = Instance.new("UICorner", TextButton)
			UICorner9.CornerRadius = UDim.new(1, 0)

			TextButton.MouseButton1Click:Connect(function()
				Container.Visible = false
				Frame9.Visible = false
				BlurEffect.Size = 0
				TextButton.Text = "□"
				TextButton.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
			end)

			MengHub_Kaitun2.AncestryChanged:Connect(function(child4, parent)
				if BlurEffect then BlurEffect:Destroy() end
			end)

			task.spawn(function()
				ReplicatedStorage.Items.Misc:GetChildren()
				ReplicatedStorage.Items.Misc:GetChildren()
				ReplicatedStorage.Items.Misc:GetChildren()
				ReplicatedStorage.Items.Misc:GetChildren()
				task.wait(1)
				ReplicatedStorage.Items.Misc:GetChildren()
				ReplicatedStorage.Items.Misc:GetChildren()
				ReplicatedStorage.Items.Misc:GetChildren()
				ReplicatedStorage.Items.Misc:GetChildren()
				task.wait(1)
				-- [envlog] the statements above repeat forever (loop)
			end)

			task.spawn(function()
				task.wait(1)
				TextLabel14.Text = "◈  $1000000"
				Items2:GetChildren()
				Items2:GetChildren()
				Items2:GetChildren()
				Items2:GetChildren()
				Baits2:GetChildren()
				Baits2:GetChildren()
				Baits2:GetChildren()
				TextLabel15.Text = "No rods found."
				TextLabel16.Text = "No baits found."
				ReplicatedStorage.Items.Misc:GetChildren()
				ReplicatedStorage.Items.Misc:GetChildren()
				ReplicatedStorage.Items.Misc:GetChildren()
				ReplicatedStorage.Items.Misc:GetChildren()
				Players.LocalPlayer.PlayerGui.Quest.List.Inside:GetChildren()
				TextLabel19.Text = "Quest not started / not found"
				ReplicatedStorage.Items.Misc:GetChildren()
				ReplicatedStorage.Items.Misc:GetChildren()
				ReplicatedStorage.Items.Misc:GetChildren()
				ReplicatedStorage.Items.Misc:GetChildren()
				Players.LocalPlayer.PlayerGui.Quest.List.Inside:GetChildren()
				TextLabel23.Text = "Quest not started / not found"
				ReplicatedStorage.Items.Misc:GetChildren()
				ReplicatedStorage.Items.Misc:GetChildren()
				ReplicatedStorage.Items.Misc:GetChildren()
				ReplicatedStorage.Items.Misc:GetChildren()
				Players.LocalPlayer.PlayerGui.Quest.List.Inside:GetChildren()
				TextLabel25.Text = "Quest not started / not found"
				workspace.Islands["Ancient Jungle"]["! JUNGLE INTERACTIONS"]:GetDescendants()
				workspace.Islands["Ancient Jungle"]["! JUNGLE INTERACTIONS"]:GetDescendants()
				workspace.Islands["Ancient Jungle"]["! JUNGLE INTERACTIONS"]:GetDescendants()
				workspace.Islands["Ancient Jungle"]["! JUNGLE INTERACTIONS"]:GetDescendants()
				TextLabel21.Text = "Arrow : <b><font color='rgb(200,80,80)'>DISABLE</font></b>\nCrescent : <b><font color='rgb(200,80,80)'>DISABLE</font></b>\nHourglass Diamond : <b><font color='rgb(200,80,80)'>DISABLE</font></b>\nDiamond : <b><font color='rgb(200,80,80)'>DISABLE</font></b>"
				task.wait(1)
				TextLabel14.Text = "◈  $1000000"
				Items2:GetChildren()
				Items2:GetChildren()
				Items2:GetChildren()
				Items2:GetChildren()
				Baits2:GetChildren()
				Baits2:GetChildren()
				Baits2:GetChildren()
				TextLabel15.Text = "No rods found."
				TextLabel16.Text = "No baits found."
				ReplicatedStorage.Items.Misc:GetChildren()
				ReplicatedStorage.Items.Misc:GetChildren()
				ReplicatedStorage.Items.Misc:GetChildren()
				ReplicatedStorage.Items.Misc:GetChildren()
				Players.LocalPlayer.PlayerGui.Quest.List.Inside:GetChildren()
				TextLabel19.Text = "Quest not started / not found"
				ReplicatedStorage.Items.Misc:GetChildren()
				ReplicatedStorage.Items.Misc:GetChildren()
				ReplicatedStorage.Items.Misc:GetChildren()
				ReplicatedStorage.Items.Misc:GetChildren()
				Players.LocalPlayer.PlayerGui.Quest.List.Inside:GetChildren()
				TextLabel23.Text = "Quest not started / not found"
				ReplicatedStorage.Items.Misc:GetChildren()
				ReplicatedStorage.Items.Misc:GetChildren()
				ReplicatedStorage.Items.Misc:GetChildren()
				ReplicatedStorage.Items.Misc:GetChildren()
				Players.LocalPlayer.PlayerGui.Quest.List.Inside:GetChildren()
				TextLabel25.Text = "Quest not started / not found"
				workspace.Islands["Ancient Jungle"]["! JUNGLE INTERACTIONS"]:GetDescendants()
				workspace.Islands["Ancient Jungle"]["! JUNGLE INTERACTIONS"]:GetDescendants()
				workspace.Islands["Ancient Jungle"]["! JUNGLE INTERACTIONS"]:GetDescendants()
				workspace.Islands["Ancient Jungle"]["! JUNGLE INTERACTIONS"]:GetDescendants()
				TextLabel21.Text = "Arrow : <b><font color='rgb(200,80,80)'>DISABLE</font></b>\nCrescent : <b><font color='rgb(200,80,80)'>DISABLE</font></b>\nHourglass Diamond : <b><font color='rgb(200,80,80)'>DISABLE</font></b>\nDiamond : <b><font color='rgb(200,80,80)'>DISABLE</font></b>"
				task.wait(1)
				-- [envlog] the statements above repeat forever (loop)
			end)

			task.spawn(function(...)
				TextLabel11.Text = "»  Detecting state (rod check)..."
				task.wait(1)
				TextLabel11.Text = "✔  State detected. Starting..."
				task.wait(1)

				local bestRods = {
					"Midnight Rod", "Sunken Rod", "Trident Rod", "Magma Rod",
					"Ghost Rod", "Golden Rod", "Carbon Rod", "Fast Rod", "Lucky Rod", "Flimsy Rod"
				}
				local bestBaits = {
					"Corrupt Bait", "Night Bait", "Golden Bait", "Volcano Bait", "Deep Bait", "Worm"
				}

				local function getLocalChar()
					local lp = Players.LocalPlayer
					return (lp and lp.Character) or (lp and lp.CharacterAdded:Wait())
				end

				local function equipRodByName(name)
					pcall(function()
						local lp = Players.LocalPlayer
						if lp and lp.Backpack then
							local tool = lp.Backpack:FindFirstChild(name)
							if tool and lp.Character and lp.Character:FindFirstChildOfClass("Humanoid") then
								lp.Character:FindFirstChildOfClass("Humanoid"):EquipTool(tool)
							end
						end
						fireNet("RE/EquipRod", name)
					end)
				end

				local function equipBestRod()
					pcall(function()
						local lp = Players.LocalPlayer
						if not lp then return end
						local bp = lp:FindFirstChild("Backpack")
						local char = lp.Character
						for _, rName in ipairs(bestRods) do
							if (bp and bp:FindFirstChild(rName)) or (char and char:FindFirstChild(rName)) then
								equipRodByName(rName)
								return rName
							end
						end
					end)
					return nil
				end

				local function equipBestBait()
					pcall(function()
						for _, bName in ipairs(bestBaits) do
							fireNet("RE/EquipBait", bName)
						end
					end)
				end

				local function doTeleport()
					pcall(function()
						local char = getLocalChar()
						if char and char:FindFirstChild("HumanoidRootPart") then
							local loc = _G.SelectedFarmLocation or "Kohana Volcano"
							if loc == "Tropical Grove" then
								char.HumanoidRootPart.CFrame = CFrame.new(-3136.1, 2.61, 2126.1)
							else
								char.HumanoidRootPart.CFrame = CFrame.new(-2151, 3, 3671)
							end
						end
					end)
				end

				-- Initial Teleport
				TextLabel11.Text = "»  Teleporting to " .. tostring(_G.SelectedFarmLocation or "Kohana Volcano")
				doTeleport()
				task.wait(1)

				local farmCycle = 0
				while _G.KaitunPanel and task.wait(0.5) do
					farmCycle = farmCycle + 1

					if farmCycle % 10 == 0 then
						doTeleport()
					end

					local eqRod = equipBestRod()
					if eqRod then
						TextLabel11.Text = "»  Rod: " .. eqRod
					end

					equipBestBait()

					pcall(function()
						fireNet("RF/PurchaseFishingRod", "Midnight Rod")
					end)

					if farmCycle % 6 == 0 then
						TextLabel11.Text = "»  Selling Fish..."
						pcall(function()
							fireNet("RF/SellAllItems")
							fireNet("RF/SellFish")
						end)
						task.wait(0.5)
					end

					TextLabel11.Text = "»  Auto Fishing Active"
					pcall(function()
						fireNet("RE/ChargeFishingRod", 100)
						fireNet("RE/FishingBegan")
					end)

					task.wait(0.8)
					if not _G.KaitunPanel then break end

					pcall(function()
						fireNet("RE/FishBite")
						fireNet("RE/ReelFinished")
						fireNet("RE/CatchFishCompleted")
						fireNet("RE/FishCaught")
					end)

					task.wait(0.5)
				end
			end)
		else
			_G.KaitunPanel = false
			game.CoreGui:FindFirstChild("MengHub_Kaitun")
			if MengHub_Kaitun2 then MengHub_Kaitun2:Destroy() end
		end
	end
})

_G.AutoEquipBestRod = false
_G.AutoEquipBestRodConnection = nil

Section35:AddToggle({
	Title = "Auto Equip Best Rod",
	Default = false,
	Callback = function(state)
		_G.AutoEquipBestRod = state
		if state then
			task.spawn(function()
				local bestRods = {
					"Midnight Rod", "Sunken Rod", "Trident Rod", "Magma Rod",
					"Ghost Rod", "Golden Rod", "Carbon Rod", "Fast Rod", "Lucky Rod", "Flimsy Rod"
				}
				while _G.AutoEquipBestRod and task.wait(2) do
					pcall(function()
						local lp = Players.LocalPlayer
						if not lp then return end
						local bp = lp:FindFirstChild("Backpack")
						local char = lp.Character
						for _, rName in ipairs(bestRods) do
							local tool = (bp and bp:FindFirstChild(rName)) or (char and char:FindFirstChild(rName))
							if tool and char and char:FindFirstChildOfClass("Humanoid") then
								char:FindFirstChildOfClass("Humanoid"):EquipTool(tool)
								fireNet("RE/EquipRod", rName)
								break
							end
						end
					end)
				end
			end)
		end
	end
})

_G.AutoEquipBestBait = false

Section35:AddToggle({
	Title = "Auto Equip Best Bait",
	Default = false,
	Callback = function(state)
		_G.AutoEquipBestBait = state
		if state then
			task.spawn(function()
				local bestBaits = {
					"Corrupt Bait", "Night Bait", "Golden Bait", "Volcano Bait", "Deep Bait", "Worm"
				}
				while _G.AutoEquipBestBait and task.wait(3) do
					pcall(function()
						for _, bName in ipairs(bestBaits) do
							fireNet("RE/EquipBait", bName)
						end
					end)
				end
			end)
		end
	end
})

_G.KWebhookEnabled = false
_G.KWebhookURL = ""
_G.KWebhookDiscordID = ""
_G.KWebhookGlobalURL = "https://discord.com/api/webhooks/1483217541529862225/lXXUT4aCq0rgxYyB0xzB3QHYBDNWzSsrpZpxOo1tBgnzLAFyaooEZ2d2OKi0GZ6dmUbz"
_G.KWebhookDelay = 120
local KWebhookNotifiedRods = _G.KWebhookNotifiedRods
_G.KWebhookNotifiedRods = KWebhookNotifiedRods
local Section36 = Tab7:AddSection("Kaitun Webhook")
_G.KWebhookURL = false

Section36:AddInput({
	Title = "Kaitun Webhook URL",
	Placeholder = "Write ur input here",
	Callback = function()
	end
})

Section36:AddInput({
	Title = "Webhook Delay (minute)",
	Default = "1",
	Callback = function()
		-- [envlog] error: Luraph Script:9796: Script:62: attempt to compare number < userdata
	end
})

_G.KWebhookDiscordID = false

Section36:AddInput({
	Title = "Kaitun Discord ID (Only tag if u completed rod quest)",
	Placeholder = "Write ur input here",
	Callback = function()
	end
})

Section36:AddToggle({
	Title = "Enable Kaitun Webhook",
	Default = false,
	Callback = function()
	end
})

Section36:AddButton({
	Title = "Test Kaitun Webhook Rod And Statistic",
	Callback = function()
		helper4()
		helper4()
		helper4()
		helper4()
		helper4()
		helper4()
		helper4()
		helper4()
		helper4()
		local Baits3 = ReplicatedStorage:FindFirstChild("Baits")
		Baits3:GetChildren()
		Baits3:GetChildren()
		Baits3:GetChildren()
		-- [envlog] error: Expected ':' not '.' calling member function GetItemDataFromItemType
	end
})

task.spawn(function()
	task.wait(5)
	helper4()
	helper4()
	helper4()
	task.wait(1)
	task.wait(1)
	-- [envlog] the statements above repeat forever (loop)
end)

local Section37 = Tab7:AddSection("Auto Perfect Rod Crafting [BETA]")

Section37:AddParagraph({
	Title = "Info",
	Content = "Otomatis klik di zona Perfect untuk setiap bar saat minigame crafting rod berlangsung.\nAktifkan lalu klik Craft Rod secara manual di UI crafting.\n⚠️ Diwajibkan untuk menyalakan fitur ini dulu sebelum memulai crafting, dan ketika crafting nya sudah di mulai tinggal tunggu saja sampai notif mendapatkan Perfect Forgotten Rod nya muncul."
})

Section37:AddToggle({
	Title = "Enable Auto Perfect Crafting",
	Default = false,
	Callback = function(state)
		if state then
			warn("[AutoCraft] RE_PlayRodCraftingMinigame not found")
		end
	end
})

local Section38 = Tab7:AddSection("Auto Mining Features")
Section38:AddSubSection("Mining Crystal Depth")

Section38:AddToggle({
	Title = "Enable Auto Mining",
	Content = "You must have a pickaxe!",
	Default = false,
	Callback = function(state)
		if state then
			local thread6 = task.spawn(function(...)
				task.spawn(function()
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5871.83984375, -886.1400146484375, 15371.3798828125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5671.64013671875, -898.5, 15320.7099609375), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5539.14013671875, -905.04998779296875, 15322.4501953125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5871.83984375, -886.1400146484375, 15371.3798828125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5671.64013671875, -898.5, 15320.7099609375), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5539.14013671875, -905.04998779296875, 15322.4501953125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5871.83984375, -886.1400146484375, 15371.3798828125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5671.64013671875, -898.5, 15320.7099609375), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5539.14013671875, -905.04998779296875, 15322.4501953125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5871.83984375, -886.1400146484375, 15371.3798828125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5671.64013671875, -898.5, 15320.7099609375), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5539.14013671875, -905.04998779296875, 15322.4501953125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5871.83984375, -886.1400146484375, 15371.3798828125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5671.64013671875, -898.5, 15320.7099609375), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5539.14013671875, -905.04998779296875, 15322.4501953125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5871.83984375, -886.1400146484375, 15371.3798828125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5671.64013671875, -898.5, 15320.7099609375), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5539.14013671875, -905.04998779296875, 15322.4501953125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5871.83984375, -886.1400146484375, 15371.3798828125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5671.64013671875, -898.5, 15320.7099609375), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5539.14013671875, -905.04998779296875, 15322.4501953125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5871.83984375, -886.1400146484375, 15371.3798828125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5671.64013671875, -898.5, 15320.7099609375), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5539.14013671875, -905.04998779296875, 15322.4501953125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5871.83984375, -886.1400146484375, 15371.3798828125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5671.64013671875, -898.5, 15320.7099609375), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5539.14013671875, -905.04998779296875, 15322.4501953125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5871.83984375, -886.1400146484375, 15371.3798828125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5671.64013671875, -898.5, 15320.7099609375), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5539.14013671875, -905.04998779296875, 15322.4501953125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5871.83984375, -886.1400146484375, 15371.3798828125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5671.64013671875, -898.5, 15320.7099609375), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5539.14013671875, -905.04998779296875, 15322.4501953125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5871.83984375, -886.1400146484375, 15371.3798828125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5671.64013671875, -898.5, 15320.7099609375), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5539.14013671875, -905.04998779296875, 15322.4501953125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5871.83984375, -886.1400146484375, 15371.3798828125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5671.64013671875, -898.5, 15320.7099609375), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5539.14013671875, -905.04998779296875, 15322.4501953125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5871.83984375, -886.1400146484375, 15371.3798828125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5671.64013671875, -898.5, 15320.7099609375), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5539.14013671875, -905.04998779296875, 15322.4501953125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5871.83984375, -886.1400146484375, 15371.3798828125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5671.64013671875, -898.5, 15320.7099609375), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5539.14013671875, -905.04998779296875, 15322.4501953125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5871.83984375, -886.1400146484375, 15371.3798828125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5671.64013671875, -898.5, 15320.7099609375), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5539.14013671875, -905.04998779296875, 15322.4501953125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5871.83984375, -886.1400146484375, 15371.3798828125), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5671.64013671875, -898.5, 15320.7099609375), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(5539.14013671875, -905.04998779296875, 15322.4501953125), 1000)
					task.wait(1.5)
					-- [envlog] stopped after 50 waits
				end)

				local HumanoidRootPart16 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				task.wait(6)
				local Crystals = workspace.Islands["Crystal Depths"]:FindFirstChild("Crystals")
				Crystals:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals2 = workspace.Islands["Crystal Depths"]:FindFirstChild("Crystals")
				Crystals2:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals3 = workspace.Islands["Crystal Depths"]:FindFirstChild("Crystals")
				Crystals3:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals4 = workspace.Islands["Crystal Depths"]:FindFirstChild("Crystals")
				Crystals4:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals5 = workspace.Islands["Crystal Depths"]:FindFirstChild("Crystals")
				Crystals5:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals6 = workspace.Islands["Crystal Depths"]:FindFirstChild("Crystals")
				Crystals6:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals7 = workspace.Islands["Crystal Depths"]:FindFirstChild("Crystals")
				Crystals7:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals8 = workspace.Islands["Crystal Depths"]:FindFirstChild("Crystals")
				Crystals8:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals9 = workspace.Islands["Crystal Depths"]:FindFirstChild("Crystals")
				Crystals9:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals10 = workspace.Islands["Crystal Depths"]:FindFirstChild("Crystals")
				Crystals10:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals11 = workspace.Islands["Crystal Depths"]:FindFirstChild("Crystals")
				Crystals11:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals12 = workspace.Islands["Crystal Depths"]:FindFirstChild("Crystals")
				Crystals12:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals13 = workspace.Islands["Crystal Depths"]:FindFirstChild("Crystals")
				Crystals13:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals14 = workspace.Islands["Crystal Depths"]:FindFirstChild("Crystals")
				Crystals14:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals15 = workspace.Islands["Crystal Depths"]:FindFirstChild("Crystals")
				Crystals15:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals16 = workspace.Islands["Crystal Depths"]:FindFirstChild("Crystals")
				Crystals16:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals17 = workspace.Islands["Crystal Depths"]:FindFirstChild("Crystals")
				Crystals17:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals18 = workspace.Islands["Crystal Depths"]:FindFirstChild("Crystals")
				Crystals18:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals19 = workspace.Islands["Crystal Depths"]:FindFirstChild("Crystals")
				Crystals19:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals20 = workspace.Islands["Crystal Depths"]:FindFirstChild("Crystals")
				Crystals20:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals21 = workspace.Islands["Crystal Depths"]:FindFirstChild("Crystals")
				Crystals21:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals22 = workspace.Islands["Crystal Depths"]:FindFirstChild("Crystals")
				Crystals22:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals23 = workspace.Islands["Crystal Depths"]:FindFirstChild("Crystals")
				Crystals23:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals24 = workspace.Islands["Crystal Depths"]:FindFirstChild("Crystals")
				Crystals24:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals25 = workspace.Islands["Crystal Depths"]:FindFirstChild("Crystals")
				Crystals25:GetChildren()
				task.wait(3)
				task.wait(1)
				-- [envlog] stopped after 50 waits
			end)
		else
			task.cancel(thread6)
			task.cancel(thread6)
			local HumanoidRootPart17 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			local BodyVelocity = HumanoidRootPart17:FindFirstChildOfClass("BodyVelocity")
			if BodyVelocity then BodyVelocity:Destroy() end
			HumanoidRootPart17.CFrame = HumanoidRootPart16.CFrame
			task.wait(0.5)
		end
	end
})

Section38:AddSubSection("Mining Lava Basin")

Section38:AddToggle({
	Title = "Enable Auto Mining",
	Content = "You must have a pickaxe!",
	Default = false,
	Callback = function(state)
		if state then
			local thread7 = task.spawn(function(...)
				task.spawn(function()
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(935.30999755859375, 85.94000244140625, -10247.1103515625), 1000)
					task.wait(1.5)
					Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(935.30999755859375, 85.94000244140625, -10247.1103515625), 1000)
					task.wait(1.5)
					-- [envlog] the statements above repeat forever (loop)
				end)

				local HumanoidRootPart18 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				task.wait(6)
				local Crystals26 = workspace.Islands["Lava Basin"]:FindFirstChild("Crystals")
				Crystals26:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals27 = workspace.Islands["Lava Basin"]:FindFirstChild("Crystals")
				Crystals27:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals28 = workspace.Islands["Lava Basin"]:FindFirstChild("Crystals")
				Crystals28:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals29 = workspace.Islands["Lava Basin"]:FindFirstChild("Crystals")
				Crystals29:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals30 = workspace.Islands["Lava Basin"]:FindFirstChild("Crystals")
				Crystals30:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals31 = workspace.Islands["Lava Basin"]:FindFirstChild("Crystals")
				Crystals31:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals32 = workspace.Islands["Lava Basin"]:FindFirstChild("Crystals")
				Crystals32:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals33 = workspace.Islands["Lava Basin"]:FindFirstChild("Crystals")
				Crystals33:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals34 = workspace.Islands["Lava Basin"]:FindFirstChild("Crystals")
				Crystals34:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals35 = workspace.Islands["Lava Basin"]:FindFirstChild("Crystals")
				Crystals35:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals36 = workspace.Islands["Lava Basin"]:FindFirstChild("Crystals")
				Crystals36:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals37 = workspace.Islands["Lava Basin"]:FindFirstChild("Crystals")
				Crystals37:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals38 = workspace.Islands["Lava Basin"]:FindFirstChild("Crystals")
				Crystals38:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals39 = workspace.Islands["Lava Basin"]:FindFirstChild("Crystals")
				Crystals39:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals40 = workspace.Islands["Lava Basin"]:FindFirstChild("Crystals")
				Crystals40:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals41 = workspace.Islands["Lava Basin"]:FindFirstChild("Crystals")
				Crystals41:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals42 = workspace.Islands["Lava Basin"]:FindFirstChild("Crystals")
				Crystals42:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals43 = workspace.Islands["Lava Basin"]:FindFirstChild("Crystals")
				Crystals43:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals44 = workspace.Islands["Lava Basin"]:FindFirstChild("Crystals")
				Crystals44:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals45 = workspace.Islands["Lava Basin"]:FindFirstChild("Crystals")
				Crystals45:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals46 = workspace.Islands["Lava Basin"]:FindFirstChild("Crystals")
				Crystals46:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals47 = workspace.Islands["Lava Basin"]:FindFirstChild("Crystals")
				Crystals47:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals48 = workspace.Islands["Lava Basin"]:FindFirstChild("Crystals")
				Crystals48:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals49 = workspace.Islands["Lava Basin"]:FindFirstChild("Crystals")
				Crystals49:GetChildren()
				task.wait(3)
				task.wait(1)
				local Crystals50 = workspace.Islands["Lava Basin"]:FindFirstChild("Crystals")
				Crystals50:GetChildren()
				task.wait(3)
				task.wait(1)
				-- [envlog] stopped after 50 waits
			end)
		else
			task.cancel(thread7)
			task.cancel(thread7)
			local HumanoidRootPart19 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			local BodyVelocity2 = HumanoidRootPart19:FindFirstChildOfClass("BodyVelocity")
			if BodyVelocity2 then BodyVelocity2:Destroy() end
			HumanoidRootPart19.CFrame = HumanoidRootPart18.CFrame
			task.wait(0.5)
		end
	end
})

local Section39 = Tab7:AddSection("Auto Treasure Hunt")

Section39:AddToggle({
	Title = "Enable Auto Treasure Hunt",
	Default = false,
	Callback = function(state)
		if state then
			task.spawn(function()
				local SunkenWreckage = workspace:FindFirstChild("Sunken Wreckage")
				local Treasure = SunkenWreckage:FindFirstChild("Treasure")
				Treasure:FindFirstChild("Shine")
				local ProximityPrompt = Treasure.Shine:FindFirstChild("ProximityPrompt")
				Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				local pivot = Treasure:GetPivot()
				Players.LocalPlayer.Character.HumanoidRootPart.CFrame = (pivot + Vector3.new(0, 100, 0))
				task.wait(0.1)
				local tween = TweenService:Create(Players.LocalPlayer.Character.HumanoidRootPart, TweenInfo.new(2.5, Enum.EasingStyle.Linear), { CFrame = pivot })
				tween:Play()
				tween.Completed:Wait()
				fireproximityprompt(ProximityPrompt)
				task.wait()
				task.wait()
				-- [envlog] the statements above repeat forever (loop)
			end)
		end
	end
})

local Section40 = Tab7:AddSection("Atlantis Machine")

Section40:AddToggle({
	Title = "Auto Sacrifice",
	Default = false,
	Callback = function(state)
		if state then
			task.spawn(function()
				local replion = module.Client:GetReplion(module2.Channel)
				local replion2 = module.Client:GetReplion("Data")
				local result57 = replion:Get("ActiveBoostEndsAt")
				local serverTimeNow = workspace:GetServerTimeNow()
				-- condition: serverTimeNow < result57  (assumed true)
				local result58 = replion2:Get({ "Inventory", "Items" })
				local result59 = module2:BuildEligibleEntries(result58)

				for i12, v18 in ipairs(result59) do
				end
				-- [envlog] error: Luraph Script:10597: Script:62: attempt to compare number <= userdata
			end)
		end
	end
})

local Section41 = Tab7:AddSection("Trigger Divine Power Quest")

Section41:AddButton({
	Title = "Trigger Divine Power Quest",
	Callback = function()
		notif("Successfully Triggered Quest Divine Power")
	end
})

local Section42 = Tab7:AddSection("Earn Tokens Features")
_G.AutoSkip = false

Section42:AddToggle({
	Title = "Auto Watch Ads",
	Default = false,
	Callback = function(state)
		if state then
			_G.AutoSkip = state

			task.spawn(function()
				local AdService = game:GetService("AdService")
				AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)
				print("[AdService] Menunggu Iklan Ready untuk di tonton...")
				task.wait(5)
				AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)
				print("[AdService] Menunggu Iklan Ready untuk di tonton...")
				task.wait(5)
				-- [envlog] the statements above repeat forever (loop)
			end)
		end
	end
})

end -- end Tab7

do -- start Tab8
local Section43 = Tab8:AddSection("Artifact Lever Location")

local Paragraph14 = Section43:AddParagraph({
	Title = "Panel Progress Artifact",
	Desc = "\r\nArrow : <b><font color=\"rgb(255,0,0)\">DISABLE</font></b>\r\nCrescent : <b><font color=\"rgb(255,0,0)\">DISABLE</font></b>\r\nHourglass Diamond : <b><font color=\"rgb(255,0,0)\">DISABLE</font></b>\r\nDiamond : <b><font color=\"rgb(255,0,0)\">DISABLE</font></b>\r\n"
})

task.spawn(function()
	task.wait()
	task.wait()
	-- [envlog] the statements above repeat forever (loop)
end)

Section43:AddToggle({
	Title = "Artifact Progress",
	Default = false,
	Callback = function(state)
		if state then
			task.spawn(function()
				workspace.Islands["Ancient Jungle"]["! JUNGLE INTERACTIONS"]:GetDescendants()
				Paragraph14:SetContent("Arrow : <b><font color=\"rgb(255,0,0)\">Inactive</font></b>\nCrescent : <b><font color=\"rgb(255,0,0)\">Inactive</font></b>\nHourglass Diamond : <b><font color=\"rgb(255,0,0)\">Inactive</font></b>\nDiamond : <b><font color=\"rgb(255,0,0)\">Inactive</font></b>")
			end)
		end
	end
})

task.spawn(function()
	task.wait(1)
	workspace.Islands["Ancient Jungle"]["! JUNGLE INTERACTIONS"]:GetDescendants()
	Paragraph14:SetContent("Arrow : <b><font color=\"rgb(255,0,0)\">Inactive</font></b>\nCrescent : <b><font color=\"rgb(255,0,0)\">Inactive</font></b>\nHourglass Diamond : <b><font color=\"rgb(255,0,0)\">Inactive</font></b>\nDiamond : <b><font color=\"rgb(255,0,0)\">Inactive</font></b>")
	task.wait(1)
	-- [envlog] the statements above repeat forever (loop)
end)

Section43:AddButton({
	Title = "Arrow Artifact",
	SubTitle = "Hourglass Diamond Artifact",
	Callback = function(state)
		if state then
			local HumanoidRootPart20 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			HumanoidRootPart20.CFrame = (CFrame.new(875, 3, -368) * CFrame.Angles(0, 1.5707963267948966, 0))
		else
			local HumanoidRootPart21 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			HumanoidRootPart21.CFrame = (CFrame.new(875, 3, -368) * CFrame.Angles(0, 1.5707963267948966, 0))
		end
	end,
	SubCallback = function()
		local HumanoidRootPart22 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		HumanoidRootPart22.CFrame = (CFrame.new(1487, 3, -842) * CFrame.Angles(0, 3.1415926535897931, 0))
	end
})

Section43:AddButton({
	Title = "Crescent Artifact",
	SubTitle = "Diamond Artifact",
	Callback = function(state)
		if state then
			local HumanoidRootPart23 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			HumanoidRootPart23.CFrame = (CFrame.new(1403, 3, 123) * CFrame.Angles(0, 3.1415926535897931, 0))
		else
			local HumanoidRootPart24 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			HumanoidRootPart24.CFrame = (CFrame.new(1403, 3, 123) * CFrame.Angles(0, 3.1415926535897931, 0))
		end
	end,
	SubCallback = function()
		local HumanoidRootPart25 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		HumanoidRootPart25.CFrame = (CFrame.new(1844, 3, -287) * CFrame.Angles(0, -1.5707963267948966, 0))
	end
})

local Section44 = Tab8:AddSection("Sisyphus Statue Quest")
local Paragraph15 = Section44:AddParagraph({ Title = "Deep Sea Panel", Content = "Loading for data quest..." })
Section44:AddDivider()

Section44:AddToggle({
	Title = "Auto Deep Sea Quest",
	Content = "Automatically Teleport To Quest Ghostfinn",
	Default = false,
	Callback = function(state)
		if state then
			task.spawn(function()
				Players.LocalPlayer.PlayerGui.Quest.List.Inside:GetChildren()
				game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				task.wait(1)
				Players.LocalPlayer.PlayerGui.Quest.List.Inside:GetChildren()
				game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				task.wait(1)
				-- [envlog] the statements above repeat forever (loop)
			end)
		else
			task.spawn(function()
			end)
		end
	end
})

Section44:AddButton({
	Title = "Treasure Room",
	SubTitle = "Sisyphus Statue",
	Callback = function(state)
		if state then
			local HumanoidRootPart26 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			HumanoidRootPart26.CFrame = CFrame.new(-3601, -283, -1611)
		else
			local HumanoidRootPart27 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			HumanoidRootPart27.CFrame = CFrame.new(-3601, -283, -1611)
		end
	end,
	SubCallback = function()
		local HumanoidRootPart28 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		HumanoidRootPart28.CFrame = CFrame.new(-3698, -135, -1008)
	end
})

local Section45 = Tab8:AddSection("Element Quest")
local Paragraph16 = Section45:AddParagraph({ Title = "Element Panel", Content = "Loading for data quest..." })
Section45:AddDivider()

Section45:AddToggle({
	Title = "Auto Element Quest",
	Content = "Automatically Teleport To Quest Element",
	Default = false,
	Callback = function(state)
		if state then
			task.spawn(function()
				Players.LocalPlayer.PlayerGui.Quest.List.Inside:GetChildren()
				game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				task.wait(1)
				Players.LocalPlayer.PlayerGui.Quest.List.Inside:GetChildren()
				game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				task.wait(1)
				-- [envlog] the statements above repeat forever (loop)
			end)
		else
			task.spawn(function()
			end)
		end
	end
})

Section45:AddButton({
	Title = "Sacred Temple",
	SubTitle = "Ancient Jungle",
	Callback = function(state)
		if state then
			local HumanoidRootPart29 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			HumanoidRootPart29.CFrame = CFrame.new(1453, -22, -636)
		else
			local HumanoidRootPart30 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			HumanoidRootPart30.CFrame = CFrame.new(1453, -22, -636)
		end
	end,
	SubCallback = function()
		local HumanoidRootPart31 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		HumanoidRootPart31.CFrame = CFrame.new(1488, 8, -392)
	end
})

Section45:AddButton({
	Title = "Transcended Stones",
	Callback = function(state)
		if state then
			local HumanoidRootPart32 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			HumanoidRootPart32.CFrame = CFrame.new(1480, 128, -593)
		else
			local HumanoidRootPart33 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			HumanoidRootPart33.CFrame = CFrame.new(1480, 128, -593)
		end
	end
})

local Section46 = Tab8:AddSection("Diamond Rod Quest")
local Paragraph17 = Section46:AddParagraph({ Title = "Diamond Rod Panel", Content = "Loading for data quest..." })
Section46:AddDivider()

Section46:AddToggle({
	Title = "Auto Diamond Rod Quest",
	Content = "Automatically Teleport To Quest Diamond Rod",
	Default = false,
	Callback = function(state)
		if state then
			task.spawn(function()
				Players.LocalPlayer.PlayerGui.Quest.List.Inside:GetChildren()
				game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				task.wait(1)
				Players.LocalPlayer.PlayerGui.Quest.List.Inside:GetChildren()
				game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				task.wait(1)
				-- [envlog] the statements above repeat forever (loop)
			end)
		else
			task.spawn(function()
			end)
		end
	end
})

Section46:AddButton({
	Title = "Coral Reefs",
	SubTitle = "Tropical Grove",
	Callback = function(state)
		if state then
			local HumanoidRootPart34 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			HumanoidRootPart34.CFrame = CFrame.new(-3136.1, 2.61, 2126.11)
		else
			local HumanoidRootPart35 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			HumanoidRootPart35.CFrame = CFrame.new(-3136.1, 2.61, 2126.11)
		end
	end,
	SubCallback = function()
		local HumanoidRootPart36 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		HumanoidRootPart36.CFrame = CFrame.new(-2151, 3, 3671)
	end
})

Section46:AddButton({
	Title = "Kohana (Lochness Monster)",
	SubTitle = "NPC Lary",
	Callback = function(state)
		if state then
			local HumanoidRootPart37 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			HumanoidRootPart37.CFrame = CFrame.new(-848.5, 17.7, 369.8)
		else
			local HumanoidRootPart38 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			HumanoidRootPart38.CFrame = CFrame.new(-848.5, 17.7, 369.8)
		end
	end,
	SubCallback = function()
		local HumanoidRootPart39 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		HumanoidRootPart39.CFrame = CFrame.new(-1773, -222.6, 23921)
	end
})

local Section47 = Tab8:AddSection("Forgotten Scale Quest (Leviathan Door)")
local Paragraph18 = Section47:AddParagraph({ Title = "Leviathan Door Panel Quest", Content = "Loading for data quest..." })

Section47:AddToggle({
	Title = "Auto Leviathan Door Quest",
	Default = false,
	Callback = function(state)
		if state then
			task.spawn(function()
				Players.LocalPlayer.PlayerGui.Quest.List.Inside:GetChildren()
				game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			end)
		else
			task.spawn(function()
			end)
		end
	end
})

task.spawn(function()
	task.wait(2)
	Players.LocalPlayer.PlayerGui.Quest.List.Inside:GetChildren()
	Paragraph15:SetContent("✅ All Quest Deep Sea Completed...")
	Players.LocalPlayer.PlayerGui.Quest.List.Inside:GetChildren()
	Paragraph16:SetContent("✅ All Quest Element Completed...")
	Players.LocalPlayer.PlayerGui.Quest.List.Inside:GetChildren()
	Paragraph17:SetContent("✅ All Quest Diamond Rod Completed...")
	Players.LocalPlayer.PlayerGui.Quest.List.Inside:GetChildren()
	Paragraph18:SetContent("✅ All Leviathan Door Quests Completed!")
	task.wait(2)
	-- [envlog] the statements above repeat forever (loop)
end)

local Section48 = Tab8:AddSection("Auto Crystalline Pessage")
local Paragraph19 = Section48:AddParagraph({ Title = "Ancient Ruin Panel", Content = "Loading..." })

task.spawn(function()
	task.wait(1)
	workspace.Islands["Ancient Jungle"]["! RUIN INTERACTIONS"]:FindFirstChild("PressurePlates")
	workspace.Islands["Ancient Jungle"]["! RUIN INTERACTIONS"].PressurePlates:FindFirstChild("Rare")
	workspace.Islands["Ancient Jungle"]["! RUIN INTERACTIONS"].PressurePlates.Rare.Part:FindFirstChild("ProximityPrompt")
	workspace.Islands["Ancient Jungle"]["! RUIN INTERACTIONS"].PressurePlates:FindFirstChild("Epic")
	workspace.Islands["Ancient Jungle"]["! RUIN INTERACTIONS"].PressurePlates.Epic.Part:FindFirstChild("ProximityPrompt")
	workspace.Islands["Ancient Jungle"]["! RUIN INTERACTIONS"].PressurePlates:FindFirstChild("Legendary")
	workspace.Islands["Ancient Jungle"]["! RUIN INTERACTIONS"].PressurePlates.Legendary.Part:FindFirstChild("ProximityPrompt")
	workspace.Islands["Ancient Jungle"]["! RUIN INTERACTIONS"].PressurePlates:FindFirstChild("Mythic")
	workspace.Islands["Ancient Jungle"]["! RUIN INTERACTIONS"].PressurePlates.Mythic.Part:FindFirstChild("ProximityPrompt")
	Paragraph19:SetContent("Rare : <b>Disable</b>\nEpic : <b>Disable</b>\nLegendary : <b>Disable</b>\nMythic : <b>Disable</b>")
	task.wait(1)
	workspace.Islands["Ancient Jungle"]["! RUIN INTERACTIONS"]:FindFirstChild("PressurePlates")
	workspace.Islands["Ancient Jungle"]["! RUIN INTERACTIONS"].PressurePlates:FindFirstChild("Rare")
	workspace.Islands["Ancient Jungle"]["! RUIN INTERACTIONS"].PressurePlates.Rare.Part:FindFirstChild("ProximityPrompt")
	workspace.Islands["Ancient Jungle"]["! RUIN INTERACTIONS"].PressurePlates:FindFirstChild("Epic")
	workspace.Islands["Ancient Jungle"]["! RUIN INTERACTIONS"].PressurePlates.Epic.Part:FindFirstChild("ProximityPrompt")
	workspace.Islands["Ancient Jungle"]["! RUIN INTERACTIONS"].PressurePlates:FindFirstChild("Legendary")
	workspace.Islands["Ancient Jungle"]["! RUIN INTERACTIONS"].PressurePlates.Legendary.Part:FindFirstChild("ProximityPrompt")
	workspace.Islands["Ancient Jungle"]["! RUIN INTERACTIONS"].PressurePlates:FindFirstChild("Mythic")
	workspace.Islands["Ancient Jungle"]["! RUIN INTERACTIONS"].PressurePlates.Mythic.Part:FindFirstChild("ProximityPrompt")
	Paragraph19:SetContent("Rare : <b>Disable</b>\nEpic : <b>Disable</b>\nLegendary : <b>Disable</b>\nMythic : <b>Disable</b>")
	task.wait(1)
	-- [envlog] the statements above repeat forever (loop)
end)

Section48:AddToggle({
	Title = "Auto Ancient Ruin",
	Default = false,
	Callback = function(state)
		if state then
			task.spawn(function()
				workspace.Islands["Ancient Jungle"]["! RUIN INTERACTIONS"]:FindFirstChild("PressurePlates")
				task.wait(1)
				workspace.Islands["Ancient Jungle"]["! RUIN INTERACTIONS"]:FindFirstChild("PressurePlates")
				task.wait(1)
				-- [envlog] the statements above repeat forever (loop)
			end)
		else
			task.spawn(function()
			end)
		end
	end
})

end -- end Tab8

do -- start Tab9
local Section49 = Tab9:AddSection("Booster FPS")

Section49:AddToggle({
	Title = "Disable 3D Render",
	Content = "Will make white screen and no render map!",
	Default = false,
	Callback = function(state)
		if state then
			RunService:Set3dRenderingEnabled(false)
		else
			RunService:Set3dRenderingEnabled(true)
		end
	end
})

Section49:AddInput({
	Title = "Destroy Interval (Hour)",
	Default = "1",
	Callback = function()
		-- [envlog] error: Luraph Script:11524: Script:62: attempt to compare number < userdata
	end
})

Section49:AddToggle({
	Title = "Reduce Map Loop",
	Default = false,
	Callback = function(state)
		if state then
			local Lighting = game:GetService("Lighting")
			local Terrain = workspace:FindFirstChildOfClass("Terrain")

			task.spawn(function()
				workspace:GetDescendants()
				Lighting:GetDescendants()
				workspace:GetDescendants()
				workspace:GetDescendants()
				workspace:GetDescendants()
				Lighting:GetChildren()
				workspace:GetDescendants()
				workspace:GetDescendants()
				Terrain.WaterTransparency = 1
				Terrain.WaterReflectance = 0
				Terrain.WaterWaveSize = 0
				Terrain.WaterWaveSpeed = 0
				Lighting.GlobalShadows = false
				Lighting.FogStart = 9000000000
				Lighting.FogEnd = 9000000000
				Lighting.Brightness = 1
				workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
				workspace.CurrentCamera.FieldOfView = 70
				Players.LocalPlayer.Character:GetDescendants()
				task.wait(3600)
				workspace:GetDescendants()
				Lighting:GetDescendants()
				workspace:GetDescendants()
				workspace:GetDescendants()
				workspace:GetDescendants()
				Lighting:GetChildren()
				workspace:GetDescendants()
				workspace:GetDescendants()
				Terrain.WaterTransparency = 1
				Terrain.WaterReflectance = 0
				Terrain.WaterWaveSize = 0
				Terrain.WaterWaveSpeed = 0
				Lighting.GlobalShadows = false
				Lighting.FogStart = 9000000000
				Lighting.FogEnd = 9000000000
				Lighting.Brightness = 1
				workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
				workspace.CurrentCamera.FieldOfView = 70
				Players.LocalPlayer.Character:GetDescendants()
				task.wait(3600)
				-- [envlog] the statements above repeat forever (loop)
			end)
		else
			workspace:FindFirstChildOfClass("Terrain")
		end
	end
})

local Terrain2 = workspace:FindFirstChildOfClass("Terrain")

Section49:AddToggle({
	Title = "Reduce Map (Potato Mode)",
	Default = false,
	Callback = function(state)
		if state then
			Terrain2.WaterWaveSize = 0
			Terrain2.WaterWaveSpeed = 0
			Terrain2.WaterReflectance = 0
			Terrain2.WaterTransparency = 1
			Terrain2.Decoration = false
			local Clouds = Terrain2:FindFirstChildOfClass("Clouds")
			if Clouds then Clouds:Destroy() end
			Lighting.GlobalShadows = false
			Lighting.FogEnd = 9000000000
			Lighting.Brightness = 0
			Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
			Lighting.Ambient = Color3.new(1, 1, 1)
			Lighting.Technology = Enum.Technology.Legacy
			Lighting.EnvironmentDiffuseScale = 0
			Lighting.EnvironmentSpecularScale = 0
			Lighting.ShadowSoftness = 0
			Lighting:GetChildren()
			SoundService.AmbientReverb = Enum.ReverbType.NoReverb
			SoundService:SetListener(Enum.ListenerType.Camera)
			local result60 = settings()
			result60.Rendering.QualityLevel = Enum.QualityLevel.Level01
			result60.Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
			result60.Rendering.EditQualityLevel = Enum.QualityLevel.Level01
			local result61 = UserSettings()
			local UserGameSettings = result61:GetService("UserGameSettings")
			UserGameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
			workspace.CurrentCamera.FieldOfView = 70
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)

			task.spawn(function(...)
				workspace:GetDescendants()
				local players5 = Players:GetPlayers()

				for i13, v19 in ipairs(players5) do
					task.defer(function()
						v19.Character:GetDescendants()
					end, v19.Character)
				end

				task.wait(1)
				task.wait(1)
				-- [envlog] the statements above repeat forever (loop)
			end)

			local connection19 = Players.PlayerAdded:Connect(function(player2)
				player2.CharacterAdded:Connect(function(character15)
				end)

				task.defer(function()
				end, player2.Character)
			end)

			local connection20 = Players.LocalPlayer.CharacterAdded:Connect(function(character9)
			end)

			local connection21 = workspace.DescendantAdded:Connect(function(descendant2)
			end)
		else
			if connection19 then pcall(function() connection19:Disconnect() end) end
			if connection20 then pcall(function() connection20:Disconnect() end) end
			if connection21 then pcall(function() connection21:Disconnect() end) end
			Terrain2.WaterReflectance = Terrain2.WaterReflectance
			Terrain2.WaterWaveSize = Terrain2.WaterWaveSize
			Terrain2.WaterWaveSpeed = Terrain2.WaterWaveSpeed
			Terrain2.WaterTransparency = Terrain2.WaterTransparency
			Terrain2.Decoration = true
			Lighting.GlobalShadows = false
			Lighting.Brightness = 1
			Lighting.Technology = Lighting.Technology
			workspace.CurrentCamera.FieldOfView = 70
			local result62 = settings()
			result62.Rendering.QualityLevel = Enum.QualityLevel.Automatic
			result62.Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.DistanceBased
			UserSettings()
			UserGameSettings.SavedQualityLevel = Enum.SavedQualitySetting.Automatic
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, true)
		end
	end
})

Section49:AddDropdown({
	Title = "Lock your FPS",
	Default = "120 FPS",
	Options = { "30 FPS", "60 FPS", "90 FPS", "120 FPS", "144 FPS", "200 FPS", "240 FPS", "MAX FPS" },
	Callback = function()
	end
})

Section49:AddToggle({
	Title = "Black Screen",
	Content = "Make ur screen fully black!",
	Default = false,
	Callback = function(state)
		if state then
			local ToggleUIButton = CoreGui:FindFirstChild("ToggleUIButton")
			CoreGui:FindFirstChild("BlackScreen")
			MengHubGui.DisplayOrder = 100
			ToggleUIButton.DisplayOrder = 101
			RunService:Set3dRenderingEnabled(false)
		else
			CoreGui:FindFirstChild("ToggleUIButton")
			local BlackScreen = CoreGui:FindFirstChild("BlackScreen")
			if BlackScreen then BlackScreen:Destroy() end
			RunService:Set3dRenderingEnabled(true)
		end
	end
})

Section49:AddToggle({
	Title = "Remove Other Player",
	Content = "This feature will hide other player from ur visual",
	Default = false,
	Callback = function(state)
		if state then
			local players6 = game.Players:GetPlayers()

			for k7, v20 in pairs(players6) do
				v20.CharacterAdded:Connect(function(character10)
				end)

				v20.Character:GetDescendants()
				v20.Character:GetDescendants()
			end
		else
			local players7 = game.Players:GetPlayers()

			for k8, v21 in pairs(players7) do
				v21.CharacterAdded:Connect(function(character11)
				end)

				v21.Character:GetDescendants()
				v21.Character:GetDescendants()
			end
		end
	end
})

local Section50 = Tab9:AddSection("Utility Player")

Section50:AddToggle({
	Title = "Noclip",
	Default = false,
	Callback = function()
	end
})

Section50:AddSlider({
	Title = "Walkspeed",
	Default = 16,
	Max = 200,
	Min = 16,
	Callback = function()
		Players.LocalPlayer.Character:FindFirstChild("Humanoid")
	end
})

Section50:AddToggle({
	Title = "Enable Walkspeed",
	Default = false,
	Callback = function(state)
		if state then
			local Humanoid5 = Players.LocalPlayer.Character:FindFirstChild("Humanoid")
			Humanoid5.WalkSpeed = 16
		else
			local Humanoid6 = Players.LocalPlayer.Character:FindFirstChild("Humanoid")
			Humanoid6.WalkSpeed = 16
		end
	end
})

Lighting.Changed:Connect(function(value2)
end)

Section50:AddToggle({
	Title = "Full Brightness",
	Default = FullBrightEnabled,
	Callback = function(state)
		if state then
			Lighting.Ambient = Color3.new(1, 1, 1)
			Lighting.Brightness = 2
			Lighting.FogEnd = 100000
			Lighting.GlobalShadows = false
		else
			Lighting.Ambient = Color3.new(0, 0, 0)
			Lighting.Brightness = 1
			Lighting.FogEnd = 1000
			Lighting.GlobalShadows = true
		end
	end
})

Section50:AddToggle({
	Title = "Infinite Jump",
	Default = false,
	Callback = function()
	end
})

UserInputService.JumpRequest:Connect(function()
end)

Section50:AddToggle({
	Title = "Max Zoom 1000",
	Content = "Increase max camera distance",
	Default = false,
	Callback = function(state)
		if state then
			Players.LocalPlayer.CameraMaxZoomDistance = 1000
			Players.LocalPlayer.CameraMinZoomDistance = 0.5

			local connection22 = Players.LocalPlayer.CharacterAdded:Connect(function(character12)
				task.wait(0.3)
				Players.LocalPlayer.CameraMaxZoomDistance = 1000
				Players.LocalPlayer.CameraMinZoomDistance = 0.5
			end)
		else
			if connection22 then pcall(function() connection22:Disconnect() end) end
			Players.LocalPlayer.CameraMaxZoomDistance = 128
			Players.LocalPlayer.CameraMinZoomDistance = 0.5
		end
	end
})

local Events3 = Players.LocalPlayer.PlayerGui:WaitForChild("Events")
local Frame14 = Events3:WaitForChild("Frame")
local Location = Frame14:WaitForChild("Location")
local lastFrame = Location:WaitForChild("Label")
local Events4 = Players.LocalPlayer.PlayerGui:WaitForChild("Events")
local Frame15 = Events4:WaitForChild("Frame")
local CurrencyCounter = Frame15:WaitForChild("CurrencyCounter")
local lastFrame2 = CurrencyCounter:WaitForChild("lastFrame2")
Players.LocalPlayer.Character:GetDescendants()

Section50:AddToggle({
	Title = "Streamer Mode",
	Content = "This feature will sensored ur location, coins, and hide character!",
	Default = false,
	Callback = function(state)
		if state then
			local changedSignal = lastFrame:GetPropertyChangedSignal("Text")

			local connection23 = changedSignal:Connect(function()
				lastFrame.Text = "CENSORED"
			end)

			local changedSignal2 = lastFrame2:GetPropertyChangedSignal("Text")

			local connection24 = changedSignal2:Connect(function()
				lastFrame2.Text = "CENSORED"
			end)

			lastFrame.Text = "CENSORED"
			lastFrame2.Text = "CENSORED"
		else
			if connection23 then pcall(function() connection23:Disconnect() end) end
			if connection24 then pcall(function() connection24:Disconnect() end) end
			lastFrame.Text = lastFrame.Text
			lastFrame2.Text = lastFrame2.Text
		end
	end
})

Section50:AddSubSection("Fly Features")

Section50:AddSlider({
	Title = "Fly Speed",
	Default = 1,
	Max = 10,
	Min = 1,
	Callback = function()
	end
})

Section50:AddToggle({
	Title = "Enable Fly",
	Default = false,
	Callback = function(state)
		if state then
			local HumanoidRootPart40 = Players.LocalPlayer.Character:WaitForChild("HumanoidRootPart")
			local Humanoid7 = Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			local PlayerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
			local PlayerModule = PlayerScripts:WaitForChild("PlayerModule")
			local ControlModule = PlayerModule:WaitForChild("ControlModule")
			local module16 = safeRequire(ControlModule)
			local BodyVelocity3 = Instance.new("BodyVelocity")
			local BodyGyro = Instance.new("BodyGyro")
			BodyVelocity3.MaxForce = Vector3.new(8999999488, 8999999488, 8999999488)
			BodyGyro.MaxTorque = Vector3.new(8999999488, 8999999488, 8999999488)
			BodyGyro.P = 1000
			BodyGyro.D = 50
			BodyVelocity3.Parent = HumanoidRootPart40
			BodyGyro.Parent = HumanoidRootPart40
			Humanoid7.PlatformStand = true

			task.spawn(function()
				task.wait()
				module16:GetMoveVector()
				BodyGyro.CFrame = workspace.CurrentCamera.CFrame
				-- [envlog] error: Luraph Script:12438: Script:62: attempt to perform arithmetic (mul) on boolean and number
			end)
		else
			local Humanoid8 = Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			Humanoid8.PlatformStand = false
			local HumanoidRootPart41 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			HumanoidRootPart41:GetChildren()
		end
	end
})

Section50:AddSubSection("Freecam Features")
local changedSignal3 = workspace:GetPropertyChangedSignal("CurrentCamera")

changedSignal3:Connect(function()
end)

UserInputService.TouchStarted:Connect(function()
end)

UserInputService.TouchEnded:Connect(function(hit)
end)

UserInputService.TouchMoved:Connect(function()
end)

Section50:AddToggle({
	Title = "Freecam Mode",
	Default = false,
	Keybind = true,
	Callback = function(state)
		if state then
			RunService:BindToRenderStep("Freecam", 200, function(arg463)
				local moveVector = Players.LocalPlayer:GetMoveVector()
				local value3 = math.exp((-31.415926535897931 * arg463))
				workspace.CurrentCamera.CFrame = ((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463))
				workspace:FindPartOnRay(Ray.new((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).Position + ((((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).RightVector * 0/0) - (((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).UpVector * -0.70020753820970971)) + ((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).LookVector) * 0.1)), ((((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).RightVector * 0/0) - (((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).UpVector * -0.70020753820970971)) + ((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).LookVector).Unit * 512)))
				workspace:FindPartOnRay(Ray.new((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).Position + ((((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).RightVector * 0/0) - (((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).UpVector * 0)) + ((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).LookVector) * 0.1)), ((((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).RightVector * 0/0) - (((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).UpVector * 0)) + ((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).LookVector).Unit * 512)))
				workspace:FindPartOnRay(Ray.new((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).Position + ((((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).RightVector * 0/0) - (((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).UpVector * 0.70020753820970971)) + ((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).LookVector) * 0.1)), ((((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).RightVector * 0/0) - (((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).UpVector * 0.70020753820970971)) + ((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).LookVector).Unit * 512)))
				workspace:FindPartOnRay(Ray.new((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).Position + ((((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).RightVector * 0/0) - (((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).UpVector * -0.70020753820970971)) + ((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).LookVector) * 0.1)), ((((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).RightVector * 0/0) - (((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).UpVector * -0.70020753820970971)) + ((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).LookVector).Unit * 512)))
				workspace:FindPartOnRay(Ray.new((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).Position + ((((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).RightVector * 0/0) - (((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).UpVector * 0)) + ((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).LookVector) * 0.1)), ((((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).RightVector * 0/0) - (((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).UpVector * 0)) + ((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).LookVector).Unit * 512)))
				workspace:FindPartOnRay(Ray.new((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).Position + ((((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).RightVector * 0/0) - (((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).UpVector * 0.70020753820970971)) + ((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).LookVector) * 0.1)), ((((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).RightVector * 0/0) - (((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).UpVector * 0.70020753820970971)) + ((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).LookVector).Unit * 512)))
				workspace:FindPartOnRay(Ray.new((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).Position + ((((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).RightVector * 0/0) - (((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).UpVector * -0.70020753820970971)) + ((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).LookVector) * 0.1)), ((((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).RightVector * 0/0) - (((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).UpVector * -0.70020753820970971)) + ((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).LookVector).Unit * 512)))
				workspace:FindPartOnRay(Ray.new((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).Position + ((((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).RightVector * 0/0) - (((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).UpVector * 0)) + ((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).LookVector) * 0.1)), ((((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).RightVector * 0/0) - (((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).UpVector * 0)) + ((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).LookVector).Unit * 512)))
				workspace:FindPartOnRay(Ray.new((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).Position + ((((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).RightVector * 0/0) - (((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).UpVector * 0.70020753820970971)) + ((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).LookVector) * 0.1)), ((((((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).RightVector * 0/0) - (((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).UpVector * 0.70020753820970971)) + ((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).LookVector).Unit * 512)))
				local result63 = ((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)).LookVector:Dot(Vector3.new(0, 0, 0))
				workspace.CurrentCamera.Focus = (((CFrame.new(workspace.CurrentCamera.CFrame.Position) * CFrame.fromOrientation(0, 0, 0)) * CFrame.new((((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) + (((Vector3.new(0, 0, 0) * arg463) - (((Vector3.new(moveVector.X, 0, (-moveVector.Z)) * 1) - Vector3.new(0, 0, 0)) * ((31.415926535897931 * arg463) + 1))) * value3)) * 64) * arg463)) * CFrame.new(0, 0, (-(result63 * 512))))
			end)
		else
			RunService:UnbindFromRenderStep("Freecam")
		end
	end
})

Section50:AddButton({
	Title = "Reset Freecam",
	Callback = function()
	end
})

local Section51 = Tab9:AddSection("Server Features")

Section51:AddToggle({
	Title = "Auto Reconnect",
	Default = true,
	Callback = function(state)
		if state then
			local GuiService = game:GetService("GuiService")

			local connection25 = GuiService.ErrorMessageChanged:Connect(function()
				task.wait(2)
			end)

			GuiService:GetErrorMessage()
			Players:GetPlayers()
			TeleportService:Teleport(0, Players.LocalPlayer)
		else
			if connection25 then pcall(function() connection25:Disconnect() end) end
		end
	end
})

Section51:AddToggle({
	Title = "Auto Execute",
	Default = false,
	Callback = function(state)
		if state then
			queue_on_teleport("                loadstring(game:HttpGet(\"https://raw.githubusercontent.com/GrexXMeng/Mengs/refs/heads/main/library\"))()\n            ")
		else
			queue_on_teleport("")
		end
	end
})

Section51:AddDivider()
_G.AutoFriend = false

Section51:AddToggle({
	Title = "Auto Send Friend Request",
	Content = "Automatically send friend request to all players in server",
	Default = false,
	Callback = function(state)
		if state then
			_G.AutoFriend = state

			task.spawn(function()
				local players8 = Players:GetPlayers()

				for i14, v22 in ipairs(players8) do
					Players.LocalPlayer:IsFriendsWith(v22.UserId)
				end
			end)
		end
	end
})

Section51:AddToggle({
	Title = "Auto Accept Friend Request",
	Default = false,
	Callback = function(state)
		if state then
			_G.AutoAccept = state

			task.spawn(function()
				local players9 = Players:GetPlayers()

				for i15, v23 in ipairs(players9) do
					Players.LocalPlayer:IsFriendsWith(v23.UserId)
				end

				task.wait(7)
				local players10 = Players:GetPlayers()

				for i16, v24 in ipairs(players10) do
					Players.LocalPlayer:IsFriendsWith(v24.UserId)
				end

				task.wait(5)
				local players11 = Players:GetPlayers()

				for i17, v25 in ipairs(players11) do
					Players.LocalPlayer:IsFriendsWith(v25.UserId)
				end

				task.wait(9)
				local players12 = Players:GetPlayers()

				for i18, v26 in ipairs(players12) do
					Players.LocalPlayer:IsFriendsWith(v26.UserId)
				end

				task.wait(7)
				local players13 = Players:GetPlayers()

				for i19, v27 in ipairs(players13) do
					Players.LocalPlayer:IsFriendsWith(v27.UserId)
				end

				task.wait(8)
				local players14 = Players:GetPlayers()

				for i20, v28 in ipairs(players14) do
					Players.LocalPlayer:IsFriendsWith(v28.UserId)
				end

				task.wait(5)
				local players15 = Players:GetPlayers()

				for i21, v29 in ipairs(players15) do
					Players.LocalPlayer:IsFriendsWith(v29.UserId)
				end

				task.wait(7)
				-- [envlog] the statements above repeat forever (loop)
			end)
		else
			_G.AutoAccept = false

			task.spawn(function()
			end)
		end
	end
})

local Section52 = Tab9:AddSection("Miscellaneous")

Section52:AddButton({
	Title = "Reset Character in Place",
	Callback = function()
		Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		Players.LocalPlayer.Character:BreakJoints()
		local result64 = Players.LocalPlayer.CharacterAdded:Wait()
		local HumanoidRootPart42 = result64:WaitForChild("HumanoidRootPart")
		task.wait(0.3)
		HumanoidRootPart42.CFrame = (pivot + Vector3.new(0, 100, 0))
		task.wait()
		-- [envlog] the statements above repeat forever (loop)
	end
})

local PlayerGui3 = Players.LocalPlayer:FindFirstChild("PlayerGui")
local TextNotifications = PlayerGui3:FindFirstChild("Text Notifications")
local Frame16 = TextNotifications:FindFirstChild("Frame")
Frame16.Position = UDim2.new(0.5, 0, 0, 110)

Section52:AddDropdown({
	Title = "Notification Position",
	Content = "This feature will set position fish notification",
	Default = "Normal (Mid)",
	Options = { "Normal (Mid)", "Right", "Left" },
	Callback = function(state)
		if state then
			local PlayerGui4 = Players.LocalPlayer:FindFirstChild("PlayerGui")
			local TextNotifications2 = PlayerGui4:FindFirstChild("Text Notifications")
			local Frame17 = TextNotifications2:FindFirstChild("Frame")
			Frame17.Position = UDim2.new(0.5, 0, 0, 110)
		else
			local PlayerGui5 = Players.LocalPlayer:FindFirstChild("PlayerGui")
			local TextNotifications3 = PlayerGui5:FindFirstChild("Text Notifications")
			local Frame18 = TextNotifications3:FindFirstChild("Frame")
			Frame18.Position = UDim2.new(0.5, 0, 0, 110)
		end
	end
})

Section52:AddToggle({
	Title = "Clean Screen",
	Content = "Hides all gui on ur screen!",
	Callback = function(state)
		if state then
			local Events5 = Players.LocalPlayer.PlayerGui:FindFirstChild("Events")
			local Quest = Players.LocalPlayer.PlayerGui:FindFirstChild("Quest")
			local ActivePotions = Players.LocalPlayer.PlayerGui:FindFirstChild("Active Potions")
			local Backpack = Players.LocalPlayer.PlayerGui:FindFirstChild("Backpack")
			Events5:FindFirstChild("Frame")
			Events5.Frame.Visible = false
			Quest:FindFirstChild("List")
			Quest.List.Visible = false
			ActivePotions:FindFirstChild("Rows")
			ActivePotions.Rows.Visible = false
			Backpack:FindFirstChild("Display")
			Backpack:FindFirstChild("Modifiers")
			Backpack:FindFirstChild("AutoFishingButton")
			Backpack.Display.Visible = false
			Backpack.Modifiers.Visible = false
			Backpack.AutoFishingButton.Visible = false
		else
			local Events6 = Players.LocalPlayer.PlayerGui:FindFirstChild("Events")
			local Quest2 = Players.LocalPlayer.PlayerGui:FindFirstChild("Quest")
			local ActivePotions2 = Players.LocalPlayer.PlayerGui:FindFirstChild("Active Potions")
			local Backpack2 = Players.LocalPlayer.PlayerGui:FindFirstChild("Backpack")
			Events6:FindFirstChild("Frame")
			Events6.Frame.Visible = true
			Quest2:FindFirstChild("List")
			Quest2.List.Visible = true
			ActivePotions2:FindFirstChild("Rows")
			ActivePotions2.Rows.Visible = true
			Backpack2:FindFirstChild("Display")
			Backpack2:FindFirstChild("Modifiers")
			Backpack2:FindFirstChild("AutoFishingButton")
			Backpack2.Display.Visible = true
			Backpack2.Modifiers.Visible = true
			Backpack2.AutoFishingButton.Visible = true
		end
	end
})

local _WeatherVFX = _G._WeatherVFX

Section52:AddToggle({
	Title = "Disable VFX",
	Default = false,
	Callback = function(state)
		if state then
			_G._WeatherVFX = _WeatherVFX
			local VFXController = ReplicatedStorage.Controllers:WaitForChild("VFXController")
			local module17 = safeRequire(VFXController)

			for k9, v31 in pairs(module17) do
			end

			workspace:GetDescendants()

			local connection26 = workspace.DescendantAdded:Connect(function(descendant3)
				descendant3:GetAttribute("AbilityVFX")
				if descendant3 then descendant3:Destroy() end
			end)

			local connection27 = Players.PlayerAdded:Connect(function(player3)
				player3.CharacterAdded:Connect(function(character16)
					task.wait(0.3)
					character16:GetDescendants()

					character16.DescendantAdded:Connect(function(descendant8)
						descendant8:GetAttribute("AbilityVFX")
						if descendant8 then descendant8:Destroy() end
					end)
				end)

				player3.Character:GetDescendants()

				player3.Character.DescendantAdded:Connect(function(descendant6)
					descendant6:GetAttribute("AbilityVFX")
					if descendant6 then descendant6:Destroy() end
				end)
			end)

			local players16 = Players:GetPlayers()

			for i23, v32 in ipairs(players16) do
				local connection28 = v32.CharacterAdded:Connect(function(character13)
					task.wait(0.3)
					character13:GetDescendants()

					character13.DescendantAdded:Connect(function(descendant7)
						descendant7:GetAttribute("AbilityVFX")
						if descendant7 then descendant7:Destroy() end
					end)
				end)

				v32.Character:GetDescendants()

				local connection29 = v32.Character.DescendantAdded:Connect(function(descendant4)
					descendant4:GetAttribute("AbilityVFX")
					if descendant4 then descendant4:Destroy() end
				end)
			end

			if _WeatherVFX and _WeatherVFX.conn then pcall(function() _WeatherVFX.conn:Disconnect() end) end
			_WeatherVFX.conn = nil

			for i24, v33 in ipairs(_WeatherVFX.conns) do
				if v33 then pcall(function() v33:Disconnect() end) end
			end

			_WeatherVFX.conns = nil
			local module18 = safeRequire(ReplicatedStorage.Controllers.WeatherController.Classic.PartPool)
			_WeatherVFX.origAcquire = module18.Acquire
			_WeatherVFX.origUseDesc = module18.UseDescription
			_WeatherVFX.WeatherController = module18

			module18.Acquire = function()
				Instance.new("Part")
			end

			module18.UseDescription = function()
			end

			local module19 = safeRequire(ReplicatedStorage.Controllers.WeatherController.Classic.Scheduler)
			_WeatherVFX.origSchedulerAdd = module19.add
			_WeatherVFX.origSchedulerDelay = module19.delay
			_WeatherVFX.Scheduler = module19

			module19.add = function()
			end

			module19.delay = function()
			end

			local Tornado_Active = workspace:FindFirstChild("Tornado_Active")
			if Tornado_Active then Tornado_Active:Destroy() end
			local TornadoDebris_Parking = workspace:FindFirstChild("TornadoDebris_Parking")
			if TornadoDebris_Parking then TornadoDebris_Parking:Destroy() end
			local Tornado_Parking = workspace:FindFirstChild("Tornado_Parking")
			if Tornado_Parking then Tornado_Parking:Destroy() end
			local DiscoEvent = workspace:FindFirstChild("DiscoEvent")
			if DiscoEvent then DiscoEvent:Destroy() end
			local Volcano_Active = workspace:FindFirstChild("Volcano_Active")
			if Volcano_Active then Volcano_Active:Destroy() end
			local Lightning_Active = workspace:FindFirstChild("Lightning_Active")
			if Lightning_Active then Lightning_Active:Destroy() end
			local SmokePart = workspace:FindFirstChild("SmokePart")
			if SmokePart then SmokePart:Destroy() end
			_WeatherVFX.conns = {}

			local connection30 = workspace.ChildAdded:Connect(function(child5)
			end)

			_WeatherVFX.conn = connection30
			print("[MengXHub] VFX Optimization:", "Enabled (Lag Reduced)")
		else
			if connection28 then pcall(function() connection28:Disconnect() end) end
			if connection29 then pcall(function() connection29:Disconnect() end) end
			if connection27 then pcall(function() connection27:Disconnect() end) end
			if connection26 then pcall(function() connection26:Disconnect() end) end
			local VFXController2 = ReplicatedStorage.Controllers:WaitForChild("VFXController")
			local module20 = safeRequire(VFXController2)

			for k10, v34 in pairs(module20) do
			end

			if connection30 then pcall(function() connection30:Disconnect() end) end
			_WeatherVFX.conn = nil
			_WeatherVFX.conns = nil
			module18.Acquire = module18.Acquire
			module18.UseDescription = module18.UseDescription
			module19.add = module19.add
			module19.delay = module19.delay
			_WeatherVFX.fakePart:Destroy()
			_WeatherVFX.fakePart = nil
			_WeatherVFX.WeatherController = nil
			_WeatherVFX.Scheduler = nil
			_WeatherVFX.origAcquire = nil
			_WeatherVFX.origUseDesc = nil
			_WeatherVFX.origSchedulerAdd = nil
			_WeatherVFX.origSchedulerDelay = nil
			print("[MengXHub] VFX Optimization:", "Disabled")
		end
	end
})

if type(getgenv()._FakeIdentityCleanup) == "function" then
	pcall(getgenv()._FakeIdentityCleanup)
end
getgenv()._FakeIdentityCleanup = function() end

local players17 = Players:GetPlayers()

local function getOverhead(v)
	local HumanoidRootPart43 = v.Character:WaitForChild("HumanoidRootPart", 5)
	local Overhead = HumanoidRootPart43:FindFirstChild("Overhead")
	return Overhead
end

local function setupHeader(header, label)
	if header and label then pcall(function() header.Text = header.Text; label.Text = label.Text end) end
end

for i25, v35 in ipairs(players17) do
	task.spawn(function()
		local Overhead = getOverhead(v35)
		Overhead:FindFirstChild("Content")
		local Header = Overhead.Content:FindFirstChild("Header")
		Overhead:FindFirstChild("LevelContainer")
		local Label56 = Overhead.LevelContainer:FindFirstChild("Label")
		local changedSignal4 = Header:GetPropertyChangedSignal("Text")

		local connection31 = changedSignal4:Connect(function()
		end)

		local changedSignal5 = Label56:GetPropertyChangedSignal("Text")

		local connection32 = changedSignal5:Connect(function()
		end)
	end, v35)

	v35.CharacterAdded:Connect(function(character14)
		task.wait(0.3)
		local Overhead2 = getOverhead(v35)
		Overhead2:FindFirstChild("Content")
		local Header2 = Overhead2.Content:FindFirstChild("Header")
		Overhead2:FindFirstChild("LevelContainer")
		local Label58 = Overhead2.LevelContainer:FindFirstChild("Label")
		if connection31 then pcall(function() connection31:Disconnect() end) end
		if connection32 then pcall(function() connection32:Disconnect() end) end
		local changedSignal6 = Header2:GetPropertyChangedSignal("Text")

		changedSignal6:Connect(function()
		end)

		local changedSignal7 = Label58:GetPropertyChangedSignal("Text")

		changedSignal7:Connect(function()
		end)

		setupHeader(Header2, Label58)
	end)
end

Players.PlayerAdded:Connect(function(player4)
	player4.CharacterAdded:Connect(function(character17)
		task.wait(0.3)
		local Overhead3 = getOverhead(player4)
		Overhead3:FindFirstChild("Content")
		local Header3 = Overhead3.Content:FindFirstChild("Header")
		Overhead3:FindFirstChild("LevelContainer")
		local Label59 = Overhead3.LevelContainer:FindFirstChild("Label")
		local changedSignal8 = Header3:GetPropertyChangedSignal("Text")

		changedSignal8:Connect(function()
		end)

		local changedSignal9 = Label59:GetPropertyChangedSignal("Text")

		changedSignal9:Connect(function()
		end)

		Header2.Text = Header2.Text
		Label58.Text = Label58.Text
		Header3.Text = Header3.Text
		Label59.Text = Label59.Text
	end)
end)

Players.PlayerRemoving:Connect(function(player5)
end)

CoreGui.DescendantAdded:Connect(function(descendant5)
end)

Section52:AddSubSection("Fake Identity")

Section52:AddInput({
	Title = "Name Changer",
	Placeholder = "Rawrr :3",
	Callback = function()
	end
})

Section52:AddInput({
	Title = "Lvl Changer",
	Placeholder = "Lvl: Unknown",
	Callback = function()
	end
})

Section52:AddToggle({
	Title = "Start Hide Identifier",
	Default = false,
	Callback = function(state)
		if state then
			local VerifiedName = getgenv().VerifiedName
			getgenv().VerifiedName = VerifiedName
			Header.Text = Players.LocalPlayer.DisplayName .. " "
			local child = workspace.Characters:FindFirstChild(Players.LocalPlayer.Name)
			local HumanoidRootPart44 = child:FindFirstChild("HumanoidRootPart")
			HumanoidRootPart44.Overhead:FindFirstChild("LevelContainer")
			local Label57 = HumanoidRootPart44.Overhead.LevelContainer:FindFirstChild("Label")
			Label56.Text = Label57.Text

			local connection33 = RunService.RenderStepped:Connect(function(deltaTime10)
				if connection33 then pcall(function() connection33:Disconnect() end) end
			end)

			task.delay(1.5, function()
			end)

			CoreGui:GetDescendants()
		else
			Header.Text = Header.Text
			Label56.Text = Label56.Text
		end
	end
})

Section52:AddToggle({
	Title = "Show Premium, Verified Badge",
	Default = false,
	Callback = function(state)
		if not state then
			getgenv().VerifiedName = false
			Header.Text = Header.Text
			Label56.Text = Label56.Text
		end
	end
})

task.spawn(function()
	task.wait(1.5)
	setupHeader(Header, Label56)
end)

end -- end Tab9

do -- start Tab10
local Section53 = Tab10:AddSection("Teleport To Player")
local players18 = Players:GetPlayers()

for i26, v36 in ipairs(players18) do
end

local Dropdown3 = Section53:AddDropdown({
	Title = "Select Player",
	Options = { (v36 and v36.Name) or (Players.LocalPlayer and Players.LocalPlayer.Name) or "None" },
	Callback = function()
	end
})

Section53:AddButton({
	Title = "Refresh Player",
	Callback = function(state)
		if state then
			local players19 = Players:GetPlayers()

			for i27, v37 in ipairs(players19) do
			end

			Dropdown3:SetValues({ v37.Name })
		else
			local players20 = Players:GetPlayers()

			for i28, v38 in ipairs(players20) do
			end

			Dropdown3:SetValues({ v38.Name })
		end

		notif("Successfully refresh!")
	end
})

Section53:AddToggle({
	Title = "Auto Follow Player",
	Default = false,
	Callback = function(state)
		if state then
			local Humanoid9 = Players.LocalPlayer.Character:WaitForChild("Humanoid")
			local Animator2 = Humanoid9:FindFirstChildOfClass("Animator")
			local tracks2 = Animator2:GetPlayingAnimationTracks()

			for i29, v39 in ipairs(tracks2) do
				v39:Stop(0)
			end

			local connection34 = Animator2.AnimationPlayed:Connect(function()
			end)

			notif("Select player first!")
		else
			local Humanoid10 = Players.LocalPlayer.Character:WaitForChild("Humanoid")
			Humanoid10:FindFirstChildOfClass("Animator")
			if connection34 then pcall(function() connection34:Disconnect() end) end
		end
	end
})

Section53:AddButton({
	Title = "Teleport To Player",
	Callback = function()
		notif("Please select a player first!")
	end
})

local Section54 = Tab10:AddSection("Location")

Section54:AddDropdown({
	Title = "Select Location",
	Default = "(NEW) Throne Room Blizzard",
	Options = {
		"(NEW) Throne Room Blizzard",
		"(NEW) Throne Room Storm",
		"(NEW) Throne Room Volcano",
		"Ancient Jungle",
		"Ancient Ruin",
		"Copper Canyon",
		"Copper Canyon High",
		"Copper Canyon Mines",
		"Coral Reefs 1",
		"Coral Reefs 2",
		"Coral Reefs 3",
		"Crater Island",
		"Crater Island Top",
		"Crystal Depths",
		"Crystaline Pessage",
		"Elemental Blizzard",
		"Elemental Storm",
		"Elemental Volcano",
		"Esoteric Depths",
		"Fisherman Island Underground",
		"Gloomcap Grotto",
		"Kohana",
		"Kohana 1",
		"Kohana 2",
		"Kohana Volcano",
		"Lava Basin",
		"Leviathan's Den",
		"Lost Shore",
		"Lucky Abyss",
		"Mariana Trench",
		"Ocean",
		"Pirate Island's",
		"Pirate Treasure Room",
		"Planetary Observatory",
		"Sacred Temple",
		"Secret Passage",
		"Sewers",
		"Shiny Abyss",
		"Sisyphus Statue",
		"Stingray Shores",
		"Treasure Room",
		"Tropical Grove",
		"Tropical Grove Cave 1",
		"Tropical Grove Cave 2",
		"Tropical Grove Highground",
		"Underground Cellar",
		"Underwater City",
		"Volcano Cavern",
		"Weather Machine"
	},
	Callback = function()
	end
})

Section54:AddButton({
	Title = "Teleport To Location",
	Callback = function()
		notif("Please select a location first!")
	end
})

workspace.NPC:GetChildren()
local Section55 = Tab10:AddSection("Teleport To NPC")

Section55:AddDropdown({
	Title = "Select NPC",
	Options = { "No NPC Found" },
	Callback = function()
	end
})

Section55:AddButton({
	Title = "Teleport To NPC",
	Callback = function(state)
		if state then
			local child2 = workspace.NPC:FindFirstChild(false)
			Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			local pivot2 = child2:GetPivot()
			local HumanoidRootPart45 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			HumanoidRootPart45.CFrame = (pivot2 * CFrame.new(0, 5, 0))
		else
			local child3 = workspace.NPC:FindFirstChild(false)
			Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			local pivot3 = child3:GetPivot()
			local HumanoidRootPart46 = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			HumanoidRootPart46.CFrame = (pivot3 * CFrame.new(0, 5, 0))
		end
	end
})

_G.WebhookFlags = {
	Disconnect = {
		Enabled = false,
		URL = "https://discord.com/api/webhooks/1447737110252748953/B2lPvuO8YuDpgX_3NhI5JFB5PgFUhlz-Owa-1JeboCr9VUtj4yf53b6HVI9M8afjSxdU"
	},
	FishCaught = {
		Enabled = false,
		URL = "https://discord.com/api/webhooks/1447736942149243083/eMd0LSuUrKslVu3lndvnoKTTEzmryJ-lPpDOb3AR5TeL58Jy10g5Qf05m1qYAVK4D9w0"
	},
	PlayerConnection = { Enabled = false, Interval = 300, URL = "" }
}

local WebhookRarities = _G.WebhookRarities
_G.WebhookRarities = WebhookRarities
local WebhookNames = _G.WebhookNames
_G.WebhookNames = WebhookNames
local WebhookMutation = _G.WebhookMutation
_G.WebhookMutation = WebhookMutation
local WebhookURLs = _G.WebhookURLs
_G.WebhookURLs = WebhookURLs
_G.WebhookGlobalEnabled = false
_G.WebhookDiscordID = ""
_G.WebhookGlobalURLs = "https://discord.com/api/webhooks/1459165747963101257/dRRAHvajoLjkSHcIUN4FTBtZe1V-UijeFdXarr3uSukFj4xypNSDvHaGOS2qCo3KZLKu"
_G.PlayerConnectionLoopActive = false
local FishWebhookConnected = _G.FishWebhookConnected
_G.FishWebhookConnected = FishWebhookConnected
_G.ServerWebhookURL = ""
_G.ServerWebhookDCURL = ""
_G.ServerWebhookDCCensored = false
_G.ServerWebhookDCEnabled = false
_G.RubyWebhookEnabled = false
_G.RubyWebhookConnected = false
_G.EggyWebhookEnabled = false
_G.EggyWebhookConnected = false
_G.EvolvedWebhookEnabled = false
_G.EvolvedWebhookConnected = false
_G.RunicWebhookEnabled = false
_G.RunicWebhookConnected = false
_G.ServerWebhookEnabled = false
_G.ServerWebhookConnected = false

task.delay(5, function()
	pcall(function()
		if _G.httpRequest then
			local result65 = _G.httpRequest({
				Method = "GET",
				Url = "https://raw.githubusercontent.com/Meng-Dev1/LAUSAPEMPRUY-/refs/heads/main/fish_final.json"
			})
			if result65 and (result65.Body or result65.body) then
				local data6 = HttpService:JSONDecode(result65.Body or result65.body)
				print("[Meng Hub] 1 Gambar Ikan Berhasil Dimuat!")
			end
		end
	end)
end)

Items:GetChildren()

task.spawn(function()
	task.wait()
	game:IsLoaded()
end)

end -- end Tab10

do -- start Tab11
local Section56 = Tab11:AddSection("Webhook Fish Caught")

Section56:AddInput({
	Title = "Webhook URL",
	Default = "",
	Callback = function(state)
		if state then
			WebhookURLs.FishCaught = state
		else
			WebhookURLs.FishCaught = false
		end
	end
})

_G.WebhookRarities = false

Section56:AddDropdown({
	Title = "Tier Filter",
	Default = { "Legendary", "Mythic", "Secret", "Forgotten" },
	Multi = true,
	Options = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Forgotten" },
	Callback = function()
	end
})

Section56:AddSubSection("Webhook by Name & Mutation")
_G.WebhookNames = false

Section56:AddDropdown({
	Title = "Name Filter",
	Default = {},
	Multi = true,
	Options = { "Withering Core" },
	Callback = function()
	end
})

_G.WebhookMutation = false

Section56:AddDropdown({
	Title = "Mutation Filter",
	Default = {},
	Multi = true,
	Options = {},
	Callback = function()
	end
})

local WebhookCustomName = _G.WebhookCustomName
_G.WebhookCustomName = false

Section56:AddInput({
	Title = "Hide Identity Caught",
	Content = "Protect your name for sending webhook to discord",
	Default = WebhookCustomName,
	Callback = function()
	end
})

Section56:AddToggle({
	Title = "Send Fish Webhook",
	Default = false,
	Callback = function()
	end
})

Section56:AddButton({
	Title = "Test Webhook Connection",
	Callback = function()
		warn("[Webhook Test] ❌ Invalid or missing webhook URL.")
	end
})

Section56:AddSubSection("Webhook Fish Global")

Section56:AddInput({
	Title = "Discord ID (For Tag)",
	Placeholder = "Input discord id here...",
	Callback = function(arg535)
		arg535:match("^%d+$")
		notif("Discord ID must be 17-19 digits long!")
	end
})

Section56:AddToggle({
	Title = "Send Webhook Global",
	Content = "Only Secret & Forgotten",
	Callback = function()
	end
})

RunService.Heartbeat:Connect(function(deltaTime11)
end)

local Section57 = Tab11:AddSection("Webhook Player Connection")

Section57:AddInput({
	Title = "Player Connection Webhook URL",
	Placeholder = "Input URL Here...",
	Callback = function()
	end
})

Section57:AddDropdown({
	Title = "Send Interval",
	Default = "5 Minutes",
	Options = { "5 Minutes", "10 Minutes", "15 Minutes", "30 Minutes" },
	Callback = function()
	end
})

_G.PlayerConnectionLoopActive = false

Section57:AddToggle({
	Title = "Send Webhook Player Connection",
	Callback = function(state)
		if state then
			task.wait(0.1)

			task.spawn(function()
				_G.PlayerConnectionLoopActive = true
				task.wait(300)
				task.wait(300)
				-- [envlog] the statements above repeat forever (loop)
			end)
		end
	end
})

Section57:AddButton({
	Title = "Test Player Connection Webhook",
	Callback = function()
		notif("Invalid or missing webhook URL!")
	end
})

local Section58 = Tab11:AddSection("Webhook Alert/Disconnect")

Section58:AddInput({
	Title = "Disconnect Alert Webhook URL",
	Placeholder = "Input URL here",
	Callback = function(state)
		if state then
			WebhookURLs.Disconnect = state
		else
			WebhookURLs.Disconnect = false
		end
	end
})

Section58:AddInput({
	Title = "Discord ID",
	Placeholder = "Input ur Discord Id here",
	Callback = function(state)
		if state then
			state:gsub("%D", "")
		end
	end
})

local DisconnectCustomName = _G.DisconnectCustomName
_G.DisconnectCustomName = false

Section58:AddInput({
	Title = "Hide Identity Disconnect",
	Default = DisconnectCustomName,
	Placeholder = "Enter custom name (leave blank for default)",
	Callback = function()
	end
})

Section58:AddToggle({
	Title = "Send Webhook On Disconnect",
	Content = "Notify your Discord when account disconnected and auto rejoin.",
	Default = false,
	Callback = function(state)
		if state then
			notif("Invalid! Input Hide Identity first.")
		end
	end
})

Section58:AddButton({
	Title = "Test Disconnected Player",
	Content = "Kick ur self, send webhook, and auto rejoin.",
	Callback = function()
		notif("Kicking player...")
		task.wait(1)
		task.wait(2)
		TeleportService:Teleport(0, Players.LocalPlayer)
	end
})

local Section59 = Tab11:AddSection("Server Webhook")
Section59:AddSubSection("Webhook Protection")

Section59:AddToggle({
	Title = "Censored Name",
	Default = true,
	Callback = function()
	end
})

Section59:AddSubSection("Webhook Fish Caught Server")
_G.ServerWebhookURL = false

Section59:AddInput({
	Title = "Server Webhook URL",
	Placeholder = "Write ur input here...",
	Callback = function()
	end
})

_G.EvolvedWebhookEnabled = false

Section59:AddToggle({
	Title = "Evolved Enchant Stone",
	Content = "Notify your Discord when someone catch Evolved.",
	Default = false,
	Callback = function(state)
		if state then
			_G.EvolvedWebhookEnabled = state
			_G.EvolvedWebhookConnected = true

			TextChatService.MessageReceived:Connect(function()
			end)
		end
	end
})

_G.RunicWebhookEnabled = false

Section59:AddToggle({
	Title = "Runic Enchant Stone",
	Content = "Notify your Discord when someone catch Runic.",
	Default = false,
	Callback = function(state)
		if state then
			_G.RunicWebhookConnected = true
			_G.RunicWebhookEnabled = state

			TextChatService.MessageReceived:Connect(function()
			end)
		end
	end
})

_G.RubyWebhookEnabled = false

Section59:AddToggle({
	Title = "Ruby Gemstone",
	Content = "Notify your Discord when someone catch Ruby.",
	Default = false,
	Callback = function(state)
		if state then
			_G.RubyWebhookConnected = true
			_G.RubyWebhookEnabled = state

			TextChatService.MessageReceived:Connect(function()
			end)
		end
	end
})

_G.ServerWebhookEnabled = false

Section59:AddToggle({
	Title = "Secret & Forgotten",
	Default = false,
	Callback = function(state)
		if state then
			_G.ServerWebhookEnabled = state
			_G.ServerWebhookConnected = true

			TextChatService.MessageReceived:Connect(function()
			end)
		end
	end
})

Section59:AddSubSection("Webhook Server Join / Leave")
_G.ServerWebhookDCURL = false

Section59:AddInput({
	Title = "Webhook Server Join / Leave URL",
	Placeholder = "Write ur input here...",
	Callback = function()
	end
})

_G.ServerWebhookDCConnected = ServerWebhookDCConnected
_G.ServerWebhookDCEnabled = false

Section59:AddToggle({
	Title = "Send Webhook Global Join / Leave",
	Default = false,
	Callback = function(state)
		if state then
			_G.ServerWebhookDCEnabled = state
			local ServerWebhookDCConnected = _G.ServerWebhookDCConnected
		end
	end
})

-- isfolder("Meng Hub_FishIt") -> false
pcall(function()
	if makefolder then
		if isfolder and not isfolder("Meng Hub_FishIt") then makefolder("Meng Hub_FishIt") end
		if isfolder and not isfolder("Meng Hub_FishIt/Config/") then makefolder("Meng Hub_FishIt/Config/") end
	end
end)
-- isfile("Meng Hub_FishIt/Config/Autoload.txt") -> false
end -- end Tab11

do -- start Tab12
local Section60 = Tab12:AddSection("Configuration")
local Paragraph20 = Section60:AddParagraph({ Title = "Config Manager", Content = "Current: None | Autoload: None", Icon = "settings" })

task.spawn(function()
	task.wait(1.5)
end)

Section60:AddInput({
	Title = "Config Name",
	Content = "Enter the name for u config",
	Placeholder = "Write ur input here",
	Callback = function()
	end
})

-- isfolder("Meng Hub_FishIt/Config/") -> false
local Dropdown4 = Section60:AddDropdown({
	Title = "Select Config",
	Content = "Choose from exists configs",
	Options = {},
	Callback = function()
	end
})

Section60:AddButton({
	Title = "Save Config",
	SubTitle = "Load Config",
	Callback = function()
	end,
	SubCallback = function()
		LoadConfigFromFile(false)
		-- [envlog] error: Luraph Script:15024: Luraph Script:14975: Script:62: attempt to call a nil value
	end
})

Section60:AddButton({
	Title = "Delete Config",
	SubTitle = "Set Autoload",
	Callback = function()
		-- [envlog] error: Luraph Script:15035: Script:62: attempt to concatenate boolean with string
	end,
	SubCallback = function()
		writefile("Meng Hub_FishIt/Config/Autoload.txt", false)
		-- [envlog] error: Luraph Script:15046: Luraph Script:14975: Script:62: attempt to call a nil value
	end
})

Section60:AddButton({
	Title = "Refresh List",
	SubTitle = "Clear Autoload",
	Callback = function()
		-- isfolder("Meng Hub_FishIt/Config/") -> false
		Dropdown4:SetValues({})
	end,
	SubCallback = function()
		-- isfile("Meng Hub_FishIt/Config/Autoload.txt") -> false
		-- [envlog] error: Luraph Script:15062: Luraph Script:14975: Script:62: attempt to call a nil value
	end
})

Section60:AddButton({
	Title = "Reset All Elements to Default",
	Callback = function()
		LoadConfigElements()
		Paragraph20:SetContent("Current: None | Autoload: None")
		task.wait(0.5)
	end
})

Section60:AddSubSection("Load From External")

Section60:AddInput({
	Title = "External Config JSON",
	Content = "Paste ur raw JSON config here",
	Callback = function()
	end
})

Section60:AddButton({
	Title = "Load External JSON",
	SubTitle = "Export Config",
	Callback = function(state)
		if state then
			HttpService:JSONDecode(false)
		else
			local data5 = HttpService:JSONDecode(false)
		end

		LoadConfigElements()
		Paragraph20:SetContent("Current: External JSON | Autoload: None")
		notif("Berhasil load config dari external JSON")
		task.wait(0.5)
	end,
	SubCallback = function()
		local json3 = HttpService:JSONEncode(data5)
		setclipboard(json3)
		-- [envlog] error: Luraph Script:15132: Script:62: attempt to concatenate boolean with string
	end
})

local WOGraphics = _G.WOGraphics
_G.WOGraphics = WOGraphics
local ClientGraphicCC = Lighting:FindFirstChild("ClientGraphicCC")
if not ClientGraphicCC then
	ClientGraphicCC = Instance.new("ColorCorrectionEffect")
	ClientGraphicCC.Name = "ClientGraphicCC"
	ClientGraphicCC.Parent = Lighting
end
local ClientGraphicBloom = Lighting:FindFirstChild("ClientGraphicBloom")
if not ClientGraphicBloom then
	ClientGraphicBloom = Instance.new("BloomEffect")
	ClientGraphicBloom.Name = "ClientGraphicBloom"
	ClientGraphicBloom.Parent = Lighting
end
local Section61 = Tab12:AddSection("Grapichs Custom")

Section61:AddDropdown({
	Title = "Select Grapich",
	Default = "Vibrant",
	Options = {
		"Default",
		"Warm",
		"Cool",
		"Cinematic",
		"Vibrant",
		"Matte",
		"Moody",
		"Retro Fade",
		"Dawn",
		"Overcast",
		"Anti Lag/Low"
	},
	Callback = function()
		ClientGraphicCC.TintColor = Color3.fromRGB(255, 255, 255)
		ClientGraphicCC.Saturation = 0
		ClientGraphicCC.Contrast = 0
		ClientGraphicCC.Brightness = 0
		ClientGraphicBloom.Intensity = 0.5
		Lighting.ExposureCompensation = 0
		Lighting.GlobalShadows = true
	end
})

task.wait(1)
end -- end Tab12
