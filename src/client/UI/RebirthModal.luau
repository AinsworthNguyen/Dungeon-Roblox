--!strict
--[[
    RebirthModal.luau
    Dark Fantasy Ascension & Rebirth Modal.
    Displays current Rebirth level, requirements, Before -> After stat multipliers,
    and ascension execution trigger.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Constants = require(Shared:WaitForChild("Constants"))

local UITheme = require(script.Parent.UITheme)

local RebirthModal = {}

local modalFrame: Frame? = nil
local callbacksRef: {
    OnRebirth: () -> (),
}? = nil

-- Dynamic labels
local currentRebirthLabel: TextLabel? = nil
local levelReqLabel: TextLabel? = nil
local goldReqLabel: TextLabel? = nil
local dmgComparisonLabel: TextLabel? = nil
local hpComparisonLabel: TextLabel? = nil
local luckComparisonLabel: TextLabel? = nil
local rebirthActionBtn: TextButton? = nil

local cachedPlayerData: Types.PlayerData? = nil

--[[
    Toggles modal visibility with smooth pop animation.
]]
function RebirthModal.Toggle(isOpen: boolean?)
    local frame = modalFrame
    if not frame then return end

    local targetOpen = if isOpen ~= nil then isOpen else not frame.Visible
    if targetOpen then
        frame.Visible = true
        frame.Position = UDim2.new(0.5, 0, 0.55, 0)
        TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, 0, 0.5, 0)
        }):Play()
    else
        local tween = TweenService:Create(frame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, 0, 0.55, 0)
        })
        tween:Play()
        tween.Completed:Connect(function()
            if modalFrame then modalFrame.Visible = false end
        end)
    end
end

function RebirthModal.IsOpen(): boolean
    local frame = modalFrame
    return if frame then frame.Visible else false
end

--[[
    Builds the complete Rebirth Modal UI.
]]
function RebirthModal.Build(parent: ScreenGui, callbacks: {
    OnRebirth: () -> (),
})
    callbacksRef = callbacks

    local frame = UITheme.CreatePanel({
        Name = "RebirthModal",
        Size = UDim2.new(0, 640, 0, 500),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Constants.THEME.BACKGROUND_DARK,
        StrokeColor = Color3.fromRGB(255, 140, 20),
        StrokeThickness = 2.2,
        CornerRadius = UDim.new(0, 16),
        Parent = parent,
    })
    frame.Visible = false
    frame.ZIndex = 30
    modalFrame = frame

    -- Header
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 54)
    header.BackgroundTransparency = 1
    header.ZIndex = 31
    header.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.new(0, 20, 0, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "🔥 REBIRTH & ASCENSION"
    title.TextColor3 = Color3.fromRGB(255, 160, 40)
    title.TextSize = 20
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 32
    title.Parent = header

    -- Close Button [X]
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 36, 0, 36)
    closeBtn.Position = UDim2.new(1, -44, 0, 9)
    closeBtn.BackgroundColor3 = Constants.THEME.SURFACE_PANEL
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Constants.THEME.TEXT_MUTED
    closeBtn.TextSize = 16
    closeBtn.ZIndex = 32
    closeBtn.Parent = header

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        RebirthModal.Toggle(false)
    end)

    -- Container
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -40, 1, -74)
    content.Position = UDim2.new(0, 20, 0, 60)
    content.BackgroundTransparency = 1
    content.ZIndex = 31
    content.Parent = frame

    -- Current Rebirth Banner
    local banner = Instance.new("Frame")
    banner.Name = "RebirthBanner"
    banner.Size = UDim2.new(1, 0, 0, 60)
    banner.BackgroundColor3 = Color3.fromRGB(30, 24, 20)
    banner.BorderSizePixel = 0
    banner.ZIndex = 32
    banner.Parent = content

    local bannerCorner = Instance.new("UICorner")
    bannerCorner.CornerRadius = UDim.new(0, 12)
    bannerCorner.Parent = banner

    local bannerStroke = Instance.new("UIStroke")
    bannerStroke.Color = Color3.fromRGB(255, 140, 20)
    bannerStroke.Thickness = 1.4
    bannerStroke.Parent = banner

    local rLbl = Instance.new("TextLabel")
    rLbl.Name = "CurrentRebirthText"
    rLbl.Size = UDim2.new(1, 0, 1, 0)
    rLbl.BackgroundTransparency = 1
    rLbl.Font = Enum.Font.GothamBold
    rLbl.Text = "CURRENT REBIRTH: 0"
    rLbl.TextColor3 = Color3.fromRGB(255, 205, 70)
    rLbl.TextSize = 18
    rLbl.ZIndex = 33
    rLbl.Parent = banner
    currentRebirthLabel = rLbl

    -- Requirements Box
    local reqBox = Instance.new("Frame")
    reqBox.Name = "RequirementsBox"
    reqBox.Size = UDim2.new(1, 0, 0, 84)
    reqBox.Position = UDim2.new(0, 0, 0, 72)
    reqBox.BackgroundColor3 = Constants.THEME.SURFACE_PANEL
    reqBox.BorderSizePixel = 0
    reqBox.ZIndex = 32
    reqBox.Parent = content

    local reqCorner = Instance.new("UICorner")
    reqCorner.CornerRadius = UDim.new(0, 12)
    reqCorner.Parent = reqBox

    local reqTitle = Instance.new("TextLabel")
    reqTitle.Size = UDim2.new(1, -24, 0, 22)
    reqTitle.Position = UDim2.new(0, 14, 0, 8)
    reqTitle.BackgroundTransparency = 1
    reqTitle.Font = Enum.Font.GothamBold
    reqTitle.Text = "ASCENSION REQUIREMENTS"
    reqTitle.TextColor3 = Color3.fromRGB(180, 190, 220)
    reqTitle.TextSize = 13
    reqTitle.TextXAlignment = Enum.TextXAlignment.Left
    reqTitle.ZIndex = 33
    reqTitle.Parent = reqBox

    local lReq = Instance.new("TextLabel")
    lReq.Name = "LevelReq"
    lReq.Size = UDim2.new(0.5, -20, 0, 42)
    lReq.Position = UDim2.new(0, 14, 0, 34)
    lReq.BackgroundTransparency = 1
    lReq.Font = Enum.Font.GothamMedium
    lReq.Text = "Required Level: 5 (Current: 1)"
    lReq.TextColor3 = Color3.fromRGB(255, 100, 100)
    lReq.TextSize = 13
    lReq.TextXAlignment = Enum.TextXAlignment.Left
    lReq.ZIndex = 33
    lReq.Parent = reqBox
    levelReqLabel = lReq

    local gReq = Instance.new("TextLabel")
    gReq.Name = "GoldReq"
    gReq.Size = UDim2.new(0.5, -20, 0, 42)
    gReq.Position = UDim2.new(0.5, 6, 0, 34)
    gReq.BackgroundTransparency = 1
    gReq.Font = Enum.Font.GothamMedium
    gReq.Text = "Required Gold: 5,000 (Current: 0)"
    gReq.TextColor3 = Color3.fromRGB(255, 100, 100)
    gReq.TextSize = 13
    gReq.TextXAlignment = Enum.TextXAlignment.Left
    gReq.ZIndex = 33
    gReq.Parent = reqBox
    goldReqLabel = gReq

    -- Permanent Perks Card
    local perksBox = Instance.new("Frame")
    perksBox.Name = "PerksBox"
    perksBox.Size = UDim2.new(1, 0, 0, 134)
    perksBox.Position = UDim2.new(0, 0, 0, 168)
    perksBox.BackgroundColor3 = Constants.THEME.SURFACE_PANEL
    perksBox.BorderSizePixel = 0
    perksBox.ZIndex = 32
    perksBox.Parent = content

    local perksCorner = Instance.new("UICorner")
    perksCorner.CornerRadius = UDim.new(0, 12)
    perksCorner.Parent = perksBox

    local pTitle = Instance.new("TextLabel")
    pTitle.Size = UDim2.new(1, -24, 0, 24)
    pTitle.Position = UDim2.new(0, 14, 0, 10)
    pTitle.BackgroundTransparency = 1
    pTitle.Font = Enum.Font.GothamBold
    pTitle.Text = "PERMANENT STACKING STAT BONUSES"
    pTitle.TextColor3 = Color3.fromRGB(255, 215, 60)
    pTitle.TextSize = 13
    pTitle.TextXAlignment = Enum.TextXAlignment.Left
    pTitle.ZIndex = 33
    pTitle.Parent = perksBox

    local dmgLbl = Instance.new("TextLabel")
    dmgLbl.Name = "DmgBonus"
    dmgLbl.Size = UDim2.new(1, -24, 0, 28)
    dmgLbl.Position = UDim2.new(0, 14, 0, 38)
    dmgLbl.BackgroundTransparency = 1
    dmgLbl.Font = Enum.Font.GothamMedium
    dmgLbl.Text = "⚔️ Total Damage: +0% -> +35%"
    dmgLbl.TextColor3 = Color3.fromRGB(255, 140, 60)
    dmgLbl.TextSize = 13
    dmgLbl.TextXAlignment = Enum.TextXAlignment.Left
    dmgLbl.ZIndex = 33
    dmgLbl.Parent = perksBox
    dmgComparisonLabel = dmgLbl

    local hpLbl = Instance.new("TextLabel")
    hpLbl.Name = "HpBonus"
    hpLbl.Size = UDim2.new(1, -24, 0, 28)
    hpLbl.Position = UDim2.new(0, 14, 0, 68)
    hpLbl.BackgroundTransparency = 1
    hpLbl.Font = Enum.Font.GothamMedium
    hpLbl.Text = "❤️ Max Health: +0% -> +35%"
    hpLbl.TextColor3 = Color3.fromRGB(80, 225, 130)
    hpLbl.TextSize = 13
    hpLbl.TextXAlignment = Enum.TextXAlignment.Left
    hpLbl.ZIndex = 33
    hpLbl.Parent = perksBox
    hpComparisonLabel = hpLbl

    local lkLbl = Instance.new("TextLabel")
    lkLbl.Name = "LuckBonus"
    lkLbl.Size = UDim2.new(1, -24, 0, 28)
    lkLbl.Position = UDim2.new(0, 14, 0, 98)
    lkLbl.BackgroundTransparency = 1
    lkLbl.Font = Enum.Font.GothamMedium
    lkLbl.Text = "🍀 Base Luck: +0.0 -> +1.5"
    lkLbl.TextColor3 = Color3.fromRGB(70, 190, 255)
    lkLbl.TextSize = 13
    lkLbl.TextXAlignment = Enum.TextXAlignment.Left
    lkLbl.ZIndex = 33
    lkLbl.Parent = perksBox
    luckComparisonLabel = lkLbl

    -- Note text
    local note = Instance.new("TextLabel")
    note.Size = UDim2.new(1, 0, 0, 26)
    note.Position = UDim2.new(0, 0, 0, 310)
    note.BackgroundTransparency = 1
    note.Font = Enum.Font.Gotham
    note.Text = "🛡️ All Inventory Gear, Rarities, Traits, & Multi-Roll tiers are KEPT upon Rebirth!"
    note.TextColor3 = Color3.fromRGB(150, 160, 190)
    note.TextSize = 11
    note.ZIndex = 32
    note.Parent = content

    -- Action Button
    local btn = UITheme.CreateButton({
        Name = "AscendButton",
        Text = "🔥 ASCEND / REBIRTH",
        Size = UDim2.new(1, 0, 0, 52),
        Position = UDim2.new(0, 0, 0, 346),
        BackgroundColor3 = Color3.fromRGB(220, 90, 20),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 16,
        Parent = content,
        OnClick = function()
            if callbacksRef then callbacksRef.OnRebirth() end
        end,
    })
    btn.ZIndex = 33
    rebirthActionBtn = btn
end

--[[
    Updates Rebirth Modal with current PlayerData.
]]
function RebirthModal.Update(data: Types.PlayerData)
    cachedPlayerData = data

    local currentRebirths = data.Rebirths or 0
    local reqLevel = 5 + (currentRebirths * 5)
    local reqGold = 5000 * (currentRebirths + 1)

    if currentRebirthLabel then
        currentRebirthLabel.Text = string.format("CURRENT REBIRTH: %d", currentRebirths)
    end

    local hasLevel = data.Level >= reqLevel
    local hasGold = data.Gold >= reqGold

    if levelReqLabel then
        levelReqLabel.Text = string.format("Level: %d / %d %s", data.Level, reqLevel, if hasLevel then " [OK]" else " [LOCKED]")
        levelReqLabel.TextColor3 = if hasLevel then Color3.fromRGB(80, 220, 120) else Color3.fromRGB(255, 100, 100)
    end

    if goldReqLabel then
        goldReqLabel.Text = string.format("Gold: %d / %d %s", data.Gold, reqGold, if hasGold then " [OK]" else " [LOCKED]")
        goldReqLabel.TextColor3 = if hasGold then Color3.fromRGB(80, 220, 120) else Color3.fromRGB(255, 100, 100)
    end

    local currentDmgPct = currentRebirths * 35
    local nextDmgPct = (currentRebirths + 1) * 35

    local currentHpPct = currentRebirths * 35
    local nextHpPct = (currentRebirths + 1) * 35

    local currentLuck = currentRebirths * 1.5
    local nextLuck = (currentRebirths + 1) * 1.5

    if dmgComparisonLabel then
        dmgComparisonLabel.Text = string.format("⚔️ Total Damage: +%d%% -> +%d%%", currentDmgPct, nextDmgPct)
    end

    if hpComparisonLabel then
        hpComparisonLabel.Text = string.format("❤️ Max Health: +%d%% -> +%d%%", currentHpPct, nextHpPct)
    end

    if luckComparisonLabel then
        luckComparisonLabel.Text = string.format("🍀 Base Luck: +%.1f -> +%.1f", currentLuck, nextLuck)
    end

    if rebirthActionBtn then
        if hasLevel and hasGold then
            rebirthActionBtn.Text = string.format("🔥 ASCEND TO REBIRTH %d", currentRebirths + 1)
            rebirthActionBtn.BackgroundColor3 = Color3.fromRGB(220, 90, 20)
            rebirthActionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            rebirthActionBtn.Text = string.format("LOCKED (LVL %d & %d GOLD REQUIRED)", reqLevel, reqGold)
            rebirthActionBtn.BackgroundColor3 = Color3.fromRGB(45, 48, 65)
            rebirthActionBtn.TextColor3 = Color3.fromRGB(140, 150, 175)
        end
    end
end

return RebirthModal
