--!strict
--[[
    DataService.luau
    Authoritative Player Data, Session Cache, Inventory, and Equipment Manager.
    
    Features:
    - In-Memory session caching with fallback for Studio (prevents API Access crashes).
    - Automatic DataStore saving on exit and periodic autosave.
    - Full inventory management (max 50 slots) with UUID assignment.
    - Equipment management (Weapon, Armor, Accessory) and dynamic stat recalculation.
    - Realtime Humanoid.MaxHealth & Health synchronization.
    - Automated Remote push notification (PlayerDataUpdated) on state change.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RarityConfig = require(Shared:WaitForChild("RarityConfig"))
local ItemConfig = require(Shared:WaitForChild("ItemConfig"))
local TraitConfig = require(Shared:WaitForChild("TraitConfig"))

local DataService = {
    Name = "DataService",
    Priority = 5, -- Runs right after LobbyService
}

local DATASTORE_KEY_PREFIX = "Player_"
local DATASTORE_NAME = "DungeonPlayerData_v1"
local MAX_INVENTORY_SLOTS = 50

-- DataStore readiness detection
local dataStore = nil
local isDataStoreActive = false

do
    local ok, ds = pcall(function()
        return DataStoreService:GetDataStore(DATASTORE_NAME)
    end)
    if ok and ds then
        -- Verify API access is truly open (handles Studio disabled API access gracefully)
        local testOk = pcall(function()
            ds:GetAsync("__connectivity_test__")
        end)
        if testOk then
            dataStore = ds
            isDataStoreActive = true
            print("[DataService] DataStore connection verified and active.")
        else
            warn("[DataService] Studio API access is disabled. Running safely in MOCK / IN-MEMORY mode.")
        end
    else
        warn("[DataService] DataStoreService is unavailable. Running in MOCK mode.")
    end
end

-- In-memory session cache: UserId -> PlayerData
local sessionCache: { [number]: Types.PlayerData } = {}

--[[
    Creates a fresh, default player profile.
]]
local function createDefaultData(userId: number): Types.PlayerData
    return {
        UserId = userId,
        Level = 1,
        XP = 0,
        NextLevelXP = 100,
        Gold = 100,
        Gems = 5,
        RollCount = 0,
        PityCounter = 0,
        BaseLuck = 1.0,
        MultiRollCount = 1,
        Rebirths = 0,
        FastRollUnlocked = false,
        ActiveBuffs = {
            LuckBoostEndTime = 0,
            GoldBoostEndTime = 0,
        },
        Quests = {
            RollChest = {
                Id = "RollChest",
                Type = "RollChest",
                Title = "Open 5 Chests",
                Tier = 1,
                Target = 5,
                Current = 0,
                Claimed = false,
                RewardGold = 150,
                RewardXP = 50,
                RewardGems = 2,
                RewardBuff = nil,
            },
            KillMonsters = {
                Id = "KillMonsters",
                Type = "KillMonsters",
                Title = "Defeat 10 Monsters",
                Tier = 1,
                Target = 10,
                Current = 0,
                Claimed = false,
                RewardGold = 250,
                RewardXP = 100,
                RewardGems = 3,
                RewardBuff = "LuckPotion",
            },
            ClearDungeon = {
                Id = "ClearDungeon",
                Type = "ClearDungeon",
                Title = "Conquer 2 Dungeons",
                Tier = 1,
                Target = 2,
                Current = 0,
                Claimed = false,
                RewardGold = 500,
                RewardXP = 200,
                RewardGems = 5,
                RewardBuff = nil,
            },
        },
        AutoDeleteRarities = {},
        Inventory = {},
        Equipped = {
            Weapon = nil,
            Armor = nil,
            Accessory = nil,
        },
    }
end

--[[
    Pushes full updated player data to the client.
]]
local function syncToClient(player: Player, data: Types.PlayerData)
    local updateEvent = Remotes.GetEvent(Constants.REMOTE_EVENTS.PlayerDataUpdated)
    updateEvent:FireClient(player, data)
end

function DataService.SyncData(player: Player)
    local data = sessionCache[player.UserId]
    if data then
        syncToClient(player, data)
    end
end

--------------------------------------------------------------------------------
-- STATS & CHARACTER SYNCHRONIZATION
--------------------------------------------------------------------------------

--[[
    Computes total aggregate stats from base values and all equipped gear.
]]
function DataService.GetTotalStats(player: Player): Types.TotalStats
    local data = sessionCache[player.UserId]
    if not data then
        return {
            MaxHP = 100,
            Damage = 10,
            CritChance = 0.05,
            LuckBonus = 1.0,
        }
    end

    local totalHP = 100
    local totalDamage = 10
    local totalCrit = 0.05
    local totalLuck = data.BaseLuck or 1.0

    for _, slotName in ipairs({ "Weapon", "Armor", "Accessory" } :: { Types.ItemSlot }) do
        local uuid = data.Equipped[slotName]
        if uuid then
            local invItem = data.Inventory[uuid]
            if invItem then
                local itemDef = ItemConfig.Get(invItem.ItemId)
                if itemDef then
                    local rarityMult = RarityConfig.GetMultiplier(itemDef.Rarity)
                    local rawQ = invItem.Quality or 50
                    if rawQ <= 1.5 then rawQ = math.round(rawQ * 50) end
                    local qualityMultiplier = 0.5 + (rawQ / 100) * 1.0
                    local enchantMult = 1.0 + (invItem.EnchantLevel * 0.1)
                    local factor = rarityMult * qualityMultiplier * enchantMult

                    local itemDmg = math.round(itemDef.BaseStats.Damage * factor)
                    local itemHP = math.round(itemDef.BaseStats.MaxHP * factor)
                    local itemCrit = (itemDef.BaseStats.CritChance * rarityMult * qualityMultiplier)
                    local itemLuck = (itemDef.BaseStats.LuckBonus * rarityMult * qualityMultiplier)

                    -- Apply Item Trait
                    if invItem.Trait then
                        local traitDef = TraitConfig.Get(invItem.Trait)
                        if traitDef then
                            itemDmg = math.round(itemDmg * traitDef.DamageMultiplier)
                            itemHP = math.round(itemHP * traitDef.HealthMultiplier)
                            itemCrit += traitDef.CritChanceBonus
                            itemLuck += traitDef.LuckBonus
                        end
                    end

                    totalHP += itemHP
                    totalDamage += itemDmg
                    totalCrit += itemCrit
                    totalLuck += itemLuck
                end
            end
        end
    end

    -- Apply Rebirth Multipliers (+35% DMG, +35% MaxHP, +1.5 Base Luck per Rebirth)
    local rebirths = data.Rebirths or 0
    if rebirths > 0 then
        local rebirthMult = 1.0 + (rebirths * 0.35)
        totalHP = math.round(totalHP * rebirthMult)
        totalDamage = math.round(totalDamage * rebirthMult)
        totalLuck += (rebirths * 1.5)
    end

    -- Apply active Luck Potion (2x Luck)
    if data.ActiveBuffs and os.time() < (data.ActiveBuffs.LuckBoostEndTime or 0) then
        totalLuck *= 2.0
    end

    return {
        MaxHP = math.max(1, totalHP),
        Damage = math.max(1, totalDamage),
        CritChance = math.clamp(totalCrit, 0, 1.0),
        LuckBonus = math.max(0.1, totalLuck),
    }
end

--[[
    Synchronizes character Humanoid.MaxHealth and Health to match computed stats.
]]
function DataService.ApplyStatsToCharacter(player: Player)
    local character = player.Character
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local stats = DataService.GetTotalStats(player)
    local currentRatio = humanoid.Health / math.max(1, humanoid.MaxHealth)

    humanoid.MaxHealth = stats.MaxHP
    humanoid.Health = math.clamp(math.round(stats.MaxHP * currentRatio), 1, stats.MaxHP)
end

--------------------------------------------------------------------------------
-- INVENTORY & CURRENCY MANAGEMENT
--------------------------------------------------------------------------------

function DataService.GetData(player: Player): Types.PlayerData?
    return sessionCache[player.UserId]
end

function DataService.AddGold(player: Player, amount: number): boolean
    local data = sessionCache[player.UserId]
    if not data then return false end

    if data.Gold + amount < 0 then
        return false -- Not enough gold
    end

    data.Gold += amount
    syncToClient(player, data)
    return true
end

function DataService.AddGems(player: Player, amount: number): boolean
    local data = sessionCache[player.UserId]
    if not data then return false end

    data.Gems = math.max(0, (data.Gems or 0) + amount)
    syncToClient(player, data)
    return true
end

function DataService.DeductGems(player: Player, amount: number): boolean
    local data = sessionCache[player.UserId]
    if not data then return false end

    local current = data.Gems or 0
    if current < amount then
        return false
    end

    data.Gems = current - amount
    syncToClient(player, data)
    return true
end

--[[
    Adds XP and handles automatic level progression.
]]
function DataService.AddXP(player: Player, amount: number): boolean
    local data = sessionCache[player.UserId]
    if not data then return false end

    data.XP += amount
    while data.XP >= data.NextLevelXP do
        data.XP -= data.NextLevelXP
        data.Level += 1
        data.NextLevelXP = math.round(data.NextLevelXP * 1.35)
        DataService.ApplyStatsToCharacter(player)
    end

    syncToClient(player, data)
    return true
end

--[[
    Adds an item to player's inventory if space permits (max 50).
    Returns (success, uuid_or_error_message).
]]
function DataService.AddItem(player: Player, itemDef: Types.ItemDefinition, trait: string?): (boolean, string?)
    local data = sessionCache[player.UserId]
    if not data then
        return false, "Player data not loaded"
    end

    -- Check slot limit
    local count = 0
    for _ in pairs(data.Inventory) do
        count += 1
    end

    if count >= MAX_INVENTORY_SLOTS then
        return false, "Inventory is full (Max 50 items)!"
    end

    local uuid = HttpService:GenerateGUID(false)
    local rawQ = quality or math.random(15, 100)
    if rawQ <= 1.5 then rawQ = math.round(rawQ * 50) end
    local finalQuality = math.clamp(rawQ, 15, 100)

    local newInvItem: Types.InventoryItem = {
        UUID = uuid,
        ItemId = itemDef.Id,
        EnchantLevel = 0,
        Quality = finalQuality,
        BonusStats = nil,
        Trait = trait,
        ObtainedTimestamp = os.time(),
        Locked = false,
    }

    data.Inventory[uuid] = newInvItem
    syncToClient(player, data)
    return true, uuid
end

--[[
    Rerolls the Quality (15% - 100%) on an item using Gold (150 Gold).
]]
function DataService.RerollQuality(player: Player, uuid: string): { Success: boolean, NewQuality: number?, Error: string? }
    local data = sessionCache[player.UserId]
    if not data then return { Success = false, Error = "No data" } end

    local invItem = data.Inventory[uuid]
    if not invItem then return { Success = false, Error = "Item not found in inventory" } end

    local cost = 150
    if data.Gold < cost then
        return { Success = false, Error = string.format("Need %d Gold to reroll Quality!", cost) }
    end

    -- Deduct gold
    DataService.AddGold(player, -cost)

    -- Roll new quality integer (15 - 100)
    local newQuality = math.random(15, 100)
    invItem.Quality = newQuality

    DataService.ApplyStatsToCharacter(player)
    syncToClient(player, data)

    return { Success = true, NewQuality = newQuality }
end

--[[
    Rerolls the Trait on an item using 1 Mystic Gem.
]]
function DataService.RerollTrait(player: Player, uuid: string): { Success: boolean, Trait: string?, Error: string? }
    local data = sessionCache[player.UserId]
    if not data then return { Success = false, Error = "No data" } end

    local invItem = data.Inventory[uuid]
    if not invItem then return { Success = false, Error = "Item not found in inventory" } end

    if (data.Gems or 0) < 1 then
        return { Success = false, Error = "Need 1 Mystic Gem (💎) to reroll Trait!" }
    end

    -- Deduct 1 Gem
    DataService.DeductGems(player, 1)

    -- Pick a new trait
    local newTrait = TraitConfig.GetRandomTrait()
    invItem.Trait = newTrait.Id

    DataService.ApplyStatsToCharacter(player)
    syncToClient(player, data)

    return { Success = true, Trait = newTrait.Id }
end

--[[
    Forces client sync with latest PlayerData.
]]
function DataService.SyncData(player: Player)
    local data = sessionCache[player.UserId]
    if data then
        syncToClient(player, data)
    end
end

local function notifyVisualUpdate(player: Player)
    task.spawn(function()
        local Server = script.Parent.Parent
        local Services = Server:FindFirstChild("Services")
        if Services then
            local visualModule = Services:FindFirstChild("EquipmentVisualService")
            if visualModule then
                local vs = require(visualModule :: ModuleScript) :: any
                if vs and typeof(vs.UpdateVisuals) == "function" then
                    vs.UpdateVisuals(player)
                end
            end
        end
    end)
end

--[[
    Removes an item from inventory. Automatically unequips if worn.
]]
function DataService.RemoveItem(player: Player, uuid: string): boolean
    local data = sessionCache[player.UserId]
    if not data or not data.Inventory[uuid] then
        return false
    end

    -- Auto-unequip if equipped
    for slot, equippedUUID in pairs(data.Equipped) do
        if equippedUUID == uuid then
            data.Equipped[slot] = nil
        end
    end

    data.Inventory[uuid] = nil
    DataService.ApplyStatsToCharacter(player)
    notifyVisualUpdate(player)
    syncToClient(player, data)
    return true
end

--[[
    Equips an item by its UUID.
]]
function DataService.EquipItem(player: Player, uuid: string): boolean
    local data = sessionCache[player.UserId]
    if not data then return false end

    local invItem = data.Inventory[uuid]
    if not invItem then return false end

    local itemDef = ItemConfig.Get(invItem.ItemId)
    if not itemDef then return false end

    data.Equipped[itemDef.Slot] = uuid
    DataService.ApplyStatsToCharacter(player)
    notifyVisualUpdate(player)
    syncToClient(player, data)
    return true
end

--[[
    Unequips whatever is in the given slot.
]]
function DataService.UnequipItem(player: Player, slot: Types.ItemSlot): boolean
    local data = sessionCache[player.UserId]
    if not data then return false end

    if data.Equipped[slot] == nil then
        return false
    end

    data.Equipped[slot] = nil
    DataService.ApplyStatsToCharacter(player)
    notifyVisualUpdate(player)
    syncToClient(player, data)
    return true
end

--------------------------------------------------------------------------------
-- PERSISTENCE: LOAD & SAVE
--------------------------------------------------------------------------------

local function loadData(player: Player): Types.PlayerData
    if isDataStoreActive and dataStore then
        local key = DATASTORE_KEY_PREFIX .. tostring(player.UserId)
        local ok, saved = pcall(function()
            return dataStore:GetAsync(key)
        end)

        if ok and saved and type(saved) == "table" then
            -- Reconcile any missing keys from new updates
            local default = createDefaultData(player.UserId)
            for k, v in pairs(default) do
                if saved[k] == nil then
                    saved[k] = v
                end
            end
            if saved.MultiRollCount == nil then
                saved.MultiRollCount = 1
            end
            if saved.Rebirths == nil then
                saved.Rebirths = 0
            end
            if saved.FastRollUnlocked == nil then
                saved.FastRollUnlocked = false
            end
            if saved.Gems == nil then
                saved.Gems = 5
            end
            if saved.ActiveBuffs == nil then
                saved.ActiveBuffs = { LuckBoostEndTime = 0, GoldBoostEndTime = 0 }
            end
            if saved.Quests == nil then
                saved.Quests = default.Quests
            end
            print(string.format("[DataService] Loaded saved DataStore for %s (Level %d, Gold %d)", player.Name, saved.Level, saved.Gold))
            return saved
        elseif not ok then
            warn(string.format("[DataService] Error loading DataStore for %s: %s", player.Name, tostring(saved)))
        end
    end

    print(string.format("[DataService] Using clean default session data for %s", player.Name))
    return createDefaultData(player.UserId)
end

local function saveData(player: Player)
    local data = sessionCache[player.UserId]
    if not data or not isDataStoreActive or not dataStore then
        return
    end

    local key = DATASTORE_KEY_PREFIX .. tostring(player.UserId)
    local ok, err = pcall(function()
        dataStore:SetAsync(key, data)
    end)

    if ok then
        print(string.format("[DataService] Saved DataStore for %s successfully.", player.Name))
    else
        warn(string.format("[DataService] Failed to save DataStore for %s: %s", player.Name, tostring(err)))
    end
end

--------------------------------------------------------------------------------
-- SERVICE LIFECYCLE
--------------------------------------------------------------------------------

function DataService:Init()
    print("[DataService] Initializing player lifecycle & network endpoints...")

    -- Bind RequestPlayerData RemoteFunction
    local requestDataFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestPlayerData)
    requestDataFn.OnServerInvoke = function(player: Player)
        return sessionCache[player.UserId] or loadData(player)
    end

    -- Bind RequestRerollQuality RemoteFunction
    local rerollQualityFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestRerollQuality)
    rerollQualityFn.OnServerInvoke = function(player: Player, uuid: string)
        return DataService.RerollQuality(player, uuid)
    end

    -- Bind RequestRerollTrait RemoteFunction
    local rerollTraitFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestRerollTrait)
    rerollTraitFn.OnServerInvoke = function(player: Player, uuid: string)
        return DataService.RerollTrait(player, uuid)
    end

    -- Setup Player connections
    Players.PlayerAdded:Connect(function(player: Player)
        self:OnPlayerAdded(player)
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        self:OnPlayerRemoving(player)
    end)

    -- Auto-save on server shutdown
    game:BindToClose(function()
        for _, player in ipairs(Players:GetPlayers()) do
            saveData(player)
        end
    end)
end

function DataService:Start()
    print("[DataService] Processing existing players in session...")
    for _, player in ipairs(Players:GetPlayers()) do
        self:OnPlayerAdded(player)
    end
end

function DataService:OnPlayerAdded(player: Player)
    if sessionCache[player.UserId] then
        return
    end

    local profile = loadData(player)
    sessionCache[player.UserId] = profile

    -- Connect CharacterAdded to re-apply stats when spawning
    player.CharacterAdded:Connect(function()
        task.wait(0.1) -- Allow character parts to assemble
        DataService.ApplyStatsToCharacter(player)
    end)

    if player.Character then
        task.spawn(function()
            DataService.ApplyStatsToCharacter(player)
        end)
    end

    -- Notify client that data is loaded
    local loadedEvent = Remotes.GetEvent(Constants.REMOTE_EVENTS.PlayerDataLoaded)
    loadedEvent:FireClient(player, profile)
end

function DataService:OnPlayerRemoving(player: Player)
    saveData(player)
    sessionCache[player.UserId] = nil
    print(string.format("[DataService] Player %s removed from session.", player.Name))
end

return DataService
