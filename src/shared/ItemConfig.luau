--!strict
--[[
    ItemConfig.luau
    Defines the catalogue of Weapons, Armors, and Accessories
    with base stats, visual 3D attributes, and slot categories.
]]

local Types = require(script.Parent.Types)

local ItemConfig = {}

local ITEMS_LIST: { Types.ItemDefinition } = {
    ----------------------------------------------------------------------------
    -- WEAPONS (RightHand)
    ----------------------------------------------------------------------------
    {
        Id = "wpn_rusty_sword",
        Name = "Rusty Shortsword",
        Description = "An old, chipped blade salvaged from the catacombs.",
        Slot = "Weapon",
        Rarity = "Common",
        BaseStats = { MaxHP = 0, Damage = 6, CritChance = 0.02, LuckBonus = 0 },
        Visual = {
            Color = Color3.fromRGB(150, 140, 130),
            Material = Enum.Material.Slate,
            Size = Vector3.new(0.6, 2.8, 0.2),
            MeshType = "Block",
            AttachmentPoint = "RightHand",
        },
        SellPrice = 10,
    },
    {
        Id = "wpn_iron_broadsword",
        Name = "Iron Broadsword",
        Description = "Sturdy steel forged by town blacksmiths.",
        Slot = "Weapon",
        Rarity = "Uncommon",
        BaseStats = { MaxHP = 0, Damage = 15, CritChance = 0.04, LuckBonus = 0 },
        Visual = {
            Color = Color3.fromRGB(190, 200, 210),
            Material = Enum.Material.Metal,
            Size = Vector3.new(0.8, 3.4, 0.2),
            MeshType = "Block",
            AttachmentPoint = "RightHand",
        },
        SellPrice = 35,
    },
    {
        Id = "wpn_frost_dagger",
        Name = "Frostbite Dagger",
        Description = "Radiates sub-zero chill that numbs wounded targets.",
        Slot = "Weapon",
        Rarity = "Rare",
        BaseStats = { MaxHP = 0, Damage = 32, CritChance = 0.08, LuckBonus = 0.05 },
        Visual = {
            Color = Color3.fromRGB(80, 180, 255),
            Material = Enum.Material.Glass,
            Size = Vector3.new(0.4, 2.2, 0.2),
            MeshType = "Block",
            AttachmentPoint = "RightHand",
        },
        SellPrice = 120,
    },
    {
        Id = "wpn_shadow_scythe",
        Name = "Shadow Reaper Scythe",
        Description = "Imbued with twilight essence to sever life force.",
        Slot = "Weapon",
        Rarity = "Epic",
        BaseStats = { MaxHP = 0, Damage = 70, CritChance = 0.15, LuckBonus = 0.1 },
        Visual = {
            Color = Color3.fromRGB(160, 50, 240),
            Material = Enum.Material.Neon,
            Size = Vector3.new(1.2, 4.2, 0.3),
            MeshType = "Block",
            AttachmentPoint = "RightHand",
        },
        SellPrice = 450,
    },
    {
        Id = "wpn_sunforged_blade",
        Name = "Sunforged Claymore",
        Description = "Forged inside solar core flares; burns with radiant fury.",
        Slot = "Weapon",
        Rarity = "Legendary",
        BaseStats = { MaxHP = 50, Damage = 150, CritChance = 0.25, LuckBonus = 0.25 },
        Visual = {
            Color = Color3.fromRGB(255, 185, 30),
            Material = Enum.Material.Neon,
            Size = Vector3.new(1.0, 4.6, 0.35),
            MeshType = "Block",
            AttachmentPoint = "RightHand",
        },
        SellPrice = 2000,
    },
    {
        Id = "wpn_crimson_demonslayer",
        Name = "Crimson Demon Slayer",
        Description = "Cursed blade bathed in the blood of fallen archdemons.",
        Slot = "Weapon",
        Rarity = "Mythic",
        BaseStats = { MaxHP = 120, Damage = 340, CritChance = 0.35, LuckBonus = 0.5 },
        Visual = {
            Color = Color3.fromRGB(255, 30, 70),
            Material = Enum.Material.Neon,
            Size = Vector3.new(1.1, 5.0, 0.4),
            MeshType = "Block",
            AttachmentPoint = "RightHand",
        },
        SellPrice = 8500,
    },
    {
        Id = "wpn_void_cosmic_katana",
        Name = "Singularity Void Katana",
        Description = "Bends fabric of space-time with every slash. A mythic cosmic relic.",
        Slot = "Weapon",
        Rarity = "Secret",
        BaseStats = { MaxHP = 300, Damage = 850, CritChance = 0.50, LuckBonus = 1.0 },
        Visual = {
            Color = Color3.fromRGB(180, 0, 255),
            Material = Enum.Material.ForceField,
            Size = Vector3.new(0.5, 4.8, 0.2),
            MeshType = "Block",
            AttachmentPoint = "RightHand",
        },
        SellPrice = 50000,
    },

    ----------------------------------------------------------------------------
    -- ARMORS (UpperTorso)
    ----------------------------------------------------------------------------
    {
        Id = "arm_torn_tunic",
        Name = "Torn Linen Tunic",
        Description = "Simple cloth providing basic warmth and minimum protection.",
        Slot = "Armor",
        Rarity = "Common",
        BaseStats = { MaxHP = 20, Damage = 0, CritChance = 0, LuckBonus = 0 },
        Visual = {
            Color = Color3.fromRGB(160, 150, 135),
            Material = Enum.Material.Fabric,
            Size = Vector3.new(2.1, 2.1, 1.1),
            MeshType = "Block",
            AttachmentPoint = "UpperTorso",
        },
        SellPrice = 10,
    },
    {
        Id = "arm_leather_vest",
        Name = "Reinforced Leather Vest",
        Description = "Tough beast hide stitched with copper rivets.",
        Slot = "Armor",
        Rarity = "Uncommon",
        BaseStats = { MaxHP = 50, Damage = 2, CritChance = 0.01, LuckBonus = 0 },
        Visual = {
            Color = Color3.fromRGB(110, 75, 45),
            Material = Enum.Material.Leather,
            Size = Vector3.new(2.15, 2.15, 1.15),
            MeshType = "Block",
            AttachmentPoint = "UpperTorso",
        },
        SellPrice = 35,
    },
    {
        Id = "arm_knight_plate",
        Name = "Silver Knight Cuirass",
        Description = "Polished plate armor favored by royal dungeon knights.",
        Slot = "Armor",
        Rarity = "Rare",
        BaseStats = { MaxHP = 120, Damage = 6, CritChance = 0.02, LuckBonus = 0.02 },
        Visual = {
            Color = Color3.fromRGB(210, 220, 235),
            Material = Enum.Material.Metal,
            Size = Vector3.new(2.2, 2.2, 1.2),
            MeshType = "Block",
            AttachmentPoint = "UpperTorso",
        },
        SellPrice = 120,
    },
    {
        Id = "arm_abyssal_carapace",
        Name = "Abyssal Carapace",
        Description = "Formed from chitin hardened in deep subterranean trenches.",
        Slot = "Armor",
        Rarity = "Epic",
        BaseStats = { MaxHP = 280, Damage = 18, CritChance = 0.05, LuckBonus = 0.08 },
        Visual = {
            Color = Color3.fromRGB(130, 40, 210),
            Material = Enum.Material.Slate,
            Size = Vector3.new(2.25, 2.25, 1.25),
            MeshType = "Block",
            AttachmentPoint = "UpperTorso",
        },
        SellPrice = 450,
    },
    {
        Id = "arm_dragonscale_aegis",
        Name = "Dragonscale Aegis",
        Description = "Impenetrable crimson scales from an elder dragon.",
        Slot = "Armor",
        Rarity = "Legendary",
        BaseStats = { MaxHP = 650, Damage = 45, CritChance = 0.10, LuckBonus = 0.20 },
        Visual = {
            Color = Color3.fromRGB(240, 140, 20),
            Material = Enum.Material.Neon,
            Size = Vector3.new(2.3, 2.3, 1.3),
            MeshType = "Block",
            AttachmentPoint = "UpperTorso",
        },
        SellPrice = 2000,
    },
    {
        Id = "arm_celestial_valkyrie",
        Name = "Valkyrie Divine Mail",
        Description = "Blessed by the heavens to bestow indomitable fortitude.",
        Slot = "Armor",
        Rarity = "Mythic",
        BaseStats = { MaxHP = 1500, Damage = 100, CritChance = 0.18, LuckBonus = 0.40 },
        Visual = {
            Color = Color3.fromRGB(255, 60, 100),
            Material = Enum.Material.Neon,
            Size = Vector3.new(2.35, 2.35, 1.35),
            MeshType = "Block",
            AttachmentPoint = "UpperTorso",
        },
        SellPrice = 8500,
    },
    {
        Id = "arm_astral_monolith",
        Name = "Astral Monolith Shroud",
        Description = "Woven from dark energy; absorbs incoming damage into the ether.",
        Slot = "Armor",
        Rarity = "Secret",
        BaseStats = { MaxHP = 3500, Damage = 250, CritChance = 0.30, LuckBonus = 1.0 },
        Visual = {
            Color = Color3.fromRGB(160, 20, 255),
            Material = Enum.Material.ForceField,
            Size = Vector3.new(2.4, 2.4, 1.4),
            MeshType = "Block",
            AttachmentPoint = "UpperTorso",
        },
        SellPrice = 50000,
    },

    ----------------------------------------------------------------------------
    -- ACCESSORIES (Head)
    ----------------------------------------------------------------------------
    {
        Id = "acc_copper_ring",
        Name = "Copper Ring",
        Description = "A simple trinket that slightly sharpens senses.",
        Slot = "Accessory",
        Rarity = "Common",
        BaseStats = { MaxHP = 10, Damage = 2, CritChance = 0.01, LuckBonus = 0.05 },
        Visual = {
            Color = Color3.fromRGB(180, 120, 70),
            Material = Enum.Material.Metal,
            Size = Vector3.new(1.1, 0.4, 1.1),
            MeshType = "Cylinder",
            AttachmentPoint = "Head",
        },
        SellPrice = 10,
    },
    {
        Id = "acc_emerald_amulet",
        Name = "Emerald Talisman",
        Description = "Carved jade stone radiating soothing vital essence.",
        Slot = "Accessory",
        Rarity = "Uncommon",
        BaseStats = { MaxHP = 25, Damage = 5, CritChance = 0.02, LuckBonus = 0.12 },
        Visual = {
            Color = Color3.fromRGB(50, 220, 110),
            Material = Enum.Material.Glass,
            Size = Vector3.new(1.15, 0.45, 1.15),
            MeshType = "Cylinder",
            AttachmentPoint = "Head",
        },
        SellPrice = 35,
    },
    {
        Id = "acc_sapphire_band",
        Name = "Sapphire Pendant",
        Description = "Gleams with mana residue, elevating combat intuition.",
        Slot = "Accessory",
        Rarity = "Rare",
        BaseStats = { MaxHP = 60, Damage = 12, CritChance = 0.05, LuckBonus = 0.25 },
        Visual = {
            Color = Color3.fromRGB(60, 160, 255),
            Material = Enum.Material.Neon,
            Size = Vector3.new(1.2, 0.5, 1.2),
            MeshType = "Cylinder",
            AttachmentPoint = "Head",
        },
        SellPrice = 120,
    },
    {
        Id = "acc_void_eye",
        Name = "Eye of the Void",
        Description = "A peering gem that uncovers unseen fortune.",
        Slot = "Accessory",
        Rarity = "Epic",
        BaseStats = { MaxHP = 140, Damage = 30, CritChance = 0.10, LuckBonus = 0.50 },
        Visual = {
            Color = Color3.fromRGB(175, 50, 255),
            Material = Enum.Material.Neon,
            Size = Vector3.new(1.25, 0.55, 1.25),
            MeshType = "Cylinder",
            AttachmentPoint = "Head",
        },
        SellPrice = 450,
    },
    {
        Id = "acc_phoenix_feather",
        Name = "Phoenix Feather Charm",
        Description = "Warm feather pulsating with everlasting regenerative flame.",
        Slot = "Accessory",
        Rarity = "Legendary",
        BaseStats = { MaxHP = 320, Damage = 70, CritChance = 0.18, LuckBonus = 1.0 },
        Visual = {
            Color = Color3.fromRGB(255, 175, 20),
            Material = Enum.Material.Neon,
            Size = Vector3.new(1.3, 0.6, 1.3),
            MeshType = "Cylinder",
            AttachmentPoint = "Head",
        },
        SellPrice = 2000,
    },
    {
        Id = "acc_bloodstone_crown",
        Name = "Bloodstone Diadem",
        Description = "Crown worn by conquerors; drains luck from enemies.",
        Slot = "Accessory",
        Rarity = "Mythic",
        BaseStats = { MaxHP = 750, Damage = 160, CritChance = 0.28, LuckBonus = 2.0 },
        Visual = {
            Color = Color3.fromRGB(255, 35, 80),
            Material = Enum.Material.Neon,
            Size = Vector3.new(1.35, 0.65, 1.35),
            MeshType = "Cylinder",
            AttachmentPoint = "Head",
        },
        SellPrice = 8500,
    },
    {
        Id = "acc_celestial_orb",
        Name = "Orb of Omniscience",
        Description = "Contains concentrated cosmic starlight. Reality bends to your favor.",
        Slot = "Accessory",
        Rarity = "Secret",
        BaseStats = { MaxHP = 1800, Damage = 400, CritChance = 0.40, LuckBonus = 5.0 },
        Visual = {
            Color = Color3.fromRGB(190, 40, 255),
            Material = Enum.Material.ForceField,
            Size = Vector3.new(1.4, 0.7, 1.4),
            MeshType = "Cylinder",
            AttachmentPoint = "Head",
        },
        SellPrice = 50000,
    },
}

-- Fast lookup maps
local itemsById: { [string]: Types.ItemDefinition } = {}
local itemsBySlot: { [Types.ItemSlot]: { Types.ItemDefinition } } = {
    Weapon = {},
    Armor = {},
    Accessory = {},
}
local itemsByRarity: { [Types.RarityTier]: { Types.ItemDefinition } } = {}

for _, item in ipairs(ITEMS_LIST) do
    itemsById[item.Id] = item

    if not itemsBySlot[item.Slot] then
        itemsBySlot[item.Slot] = {}
    end
    table.insert(itemsBySlot[item.Slot], item)

    if not itemsByRarity[item.Rarity] then
        itemsByRarity[item.Rarity] = {}
    end
    table.insert(itemsByRarity[item.Rarity], item)
end

--------------------------------------------------------------------------------
-- PUBLIC LOOKUP APIS
--------------------------------------------------------------------------------
function ItemConfig.Get(id: string): Types.ItemDefinition?
    return itemsById[id]
end

function ItemConfig.GetBySlot(slot: Types.ItemSlot): { Types.ItemDefinition }
    return itemsBySlot[slot] or {}
end

function ItemConfig.GetByRarity(rarity: Types.RarityTier): { Types.ItemDefinition }
    return itemsByRarity[rarity] or {}
end

function ItemConfig.GetAll(): { Types.ItemDefinition }
    return ITEMS_LIST
end

return ItemConfig
