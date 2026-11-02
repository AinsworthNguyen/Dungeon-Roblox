--!strict
--[[
    ShopService.luau
    Authoritative Potion & Multi-Roll Upgrade Shop.
    
    Items:
    1. Luck Potion (500 Gold): 2x Luck for 5 minutes (stacks duration).
    2. Wealth Potion (500 Gold): 2x Gold for 5 minutes (stacks duration).
    3. Multi-Roll Upgrade:
       - Tier 1 -> Tier 2: 2,500 Gold
       - Tier 2 -> Tier 3: 10,000 Gold
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local _Types = require(Shared:WaitForChild("Types"))
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ShopService = {
    Name = "ShopService",
    Priority = 8,
}

local LUCK_POTION_COST = 500
local WEALTH_POTION_COST = 500
local POTION_DURATION_SECONDS = 300 -- 5 minutes

local MULTI_ROLL_COSTS = {
    [1] = 2500,  -- Upgrade from 1x to 2x
    [2] = 10000, -- Upgrade from 2x to 3x
}

-- Lazy DataService accessor
local function getDataService(): any
    local Server = script.Parent.Parent
    local Services = Server:FindFirstChild("Services")
    if Services then
        local dsModule = Services:FindFirstChild("DataService")
        if dsModule then
            return (require :: any)(dsModule)
        end
    end
    return nil
end

--[[
    Handles player purchasing an item from the Shop.
]]
function ShopService.BuyItem(player: Player, itemType: string): { Success: boolean, Error: string?, NewValue: any? }
    local DataService = getDataService()
    if not DataService then return { Success = false, Error = "DataService unavailable" } end

    local data = DataService.GetData(player)
    if not data then return { Success = false, Error = "Player data not loaded" } end

    if itemType == "LuckPotion" then
        if data.Gold < LUCK_POTION_COST then
            return { Success = false, Error = string.format("Need %d Gold for Luck Potion!", LUCK_POTION_COST) }
        end

        DataService.AddGold(player, -LUCK_POTION_COST)
        local now = os.time()
        local currentEnd = data.ActiveBuffs.LuckBoostEndTime or 0
        local base = math.max(now, currentEnd)
        data.ActiveBuffs.LuckBoostEndTime = base + POTION_DURATION_SECONDS

        DataService.SyncData(player)
        return { Success = true, NewValue = data.ActiveBuffs.LuckBoostEndTime }

    elseif itemType == "WealthPotion" then
        if data.Gold < WEALTH_POTION_COST then
            return { Success = false, Error = string.format("Need %d Gold for Wealth Potion!", WEALTH_POTION_COST) }
        end

        DataService.AddGold(player, -WEALTH_POTION_COST)
        local now = os.time()
        local currentEnd = data.ActiveBuffs.GoldBoostEndTime or 0
        local base = math.max(now, currentEnd)
        data.ActiveBuffs.GoldBoostEndTime = base + POTION_DURATION_SECONDS

        DataService.SyncData(player)
        return { Success = true, NewValue = data.ActiveBuffs.GoldBoostEndTime }

    elseif itemType == "MultiRollUpgrade" then
        local currentLevel = data.MultiRollCount or 1
        if currentLevel >= 3 then
            return { Success = false, Error = "Multi-Roll is already at MAX level (3x)!" }
        end

        local cost = MULTI_ROLL_COSTS[currentLevel]
        if not cost or data.Gold < cost then
            return { Success = false, Error = string.format("Need %d Gold to upgrade Multi-Roll to %dx!", cost or 0, currentLevel + 1) }
        end

        DataService.AddGold(player, -cost)
        data.MultiRollCount = currentLevel + 1

        DataService.SyncData(player)
        return { Success = true, NewValue = data.MultiRollCount }

    elseif itemType == "FastRollPass" then
        if data.FastRollUnlocked then
            return { Success = false, Error = "Fast Roll Pass is already unlocked!" }
        end

        local FAST_ROLL_COST = 15000
        if data.Gold < FAST_ROLL_COST then
            return { Success = false, Error = string.format("Need %d Gold to unlock Fast Roll Pass!", FAST_ROLL_COST) }
        end

        DataService.AddGold(player, -FAST_ROLL_COST)
        data.FastRollUnlocked = true

        DataService.SyncData(player)
        return { Success = true, NewValue = true }

    elseif itemType == "GemPouch" then
        local GEM_POUCH_COST = 1000
        if data.Gold < GEM_POUCH_COST then
            return { Success = false, Error = string.format("Need %d Gold for Pouch of Gems!", GEM_POUCH_COST) }
        end

        DataService.AddGold(player, -GEM_POUCH_COST)
        DataService.AddGems(player, 3)
        return { Success = true, NewValue = data.Gems }

    else
        return { Success = false, Error = "Unknown shop item!" }
    end
end

function ShopService:Init()
    print("[ShopService] Registering shop Remote endpoint...")
    local buyFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestBuyShopItem)
    buyFn.OnServerInvoke = function(player: Player, itemType: string)
        return ShopService.BuyItem(player, itemType)
    end
end

function ShopService:Start()
    print("[ShopService] Potion Shop & Multi-Roll Upgrade Service active.")
end

return ShopService
