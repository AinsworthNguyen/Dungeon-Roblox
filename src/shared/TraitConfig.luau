--!strict
--[[
    TraitConfig.luau
    Defines Item Traits (Nội tại Trang bị) with weights, stat multipliers, and reroll mechanics.
]]

local Types = require(script.Parent.Types)

local TraitConfig = {}

TraitConfig.NATURAL_ROLL_CHANCE = 0.30 -- 30% chance to drop with a trait
TraitConfig.REROLL_COST = 200          -- 200 Gold to reroll a trait

local TRAITS: { [string]: Types.TraitDefinition } = {
    Swift = {
        Id = "Swift",
        DisplayName = "Swift",
        Color = Color3.fromRGB(220, 225, 235), -- Pure Silver White
        Description = "+10% Damage",
        Weight = 40,
        DamageMultiplier = 1.10,
        HealthMultiplier = 1.0,
        CritChanceBonus = 0.0,
        LuckBonus = 0.0,
    },
    Fortified = {
        Id = "Fortified",
        DisplayName = "Fortified",
        Color = Color3.fromRGB(80, 220, 110), -- Forest Emerald Green
        Description = "+20% Max HP",
        Weight = 25,
        DamageMultiplier = 1.0,
        HealthMultiplier = 1.20,
        CritChanceBonus = 0.0,
        LuckBonus = 0.0,
    },
    Lucky = {
        Id = "Lucky",
        DisplayName = "Lucky",
        Color = Color3.fromRGB(50, 160, 255), -- Azure Blue
        Description = "+0.5 Luck Bonus",
        Weight = 15,
        DamageMultiplier = 1.0,
        HealthMultiplier = 1.0,
        CritChanceBonus = 0.0,
        LuckBonus = 0.5,
    },
    Ruthless = {
        Id = "Ruthless",
        DisplayName = "Ruthless",
        Color = Color3.fromRGB(180, 70, 255), -- Amethyst Purple
        Description = "+15% Crit & +20% Damage",
        Weight = 12,
        DamageMultiplier = 1.20,
        HealthMultiplier = 1.0,
        CritChanceBonus = 0.15,
        LuckBonus = 0.0,
    },
    Warlord = {
        Id = "Warlord",
        DisplayName = "Warlord",
        Color = Color3.fromRGB(255, 145, 30), -- Radiant Sun Orange
        Description = "+45% Damage & +30% Max HP",
        Weight = 6,
        DamageMultiplier = 1.45,
        HealthMultiplier = 1.30,
        CritChanceBonus = 0.0,
        LuckBonus = 0.0,
    },
    Celestial = {
        Id = "Celestial",
        DisplayName = "Celestial",
        Color = Color3.fromRGB(255, 45, 120), -- Crimson / Divine Magenta
        Description = "+80% DMG, +50% HP, +1.5 Luck",
        Weight = 2,
        DamageMultiplier = 1.80,
        HealthMultiplier = 1.50,
        CritChanceBonus = 0.10,
        LuckBonus = 1.5,
    },
}
TraitConfig.TRAITS = TRAITS

-- Ordered list for deterministic weighted picking
local ORDERED_TRAIT_IDS = { "Swift", "Fortified", "Lucky", "Ruthless", "Warlord", "Celestial" }
local TOTAL_WEIGHT = 0
for _, id in ipairs(ORDERED_TRAIT_IDS) do
    local def = TraitConfig.TRAITS[id]
    if def then
        TOTAL_WEIGHT += def.Weight
    end
end

--[[
    Returns TraitDefinition by Id.
]]
function TraitConfig.Get(id: string?): Types.TraitDefinition?
    if not id then return nil end
    return TraitConfig.TRAITS[id]
end

--[[
    Selects a random trait using predefined probability weights.
]]
function TraitConfig.GetRandomTrait(): Types.TraitDefinition
    local rand = math.random() * TOTAL_WEIGHT
    local running = 0
    for _, id in ipairs(ORDERED_TRAIT_IDS) do
        local def = TraitConfig.TRAITS[id]
        if def then
            running += def.Weight
            if rand <= running then
                return def
            end
        end
    end
    return TraitConfig.TRAITS["Swift"]
end

--[[
    Rolls a natural trait when an item is generated (30% base chance).
]]
function TraitConfig.RollNaturalTrait(): string?
    if math.random() <= TraitConfig.NATURAL_ROLL_CHANCE then
        return TraitConfig.GetRandomTrait().Id
    end
    return nil
end

return TraitConfig
