--!strict
--[[
    Constants.luau
    Central configuration and constant definitions for the game.
    Includes Dark Fantasy UI palettes, rarity configurations, and network channel identifiers.
]]

local Types = require(script.Parent.Types)

local Constants = {}

--------------------------------------------------------------------------------
-- UI & VISUAL THEME (Dark Fantasy / Modern RPG)
--------------------------------------------------------------------------------
Constants.THEME = {
    -- Backgrounds
    BACKGROUND_DARK = Color3.fromRGB(15, 17, 26),     -- #0F111A Deep Void Dark
    SURFACE_PANEL   = Color3.fromRGB(22, 25, 38),     -- #161926 Card / Panel Background
    SURFACE_HOVER   = Color3.fromRGB(31, 35, 53),     -- #1F2335 Hover State
    SURFACE_ACTIVE  = Color3.fromRGB(41, 46, 70),     -- #292E46 Active / Pressed State

    -- Borders & Strokes
    STROKE_DEFAULT  = Color3.fromRGB(48, 54, 82),     -- Subtle panel border
    STROKE_FOCUSED  = Color3.fromRGB(98, 108, 160),   -- Highlighted border

    -- Typography
    TEXT_PRIMARY    = Color3.fromRGB(242, 244, 255),   -- High contrast white
    TEXT_SECONDARY  = Color3.fromRGB(150, 158, 185),   -- Muted label text
    TEXT_MUTED      = Color3.fromRGB(95, 102, 128),    -- Disabled / Hint text

    -- Accents
    ACCENT_GOLD     = Color3.fromRGB(255, 204, 0),     -- Coins / High Tier
    ACCENT_GEM      = Color3.fromRGB(46, 213, 255),    -- Diamonds / Currency
    ACCENT_DAMAGE   = Color3.fromRGB(255, 68, 85),     -- Combat / Health depletion
    ACCENT_HEALTH   = Color3.fromRGB(60, 220, 120),    -- Health / Success
    ACCENT_MANA     = Color3.fromRGB(50, 130, 255),    -- Energy / Special

    -- Fonts
    FONT_TITLE      = Enum.Font.GothamBold,
    FONT_BODY       = Enum.Font.GothamMedium,
    FONT_MUTED      = Enum.Font.Gotham,
}

local RarityConfig = require(script.Parent.RarityConfig)

--------------------------------------------------------------------------------
-- RARITY CATALOGUE & ROLL WEIGHTS (Reference to RarityConfig)
--------------------------------------------------------------------------------
Constants.RARITY_ORDER = RarityConfig.ORDERED_TIERS
Constants.RARITIES = RarityConfig.TIERS

--------------------------------------------------------------------------------
-- NETWORK IDENTIFIERS
--------------------------------------------------------------------------------
Constants.REMOTE_EVENTS = {
    -- Player State
    PlayerDataLoaded     = "PlayerDataLoaded",
    PlayerDataUpdated    = "PlayerDataUpdated",
    NotificationSent     = "NotificationSent",

    -- RNG & Inventory
    RollResultReceived   = "RollResultReceived",
    ItemEquipped         = "ItemEquipped",
    ItemUnequipped       = "ItemUnequipped",
    ItemLockedChanged    = "ItemLockedChanged",
    EquipmentVisualUpdated = "EquipmentVisualUpdated",
    OpenUIModal          = "OpenUIModal",

    -- Dungeon Combat
    DungeonStateChanged  = "DungeonStateChanged",
    WaveCountdownStarted = "WaveCountdownStarted",
    WaveStarted          = "WaveStarted",
    WaveCompleted        = "WaveCompleted",
    DungeonCompleted     = "DungeonCompleted",
    DungeonFailed        = "DungeonFailed",
    MobSpawned           = "MobSpawned",
    MobDamaged           = "MobDamaged",
    -- Combat Actions & Feedback
    PerformAttack        = "PerformAttack",
    CombatFeedback       = "CombatFeedback",

    -- Multiplayer Custom Party Rooms
    PartyRoomStateUpdated = "PartyRoomStateUpdated",
    PartyInviteReceived   = "PartyInviteReceived",
} :: { [string]: string }

Constants.REMOTE_FUNCTIONS = {
    -- Data & Inventory
    RequestPlayerData       = "RequestPlayerData",
    RequestRoll             = "RequestRoll",
    RequestEquipItem        = "RequestEquipItem",
    RequestUnequipItem      = "RequestUnequipItem",
    RequestEquipBest        = "RequestEquipBest",
    RequestUpgradeItem      = "RequestUpgradeItem",
    RequestSellItem         = "RequestSellItem",
    RequestUpdateAutoDelete = "RequestUpdateAutoDelete",
    RequestToggleLock       = "RequestToggleLock",

    -- Phase 6, 7 & 8: Traits, Quality Reroll, Shop, Quests, and Rebirth
    RequestRerollQuality    = "RequestRerollQuality",
    RequestRerollTrait      = "RequestRerollTrait",
    RequestBuyShopItem      = "RequestBuyShopItem",
    RequestClaimQuestReward = "RequestClaimQuestReward",
    RequestRebirth          = "RequestRebirth",

    -- Dungeon
    RequestEnterDungeon     = "RequestEnterDungeon",
    RequestLeaveDungeon     = "RequestLeaveDungeon",
    RequestPlayerAttack     = "RequestPlayerAttack",

    -- Multiplayer Custom Party Rooms
    RequestPartyRoomAction  = "RequestPartyRoomAction",
} :: { [string]: string }

--------------------------------------------------------------------------------
-- DEFAULT VALUES
--------------------------------------------------------------------------------
Constants.DEFAULT_PLAYER_STATS = {
    MaxHealth   = 100,
    Damage      = 10,
    Defense     = 0,
    Speed       = 16,
    CritChance  = 0.05, -- 5%
    CritDamage  = 1.5,  -- 150%
    AttackSpeed = 1.0,  -- 1.0 attack / sec
    Luck        = 1.0,  -- Base 1.0x luck
} :: Types.PlayerStats

--------------------------------------------------------------------------------
-- COMBAT CONFIGURATION
--------------------------------------------------------------------------------
Constants.COMBAT = {
    M1_COOLDOWN = 0.35,
    M1_COMBO_RESET_TIME = 1.2,
    WHIRLWIND_COOLDOWN = 5.0,
    METEOR_COOLDOWN = 10.0,
    WHIRLWIND_RADIUS = 14,
    METEOR_RADIUS = 18,
    WHIRLWIND_MULT = 1.8,
    METEOR_MULT = 3.0,
    CRIT_MULT = 2.0,
    -- Dash & Heal Mechanics
    DASH_COOLDOWN = 2.5,
    DASH_DISTANCE = 22,
    DASH_DURATION = 0.20,
    DASH_IFRAME_DURATION = 0.30,
    HEAL_COOLDOWN = 12.0,
    HEAL_PERCENT = 0.35,
}

return Constants
