--!strict
--[[
    QuestModal.luau
    Dark Fantasy Quest Board Modal displaying rolling quests and reward claims.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Constants = require(Shared:WaitForChild("Constants"))

local UITheme = require(script.Parent.UITheme)

local QuestModal = {}

local modalFrame: Frame? = nil
local callbacksRef: {
    OnClaim: (questId: string) -> (),
}? = nil

type QuestCardEntry = {
    Card: Frame,
    TitleLabel: TextLabel,
    ProgressLabel: TextLabel,
    ProgressBarFill: Frame,
    RewardLabel: TextLabel,
    ClaimButton: TextButton,
}

local questCardEntries: { [string]: QuestCardEntry } = {}

--[[
    Toggles the modal visibility.
]]
function QuestModal.Toggle(isOpen: boolean?)
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

function QuestModal.IsOpen(): boolean
    local frame = modalFrame
    return if frame then frame.Visible else false
end

--[[
    Checks if there are any completed quests ready to be claimed.
]]
function QuestModal.HasUnclaimedReward(data: Types.PlayerData?): boolean
    if not data or not data.Quests then return false end
    for _, quest in pairs(data.Quests) do
        if quest.Current >= quest.Target and not quest.Claimed then
            return true
        end
    end
    return false
end

--[[
    Builds the complete Quest Modal.
]]
function QuestModal.Build(parent: ScreenGui, callbacks: {
    OnClaim: (questId: string) -> (),
})
    callbacksRef = callbacks

    local frame = UITheme.CreatePanel({
        Name = "QuestModal",
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
    title.Text = "📜 ROLLING QUESTS & BOUNTIES"
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
        QuestModal.Toggle(false)
    end)

    -- Container for Quests
    local cardsContainer = Instance.new("Frame")
    cardsContainer.Name = "CardsContainer"
    cardsContainer.Size = UDim2.new(1, -40, 1, -72)
    cardsContainer.Position = UDim2.new(0, 20, 0, 60)
    cardsContainer.BackgroundTransparency = 1
    cardsContainer.ZIndex = 31
    cardsContainer.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, 12)
    layout.Parent = cardsContainer

    -- Helper to build 1 Quest Card
    local function createQuestCard(questId: string, icon: string): QuestCardEntry
        local card = Instance.new("Frame")
        card.Name = string.format("Quest_%s", questId)
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

        -- Icon
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

        -- Title
        local tLbl = Instance.new("TextLabel")
        tLbl.Size = UDim2.new(0.55, 0, 0, 24)
        tLbl.Position = UDim2.new(0, 92, 0, 12)
        tLbl.BackgroundTransparency = 1
        tLbl.Font = Constants.THEME.FONT_TITLE
        tLbl.Text = "Loading quest..."
        tLbl.TextColor3 = Constants.THEME.TEXT_PRIMARY
        tLbl.TextSize = 16
        tLbl.TextXAlignment = Enum.TextXAlignment.Left
        tLbl.ZIndex = 33
        tLbl.Parent = card

        -- Progress Bar Background
        local barBg = Instance.new("Frame")
        barBg.Size = UDim2.new(0.55, 0, 0, 16)
        barBg.Position = UDim2.new(0, 92, 0, 42)
        barBg.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
        barBg.BorderSizePixel = 0
        barBg.ZIndex = 33
        barBg.Parent = card

        local barCorner = Instance.new("UICorner")
        barCorner.CornerRadius = UDim.new(0, 8)
        barCorner.Parent = barBg

        local barFill = Instance.new("Frame")
        barFill.Size = UDim2.new(0, 0, 1, 0)
        barFill.BackgroundColor3 = Color3.fromRGB(60, 180, 255)
        barFill.BorderSizePixel = 0
        barFill.ZIndex = 34
        barFill.Parent = barBg

        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(0, 8)
        fillCorner.Parent = barFill

        local pLbl = Instance.new("TextLabel")
        pLbl.Size = UDim2.new(1, 0, 1, 0)
        pLbl.BackgroundTransparency = 1
        pLbl.Font = Constants.THEME.FONT_BODY
        pLbl.Text = "0 / 0"
        pLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        pLbl.TextSize = 11
        pLbl.ZIndex = 35
        pLbl.Parent = barBg

        -- Reward Label
        local rLbl = Instance.new("TextLabel")
        rLbl.Size = UDim2.new(0.55, 0, 0, 26)
        rLbl.Position = UDim2.new(0, 92, 0, 68)
        rLbl.BackgroundTransparency = 1
        rLbl.Font = Constants.THEME.FONT_TITLE
        rLbl.Text = "Rewards: 💰 0 Gold  •  ⭐ 0 XP"
        rLbl.TextColor3 = Constants.THEME.ACCENT_GOLD
        rLbl.TextSize = 13
        rLbl.TextXAlignment = Enum.TextXAlignment.Left
        rLbl.ZIndex = 33
        rLbl.Parent = card

        -- Claim Button
        local claimBtn = UITheme.CreateButton({
            Name = "ClaimBtn",
            Text = "IN PROGRESS",
            Size = UDim2.new(0, 140, 0, 44),
            Position = UDim2.new(1, -156, 0.5, -22),
            BackgroundColor3 = Color3.fromRGB(45, 50, 70),
            TextColor3 = Color3.fromRGB(150, 160, 180),
            TextSize = 13,
            Parent = card,
            OnClick = function()
                if callbacksRef then callbacksRef.OnClaim(questId) end
            end,
        })
        claimBtn.ZIndex = 34

        return {
            Card = card,
            TitleLabel = tLbl,
            ProgressLabel = pLbl,
            ProgressBarFill = barFill,
            RewardLabel = rLbl,
            ClaimButton = claimBtn,
        }
    end

    questCardEntries["RollChest"] = createQuestCard("RollChest", "🎲")
    questCardEntries["KillMonsters"] = createQuestCard("KillMonsters", "⚔️")
    questCardEntries["ClearDungeon"] = createQuestCard("ClearDungeon", "🏰")
end

--[[
    Updates Quest cards with latest player quest data.
]]
function QuestModal.Update(data: Types.PlayerData)
    if not data or not data.Quests then return end

    for qId, entry in pairs(questCardEntries) do
        local qData = data.Quests[qId]
        if qData then
            entry.TitleLabel.Text = string.format("Tier %d: %s", qData.Tier or 1, qData.Title)

            local ratio = math.clamp(qData.Current / math.max(1, qData.Target), 0, 1)
            entry.ProgressBarFill.Size = UDim2.new(ratio, 0, 1, 0)
            entry.ProgressLabel.Text = string.format("%d / %d", qData.Current, qData.Target)

            local rewardStr = string.format("Rewards: 💰 %d Gold  •  ⭐ %d XP", qData.RewardGold, qData.RewardXP)
            if qData.RewardBuff == "LuckPotion" then
                rewardStr ..= "  •  🍀 Luck Potion (5m)"
            end
            entry.RewardLabel.Text = rewardStr

            -- Button state
            if qData.Current >= qData.Target and not qData.Claimed then
                entry.ClaimButton.Text = "CLAIM REWARD"
                entry.ClaimButton.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
                entry.ClaimButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                entry.ProgressBarFill.BackgroundColor3 = Color3.fromRGB(60, 220, 100)
            else
                entry.ClaimButton.Text = "IN PROGRESS"
                entry.ClaimButton.BackgroundColor3 = Color3.fromRGB(45, 50, 70)
                entry.ClaimButton.TextColor3 = Color3.fromRGB(150, 160, 180)
                entry.ProgressBarFill.BackgroundColor3 = Color3.fromRGB(60, 160, 255)
            end
        end
    end
end

return QuestModal
