--!strict
--[[
    DungeonModal.luau
    Popup UI allowing players to view and select from the 3 Dungeon difficulty tiers.
    Displays Recommended CP, Floor theme, Wave breakdown, and lucrative Gold/XP rewards.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local DungeonConfig = require(Shared:WaitForChild("DungeonConfig"))

local UITheme = require(script.Parent.UITheme)

local DungeonModal = {}

local modalFrame: Frame? = nil
local onEnterCallback: ((dungeonId: string) -> ())? = nil

function DungeonModal.IsOpen(): boolean
    local frame = modalFrame
    return if frame then frame.Visible else false
end

function DungeonModal.Toggle(isOpen: boolean?)
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
        frame.Visible = false
    end
end

function DungeonModal.Build(parent: ScreenGui, onEnter: (dungeonId: string) -> ())
    onEnterCallback = onEnter

    local frame = UITheme.CreatePanel({
        Name = "DungeonModal",
        Size = UDim2.new(0, 780, 0, 480),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Constants.THEME.BACKGROUND_DARK,
        StrokeColor = Constants.THEME.STROKE_DEFAULT,
        StrokeThickness = 2.0,
        CornerRadius = UDim.new(0, 16),
        Parent = parent,
    })
    frame.Visible = false
    frame.ZIndex = 35
    modalFrame = frame

    -- Header
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 0, 36)
    title.Position = UDim2.new(0, 24, 0, 14)
    title.BackgroundTransparency = 1
    title.Font = Constants.THEME.FONT_TITLE
    title.Text = "⚔️ DUNGEON EXPEDITIONS"
    title.TextColor3 = Constants.THEME.TEXT_PRIMARY
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 36
    title.Parent = frame

    local closeBtn = UITheme.CreateButton({
        Name = "CloseButton",
        Text = "X",
        Size = UDim2.new(0, 32, 0, 32),
        Position = UDim2.new(1, -44, 0, 14),
        BackgroundColor3 = Color3.fromRGB(35, 40, 60),
        TextColor3 = Color3.fromRGB(255, 120, 120),
        TextSize = 14,
        Parent = frame,
        OnClick = function()
            DungeonModal.Toggle(false)
        end,
    })
    closeBtn.ZIndex = 36

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -48, 0, 24)
    desc.Position = UDim2.new(0, 24, 0, 48)
    desc.BackgroundTransparency = 1
    desc.Font = Constants.THEME.FONT_BODY
    desc.Text = "Battle through 3 waves of relentless dungeon monsters and defeat the final boss for massive rewards!"
    desc.TextColor3 = Constants.THEME.TEXT_SECONDARY
    desc.TextSize = 12
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.ZIndex = 36
    desc.Parent = frame

    -- 3 Horizontal Dungeon Cards Container
    local cardsContainer = Instance.new("Frame")
    cardsContainer.Name = "CardsContainer"
    cardsContainer.Size = UDim2.new(1, -48, 0, 380)
    cardsContainer.Position = UDim2.new(0, 24, 0, 80)
    cardsContainer.BackgroundTransparency = 1
    cardsContainer.ZIndex = 36
    cardsContainer.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 14)
    layout.Parent = cardsContainer

    local dungeons = DungeonConfig.GetAll()
    for _, dCfg in ipairs(dungeons) do
        local card = Instance.new("Frame")
        card.Name = "Card_" .. dCfg.Id
        card.LayoutOrder = dCfg.FloorNumber
        card.Size = UDim2.new(0, 235, 0, 360)
        card.BackgroundColor3 = Constants.THEME.SURFACE_PANEL
        card.BorderSizePixel = 0
        card.ZIndex = 37
        card.Parent = cardsContainer

        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 12)
        cardCorner.Parent = card

        local cardStroke = Instance.new("UIStroke")
        cardStroke.Color = dCfg.ThemeColor
        cardStroke.Thickness = 1.8
        cardStroke.Parent = card

        -- Floor badge
        local floorBadge = Instance.new("TextLabel")
        floorBadge.Size = UDim2.new(1, -20, 0, 20)
        floorBadge.Position = UDim2.new(0, 10, 0, 12)
        floorBadge.BackgroundTransparency = 1
        floorBadge.Font = Constants.THEME.FONT_TITLE
        floorBadge.Text = string.format("FLOOR %d", dCfg.FloorNumber)
        floorBadge.TextColor3 = dCfg.ThemeColor
        floorBadge.TextSize = 11
        floorBadge.TextXAlignment = Enum.TextXAlignment.Left
        floorBadge.ZIndex = 38
        floorBadge.Parent = card

        -- Dungeon Name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -20, 0, 24)
        nameLabel.Position = UDim2.new(0, 10, 0, 32)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Constants.THEME.FONT_TITLE
        nameLabel.Text = dCfg.Name
        nameLabel.TextColor3 = Constants.THEME.TEXT_PRIMARY
        nameLabel.TextSize = 16
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.ZIndex = 38
        nameLabel.Parent = card

        -- Recommended CP Badge
        local cpBadge = Instance.new("Frame")
        cpBadge.Size = UDim2.new(1, -20, 0, 24)
        cpBadge.Position = UDim2.new(0, 10, 0, 62)
        cpBadge.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
        cpBadge.BorderSizePixel = 0
        cpBadge.ZIndex = 38
        cpBadge.Parent = card

        local cpCorner = Instance.new("UICorner")
        cpCorner.CornerRadius = UDim.new(0, 6)
        cpCorner.Parent = cpBadge

        local cpTxt = Instance.new("TextLabel")
        cpTxt.Size = UDim2.new(1, -10, 1, 0)
        cpTxt.Position = UDim2.new(0, 8, 0, 0)
        cpTxt.BackgroundTransparency = 1
        cpTxt.Font = Constants.THEME.FONT_BODY
        cpTxt.Text = string.format("⚔️ Rec. CP: %d+", dCfg.RecommendedCP)
        cpTxt.TextColor3 = Color3.fromRGB(255, 180, 80)
        cpTxt.TextSize = 11
        cpTxt.TextXAlignment = Enum.TextXAlignment.Left
        cpTxt.ZIndex = 39
        cpTxt.Parent = cpBadge

        -- Description
        local descLbl = Instance.new("TextLabel")
        descLbl.Size = UDim2.new(1, -20, 0, 48)
        descLbl.Position = UDim2.new(0, 10, 0, 94)
        descLbl.BackgroundTransparency = 1
        descLbl.Font = Constants.THEME.FONT_BODY
        descLbl.Text = dCfg.Description
        descLbl.TextColor3 = Constants.THEME.TEXT_SECONDARY
        descLbl.TextSize = 11
        descLbl.TextWrapped = true
        descLbl.TextXAlignment = Enum.TextXAlignment.Left
        descLbl.ZIndex = 38
        descLbl.Parent = card

        -- Wave info
        local waveInfo = Instance.new("TextLabel")
        waveInfo.Size = UDim2.new(1, -20, 0, 20)
        waveInfo.Position = UDim2.new(0, 10, 0, 146)
        waveInfo.BackgroundTransparency = 1
        waveInfo.Font = Constants.THEME.FONT_TITLE
        waveInfo.Text = "⚡ 3 Waves (Includes Boss)"
        waveInfo.TextColor3 = Color3.fromRGB(140, 190, 255)
        waveInfo.TextSize = 11
        waveInfo.TextXAlignment = Enum.TextXAlignment.Left
        waveInfo.ZIndex = 38
        waveInfo.Parent = card

        -- Rewards Box
        local rewBox = Instance.new("Frame")
        rewBox.Size = UDim2.new(1, -20, 0, 100)
        rewBox.Position = UDim2.new(0, 10, 0, 172)
        rewBox.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
        rewBox.BorderSizePixel = 0
        rewBox.ZIndex = 38
        rewBox.Parent = card

        local rewCorner = Instance.new("UICorner")
        rewCorner.CornerRadius = UDim.new(0, 8)
        rewCorner.Parent = rewBox

        local rewTitle = Instance.new("TextLabel")
        rewTitle.Size = UDim2.new(1, -12, 0, 18)
        rewTitle.Position = UDim2.new(0, 8, 0, 6)
        rewTitle.BackgroundTransparency = 1
        rewTitle.Font = Constants.THEME.FONT_TITLE
        rewTitle.Text = "REWARDS:"
        rewTitle.TextColor3 = Constants.THEME.ACCENT_GOLD
        rewTitle.TextSize = 10
        rewTitle.TextXAlignment = Enum.TextXAlignment.Left
        rewTitle.ZIndex = 39
        rewTitle.Parent = rewBox

        local goldLbl = Instance.new("TextLabel")
        goldLbl.Size = UDim2.new(1, -12, 0, 18)
        goldLbl.Position = UDim2.new(0, 8, 0, 26)
        goldLbl.BackgroundTransparency = 1
        goldLbl.Font = Constants.THEME.FONT_BODY
        goldLbl.Text = string.format("💰 +%d Gold", dCfg.Rewards.Gold)
        goldLbl.TextColor3 = Constants.THEME.TEXT_PRIMARY
        goldLbl.TextSize = 11
        goldLbl.TextXAlignment = Enum.TextXAlignment.Left
        goldLbl.ZIndex = 39
        goldLbl.Parent = rewBox

        local xpLbl = Instance.new("TextLabel")
        xpLbl.Size = UDim2.new(1, -12, 0, 18)
        xpLbl.Position = UDim2.new(0, 8, 0, 46)
        xpLbl.BackgroundTransparency = 1
        xpLbl.Font = Constants.THEME.FONT_BODY
        xpLbl.Text = string.format("⭐ +%d XP", dCfg.Rewards.XP)
        xpLbl.TextColor3 = Color3.fromRGB(100, 180, 255)
        xpLbl.TextSize = 11
        xpLbl.TextXAlignment = Enum.TextXAlignment.Left
        xpLbl.ZIndex = 39
        xpLbl.Parent = rewBox

        local rollLbl = Instance.new("TextLabel")
        rollLbl.Size = UDim2.new(1, -12, 0, 26)
        rollLbl.Position = UDim2.new(0, 8, 0, 66)
        rollLbl.BackgroundTransparency = 1
        rollLbl.Font = Constants.THEME.FONT_BODY
        rollLbl.Text = string.format("🎲 %s", dCfg.Rewards.BonusRollText)
        rollLbl.TextColor3 = dCfg.ThemeColor
        rollLbl.TextSize = 10
        rollLbl.TextWrapped = true
        rollLbl.TextXAlignment = Enum.TextXAlignment.Left
        rollLbl.ZIndex = 39
        rollLbl.Parent = rewBox

        -- Enter Button
        local enterBtn = UITheme.CreateButton({
            Name = "EnterBtn_" .. dCfg.Id,
            Text = "⚔️ ENTER DUNGEON",
            Size = UDim2.new(1, -20, 0, 42),
            Position = UDim2.new(0, 10, 1, -52),
            BackgroundColor3 = dCfg.ThemeColor,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextSize = 12,
            Parent = card,
            OnClick = function()
                if onEnterCallback then
                    onEnterCallback(dCfg.Id)
                end
                DungeonModal.Toggle(false)
            end,
        })
        enterBtn.ZIndex = 38
    end
end

return DungeonModal
