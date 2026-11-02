--!strict
--[[
    HUDView.luau
    Builds the Top-Left Player Status HUD and Bottom Action Control Bar.
    Pure procedural creation following the Dark Fantasy design system.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Constants = require(Shared:WaitForChild("Constants"))
local ItemConfig = require(Shared:WaitForChild("ItemConfig"))
local RarityConfig = require(Shared:WaitForChild("RarityConfig"))

local UITheme = require(script.Parent.UITheme)

local HUDView = {}

local screenGui: ScreenGui? = nil

-- References for dynamic updates
local levelLabel: TextLabel? = nil
local xpBarFill: Frame? = nil
local xpTextLabel: TextLabel? = nil
local goldLabel: TextLabel? = nil
local cpLabel: TextLabel? = nil
local luckLabel: TextLabel? = nil
local pityLabel: TextLabel? = nil
local buffsLabel: TextLabel? = nil
local gemLabel: TextLabel? = nil
local questNotificationDot: Frame? = nil
local autoRollBtn: TextButton? = nil
local bottomBarContainer: Frame? = nil
local cachedData: Types.PlayerData? = nil

function HUDView.GetScreenGui(): ScreenGui
    if not screenGui then
        screenGui = UITheme.CreateScreenGui("DungeonGameHUD", 10)
    end
    return screenGui :: ScreenGui
end

--[[
    Toggles red notification dot on Quest button.
]]
function HUDView.SetQuestNotification(hasUnclaimed: boolean)
    if questNotificationDot then
        questNotificationDot.Visible = hasUnclaimed
    end
end

--[[
    Builds the Top-Left Player Status HUD.
]]
function HUDView.BuildTopHUD(parent: ScreenGui)
    local container = UITheme.CreatePanel({
        Name = "TopHUDContainer",
        Size = UDim2.new(0, 430, 0, 126),
        Position = UDim2.new(0, 18, 0, 18),
        BackgroundColor3 = Constants.THEME.SURFACE_PANEL,
        StrokeColor = Constants.THEME.STROKE_DEFAULT,
        StrokeThickness = 1.8,
        CornerRadius = UDim.new(0, 12),
        Parent = parent,
    })

    -- Row 1: Level Badge, Gold Counter, Gem Counter, CP
    local levelBadge = Instance.new("Frame")
    levelBadge.Name = "LevelBadge"
    levelBadge.Size = UDim2.new(0, 95, 0, 28)
    levelBadge.Position = UDim2.new(0, 12, 0, 10)
    levelBadge.BackgroundColor3 = Color3.fromRGB(35, 40, 62)
    levelBadge.BorderSizePixel = 0
    levelBadge.Parent = container

    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(0, 6)
    badgeCorner.Parent = levelBadge

    local lvlLbl = Instance.new("TextLabel")
    lvlLbl.Name = "LevelLabel"
    lvlLbl.Size = UDim2.new(1, 0, 1, 0)
    lvlLbl.BackgroundTransparency = 1
    lvlLbl.Font = Constants.THEME.FONT_TITLE
    lvlLbl.Text = "LVL 1"
    lvlLbl.TextColor3 = Color3.fromRGB(130, 200, 255)
    lvlLbl.TextSize = 14
    lvlLbl.Parent = levelBadge
    levelLabel = lvlLbl

    -- Gold Display
    local goldBadge = Instance.new("Frame")
    goldBadge.Name = "GoldBadge"
    goldBadge.Size = UDim2.new(0, 105, 0, 28)
    goldBadge.Position = UDim2.new(0, 114, 0, 10)
    goldBadge.BackgroundColor3 = Color3.fromRGB(35, 38, 52)
    goldBadge.BorderSizePixel = 0
    goldBadge.Parent = container

    local goldCorner = Instance.new("UICorner")
    goldCorner.CornerRadius = UDim.new(0, 6)
    goldCorner.Parent = goldBadge

    local gLbl = Instance.new("TextLabel")
    gLbl.Name = "GoldLabel"
    gLbl.Size = UDim2.new(1, -6, 1, 0)
    gLbl.Position = UDim2.new(0, 6, 0, 0)
    gLbl.BackgroundTransparency = 1
    gLbl.Font = Constants.THEME.FONT_TITLE
    gLbl.Text = "💰 100 Gold"
    gLbl.TextColor3 = Constants.THEME.ACCENT_GOLD
    gLbl.TextSize = 12
    gLbl.TextXAlignment = Enum.TextXAlignment.Left
    gLbl.Parent = goldBadge
    goldLabel = gLbl

    -- Gem Display (💎 Mystic Gems)
    local gemBadge = Instance.new("Frame")
    gemBadge.Name = "GemBadge"
    gemBadge.Size = UDim2.new(0, 98, 0, 28)
    gemBadge.Position = UDim2.new(0, 226, 0, 10)
    gemBadge.BackgroundColor3 = Color3.fromRGB(28, 42, 60)
    gemBadge.BorderSizePixel = 0
    gemBadge.Parent = container

    local gemCorner = Instance.new("UICorner")
    gemCorner.CornerRadius = UDim.new(0, 6)
    gemCorner.Parent = gemBadge

    local gmText = Instance.new("TextLabel")
    gmText.Name = "GemLabel"
    gmText.Size = UDim2.new(1, -6, 1, 0)
    gmText.Position = UDim2.new(0, 6, 0, 0)
    gmText.BackgroundTransparency = 1
    gmText.Font = Constants.THEME.FONT_TITLE
    gmText.Text = "💎 5 Gems"
    gmText.TextColor3 = Color3.fromRGB(80, 230, 255)
    gmText.TextSize = 12
    gmText.TextXAlignment = Enum.TextXAlignment.Left
    gmText.Parent = gemBadge
    gemLabel = gmText

    -- Combat Power (CP) Badge
    local cLbl = Instance.new("TextLabel")
    cLbl.Name = "CPLabel"
    cLbl.Size = UDim2.new(0, 92, 0, 28)
    cLbl.Position = UDim2.new(0, 328, 0, 10)
    cLbl.BackgroundTransparency = 1
    cLbl.Font = Constants.THEME.FONT_TITLE
    cLbl.Text = "⚔️ 10 CP"
    cLbl.TextColor3 = Color3.fromRGB(255, 120, 80)
    cLbl.TextSize = 13
    cLbl.TextXAlignment = Enum.TextXAlignment.Right
    cLbl.Parent = container
    cpLabel = cLbl

    -- Row 2: XP Progress Bar
    local xpBarBg = Instance.new("Frame")
    xpBarBg.Name = "XPBarBg"
    xpBarBg.Size = UDim2.new(1, -24, 0, 14)
    xpBarBg.Position = UDim2.new(0, 12, 0, 46)
    xpBarBg.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
    xpBarBg.BorderSizePixel = 0
    xpBarBg.Parent = container

    local xpBgCorner = Instance.new("UICorner")
    xpBgCorner.CornerRadius = UDim.new(0, 7)
    xpBgCorner.Parent = xpBarBg

    local xFill = Instance.new("Frame")
    xFill.Name = "XPBarFill"
    xFill.Size = UDim2.new(0.05, 0, 1, 0)
    xFill.BackgroundColor3 = Color3.fromRGB(60, 160, 255)
    xFill.BorderSizePixel = 0
    xFill.Parent = xpBarBg
    xpBarFill = xFill

    local xpFillCorner = Instance.new("UICorner")
    xpFillCorner.CornerRadius = UDim.new(0, 7)
    xpFillCorner.Parent = xFill

    local xLbl = Instance.new("TextLabel")
    xLbl.Name = "XPText"
    xLbl.Size = UDim2.new(1, 0, 1, 0)
    xLbl.BackgroundTransparency = 1
    xLbl.Font = Constants.THEME.FONT_BODY
    xLbl.Text = "0 / 100 XP"
    xLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    xLbl.TextSize = 10
    xLbl.Parent = xpBarBg
    xpTextLabel = xLbl

    -- Row 3: Luck & Pity Tracker
    local lkLbl = Instance.new("TextLabel")
    lkLbl.Name = "LuckLabel"
    lkLbl.Size = UDim2.new(0, 120, 0, 24)
    lkLbl.Position = UDim2.new(0, 12, 0, 70)
    lkLbl.BackgroundTransparency = 1
    lkLbl.Font = Constants.THEME.FONT_TITLE
    lkLbl.Text = "🍀 Luck: 1.0x"
    lkLbl.TextColor3 = Color3.fromRGB(75, 220, 110)
    lkLbl.TextSize = 12
    lkLbl.TextXAlignment = Enum.TextXAlignment.Left
    lkLbl.Parent = container
    luckLabel = lkLbl

    local ptyLbl = Instance.new("TextLabel")
    ptyLbl.Name = "PityLabel"
    ptyLbl.Size = UDim2.new(1, -140, 0, 24)
    ptyLbl.Position = UDim2.new(0, 130, 0, 70)
    ptyLbl.BackgroundTransparency = 1
    ptyLbl.Font = Constants.THEME.FONT_BODY
    ptyLbl.Text = "Epic: 0/50 | Leg: 0/200"
    ptyLbl.TextColor3 = Color3.fromRGB(170, 180, 210)
    ptyLbl.TextSize = 11
    ptyLbl.TextXAlignment = Enum.TextXAlignment.Right
    ptyLbl.Parent = container
    pityLabel = ptyLbl

    -- Row 4: Active Potion Buffs Tracker
    local bLbl = Instance.new("TextLabel")
    bLbl.Name = "BuffsLabel"
    bLbl.Size = UDim2.new(1, -24, 0, 20)
    bLbl.Position = UDim2.new(0, 12, 0, 96)
    bLbl.BackgroundTransparency = 1
    bLbl.Font = Constants.THEME.FONT_TITLE
    bLbl.Text = ""
    bLbl.TextColor3 = Color3.fromRGB(80, 220, 140)
    bLbl.TextSize = 11
    bLbl.TextXAlignment = Enum.TextXAlignment.Left
    bLbl.Parent = container
    buffsLabel = bLbl

    -- Real-time countdown for buffs tracker in Top HUD
    RunService.RenderStepped:Connect(function()
        if not buffsLabel or not cachedData or not cachedData.ActiveBuffs then return end
        local now = os.time()
        local luckRemaining = (cachedData.ActiveBuffs.LuckBoostEndTime or 0) - now
        local goldRemaining = (cachedData.ActiveBuffs.GoldBoostEndTime or 0) - now

        local buffTexts = {}
        if luckRemaining > 0 then
            local mins = math.floor(luckRemaining / 60)
            local secs = luckRemaining % 60
            table.insert(buffTexts, string.format("🍀 2x Luck (%02d:%02d)", mins, secs))
        end
        if goldRemaining > 0 then
            local mins = math.floor(goldRemaining / 60)
            local secs = goldRemaining % 60
            table.insert(buffTexts, string.format("💰 2x Gold (%02d:%02d)", mins, secs))
        end

        if #buffTexts > 0 then
            buffsLabel.Text = table.concat(buffTexts, "  •  ")
        else
            buffsLabel.Text = ""
        end
    end)
end

--[[
    Builds the Bottom Action Bar with 7 action controls:
    Auto-Sell, Bag, Shop, Roll Chest, Auto-Roll, Quests, Dungeons.
]]
function HUDView.BuildBottomBar(parent: ScreenGui, callbacks: {
    OnRoll: () -> (),
    OnToggleAutoRoll: () -> (),
    OnOpenInventory: () -> (),
    OnOpenAutoSell: () -> (),
    OnOpenShop: () -> (),
    OnOpenQuests: () -> (),
    OnOpenRebirth: () -> (),
    OnDungeons: () -> (),
})
    local barContainer = Instance.new("Frame")
    barContainer.Name = "BottomBarContainer"
    barContainer.Size = UDim2.new(0, 840, 0, 68)
    barContainer.Position = UDim2.new(0.5, 0, 1, -24)
    barContainer.AnchorPoint = Vector2.new(0.5, 1)
    barContainer.BackgroundColor3 = Constants.THEME.BACKGROUND_DARK
    barContainer.BorderSizePixel = 0
    barContainer.Parent = parent
    bottomBarContainer = barContainer

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 16)
    barCorner.Parent = barContainer

    local barStroke = Instance.new("UIStroke")
    barStroke.Color = Constants.THEME.STROKE_DEFAULT
    barStroke.Thickness = 1.8
    barStroke.Parent = barContainer

    -- Layout
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 8)
    layout.Parent = barContainer

    -- 1. Auto-Sell Filter Button
    UITheme.CreateButton({
        Name = "AutoSellButton",
        Text = "⚙️ SELL",
        Size = UDim2.new(0, 90, 0, 46),
        BackgroundColor3 = Constants.THEME.SURFACE_PANEL,
        TextColor3 = Constants.THEME.TEXT_PRIMARY,
        TextSize = 12,
        Parent = barContainer,
        OnClick = callbacks.OnOpenAutoSell,
    })

    -- 2. Inventory Button (Shortcut B)
    UITheme.CreateButton({
        Name = "InventoryButton",
        Text = "🎒 BAG (B)",
        Size = UDim2.new(0, 90, 0, 46),
        BackgroundColor3 = Constants.THEME.SURFACE_PANEL,
        TextColor3 = Constants.THEME.TEXT_PRIMARY,
        TextSize = 12,
        Parent = barContainer,
        OnClick = callbacks.OnOpenInventory,
    })

    -- 3. Potion & Upgrade Shop Button
    UITheme.CreateButton({
        Name = "ShopButton",
        Text = "🧪 SHOP",
        Size = UDim2.new(0, 90, 0, 46),
        BackgroundColor3 = Color3.fromRGB(30, 100, 160),
        TextColor3 = Color3.fromRGB(240, 245, 255),
        TextSize = 12,
        Parent = barContainer,
        OnClick = callbacks.OnOpenShop,
    })

    -- 4. Center Giant ROLL CHEST Button
    local rollBtn = UITheme.CreateButton({
        Name = "RollChestButton",
        Text = "🎲 ROLL CHEST",
        Size = UDim2.new(0, 140, 0, 52),
        BackgroundColor3 = Color3.fromRGB(240, 150, 20),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 15,
        StrokeColor = Color3.fromRGB(255, 215, 80),
        Parent = barContainer,
        OnClick = callbacks.OnRoll,
    })

    -- Pulse effect for center button
    local rollStroke = rollBtn:FindFirstChild("ButtonStroke")
    if rollStroke and rollStroke:IsA("UIStroke") then
        rollStroke.Thickness = 2.5
    end

    -- 5. Auto-Roll Toggle Button
    autoRollBtn = UITheme.CreateButton({
        Name = "AutoRollButton",
        Text = "⚡ AUTO: OFF",
        Size = UDim2.new(0, 90, 0, 46),
        BackgroundColor3 = Color3.fromRGB(45, 50, 70),
        TextColor3 = Color3.fromRGB(200, 210, 240),
        TextSize = 12,
        Parent = barContainer,
        OnClick = callbacks.OnToggleAutoRoll,
    })

    -- 6. Quests Button with Notification Dot
    local qBtn = UITheme.CreateButton({
        Name = "QuestsButton",
        Text = "📜 QUESTS",
        Size = UDim2.new(0, 90, 0, 46),
        BackgroundColor3 = Color3.fromRGB(130, 80, 25),
        TextColor3 = Color3.fromRGB(255, 240, 220),
        TextSize = 12,
        Parent = barContainer,
        OnClick = callbacks.OnOpenQuests,
    })

    local qDot = Instance.new("Frame")
    qDot.Name = "NotificationDot"
    qDot.Size = UDim2.new(0, 12, 0, 12)
    qDot.Position = UDim2.new(1, -6, 0, -4)
    qDot.BackgroundColor3 = Color3.fromRGB(255, 50, 65)
    qDot.BorderSizePixel = 0
    qDot.Visible = false
    qDot.ZIndex = 50
    qDot.Parent = qBtn

    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = qDot
    questNotificationDot = qDot

    -- 7. Dungeons Expedition Button
    UITheme.CreateButton({
        Name = "DungeonsButton",
        Text = "⚔️ DUNGEON",
        Size = UDim2.new(0, 88, 0, 46),
        BackgroundColor3 = Color3.fromRGB(140, 35, 45),
        TextColor3 = Color3.fromRGB(255, 230, 230),
        TextSize = 12,
        Parent = barContainer,
        OnClick = callbacks.OnDungeons,
    })

    -- 8. Rebirth & Ascension Button
    UITheme.CreateButton({
        Name = "RebirthButton",
        Text = "🔥 REBIRTH",
        Size = UDim2.new(0, 92, 0, 46),
        BackgroundColor3 = Color3.fromRGB(190, 75, 20),
        TextColor3 = Color3.fromRGB(255, 240, 220),
        TextSize = 12,
        Parent = barContainer,
        OnClick = callbacks.OnOpenRebirth,
    })
end

--[[
    Toggles visibility of the bottom action bar (e.g. hides inside dungeons to focus on combat).
]]
function HUDView.SetBottomBarVisible(visible: boolean)
    if bottomBarContainer then
        bottomBarContainer.Visible = visible
    end
end

--[[
    Updates HUD elements dynamically based on updated PlayerData.
]]
function HUDView.Update(data: Types.PlayerData)
    cachedData = data

    if levelLabel then
        local rebirths = data.Rebirths or 0
        if rebirths > 0 then
            levelLabel.Text = string.format("LVL %d • 🔥 R-%d", data.Level, rebirths)
        else
            levelLabel.Text = string.format("LVL %d", data.Level)
        end
    end

    if goldLabel then
        goldLabel.Text = string.format("💰 %d Gold", data.Gold)
    end

    if gemLabel then
        gemLabel.Text = string.format("💎 %d Gems", data.Gems or 0)
    end

    if xpBarFill and xpTextLabel then
        local ratio = math.clamp(data.XP / math.max(1, data.NextLevelXP), 0, 1)
        xpBarFill.Size = UDim2.new(math.max(0.04, ratio), 0, 1, 0)
        xpTextLabel.Text = string.format("%d / %d XP", data.XP, data.NextLevelXP)
    end

    -- Compute CP & Luck from equipped items
    local totalCP = 10
    local totalLuck = data.BaseLuck or 1.0

    for _, slot in ipairs({ "Weapon", "Armor", "Accessory" } :: { Types.ItemSlot }) do
        local uuid = data.Equipped[slot]
        if uuid and data.Inventory[uuid] then
            local invItem = data.Inventory[uuid]
            local itemDef = ItemConfig.Get(invItem.ItemId)
            if itemDef then
                local mult = RarityConfig.GetMultiplier(itemDef.Rarity)
                local rawQuality = invItem.Quality or 50
                local qualityMultiplier = 0.5 + (rawQuality / 100) * 1.0
                local enchant = 1.0 + (invItem.EnchantLevel * 0.1)
                local factor = mult * qualityMultiplier * enchant

                local hpScore = (itemDef.BaseStats.MaxHP or 0) * 1.0
                local dmgScore = (itemDef.BaseStats.Damage or 0) * 3.5
                local critScore = (itemDef.BaseStats.CritChance or 0) * 600.0
                local luckScore = (itemDef.BaseStats.LuckBonus or 0) * 80.0

                totalCP += math.round((hpScore + dmgScore + critScore + luckScore) * factor)
                totalLuck += (itemDef.BaseStats.LuckBonus or 0) * mult
            end
        end
    end

    -- Double luck if potion active
    if data.ActiveBuffs and os.time() < (data.ActiveBuffs.LuckBoostEndTime or 0) then
        totalLuck *= 2.0
    end

    -- Apply Rebirth Stat Multipliers (+35% CP, +1.5 Luck per rebirth)
    local rebirths = data.Rebirths or 0
    if rebirths > 0 then
        totalCP = math.round(totalCP * (1.0 + rebirths * 0.35))
        totalLuck += (rebirths * 1.5)
    end

    if cpLabel then
        cpLabel.Text = string.format("⚔️ %d CP", totalCP)
    end

    if luckLabel then
        luckLabel.Text = string.format("🍀 Luck: %.1fx", totalLuck)
    end

    if pityLabel then
        local epicPity = data.RollCount % 50
        local legPity = data.PityCounter % 200
        pityLabel.Text = string.format("Epic: %d/50 | Leg: %d/200", epicPity, legPity)
    end
end

--[[
    Toggles visual state of Auto Roll button.
]]
function HUDView.SetAutoRollState(isActive: boolean)
    if autoRollBtn then
        if isActive then
            autoRollBtn.Text = "⚡ AUTO: ON"
            autoRollBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
            autoRollBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            autoRollBtn.Text = "⚡ AUTO: OFF"
            autoRollBtn.BackgroundColor3 = Color3.fromRGB(45, 50, 70)
            autoRollBtn.TextColor3 = Color3.fromRGB(200, 210, 240)
        end
    end
end

return HUDView
