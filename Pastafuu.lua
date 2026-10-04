local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local GUI_NAME = "SimCheat_V4.7_UI"
local CONFIG_FILE = "WibeWare_Config.json"

--------------------------------------------------------------------------------
-- ГЛОБАЛЬНОЕ СОСТОЯНИЕ СКРИПТА
--------------------------------------------------------------------------------
getgenv().CurrentSimScript = getgenv().CurrentSimScript or {
    Name = "SimCheat_V4.7",
    Exit = nil
}

local FeatureState = {
    BoxESP = false,
    HealthBar = false,
    SkeletonESP = false,
    Nimb = false,
    NameESP = false,
    DistanceESP = false,
    TracerESP = false,
    TeamCheck = false,
    Chams = false, -- Новая функция

    -- Цвета
    BoxColor = Color3.fromRGB(255, 255, 255),
    HealthColor = Color3.fromRGB(0, 255, 0),
    SkeletonColor = Color3.fromRGB(255, 255, 255),
    NimbColor = Color3.fromRGB(0, 255, 255),
    NameColor = Color3.fromRGB(255, 255, 255),
    DistanceColor = Color3.fromRGB(230, 230, 235),
    TracerColor = Color3.fromRGB(255, 80, 80),
    ChamsColor = Color3.fromRGB(180, 100, 255),
    ChamsOutlineColor = Color3.fromRGB(255, 255, 255),

    -- Настройки стиля
    BoxStyle = "Outline",
    BoxThickness = "Normal",
    HealthSide = "Left",
    SkelThickness = "Normal",
    NimbHeight = "Normal",
    NameSize = "Normal",
    DistanceUnit = "Studs",
    TracerOrigin = "Bottom",
    TracerThickness = "Normal",
    ChamsFillTrans = 0.5,
    ChamsOutlineTrans = 0
}

-- Карты значений для настроек
local THICKNESS_MAP = { Thin = 1, Normal = 1.5, Thick = 2.5 }
local NAME_SIZE_MAP = { Small = 11, Normal = 14, Large = 18 }
local NIMB_HEIGHT_MAP = { Low = 1.4, Normal = 1.75, High = 2.15 }

local IsScriptActive = true
local playerDrawings = {}
local ChamsObjects = {}

--------------------------------------------------------------------------------
-- СИСТЕМА КОНФИГУРАЦИИ (SAVE/LOAD)
--------------------------------------------------------------------------------
local function saveConfig()
    if not writefile then return end
    local success, encoded = pcall(function()
        local data = {}
        for k, v in pairs(FeatureState) do
            if typeof(v) == "Color3" then
                data[k] = {v.R, v.G, v.B}
            else
                data[k] = v
            end
        end
        return HttpService:JSONEncode(data)
    end)
    if success then
        writefile(CONFIG_FILE, encoded)
    end
end

local function loadConfig()
    if not readfile or not isfile or not isfile(CONFIG_FILE) then return end
    local success, decoded = pcall(function()
        return HttpService:JSONDecode(readfile(CONFIG_FILE))
    end)
    if success and type(decoded) == "table" then
        for k, v in pairs(decoded) do
            if type(v) == "table" and #v == 3 then
                FeatureState[k] = Color3.new(v[1], v[2], v[3])
            else
                FeatureState[k] = v
            end
        end
    end
end

loadConfig() -- Авто-загрузка при старте

--------------------------------------------------------------------------------
-- NIMB (НИМБ НАД ГОЛОВОЙ) СИСТЕМА — Безопасное создание в Camera
--------------------------------------------------------------------------------
local NimbColor = FeatureState.NimbColor
local NimbHalo = nil
local NimbHead = nil
local NimbSegments = {}
local RING_HEIGHT = NIMB_HEIGHT_MAP[FeatureState.NimbHeight] or 1.75
local NIMB_SPIN_SPEED = 0.8

local function setBloom(enabled)
    local lighting = game:GetService("Lighting")
    local b = lighting:FindFirstChild("NimbBloom")
    if enabled and not b then
        local bloom = Instance.new("BloomEffect")
        bloom.Name = "NimbBloom"
        bloom.Intensity = 1.3
        bloom.Size = 28
        bloom.Threshold = 0.85
        bloom.Parent = lighting
    elseif not enabled and b then
        b:Destroy()
    end
end

local function addRing(halo, radiusX, radiusZ, segmentsCount, thickness, width, segLen, list)
    for i = 1, segmentsCount do
        local a = (i - 1) * (2 * math.pi / segmentsCount)
        local cosA, sinA = math.cos(a), math.sin(a)
        local tangent = Vector3.new(-radiusX * sinA, 0, radiusZ * cosA).Unit
        local radial = Vector3.new(radiusX * cosA, 0, radiusZ * sinA).Unit
        local pos = Vector3.new(radiusX * cosA, 0, radiusZ * sinA)
        local cf = CFrame.new(
            pos.X, pos.Y, pos.Z,
            tangent.X, 0, -radial.X,
            tangent.Y, 1, -radial.Y,
            tangent.Z, 0, -radial.Z
        )
        local seg = Instance.new("Part")
        seg.Shape = Enum.PartType.Block
        seg.Size = Vector3.new(segLen, thickness, width)
        seg.Material = Enum.Material.Neon
        seg.Color = NimbColor
        seg.Anchored = true
        seg.CanCollide = false
        seg.CanQuery = false
        seg.CanTouch = false
        seg.CastShadow = false
        seg.Parent = halo
        table.insert(list, { Part = seg, Local = cf })
    end
end

local function destroyNimb()
    if NimbHalo then
        NimbHalo:Destroy()
        NimbHalo = nil
    end
    NimbHead = nil
    NimbSegments = {}
    setBloom(false)
end

local function buildNimb(character)
    destroyNimb()
    setBloom(true)
    local head = character:FindFirstChild("Head")
    if not head then return end
    
    -- Спавним в Camera, чтобы скрыть от серверных проверок античита
    local halo = Instance.new("Model")
    halo.Name = "NimbHalo"
    
    local list = {}
    addRing(halo, 1.0, 0.9, 44, 0.26, 0.34, 0.32, list)

    local center = Instance.new("Part")
    center.Name = "Center"
    center.Anchored = true
    center.CanCollide = false
    center.CanQuery = false
    center.CanTouch = false
    center.Transparency = 1
    center.Size = Vector3.new(0.2, 0.2, 0.2)
    center.CastShadow = false
    center.Parent = halo

    local light = Instance.new("PointLight")
    light.Color = NimbColor
    light.Brightness = 1.0
    light.Range = 6
    light.Shadows = false
    light.Parent = center

    local spark = Instance.new("Part")
    spark.Name = "Spark"
    spark.Anchored = true
    spark.CanCollide = false
    spark.CanQuery = false
    spark.CanTouch = false
    spark.Transparency = 1
    spark.Size = Vector3.new(0.2, 0.2, 0.2)
    spark.CastShadow = false
    spark.Parent = halo

    local emitter = Instance.new("ParticleEmitter")
    emitter.Rate = 25
    emitter.Lifetime = NumberRange.new(0.6, 1.2)
    emitter.Speed = NumberRange.new(0.5, 1.5)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.07),
        NumberSequenceKeypoint.new(1, 0)
    })
    emitter.Color = ColorSequence.new(NimbColor)
    emitter.LightEmission = 1
    emitter.LightInfluence = 0
    emitter.Parent = spark

    table.insert(list, { Part = center, Local = CFrame.new() })
    table.insert(list, { Part = spark, Local = CFrame.new(1.0, 0, 0) })
    
    halo.Parent = Camera -- Безопасный родитель
    NimbHalo = halo
    NimbHead = head
    NimbSegments = list
end

local function setNimb(enabled)
    FeatureState.Nimb = enabled
    saveConfig()
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
    saveConfig()
    if NimbHalo then
        for _, data in ipairs(NimbSegments) do
            data.Part.Color = col
        end
        local light = NimbHalo:FindFirstChildWhichIsA("PointLight", true)
        if light then light.Color = col end
        local emitter = NimbHalo:FindFirstChildWhichIsA("ParticleEmitter", true)
        if emitter then emitter.Color = ColorSequence.new(col) end
    end
end

LocalPlayer.CharacterAdded:Connect(function(character)
    if not FeatureState.Nimb then return end
    task.spawn(function()
        character:WaitForChild("Head")
        if FeatureState.Nimb then buildNimb(character) end
    end)
end)

if FeatureState.Nimb and LocalPlayer.Character then
    task.spawn(function()
        LocalPlayer.Character:WaitForChild("Head")
        if FeatureState.Nimb then buildNimb(LocalPlayer.Character) end
    end)
end

RunService.RenderStepped:Connect(function()
    if FeatureState.Nimb and (not NimbHalo or not NimbHalo.Parent) then
        local chr = LocalPlayer.Character
        if chr and chr:FindFirstChild("Head") then buildNimb(chr) end
    end
    if not NimbHalo or not NimbHead or not NimbHead.Parent then return end
    local t = tick()
    local bob = math.sin(t * 2.2) * 0.12
    local spin = CFrame.Angles(0, t * NIMB_SPIN_SPEED, 0)
    
    local look = NimbHead.CFrame.LookVector
    local back = Vector3.new(look.X, 0, look.Z)
    if back.Magnitude > 0.001 then back = back.Unit end
    local basePos = NimbHead.Position - back * 0.13 + Vector3.new(0, RING_HEIGHT + bob, 0)
    local anchor = CFrame.new(basePos) * spin
    
    for _, data in ipairs(NimbSegments) do
        data.Part.CFrame = anchor * data.Local
    end
end)

--------------------------------------------------------------------------------
-- СИСТЕМА ОЧИСТКИ
--------------------------------------------------------------------------------
local function cleanupScript()
    IsScriptActive = false
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        local oldMenu = pg:FindFirstChild(GUI_NAME)
        if oldMenu then oldMenu:Destroy() end
    end
    for player, drawings in pairs(playerDrawings) do
        for _, d in pairs(drawings) do
            if typeof(d) == "table" then
                for _, sub in pairs(d) do
                    if sub.Line then sub.Line:Remove() end
                end
            elseif d.Remove then
                d:Remove()
            end
        end
    end
    for _, highlight in pairs(ChamsObjects) do
        if highlight then highlight:Destroy() end
    end
    playerDrawings = {}
    ChamsObjects = {}
    destroyNimb()
end

if getgenv().CurrentSimScript and getgenv().CurrentSimScript.Exit then
    getgenv().CurrentSimScript.Exit()
end
getgenv().CurrentSimScript.Exit = cleanupScript

--------------------------------------------------------------------------------
-- GUI МЕНЮ & ДИЗАЙН
--------------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = GUI_NAME
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

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
                WM_Text.Text = string.format("Wibe Ware | %d FPS | %dms", currentFPS, pingVal)
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
-- DRAGGING & RESIZING
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

local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 32)
TopBar.BackgroundTransparency = 1
TopBar.ZIndex = 11
TopBar.Parent = MainFrame

local GlowLabel1 = Instance.new("TextLabel")
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
VisualsPage.ZIndex = 12
VisualsPage.CanvasSize = UDim2.new(0, 0, 0, 420)
VisualsPage.ScrollBarThickness = 3
VisualsPage.Parent = ContentArea

local VisualsTabBtn = Instance.new("TextButton")
VisualsTabBtn.Size = UDim2.new(0.9, 0, 0, 24)
VisualsTabBtn.Position = UDim2.new(0.05, 0, 0, 8)
VisualsTabBtn.BackgroundColor3 = Color3.fromRGB(38, 38, 52)
VisualsTabBtn.Text = "Visuals"
VisualsTabBtn.TextColor3 = Color3.fromRGB(0, 210, 255)
VisualsTabBtn.Font = Enum.Font.GothamBold
VisualsTabBtn.TextSize = 11
VisualsTabBtn.ZIndex = 13
VisualsTabBtn.Parent = Sidebar

local TabCorner = Instance.new("UICorner")
TabCorner.CornerRadius = UDim.new(0, 5)
TabCorner.Parent = VisualsTabBtn

local ResizeGrip = Instance.new("TextButton")
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
-- COLOR PICKER SYSTEM
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

local CP_TopBar = Instance.new("Frame")
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

local CP_CloseBtn = Instance.new("TextButton")
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

local PaletteBox = Instance.new("ImageButton")
PaletteBox.Size = UDim2.new(0, 180, 0, 160)
PaletteBox.Position = UDim2.new(0, 10, 0, 35)
PaletteBox.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
PaletteBox.BorderSizePixel = 0
PaletteBox.AutoButtonColor = false
PaletteBox.ZIndex = 101
PaletteBox.Parent = ColorPickerGui

local SatGrad = Instance.new("Frame")
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
HueSlider.Size = UDim2.new(0, 22, 0, 160)
HueSlider.Position = UDim2.new(0, 200, 0, 35)
HueSlider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
HueSlider.BorderSizePixel = 0
HueSlider.AutoButtonColor = false
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

local OriginalPreview = Instance.new("Frame")
OriginalPreview.Size = UDim2.new(0, 36, 0, 24)
OriginalPreview.Position = UDim2.new(0, 200, 0, 246)
OriginalPreview.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
OriginalPreview.BorderSizePixel = 0
OriginalPreview.ZIndex = 101
OriginalPreview.Parent = ColorPickerGui

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
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 4)
    c.Parent = box
    return box
end

local BoxR = createColorInput(10, 202, 54)
local BoxG = createColorInput(70, 202, 54)
local BoxB = createColorInput(130, 202, 54)
local BoxHex = createColorInput(10, 230, 174)
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
    BoxHex.Text = "#" .. string.format("%02X%02X%02X", math.floor(col.R*255+0.5), math.floor(col.G*255+0.5), math.floor(col.B*255+0.5))
    if activeColorCallback then
        activeColorCallback(col)
    end
end

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
                TweenService:Create(obj, tweenInfo, { BackgroundTransparency = targetTransparency }):Play()
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
    local closeTween = TweenService:Create(ColorPickerGui, closeTweenInfo, { Size = UDim2.new(0, 180, 0, 210) })
    animateColorPicker(1, 0.25)
    closeTween:Play()
    closeTween.Completed:Connect(function()
        ColorPickerGui.Visible = false
        cpAnimating = false
        saveConfig() -- Сохраняем цвет после закрытия пикера
    end)
end
CP_CloseBtn.MouseButton1Click:Connect(closeColorPicker)

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
    local openTween = TweenService:Create(ColorPickerGui, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(0, 260, 0, 310) })
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
-- MENU TOGGLE AND DRAG
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

local resetToVisuals
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
        if resetToVisuals then resetToVisuals() end
        animateTransparency(1, 0)
        local sizeTween = TweenService:Create(MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = savedPosition, Size = targetSize, AnchorPoint = Vector2.new(0.5, 0.5) })
        animateTransparency(0, 0.35)
        sizeTween:Play()
        sizeTween.Completed:Connect(function() isAnimating = false end)
    else
        savedPosition = MainFrame.Position
        targetSize = MainFrame.Size
        MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
        local closeTween = TweenService:Create(MainFrame, TweenInfo.new(0.32, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), { Position = UDim2.new(0, 20, 1, -20), Size = UDim2.new(0, 100, 0, 60), AnchorPoint = Vector2.new(0, 1) })
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
    if not wmDragging then toggleMenu() end
end)

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
        local targetPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        MainFrame.Position = targetPos
        savedPosition = targetPos
    end
end)

--------------------------------------------------------------------------------
-- SETTINGS PANEL WITH COLLAPSIBLE SECTIONS
--------------------------------------------------------------------------------
local SettingsPage = Instance.new("ScrollingFrame")
SettingsPage.Name = "SettingsPage"
SettingsPage.Size = UDim2.new(1, 0, 1, 0)
SettingsPage.BackgroundTransparency = 1
SettingsPage.BorderSizePixel = 0
SettingsPage.Visible = false
SettingsPage.ZIndex = 12
SettingsPage.ScrollBarThickness = 3
SettingsPage.CanvasSize = UDim2.new(0, 0, 0, 0)
SettingsPage.AutomaticCanvasSize = Enum.AutomaticSize.Y
SettingsPage.Parent = ContentArea

local SettingsLayout = Instance.new("UIListLayout")
SettingsLayout.FillDirection = Enum.FillDirection.Vertical
SettingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
SettingsLayout.Padding = UDim.new(0, 6)
SettingsLayout.Parent = SettingsPage

local SettingsHeader = Instance.new("Frame")
SettingsHeader.Size = UDim2.new(1, 0, 0, 26)
SettingsHeader.BackgroundTransparency = 1
SettingsHeader.LayoutOrder = 0
SettingsHeader.ZIndex = 13
SettingsHeader:SetAttribute("BaseTransparency", 1)
SettingsHeader.Parent = SettingsPage

local BackBtn = Instance.new("TextButton")
BackBtn.Size = UDim2.new(0, 54, 0, 22)
BackBtn.Position = UDim2.new(0, 0, 0, 2)
BackBtn.BackgroundColor3 = Color3.fromRGB(38, 38, 52)
BackBtn.AutoButtonColor = false
BackBtn.Text = "← Back"
BackBtn.TextColor3 = Color3.fromRGB(0, 210, 255)
BackBtn.Font = Enum.Font.GothamBold
BackBtn.TextSize = 11
BackBtn.ZIndex = 14
BackBtn.Parent = SettingsHeader

local BackCorner = Instance.new("UICorner")
BackCorner.CornerRadius = UDim.new(0, 5)
BackCorner.Parent = BackBtn

local SettingsTitle = Instance.new("TextLabel")
SettingsTitle.Size = UDim2.new(1, -60, 1, 0)
SettingsTitle.Position = UDim2.new(0, 62, 0, 0)
SettingsTitle.BackgroundTransparency = 1
SettingsTitle.Text = "Settings"
SettingsTitle.TextColor3 = Color3.fromRGB(240, 240, 245)
SettingsTitle.Font = Enum.Font.GothamBold
SettingsTitle.TextSize = 14
SettingsTitle.TextXAlignment = Enum.TextXAlignment.Left
SettingsTitle.ZIndex = 14
SettingsTitle.Parent = SettingsHeader

local currentSections = {}
local settingsOrder = 0

local function createSection(title, defaultExpanded)
    settingsOrder = settingsOrder + 1
    local section = Instance.new("Frame")
    section.Size = UDim2.new(1, 0, 0, 28)
    section.AutomaticSize = Enum.AutomaticSize.Y
    section.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
    section.BorderSizePixel = 0
    section.LayoutOrder = settingsOrder
    section.ZIndex = 13
    section:SetAttribute("BaseTransparency", 0)
    section.Parent = SettingsPage

    local sectionCorner = Instance.new("UICorner")
    sectionCorner.CornerRadius = UDim.new(0, 6)
    sectionCorner.Parent = section

    local sectionLayout = Instance.new("UIListLayout")
    sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sectionLayout.Padding = UDim.new(0, 6)
    sectionLayout.Parent = section

    local sectionPad = Instance.new("UIPadding")
    sectionPad.PaddingTop = UDim.new(0, 4)
    sectionPad.PaddingBottom = UDim.new(0, 6)
    sectionPad.PaddingLeft = UDim.new(0, 8)
    sectionPad.PaddingRight = UDim.new(0, 8)
    sectionPad.Parent = section

    local header = Instance.new("TextButton")
    header.Size = UDim2.new(1, 0, 0, 20)
    header.BackgroundTransparency = 1
    header.AutoButtonColor = false
    header.Text = (defaultExpanded and "▾ " or "▸ ") .. title
    header.TextColor3 = Color3.fromRGB(0, 210, 255)
    header.Font = Enum.Font.GothamBold
    header.TextSize = 12
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.LayoutOrder = 1
    header.ZIndex = 14
    header:SetAttribute("BaseTransparency", 1)
    header.Parent = section

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, 0, 0, 0)
    content.AutomaticSize = Enum.AutomaticSize.Y
    content.BackgroundTransparency = 1
    content.LayoutOrder = 2
    content.Visible = defaultExpanded
    content.ZIndex = 13
    content:SetAttribute("BaseTransparency", 1)
    content.Parent = section

    local contentLayout = Instance.new("UIListLayout")
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.Padding = UDim.new(0, 4)
    contentLayout.Parent = content

    header.MouseButton1Click:Connect(function()
        if not IsScriptActive then return end
        content.Visible = not content.Visible
        header.Text = (content.Visible and "▾ " or "▸ ") .. title
    end)
    table.insert(currentSections, section)
    return content
end

local function addOptionRow(content, label, options, getCurrent, onSelect)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 20)
    row.BackgroundTransparency = 1
    row.LayoutOrder = #content:GetChildren() + 1
    row.ZIndex = 14
    row:SetAttribute("BaseTransparency", 1)
    row.Parent = content

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.42, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(215, 215, 225)
    lbl.Font = Enum.Font.SourceSansSemibold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 14
    lbl.Parent = row

    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(0.58, 0, 1, 0)
    holder.Position = UDim2.new(0.42, 0, 0, 0)
    holder.BackgroundTransparency = 1
    holder.ZIndex = 14
    holder:SetAttribute("BaseTransparency", 1)
    holder.Parent = row

    local holderLayout = Instance.new("UIListLayout")
    holderLayout.FillDirection = Enum.FillDirection.Horizontal
    holderLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    holderLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    holderLayout.SortOrder = Enum.SortOrder.LayoutOrder
    holderLayout.Padding = UDim.new(0, 4)
    holderLayout.Parent = holder

    local buttons = {}
    local function refresh()
        for _, b in ipairs(buttons) do
            local active = (getCurrent() == b.Name)
            b.BackgroundColor3 = active and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(45, 45, 58)
            b.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 195)
        end
    end

    for _, opt in ipairs(options) do
        local b = Instance.new("TextButton")
        b.Name = opt
        b.Size = UDim2.new(0, 52, 0, 18)
        b.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
        b.AutoButtonColor = false
        b.Text = opt
        b.TextColor3 = Color3.fromRGB(180, 180, 195)
        b.Font = Enum.Font.Gotham
        b.TextSize = 10
        b.ZIndex = 15
        b.Parent = holder
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 4)
        bc.Parent = b

        b.MouseButton1Click:Connect(function()
            if not IsScriptActive then return end
            onSelect(opt)
            saveConfig()
            refresh()
        end)
        table.insert(buttons, b)
    end
    refresh()
    return row
end

local function addColorRow(content, label, getColor, setColor)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 20)
    row.BackgroundTransparency = 1
    row.LayoutOrder = #content:GetChildren() + 1
    row.ZIndex = 14
    row:SetAttribute("BaseTransparency", 1)
    row.Parent = content

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.6, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(215, 215, 225)
    lbl.Font = Enum.Font.SourceSansSemibold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 14
    lbl.Parent = row

    local colorBtn = Instance.new("TextButton")
    colorBtn.Size = UDim2.new(0, 28, 0, 18)
    colorBtn.Position = UDim2.new(1, -28, 0.5, -9)
    colorBtn.BackgroundColor3 = getColor()
    colorBtn.AutoButtonColor = false
    colorBtn.Text = ""
    colorBtn.ZIndex = 15
    colorBtn.Parent = row

    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 4)
    cc.Parent = colorBtn

    local cs = Instance.new("UIStroke")
    cs.Color = Color3.fromRGB(70, 70, 90)
    cs.Thickness = 1
    cs.Parent = colorBtn

    colorBtn.MouseButton1Click:Connect(function()
        if not IsScriptActive then return end
        openColorPicker(colorBtn.BackgroundColor3, function(newCol)
            colorBtn.BackgroundColor3 = newCol
            setColor(newCol)
        end)
    end)
    return row
end

local function addInfoRow(content, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 0)
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(150, 150, 170)
    lbl.Font = Enum.Font.SourceSans
    lbl.TextSize = 11
    lbl.TextWrapped = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = #content:GetChildren() + 1
    lbl.ZIndex = 14
    lbl.Parent = content
    return lbl
end

local FeatureTitles = {
    BoxESPBtn = "Box ESP",
    HealthBarBtn = "Health Bar",
    SkeletonBtn = "Skeleton",
    NimbBtn = "Nimb",
    NameBtn = "Name ESP",
    DistanceBtn = "Distance",
    TracerBtn = "Tracers",
    TeamCheckBtn = "Team Check",
    ChamsBtn = "Chams ESP"
}

local FeatureSettings = {}
FeatureSettings.BoxESPBtn = function()
    local c1 = createSection("Color", true)
    addColorRow(c1, "Box color", function() return FeatureState.BoxColor end, function(v) FeatureState.BoxColor = v end)
    local c2 = createSection("Style", true)
    addOptionRow(c2, "Box style", {"Outline", "Filled"}, function() return FeatureState.BoxStyle end, function(v) FeatureState.BoxStyle = v end)
    local c3 = createSection("Thickness", false)
    addOptionRow(c3, "Line", {"Thin", "Normal", "Thick"}, function() return FeatureState.BoxThickness end, function(v) FeatureState.BoxThickness = v end)
end

FeatureSettings.HealthBarBtn = function()
    local c1 = createSection("Color", true)
    addColorRow(c1, "Health color", function() return FeatureState.HealthColor end, function(v) FeatureState.HealthColor = v end)
    local c2 = createSection("Position", true)
    addOptionRow(c2, "Bar side", {"Left", "Right"}, function() return FeatureState.HealthSide end, function(v) FeatureState.HealthSide = v end)
end

FeatureSettings.SkeletonBtn = function()
    local c1 = createSection("Color", true)
    addColorRow(c1, "Skeleton color", function() return FeatureState.SkeletonColor end, function(v) FeatureState.SkeletonColor = v end)
    local c2 = createSection("Thickness", false)
    addOptionRow(c2, "Line", {"Thin", "Normal", "Thick"}, function() return FeatureState.SkelThickness end, function(v) FeatureState.SkelThickness = v end)
end

FeatureSettings.NimbBtn = function()
    local c1 = createSection("Color", true)
    addColorRow(c1, "Nimb color", function() return FeatureState.NimbColor end, function(v) setNimbColor(v) end)
    local c2 = createSection("Height", true)
    addOptionRow(c2, "Ring height", {"Low", "Normal", "High"}, function() return FeatureState.NimbHeight end, function(v) FeatureState.NimbHeight = v RING_HEIGHT = NIMB_HEIGHT_MAP[v] or 1.75 end)
end

FeatureSettings.NameBtn = function()
    local c1 = createSection("Color", true)
    addColorRow(c1, "Name color", function() return FeatureState.NameColor end, function(v) FeatureState.NameColor = v end)
    local c2 = createSection("Size", true)
    addOptionRow(c2, "Text size", {"Small", "Normal", "Large"}, function() return FeatureState.NameSize end, function(v) FeatureState.NameSize = v end)
end

FeatureSettings.DistanceBtn = function()
    local c1 = createSection("Color", true)
    addColorRow(c1, "Distance color", function() return FeatureState.DistanceColor end, function(v) FeatureState.DistanceColor = v end)
    local c2 = createSection("Unit", true)
    addOptionRow(c2, "Unit", {"Studs", "Meters"}, function() return FeatureState.DistanceUnit end, function(v) FeatureState.DistanceUnit = v end)
end

FeatureSettings.TracerBtn = function()
    local c1 = createSection("Line type", true)
    addOptionRow(c1, "Origin", {"Top", "Middle", "Bottom"}, function() return FeatureState.TracerOrigin end, function(v) FeatureState.TracerOrigin = v end)
    local c2 = createSection("Color", true)
    addColorRow(c2, "Line color", function() return FeatureState.TracerColor end, function(v) FeatureState.TracerColor = v end)
    local c3 = createSection("Thickness", false)
    addOptionRow(c3, "Line", {"Thin", "Normal", "Thick"}, function() return FeatureState.TracerThickness end, function(v) FeatureState.TracerThickness = v end)
end

FeatureSettings.TeamCheckBtn = function()
    local c1 = createSection("Info", true)
    addInfoRow(c1, "Когда включено, ESP показывается только для врагов. Игроки вашей команды скрываются.")
end

FeatureSettings.ChamsBtn = function()
    local c1 = createSection("Colors", true)
    addColorRow(c1, "Fill Color", function() return FeatureState.ChamsColor end, function(v) FeatureState.ChamsColor = v end)
    addColorRow(c1, "Outline Color", function() return FeatureState.ChamsOutlineColor end, function(v) FeatureState.ChamsOutlineColor = v end)
end

local function clearSettings()
    for _, s in ipairs(currentSections) do s:Destroy() end
    currentSections = {}
    settingsOrder = 0
end

local function openFeatureSettings(key)
    clearSettings()
    local builder = FeatureSettings[key]
    if builder then builder() end
    SettingsTitle.Text = FeatureTitles[key] or "Settings"
    VisualsPage.Visible = false
    SettingsPage.Visible = true
    SettingsPage.CanvasPosition = Vector2.new(0, 0)
end

BackBtn.MouseButton1Click:Connect(function()
    if not IsScriptActive then return end
    SettingsPage.Visible = false
    VisualsPage.Visible = true
end)

resetToVisuals = function()
    SettingsPage.Visible = false
    VisualsPage.Visible = true
end

--------------------------------------------------------------------------------
-- TOGGLE BUILDERS
--------------------------------------------------------------------------------
local function createToggleRow(parentPage, name, text, positionY, initialColor, onClick, onColorChange, settingsKey)
    local rowFrame = Instance.new("Frame")
    rowFrame.Name = name .. "Row"
    rowFrame.Size = UDim2.new(1, 0, 0, 34)
    rowFrame.Position = UDim2.new(0, 0, 0, positionY)
    rowFrame.BackgroundTransparency = 1
    rowFrame.ZIndex = 13
    rowFrame.Parent = parentPage

    local label = Instance.new("TextLabel")
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
    colorBtn.Size = UDim2.new(0, 24, 0, 18)
    colorBtn.Position = UDim2.new(1, -90, 0.5, -9)
    colorBtn.BackgroundColor3 = initialColor or Color3.fromRGB(60, 60, 70)
    colorBtn.AutoButtonColor = false
    colorBtn.Text = ""
    colorBtn.ZIndex = 14
    colorBtn.Parent = rowFrame

    if initialColor == nil then colorBtn.Visible = false end
    
    colorBtn.MouseButton1Click:Connect(function()
        if not IsScriptActive then return end
        openColorPicker(colorBtn.BackgroundColor3, function(newCol)
            colorBtn.BackgroundColor3 = newCol
            if onColorChange then onColorChange(newCol) end
        end)
    end)

    if settingsKey then
        local gearBtn = Instance.new("TextButton")
        gearBtn.Size = UDim2.new(0, 22, 0, 22)
        gearBtn.Position = UDim2.new(1, -122, 0.5, -11)
        gearBtn.BackgroundColor3 = Color3.fromRGB(38, 38, 52)
        gearBtn.AutoButtonColor = false
        gearBtn.Text = "⚙"
        gearBtn.TextColor3 = Color3.fromRGB(0, 210, 255)
        gearBtn.Font = Enum.Font.GothamBold
        gearBtn.TextSize = 13
        gearBtn.ZIndex = 15
        gearBtn.Parent = rowFrame

        local gearCorner = Instance.new("UICorner")
        gearCorner.CornerRadius = UDim.new(0, 6)
        gearCorner.Parent = gearBtn

        gearBtn.MouseEnter:Connect(function()
            TweenService:Create(gearBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(0, 120, 170) }):Play()
        end)
        gearBtn.MouseLeave:Connect(function()
            TweenService:Create(gearBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(38, 38, 52) }):Play()
        end)
        gearBtn.MouseButton1Click:Connect(function()
            if not IsScriptActive then return end
            openFeatureSettings(settingsKey)
        end)
    end

    local track = Instance.new("TextButton")
    track.Size = UDim2.new(0, 46, 0, 22)
    track.Position = UDim2.new(1, -56, 0.5, -11)
    track.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
    track.Text = ""
    track.AutoButtonColor = false
    track.ZIndex = 14
    track.Parent = rowFrame

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(180, 180, 195)
    knob.ZIndex = 15
    knob.Parent = track

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    -- Чтение загруженного конфига для установки тумблера
    local loadedState = FeatureState[name:gsub("Btn", "")] or false
    local enabled = loadedState
    if enabled then
        track.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
        knob.Position = UDim2.new(1, -19, 0.5, -8)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    end

    track.MouseButton1Click:Connect(function()
        if not IsScriptActive then return end
        enabled = not enabled
        local targetTrackColor = enabled and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(45, 45, 58)
        local targetKnobPos = enabled and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        local targetKnobColor = enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 195)
        TweenService:Create(track, TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { BackgroundColor3 = targetTrackColor }):Play()
        TweenService:Create(knob, TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { Position = targetKnobPos, BackgroundColor3 = targetKnobColor }):Play()
        onClick(enabled)
        saveConfig()
    end)
end

-- Создаем элементы в списке Visuals
createToggleRow(VisualsPage, "BoxESP", "Box ESP", 10, FeatureState.BoxColor, function(s) FeatureState.BoxESP = s end, function(c) FeatureState.BoxColor = c end, "BoxESPBtn")
createToggleRow(VisualsPage, "HealthBar", "Health Bar", 50, FeatureState.HealthColor, function(s) FeatureState.HealthBar = s end, function(c) FeatureState.HealthColor = c end, "HealthBarBtn")
createToggleRow(VisualsPage, "SkeletonESP", "White Skeleton", 90, FeatureState.SkeletonColor, function(s) FeatureState.SkeletonESP = s end, function(c) FeatureState.SkeletonColor = c end, "SkeletonBtn")
createToggleRow(VisualsPage, "Nimb", "Nimb (Glow)", 130, FeatureState.NimbColor, setNimb, setNimbColor, "NimbBtn")
createToggleRow(VisualsPage, "NameESP", "Name ESP", 170, FeatureState.NameColor, function(s) FeatureState.NameESP = s end, function(c) FeatureState.NameColor = c end, "NameBtn")
createToggleRow(VisualsPage, "DistanceESP", "Distance", 210, FeatureState.DistanceColor, function(s) FeatureState.DistanceESP = s end, function(c) FeatureState.DistanceColor = c end, "DistanceBtn")
createToggleRow(VisualsPage, "TracerESP", "Tracers", 250, FeatureState.TracerColor, function(s) FeatureState.TracerESP = s end, function(c) FeatureState.TracerColor = c end, "TracerBtn")
createToggleRow(VisualsPage, "Chams", "Chams (Wallhack)", 290, FeatureState.ChamsColor, function(s) FeatureState.Chams = s end, function(c) FeatureState.ChamsColor = c end, "ChamsBtn")
createToggleRow(VisualsPage, "TeamCheck", "Team Check", 330, nil, function(s) FeatureState.TeamCheck = s end, nil, "TeamCheckBtn")

local ExitBtn = Instance.new("TextButton")
ExitBtn.Size = UDim2.new(1, -20, 0, 30)
ExitBtn.Position = UDim2.new(0, 10, 0, 375)
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
ExitBtn.MouseButton1Click:Connect(cleanupScript)

--------------------------------------------------------------------------------
-- ОПТИМИЗИРОВАННАЯ СИСТЕМА ESP & CHAMS
--------------------------------------------------------------------------------
local function getOrCreateDrawings(player)
    if playerDrawings[player] then return playerDrawings[player] end
    local box = Drawing.new("Square")
    box.Visible = false
    box.Thickness = 1.5
    box.Filled = false

    local healthBg = Drawing.new("Square")
    healthBg.Visible = false
    healthBg.Color = Color3.fromRGB(0, 0, 0)
    healthBg.Filled = true

    local healthFill = Drawing.new("Square")
    healthFill.Visible = false
    healthFill.Filled = true

    local nameText = Drawing.new("Text")
    nameText.Visible = false
    nameText.Center = true
    nameText.Outline = true
    nameText.OutlineColor = Color3.fromRGB(0, 0, 0)
    nameText.Font = 2

    local distanceText = Drawing.new("Text")
    distanceText.Visible = false
    distanceText.Center = true
    distanceText.Outline = true
    distanceText.OutlineColor = Color3.fromRGB(0, 0, 0)
    distanceText.Font = 2

    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Thickness = 1.5

    local skeletonLines = {}
    local connections = {
        {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
        {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"},
        {"LeftLowerArm", "LeftHand"}, {"UpperTorso", "RightUpperArm"},
        {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
        {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"},
        {"LeftLowerLeg", "LeftFoot"}, {"LowerTorso", "RightUpperLeg"},
        {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}
    }
    for _, conn in ipairs(connections) do
        local line = Drawing.new("Line")
        line.Visible = false
        table.insert(skeletonLines, {Line = line, FromPart = conn[1], ToPart = conn[2]})
    end

    local elements = {
        Box = box, HealthBg = healthBg, HealthFill = healthFill,
        NameText = nameText, DistanceText = distanceText, Tracer = tracer,
        SkeletonLines = skeletonLines
    }
    playerDrawings[player] = elements
    return elements
end

local function removeDrawings(player)
    local drawings = playerDrawings[player]
    if drawings then
        if drawings.Box then drawings.Box:Remove() end
        if drawings.HealthBg then drawings.HealthBg:Remove() end
        if drawings.HealthFill then drawings.HealthFill:Remove() end
        if drawings.NameText then drawings.NameText:Remove() end
        if drawings.DistanceText then drawings.DistanceText:Remove() end
        if drawings.Tracer then drawings.Tracer:Remove() end
        if drawings.SkeletonLines then
            for _, item in pairs(drawings.SkeletonLines) do
                if item.Line then item.Line:Remove() end
            end
        end
        playerDrawings[player] = nil
    end
    if ChamsObjects[player] then
        ChamsObjects[player]:Destroy()
        ChamsObjects[player] = nil
    end
end

Players.PlayerRemoving:Connect(removeDrawings)

-- Оптимизированный RenderStepped цикл
RunService.RenderStepped:Connect(function()
    if not IsScriptActive then return end
    
    local cameraPos = Camera.CFrame.Position
    local viewportSize = Camera.ViewportSize
    local screenCenter = Vector2.new(viewportSize.X / 2, viewportSize.Y)

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        
        local character = player.Character
        local drawings = getOrCreateDrawings(player)
        
        local function hideAll()
            drawings.Box.Visible = false
            drawings.HealthBg.Visible = false
            drawings.HealthFill.Visible = false
            drawings.NameText.Visible = false
            drawings.DistanceText.Visible = false
            drawings.Tracer.Visible = false
            for _, item in ipairs(drawings.SkeletonLines) do item.Line.Visible = false end
            if ChamsObjects[player] then ChamsObjects[player].Enabled = false end
        end

        local isTeammate = FeatureState.TeamCheck and player.Team ~= nil and LocalPlayer.Team ~= nil and player.Team == LocalPlayer.Team
        
        if isTeammate or not character then
            hideAll()
            continue
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        local head = character:FindFirstChild("Head")

        if not humanoid or not rootPart or not head or humanoid.Health <= 0 then
            hideAll()
            continue
        end

        -- Одиночный вызов проецирования на экран для оптимизации
        local rootScreenPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
        if not onScreen then
            hideAll()
            continue
        end

        -- Кастомный Chams (Highlight)
        if FeatureState.Chams then
            local hl = ChamsObjects[player]
            if not hl or hl.Parent ~= character then
                if hl then hl:Destroy() end
                hl = Instance.new("Highlight")
                hl.Parent = character
                ChamsObjects[player] = hl
            end
            hl.Enabled = true
            hl.FillColor = FeatureState.ChamsColor
            hl.OutlineColor = FeatureState.ChamsOutlineColor
            hl.FillTransparency = FeatureState.ChamsFillTrans
            hl.OutlineTransparency = FeatureState.ChamsOutlineTrans
        else
            if ChamsObjects[player] then ChamsObjects[player].Enabled = false end
        end

        -- Предварительно рассчитываем верхнюю и нижнюю точки игрока
        local topScreen, topVis = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.8, 0))
        local bottomScreen, bottomVis = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))

        if topVis and bottomVis then
            local boxHeight = math.abs(bottomScreen.Y - topScreen.Y)
            local boxWidth = boxHeight / 2
            local boxX = topScreen.X - boxWidth / 2

            -- Box ESP
            if FeatureState.BoxESP then
                drawings.Box.Color = FeatureState.BoxColor
                drawings.Box.Thickness = THICKNESS_MAP[FeatureState.BoxThickness] or 1.5
                drawings.Box.Filled = (FeatureState.BoxStyle == "Filled")
                drawings.Box.Transparency = (FeatureState.BoxStyle == "Filled") and 0.4 or 1
                drawings.Box.Size = Vector2.new(boxWidth, boxHeight)
                drawings.Box.Position = Vector2.new(boxX, topScreen.Y)
                drawings.Box.Visible = true
            else
                drawings.Box.Visible = false
            end

            -- Health Bar
            if FeatureState.HealthBar then
                drawings.HealthFill.Color = FeatureState.HealthColor
                local x = (FeatureState.HealthSide == "Right") and (topScreen.X + boxWidth / 2 + 3) or (boxX - 6)
                drawings.HealthBg.Size = Vector2.new(3, boxHeight)
                drawings.HealthBg.Position = Vector2.new(x, topScreen.Y)
                drawings.HealthBg.Visible = true

                local pct = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                local fillH = boxHeight * pct
                drawings.HealthFill.Size = Vector2.new(1, fillH)
                drawings.HealthFill.Position = Vector2.new(x + 1, topScreen.Y + (boxHeight - fillH))
                drawings.HealthFill.Visible = true
            else
                drawings.HealthBg.Visible = false
                drawings.HealthFill.Visible = false
            end

            -- Names and Distance
            if FeatureState.NameESP or FeatureState.DistanceESP then
                if FeatureState.NameESP then
                    drawings.NameText.Color = FeatureState.NameColor
                    drawings.NameText.Size = NAME_SIZE_MAP[FeatureState.NameSize] or 14
                    drawings.NameText.Text = player.Name
                    drawings.NameText.Position = Vector2.new(topScreen.X, topScreen.Y - (FeatureState.DistanceESP and 26 or 16))
                    drawings.NameText.Visible = true
                else
                    drawings.NameText.Visible = false
                end

                if FeatureState.DistanceESP then
                    local dist = (cameraPos - rootPart.Position).Magnitude
                    local distText = (FeatureState.DistanceUnit == "Meters") and string.format("%.1f m", dist * 0.28) or string.format("%d studs", math.floor(dist + 0.5))
                    drawings.DistanceText.Color = FeatureState.DistanceColor
                    drawings.DistanceText.Text = distText
                    drawings.DistanceText.Position = Vector2.new(topScreen.X, topScreen.Y - (FeatureState.NameESP and 12 or 16))
                    drawings.DistanceText.Visible = true
                else
                    drawings.DistanceText.Visible = false
                end
            else
                drawings.NameText.Visible = false
                drawings.DistanceText.Visible = false
            end
        else
            drawings.Box.Visible = false
            drawings.HealthBg.Visible = false
            drawings.HealthFill.Visible = false
            drawings.NameText.Visible = false
            drawings.DistanceText.Visible = false
        end

        -- Skeleton (с поддержкой R6/R15)
        if FeatureState.SkeletonESP then
            for _, item in ipairs(drawings.SkeletonLines) do
                local partFrom = character:FindFirstChild(item.FromPart)
                local partTo = character:FindFirstChild(item.ToPart)
                if partFrom and partTo then
                    local p1, v1 = Camera:WorldToViewportPoint(partFrom.Position)
                    local p2, v2 = Camera:WorldToViewportPoint(partTo.Position)
                    if v1 or v2 then
                        item.Line.Color = FeatureState.SkeletonColor
                        item.Line.Thickness = THICKNESS_MAP[FeatureState.SkelThickness] or 1.5
                        item.Line.From = Vector2.new(p1.X, p1.Y)
                        item.Line.To = Vector2.new(p2.X, p2.Y)
                        item.Line.Visible = true
                    else
                        item.Line.Visible = false
                    end
                else
                    item.Line.Visible = false
                end
            end
        else
            for _, item in ipairs(drawings.SkeletonLines) do item.Line.Visible = false end
        end

        -- Tracers
        if FeatureState.TracerESP then
            drawings.Tracer.Color = FeatureState.TracerColor
            drawings.Tracer.Thickness = THICKNESS_MAP[FeatureState.TracerThickness] or 1.5
            local originY = (FeatureState.TracerOrigin == "Top") and 0 or (FeatureState.TracerOrigin == "Middle" and viewportSize.Y / 2 or viewportSize.Y)
            drawings.Tracer.From = Vector2.new(viewportSize.X / 2, originY)
            drawings.Tracer.To = Vector2.new(rootScreenPos.X, rootScreenPos.Y)
            drawings.Tracer.Visible = true
        else
            drawings.Tracer.Visible = false
        end
    end
end)

print("[SYSTEM] Script V.4.8 loaded. Config auto-saved and Chams included.")
