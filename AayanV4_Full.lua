--// THE KING'S V3 - FULL SCRIPT (premium GUI + INFO tab)
--// ROBLOX LOCAL SCRIPT

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TextChatService = game:GetService("TextChatService")
local StatsService = game:GetService("Stats")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

--==================================================
-- CHARACTER HELPERS
--==================================================

local function getCharacter()
	return player.Character or player.CharacterAdded:Wait()
end

local function getRoot()
	local character = getCharacter()
	return character:FindFirstChild("HumanoidRootPart")
end

local function getHum()
	local character = getCharacter()
	return character:FindFirstChildOfClass("Humanoid")
end

--==================================================
-- CONFIG
--==================================================

local Config = {
	AntiVoid = false,
	AntiFling = false,
	AntiSit = false,
	Spd = false,
	Spin = false,
	InfJump = false,
	CurrentTroll = nil
}

--==================================================
-- THEME + SHARED HELPERS
--==================================================

local Theme = {
	Cyan = Color3.fromRGB(0, 200, 255),
	Blue = Color3.fromRGB(0, 170, 255),
	Purple = Color3.fromRGB(160, 60, 255),
	Pink = Color3.fromRGB(235, 60, 255),
	Navy = Color3.fromRGB(14, 16, 38),
	NavyLight = Color3.fromRGB(26, 34, 78),
	NavyHover = Color3.fromRGB(38, 52, 112),
	NavyActive = Color3.fromRGB(70, 44, 150),
	Muted = Color3.fromRGB(160, 165, 205),
	Text = Color3.fromRGB(245, 247, 255)
}

local function addGradient(parent, c0, c1, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c0, c1)
	g.Rotation = rotation or 0
	g.Parent = parent
	return g
end

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(
		obj,
		TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

-- Scale that keeps the GUI usable on small phone screens
local function viewScale()
	local cam = workspace.CurrentCamera
	if not cam then return 1 end
	local v = cam.ViewportSize
	return math.clamp(math.min(v.Y / 420, v.X / 440), 0.55, 1)
end

-- Border stroke with a cyan -> purple gradient (stroke gradients do not tint text)
local function borderStroke(parent, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 1.5
	s.Transparency = transparency or 0
	s.Color = Color3.new(1, 1, 1)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	local g = addGradient(s, Theme.Cyan, Theme.Purple, 0)
	return s, g
end

--==================================================
-- CLEAN OLD GUI
--==================================================

local old = PlayerGui:FindFirstChild("AAYAN_PAPA_SPECIAL")
if old then
	old:Destroy()
end

local sg = Instance.new("ScreenGui")
sg.Name = "AAYAN_PAPA_SPECIAL"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = PlayerGui

-- connections that must be cleaned when the GUI is destroyed
local Cleanup = {}
sg.Destroying:Connect(function()
	for _, c in ipairs(Cleanup) do
		pcall(function() c:Disconnect() end)
	end
	local leftoverBlur = Lighting:FindFirstChild("KINGS_V3_BLUR")
	if leftoverBlur then leftoverBlur:Destroy() end
end)

--==================================================
-- DRAG FUNCTION
--==================================================

local function makeDraggable(frame)
	local dragging = false
	local dragStart
	local startPos

	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then

			dragging = true
			dragStart = input.Position
			startPos = frame.Position

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	table.insert(Cleanup, UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end

		if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then

			local delta = input.Position - dragStart

			frame.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end))
end

--==================================================
-- AVATAR THUMBNAIL (real avatar of the local player)
--==================================================

local avatarImage = ""
do
	local ok, img = pcall(function()
		return Players:GetUserThumbnailAsync(
			player.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size150x150
		)
	end)
	if ok and img and img ~= "" then
		avatarImage = img
	else
		avatarImage = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
	end
end

--==================================================
-- INTRO: NAME -> GANG -> TARGET (3 GUIs)
--==================================================

local playerName, gangName, targetName

do
	local oldSetup = PlayerGui:FindFirstChild("KINGS_V3_SETUP")
	if oldSetup then oldSetup:Destroy() end
	local oldBlur = Lighting:FindFirstChild("KINGS_V3_BLUR")
	if oldBlur then oldBlur:Destroy() end

	local setupGui = Instance.new("ScreenGui")
	setupGui.Name = "KINGS_V3_SETUP"
	setupGui.ResetOnSpawn = false
	setupGui.IgnoreGuiInset = true
	setupGui.DisplayOrder = 500
	setupGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	setupGui.Parent = PlayerGui

	local blur = Instance.new("BlurEffect")
	blur.Name = "KINGS_V3_BLUR"
	blur.Size = 0
	blur.Parent = Lighting

	setupGui.Destroying:Connect(function()
		if blur and blur.Parent then blur:Destroy() end
	end)

	local FIELD = Color3.fromRGB(22, 24, 54)

	local function runStep(heading, subtitle, placeholder, iconText, buttonText)
		local result = nil
		local submitted = false
		local finished = Instance.new("BindableEvent")

		-- CanvasGroup used only for fading. NO gradient on the group itself
		-- (a UIGradient on a CanvasGroup tints everything inside = black GUI).
		local card = Instance.new("CanvasGroup")
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.new(0.5, 0, 0.5, 0)
		card.Size = UDim2.new(0, 360, 0, 330)
		card.BackgroundTransparency = 1
		card.BorderSizePixel = 0
		card.GroupTransparency = 1
		card.Parent = setupGui

		local scale = Instance.new("UIScale")
		scale.Scale = viewScale() * 0.85
		scale.Parent = card

		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 20)

		local cardStroke, cardStrokeGrad = borderStroke(card, 2.5, 0)

		local bg = Instance.new("Frame")
		bg.Name = "Bg"
		bg.Size = UDim2.new(1, 0, 1, 0)
		bg.BackgroundColor3 = Color3.new(1, 1, 1)
		bg.BackgroundTransparency = 0.08
		bg.BorderSizePixel = 0
		bg.ZIndex = 1
		bg.Parent = card
		addGradient(bg, Color3.fromRGB(18, 20, 52), Color3.fromRGB(10, 10, 28), 90)

		local ring = Instance.new("Frame")
		ring.AnchorPoint = Vector2.new(0.5, 0)
		ring.Position = UDim2.new(0.5, 0, 0, 18)
		ring.Size = UDim2.new(0, 84, 0, 84)
		ring.BackgroundColor3 = Color3.fromRGB(16, 30, 80)
		ring.BorderSizePixel = 0
		ring.ZIndex = 3
		ring.Parent = card
		Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
		local _, ringGrad = borderStroke(ring, 3, 0)

		local avatar = Instance.new("ImageLabel")
		avatar.AnchorPoint = Vector2.new(0.5, 0.5)
		avatar.Position = UDim2.new(0.5, 0, 0.5, 0)
		avatar.Size = UDim2.new(1, -10, 1, -10)
		avatar.BackgroundTransparency = 1
		avatar.Image = avatarImage
		avatar.ScaleType = Enum.ScaleType.Crop
		avatar.ZIndex = 4
		avatar.Parent = ring
		Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)

		local head = Instance.new("TextLabel")
		head.AnchorPoint = Vector2.new(0.5, 0)
		head.Position = UDim2.new(0.5, 0, 0, 112)
		head.Size = UDim2.new(1, -30, 0, 34)
		head.BackgroundTransparency = 1
		head.Text = heading
		head.TextColor3 = Color3.new(1, 1, 1)
		head.Font = Enum.Font.GothamBlack
		head.TextScaled = true
		head.ZIndex = 3
		head.Parent = card
		local headLimit = Instance.new("UITextSizeConstraint")
		headLimit.MaxTextSize = 24
		headLimit.MinTextSize = 12
		headLimit.Parent = head
		addGradient(head, Color3.fromRGB(80, 220, 255), Color3.fromRGB(240, 130, 255), 0)

		local sub = Instance.new("TextLabel")
		sub.AnchorPoint = Vector2.new(0.5, 0)
		sub.Position = UDim2.new(0.5, 0, 0, 148)
		sub.Size = UDim2.new(1, -40, 0, 18)
		sub.BackgroundTransparency = 1
		sub.Text = subtitle
		sub.TextColor3 = Theme.Muted
		sub.Font = Enum.Font.Gotham
		sub.TextSize = 13
		sub.ZIndex = 3
		sub.Parent = card

		local field = Instance.new("Frame")
		field.AnchorPoint = Vector2.new(0.5, 0)
		field.Position = UDim2.new(0.5, 0, 0, 182)
		field.Size = UDim2.new(1, -40, 0, 44)
		field.BackgroundColor3 = FIELD
		field.BorderSizePixel = 0
		field.ZIndex = 3
		field.Parent = card
		Instance.new("UICorner", field).CornerRadius = UDim.new(0, 12)
		local fieldStroke = Instance.new("UIStroke")
		fieldStroke.Thickness = 1.5
		fieldStroke.Color = Color3.fromRGB(110, 80, 230)
		fieldStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		fieldStroke.Parent = field

		local icon = Instance.new("TextLabel")
		icon.Position = UDim2.new(0, 10, 0, 0)
		icon.Size = UDim2.new(0, 28, 1, 0)
		icon.BackgroundTransparency = 1
		icon.Text = iconText
		icon.TextSize = 18
		icon.TextColor3 = Theme.Muted
		icon.Font = Enum.Font.GothamBold
		icon.ZIndex = 4
		icon.Parent = field

		local box = Instance.new("TextBox")
		box.Position = UDim2.new(0, 42, 0, 0)
		box.Size = UDim2.new(1, -52, 1, 0)
		box.BackgroundTransparency = 1
		box.PlaceholderText = placeholder
		box.PlaceholderColor3 = Color3.fromRGB(150, 155, 195)
		box.Text = ""
		box.TextColor3 = Color3.new(1, 1, 1)
		box.Font = Enum.Font.GothamMedium
		box.TextSize = 15
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.ClearTextOnFocus = false
		box.ClipsDescendants = true
		box.ZIndex = 4
		box.Parent = field

		-- solid button colour (gradient would tint the text); gradient lives on the stroke
		local button = Instance.new("TextButton")
		button.AnchorPoint = Vector2.new(0.5, 0)
		button.Position = UDim2.new(0.5, 0, 0, 242)
		button.Size = UDim2.new(1, -40, 0, 46)
		button.BackgroundColor3 = Color3.fromRGB(40, 100, 235)
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		button.Text = buttonText .. "  →"
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Font = Enum.Font.GothamBlack
		button.TextSize = 17
		button.ZIndex = 3
		button.Parent = card
		Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)
		borderStroke(button, 1.8, 0)

		local hint = Instance.new("TextLabel")
		hint.AnchorPoint = Vector2.new(0.5, 0)
		hint.Position = UDim2.new(0.5, 0, 0, 298)
		hint.Size = UDim2.new(1, -40, 0, 18)
		hint.BackgroundTransparency = 1
		hint.Text = "Press Enter to continue"
		hint.TextColor3 = Theme.Muted
		hint.Font = Enum.Font.Gotham
		hint.TextSize = 12
		hint.ZIndex = 3
		hint.Parent = card

		local close = Instance.new("TextButton")
		close.Position = UDim2.new(1, -38, 0, 10)
		close.Size = UDim2.new(0, 28, 0, 28)
		close.BackgroundColor3 = FIELD
		close.Text = "✕"
		close.TextColor3 = Color3.new(1, 1, 1)
		close.Font = Enum.Font.GothamBold
		close.TextSize = 14
		close.AutoButtonColor = false
		close.ZIndex = 5
		close.Parent = card
		Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)
		local closeStroke = Instance.new("UIStroke")
		closeStroke.Thickness = 1
		closeStroke.Color = Color3.fromRGB(100, 100, 170)
		closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		closeStroke.Parent = close

		local alive = true
		task.spawn(function()
			local rot = 0
			while alive and card.Parent do
				rot = (rot + 2) % 360
				cardStrokeGrad.Rotation = rot
				ringGrad.Rotation = -rot
				task.wait(0.03)
			end
		end)

		button.MouseEnter:Connect(function()
			tween(button, 0.15, { BackgroundColor3 = Color3.fromRGB(70, 130, 255) })
		end)
		button.MouseLeave:Connect(function()
			tween(button, 0.15, { BackgroundColor3 = Color3.fromRGB(40, 100, 235) })
		end)
		button.MouseButton1Down:Connect(function()
			tween(button, 0.08, { BackgroundColor3 = Color3.fromRGB(110, 60, 220) })
		end)
		box.Focused:Connect(function()
			tween(fieldStroke, 0.2, { Color = Color3.fromRGB(0, 210, 255) })
		end)
		box.FocusLost:Connect(function()
			tween(fieldStroke, 0.2, { Color = Color3.fromRGB(110, 80, 230) })
		end)

		tween(blur, 0.5, { Size = 14 })
		tween(card, 0.45, { GroupTransparency = 0 })
		tween(scale, 0.5, { Scale = viewScale() }, Enum.EasingStyle.Back)

		local function closeCard(value)
			if submitted then return end
			submitted = true
			result = value
			alive = false
			tween(card, 0.3, { GroupTransparency = 1 })
			local out = tween(scale, 0.3, { Scale = viewScale() * 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			out.Completed:Wait()
			card:Destroy()
			finished:Fire()
		end

		local function shake()
			local origin = field.Position
			for _, dx in ipairs({ 8, -8, 5, -5, 0 }) do
				field.Position = origin + UDim2.new(0, dx, 0, 0)
				task.wait(0.03)
			end
			field.Position = origin
		end

		local function trySubmit()
			if submitted then return end
			local text = box.Text:gsub("^%s+", ""):gsub("%s+$", "")
			if text == "" then
				tween(fieldStroke, 0.1, { Color = Color3.fromRGB(255, 80, 100) })
				task.spawn(shake)
				box.PlaceholderText = "This field can't be empty"
				task.delay(0.8, function()
					if not submitted then
						tween(fieldStroke, 0.2, { Color = Color3.fromRGB(110, 80, 230) })
						box.PlaceholderText = placeholder
					end
				end)
				return
			end
			task.spawn(closeCard, text)
		end

		button.Activated:Connect(trySubmit)
		box.FocusLost:Connect(function(enterPressed)
			if enterPressed then trySubmit() end
		end)
		close.Activated:Connect(function()
			task.spawn(closeCard, nil)
		end)

		finished.Event:Wait()
		finished:Destroy()
		return result
	end

	local function showStatus(text, good)
		local toast = Instance.new("CanvasGroup")
		toast.AnchorPoint = Vector2.new(0.5, 0)
		toast.Position = UDim2.new(0.5, 0, 0, -60)
		toast.Size = UDim2.new(0, 300, 0, 48)
		toast.BackgroundColor3 = Color3.fromRGB(14, 16, 38)
		toast.BorderSizePixel = 0
		toast.GroupTransparency = 1
		toast.Parent = setupGui
		Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 14)
		local s = Instance.new("UIStroke")
		s.Thickness = 2
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Color = good and Color3.fromRGB(0, 255, 170) or Color3.fromRGB(255, 170, 60)
		s.Parent = toast
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, -16, 1, 0)
		l.Position = UDim2.new(0, 8, 0, 0)
		l.BackgroundTransparency = 1
		l.Text = text
		l.TextColor3 = Color3.new(1, 1, 1)
		l.Font = Enum.Font.GothamBold
		l.TextSize = 14
		l.TextWrapped = true
		l.Parent = toast

		tween(toast, 0.4, { Position = UDim2.new(0.5, 0, 0, 30), GroupTransparency = 0 }, Enum.EasingStyle.Back)
		task.delay(4, function()
			local out = tween(toast, 0.4, { Position = UDim2.new(0.5, 0, 0, -60), GroupTransparency = 1 })
			out.Completed:Wait()
			toast:Destroy()
			if setupGui and setupGui.Parent then
				setupGui:Destroy()
			end
		end)
	end

	local function getChannel()
		if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
			return nil
		end
		local channels = TextChatService:FindFirstChild("TextChannels")
		if not channels then
			channels = TextChatService:WaitForChild("TextChannels", 5)
		end
		if not channels then return nil end
		return channels:FindFirstChild("RBXGeneral") or channels:WaitForChild("RBXGeneral", 5)
	end

	local function sendChat(channel, message)
		if not channel then return false end
		local ok, err = pcall(function()
			channel:SendAsync(message)
		end)
		if not ok then
			warn("[V3] Chat message failed: " .. tostring(err))
		end
		return ok
	end

	playerName = runStep("ENTER YOUR NAME", "Your name will be used in the script", "Enter your name...", "👤", "ENTER")
	if playerName then
		gangName = runStep("ENTER YOUR GANG NAME", "Your gang name will be used in the script", "Enter your gang name...", "👥", "ENTER")
	end
	if gangName then
		targetName = runStep("ENTER YOUR TARGET NAME", "Type the name you want to mention", "Enter target name...", "🎯", "ENTER")
	end

	local blurOut = tween(blur, 0.5, { Size = 0 })
	blurOut.Completed:Connect(function()
		if blur and blur.Parent then blur:Destroy() end
	end)

	if not (playerName and gangName and targetName) then
		-- setup was closed: stop the script cleanly
		task.delay(0.6, function()
			setupGui:Destroy()
			sg:Destroy()
		end)
		return
	end

	local channel = getChannel()

	local sent1 = sendChat(
		channel,
		"SCRIPT BY " .. playerName .. " _________________________THE KING'S V3 IS HERE_________________________MADE BY " .. playerName .. "___V3 LOADED"
	)

	task.wait(2)

	local sent2 = sendChat(
		channel,
		"THE FATHER OF " .. targetName .. " TERA BAP AGYA 🥰😭 ___" .. gangName .. " ON TOP"
	)

	if sent1 and sent2 then
		showStatus("V3 LOADED  •  by " .. playerName, true)
	else
		showStatus("V3 LOADED  •  by " .. playerName .. "  (chat message not sent)", false)
	end
end

--==================================================
-- MAIN GUI
-- CanvasGroup (for fade) + background frame child.
-- The gradient is on the background frame, never on the group.
--==================================================

local Main = Instance.new("CanvasGroup", sg)

Main.Name = "MainWindow"
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.Size = UDim2.new(0,420,0,340)
Main.Position = UDim2.new(.5,0,.5,0)

Main.BackgroundTransparency = 1
Main.BorderSizePixel = 0
Main.Active = true
Main.ZIndex = 10
Main.Visible = false
Main.GroupTransparency = 1

Instance.new("UICorner",Main).CornerRadius = UDim.new(0,16)

local MainScale = Instance.new("UIScale", Main)
MainScale.Scale = viewScale() * 0.9

makeDraggable(Main)

local MainBg = Instance.new("Frame", Main)
MainBg.Name = "Bg"
MainBg.Size = UDim2.new(1,0,1,0)
MainBg.BackgroundColor3 = Color3.new(1,1,1)
MainBg.BackgroundTransparency = 0.1
MainBg.BorderSizePixel = 0
MainBg.ZIndex = 1
addGradient(MainBg, Color3.fromRGB(16,20,50), Color3.fromRGB(26,12,56), 60)

--==================================================
-- MAIN BORDER (cyan -> purple, slowly rotating)
--==================================================

local MainStroke, MainStrokeGrad = borderStroke(Main, 2.5, 0)

task.spawn(function()

	local rot = 0

	while Main.Parent do

		rot = (rot + 1.5) % 360
		MainStrokeGrad.Rotation = rot

		task.wait(.03)
	end

end)

--==================================================
-- TITLE
--==================================================

local Title = Instance.new("TextLabel",Main)

Title.Size = UDim2.new(1,-20,0,34)
Title.Position = UDim2.new(0,10,0,5)

Title.BackgroundTransparency = 1
Title.Text = "[ AAYAN V2 ]"

Title.Font = Enum.Font.GothamBlack
Title.TextSize = 20
Title.TextXAlignment = Enum.TextXAlignment.Center

Title.ZIndex = 12

task.spawn(function()

	local h = 0

	while Title.Parent do

		h = (h + .008) % 1

		Title.TextColor3 =
			Color3.fromHSV(h,.7,1)

		task.wait(.02)
	end

end)

--==================================================
-- SUB TITLE
--==================================================

local SubTitle = Instance.new("TextLabel",Main)

SubTitle.Size = UDim2.new(1,-20,0,20)
SubTitle.Position = UDim2.new(0,10,0,37)

SubTitle.BackgroundTransparency = 1
SubTitle.RichText = true

SubTitle.Text =
'<font color="#FFD700">WELCOME TO</font> <font color="#FF2D55">AAYAB HUB V2 </font> 💀😼'

SubTitle.Font = Enum.Font.GothamBold
SubTitle.TextSize = 11

SubTitle.ZIndex = 12

--==================================================
-- SIDEBAR
--==================================================

local Sidebar = Instance.new("ScrollingFrame",Main)

Sidebar.Size = UDim2.new(0,125,1,-70)
Sidebar.Position = UDim2.new(0,10,0,60)

Sidebar.BackgroundColor3 = Color3.fromRGB(8,10,28)
Sidebar.BackgroundTransparency = .25
Sidebar.BorderSizePixel = 0

Sidebar.ScrollBarThickness = 2
Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
Sidebar.CanvasSize = UDim2.new(0,0,0,0)

Sidebar.ZIndex = 11

Instance.new("UICorner",Sidebar).CornerRadius = UDim.new(0,12)

local SideStroke = Instance.new("UIStroke",Sidebar)
SideStroke.Thickness = 1
SideStroke.Color = Theme.Cyan
SideStroke.Transparency = 0.5
SideStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local SideList = Instance.new("UIListLayout",Sidebar)

SideList.Padding = UDim.new(0,5)
SideList.HorizontalAlignment =
Enum.HorizontalAlignment.Center

local SidePadding = Instance.new("UIPadding",Sidebar)

SidePadding.PaddingTop = UDim.new(0,6)
SidePadding.PaddingBottom = UDim.new(0,6)

--==================================================
-- PAGES
--==================================================

local Pages = Instance.new("Frame",Main)
Pages.Size = UDim2.new(1,-160,1,-70)
Pages.Position = UDim2.new(0,148,0,60)
Pages.BackgroundTransparency = 1
Pages.ZIndex = 11

local function createPage()
	local p = Instance.new("ScrollingFrame",Pages)

	p.Size = UDim2.new(1,0,1,0)
	p.BackgroundTransparency = 1
	p.BorderSizePixel = 0
	p.Visible = false
	p.ScrollBarThickness = 3
	p.AutomaticCanvasSize = Enum.AutomaticSize.Y
	p.CanvasSize = UDim2.new(0,0,0,0)
	p.ZIndex = 11

	local layout = Instance.new("UIListLayout",p)
	layout.Padding = UDim.new(0,8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	return p
end

local P1 = createPage()
local P2 = createPage()
local P3 = createPage()
local P4 = createPage()
local P5 = createPage()
local P6 = createPage()
local P7 = createPage()
local P8 = createPage()
local P9 = createPage()
local P10 = createPage()
local P11 = createPage()
local P12 = createPage()
local P13 = createPage() -- INFO

--==================================================
-- TAB FUNCTION
--==================================================

local activeTab = nil

local function setTabLook(b, mode)
	if mode == "active" then
		tween(b, 0.15, { BackgroundColor3 = Theme.NavyActive })
	elseif mode == "hover" then
		tween(b, 0.15, { BackgroundColor3 = Theme.NavyHover })
	else
		tween(b, 0.15, { BackgroundColor3 = Theme.NavyLight })
	end
end

local function tab(name, page)
	local b = Instance.new("TextButton", Sidebar)

	b.Size = UDim2.new(1, -8, 0, 38)
	b.BackgroundColor3 = Theme.NavyLight
	b.BorderSizePixel = 0
	b.Text = name
	b.TextColor3 = Theme.Text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextWrapped = true
	b.ZIndex = 15
	b.AutoButtonColor = false

	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	borderStroke(b, 1.3, 0.2)

	b.MouseEnter:Connect(function()
		if activeTab ~= b then setTabLook(b, "hover") end
	end)

	b.MouseLeave:Connect(function()
		if activeTab ~= b then setTabLook(b, "normal") end
	end)

	b.MouseButton1Click:Connect(function()
		for _, v in ipairs(Pages:GetChildren()) do
			if v:IsA("ScrollingFrame") then
				v.Visible = false
			end
		end

		if activeTab and activeTab ~= b then
			setTabLook(activeTab, "normal")
		end
		activeTab = b
		setTabLook(b, "active")

		page.Visible = true
	end)

	return b
end

--==================================================
-- BUTTON FUNCTION
--==================================================

local function btn(text, parent, callback)
	local b = Instance.new("TextButton")
	b.Parent = parent
	b.Size = UDim2.new(1, -10, 0, 38)
	b.BackgroundColor3 = Theme.NavyLight
	b.BackgroundTransparency = 0
	b.BorderSizePixel = 0

	b.Text = text
	b.TextColor3 = Theme.Text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextWrapped = true
	b.AutoButtonColor = false
	b.ZIndex = 15

	local corner = Instance.new("UICorner", b)
	corner.CornerRadius = UDim.new(0, 8)

	local stroke = borderStroke(b, 1.3, 0.15)

	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.15), {
			BackgroundColor3 = Theme.NavyHover
		}):Play()

		TweenService:Create(stroke, TweenInfo.new(0.15), {
			Thickness = 2
		}):Play()
	end)

	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.15), {
			BackgroundColor3 = Theme.NavyLight
		}):Play()

		TweenService:Create(stroke, TweenInfo.new(0.15), {
			Thickness = 1.3
		}):Play()
	end)

	b.MouseButton1Down:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.07), {
			BackgroundColor3 = Theme.NavyActive
		}):Play()
	end)

	b.MouseButton1Up:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), {
			BackgroundColor3 = Theme.NavyHover
		}):Play()
	end)

	if typeof(callback) == "function" then
		b.MouseButton1Click:Connect(function()
			callback(b)
		end)
	end

	return b
end


--==================================================
-- TABS
--==================================================

tab("PANEL 💀",P1)
tab("SPAMMER 🌀",P2)
tab("OTHER ☣",P3)
tab("SHIELD 🤖",P4)
tab("VOIDOUT 🗿",P5)
tab("DJ SYSTEM 🎶",P6)
tab("fun💥",P7)
tab("ALPHA EMPIRE ⛩️",P8)
tab("MINI GAMES 🎮",P9)
tab("OWNER 🚩",P10)
tab("NOTE 🔷",P11)
tab("SPECIAL 💖",P12)
tab("INFO 📊",P13)

--==================================================
-- ADD HERE P1
--==================================================
P1.Visible = true
do
	-- highlight the first tab (PANEL) as active
	local first
	for _, v in ipairs(Sidebar:GetChildren()) do
		if v:IsA("TextButton") then first = v break end
	end
	if first then
		activeTab = first
		first.BackgroundColor3 = Theme.NavyActive
	end
end

local targetBox = Instance.new("TextBox", P1)
targetBox.Size = UDim2.new(1, -8, 0, 36)
targetBox.PlaceholderText = "⚡ Enter Target Name..."
targetBox.PlaceholderColor3 = Color3.fromRGB(150, 155, 195)
targetBox.Text = ""
targetBox.BackgroundColor3 = Color3.fromRGB(22, 24, 54)
targetBox.TextColor3 = Theme.Text
targetBox.Font = Enum.Font.GothamMedium
targetBox.TextSize = 13
targetBox.ClearTextOnFocus = false
targetBox.ZIndex = 15
Instance.new("UICorner", targetBox).CornerRadius = UDim.new(0, 8)
local targetStroke = Instance.new("UIStroke", targetBox)
targetStroke.Color = Theme.Cyan
targetStroke.Thickness = 1.3
targetStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local function getT()
	local n = targetBox.Text:lower()
	if n == "" then return nil end
	for _, v in pairs(Players:GetPlayers()) do
		if v ~= player and (v.Name:lower():find(n) or v.DisplayName:lower():find(n)) then return v end
	end
end

--==================================================
-- YOU WILL ADD HERE
-- (the troll-mode function startTroll(mode) goes here)
--==================================================

btn("GO TO 👤", P1, function()
	local t = getT()
	local root = getRoot()
	if t and t.Character and t.Character:FindFirstChild("HumanoidRootPart") and root then
		root.CFrame = t.Character.HumanoidRootPart.CFrame
	end
end)

btn("🚀 GOTO", P1, function()
	local t = getT()
	if t and t.Character and t.Character.HumanoidRootPart then
		pcall(function()
			player.Character.HumanoidRootPart.CFrame = t.Character.HumanoidRootPart.CFrame
		end)
	end
end)

-- YOU WILL ADD HERE  (FACE button)

btn("SPECTATE 👁️", P1, function()
	local t = getT()
	if t and t.Character and t.Character:FindFirstChildOfClass("Humanoid") then
		workspace.CurrentCamera.CameraSubject = t.Character:FindFirstChildOfClass("Humanoid")
	end
end)

-- YOU WILL ADD HERE  (fun⚠️ button)
-- YOU WILL ADD HERE  (HEADSIT button)
-- YOU WILL ADD HERE  (FRONT SIT button)
-- YOU WILL ADD HERE  (FRONT HEADSIT button)
-- YOU WILL ADD HERE  (ANNOY button)

btn("STOP TROLL 💢", P1, function()
	Config.CurrentTroll = nil
	_G.Loop = false
	local hum = getHum()
	if hum then
		hum.Sit = false
		workspace.CurrentCamera.CameraSubject = hum
	end
end)

--==================================================
-- P2
--==================================================

btn("CUSTOM SPAM 😎👺",P2,function()
	loadstring(game:HttpGet(
		"https://pastebin.com/raw/FVLWdWWy"
	))()
end)

btn("ROAST SPAM 💢🤬",P2,function()
	loadstring(game:HttpGet(
		"https://pastebin.com/raw/crWrmZMT"
	))()
end)
btn("ULTIMATE SPAM 💥⚠️",P2,function()
	loadstring(game:HttpGet(
		"https://pastebin.com/raw/BKt9y40g"
	))()
end)
btn("ALPHA EMPIRE ⛩️😼",P2,function()
	loadstring(game:HttpGet(
		"https://pastebin.com/raw/Bm3p4tnh"
	))()
end)
btn("FORBID 🚫☣️",P2,function()
	loadstring(game:HttpGet(
		"https://gist.githubusercontent.com/forbidtherobloxscripter/3e1a67cdf3f22192307218825c8469ea/raw/d16fabac096433b08eb63170274af33c8345603e/fm%25201.5.txt"
	))()
end)



--==================================================
-- P3
--==================================================


btn("😋 AAYAN EMOTE", P3, function()
	loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-7yd7-I-Emote-Script-48024"))()
end)

btn("🚀 INF JUMP: OFF", P3, function(self)
	Config.InfJump = not Config.InfJump
	self.Text = "🚀 INF JUMP: " .. (Config.InfJump and "ON" or "OFF")
end)

btn("🏃 SPEED 300", P3, function(self)
	Config.Spd = not Config.Spd

	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")

	if hum then
		hum.WalkSpeed = Config.Spd and 300 or 16
	end

	self.Text = "🏃 SPEED 300: " .. (Config.Spd and "ON" or "OFF")
end)

btn("𫯯 SPIN 300", P3, function() Config.Spin = not Config.Spin end)

btn("💃 COPY EMOTE AND MORE", P3, function()
	loadstring(game:HttpGet("https://rawscripts.net/raw/Ro-vibes-ROVibes-95220"))()
end)

btn("🪓 SKY DESTROYER", P3, function()
	loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-sky-destroyer-V2-AXEZZ-110640"))()
end)

btn("🧍‍♂️ STAND BY", P3, function()
	loadstring(game:HttpGet("https://pastebin.com/raw/10c0XURE"))()
end)

btn("🎈 HEADSTAND", P3, function()
	loadstring(game:HttpGet("https://pastebin.com/raw/1zxuPzS4"))()
end)

btn("🍁 GAZE EMOTES", P3, function()
	loadstring(game:HttpGet("https://raw.githubusercontent.com/Gazer-Ha/Gaze-stuff/refs/heads/main/Gaze%20emote"))()
end)

btn("🕊️ FLY CONTROLLER", P3, function()
	loadstring(game:HttpGet("https://pastebin.com/raw/6btVgzWN"))()
end)

btn("👻 NO CLIP", P3, function()
	loadstring(game:HttpGet("https://pastebin.com/raw/YW3XzdGD"))()
end)
--==================================================
-- P4
--==================================================
btn("👑 ANTI-VOID", P4, function(self)
	Config.AntiVoid = not Config.AntiVoid
	self.Text = "👑 ANTI-VOID: " .. (Config.AntiVoid and "ON" or "OFF")
end)

btn("🚫 ANTI-SIT", P4, function(self)
	Config.AntiSit = not Config.AntiSit
	self.Text = "🚫 ANTI-SIT: " .. (Config.AntiSit and "ON" or "OFF")
end)

btn("😴 ANTI-AFK", P4, function(self)
	Config.AntiAFK = not Config.AntiAFK
	self.Text = "😴 ANTI-AFK: " .. (Config.AntiAFK and "ON" or "OFF")
end)
btn("🔄 REVERSE FLING", P4, function() local hrp = player.Character.HumanoidRootPart; local s = Instance.new("BodyAngularVelocity", hrp); s.MaxTorque = Vector3.new(math.huge,math.huge,math.huge); s.AngularVelocity = Vector3.new(0,999999,0) end)
btn("🔥  ANTI-FLING", P4, function() for _,v in pairs(player.Character:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide = false end end end)

--==================================================
-- P5
--==================================================

btn("VOIDSTRIKER 🗿", P5, function() loadstring(game:HttpGet("https://pastebin.com/raw/c3R861CE"))() end)
btn("🪐 LOW GRAVITY", P5, function() workspace.Gravity = 15 end)
btn("🌌 ZERO GRAVITY", P5, function() workspace.Gravity = 0 end)
btn("🌍 NORMAL GRAVITY", P5, function() workspace.Gravity = 196.2 end)
btn("AURA GLOW 🌟", P5, function() loadstring(game:HttpGet("https://pastebin.com/raw/SEEgQyMg"))() end)
btn("PATROL👽", P5, function()
	loadstring(game:HttpGet("https://pastebin.com/raw/XhKJMEqj"))() end)
btn("FAKEOUT 🌚", P5, function() loadstring(game:HttpGet("https://pastebin.com/raw/67KEqzjv"))() end)
btn("TELEPORTER V1 👾", P5, function() loadstring(game:HttpGet("https://pastebin.com/raw/EUSknnAF"))() end)
btn("TELEPORTER V2 👾", P5, function() loadstring(game:HttpGet("https://pastebin.com/raw/216FSAFS"))() end)

-- YOU WILL ADD HERE  (UNIVERSAL BANG 3F button)

btn("TROLL ADMIN 🔥", P5, function() loadstring(game:HttpGet("https://pastebin.com/raw/ZnAdZPW1"))() end)
btn("INFINITE YEILD 🔲", P5, function() loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))() end)
btn("ULTIMATE ADMIN 🔥", P5, function() loadstring(game:HttpGet("https://raw.githubusercontent.com/Veaquach/kruel/refs/heads/main/kruel%20obf.txt"))() end)

--==================================================
-- P6
--==================================================

btn("🎵 DJ PLAYER",P6,function()
	loadstring(game:HttpGet(
		"https://pastefy.app/EZbyn0pl/raw"
	))()
end)

btn("funV1 💀", P7, function() loadstring(game:HttpGet("https://pastebin.com/raw/Gk24KYmb"))() end)
btn("fun V2💀", P7, function() loadstring(game:HttpGet("https://pastebin.com/raw/X73d41m6"))() end)
btn("fun 3 💀", P7, function() loadstring(game:HttpGet("https://pastebin.com/raw/TsLFDeKw"))() end)
btn("MULTI TARGET 💥🕷️", P7, function() loadstring(game:HttpGet("https://pastebin.com/raw/6f0Kfemd"))() end)
btn("HUB 🔥💢", P7, function() loadstring(game:HttpGet("https://pastebin.com/raw/EgVAYt7U"))() end)
btn("VOID WALKER ✨", P7, function() loadstring(game:HttpGet("https://pastefy.app/RdQmPLSO/raw"))() end)




--==================================================
-- P8
--==================================================

btn("ALPHA HISTORY 📜", P8, function() loadstring(game:HttpGet("https://pastefy.app/VlheRB4L/raw"))() end)
btn("JOIN EMPIRE ⛩️", P8, function() loadstring(game:HttpGet("https://pastefy.app/62LGo4kD/raw"))() end)
btn("VISIT ONCE 👀", P8, function() loadstring(game:HttpGet("https://pastebin.com/raw/2u9zqrk2"))() end)

--==================================================
-- P9
--==================================================

btn("TIC TAC TOE 🎮", P9, function() loadstring(game:HttpGet("https://pastebin.com/raw/ZYPzKzBF"))() end)
btn("JET DEFENDER ✈️", P9, function() loadstring(game:HttpGet("https://pastebin.com/raw/KEjtCtpP"))() end)
btn("CANDY BOM 💥", P9, function() loadstring(game:HttpGet("https://pastebin.com/raw/tTCmn7FS"))() end)
btn("FLAPPY BIRD 🐦", P9, function() loadstring(game:HttpGet("https://pastebin.com/raw/BNqYv7N6"))() end)
btn("CANDY CRUSH 🍭", P9, function() loadstring(game:HttpGet("https://pastebin.com/raw/gSW5NzsZ"))() end)


--==================================================
-- P10
--==================================================

local info = Instance.new("TextLabel", P10)

info.Size = UDim2.new(1,-5,1,0)
info.BackgroundTransparency = 1
info.TextSize = 16
info.Font = Enum.Font.GothamBold
info.TextWrapped = true
info.TextYAlignment = Enum.TextYAlignment.Top
info.TextXAlignment = Enum.TextXAlignment.Center
info.RichText = false

info.Text = [[
👑 ꜱᴄʀɪᴘᴛ ᴏᴡɴᴇʀ - 🗿ᴀᴀʏᴀɴ⛩️


📩 ʀᴏʙʟᴏx ɪᴅ -> AAYAN_ZZZZ

📩 ꜱɴᴀᴘᴄʜᴀᴛ ɪᴅ -> aayanzz123

ʀᴏʙʟᴏx ɪᴅ -> mr_king784(AE_MAX)


ʙɪʜᴀʀ ᴏɴ ᴛᴏᴘ 🚩

ᴜʟᴛɪᴍᴀᴛᴇ ʙᴀɴɢ ꜱᴄʀɪᴘᴛ💀😈

♣ ᴛʜᴀɴᴋ ʏᴏᴜ ꜰᴏʀ ᴜꜱᴇ ᴀᴀʏᴀɴ ᴠ2 ♠
]]

-- RGB TEXT
task.spawn(function()
	local h = 0

	while info.Parent do
		h = (h + 0.008) % 1
		info.TextColor3 = Color3.fromHSV(h, 0.8, 1)
		task.wait(0.02)
	end
end)

--==================================================
-- P11
--==================================================

local InfoFrame = Instance.new("Frame", P11)
InfoFrame.Size = UDim2.new(1,0,1,0)
InfoFrame.BackgroundTransparency = 1

local function AddInfoText(Text, Color, Size, Bold)
	local Label = Instance.new("TextLabel")
	Label.Parent = InfoFrame
	Label.Size = UDim2.new(1,-10,0,Size)
	Label.BackgroundTransparency = 1
	Label.Text = Text
	Label.TextColor3 = Color
	Label.TextSize = 15
	Label.Font = Bold and Enum.Font.GothamBold or Enum.Font.Gotham
	Label.TextWrapped = true
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.TextYAlignment = Enum.TextYAlignment.Center
	return Label
end

local Cyan = Color3.fromRGB(0,255,255)
local Purple = Color3.fromRGB(190,70,255)
local Red = Color3.fromRGB(255,70,90)
local White = Color3.fromRGB(240,240,245)

-- TITLE
local Title = AddInfoText(
	"⛩️ ᴡᴇʟᴄᴏᴍᴇ ᴛᴏ ᴀᴀʏᴀɴ ᴠ2 👑",
	Cyan,
	32,
	true
)
Title.Position = UDim2.new(0,5,0,5)

-- SUBTITLE
local SubTitle = AddInfoText(
	"ᴛʜᴇ ᴋᴇʏʟᴇꜱꜱ ꜱᴄʀɪᴘᴛ ʙʏ ᴀᴀʏᴀɴ 💀",
	Purple,
	28,
	true
)
SubTitle.Position = UDim2.new(0,5,0,38)

-- FEATURE TITLE
local FeatureTitle = AddInfoText(
	"✨ FEATURES ✨",
	Red,
	25,
	true
)
FeatureTitle.Position = UDim2.new(0,5,0,70)

-- FEATURES
local Features = AddInfoText(
	[[
🔷 ʙᴀɴɢ - ᴜʟᴛɪᴍᴀᴛᴇ ɢᴀᴍᴇᴘʟᴀʏ ꜰᴇᴀᴛᴜʀᴇ 👽

🛡️ ꜱʜɪᴇʟᴅ - ᴘʀᴏᴛᴇᴄᴛɪᴏɴ ꜰᴇᴀᴛᴜʀᴇꜱ ᴀɢᴀɪɴꜱᴛ ᴀᴛᴛᴀᴄᴋꜱ

🟣 ꜱᴘᴀᴍᴍᴇʀ - ꜰᴜɴ ᴄʜᴀᴛ & ᴍᴇꜱꜱᴀɢᴇ ꜰᴇᴀᴛᴜʀᴇꜱ 😂

🔴 ᴠᴏɪᴅᴏᴜᴛ - ʙᴀɴɢɢᴇʀ + ᴇxᴛʀᴀ ɢᴀᴍᴇ ꜰᴇᴀᴛᴜʀᴇꜱ

🎵 ᴅᴊ ꜱʏꜱᴛᴇᴍ - ᴇɴᴊᴏʏ ᴛʜᴇ ɢᴀᴍᴇ ᴡɪᴛʜ ᴍᴜꜱɪᴄ & ꜰᴜɴᴋ 💀

⛩️ ᴀʟᴘʜᴀ ᴇᴍᴘɪʀᴇ - ꜰᴇᴀᴛᴜʀᴇꜱ & ᴄᴏɴᴛᴇɴᴛ ᴀʙᴏᴜᴛ ᴀʟᴘʜᴀ ᴇᴍᴘɪʀᴇ

🎮 ᴍɪɴɪ ɢᴀᴍᴇ - ᴘʟᴀʏ ᴍɪɴɪ ɢᴀᴍᴇꜱ ᴡʜᴇɴ ʏᴏᴜ ɢᴇᴛ ʙᴏʀᴇᴅ 😋

🌚 ꜱᴘᴇᴄɪᴀʟ - ᴜʟᴛɪᴍᴀᴛᴇ ꜱᴘᴇᴄɪᴀʟ ꜰᴇᴀᴛᴜʀᴇꜱ

✨ ɪ ʜᴏᴘᴇ ʏᴏᴜ ʟɪᴋᴇ ᴀᴀʏᴀɴ ʜᴜʙ ᴠ2
]],
	White,
	205,
	false
)

Features.Position = UDim2.new(0,5,0,98)
Features.TextYAlignment = Enum.TextYAlignment.Top
Features.TextSize = 13

--// RGB FEATURE TEXT EFFECT
local Hue = 0

table.insert(Cleanup, RunService.RenderStepped:Connect(function()
	Hue = (Hue + 0.003) % 1

	local RGB = Color3.fromHSV(Hue,0.8,1)

	FeatureTitle.TextColor3 = RGB
end))
--==================================================
-- P12
--==================================================

btn("SPECIAL MODES 😋 ", P12, function() loadstring(game:HttpGet("https://pastebin.com/raw/yiz4bZgG"))() end)
btn("FOV VIEW 👁️ ", P12, function() loadstring(game:HttpGet("https://pastefy.app/wBDTCnNa/raw"))() end)
btn("DRONE CONTROLLER 🚁", P12, function() loadstring(game:HttpGet("https://pastefy.app/9QN9NTjk/raw"))() end)
btn("AURA GLITCH 🎭", P12, function() loadstring(game:HttpGet("https://pastebin.com/raw/Uq7htgyG"))() end)
btn("OUTFIT BREAKER 😈", P12, function() loadstring(game:HttpGet("https://pastebin.com/raw/d4u4u9tn"))() end)
btn("🦖 Giant Mode", P12, function() if player.Character and player.Character:FindFirstChild("Humanoid") then for _, scale in pairs({"BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale"}) do local obj = player.Character.Humanoid:FindFirstChild(scale); if obj then obj.Value = 2.5 end end end end, false)
btn("FAKE CHAT ☠️", P12, function() loadstring(game:HttpGet("https://pastebin.com/raw/96AH9Dcr"))() end)
btn("TRAIL 🏳️‍🌈", P12, function() loadstring(game:HttpGet("https://pastebin.com/raw/xhXTB61N"))() end)
btn("AUTO CLICKER ↗️", P12, function() loadstring(game:HttpGet("https://pastebin.com/raw/4b3HeU6Q"))() end)

--==================================================
-- P13 : INFO TAB
--==================================================

do
	-- avatar + welcome section
	local header = Instance.new("Frame", P13)
	header.Size = UDim2.new(1, -10, 0, 150)
	header.BackgroundTransparency = 1
	header.ZIndex = 12

	local ring = Instance.new("Frame", header)
	ring.AnchorPoint = Vector2.new(0.5, 0)
	ring.Position = UDim2.new(0.5, 0, 0, 4)
	ring.Size = UDim2.new(0, 84, 0, 84)
	ring.BackgroundColor3 = Color3.fromRGB(16, 30, 80)
	ring.BorderSizePixel = 0
	ring.ZIndex = 13
	Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
	local _, ringGrad = borderStroke(ring, 3, 0)

	local av = Instance.new("ImageLabel", ring)
	av.AnchorPoint = Vector2.new(0.5, 0.5)
	av.Position = UDim2.new(0.5, 0, 0.5, 0)
	av.Size = UDim2.new(1, -10, 1, -10)
	av.BackgroundTransparency = 1
	av.Image = avatarImage
	av.ScaleType = Enum.ScaleType.Crop
	av.ZIndex = 14
	Instance.new("UICorner", av).CornerRadius = UDim.new(1, 0)

	local welcome = Instance.new("TextLabel", header)
	welcome.Position = UDim2.new(0, 0, 0, 94)
	welcome.Size = UDim2.new(1, 0, 0, 28)
	welcome.BackgroundTransparency = 1
	welcome.Text = "WELCOME, " .. player.Name
	welcome.TextColor3 = Theme.Text
	welcome.Font = Enum.Font.GothamBlack
	welcome.TextScaled = true
	welcome.ZIndex = 13
	local wLimit = Instance.new("UITextSizeConstraint", welcome)
	wLimit.MaxTextSize = 18
	wLimit.MinTextSize = 10

	local display = Instance.new("TextLabel", header)
	display.Position = UDim2.new(0, 0, 0, 124)
	display.Size = UDim2.new(1, 0, 0, 18)
	display.BackgroundTransparency = 1
	display.Text = "Display name: " .. player.DisplayName
	display.TextColor3 = Theme.Muted
	display.Font = Enum.Font.Gotham
	display.TextSize = 12
	display.ZIndex = 13

	task.spawn(function()
		local rot = 0
		while header.Parent do
			-- only animate while the INFO page is actually visible
			if P13.Visible and Main.Visible then
				rot = (rot + 4) % 360
				ringGrad.Rotation = rot
			end
			task.wait(0.05)
		end
	end)

	-- info cards
	local function makeCard(iconText, labelText)
		local card = Instance.new("Frame", P13)
		card.Size = UDim2.new(1, -10, 0, 46)
		card.BackgroundColor3 = Theme.Navy
		card.BackgroundTransparency = 0.05
		card.BorderSizePixel = 0
		card.ZIndex = 12
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
		borderStroke(card, 1.2, 0.25)

		local icon = Instance.new("TextLabel", card)
		icon.Position = UDim2.new(0, 8, 0, 0)
		icon.Size = UDim2.new(0, 30, 1, 0)
		icon.BackgroundTransparency = 1
		icon.Text = iconText
		icon.TextSize = 20
		icon.TextColor3 = Theme.Text
		icon.Font = Enum.Font.GothamBold
		icon.ZIndex = 13

		local label = Instance.new("TextLabel", card)
		label.Position = UDim2.new(0, 44, 0, 5)
		label.Size = UDim2.new(1, -52, 0, 14)
		label.BackgroundTransparency = 1
		label.Text = labelText
		label.TextColor3 = Theme.Muted
		label.Font = Enum.Font.GothamBold
		label.TextSize = 11
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.ZIndex = 13

		local value = Instance.new("TextLabel", card)
		value.Position = UDim2.new(0, 44, 0, 21)
		value.Size = UDim2.new(1, -52, 0, 20)
		value.BackgroundTransparency = 1
		value.Text = "..."
		value.TextColor3 = Theme.Text
		value.Font = Enum.Font.GothamBold
		value.TextSize = 15
		value.TextXAlignment = Enum.TextXAlignment.Left
		value.TextTruncate = Enum.TextTruncate.AtEnd
		value.ZIndex = 13

		return value
	end

	local fpsValue = makeCard("⚡", "FPS")
	local pingValue = makeCard("📶", "PING (LATENCY)")
	local speedValue = makeCard("🌐", "NETWORK SPEED")
	local timeValue = makeCard("🕒", "LOCAL TIME")
	local dayValue = makeCard("📅", "DAY")
	local dateValue = makeCard("🗓️", "DATE")

	-- Roblox LocalScripts cannot measure real download/upload throughput
	speedValue.Text = "N/A (not measurable in Roblox)"
	speedValue.TextSize = 12
	speedValue.TextColor3 = Theme.Muted

	-- FPS counter: one lightweight Heartbeat connection, labels refreshed once per second
	local frames = 0
	table.insert(Cleanup, RunService.Heartbeat:Connect(function()
		frames += 1
	end))

	local function readPing()
		local ok, val = pcall(function()
			return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
		end)
		if ok and typeof(val) == "number" then
			return math.floor(val + 0.5)
		end
		return nil
	end

	local function refresh(fps)
		if fps then
			fpsValue.Text = tostring(fps) .. " FPS"
			if fps >= 50 then
				fpsValue.TextColor3 = Color3.fromRGB(80, 255, 150)
			elseif fps >= 30 then
				fpsValue.TextColor3 = Color3.fromRGB(255, 200, 70)
			else
				fpsValue.TextColor3 = Color3.fromRGB(255, 90, 90)
			end
		end

		local ping = readPing()
		pingValue.Text = ping and (tostring(ping) .. " ms") or "N/A"

		timeValue.Text = os.date("%I:%M:%S %p")
		dayValue.Text = os.date("%A")
		dateValue.Text = os.date("%d %B %Y")
	end

	refresh(nil)

	-- refresh immediately when the INFO page becomes visible
	P13:GetPropertyChangedSignal("Visible"):Connect(function()
		if P13.Visible then refresh(nil) end
	end)

	task.spawn(function()
		local last = os.clock()
		while sg.Parent do
			task.wait(1)
			local now = os.clock()
			local dt = now - last
			last = now
			local fps = math.floor(frames / math.max(dt, 0.001) + 0.5)
			frames = 0

			if Main.Visible and P13.Visible then
				refresh(fps)
			end
		end
	end)
end

--==================================================
-- BIG IMAGE TOGGLE
--==================================================

local ToggleBtn = Instance.new("ImageButton",sg)

ToggleBtn.Name = "ToggleButton"
ToggleBtn.Size = UDim2.new(0,70,0,70)
ToggleBtn.Position = UDim2.new(0,20,0.5,-35)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(15,15,15)
ToggleBtn.BackgroundTransparency = 0.15
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Image = "rbxassetid://83877589941594"
ToggleBtn.ScaleType = Enum.ScaleType.Fit
ToggleBtn.Visible = true
ToggleBtn.ZIndex = 200
ToggleBtn.Active = true
ToggleBtn.AutoButtonColor = false

Instance.new("UICorner",ToggleBtn).CornerRadius = UDim.new(0,18)

local ToggleStroke = Instance.new("UIStroke",ToggleBtn)
ToggleStroke.Thickness = 3
ToggleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

task.spawn(function()
	local h = 0

	while ToggleBtn.Parent do
		h = (h + 0.01) % 1
		ToggleStroke.Color = Color3.fromHSV(h,1,1)
		task.wait(0.02)
	end

end)

makeDraggable(ToggleBtn)

--==================================================
-- OPEN / CLOSE ANIMATION
--==================================================

local mainOpen = false
local mainTweens = {}

local function setMain(open)
	mainOpen = open

	for _, t in ipairs(mainTweens) do
		t:Cancel()
	end
	table.clear(mainTweens)

	local base = viewScale()

	if open then
		if not Main.Visible then
			Main.GroupTransparency = 1
			MainScale.Scale = base * 0.9
			Main.Visible = true
		end

		table.insert(mainTweens, tween(Main, 0.3, { GroupTransparency = 0 }))
		table.insert(mainTweens, tween(MainScale, 0.35, { Scale = base }, Enum.EasingStyle.Back))
	else
		table.insert(mainTweens, tween(Main, 0.22, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
		local closing = tween(MainScale, 0.22, { Scale = base * 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		table.insert(mainTweens, closing)

		closing.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and not mainOpen then
				Main.Visible = false
			end
		end)
	end
end

-- keep the GUI sized correctly if the screen size changes
do
	local cam = workspace.CurrentCamera
	if cam then
		table.insert(Cleanup, cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if mainOpen and #mainTweens > 0 then
				MainScale.Scale = viewScale()
			end
		end))
	end
end

-- ignore toggle clicks that were really drags
local toggleDownPos = nil

ToggleBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		toggleDownPos = ToggleBtn.AbsolutePosition
	end
end)

ToggleBtn.Activated:Connect(function()
	if toggleDownPos and (ToggleBtn.AbsolutePosition - toggleDownPos).Magnitude > 6 then
		return
	end
	setMain(not mainOpen)
end)

-- open the main window once everything is built
setMain(true)
