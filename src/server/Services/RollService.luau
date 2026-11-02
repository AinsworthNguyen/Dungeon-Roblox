--!strict
--[[
    RollService.luau
    Authoritative RNG Chest Rolling, Pity System, and Inventory Actions.
    
    Features:
    - 0.7s cooldown throttle to prevent macro spam.
    - Weighted RNG rolling influenced by total player Luck.
    - Dual Pity system (Guaranteed Epic every 50 rolls, Legendary every 200 rolls).
    - Auto-sell filter integration (converts unwanted rarities into Gold).
    - Remote endpoints: RequestRoll, EquipBest, UpgradeItem, SellItem, UpdateAutoDelete.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RarityConfig = require(Shared:WaitForChild("RarityConfig"))
local ItemConfig = require(Shared:WaitForChild("ItemConfig"))
local TraitConfig = require(Shared:WaitForChild("TraitConfig"))

local RollService = {
    Name = "RollService",
    Priority = 10,
}

local COOLDOWN_SECONDS = 0.7
local lastRollTimestamps: { [number]: number } = {}

-- Lazy accessor for DataService
local function getDataService(): any
    local Server = script.Parent.Parent
    local Services = Server:FindFirstChild("Services")
    if Services then
        local dsModule = Services:FindFirstChild("DataService")
        if dsModule then
            return (require :: any)(dsModule)
        end
    end
    error("[RollService] Could not locate DataService module!")
end

-- Lazy accessor for QuestService
local function getQuestService(): any
    local Server = script.Parent.Parent
    local Services = Server:FindFirstChild("Services")
    if Services then
        local qsModule = Services:FindFirstChild("QuestService")
        if qsModule then
            return (require :: any)(qsModule)
        end
    end
    return nil
end

--[[
    Computes Combat Power (CP) score for prioritizing Best Equipment.
]]
local function calculateCombatPower(itemDef: Types.ItemDefinition, invItem: Types.InventoryItem): number
    local rarityMult = RarityConfig.GetMultiplier(itemDef.Rarity)
    local rawQ = invItem.Quality or 50
    if rawQ <= 1.5 then rawQ = math.round(rawQ * 50) end
    local qualityMultiplier = 0.5 + (rawQ / 100) * 1.0
    local enchantMult = 1.0 + (invItem.EnchantLevel * 0.1)
    local factor = rarityMult * qualityMultiplier * enchantMult

    local hpScore = (itemDef.BaseStats.MaxHP or 0) * 1.0
    local dmgScore = (itemDef.BaseStats.Damage or 0) * 3.5
    local critScore = (itemDef.BaseStats.CritChance or 0) * 600.0
    local luckScore = (itemDef.BaseStats.LuckBonus or 0) * 80.0

    return (hpScore + dmgScore + critScore + luckScore) * factor
end

--------------------------------------------------------------------------------
-- CORE ROLL ALGORITHM
--------------------------------------------------------------------------------

export type SingleRollResult = {
    Item: Types.ItemDefinition,
    UUID: string?,
    Quality: number?,
    Trait: string?,
    AutoSold: boolean,
    GoldEarned: number,
    PityTriggered: string?,
}

export type RollResponse = {
    Success: boolean,
    Item: Types.ItemDefinition?,
    UUID: string?,
    Quality: number?,
    Trait: string?,
    AutoSold: boolean?,
    GoldEarned: number?,
    PityTriggered: string?,
    Items: { SingleRollResult }?,
    MultiCount: number?,
    Error: string?,
}

--[[
    Executes a weighted RNG roll for the player with Luck, Pity, Multi-Roll, and Item Traits.
]]
function RollService.RollItem(player: Player, isExternalTrigger: boolean?): RollResponse
    local now = os.clock()
    local lastRoll = lastRollTimestamps[player.UserId] or 0

    local DataService = getDataService()
    local data = DataService.GetData(player)
    if not data then
        return { Success = false, Error = "Player data not loaded." }
    end

    local cd = if data.FastRollUnlocked then 0.25 else COOLDOWN_SECONDS
    if (now - lastRoll) < cd then
        return { Success = false, Error = "Rolling too quickly! Please wait." }
    end
    lastRollTimestamps[player.UserId] = now

    local multiCount = math.clamp(data.MultiRollCount or 1, 1, 3)
    local rolledList: { SingleRollResult } = {}
    local latestPity: string? = nil

    for _ = 1, multiCount do
        -- 1. Query Player Luck
        local totalStats = DataService.GetTotalStats(player)
        local luckMultiplier = math.max(1.0, totalStats.LuckBonus)

        -- 2. Increment Pity and Roll Counters
        data.RollCount += 1
        data.PityCounter += 1

        local pityTriggered: string? = nil
        local minimumRank = 1

        -- Pity Rules: 200 rolls = Legendary (Rank 5), 50 rolls = Epic (Rank 4)
        if data.PityCounter >= 200 then
            minimumRank = 5
            pityTriggered = "Legendary Pity (200 Rolls)!"
            data.PityCounter = 0
        elseif (data.RollCount % 50 == 0) then
            minimumRank = 4
            pityTriggered = "Epic Pity (50 Rolls)!"
        end
        if pityTriggered then
            latestPity = pityTriggered
        end

        -- 3. Calculate Weighted Rarity Selection
        local orderedTiers = RarityConfig.GetAllTiers()
        local adjustedWeights: { [string]: number } = {}
        local totalWeight = 0

        for _, tier in ipairs(orderedTiers) do
            local tierCfg = RarityConfig.Get(tier)
            if tierCfg then
                local rankFactor = math.max(0, tierCfg.Rank - 1)
                local weight = tierCfg.Weight * (1 + (luckMultiplier - 1) * 0.18 * rankFactor)
                adjustedWeights[tier] = weight
                totalWeight += weight
            end
        end

        local randomPick = math.random() * totalWeight
        local runningSum = 0
        local chosenTier: Types.RarityTier = "Common"

        for _, tier in ipairs(orderedTiers) do
            runningSum += (adjustedWeights[tier] or 0)
            if randomPick <= runningSum then
                chosenTier = (tier :: any) :: Types.RarityTier
                break
            end
        end

        -- Apply Pity Guarantee
        local chosenTierCfg = RarityConfig.Get(chosenTier)
        local chosenRank = if chosenTierCfg then chosenTierCfg.Rank else 1

        if chosenRank < minimumRank then
            if minimumRank == 5 then
                chosenTier = "Legendary"
            elseif minimumRank == 4 then
                chosenTier = "Epic"
            end
        end

        -- Reset 200 Pity if naturally hit Legendary+
        local finalCfg = RarityConfig.Get(chosenTier)
        local finalRank = if finalCfg then finalCfg.Rank else 1
        if finalRank >= 5 then
            data.PityCounter = 0
        end

        -- 4. Select random item from chosen rarity
        local candidateItems = ItemConfig.GetByRarity(chosenTier)
        if #candidateItems == 0 then
            chosenTier = "Common"
            candidateItems = ItemConfig.GetByRarity("Common")
        end
        local selectedItem = candidateItems[math.random(1, #candidateItems)]

        -- 30% chance for natural Trait
        local naturalTrait = TraitConfig.RollNaturalTrait()
        local rolledQuality = math.random(15, 100)

        -- 5. Handle Auto-Delete / Auto-Sell
        local shouldAutoSell = data.AutoDeleteRarities[chosenTier] == true
        local isGoldBoost = data.ActiveBuffs and os.time() < (data.ActiveBuffs.GoldBoostEndTime or 0)

        if shouldAutoSell then
            local sellValue = selectedItem.SellPrice or 10
            if isGoldBoost then
                sellValue *= 2
            end
            DataService.AddGold(player, sellValue)

            table.insert(rolledList, {
                Item = selectedItem,
                UUID = nil,
                Quality = rolledQuality,
                Trait = naturalTrait,
                AutoSold = true,
                GoldEarned = sellValue,
                PityTriggered = pityTriggered,
            })
        else
            -- Add to Inventory
            local addOk, uuidOrErr = DataService.AddItem(player, selectedItem, naturalTrait, rolledQuality)
            if not addOk then
                local sellValue = selectedItem.SellPrice or 10
                if isGoldBoost then
                    sellValue *= 2
                end
                DataService.AddGold(player, sellValue)

                table.insert(rolledList, {
                    Item = selectedItem,
                    UUID = nil,
                    Quality = rolledQuality,
                    Trait = naturalTrait,
                    AutoSold = true,
                    GoldEarned = sellValue,
                    PityTriggered = pityTriggered,
                })
            else
                table.insert(rolledList, {
                    Item = selectedItem,
                    UUID = uuidOrErr,
                    Quality = rolledQuality,
                    Trait = naturalTrait,
                    AutoSold = false,
                    GoldEarned = 0,
                    PityTriggered = pityTriggered,
                })
            end
        end
    end

    -- Progress Quests
    local questService = getQuestService()
    if questService and typeof(questService.OnChestRolled) == "function" then
        questService.OnChestRolled(player, multiCount)
    end

    local first = rolledList[1]
    local result: RollResponse = {
        Success = true,
        Item = first.Item,
        UUID = first.UUID,
        Quality = first.Quality,
        Trait = first.Trait,
        AutoSold = first.AutoSold,
        GoldEarned = first.GoldEarned,
        PityTriggered = latestPity,
        Items = rolledList,
        MultiCount = multiCount,
    }

    -- Only broadcast remote event if triggered externally (e.g. 3D Lobby Chest prompt or Dungeon bonus reward)
    -- Direct RemoteFunction invocations return the result table directly to InvokeServer callers.
    if isExternalTrigger == true then
        local rollResultEvent = Remotes.GetEvent(Constants.REMOTE_EVENTS.RollResultReceived)
        rollResultEvent:FireClient(player, result)
    end

    return result
end

--------------------------------------------------------------------------------
-- INVENTORY ACTIONS: EQUIP BEST, UPGRADE, SELL
--------------------------------------------------------------------------------

--[[
    Auto-detects and equips the single highest CP item for each slot.
]]
function RollService.EquipBest(player: Player): { Success: boolean, Equipped: Types.PlayerEquipped? }
    local DataService = getDataService()
    local data = DataService.GetData(player)
    if not data then return { Success = false } end

    local bestBySlot: { [Types.ItemSlot]: { UUID: string, CP: number }? } = {
        Weapon = nil,
        Armor = nil,
        Accessory = nil,
    }

    for uuid, invItem in pairs(data.Inventory) do
        local itemDef = ItemConfig.Get(invItem.ItemId)
        if itemDef then
            local cp = calculateCombatPower(itemDef, invItem)
            local currentBest = bestBySlot[itemDef.Slot]
            if not currentBest or cp > currentBest.CP then
                bestBySlot[itemDef.Slot] = { UUID = uuid, CP = cp }
            end
        end
    end

    for slot, bestEntry in pairs(bestBySlot) do
        if bestEntry then
            DataService.EquipItem(player, bestEntry.UUID)
        end
    end

    return { Success = true, Equipped = data.Equipped }
end

--[[
    Upgrades an item's EnchantLevel (+10% stat boost per level) using Gold.
]]
function RollService.UpgradeItem(player: Player, uuid: string): { Success: boolean, NewLevel: number?, Error: string? }
    local DataService = getDataService()
    local data = DataService.GetData(player)
    if not data then return { Success = false, Error = "No data" } end

    local invItem = data.Inventory[uuid]
    if not invItem then return { Success = false, Error = "Item not found in inventory" } end

    local cost = math.round(120 * (1.7 ^ invItem.EnchantLevel))
    if data.Gold < cost then
        return { Success = false, Error = string.format("Need %d Gold to upgrade!", cost) }
    end

    DataService.AddGold(player, -cost)
    invItem.EnchantLevel += 1
    DataService.ApplyStatsToCharacter(player)

    -- Force client sync
    local updateEvent = Remotes.GetEvent(Constants.REMOTE_EVENTS.PlayerDataUpdated)
    updateEvent:FireClient(player, data)

    return { Success = true, NewLevel = invItem.EnchantLevel }
end

--[[
    Sells an item from inventory to earn Gold.
]]
function RollService.SellItem(player: Player, uuid: string): { Success: boolean, GoldEarned: number }
    local DataService = getDataService()
    local data = DataService.GetData(player)
    if not data then return { Success = false, GoldEarned = 0 } end

    local invItem = data.Inventory[uuid]
    if not invItem then return { Success = false, GoldEarned = 0 } end

    local itemDef = ItemConfig.Get(invItem.ItemId)
    local basePrice = if itemDef then itemDef.SellPrice else 10
    local enchantBonus = 1.0 + (invItem.EnchantLevel * 0.25)
    local finalSellGold = math.round(basePrice * enchantBonus)

    -- Wealth Potion 2x Gold buff
    if data.ActiveBuffs and os.time() < (data.ActiveBuffs.GoldBoostEndTime or 0) then
        finalSellGold *= 2
    end

    DataService.RemoveItem(player, uuid)
    DataService.AddGold(player, finalSellGold)

    return { Success = true, GoldEarned = finalSellGold }
end

--------------------------------------------------------------------------------
-- SERVICE LIFECYCLE & REMOTE BINDINGS
--------------------------------------------------------------------------------

function RollService:Init()
    print("[RollService] Binding RNG and Inventory Remote endpoints...")

    local rollFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestRoll)
    rollFn.OnServerInvoke = function(player: Player)
        return RollService.RollItem(player)
    end

    local equipFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestEquipItem)
    equipFn.OnServerInvoke = function(player: Player, uuid: string)
        local DataService = getDataService()
        return DataService.EquipItem(player, uuid)
    end

    local unequipFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestUnequipItem)
    unequipFn.OnServerInvoke = function(player: Player, slot: Types.ItemSlot)
        local DataService = getDataService()
        return DataService.UnequipItem(player, slot)
    end

    local equipBestFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestEquipBest)
    equipBestFn.OnServerInvoke = function(player: Player)
        return RollService.EquipBest(player)
    end

    local upgradeFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestUpgradeItem)
    upgradeFn.OnServerInvoke = function(player: Player, uuid: string)
        return RollService.UpgradeItem(player, uuid)
    end

    local sellFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestSellItem)
    sellFn.OnServerInvoke = function(player: Player, uuid: string)
        return RollService.SellItem(player, uuid)
    end

    local autoDeleteFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestUpdateAutoDelete)
    autoDeleteFn.OnServerInvoke = function(player: Player, newSettings: { [string]: boolean })
        local DataService = getDataService()
        local data = DataService.GetData(player)
        if data and type(newSettings) == "table" then
            data.AutoDeleteRarities = newSettings
            return true
        end
        return false
    end
end

function RollService:Start()
    print("[RollService] Roll engine and inventory actions ready.")
end

return RollService
