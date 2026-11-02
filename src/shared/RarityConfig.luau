--!strict
--[[
    RarityConfig.luau
    Defines the 7 core rarity tiers, their weights, visual styling,
    stat multipliers, and cutscene triggers.
]]

local Types = require(script.Parent.Types)

local RarityConfig = {}

RarityConfig.TIERS = {
    Common = {
        Tier = "Common",
        DisplayName = "Common",
        Weight = 10000, -- 1/1 Base
        Color = Color3.fromRGB(240, 240, 245), -- Trắng
        StatMultiplier = 1.0,
        PlayCutscene = false,
        Rank = 1,
    },
    Uncommon = {
        Tier = "Uncommon",
        DisplayName = "Uncommon",
        Weight = 2000,  -- 1/5
        Color = Color3.fromRGB(75, 220, 110),  -- Xanh lá
        StatMultiplier = 1.3,
        PlayCutscene = false,
        Rank = 2,
    },
    Rare = {
        Tier = "Rare",
        DisplayName = "Rare",
        Weight = 400,   -- 1/25
        Color = Color3.fromRGB(60, 160, 255),  -- Xanh dương
        StatMultiplier = 1.8,
        PlayCutscene = false,
        Rank = 3,
    },
    Epic = {
        Tier = "Epic",
        DisplayName = "Epic",
        Weight = 100,   -- 1/100
        Color = Color3.fromRGB(185, 75, 255),  -- Tím
        StatMultiplier = 2.6,
        PlayCutscene = false,
        Rank = 4,
    },
    Legendary = {
        Tier = "Legendary",
        DisplayName = "Legendary",
        Weight = 20,    -- 1/500
        Color = Color3.fromRGB(255, 175, 25),  -- Vàng cam
        StatMultiplier = 4.0,
        PlayCutscene = true,                   -- Bật cutscene từ Legendary
        Rank = 5,
    },
    Mythic = {
        Tier = "Mythic",
        DisplayName = "Mythic",
        Weight = 4,     -- 1/2500
        Color = Color3.fromRGB(255, 45, 85),   -- Đỏ rực
        StatMultiplier = 6.5,
        PlayCutscene = true,
        Rank = 6,
    },
    Secret = {
        Tier = "Secret",
        DisplayName = "Secret",
        Weight = 1,     -- 1/10000
        Color = Color3.fromRGB(170, 0, 255),   -- Tím ngân hà
        StatMultiplier = 12.0,
        PlayCutscene = true,
        Rank = 7,
    },
} :: { [string]: Types.RarityConfigData }

local ORDERED_TIERS: { Types.RarityTier } = {
    "Common" :: any,
    "Uncommon" :: any,
    "Rare" :: any,
    "Epic" :: any,
    "Legendary" :: any,
    "Mythic" :: any,
    "Secret" :: any,
}
RarityConfig.ORDERED_TIERS = ORDERED_TIERS

--------------------------------------------------------------------------------
-- HELPER METHODS
--------------------------------------------------------------------------------
function RarityConfig.Get(tier: Types.RarityTier | string): Types.RarityConfigData?
    return RarityConfig.TIERS[tier]
end

function RarityConfig.GetColor(tier: Types.RarityTier | string): Color3
    local cfg = RarityConfig.Get(tier)
    return if cfg then cfg.Color else Color3.fromRGB(255, 255, 255)
end

function RarityConfig.GetMultiplier(tier: Types.RarityTier | string): number
    local cfg = RarityConfig.Get(tier)
    return if cfg then cfg.StatMultiplier else 1.0
end

function RarityConfig.ShouldCutscene(tier: Types.RarityTier | string): boolean
    local cfg = RarityConfig.Get(tier)
    return if cfg then cfg.PlayCutscene else false
end

function RarityConfig.GetAllTiers(): { Types.RarityTier }
    return ORDERED_TIERS
end

return RarityConfig
