--!strict
--[[
    SkillBarView.luau
    Renders the bottom-right Skill Control Bar with Dash, Heal Potion, M1 Combo tracker,
    and E/R Skill Cooldown timers. Dark Fantasy styling with responsive click/touch support.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local SkillBarView = {}

-- UI elements
local m1ComboLabel: TextLabel? = nil
local m1Stroke: UIStroke? = nil

local whirlwindOverlay: Frame? = nil
local whirlwindLabel: TextLabel? = nil

local meteorOverlay: Frame? = nil
local meteorLabel: TextLabel? = nil

local dashOverlay: Frame? = nil
local dashLabel: TextLabel? = nil

local healOverlay: Frame? = nil
local healLabel: TextLabel? = nil

-- Cooldown tracking
local activeCooldowns: { [string]: number } = {}

function SkillBarView.Build(parent: ScreenGui, callbacks: {
    OnM1: () -> (),
    OnWhirlwind: () -> (),
    OnMeteor: () -> (),
    OnDash: () -> (),
    OnHeal: () -> (),
})
    local container = Instance.new("Frame")
    container.Name = "SkillBarContainer"
    container.Size = UDim2.new(0, 360, 0, 70)
    container.Position = UDim2.new(1, -20, 1, -20)
    container.AnchorPoint = Vector2.new(1, 1)
    container.BackgroundTransparency = 1
    container.ZIndex = 25
    container.Parent = parent

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 8)
    layout.Parent = container

    -- 1. Dash Button (Shift / F)
    local dashBtn = Instance.new("TextButton")
    dashBtn.Name = "DashButton"
    dashBtn.Size = UDim2.new(0, 62, 0, 62)
    dashBtn.BackgroundColor3 = Constants.THEME.SURFACE_PANEL
    dashBtn.BorderSizePixel = 0
    dashBtn.Text = ""
    dashBtn.AutoButtonColor = false
    dashBtn.ZIndex = 26
    dashBtn.Parent = container

    local dashCorner = Instance.new("UICorner")
    dashCorner.CornerRadius = UDim.new(0, 12)
    dashCorner.Parent = dashBtn

    local dashStroke = Instance.new("UIStroke")
    dashStroke.Color = Color3.fromRGB(80, 200, 255)
    dashStroke.Thickness = 1.6
    dashStroke.Parent = dashBtn

    local dashIcon = Instance.new("TextLabel")
    dashIcon.Size = UDim2.new(1, 0, 0, 26)
    dashIcon.Position = UDim2.new(0, 0, 0, 6)
    dashIcon.BackgroundTransparency = 1
    dashIcon.Font = Constants.THEME.FONT_TITLE
    dashIcon.Text = "💨"
    dashIcon.TextSize = 20
    dashIcon.ZIndex = 27
    dashIcon.Parent = dashBtn

    local dashKey = Instance.new("TextLabel")
    dashKey.Size = UDim2.new(1, 0, 0, 12)
    dashKey.Position = UDim2.new(0, 0, 0, 32)
    dashKey.BackgroundTransparency = 1
    dashKey.Font = Constants.THEME.FONT_TITLE
    dashKey.Text = "SHIFT"
    dashKey.TextColor3 = Color3.fromRGB(140, 220, 255)
    dashKey.TextSize = 10
    dashKey.ZIndex = 27
    dashKey.Parent = dashBtn

    local dashSub = Instance.new("TextLabel")
    dashSub.Size = UDim2.new(1, 0, 0, 12)
    dashSub.Position = UDim2.new(0, 0, 0, 46)
    dashSub.BackgroundTransparency = 1
    dashSub.Font = Constants.THEME.FONT_BODY
    dashSub.Text = "DASH"
    dashSub.TextColor3 = Constants.THEME.TEXT_MUTED
    dashSub.TextSize = 9
    dashSub.ZIndex = 27
    dashSub.Parent = dashBtn

    local dOverlay = Instance.new("Frame")
    dOverlay.Name = "CDOverlay"
    dOverlay.Size = UDim2.new(1, 0, 0, 0)
    dOverlay.Position = UDim2.new(0, 0, 1, 0)
    dOverlay.AnchorPoint = Vector2.new(0, 1)
    dOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    dOverlay.BackgroundTransparency = 0.5
    dOverlay.BorderSizePixel = 0
    dOverlay.ZIndex = 28
    dOverlay.Parent = dashBtn
    dashOverlay = dOverlay

    local dOverlayCorner = Instance.new("UICorner")
    dOverlayCorner.CornerRadius = UDim.new(0, 12)
    dOverlayCorner.Parent = dOverlay

    local dCDText = Instance.new("TextLabel")
    dCDText.Name = "CDText"
    dCDText.Size = UDim2.new(1, 0, 1, 0)
    dCDText.BackgroundTransparency = 1
    dCDText.Font = Constants.THEME.FONT_TITLE
    dCDText.Text = ""
    dCDText.TextColor3 = Color3.fromRGB(255, 255, 255)
    dCDText.TextSize = 13
    dCDText.ZIndex = 29
    dCDText.Parent = dashBtn
    dashLabel = dCDText

    dashBtn.MouseButton1Click:Connect(function()
        callbacks.OnDash()
    end)

    -- 2. Heal Potion Button (H / 1)
    local healBtn = Instance.new("TextButton")
    healBtn.Name = "HealButton"
    healBtn.Size = UDim2.new(0, 62, 0, 62)
    healBtn.BackgroundColor3 = Constants.THEME.SURFACE_PANEL
    healBtn.BorderSizePixel = 0
    healBtn.Text = ""
    healBtn.AutoButtonColor = false
    healBtn.ZIndex = 26
    healBtn.Parent = container

    local healCorner = Instance.new("UICorner")
    healCorner.CornerRadius = UDim.new(0, 12)
    healCorner.Parent = healBtn

    local healStroke = Instance.new("UIStroke")
    healStroke.Color = Color3.fromRGB(60, 220, 120)
    healStroke.Thickness = 1.6
    healStroke.Parent = healBtn

    local healIcon = Instance.new("TextLabel")
    healIcon.Size = UDim2.new(1, 0, 0, 26)
    healIcon.Position = UDim2.new(0, 0, 0, 6)
    healIcon.BackgroundTransparency = 1
    healIcon.Font = Constants.THEME.FONT_TITLE
    healIcon.Text = "🧪"
    healIcon.TextSize = 20
    healIcon.ZIndex = 27
    healIcon.Parent = healBtn

    local healKey = Instance.new("TextLabel")
    healKey.Size = UDim2.new(1, 0, 0, 12)
    healKey.Position = UDim2.new(0, 0, 0, 32)
    healKey.BackgroundTransparency = 1
    healKey.Font = Constants.THEME.FONT_TITLE
    healKey.Text = "H / 1"
    healKey.TextColor3 = Color3.fromRGB(120, 255, 160)
    healKey.TextSize = 10
    healKey.ZIndex = 27
    healKey.Parent = healBtn

    local healSub = Instance.new("TextLabel")
    healSub.Size = UDim2.new(1, 0, 0, 12)
    healSub.Position = UDim2.new(0, 0, 0, 46)
    healSub.BackgroundTransparency = 1
    healSub.Font = Constants.THEME.FONT_BODY
    healSub.Text = "HEAL"
    healSub.TextColor3 = Constants.THEME.TEXT_MUTED
    healSub.TextSize = 9
    healSub.ZIndex = 27
    healSub.Parent = healBtn

    local hOverlay = Instance.new("Frame")
    hOverlay.Name = "CDOverlay"
    hOverlay.Size = UDim2.new(1, 0, 0, 0)
    hOverlay.Position = UDim2.new(0, 0, 1, 0)
    hOverlay.AnchorPoint = Vector2.new(0, 1)
    hOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    hOverlay.BackgroundTransparency = 0.5
    hOverlay.BorderSizePixel = 0
    hOverlay.ZIndex = 28
    hOverlay.Parent = healBtn
    healOverlay = hOverlay

    local hOverlayCorner = Instance.new("UICorner")
    hOverlayCorner.CornerRadius = UDim.new(0, 12)
    hOverlayCorner.Parent = hOverlay

    local hCDText = Instance.new("TextLabel")
    hCDText.Name = "CDText"
    hCDText.Size = UDim2.new(1, 0, 1, 0)
    hCDText.BackgroundTransparency = 1
    hCDText.Font = Constants.THEME.FONT_TITLE
    hCDText.Text = ""
    hCDText.TextColor3 = Color3.fromRGB(255, 255, 255)
    hCDText.TextSize = 13
    hCDText.ZIndex = 29
    hCDText.Parent = healBtn
    healLabel = hCDText

    healBtn.MouseButton1Click:Connect(function()
        callbacks.OnHeal()
    end)

    -- 3. M1 Basic Attack Button
    local m1Btn = Instance.new("TextButton")
    m1Btn.Name = "M1AttackButton"
    m1Btn.Size = UDim2.new(0, 62, 0, 62)
    m1Btn.BackgroundColor3 = Constants.THEME.SURFACE_PANEL
    m1Btn.BorderSizePixel = 0
    m1Btn.Text = ""
    m1Btn.AutoButtonColor = false
    m1Btn.ZIndex = 26
    m1Btn.Parent = container

    local m1Corner = Instance.new("UICorner")
    m1Corner.CornerRadius = UDim.new(0, 12)
    m1Corner.Parent = m1Btn

    local stroke1 = Instance.new("UIStroke")
    stroke1.Color = Constants.THEME.STROKE_DEFAULT
    stroke1.Thickness = 1.6
    stroke1.Parent = m1Btn
    m1Stroke = stroke1

    local m1Icon = Instance.new("TextLabel")
    m1Icon.Size = UDim2.new(1, 0, 0, 26)
    m1Icon.Position = UDim2.new(0, 0, 0, 6)
    m1Icon.BackgroundTransparency = 1
    m1Icon.Font = Constants.THEME.FONT_TITLE
    m1Icon.Text = "⚔️"
    m1Icon.TextSize = 20
    m1Icon.ZIndex = 27
    m1Icon.Parent = m1Btn

    local m1Key = Instance.new("TextLabel")
    m1Key.Size = UDim2.new(1, 0, 0, 12)
    m1Key.Position = UDim2.new(0, 0, 0, 32)
    m1Key.BackgroundTransparency = 1
    m1Key.Font = Constants.THEME.FONT_TITLE
    m1Key.Text = "M1"
    m1Key.TextColor3 = Constants.THEME.ACCENT_GOLD
    m1Key.TextSize = 10
    m1Key.ZIndex = 27
    m1Key.Parent = m1Btn

    local m1Combo = Instance.new("TextLabel")
    m1Combo.Size = UDim2.new(1, 0, 0, 12)
    m1Combo.Position = UDim2.new(0, 0, 0, 46)
    m1Combo.BackgroundTransparency = 1
    m1Combo.Font = Constants.THEME.FONT_BODY
    m1Combo.Text = "HIT 1"
    m1Combo.TextColor3 = Constants.THEME.TEXT_MUTED
    m1Combo.TextSize = 9
    m1Combo.ZIndex = 27
    m1Combo.Parent = m1Btn
    m1ComboLabel = m1Combo

    m1Btn.MouseButton1Click:Connect(function()
        callbacks.OnM1()
    end)

    -- 4. Skill E / Q (Whirlwind Slash)
    local eBtn = Instance.new("TextButton")
    eBtn.Name = "WhirlwindButton"
    eBtn.Size = UDim2.new(0, 62, 0, 62)
    eBtn.BackgroundColor3 = Constants.THEME.SURFACE_PANEL
    eBtn.BorderSizePixel = 0
    eBtn.Text = ""
    eBtn.AutoButtonColor = false
    eBtn.ZIndex = 26
    eBtn.Parent = container

    local eCorner = Instance.new("UICorner")
    eCorner.CornerRadius = UDim.new(0, 12)
    eCorner.Parent = eBtn

    local stroke2 = Instance.new("UIStroke")
    stroke2.Color = Color3.fromRGB(70, 160, 255)
    stroke2.Thickness = 1.6
    stroke2.Parent = eBtn

    local eIcon = Instance.new("TextLabel")
    eIcon.Size = UDim2.new(1, 0, 0, 26)
    eIcon.Position = UDim2.new(0, 0, 0, 6)
    eIcon.BackgroundTransparency = 1
    eIcon.Font = Constants.THEME.FONT_TITLE
    eIcon.Text = "🌪️"
    eIcon.TextSize = 20
    eIcon.ZIndex = 27
    eIcon.Parent = eBtn

    local eKey = Instance.new("TextLabel")
    eKey.Size = UDim2.new(1, 0, 0, 12)
    eKey.Position = UDim2.new(0, 0, 0, 32)
    eKey.BackgroundTransparency = 1
    eKey.Font = Constants.THEME.FONT_TITLE
    eKey.Text = "E / Q"
    eKey.TextColor3 = Color3.fromRGB(120, 210, 255)
    eKey.TextSize = 10
    eKey.ZIndex = 27
    eKey.Parent = eBtn

    local eSub = Instance.new("TextLabel")
    eSub.Size = UDim2.new(1, 0, 0, 12)
    eSub.Position = UDim2.new(0, 0, 0, 46)
    eSub.BackgroundTransparency = 1
    eSub.Font = Constants.THEME.FONT_BODY
    eSub.Text = "WHIRL"
    eSub.TextColor3 = Constants.THEME.TEXT_MUTED
    eSub.TextSize = 9
    eSub.ZIndex = 27
    eSub.Parent = eBtn

    local eOverlay = Instance.new("Frame")
    eOverlay.Name = "CDOverlay"
    eOverlay.Size = UDim2.new(1, 0, 0, 0)
    eOverlay.Position = UDim2.new(0, 0, 1, 0)
    eOverlay.AnchorPoint = Vector2.new(0, 1)
    eOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    eOverlay.BackgroundTransparency = 0.5
    eOverlay.BorderSizePixel = 0
    eOverlay.ZIndex = 28
    eOverlay.Parent = eBtn
    whirlwindOverlay = eOverlay

    local eOverlayCorner = Instance.new("UICorner")
    eOverlayCorner.CornerRadius = UDim.new(0, 12)
    eOverlayCorner.Parent = eOverlay

    local eCDText = Instance.new("TextLabel")
    eCDText.Name = "CDText"
    eCDText.Size = UDim2.new(1, 0, 1, 0)
    eCDText.BackgroundTransparency = 1
    eCDText.Font = Constants.THEME.FONT_TITLE
    eCDText.Text = ""
    eCDText.TextColor3 = Color3.fromRGB(255, 255, 255)
    eCDText.TextSize = 13
    eCDText.ZIndex = 29
    eCDText.Parent = eBtn
    whirlwindLabel = eCDText

    eBtn.MouseButton1Click:Connect(function()
        callbacks.OnWhirlwind()
    end)

    -- 5. Skill R (Meteor Strike)
    local rBtn = Instance.new("TextButton")
    rBtn.Name = "MeteorButton"
    rBtn.Size = UDim2.new(0, 62, 0, 62)
    rBtn.BackgroundColor3 = Constants.THEME.SURFACE_PANEL
    rBtn.BorderSizePixel = 0
    rBtn.Text = ""
    rBtn.AutoButtonColor = false
    rBtn.ZIndex = 26
    rBtn.Parent = container

    local rCorner = Instance.new("UICorner")
    rCorner.CornerRadius = UDim.new(0, 12)
    rCorner.Parent = rBtn

    local stroke3 = Instance.new("UIStroke")
    stroke3.Color = Color3.fromRGB(255, 120, 60)
    stroke3.Thickness = 1.6
    stroke3.Parent = rBtn

    local rIcon = Instance.new("TextLabel")
    rIcon.Size = UDim2.new(1, 0, 0, 26)
    rIcon.Position = UDim2.new(0, 0, 0, 6)
    rIcon.BackgroundTransparency = 1
    rIcon.Font = Constants.THEME.FONT_TITLE
    rIcon.Text = "☄️"
    rIcon.TextSize = 20
    rIcon.ZIndex = 27
    rIcon.Parent = rBtn

    local rKey = Instance.new("TextLabel")
    rKey.Size = UDim2.new(1, 0, 0, 12)
    rKey.Position = UDim2.new(0, 0, 0, 32)
    rKey.BackgroundTransparency = 1
    rKey.Font = Constants.THEME.FONT_TITLE
    rKey.Text = "R"
    rKey.TextColor3 = Color3.fromRGB(255, 160, 80)
    rKey.TextSize = 10
    rKey.ZIndex = 27
    rKey.Parent = rBtn

    local rSub = Instance.new("TextLabel")
    rSub.Size = UDim2.new(1, 0, 0, 12)
    rSub.Position = UDim2.new(0, 0, 0, 46)
    rSub.BackgroundTransparency = 1
    rSub.Font = Constants.THEME.FONT_BODY
    rSub.Text = "METEOR"
    rSub.TextColor3 = Constants.THEME.TEXT_MUTED
    rSub.TextSize = 9
    rSub.ZIndex = 27
    rSub.Parent = rBtn

    local rOverlay = Instance.new("Frame")
    rOverlay.Name = "CDOverlay"
    rOverlay.Size = UDim2.new(1, 0, 0, 0)
    rOverlay.Position = UDim2.new(0, 0, 1, 0)
    rOverlay.AnchorPoint = Vector2.new(0, 1)
    rOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    rOverlay.BackgroundTransparency = 0.5
    rOverlay.BorderSizePixel = 0
    rOverlay.ZIndex = 28
    rOverlay.Parent = rBtn
    meteorOverlay = rOverlay

    local rOverlayCorner = Instance.new("UICorner")
    rOverlayCorner.CornerRadius = UDim.new(0, 12)
    rOverlayCorner.Parent = rOverlay

    local rCDText = Instance.new("TextLabel")
    rCDText.Name = "CDText"
    rCDText.Size = UDim2.new(1, 0, 1, 0)
    rCDText.BackgroundTransparency = 1
    rCDText.Font = Constants.THEME.FONT_TITLE
    rCDText.Text = ""
    rCDText.TextColor3 = Color3.fromRGB(255, 255, 255)
    rCDText.TextSize = 13
    rCDText.ZIndex = 29
    rCDText.Parent = rBtn
    meteorLabel = rCDText

    rBtn.MouseButton1Click:Connect(function()
        callbacks.OnMeteor()
    end)
end

--[[
    Updates M1 Combo label and glowing stroke.
]]
function SkillBarView.SetM1Combo(step: number)
    if m1ComboLabel then
        m1ComboLabel.Text = string.format("HIT %d", step)
        if step == 3 then
            m1ComboLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
            if m1Stroke then
                m1Stroke.Color = Color3.fromRGB(255, 200, 40)
            end
        else
            m1ComboLabel.TextColor3 = Constants.THEME.TEXT_MUTED
            if m1Stroke then
                m1Stroke.Color = Constants.THEME.STROKE_DEFAULT
            end
        end
    end
end

--[[
    Triggers visual cooldown countdown animation on any skill slot.
]]
function SkillBarView.StartCooldown(skill: "Whirlwind" | "Meteor" | "Dash" | "Heal", duration: number)
    local now = os.clock()
    local targetEndTime = now + duration

    local overlay: Frame? = nil
    local label: TextLabel? = nil

    if skill == "Whirlwind" then
        overlay = whirlwindOverlay
        label = whirlwindLabel
    elseif skill == "Meteor" then
        overlay = meteorOverlay
        label = meteorLabel
    elseif skill == "Dash" then
        overlay = dashOverlay
        label = dashLabel
    elseif skill == "Heal" then
        overlay = healOverlay
        label = healLabel
    end

    if not overlay or not label then return end
    activeCooldowns[skill] = targetEndTime

    task.spawn(function()
        while os.clock() < targetEndTime and activeCooldowns[skill] == targetEndTime do
            local remaining = math.max(0, targetEndTime - os.clock())
            local ratio = remaining / duration
            if overlay then
                overlay.Size = UDim2.new(1, 0, ratio, 0)
            end
            if label then
                label.Text = string.format("%.1fs", remaining)
            end
            task.wait(0.05)
        end
        if activeCooldowns[skill] == targetEndTime then
            if overlay then
                overlay.Size = UDim2.new(1, 0, 0, 0)
            end
            if label then
                label.Text = ""
            end
        end
    end)
end

return SkillBarView
