--!strict
--[[
    Types.luau
    Central type definition module for RNG + Dungeon Crawler game.
    Provides strict type checking across both Server and Client environments.
]]

local Types = {}

--------------------------------------------------------------------------------
-- RARITY TYPES
--------------------------------------------------------------------------------
export type RarityTier =
    | "Common"
    | "Uncommon"
    | "Rare"
    | "Epic"
    | "Legendary"
    | "Mythic"
    | "Secret"

export type RarityConfigData = {
    Tier: RarityTier,
    DisplayName: string,
    Weight: number,              -- Trọng số xác suất
    Color: Color3,               -- Màu chủ đạo
    StatMultiplier: number,      -- Hệ số nhân chỉ số trang bị
    PlayCutscene: boolean,       -- Bật true từ Legendary trở lên
    Rank: number,                -- Thứ tự xếp hạng (1=Common ... 7=Secret)
}

--------------------------------------------------------------------------------
-- ITEM & INVENTORY TYPES
--------------------------------------------------------------------------------
export type ItemSlot = "Weapon" | "Armor" | "Accessory"

export type ItemBaseStats = {
    MaxHP: number,
    Damage: number,
    CritChance: number, -- Tỉ lệ chí mạng (vd: 0.05 = 5%)
    LuckBonus: number,  -- Điểm may mắn cộng thêm (vd: 0.2 = +20%)
}

export type VisualConfig = {
    Color: Color3,
    Material: Enum.Material,
    Size: Vector3,
    MeshType: string,
    AttachmentPoint: string, -- e.g. "RightHand", "UpperTorso", "Head"
}

export type ItemDefinition = {
    Id: string,
    Name: string,
    Description: string,
    Slot: ItemSlot,
    Rarity: RarityTier,
    BaseStats: ItemBaseStats,
    Visual: VisualConfig,
    SellPrice: number,
}

export type InventoryItem = {
    UUID: string,
    ItemId: string,
    EnchantLevel: number,
    Quality: number,             -- Hệ số biến thiên (0.90 - 1.10)
    BonusStats: ItemBaseStats?,  -- Chỉ số phụ (nếu có)
    Trait: string?,              -- Tên Nội tại (Trait) ngẫu nhiên
    ObtainedTimestamp: number,
    Locked: boolean,
}

--------------------------------------------------------------------------------
-- TRAITS & BUFFS
--------------------------------------------------------------------------------
export type TraitDefinition = {
    Id: string,
    DisplayName: string,
    Color: Color3,
    Description: string,
    Weight: number,
    DamageMultiplier: number,
    HealthMultiplier: number,
    CritChanceBonus: number,
    LuckBonus: number,
}

export type ActiveBuffs = {
    LuckBoostEndTime: number,
    GoldBoostEndTime: number,
}

export type QuestType = "RollChest" | "KillMonsters" | "ClearDungeon"

export type QuestData = {
    Id: string,
    Type: QuestType,
    Title: string,
    Tier: number,
    Target: number,
    Current: number,
    Claimed: boolean,
    RewardGold: number,
    RewardXP: number,
    RewardGems: number?,
    RewardBuff: string?,
}

--------------------------------------------------------------------------------
-- PLAYER DATA & STATS
--------------------------------------------------------------------------------
export type PlayerEquipped = {
    Weapon: string?,     -- UUID của item trong Inventory
    Armor: string?,      -- UUID của item trong Inventory
    Accessory: string?,  -- UUID của item trong Inventory
}

export type TotalStats = {
    MaxHP: number,
    Damage: number,
    CritChance: number,
    LuckBonus: number,
}

export type PlayerStats = {
    MaxHealth: number,
    Damage: number,
    Defense: number,
    Speed: number,
    CritChance: number,
    CritDamage: number,
    AttackSpeed: number,
    Luck: number,
}

export type PlayerData = {
    UserId: number,
    Level: number,
    XP: number,
    NextLevelXP: number,
    Gold: number,
    Gems: number,        -- Viên ngọc ma thuật / đá quý tẩy luyện
    RollCount: number,
    PityCounter: number,
    BaseLuck: number,
    MultiRollCount: number,
    Rebirths: number,
    FastRollUnlocked: boolean,
    ActiveBuffs: ActiveBuffs,
    Quests: { [string]: QuestData },
    AutoDeleteRarities: { [string]: boolean },
    Inventory: { [string]: InventoryItem }, -- Tối đa 50 ô
    Equipped: PlayerEquipped,
}

--------------------------------------------------------------------------------
-- COMBAT TYPES
--------------------------------------------------------------------------------
export type AttackSkillType = "M1" | "Whirlwind" | "Meteor" | "Dash" | "Heal"

export type CombatFeedbackData = {
    Position: Vector3,
    Damage: number,
    IsCrit: boolean,
    SkillType: AttackSkillType,
    TargetName: string?,
}

--------------------------------------------------------------------------------
-- FRAMEWORK ARCHITECTURE TYPES
--------------------------------------------------------------------------------
export type Service = {
    Name: string,
    Priority: number?,
    Init: ((self: any) -> ())?,
    Start: ((self: any) -> ())?,
    [string]: any,
}

--------------------------------------------------------------------------------
-- MULTIPLAYER CUSTOM PARTY ROOM TYPES
--------------------------------------------------------------------------------
export type PartyMemberInfo = {
    UserId: number,
    DisplayName: string,
    Name: string,
    Level: number,
    CombatPower: number,
    IsHost: boolean,
}

export type PartyRoomClientState = {
    RoomId: number,
    HostUserId: number?,
    HostName: string?,
    SelectedFloor: string,
    FloorName: string,
    MaxPlayers: number,
    FriendsOnly: boolean,
    Members: { PartyMemberInfo },
    Countdown: number?,
    IsInRoom: boolean,
    IsHost: boolean,
}

export type PartyInviteInfo = {
    RoomId: number,
    HostName: string,
    FloorId: string,
    FloorName: string,
}

export type Controller = {
    Name: string,
    Priority: number?,
    Init: ((self: any) -> ())?,
    Start: ((self: any) -> ())?,
    [string]: any,
}

return Types
