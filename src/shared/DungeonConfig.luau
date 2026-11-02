--!strict
--[[
    DungeonConfig.luau
    Defines the 3 Dungeon difficulty tiers, wave compositions, rewards, and enemy stats.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))

export type EnemySpawnConfig = {
    Name: string,
    MaxHP: number,
    Damage: number,
    MoveSpeed: number,
    Scale: number,
    BodyColor: Color3,
    IsBoss: boolean?,
}

export type DungeonWaveConfig = {
    WaveNumber: number,
    Enemies: { EnemySpawnConfig },
}

export type DungeonDifficulty = {
    Id: string,
    Name: string,
    FloorNumber: number,
    Description: string,
    RecommendedCP: number,
    ThemeColor: Color3,
    Rewards: {
        Gold: number,
        XP: number,
        Gems: number,
        BonusRollText: string,
        GuaranteedRarity: Types.RarityTier?,
    },
    Waves: { DungeonWaveConfig },
}

local DungeonConfig = {}

local DUNGEONS: { [string]: DungeonDifficulty } = {
    goblin_crypt = {
        Id = "goblin_crypt",
        Name = "Goblin Crypt",
        FloorNumber = 1,
        Description = "An abandoned ancient crypt overrun by ravenous green skins.",
        RecommendedCP = 30,
        ThemeColor = Color3.fromRGB(75, 215, 110),
        Rewards = {
            Gold = 250,
            XP = 120,
            Gems = 2,
            BonusRollText = "+1 Free Lucky Roll (Uncommon+)",
            GuaranteedRarity = "Uncommon",
        },
        Waves = {
            {
                WaveNumber = 1,
                Enemies = {
                    { Name = "Goblin Scavenger", MaxHP = 120, Damage = 6, MoveSpeed = 13, Scale = 0.9, BodyColor = Color3.fromRGB(70, 130, 60) },
                    { Name = "Goblin Scavenger", MaxHP = 120, Damage = 6, MoveSpeed = 13, Scale = 0.9, BodyColor = Color3.fromRGB(70, 130, 60) },
                    { Name = "Goblin Scavenger", MaxHP = 120, Damage = 6, MoveSpeed = 13, Scale = 0.9, BodyColor = Color3.fromRGB(70, 130, 60) },
                },
            },
            {
                WaveNumber = 2,
                Enemies = {
                    { Name = "Goblin Berserker", MaxHP = 200, Damage = 10, MoveSpeed = 15, Scale = 1.1, BodyColor = Color3.fromRGB(90, 140, 50) },
                    { Name = "Goblin Berserker", MaxHP = 200, Damage = 10, MoveSpeed = 15, Scale = 1.1, BodyColor = Color3.fromRGB(90, 140, 50) },
                    { Name = "Goblin Berserker", MaxHP = 200, Damage = 10, MoveSpeed = 15, Scale = 1.1, BodyColor = Color3.fromRGB(90, 140, 50) },
                    { Name = "Goblin Shaman",    MaxHP = 180, Damage = 12, MoveSpeed = 12, Scale = 1.0, BodyColor = Color3.fromRGB(60, 110, 140) },
                },
            },
            {
                WaveNumber = 3,
                Enemies = {
                    { Name = "Goblin Warlord", MaxHP = 950, Damage = 22, MoveSpeed = 12, Scale = 1.7, BodyColor = Color3.fromRGB(130, 40, 40), IsBoss = true },
                    { Name = "Goblin Elite Guard", MaxHP = 180, Damage = 8, MoveSpeed = 13, Scale = 1.0, BodyColor = Color3.fromRGB(80, 110, 60) },
                    { Name = "Goblin Elite Guard", MaxHP = 180, Damage = 8, MoveSpeed = 13, Scale = 1.0, BodyColor = Color3.fromRGB(80, 110, 60) },
                },
            },
        },
    },

    cursed_citadel = {
        Id = "cursed_citadel",
        Name = "Cursed Citadel",
        FloorNumber = 2,
        Description = "A ruined obsidian fortress haunted by damned specters and shadow knights.",
        RecommendedCP = 350,
        ThemeColor = Color3.fromRGB(175, 75, 255),
        Rewards = {
            Gold = 1200,
            XP = 450,
            Gems = 5,
            BonusRollText = "+1 Guaranteed Epic+ Roll",
            GuaranteedRarity = "Epic",
        },
        Waves = {
            {
                WaveNumber = 1,
                Enemies = {
                    { Name = "Cursed Knight", MaxHP = 650, Damage = 28, MoveSpeed = 14, Scale = 1.0, BodyColor = Color3.fromRGB(55, 60, 80) },
                    { Name = "Cursed Knight", MaxHP = 650, Damage = 28, MoveSpeed = 14, Scale = 1.0, BodyColor = Color3.fromRGB(55, 60, 80) },
                    { Name = "Cursed Knight", MaxHP = 650, Damage = 28, MoveSpeed = 14, Scale = 1.0, BodyColor = Color3.fromRGB(55, 60, 80) },
                },
            },
            {
                WaveNumber = 2,
                Enemies = {
                    { Name = "Shadow Assassin", MaxHP = 950, Damage = 38, MoveSpeed = 17, Scale = 1.05, BodyColor = Color3.fromRGB(40, 30, 60) },
                    { Name = "Shadow Assassin", MaxHP = 950, Damage = 38, MoveSpeed = 17, Scale = 1.05, BodyColor = Color3.fromRGB(40, 30, 60) },
                    { Name = "Shadow Assassin", MaxHP = 950, Damage = 38, MoveSpeed = 17, Scale = 1.05, BodyColor = Color3.fromRGB(40, 30, 60) },
                    { Name = "Void Sorcerer",   MaxHP = 820, Damage = 45, MoveSpeed = 13, Scale = 1.0,  BodyColor = Color3.fromRGB(80, 20, 120) },
                },
            },
            {
                WaveNumber = 3,
                Enemies = {
                    { Name = "Abyssal Dreadknight", MaxHP = 3800, Damage = 65, MoveSpeed = 13, Scale = 1.9, BodyColor = Color3.fromRGB(90, 20, 130), IsBoss = true },
                    { Name = "Void Reaper", MaxHP = 800, Damage = 30, MoveSpeed = 14, Scale = 1.1, BodyColor = Color3.fromRGB(50, 25, 75) },
                    { Name = "Void Reaper", MaxHP = 800, Damage = 30, MoveSpeed = 14, Scale = 1.1, BodyColor = Color3.fromRGB(50, 25, 75) },
                },
            },
        },
    },

    abyssal_sanctum = {
        Id = "abyssal_sanctum",
        Name = "Abyssal Sanctum",
        FloorNumber = 3,
        Description = "The deepest underworld abyss guarded by ancient demon lords.",
        RecommendedCP = 2000,
        ThemeColor = Color3.fromRGB(255, 60, 90),
        Rewards = {
            Gold = 6000,
            XP = 1800,
            Gems = 12,
            BonusRollText = "+1 Guaranteed Legendary+ Roll",
            GuaranteedRarity = "Legendary",
        },
        Waves = {
            {
                WaveNumber = 1,
                Enemies = {
                    { Name = "Nether Fiend", MaxHP = 2800, Damage = 110, MoveSpeed = 15, Scale = 1.1, BodyColor = Color3.fromRGB(120, 30, 30) },
                    { Name = "Nether Fiend", MaxHP = 2800, Damage = 110, MoveSpeed = 15, Scale = 1.1, BodyColor = Color3.fromRGB(120, 30, 30) },
                    { Name = "Nether Fiend", MaxHP = 2800, Damage = 110, MoveSpeed = 15, Scale = 1.1, BodyColor = Color3.fromRGB(120, 30, 30) },
                },
            },
            {
                WaveNumber = 2,
                Enemies = {
                    { Name = "Chaos Behemoth", MaxHP = 4200, Damage = 160, MoveSpeed = 16, Scale = 1.3, BodyColor = Color3.fromRGB(140, 40, 25) },
                    { Name = "Chaos Behemoth", MaxHP = 4200, Damage = 160, MoveSpeed = 16, Scale = 1.3, BodyColor = Color3.fromRGB(140, 40, 25) },
                    { Name = "Chaos Behemoth", MaxHP = 4200, Damage = 160, MoveSpeed = 16, Scale = 1.3, BodyColor = Color3.fromRGB(140, 40, 25) },
                    { Name = "Hellfire Archon", MaxHP = 3800, Damage = 180, MoveSpeed = 14, Scale = 1.2, BodyColor = Color3.fromRGB(160, 50, 10) },
                },
            },
            {
                WaveNumber = 3,
                Enemies = {
                    { Name = "Archdemon of the Void", MaxHP = 16000, Damage = 280, MoveSpeed = 14, Scale = 2.2, BodyColor = Color3.fromRGB(180, 20, 40), IsBoss = true },
                    { Name = "Infernal Lieutenant", MaxHP = 3500, Damage = 130, MoveSpeed = 15, Scale = 1.2, BodyColor = Color3.fromRGB(110, 25, 25) },
                    { Name = "Infernal Lieutenant", MaxHP = 3500, Damage = 130, MoveSpeed = 15, Scale = 1.2, BodyColor = Color3.fromRGB(110, 25, 25) },
                },
            },
        },
    },
}

local ORDERED_IDS = { "goblin_crypt", "cursed_citadel", "abyssal_sanctum" }

function DungeonConfig.Get(id: string): DungeonDifficulty?
    return DUNGEONS[id]
end

function DungeonConfig.GetAll(): { DungeonDifficulty }
    local list: { DungeonDifficulty } = {}
    for _, id in ipairs(ORDERED_IDS) do
        local d = DUNGEONS[id]
        if d then
            table.insert(list, d)
        end
    end
    return list
end

return DungeonConfig
