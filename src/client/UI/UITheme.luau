--!strict
--[[
    UITheme.luau
    Central UI Design System for Dark Fantasy / Modern RPG aesthetic.
    
    Standards:
    - Pure procedural creation (no manual Roblox Studio instances).
    - Deep Void Dark palette (#0F111A, #161926).
    - Smooth rounded corners (UICorner).
    - Delicate glowing borders (UIStroke) dynamically tinted by Rarity.
    - Crisp typography (GothamBold).
    - Fluid interactive micro-animations (TweenService) on hover and click.
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Constants = require(Shared:WaitForChild("Constants"))
local RarityConfig = require(Shared:WaitForChild("RarityConfig"))

local UITheme = {}

local TWEEN_INFO_FAST = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_INFO_BOUNCE = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

--[[
    Creates or retrieves the main PlayerGui container.
]]
function UITheme.GetPlayerGui(): PlayerGui
    local localPlayer = Players.LocalPlayer
    local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
    return playerGui
end

--[[
    Creates a protected ScreenGui.
]]
function UITheme.CreateScreenGui(name: string, displayOrder: number?): ScreenGui
    local playerGui = UITheme.GetPlayerGui()
    local existing = playerGui:FindFirstChild(name)
    if existing and existing:IsA("ScreenGui") then
        return existing
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = name
    gui.DisplayOrder = displayOrder or 1
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = playerGui
    return gui
end

--[[
    Creates a Dark Fantasy container frame with rounded corners and subtle stroke.
]]
function UITheme.CreatePanel(config: {
    Name: string?,
    Size: UDim2?,
    Position: UDim2?,
    AnchorPoint: Vector2?,
    BackgroundColor3: Color3?,
    CornerRadius: UDim?,
    StrokeColor: Color3?,
    StrokeThickness: number?,
    Parent: Instance?,
}): Frame
    local frame = Instance.new("Frame")
    frame.Name = config.Name or "Panel"
    frame.Size = config.Size or UDim2.new(0, 200, 0, 100)
    frame.Position = config.Position or UDim2.new(0, 0, 0, 0)
    frame.AnchorPoint = config.AnchorPoint or Vector2.new(0, 0)
    frame.BackgroundColor3 = config.BackgroundColor3 or Constants.THEME.SURFACE_PANEL
    frame.BorderSizePixel = 0

    local corner = Instance.new("UICorner")
    corner.CornerRadius = config.CornerRadius or UDim.new(0, 10)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Name = "PanelStroke"
    stroke.Color = config.StrokeColor or Constants.THEME.STROKE_DEFAULT
    stroke.Thickness = config.StrokeThickness or 1.5
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = frame

    if config.Parent then
        frame.Parent = config.Parent
    end

    return frame
end

--[[
    Creates an interactive Dark Fantasy button with automatic TweenService hover & click feedback.
]]
function UITheme.CreateButton(config: {
    Name: string?,
    Text: string?,
    Size: UDim2?,
    Position: UDim2?,
    AnchorPoint: Vector2?,
    BackgroundColor3: Color3?,
    TextColor3: Color3?,
    TextSize: number?,
    CornerRadius: UDim?,
    StrokeColor: Color3?,
    Parent: Instance?,
    OnClick: (() -> ())?,
}): TextButton
    local button = Instance.new("TextButton")
    button.Name = config.Name or "Button"
    button.Size = config.Size or UDim2.new(0, 160, 0, 44)
    button.Position = config.Position or UDim2.new(0, 0, 0, 0)
    button.AnchorPoint = config.AnchorPoint or Vector2.new(0, 0)
    button.BackgroundColor3 = config.BackgroundColor3 or Constants.THEME.SURFACE_PANEL
    button.AutoButtonColor = false
    button.BorderSizePixel = 0
    button.Font = Constants.THEME.FONT_TITLE
    button.Text = config.Text or "Click"
    button.TextColor3 = config.TextColor3 or Constants.THEME.TEXT_PRIMARY
    button.TextSize = config.TextSize or 15

    local corner = Instance.new("UICorner")
    corner.CornerRadius = config.CornerRadius or UDim.new(0, 8)
    corner.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.Name = "ButtonStroke"
    stroke.Color = config.StrokeColor or Constants.THEME.STROKE_DEFAULT
    stroke.Thickness = 1.2
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = button

    -- Interactive animations
    local baseColor = button.BackgroundColor3
    local hoverColor = Constants.THEME.SURFACE_HOVER
    local activeColor = Constants.THEME.SURFACE_ACTIVE
    local baseStrokeColor = stroke.Color

    button.MouseEnter:Connect(function()
        TweenService:Create(button, TWEEN_INFO_FAST, { BackgroundColor3 = hoverColor }):Play()
        TweenService:Create(stroke, TWEEN_INFO_FAST, { Color = Constants.THEME.STROKE_FOCUSED }):Play()
    end)

    button.MouseLeave:Connect(function()
        TweenService:Create(button, TWEEN_INFO_FAST, { BackgroundColor3 = baseColor }):Play()
        TweenService:Create(stroke, TWEEN_INFO_FAST, { Color = baseStrokeColor }):Play()
    end)

    button.MouseButton1Down:Connect(function()
        TweenService:Create(button, TWEEN_INFO_BOUNCE, { BackgroundColor3 = activeColor }):Play()
    end)

    button.MouseButton1Up:Connect(function()
        TweenService:Create(button, TWEEN_INFO_FAST, { BackgroundColor3 = hoverColor }):Play()
    end)

    if config.OnClick then
        button.MouseButton1Click:Connect(config.OnClick)
    end

    if config.Parent then
        button.Parent = config.Parent
    end

    return button
end

--[[
    Creates a styled TextLabel following the Dark Fantasy typography standard.
]]
function UITheme.CreateTextLabel(config: {
    Name: string?,
    Text: string,
    Size: UDim2?,
    Position: UDim2?,
    AnchorPoint: Vector2?,
    TextColor3: Color3?,
    TextSize: number?,
    Font: Enum.Font?,
    TextXAlignment: Enum.TextXAlignment?,
    Parent: Instance?,
}): TextLabel
    local label = Instance.new("TextLabel")
    label.Name = config.Name or "TextLabel"
    label.Size = config.Size or UDim2.new(1, 0, 0, 30)
    label.Position = config.Position or UDim2.new(0, 0, 0, 0)
    label.AnchorPoint = config.AnchorPoint or Vector2.new(0, 0)
    label.BackgroundTransparency = 1
    label.Font = config.Font or Constants.THEME.FONT_TITLE
    label.Text = config.Text
    label.TextColor3 = config.TextColor3 or Constants.THEME.TEXT_PRIMARY
    label.TextSize = config.TextSize or 14
    label.TextXAlignment = config.TextXAlignment or Enum.TextXAlignment.Center

    if config.Parent then
        label.Parent = config.Parent
    end

    return label
end

--[[
    Tints the UIStroke of a component according to an item or rarity tier.
]]
function UITheme.ApplyRarityGlow(guiObject: GuiObject, rarity: Types.RarityTier): ()
    local rarityColor = RarityConfig.GetColor(rarity)

    local stroke = guiObject:FindFirstChild("PanelStroke") or guiObject:FindFirstChild("ButtonStroke")
    if not stroke or not stroke:IsA("UIStroke") then
        local newStroke = Instance.new("UIStroke")
        newStroke.Name = "PanelStroke"
        newStroke.Thickness = 1.8
        newStroke.Parent = guiObject
        stroke = newStroke
    end

    TweenService:Create(stroke :: UIStroke, TWEEN_INFO_FAST, {
        Color = rarityColor
    }):Play()
end

return UITheme
