--!strict
--[[
    ShopModal.luau
    Dark Fantasy Alchemist & Multi-Roll Upgrade Shop Modal.
    
    Items:
    1. Luck Potion (500 Gold): 2x Luck for 5 minutes.
    2. Wealth Potion (500 Gold): 2x Gold for 5 minutes.
    3. Multi-Roll Upgrade: 1x -> 2x (2,500 G) -> 3x (10,000 G).
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Constants = require(Shared:WaitForChild("Constants"))

local UITheme = require(script.Parent.UITheme)

local ShopModal = {}

local modalFrame: Frame? = nil
local callbacksRef: {
    OnBuy: (itemType: string) -> (),
}? = nil

local luckTimerLabel: TextLabel? = nil
local wealthTimerLabel: TextLabel? = nil
local multiRollStatusLabel: TextLabel? = nil
local multiRollBtn: TextButton? = nil
local fastRollStatusLabel: TextLabel? = nil
local fastRollBtn: TextButton? = nil

local cachedPlayerData: Types.PlayerData? = nil

--[[
    Toggles the modal visibility.
]]
function ShopModal.Toggle(isOpen: boolean?)
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

function ShopModal.IsOpen(): boolean
    local frame = modalFrame
    return if frame then frame.Visible else false
end

--[[
    Builds the complete Shop Modal.
]]
function ShopModal.Build(parent: ScreenGui, callbacks: {
    OnBuy: (itemType: string) -> (),
})
    callbacksRef = callbacks

    local frame = UITheme.CreatePanel({
        Name = "ShopModal",
        Size = UDim2.new(0, 680, 0, 480),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Constants.THEME.BACKGROUND_DARK,
        StrokeColor = Constants.THEME.STROKE_DEFAULT,
        StrokeThickness = 2.0,
        CornerRadius = UDim.new(0, 16),
        Parent = parent,
    })
    frame.Visible = false
    frame.ZIndex = 30
    modalFrame = frame

    -- Header
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 52)
    header.BackgroundTransparency = 1
    header.ZIndex = 31
    header.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.new(0, 20, 0, 0)
    title.BackgroundTransparency = 1
    title.Font = Constants.THEME.FONT_TITLE
    title.Text = "🧪 ALCHEMIST & UPGRADE SHOP"
    title.TextColor3 = Constants.THEME.TEXT_PRIMARY
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 32
    title.Parent = header

    -- Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 36, 0, 36)
    closeBtn.Position = UDim2.new(1, -44, 0, 8)
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
        ShopModal.Toggle(false)
    end)

    -- Item Cards Container (ScrollingFrame for 4 items)
    local cardsContainer = Instance.new("ScrollingFrame")
    cardsContainer.Name = "CardsContainer"
    cardsContainer.Size = UDim2.new(1, -40, 1, -72)
    cardsContainer.Position = UDim2.new(0, 20, 0, 60)
    cardsContainer.BackgroundTransparency = 1
    cardsContainer.BorderSizePixel = 0
    cardsContainer.ScrollBarThickness = 5
    cardsContainer.ScrollBarImageColor3 = Constants.THEME.STROKE_FOCUSED
    cardsContainer.CanvasSize = UDim2.new(0, 0, 0, 680)
    cardsContainer.ZIndex = 31
    cardsContainer.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, 12)
    layout.Parent = cardsContainer

    -- Helper to build an item card row
    local function createShopCard(icon: string, titleText: string, descText: string, costText: string, buttonColor: Color3, onClick: () -> ()): (Frame, TextLabel, TextButton)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 118)
        card.BackgroundColor3 = Constants.THEME.SURFACE_PANEL
        card.BorderSizePixel = 0
        card.ZIndex = 32
        card.Parent = cardsContainer

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = card

        local stroke = Instance.new("UIStroke")
        stroke.Color = Constants.THEME.STROKE_DEFAULT
        stroke.Thickness = 1.4
        stroke.Parent = card

        -- Icon Box
        local iconBox = Instance.new("TextLabel")
        iconBox.Size = UDim2.new(0, 64, 0, 64)
        iconBox.Position = UDim2.new(0, 16, 0.5, -32)
        iconBox.BackgroundColor3 = Color3.fromRGB(30, 34, 52)
        iconBox.Font = Enum.Font.GothamBold
        iconBox.Text = icon
        iconBox.TextSize = 32
        iconBox.ZIndex = 33
        iconBox.Parent = card

        local iconCorner = Instance.new("UICorner")
        iconCorner.CornerRadius = UDim.new(0, 10)
        iconCorner.Parent = iconBox

        -- Title & Description
        local tLbl = Instance.new("TextLabel")
        tLbl.Size = UDim2.new(0.55, 0, 0, 24)
        tLbl.Position = UDim2.new(0, 92, 0, 14)
        tLbl.BackgroundTransparency = 1
        tLbl.Font = Constants.THEME.FONT_TITLE
        tLbl.Text = titleText
        tLbl.TextColor3 = Constants.THEME.TEXT_PRIMARY
        tLbl.TextSize = 16
        tLbl.TextXAlignment = Enum.TextXAlignment.Left
        tLbl.ZIndex = 33
        tLbl.Parent = card

        local dLbl = Instance.new("TextLabel")
        dLbl.Size = UDim2.new(0.55, 0, 0, 36)
        dLbl.Position = UDim2.new(0, 92, 0, 40)
        dLbl.BackgroundTransparency = 1
        dLbl.Font = Constants.THEME.FONT_BODY
        dLbl.Text = descText
        dLbl.TextColor3 = Constants.THEME.TEXT_SECONDARY
        dLbl.TextSize = 12
        dLbl.TextWrapped = true
        dLbl.TextXAlignment = Enum.TextXAlignment.Left
        dLbl.TextYAlignment = Enum.TextYAlignment.Top
        dLbl.ZIndex = 33
        dLbl.Parent = card

        -- Status Timer / Level label
        local sLbl = Instance.new("TextLabel")
        sLbl.Size = UDim2.new(0.55, 0, 0, 22)
        sLbl.Position = UDim2.new(0, 92, 0, 82)
        sLbl.BackgroundTransparency = 1
        sLbl.Font = Constants.THEME.FONT_TITLE
        sLbl.Text = "Not Active"
        sLbl.TextColor3 = Constants.THEME.TEXT_MUTED
        sLbl.TextSize = 12
        sLbl.TextXAlignment = Enum.TextXAlignment.Left
        sLbl.ZIndex = 33
        sLbl.Parent = card

        -- Buy Button
        local btn = UITheme.CreateButton({
            Name = "BuyBtn",
            Text = costText,
            Size = UDim2.new(0, 140, 0, 44),
            Position = UDim2.new(1, -156, 0.5, -22),
            BackgroundColor3 = buttonColor,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextSize = 13,
            Parent = card,
            OnClick = onClick,
        })
        btn.ZIndex = 34

        return card, sLbl, btn
    end

    -- Card 1: Luck Potion
    local _, luckLbl, _ = createShopCard(
        "🍀",
        "LUCK POTION (2x LUCK)",
        "Doubles your Luck bonus for 5 minutes! Stacks duration when purchased repeatedly.",
        "BUY (500 G)",
        Color3.fromRGB(40, 140, 80),
        function()
            if callbacksRef then callbacksRef.OnBuy("LuckPotion") end
        end
    )
    luckTimerLabel = luckLbl

    -- Card 2: Wealth Potion
    local _, wealthLbl, _ = createShopCard(
        "💰",
        "WEALTH POTION (2x GOLD)",
        "Doubles all Gold earned from Dungeons & selling gear for 5 minutes!",
        "BUY (500 G)",
        Color3.fromRGB(200, 140, 20),
        function()
            if callbacksRef then callbacksRef.OnBuy("WealthPotion") end
        end
    )
    wealthTimerLabel = wealthLbl

    -- Card 3: Multi-Roll Upgrade
    local _, multiLbl, mBtn = createShopCard(
        "🎲",
        "MULTI-ROLL UPGRADE",
        "Permanently roll multiple items simultaneously! Level 1: 1x -> Level 2: 2x -> Level 3: 3x!",
        "UPGRADE (2,500 G)",
        Color3.fromRGB(150, 40, 180),
        function()
            if callbacksRef then callbacksRef.OnBuy("MultiRollUpgrade") end
        end
    )
    multiRollStatusLabel = multiLbl
    multiRollBtn = mBtn

    -- Card 4: Fast Roll Pass (VIP)
    local _, fastLbl, fBtn = createShopCard(
        "⚡",
        "FAST ROLL PASS (VIP)",
        "Permanently triple your roll speed! Reduces roll cooldown and auto-roll from 0.75s to 0.25s!",
        "UNLOCK (15,000 G)",
        Color3.fromRGB(220, 50, 70),
        function()
            if callbacksRef then callbacksRef.OnBuy("FastRollPass") end
        end
    )
    fastRollStatusLabel = fastLbl
    fastRollBtn = fBtn

    -- Card 5: Pouch of Mystic Gems
    createShopCard(
        "💎",
        "POUCH OF MYSTIC GEMS (3 GEMS)",
        "Exchange 1,000 Gold for 3 rare Mystic Gems! Used for rerolling powerful Traits.",
        "BUY (1,000 G)",
        Color3.fromRGB(30, 140, 200),
        function()
            if callbacksRef then callbacksRef.OnBuy("GemPouch") end
        end
    )

    -- Real-time countdown timer tick
    RunService.RenderStepped:Connect(function()
        if not modalFrame or not modalFrame.Visible then return end
        if not cachedPlayerData or not cachedPlayerData.ActiveBuffs then return end

        local now = os.time()

        -- Luck timer
        local luckRemaining = (cachedPlayerData.ActiveBuffs.LuckBoostEndTime or 0) - now
        if luckRemaining > 0 and luckTimerLabel then
            local mins = math.floor(luckRemaining / 60)
            local secs = luckRemaining % 60
            luckTimerLabel.Text = string.format("⚡ ACTIVE: %02d:%02d remaining", mins, secs)
            luckTimerLabel.TextColor3 = Color3.fromRGB(60, 220, 120)
        elseif luckTimerLabel then
            luckTimerLabel.Text = "Inactive (No active buff)"
            luckTimerLabel.TextColor3 = Constants.THEME.TEXT_MUTED
        end

        -- Wealth timer
        local wealthRemaining = (cachedPlayerData.ActiveBuffs.GoldBoostEndTime or 0) - now
        if wealthRemaining > 0 and wealthTimerLabel then
            local mins = math.floor(wealthRemaining / 60)
            local secs = wealthRemaining % 60
            wealthTimerLabel.Text = string.format("⚡ ACTIVE: %02d:%02d remaining", mins, secs)
            wealthTimerLabel.TextColor3 = Constants.THEME.ACCENT_GOLD
        elseif wealthTimerLabel then
            wealthTimerLabel.Text = "Inactive (No active buff)"
            wealthTimerLabel.TextColor3 = Constants.THEME.TEXT_MUTED
        end
    end)
end

--[[
    Updates the modal state with latest PlayerData.
]]
function ShopModal.Update(data: Types.PlayerData)
    cachedPlayerData = data

    -- Update Multi-Roll status
    local currentLevel = data.MultiRollCount or 1
    if multiRollStatusLabel then
        if currentLevel >= 3 then
            multiRollStatusLabel.Text = "Level: 3x (MAX LEVEL REACHED)"
            multiRollStatusLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
        else
            multiRollStatusLabel.Text = string.format("Current: %dx -> Next: %dx", currentLevel, currentLevel + 1)
            multiRollStatusLabel.TextColor3 = Color3.fromRGB(180, 200, 240)
        end
    end

    if multiRollBtn then
        if currentLevel == 1 then
            multiRollBtn.Text = "UPGRADE (2,500 G)"
        elseif currentLevel == 2 then
            multiRollBtn.Text = "UPGRADE (10,000 G)"
        else
            multiRollBtn.Text = "MAX LEVEL"
        end
    end

    -- Update Fast Roll status
    if fastRollStatusLabel and fastRollBtn then
        if data.FastRollUnlocked then
            fastRollStatusLabel.Text = "Status: UNLOCKED (0.25s Super Roll Active!)"
            fastRollStatusLabel.TextColor3 = Color3.fromRGB(60, 220, 120)
            fastRollBtn.Text = "UNLOCKED [MAX]"
            fastRollBtn.BackgroundColor3 = Color3.fromRGB(45, 60, 50)
            fastRollBtn.TextColor3 = Color3.fromRGB(120, 220, 150)
        else
            fastRollStatusLabel.Text = "Status: Locked (Default 0.75s cooldown)"
            fastRollStatusLabel.TextColor3 = Constants.THEME.TEXT_MUTED
            fastRollBtn.Text = "UNLOCK (15,000 G)"
            fastRollBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 70)
            fastRollBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end
end

return ShopModal
