local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--------------------------------------------------------------------------------
-- ГЛОБАЛЬНОЕ СОСТОЯНИЕ СКРИПТА
--------------------------------------------------------------------------------
getgenv().CurrentSimScript = getgenv().CurrentSimScript or { Name = "SimCheat_V4.5", Exit = nil }

local GUI_NAME = "SimCheat_V4.5_UI"

local FeatureState = {
	BoxESP = false,
	HealthBar = false,
	SkeletonESP = false,
	Nimb = false,
	BoxColor = Color3.fromRGB(255, 255, 255),
	HealthColor = Color3.fromRGB(0, 255, 0),
	SkeletonColor = Color3.fromRGB(255, 255, 255),
	NimbColor = Color3.fromRGB(0, 255, 255)
}

local IsScriptActive = true
local playerDrawings = {}

--------------------------------------------------------------------------------
-- NIMB (НИМБ НАД ГОЛОВОЙ) СИСТЕМА — красивое сияющее кольцо с glow
--------------------------------------------------------------------------------
local NimbColor = FeatureState.NimbColor
local NimbHalo = nil
local NimbHead = nil

local function destroyNimb()
	if NimbHalo then
		NimbHalo:Destroy()
		NimbHalo = nil
	end
	NimbHead = nil
end

local function buildNimb(character)
	destroyNimb()

	local head = character:FindFirstChild("Head")
	if not head then return end

	local halo = Instance.new("Model")
	halo.Name = "NimbHalo"

	-- Основное светящееся кольцо (неон)
	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = NimbColor
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(1.5, 0.1, 1.5)
	ring.CastShadow = false
	ring.Parent = halo

	-- Внешнее мягкое свечение (светящийся ореол вокруг кольца)
	local glowDisc = Instance.new("Part")
	glowDisc.Name = "GlowDisc"
	glowDisc.Anchored = true
	glowDisc.CanCollide = false
	glowDisc.CanQuery = false
	glowDisc.CanTouch = false
	glowDisc.Material = Enum.Material.Neon
	glowDisc.Color = NimbColor
	glowDisc.Shape = Enum.PartType.Cylinder
	glowDisc.Size = Vector3.new(2.4, 0.04, 2.4)
	glowDisc.Transparency = 0.7
	glowDisc.CastShadow = false
	glowDisc.Parent = halo

	-- Реальный glow (освещение вокруг)
	local light = Instance.new("PointLight")
	light.Color = NimbColor
	light.Brightness = 1.5
	light.Range = 12
	light.Shadows = false
	light.Parent = ring

	halo.Parent = character

	-- Ставим нимб над головой
	ring.CFrame = head.CFrame * CFrame.new(0, 1.5, 0)
	glowDisc.CFrame = ring.CFrame

	NimbHalo = halo
	NimbHead = head
end

local function setNimb(enabled)
	FeatureState.Nimb = enabled
	local chr = LocalPlayer.Character
	if enabled then
		if chr then buildNimb(chr) end
	else
		destroyNimb()
	end
end

local function setNimbColor(col)
	FeatureState.NimbColor = col
	NimbColor = col
	if NimbHalo then
		local ring = NimbHalo:FindFirstChild("Ring")
		if ring then ring.Color = col end
		local glowDisc = NimbHalo:FindFirstChild("GlowDisc")
		if glowDisc then glowDisc.Color = col end
		local light = NimbHalo:FindFirstChildOfClass("PointLight")
		if light then light.Color = col end
	end
end

-- Пересоздаём нимб при ресспавне локального игрока, если он включён
LocalPlayer.CharacterAdded:Connect(function(character)
	if FeatureState.Nimb then buildNimb(character) end
end)

if FeatureState.Nimb and LocalPlayer.Character then
	buildNimb(LocalPlayer.Character)
end

-- Следим за головой каждый кадр (без физики, анкор — персонажа не толкает)
RunService.RenderStepped:Connect(function()
	if not NimbHalo or not NimbHead or not NimbHead.Parent then return end
	local ring = NimbHalo:FindFirstChild("Ring")
	local glowDisc = NimbHalo:FindFirstChild("GlowDisc")
	local cf = NimbHead.CFrame * CFrame.new(0, 1.5, 0)
	if ring then ring.CFrame = cf end
	if glowDisc then glowDisc.CFrame = cf end
end)

--------------------------------------------------------------------------------
-- СИСТЕМА ОЧИСТКИ
--------------------------------------------------------------------------------
local function cleanupScript()
	print("[SYSTEM] Stopping and cleaning up Script...")
	IsScriptActive = false

	local pg = LocalPlayer:FindFirstChild("PlayerGui")
	if pg then
		local oldMenu = pg:FindFirstChild(GUI_NAME)
		if oldMenu then oldMenu:Destroy() end
	end

	for player, drawings in pairs(playerDrawings) do
		if drawings.Box then drawings.Box:Remove() end
		if drawings.HealthBg then drawings.HealthBg:Remove() end
		if drawings.HealthFill then drawings.HealthFill:Remove() end
		if drawings.SkeletonLines then
			for _, item in pairs(drawings.SkeletonLines) do
				if item.Line then item.Line:Remove() end
			end
		end
	end
	playerDrawings = {}

	destroyNimb()

	print("[SYSTEM] Script cleaned up fully.")
end

if getgenv().CurrentSimScript and getgenv().CurrentSimScript.Exit then
	print("[SYSTEM] Previous version detected. Stopping it...")
	getgenv().CurrentSimScript.Exit()
end

getgenv().CurrentSimScript.Exit = cleanupScript

--------------------------------------------------------------------------------
-- GUI МЕНЮ
--------------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = GUI_NAME
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

--------------------------------------------------------------------------------
-- ВАТЕРМАРКА
--------------------------------------------------------------------------------
local Watermark = Instance.new("TextButton")
Watermark.Name = "Watermark"
Watermark.Size = UDim2.new(0, 190, 0, 32)
Watermark.Position = UDim2.new(0, 15, 0, 60)
Watermark.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
Watermark.AutoButtonColor = false
Watermark.Text = ""
Watermark.ZIndex = 50
Watermark.Parent = ScreenGui

local WM_Corner = Instance.new("UICorner")
WM_Corner.CornerRadius = UDim.new(0, 8)
WM_Corner.Parent = Watermark

local WM_Stroke = Instance.new("UIStroke")
WM_Stroke.Color = Color3.fromRGB(50, 50, 70)
WM_Stroke.Thickness = 1
WM_Stroke.Parent = Watermark

local WM_Text = Instance.new("TextLabel")
WM_Text.Size = UDim2.new(1, 0, 1, 0)
WM_Text.BackgroundTransparency = 1
WM_Text.Text = "Wibe Ware | 0 FPS | 0ms"
WM_Text.TextColor3 = Color3.fromRGB(255, 255, 255)
WM_Text.Font = Enum.Font.GothamBold
WM_Text.TextSize = 11
WM_Text.ZIndex = 51
WM_Text.Parent = Watermark

local WM_Gradient = Instance.new("UIGradient")
WM_Gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 220, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 100, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 220))
})
WM_Gradient.Parent = WM_Text

task.spawn(function()
	local lastUpdate = 0
	local frameCount = 0
	local currentFPS = 60

	RunService.RenderStepped:Connect(function(dt)
		frameCount = frameCount + 1
		if tick() - lastUpdate >= 0.5 then
			currentFPS = math.floor(frameCount / (tick() - lastUpdate) + 0.5)
			frameCount = 0
			lastUpdate = tick()

			local pingVal = 0
			pcall(function()
				pingVal = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5)
			end)

			if IsScriptActive then
				WM_Text.Text = string.format("Wibe Ware  |  %d FPS  |  %dms", currentFPS, pingVal)
			end
		end
	end)

	local rot = 0
	while IsScriptActive do
		rot = (rot + 2) % 360
		WM_Gradient.Rotation = rot
		task.wait(0.03)
	end
end)

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 480, 0, 290)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
MainFrame.BorderSizePixel = 0
MainFrame.BackgroundTransparency = 1
MainFrame.ClipsDescendants = false
MainFrame.Visible = false
MainFrame.ZIndex = 10
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 14)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(45, 45, 60)
MainStroke.Thickness = 1
MainStroke.Transparency = 1
MainStroke.Parent = MainFrame

--------------------------------------------------------------------------------
-- ПЕРЕМЕЩЕНИЕ ВАТЕРМАРКИ
--------------------------------------------------------------------------------
local menuOpen = false
local wmDragging = false
local wmDragInput, wmDragStart, wmStartPos

Watermark.InputBegan:Connect(function(input)
	if menuOpen and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		wmDragging = true
		wmDragStart = input.Position
		wmStartPos = Watermark.Position

		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				wmDragging = false
			end
		end)
	end
end)

Watermark.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		wmDragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input == wmDragInput and wmDragging then
		local delta = input.Position - wmDragStart
		local viewportSize = Camera.ViewportSize
		local wmSize = Watermark.AbsoluteSize

		local newX = wmStartPos.X.Offset + delta.X
		local newY = wmStartPos.Y.Offset + delta.Y

		newX = math.clamp(newX, 0, viewportSize.X - wmSize.X)
		newY = math.clamp(newY, 0, viewportSize.Y - wmSize.Y)

		Watermark.Position = UDim2.new(0, newX, 0, newY)
	end
end)

--------------------------------------------------------------------------------
-- НЕОНОВЫЙ ЗАГОЛОВОК
--------------------------------------------------------------------------------
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 32)
TopBar.Position = UDim2.new(0, 0, 0, 0)
TopBar.BackgroundTransparency = 1
TopBar.ZIndex = 11
TopBar.Parent = MainFrame

local GlowLabel1 = Instance.new("TextLabel")
GlowLabel1.Name = "GlowLabel1"
GlowLabel1.Size = UDim2.new(1, 0, 1, 0)
GlowLabel1.BackgroundTransparency = 1
GlowLabel1.Text = "Wibe Ware"
GlowLabel1.TextColor3 = Color3.fromRGB(0, 200, 255)
GlowLabel1.TextSize = 21
GlowLabel1.Font = Enum.Font.GothamBlack
GlowLabel1.TextTransparency = 0.5
GlowLabel1.ZIndex = 12
GlowLabel1.Parent = TopBar

local GlowLabel2 = Instance.new("TextLabel")
GlowLabel2.Name = "GlowLabel2"
GlowLabel2.Size = UDim2.new(1, 0, 1, 0)
GlowLabel2.BackgroundTransparency = 1
GlowLabel2.Text = "Wibe Ware"
GlowLabel2.TextColor3 = Color3.fromRGB(170, 50, 255)
GlowLabel2.TextSize = 20
GlowLabel2.Font = Enum.Font.GothamBlack
GlowLabel2.TextTransparency = 0.6
GlowLabel2.ZIndex = 13
GlowLabel2.Parent = TopBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.Size = UDim2.new(1, 0, 1, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Wibe Ware"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 19
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextTransparency = 1
TitleLabel.ZIndex = 14
TitleLabel.Parent = TopBar

local TitleGradient = Instance.new("UIGradient")
TitleGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 220, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 100, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 220))
})
TitleGradient.Parent = TitleLabel

task.spawn(function()
	local rot = 0
	while IsScriptActive do
		rot = (rot + 2) % 360
		TitleGradient.Rotation = rot

		local pulse = (math.sin(tick() * 3) + 1) / 2
		GlowLabel1.TextTransparency = 0.3 + (pulse * 0.3)
		GlowLabel2.TextTransparency = 0.4 + ((1 - pulse) * 0.3)

		task.wait(0.03)
	end
end)

--------------------------------------------------------------------------------
-- САЙДБАР И КОНТЕНТ
--------------------------------------------------------------------------------
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 80, 1, -40)
Sidebar.Position = UDim2.new(0, 8, 0, 34)
Sidebar.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 12
Sidebar.Parent = MainFrame

local SidebarCorner = Instance.new("UICorner")
SidebarCorner.CornerRadius = UDim.new(0, 6)
SidebarCorner.Parent = Sidebar

local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, -96, 1, -40)
ContentArea.Position = UDim2.new(0, 93, 0, 34)
ContentArea.BackgroundTransparency = 1
ContentArea.ZIndex = 12
ContentArea.Parent = MainFrame

local VisualsPage = Instance.new("ScrollingFrame")
VisualsPage.Name = "VisualsPage"
VisualsPage.Size = UDim2.new(1, 0, 1, 0)
VisualsPage.BackgroundTransparency = 1
VisualsPage.Visible = true
VisualsPage.ZIndex = 12
VisualsPage.CanvasSize = UDim2.new(0, 0, 0, 230)
VisualsPage.ScrollBarThickness = 3
VisualsPage.Parent = ContentArea

local VisualsTabBtn = Instance.new("TextButton")
VisualsTabBtn.Name = "VisualsTabBtn"
VisualsTabBtn.Size = UDim2.new(0.9, 0, 0, 24)
VisualsTabBtn.Position = UDim2.new(0.05, 0, 0, 8)
VisualsTabBtn.BackgroundColor3 = Color3.fromRGB(38, 38, 52)
VisualsTabBtn.Text = "Visuals"
VisualsTabBtn.TextColor3 = Color3.fromRGB(0, 210, 255)
VisualsTabBtn.TextTransparency = 1
VisualsTabBtn.Font = Enum.Font.GothamBold
VisualsTabBtn.TextSize = 11
VisualsTabBtn.ZIndex = 13
VisualsTabBtn.Parent = Sidebar

local TabCorner = Instance.new("UICorner")
TabCorner.CornerRadius = UDim.new(0, 5)
TabCorner.Parent = VisualsTabBtn

local ResizeGrip = Instance.new("TextButton")
ResizeGrip.Name = "ResizeGrip"
ResizeGrip.Size = UDim2.new(0, 18, 0, 18)
ResizeGrip.Position = UDim2.new(1, -18, 1, -18)
ResizeGrip.BackgroundTransparency = 1
ResizeGrip.Text = "///"
ResizeGrip.TextColor3 = Color3.fromRGB(90, 90, 110)
ResizeGrip.TextSize = 11
ResizeGrip.Font = Enum.Font.SourceSansBold
ResizeGrip.ZIndex = 20
ResizeGrip.Parent = MainFrame

local function makeResizable(frame, handle)
	local resizing = false
	local startSize, startMousePos

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			resizing = true
			startSize = frame.Size
			startMousePos = input.Position

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					resizing = false
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - startMousePos
			local newWidth = math.max(340, startSize.X.Offset + delta.X)
			local newHeight = math.max(200, startSize.Y.Offset + delta.Y)

			frame.Size = UDim2.new(0, newWidth, 0, newHeight)
		end
	end)
end

makeResizable(MainFrame, ResizeGrip)

--------------------------------------------------------------------------------
-- КАСТОМНОЕ ОКНО ВЫБОРА ЦВЕТА (COLOR PICKER)
--------------------------------------------------------------------------------
local ColorPickerGui = Instance.new("Frame")
ColorPickerGui.Name = "ColorPickerWindow"
ColorPickerGui.Size = UDim2.new(0, 260, 0, 310)
ColorPickerGui.AnchorPoint = Vector2.new(0.5, 0.5)
ColorPickerGui.Position = UDim2.new(0.5, 0, 0.5, 0)
ColorPickerGui.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
ColorPickerGui.BorderSizePixel = 0
ColorPickerGui.BackgroundTransparency = 1
ColorPickerGui.Visible = false
ColorPickerGui.ZIndex = 100
ColorPickerGui.Parent = ScreenGui

local CP_Corner = Instance.new("UICorner")
CP_Corner.CornerRadius = UDim.new(0, 10)
CP_Corner.Parent = ColorPickerGui

local CP_Stroke = Instance.new("UIStroke")
CP_Stroke.Color = Color3.fromRGB(50, 50, 70)
CP_Stroke.Thickness = 1
CP_Stroke.Transparency = 1
CP_Stroke.Parent = ColorPickerGui

-- Прозрачная шапка окна (без серого фона)
local CP_TopBar = Instance.new("Frame")
CP_TopBar.Name = "CP_TopBar"
CP_TopBar.Size = UDim2.new(1, 0, 0, 30)
CP_TopBar.BackgroundTransparency = 1
CP_TopBar.ZIndex = 101
CP_TopBar.Parent = ColorPickerGui

local CP_Title = Instance.new("TextLabel")
CP_Title.Size = UDim2.new(1, -40, 1, 0)
CP_Title.Position = UDim2.new(0, 12, 0, 0)
CP_Title.BackgroundTransparency = 1
CP_Title.Text = "Color Picker"
CP_Title.TextColor3 = Color3.fromRGB(230, 230, 240)
CP_Title.Font = Enum.Font.GothamBold
CP_Title.TextSize = 13
CP_Title.TextTransparency = 1
CP_Title.TextXAlignment = Enum.TextXAlignment.Left
CP_Title.ZIndex = 102
CP_Title.Parent = CP_TopBar

-- ЧЁТКИЙ И ВИДИМЫЙ КРЕСТИК ЗАКРЫТИЯ
local CP_CloseBtn = Instance.new("TextButton")
CP_CloseBtn.Name = "CloseButton"
CP_CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CP_CloseBtn.Position = UDim2.new(1, -28, 0, 3)
CP_CloseBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
CP_CloseBtn.AutoButtonColor = false
CP_CloseBtn.Text = "✕"
CP_CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CP_CloseBtn.Font = Enum.Font.GothamBold
CP_CloseBtn.TextSize = 12
CP_CloseBtn.TextTransparency = 1
CP_CloseBtn.BackgroundTransparency = 1
CP_CloseBtn.ZIndex = 105
CP_CloseBtn.Parent = CP_TopBar

local CP_CloseCorner = Instance.new("UICorner")
CP_CloseCorner.CornerRadius = UDim.new(0, 6)
CP_CloseCorner.Parent = CP_CloseBtn

CP_CloseBtn.MouseEnter:Connect(function()
	TweenService:Create(CP_CloseBtn, TweenInfo.new(0.2), {
		BackgroundColor3 = Color3.fromRGB(220, 50, 60),
		TextColor3 = Color3.fromRGB(255, 255, 255)
	}):Play()
end)

CP_CloseBtn.MouseLeave:Connect(function()
	TweenService:Create(CP_CloseBtn, TweenInfo.new(0.2), {
		BackgroundColor3 = Color3.fromRGB(35, 35, 48),
		TextColor3 = Color3.fromRGB(255, 255, 255)
	}):Play()
end)

local PaletteBox = Instance.new("ImageButton")
PaletteBox.Name = "PaletteBox"
PaletteBox.Size = UDim2.new(0, 180, 0, 160)
PaletteBox.Position = UDim2.new(0, 10, 0, 35)
PaletteBox.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
PaletteBox.BorderSizePixel = 0
PaletteBox.AutoButtonColor = false
PaletteBox.Image = ""
PaletteBox.ZIndex = 101
PaletteBox.Parent = ColorPickerGui

local SatGrad = Instance.new("Frame")
SatGrad.Name = "SatGrad"
SatGrad.Size = UDim2.new(1, 0, 1, 0)
SatGrad.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
SatGrad.BorderSizePixel = 0
SatGrad.ZIndex = 102
SatGrad.Parent = PaletteBox

local SatUI = Instance.new("UIGradient")
SatUI.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(1, 1)
})
SatUI.Parent = SatGrad

local ValGrad = Instance.new("Frame")
ValGrad.Name = "ValGrad"
ValGrad.Size = UDim2.new(1, 0, 1, 0)
ValGrad.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
ValGrad.BorderSizePixel = 0
ValGrad.ZIndex = 103
ValGrad.Parent = PaletteBox

local ValUI = Instance.new("UIGradient")
ValUI.Rotation = 90
ValUI.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(1, 0)
})
ValUI.Parent = ValGrad

local PaletteSelector = Instance.new("Frame")
PaletteSelector.Size = UDim2.new(0, 10, 0, 10)
PaletteSelector.AnchorPoint = Vector2.new(0.5, 0.5)
PaletteSelector.Position = UDim2.new(0, 0, 0, 0)
PaletteSelector.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
PaletteSelector.ZIndex = 105
PaletteSelector.Parent = PaletteBox

local PS_Corner = Instance.new("UICorner")
PS_Corner.CornerRadius = UDim.new(1, 0)
PS_Corner.Parent = PaletteSelector
local PS_Stroke = Instance.new("UIStroke")
PS_Stroke.Color = Color3.fromRGB(0, 0, 0)
PS_Stroke.Thickness = 1.5
PS_Stroke.Parent = PaletteSelector

local HueSlider = Instance.new("ImageButton")
HueSlider.Name = "HueSlider"
HueSlider.Size = UDim2.new(0, 22, 0, 160)
HueSlider.Position = UDim2.new(0, 200, 0, 35)
HueSlider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
HueSlider.BorderSizePixel = 0
HueSlider.AutoButtonColor = false
HueSlider.Image = ""
HueSlider.ZIndex = 101
HueSlider.Parent = ColorPickerGui

local HueGrad = Instance.new("UIGradient")
HueGrad.Rotation = 90
HueGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
	ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
	ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
	ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
	ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
	ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0))
})
HueGrad.Parent = HueSlider

local HueSelector = Instance.new("Frame")
HueSelector.Size = UDim2.new(1, 4, 0, 4)
HueSelector.AnchorPoint = Vector2.new(0.5, 0.5)
HueSelector.Position = UDim2.new(0.5, 0, 0, 0)
HueSelector.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
HueSelector.ZIndex = 105
HueSelector.Parent = HueSlider

local CurrentPreview = Instance.new("Frame")
CurrentPreview.Size = UDim2.new(0, 36, 0, 24)
CurrentPreview.Position = UDim2.new(0, 200, 0, 202)
CurrentPreview.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
CurrentPreview.BorderSizePixel = 0
CurrentPreview.ZIndex = 101
CurrentPreview.Parent = ColorPickerGui

local CP_LabelCurr = Instance.new("TextLabel")
CP_LabelCurr.Size = UDim2.new(0, 36, 0, 12)
CP_LabelCurr.Position = UDim2.new(0, 200, 0, 228)
CP_LabelCurr.BackgroundTransparency = 1
CP_LabelCurr.Text = "Current"
CP_LabelCurr.TextColor3 = Color3.fromRGB(150, 150, 170)
CP_LabelCurr.Font = Enum.Font.Gotham
CP_LabelCurr.TextSize = 9
CP_LabelCurr.ZIndex = 101
CP_LabelCurr.Parent = ColorPickerGui

local OriginalPreview = Instance.new("Frame")
OriginalPreview.Size = UDim2.new(0, 36, 0, 24)
OriginalPreview.Position = UDim2.new(0, 200, 0, 246)
OriginalPreview.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
OriginalPreview.BorderSizePixel = 0
OriginalPreview.ZIndex = 101
OriginalPreview.Parent = ColorPickerGui

local CP_LabelOrig = Instance.new("TextLabel")
CP_LabelOrig.Size = UDim2.new(0, 36, 0, 12)
CP_LabelOrig.Position = UDim2.new(0, 200, 0, 272)
CP_LabelOrig.BackgroundTransparency = 1
CP_LabelOrig.Text = "Original"
CP_LabelOrig.TextColor3 = Color3.fromRGB(150, 150, 170)
CP_LabelOrig.Font = Enum.Font.Gotham
CP_LabelOrig.TextSize = 9
CP_LabelOrig.ZIndex = 101
CP_LabelOrig.Parent = ColorPickerGui

local function createColorInput(posX, posY, sizeX)
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0, sizeX, 0, 22)
	box.Position = UDim2.new(0, posX, 0, posY)
	box.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	box.TextColor3 = Color3.fromRGB(220, 220, 230)
	box.Font = Enum.Font.Code
	box.TextSize = 11
	box.Text = ""
	box.ClearTextOnFocus = false
	box.ZIndex = 101
	box.Parent = ColorPickerGui
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 4) c.Parent = box
	return box
end

local BoxR = createColorInput(10, 202, 54)
local BoxG = createColorInput(70, 202, 54)
BoxG.Position = UDim2.new(0, 70, 0, 202)
local BoxB = createColorInput(130, 202, 54)

local BoxH = createColorInput(10, 230, 54)
local BoxS = createColorInput(70, 230, 54)
local BoxV = createColorInput(130, 230, 54)

local BoxHex = createColorInput(10, 258, 174)
BoxHex.Text = "#FFFFFF"

local activeColorCallback = nil
local currentHue, currentSat, currentVal = 0, 0, 1
local colorPickerOpen = false
local cpAnimating = false

local function updateColorPickerVisuals()
	local col = Color3.fromHSV(currentHue, currentSat, currentVal)
	PaletteBox.BackgroundColor3 = Color3.fromHSV(currentHue, 1, 1)
	CurrentPreview.BackgroundColor3 = col
	
	BoxR.Text = "R: " .. math.floor(col.R * 255 + 0.5)
	BoxG.Text = "G: " .. math.floor(col.G * 255 + 0.5)
	BoxB.Text = "B: " .. math.floor(col.B * 255 + 0.5)
	
	BoxH.Text = "H: " .. math.floor(currentHue * 360 + 0.5)
	BoxS.Text = "S: " .. math.floor(currentSat * 100 + 0.5)
	BoxV.Text = "V: " .. math.floor(currentVal * 100 + 0.5)
	
	BoxHex.Text = "#" .. string.format("%02X%02X%02X", math.floor(col.R*255+0.5), math.floor(col.G*255+0.5), math.floor(col.B*255+0.5))
	
	if activeColorCallback then
		activeColorCallback(col)
	end
end

-- Исправленная плавная анимация прозрачности всех элементов палитры
local function animateColorPicker(targetTransparency, duration)
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	TweenService:Create(ColorPickerGui, tweenInfo, { BackgroundTransparency = targetTransparency }):Play()
	TweenService:Create(CP_Stroke, tweenInfo, { Transparency = targetTransparency }):Play()

	for _, obj in ipairs(ColorPickerGui:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextBox") then
			TweenService:Create(obj, tweenInfo, { TextTransparency = targetTransparency }):Play()
		end
		if obj:IsA("Frame") or obj:IsA("TextButton") or obj:IsA("ImageButton") or obj:IsA("TextBox") then
			if obj ~= CP_TopBar then
				local targetBg = targetTransparency
				if targetTransparency == 0 and obj == CP_CloseBtn then
					targetBg = 0
				end
				TweenService:Create(obj, tweenInfo, { BackgroundTransparency = targetBg }):Play()
			end
		end
		if obj:IsA("UIStroke") then
			TweenService:Create(obj, tweenInfo, { Transparency = targetTransparency }):Play()
		end
	end
end

local function closeColorPicker()
	if cpAnimating or not colorPickerOpen then return end
	cpAnimating = true
	colorPickerOpen = false

	local closeTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
	local closeTween = TweenService:Create(ColorPickerGui, closeTweenInfo, {
		Size = UDim2.new(0, 180, 0, 210)
	})

	animateColorPicker(1, 0.25)
	closeTween:Play()

	closeTween.Completed:Connect(function()
		ColorPickerGui.Visible = false
		cpAnimating = false
	end)
end

CP_CloseBtn.MouseButton1Click:Connect(function()
	closeColorPicker()
end)

local function openColorPicker(defaultColor, callback)
	if cpAnimating then return end
	activeColorCallback = callback
	OriginalPreview.BackgroundColor3 = defaultColor
	
	local h, s, v = defaultColor:ToHSV()
	currentHue, currentSat, currentVal = h, s, v
	
	PaletteSelector.Position = UDim2.new(s, 0, 1 - v, 0)
	HueSelector.Position = UDim2.new(0.5, 0, 1 - h, 0)
	
	updateColorPickerVisuals()

	cpAnimating = true
	colorPickerOpen = true
	
	ColorPickerGui.Size = UDim2.new(0, 180, 0, 210)
	ColorPickerGui.Visible = true
	animateColorPicker(1, 0)

	local openTweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local openTween = TweenService:Create(ColorPickerGui, openTweenInfo, {
		Size = UDim2.new(0, 260, 0, 310)
	})

	animateColorPicker(0, 0.3)
	openTween:Play()

	openTween.Completed:Connect(function()
		cpAnimating = false
	end)
end

local selectingPalette = false
local selectingHue = false

local function processPaletteInput(inputPosition)
	local absPos = PaletteBox.AbsolutePosition
	local absSize = PaletteBox.AbsoluteSize
	
	local x = math.clamp((inputPosition.X - absPos.X) / absSize.X, 0, 1)
	local y = math.clamp((inputPosition.Y - absPos.Y) / absSize.Y, 0, 1)
	
	currentSat = x
	currentVal = 1 - y
	PaletteSelector.Position = UDim2.new(x, 0, y, 0)
	updateColorPickerVisuals()
end

local function processHueInput(inputPosition)
	local absPos = HueSlider.AbsolutePosition
	local absSize = HueSlider.AbsoluteSize
	
	local y = math.clamp((inputPosition.Y - absPos.Y) / absSize.Y, 0, 1)
	
	currentHue = 1 - y
	HueSelector.Position = UDim2.new(0.5, 0, y, 0)
	updateColorPickerVisuals()
end

PaletteBox.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		selectingPalette = true
		processPaletteInput(input.Position)
	end
end)

HueSlider.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		selectingHue = true
		processHueInput(input.Position)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		selectingPalette = false
		selectingHue = false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		if selectingPalette then
			processPaletteInput(input.Position)
		elseif selectingHue then
			processHueInput(input.Position)
		end
	end
end)

--------------------------------------------------------------------------------
-- АНИМАЦИЯ МЕНЮ С ИСПРАВЛЕННОЙ ПРОЗРАЧНОСТЬЮ
--------------------------------------------------------------------------------
local isAnimating = false
local savedPosition = UDim2.new(0.5, 0, 0.5, 0)
local targetSize = UDim2.new(0, 480, 0, 290)

local function animateTransparency(targetTransparency, duration)
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	TweenService:Create(MainFrame, tweenInfo, { BackgroundTransparency = targetTransparency }):Play()
	TweenService:Create(MainStroke, tweenInfo, { Transparency = targetTransparency }):Play()
	TweenService:Create(Sidebar, tweenInfo, { BackgroundTransparency = math.clamp(targetTransparency + 0.1, 0, 1) }):Play()

	for _, obj in ipairs(MainFrame:GetDescendants()) do
		if obj.Name:find("Row") then
			obj.BackgroundTransparency = 1
		else
			if obj:IsA("TextLabel") then
				TweenService:Create(obj, tweenInfo, { TextTransparency = targetTransparency }):Play()
			elseif obj:IsA("TextButton") or obj:IsA("Frame") or obj:IsA("ImageButton") then
				if obj ~= TopBar and obj ~= ContentArea and obj ~= VisualsPage then
					local bgTarget = targetTransparency
					if targetTransparency == 0 then
						bgTarget = (obj:GetAttribute("BaseTransparency") or 0)
					end
					TweenService:Create(obj, tweenInfo, { BackgroundTransparency = bgTarget }):Play()
				end

				if obj:IsA("TextButton") then
					TweenService:Create(obj, tweenInfo, { TextTransparency = targetTransparency }):Play()
				end
			elseif obj:IsA("UIStroke") then
				TweenService:Create(obj, tweenInfo, { Transparency = targetTransparency }):Play()
			end
		end
	end
end

local function toggleMenu()
	if isAnimating or not IsScriptActive then return end
	isAnimating = true
	menuOpen = not menuOpen

	if menuOpen then
		targetSize = MainFrame.Size
		
		MainFrame.AnchorPoint = Vector2.new(0, 1)
		MainFrame.Position = UDim2.new(0, 20, 1, -20)
		MainFrame.Size = UDim2.new(0, 120, 0, 70)
		MainFrame.Visible = true
		
		animateTransparency(1, 0)

		local iosTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		
		local sizeTween = TweenService:Create(MainFrame, iosTweenInfo, {
			Position = savedPosition,
			Size = targetSize,
			AnchorPoint = Vector2.new(0.5, 0.5)
		})
		
		animateTransparency(0, 0.35)
		sizeTween:Play()
		
		sizeTween.Completed:Connect(function()
			isAnimating = false
		end)
	else
		savedPosition = MainFrame.Position
		targetSize = MainFrame.Size
		
		MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		local iosCloseInfo = TweenInfo.new(0.32, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
		
		local closeTween = TweenService:Create(MainFrame, iosCloseInfo, {
			Position = UDim2.new(0, 20, 1, -20),
			Size = UDim2.new(0, 100, 0, 60),
			AnchorPoint = Vector2.new(0, 1)
		})
		
		animateTransparency(1, 0.28)
		closeTween:Play()
		
		closeTween.Completed:Connect(function()
			MainFrame.Visible = false
			closeColorPicker()
			
			MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
			MainFrame.Position = savedPosition
			MainFrame.Size = targetSize
			isAnimating = false
		end)
	end
end

Watermark.MouseButton1Click:Connect(function()
	if not wmDragging then
		toggleMenu()
	end
end)

--------------------------------------------------------------------------------
-- УНИВЕРСАЛЬНОЕ ПЕРЕМЕЩЕНИЕ МЕНЮ
--------------------------------------------------------------------------------
local dragging = false
local dragInput, dragStart, startPos

MainFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		local target = input.Target
		if target and (target:IsA("TextButton") or target:IsA("TextBox") or target:IsA("ImageButton")) and target ~= MainFrame and target ~= Sidebar and target ~= TopBar then
			return
		end
		
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

MainFrame.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging then
		local delta = input.Position - dragStart
		local targetPos = UDim2.new(
			startPos.X.Scale, 
			startPos.X.Offset + delta.X, 
			startPos.Y.Scale, 
			startPos.Y.Offset + delta.Y
		)
		MainFrame.Position = targetPos
		savedPosition = targetPos
	end
end)

--------------------------------------------------------------------------------
-- ЭЛЕМЕНТЫ МЕНЮ
--------------------------------------------------------------------------------
local function createToggleRow(parentPage, name, text, positionY, initialColor, onClick, onColorChange)
	local rowFrame = Instance.new("Frame")
	rowFrame.Name = name .. "Row"
	rowFrame.Size = UDim2.new(1, 0, 0, 34)
	rowFrame.Position = UDim2.new(0, 0, 0, positionY)
	rowFrame.BackgroundTransparency = 1
	rowFrame.ZIndex = 13
	rowFrame.Parent = parentPage

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(0.55, 0, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(230, 230, 235)
	label.TextTransparency = 1
	label.Font = Enum.Font.SourceSansSemibold
	label.TextSize = 15
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 13
	label.Parent = rowFrame

	local colorBtn = Instance.new("TextButton")
	colorBtn.Name = "ColorPreview"
	colorBtn.Size = UDim2.new(0, 24, 0, 18)
	colorBtn.Position = UDim2.new(1, -90, 0.5, -9)
	colorBtn.BackgroundColor3 = initialColor
	colorBtn.AutoButtonColor = false
	colorBtn.Text = ""
	colorBtn.ZIndex = 14
	colorBtn.Parent = rowFrame

	local cbCorner = Instance.new("UICorner")
	cbCorner.CornerRadius = UDim.new(0, 4)
	cbCorner.Parent = colorBtn

	colorBtn.MouseButton1Click:Connect(function()
		if not IsScriptActive then return end
		openColorPicker(colorBtn.BackgroundColor3, function(newCol)
			colorBtn.BackgroundColor3 = newCol
			if onColorChange then onColorChange(newCol) end
		end)
	end)

	local track = Instance.new("TextButton")
	track.Name = "ToggleTrack"
	track.Size = UDim2.new(0, 46, 0, 22)
	track.Position = UDim2.new(1, -56, 0.5, -11)
	track.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
	track.BackgroundTransparency = 0
	track.Text = ""
	track.AutoButtonColor = false
	track.ZIndex = 14
	track.Parent = rowFrame

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.Position = UDim2.new(0, 3, 0.5, -8)
	knob.BackgroundColor3 = Color3.fromRGB(180, 180, 195)
	knob.BackgroundTransparency = 0
	knob.BorderSizePixel = 0
	knob.ZIndex = 15
	knob.Parent = track

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	local enabled = false
	track.MouseButton1Click:Connect(function()
		if not IsScriptActive then return end
		enabled = not enabled

		local targetTrackColor = enabled and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(45, 45, 58)
		local targetKnobPos = enabled and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
		local targetKnobColor = enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 195)

		TweenService:Create(track, TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { 
			BackgroundColor3 = targetTrackColor 
		}):Play()
		
		TweenService:Create(knob, TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { 
			Position = targetKnobPos, 
			BackgroundColor3 = targetKnobColor 
		}):Play()

		onClick(enabled)
	end)
end

createToggleRow(VisualsPage, "BoxESPBtn", "Box ESP", 10, FeatureState.BoxColor, function(state) FeatureState.BoxESP = state end, function(col) FeatureState.BoxColor = col end)
createToggleRow(VisualsPage, "HealthBarBtn", "Health Bar", 50, FeatureState.HealthColor, function(state) FeatureState.HealthBar = state end, function(col) FeatureState.HealthColor = col end)
createToggleRow(VisualsPage, "SkeletonBtn", "White Skeleton", 90, FeatureState.SkeletonColor, function(state) FeatureState.SkeletonESP = state end, function(col) FeatureState.SkeletonColor = col end)
createToggleRow(VisualsPage, "NimbBtn", "Nimb (Glow)", 130, FeatureState.NimbColor, setNimb, setNimbColor)

local ExitBtn = Instance.new("TextButton")
ExitBtn.Name = "ExitBtn"
ExitBtn.Size = UDim2.new(1, -20, 0, 30)
ExitBtn.Position = UDim2.new(0, 10, 0, 175)
ExitBtn.BackgroundColor3 = Color3.fromRGB(160, 35, 45)
ExitBtn.BackgroundTransparency = 1
ExitBtn.Text = "EXIT SCRIPT"
ExitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ExitBtn.TextTransparency = 1
ExitBtn.Font = Enum.Font.SourceSansBold
ExitBtn.TextSize = 13
ExitBtn.ZIndex = 14
ExitBtn.Parent = VisualsPage

local ExitCorner = Instance.new("UICorner")
ExitCorner.CornerRadius = UDim.new(0, 6)
ExitCorner.Parent = ExitBtn

ExitBtn.MouseButton1Click:Connect(function()
	cleanupScript()
end)

--------------------------------------------------------------------------------
-- СИСТЕМА DRAWING ESP
--------------------------------------------------------------------------------
local function worldToViewportPoint(position)
	local screenPos, onScreen = Camera:WorldToViewportPoint(position)
	return Vector2.new(screenPos.X, screenPos.Y), onScreen
end

local function getOrCreateDrawings(player)
	if playerDrawings[player] then return playerDrawings[player] end

	local box = Drawing.new("Square")
	box.Visible = false
	box.Color = FeatureState.BoxColor
	box.Thickness = 1.5
	box.Filled = false

	local healthBg = Drawing.new("Square")
	healthBg.Visible = false
	healthBg.Color = Color3.fromRGB(0, 0, 0)
	healthBg.Thickness = 1
	healthBg.Filled = true

	local healthFill = Drawing.new("Square")
	healthFill.Visible = false
	healthFill.Color = FeatureState.HealthColor
	healthFill.Thickness = 1
	healthFill.Filled = true

	local skeletonLines = {}
	local connections = {
		{"Head", "UpperTorso"},
		{"UpperTorso", "LowerTorso"},
		{"UpperTorso", "LeftUpperArm"},
		{"LeftUpperArm", "LeftLowerArm"},
		{"LeftLowerArm", "LeftHand"},
		{"UpperTorso", "RightUpperArm"},
		{"RightUpperArm", "RightLowerArm"},
		{"RightLowerArm", "RightHand"},
		{"LowerTorso", "LeftUpperLeg"},
		{"LeftUpperLeg", "LeftLowerLeg"},
		{"LeftLowerLeg", "LeftFoot"},
		{"LowerTorso", "RightUpperLeg"},
		{"RightUpperLeg", "RightLowerLeg"},
		{"RightLowerLeg", "RightFoot"}
	}
	
	for _, conn in ipairs(connections) do
		local line = Drawing.new("Line")
		line.Visible = false
		line.Color = FeatureState.SkeletonColor
		line.Thickness = 1.5
		table.insert(skeletonLines, {Line = line, FromPart = conn[1], ToPart = conn[2]})
	end

	local elements = {
		Box = box,
		HealthBg = healthBg,
		HealthFill = healthFill,
		SkeletonLines = skeletonLines
	}

	playerDrawings[player] = elements
	return elements
end

local function removeDrawings(player)
	if playerDrawings[player] then
		if playerDrawings[player].Box then playerDrawings[player].Box:Remove() end
		if playerDrawings[player].HealthBg then playerDrawings[player].HealthBg:Remove() end
		if playerDrawings[player].HealthFill then playerDrawings[player].HealthFill:Remove() end
		if playerDrawings[player].SkeletonLines then
			for _, item in pairs(playerDrawings[player].SkeletonLines) do
				if item.Line then item.Line:Remove() end
			end
		end
		playerDrawings[player] = nil
	end
end

Players.PlayerRemoving:Connect(function(player)
	removeDrawings(player)
end)

RunService.RenderStepped:Connect(function()
	if not IsScriptActive then return end

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local character = player.Character
			local drawings = getOrCreateDrawings(player)

			local function hideAll()
				if drawings.Box then drawings.Box.Visible = false end
				if drawings.HealthBg then drawings.HealthBg.Visible = false end
				if drawings.HealthFill then drawings.HealthFill.Visible = false end
				if drawings.SkeletonLines then
					for _, item in ipairs(drawings.SkeletonLines) do
						if item.Line then item.Line.Visible = false end
					end
				end
			end

			if not character or not character:FindFirstChild("HumanoidRootPart") or not character:FindFirstChild("Humanoid") then
				hideAll()
			else
				local humanoid = character:FindFirstChild("Humanoid")
				if humanoid.Health <= 0 then
					hideAll()
				else
					local rootPart = character.HumanoidRootPart
					local head = character:FindFirstChild("Head")
					
					local _, onScreen = worldToViewportPoint(rootPart.Position)
					if not onScreen then
						hideAll()
					else
						-- Box ESP
						if FeatureState.BoxESP and head and rootPart then
							drawings.Box.Color = FeatureState.BoxColor
							local topPos, topVis = worldToViewportPoint(head.Position + Vector3.new(0, 0.8, 0))
							local bottomPos, bottomVis = worldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
							
							if topVis and bottomVis then
								local height = math.abs(bottomPos.Y - topPos.Y)
								local width = height / 2
								drawings.Box.Size = Vector2.new(width, height)
								drawings.Box.Position = Vector2.new(topPos.X - width / 2, topPos.Y)
								drawings.Box.Visible = true
							else
								drawings.Box.Visible = false
							end
						else
							drawings.Box.Visible = false
						end

						-- Health Bar
						if FeatureState.HealthBar and head and rootPart then
							drawings.HealthFill.Color = FeatureState.HealthColor
							local topPos, topVis = worldToViewportPoint(head.Position + Vector3.new(0, 0.8, 0))
							local bottomPos, bottomVis = worldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
							
							if topVis and bottomVis then
								local height = math.abs(bottomPos.Y - topPos.Y)
								local width = height / 2
								local x = topPos.X - width / 2 - 6
								local y = topPos.Y
								
								drawings.HealthBg.Size = Vector2.new(3, height)
								drawings.HealthBg.Position = Vector2.new(x, y)
								drawings.HealthBg.Visible = true

								local healthPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
								local fillHeight = height * healthPercent
								drawings.HealthFill.Size = Vector2.new(1, fillHeight)
								drawings.HealthFill.Position = Vector2.new(x + 1, y + (height - fillHeight))
								drawings.HealthFill.Visible = true
							else
								drawings.HealthBg.Visible = false
								drawings.HealthFill.Visible = false
							end
						else
							drawings.HealthBg.Visible = false
							drawings.HealthFill.Visible = false
						end

						-- Skeleton ESP
						if FeatureState.SkeletonESP then
							for _, item in ipairs(drawings.SkeletonLines) do
								item.Line.Color = FeatureState.SkeletonColor
								local partFrom = character:FindFirstChild(item.FromPart)
								local partTo = character:FindFirstChild(item.ToPart)

								if partFrom and partTo then
									local pos1, vis1 = worldToViewportPoint(partFrom.Position)
									local pos2, vis2 = worldToViewportPoint(partTo.Position)

									if vis1 or vis2 then
										item.Line.From = pos1
										item.Line.To = pos2
										item.Line.Visible = true
									else
										item.Line.Visible = false
									end
								else
									item.Line.Visible = false
								end
							end
						else
							for _, item in ipairs(drawings.SkeletonLines) do
								if item.Line then item.Line.Visible = false end
							end
						end
					end
				end
			end
		end
	end
end)

print("[SYSTEM] Script V.4.5 loaded (Fixed topbar background, palette animation transparency, and close button).")
