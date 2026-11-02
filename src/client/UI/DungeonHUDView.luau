--!strict
--[[
    DungeonHUDView.luau
    Displays the Top-Center Dungeon tracker during active expeditions and the Victory Popup.
    Tracks Wave progression, remaining enemy count, and provides an instant Leave button.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local UITheme = require(script.Parent.UITheme)

local DungeonHUDView = {}

local hudFrame: Frame? = nil
local nameLabel: TextLabel? = nil
local waveLabel: TextLabel? = nil
local enemiesLabel: TextLabel? = nil

local victoryCard: Frame? = nil
local victoryRewards: TextLabel? = nil

function DungeonHUDView.Build(parent: ScreenGui, onLeave: () -> ())
    -- 1. Top-Center Banner
    local banner = UITheme.CreatePanel({
        Name = "DungeonTopBanner",
        Size = UDim2.new(0, 480, 0, 68),
        Position = UDim2.new(0.5, 0, 0, 16),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = Constants.THEME.BACKGROUND_DARK,
        StrokeColor = Constants.THEME.STROKE_DEFAULT,
        StrokeThickness = 1.8,
        CornerRadius = UDim.new(0, 14),
        Parent = parent,
    })
    banner.Visible = false
    banner.ZIndex = 25
    hudFrame = banner

    local dName = Instance.new("TextLabel")
    dName.Name = "DungeonName"
    dName.Size = UDim2.new(0, 200, 0, 24)
    dName.Position = UDim2.new(0, 18, 0, 10)
    dName.BackgroundTransparency = 1
    dName.Font = Constants.THEME.FONT_TITLE
    dName.Text = "🏰 DUNGEON"
    dName.TextColor3 = Constants.THEME.TEXT_PRIMARY
    dName.TextSize = 15
    dName.TextXAlignment = Enum.TextXAlignment.Left
    dName.ZIndex = 26
    dName.Parent = banner
    nameLabel = dName

    local dWave = Instance.new("TextLabel")
    dWave.Name = "WaveTracker"
    dWave.Size = UDim2.new(0, 140, 0, 24)
    dWave.Position = UDim2.new(0, 220, 0, 10)
    dWave.BackgroundTransparency = 1
    dWave.Font = Constants.THEME.FONT_TITLE
    dWave.Text = "WAVE 1 / 3"
    dWave.TextColor3 = Color3.fromRGB(100, 190, 255)
    dWave.TextSize = 14
    dWave.TextXAlignment = Enum.TextXAlignment.Left
    dWave.ZIndex = 26
    dWave.Parent = banner
    waveLabel = dWave

    local dEnemies = Instance.new("TextLabel")
    dEnemies.Name = "EnemiesCount"
    dEnemies.Size = UDim2.new(0, 340, 0, 20)
    dEnemies.Position = UDim2.new(0, 18, 0, 38)
    dEnemies.BackgroundTransparency = 1
    dEnemies.Font = Constants.THEME.FONT_BODY
    dEnemies.Text = "👾 3 Enemies Alive"
    dEnemies.TextColor3 = Constants.THEME.TEXT_SECONDARY
    dEnemies.TextSize = 12
    dEnemies.TextXAlignment = Enum.TextXAlignment.Left
    dEnemies.ZIndex = 26
    dEnemies.Parent = banner
    enemiesLabel = dEnemies

    -- Leave Dungeon Button
    local leaveBtn = UITheme.CreateButton({
        Name = "LeaveDungeonBtn",
        Text = "🚪 LEAVE",
        Size = UDim2.new(0, 100, 0, 38),
        Position = UDim2.new(1, -114, 0, 15),
        BackgroundColor3 = Color3.fromRGB(180, 40, 50),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 12,
        Parent = banner,
        OnClick = onLeave,
    })
    leaveBtn.ZIndex = 26

    -- 2. Victory Modal Card
    local vCard = UITheme.CreatePanel({
        Name = "DungeonVictoryCard",
        Size = UDim2.new(0, 420, 0, 240),
        Position = UDim2.new(0.5, 0, 0.4, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Constants.THEME.BACKGROUND_DARK,
        StrokeColor = Constants.THEME.ACCENT_GOLD,
        StrokeThickness = 2.5,
        CornerRadius = UDim.new(0, 16),
        Parent = parent,
    })
    vCard.Visible = false
    vCard.ZIndex = 50
    victoryCard = vCard

    local vTitle = Instance.new("TextLabel")
    vTitle.Size = UDim2.new(1, 0, 0, 40)
    vTitle.Position = UDim2.new(0, 0, 0, 20)
    vTitle.BackgroundTransparency = 1
    vTitle.Font = Enum.Font.GothamBlack
    vTitle.Text = "👑 DUNGEON CONQUERED!"
    vTitle.TextColor3 = Constants.THEME.ACCENT_GOLD
    vTitle.TextSize = 22
    vTitle.ZIndex = 51
    vTitle.Parent = vCard

    local vRewards = Instance.new("TextLabel")
    vRewards.Size = UDim2.new(1, -40, 0, 100)
    vRewards.Position = UDim2.new(0, 20, 0, 68)
    vRewards.BackgroundTransparency = 1
    vRewards.Font = Constants.THEME.FONT_BODY
    vRewards.Text = "Rewards..."
    vRewards.TextColor3 = Constants.THEME.TEXT_PRIMARY
    vRewards.TextSize = 14
    vRewards.TextWrapped = true
    vRewards.ZIndex = 51
    vRewards.Parent = vCard
    victoryRewards = vRewards

    local vHint = Instance.new("TextLabel")
    vHint.Size = UDim2.new(1, 0, 0, 24)
    vHint.Position = UDim2.new(0, 0, 1, -36)
    vHint.BackgroundTransparency = 1
    vHint.Font = Constants.THEME.FONT_BODY
    vHint.Text = "Returning to Lobby in 5 seconds..."
    vHint.TextColor3 = Constants.THEME.TEXT_MUTED
    vHint.TextSize = 12
    vHint.ZIndex = 51
    vHint.Parent = vCard
end

--[[
    Updates or hides the Dungeon HUD based on session state.
]]
function DungeonHUDView.SetState(
    inDungeon: boolean,
    dName: string?,
    wave: number?,
    totalWaves: number?,
    remaining: number?
)
    if not hudFrame then return end

    if inDungeon then
        hudFrame.Visible = true
        if nameLabel and dName then
            nameLabel.Text = string.format("🏰 %s", dName)
        end
        if waveLabel and wave and totalWaves then
            if wave == totalWaves then
                waveLabel.Text = string.format("🔥 BOSS WAVE %d/%d", wave, totalWaves)
                waveLabel.TextColor3 = Color3.fromRGB(255, 75, 75)
            else
                waveLabel.Text = string.format("WAVE %d / %d", wave, totalWaves)
                waveLabel.TextColor3 = Color3.fromRGB(100, 190, 255)
            end
        end
        if enemiesLabel and remaining ~= nil then
            enemiesLabel.Text = string.format("👾 %d %s Remaining", remaining, if remaining == 1 then "Enemy" else "Enemies")
        end
    else
        hudFrame.Visible = false
        if victoryCard then
            victoryCard.Visible = false
        end
    end
end

--[[
    Displays the Victory popup when a dungeon floor is conquered.
]]
function DungeonHUDView.ShowVictory(data: {
    DungeonName: string,
    GoldEarned: number,
    XPEarned: number,
    BonusText: string,
})
    if not victoryCard or not victoryRewards then return end

    victoryRewards.Text = string.format(
        "Floor Conquered: %s\n\n💰 +%d Gold  |  ⭐ +%d XP\n🎲 %s",
        data.DungeonName,
        data.GoldEarned,
        data.XPEarned,
        data.BonusText
    )

    victoryCard.Visible = true
    victoryCard.Position = UDim2.new(0.5, 0, 0.45, 0)
    TweenService:Create(victoryCard, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0.4, 0)
    }):Play()
end

return DungeonHUDView
