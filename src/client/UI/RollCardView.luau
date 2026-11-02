--!strict
--[[
    RollCardView.luau
    Displays procedural Roll Result popups for Single & Multi-Roll (1x, 2x, 3x)
    with Item Traits and cinematic cutscenes for high-tier loot.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Constants = require(Shared:WaitForChild("Constants"))
local RarityConfig = require(Shared:WaitForChild("RarityConfig"))
local TraitConfig = require(Shared:WaitForChild("TraitConfig"))

local UITheme = require(script.Parent.UITheme)

local RollCardView = {}

local activeContainer: Frame? = nil
local _activeCutscene: Frame? = nil

--[[
    Plays cinematic reveal cutscene for Legendary+ items.
]]
local function playCinematicCutscene(parent: ScreenGui, rarityColor: Color3, onComplete: () -> ())
    local cutsceneFrame = Instance.new("Frame")
    cutsceneFrame.Name = "CutsceneOverlay"
    cutsceneFrame.Size = UDim2.new(1, 0, 1, 0)
    cutsceneFrame.Position = UDim2.new(0, 0, 0, 0)
    cutsceneFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    cutsceneFrame.BackgroundTransparency = 1
    cutsceneFrame.ZIndex = 50
    cutsceneFrame.Parent = parent
    _activeCutscene = cutsceneFrame

    -- Rotating Ray Starburst
    local starburst = Instance.new("Frame")
    starburst.Name = "Starburst"
    starburst.Size = UDim2.new(0, 420, 0, 420)
    starburst.Position = UDim2.new(0.5, 0, 0.5, 0)
    starburst.AnchorPoint = Vector2.new(0.5, 0.5)
    starburst.BackgroundColor3 = rarityColor
    starburst.BackgroundTransparency = 0.8
    starburst.ZIndex = 51
    starburst.Parent = cutsceneFrame

    local burstCorner = Instance.new("UICorner")
    burstCorner.CornerRadius = UDim.new(1, 0)
    burstCorner.Parent = starburst

    -- Flash text
    local alertText = Instance.new("TextLabel")
    alertText.Name = "RarityAlert"
    alertText.Size = UDim2.new(1, 0, 0, 60)
    alertText.Position = UDim2.new(0.5, 0, 0.35, 0)
    alertText.AnchorPoint = Vector2.new(0.5, 0.5)
    alertText.BackgroundTransparency = 1
    alertText.Font = Constants.THEME.FONT_TITLE
    alertText.Text = "★ RARE DROP DETECTED ★"
    alertText.TextColor3 = rarityColor
    alertText.TextSize = 28
    alertText.ZIndex = 52
    alertText.Parent = cutsceneFrame

    -- Sequence: Fade in black -> rotate rays -> flash out
    local tweenIn = TweenService:Create(cutsceneFrame, TweenInfo.new(0.35), { BackgroundTransparency = 0.25 })
    local rotateTween = TweenService:Create(starburst, TweenInfo.new(1.0, Enum.EasingStyle.Linear), { Rotation = 180 })

    tweenIn:Play()
    rotateTween:Play()

    task.delay(1.1, function()
        local tweenOut = TweenService:Create(cutsceneFrame, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
        tweenOut:Play()
        tweenOut.Completed:Connect(function()
            cutsceneFrame:Destroy()
            _activeCutscene = nil
            onComplete()
        end)
    end)
end

--[[
    Constructs a single card frame inside the container.
]]
local function buildSingleCard(parentContainer: Frame, entry: any, cardWidth: number): Frame
    local itemDef = entry.Item :: Types.ItemDefinition
    local tierCfg = RarityConfig.Get(itemDef.Rarity)
    local rarityColor = if tierCfg then tierCfg.Color else Color3.fromRGB(255, 255, 255)

    local card = UITheme.CreatePanel({
        Name = "Card_" .. itemDef.Id,
        Size = UDim2.new(0, cardWidth, 0, 360),
        BackgroundColor3 = Constants.THEME.BACKGROUND_DARK,
        StrokeColor = rarityColor,
        StrokeThickness = 2.4,
        CornerRadius = UDim.new(0, 16),
        Parent = parentContainer,
    })
    card.ZIndex = 41

    -- Top Rarity Banner
    local banner = Instance.new("Frame")
    banner.Name = "RarityBanner"
    banner.Size = UDim2.new(1, -20, 0, 32)
    banner.Position = UDim2.new(0, 10, 0, 12)
    banner.BackgroundColor3 = Color3.fromRGB(24, 27, 40)
    banner.BorderSizePixel = 0
    banner.ZIndex = 42
    banner.Parent = card

    local bannerCorner = Instance.new("UICorner")
    bannerCorner.CornerRadius = UDim.new(0, 8)
    bannerCorner.Parent = banner

    local bannerStroke = Instance.new("UIStroke")
    bannerStroke.Color = rarityColor
    bannerStroke.Thickness = 1.2
    bannerStroke.Parent = banner

    local rarityLabel = Instance.new("TextLabel")
    rarityLabel.Size = UDim2.new(1, 0, 1, 0)
    rarityLabel.BackgroundTransparency = 1
    rarityLabel.Font = Constants.THEME.FONT_TITLE
    rarityLabel.Text = string.upper(itemDef.Rarity)
    rarityLabel.TextColor3 = rarityColor
    rarityLabel.TextSize = 14
    rarityLabel.ZIndex = 43
    rarityLabel.Parent = banner

    -- Item Name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "ItemName"
    nameLabel.Size = UDim2.new(1, -20, 0, 28)
    nameLabel.Position = UDim2.new(0, 10, 0, 48)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Constants.THEME.FONT_TITLE
    nameLabel.Text = itemDef.Name
    nameLabel.TextColor3 = Constants.THEME.TEXT_PRIMARY
    nameLabel.TextSize = 16
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.ZIndex = 42
    nameLabel.Parent = card

    -- Slot & Quality Badge
    local rawQuality = if typeof(entry.Quality) == "number" then math.round(entry.Quality) else 50
    local qualityMult = 0.5 + (rawQuality / 100) * 1.0

    -- Quality Color Coding (<40% Gray, 40-70% Green, 71-89% Purple, 90-100% Golden Yellow)
    local qualityColor = Color3.fromRGB(150, 155, 170)
    if rawQuality >= 90 then
        qualityColor = Color3.fromRGB(255, 205, 40)
    elseif rawQuality >= 71 then
        qualityColor = Color3.fromRGB(180, 80, 255)
    elseif rawQuality >= 40 then
        qualityColor = Color3.fromRGB(80, 220, 120)
    end

    local subLabel = Instance.new("TextLabel")
    subLabel.Name = "SubDetail"
    subLabel.Size = UDim2.new(1, -20, 0, 18)
    subLabel.Position = UDim2.new(0, 10, 0, 76)
    subLabel.BackgroundTransparency = 1
    subLabel.Font = Constants.THEME.FONT_TITLE
    subLabel.Text = string.format("%s  •  Quality: %d%%", itemDef.Slot, rawQuality)
    subLabel.TextColor3 = qualityColor
    subLabel.TextSize = 12
    subLabel.ZIndex = 42
    subLabel.Parent = card

    -- Item Trait Badge
    local traitBadge = Instance.new("TextLabel")
    traitBadge.Name = "TraitBadge"
    traitBadge.Size = UDim2.new(1, -20, 0, 22)
    traitBadge.Position = UDim2.new(0, 10, 0, 96)
    traitBadge.BackgroundTransparency = 1
    traitBadge.Font = Constants.THEME.FONT_TITLE
    traitBadge.ZIndex = 42
    traitBadge.Parent = card

    if entry.Trait then
        local tDef = TraitConfig.Get(entry.Trait)
        if tDef then
            traitBadge.Text = string.format("🔮 %s: %s", tDef.DisplayName, tDef.Description)
            traitBadge.TextColor3 = tDef.Color
        else
            traitBadge.Text = string.format("🔮 Trait: %s", entry.Trait)
            traitBadge.TextColor3 = Color3.fromRGB(220, 220, 255)
        end
        traitBadge.TextSize = 11
    else
        traitBadge.Text = "No Trait"
        traitBadge.TextColor3 = Color3.fromRGB(90, 95, 115)
        traitBadge.TextSize = 10
    end

    -- Stats Box
    local statsBox = Instance.new("Frame")
    statsBox.Name = "StatsBox"
    statsBox.Size = UDim2.new(1, -20, 0, 110)
    statsBox.Position = UDim2.new(0, 10, 0, 122)
    statsBox.BackgroundColor3 = Color3.fromRGB(20, 23, 34)
    statsBox.BorderSizePixel = 0
    statsBox.ZIndex = 42
    statsBox.Parent = card

    local statsCorner = Instance.new("UICorner")
    statsCorner.CornerRadius = UDim.new(0, 8)
    statsCorner.Parent = statsBox

    local statsLayout = Instance.new("UIListLayout")
    statsLayout.FillDirection = Enum.FillDirection.Vertical
    statsLayout.Padding = UDim.new(0, 4)
    statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    statsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    statsLayout.Parent = statsBox

    local function addStatLine(text: string, color: Color3)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -16, 0, 20)
        lbl.BackgroundTransparency = 1
        lbl.Font = Constants.THEME.FONT_BODY
        lbl.Text = text
        lbl.TextColor3 = color
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 43
        lbl.Parent = statsBox
    end

    local rarityMult = RarityConfig.GetMultiplier(itemDef.Rarity)
    if (itemDef.BaseStats.MaxHP or 0) > 0 then
        local val = math.round(itemDef.BaseStats.MaxHP * rarityMult * qualityMult)
        addStatLine(string.format("❤️ Health: +%d HP", val), Color3.fromRGB(75, 220, 110))
    end
    if (itemDef.BaseStats.Damage or 0) > 0 then
        local val = math.round(itemDef.BaseStats.Damage * rarityMult * qualityMult)
        addStatLine(string.format("⚔️ Damage: +%d DMG", val), Color3.fromRGB(255, 110, 80))
    end
    if (itemDef.BaseStats.CritChance or 0) > 0 then
        local val = itemDef.BaseStats.CritChance * rarityMult * qualityMult * 100
        addStatLine(string.format("💥 Crit Chance: +%.1f%%", val), Color3.fromRGB(255, 200, 40))
    end
    if (itemDef.BaseStats.LuckBonus or 0) > 0 then
        local val = itemDef.BaseStats.LuckBonus * rarityMult * qualityMult
        addStatLine(string.format("🍀 Luck Bonus: +%.1fx", val), Color3.fromRGB(80, 230, 255))
    end

    -- Bottom Status: Auto-Sold or Added
    local statusFrame = Instance.new("Frame")
    statusFrame.Size = UDim2.new(1, -20, 0, 36)
    statusFrame.Position = UDim2.new(0, 10, 1, -48)
    statusFrame.BorderSizePixel = 0
    statusFrame.ZIndex = 42
    statusFrame.Parent = card

    local sCorner = Instance.new("UICorner")
    sCorner.CornerRadius = UDim.new(0, 8)
    sCorner.Parent = statusFrame

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 1, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Constants.THEME.FONT_TITLE
    statusLabel.TextSize = 12
    statusLabel.ZIndex = 43
    statusLabel.Parent = statusFrame

    if entry.AutoSold then
        statusFrame.BackgroundColor3 = Color3.fromRGB(45, 40, 25)
        statusLabel.Text = string.format("💰 Auto-Sold (+%d Gold)", entry.GoldEarned or 0)
        statusLabel.TextColor3 = Constants.THEME.ACCENT_GOLD
    else
        statusFrame.BackgroundColor3 = Color3.fromRGB(25, 45, 35)
        statusLabel.Text = "✨ Added to Bag"
        statusLabel.TextColor3 = Color3.fromRGB(75, 220, 130)
    end

    return card
end

--[[
    Displays the Roll Result Card(s) on screen.
]]
function RollCardView.ShowRollResult(parent: ScreenGui, result: any)
    if not result.Success then return end

    local itemsList: { any } = {}
    if result.Items and #result.Items > 0 then
        itemsList = result.Items
    elseif result.Item then
        table.insert(itemsList, {
            Item = result.Item,
            UUID = result.UUID,
            Quality = result.Quality,
            Trait = result.Trait,
            AutoSold = result.AutoSold,
            GoldEarned = result.GoldEarned,
            PityTriggered = result.PityTriggered,
        })
    else
        return
    end

    -- Check if any item triggers cutscene
    local highestRarityColor = Color3.fromRGB(255, 255, 255)
    local shouldCutscene = false

    for _, entry in ipairs(itemsList) do
        if entry.Item and RarityConfig.ShouldCutscene(entry.Item.Rarity) then
            shouldCutscene = true
            local cfg = RarityConfig.Get(entry.Item.Rarity)
            if cfg then
                highestRarityColor = cfg.Color
            end
        end
    end

    local function displayCards()
        if activeContainer then
            activeContainer:Destroy()
            activeContainer = nil
        end

        local count = #itemsList
        local totalWidth = if count == 1 then 320 elseif count == 2 then 600 else 840
        local cardWidth = if count == 1 then 320 elseif count == 2 then 285 else 265

        local container = Instance.new("Frame")
        container.Name = "RollResultsContainer"
        container.Size = UDim2.new(0, totalWidth, 0, 360)
        container.Position = UDim2.new(0.5, 0, 0.5, 0)
        container.AnchorPoint = Vector2.new(0.5, 0.5)
        container.BackgroundTransparency = 1
        container.ZIndex = 40
        container.Parent = parent
        activeContainer = container

        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.VerticalAlignment = Enum.VerticalAlignment.Center
        layout.Padding = UDim.new(0, 14)
        layout.Parent = container

        -- Pop-in animation
        container.Size = UDim2.new(0, math.round(totalWidth * 0.7), 0, 260)
        TweenService:Create(container, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, totalWidth, 0, 360)
        }):Play()

        for _, entry in ipairs(itemsList) do
            buildSingleCard(container, entry, cardWidth)
        end

        -- Auto-dismiss after 3.8s
        task.delay(3.8, function()
            if activeContainer == container then
                TweenService:Create(container, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
                container:Destroy()
                activeContainer = nil
            end
        end)
    end

    if shouldCutscene then
        playCinematicCutscene(parent, highestRarityColor, displayCards)
    else
        displayCards()
    end
end

return RollCardView
