--!strict
--[[
    QuestService.luau
    Authoritative Rolling Quest System (Nhiệm vụ Tự động Lũy tiến).
    
    Quests:
    1. RollChest: Open X Chests (Rewards Gold & XP).
    2. KillMonsters: Defeat X Dungeon Monsters (Rewards Gold, XP, and Luck Potion).
    3. ClearDungeon: Conquer X Dungeons (Rewards Large Gold & XP).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local QuestService = {
    Name = "QuestService",
    Priority = 7,
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
    Generates a scaled quest for the next tier.
]]
local function generateNextTierQuest(questType: Types.QuestType, tier: number): Types.QuestData
    if questType == "RollChest" then
        local target = if tier == 1 then 5 elseif tier == 2 then 15 else (tier * 15)
        return {
            Id = "RollChest",
            Type = "RollChest",
            Title = string.format("Open %d Chests", target),
            Tier = tier,
            Target = target,
            Current = 0,
            Claimed = false,
            RewardGold = 150 * tier,
            RewardXP = 50 * tier,
            RewardBuff = nil,
        }
    elseif questType == "KillMonsters" then
        local target = if tier == 1 then 10 elseif tier == 2 then 25 else (tier * 25)
        return {
            Id = "KillMonsters",
            Type = "KillMonsters",
            Title = string.format("Defeat %d Dungeon Monsters", target),
            Tier = tier,
            Target = target,
            Current = 0,
            Claimed = false,
            RewardGold = 250 * tier,
            RewardXP = 100 * tier,
            RewardBuff = "LuckPotion",
        }
    else -- ClearDungeon
        local target = if tier == 1 then 2 elseif tier == 2 then 5 else (tier * 4)
        return {
            Id = "ClearDungeon",
            Type = "ClearDungeon",
            Title = string.format("Conquer %d Dungeons", target),
            Tier = tier,
            Target = target,
            Current = 0,
            Claimed = false,
            RewardGold = 500 * tier,
            RewardXP = 200 * tier,
            RewardBuff = nil,
        }
    end
end

--[[
    Updates progress on a specific quest type.
]]
local function addQuestProgress(player: Player, questType: Types.QuestType, amount: number)
    local DataService = getDataService()
    if not DataService then return end

    local data = DataService.GetData(player)
    if not data or not data.Quests then return end

    local quest = data.Quests[questType]
    if not quest or quest.Claimed then return end

    if quest.Current < quest.Target then
        quest.Current = math.min(quest.Target, quest.Current + amount)
        DataService.SyncData(player)
    end
end

--[[
    Hook: Called whenever a player opens chests (supports multi-roll count).
]]
function QuestService.OnChestRolled(player: Player, rollCount: number)
    addQuestProgress(player, "RollChest", rollCount or 1)
end

--[[
    Hook: Called whenever a player defeats a dungeon enemy.
]]
function QuestService.OnMonsterKilled(player: Player)
    addQuestProgress(player, "KillMonsters", 1)
end

--[[
    Hook: Called whenever a player successfully clears a dungeon floor.
]]
function QuestService.OnDungeonCleared(player: Player)
    addQuestProgress(player, "ClearDungeon", 1)
end

--[[
    Claims the reward for a completed quest and spawns the next tier.
]]
function QuestService.ClaimReward(player: Player, questId: string): { Success: boolean, Error: string?, NewQuest: Types.QuestData? }
    local DataService = getDataService()
    if not DataService then return { Success = false, Error = "DataService unavailable" } end

    local data = DataService.GetData(player)
    if not data or not data.Quests then return { Success = false, Error = "No player data" } end

    local quest = data.Quests[questId]
    if not quest then
        return { Success = false, Error = "Quest not found" }
    end

    if quest.Current < quest.Target then
        return { Success = false, Error = "Quest objectives not yet completed!" }
    end

    if quest.Claimed then
        return { Success = false, Error = "Reward already claimed!" }
    end

    -- 1. Award Gold, XP & Gems
    DataService.AddGold(player, quest.RewardGold)
    DataService.AddXP(player, quest.RewardXP)
    local gemReward = quest.RewardGems or (if quest.Type == "ClearDungeon" then 5 elseif quest.Type == "KillMonsters" then 3 else 2)
    DataService.AddGems(player, gemReward)

    -- 2. Award Buff if configured
    if quest.RewardBuff == "LuckPotion" and data.ActiveBuffs then
        local now = os.time()
        local currentEnd = data.ActiveBuffs.LuckBoostEndTime or 0
        local base = math.max(now, currentEnd)
        data.ActiveBuffs.LuckBoostEndTime = base + 300 -- 5 min Luck Potion
    end

    -- 3. Progress to Next Tier
    local nextTier = (quest.Tier or 1) + 1
    local newQuest = generateNextTierQuest(quest.Type, nextTier)
    data.Quests[questId] = newQuest

    DataService.SyncData(player)
    return { Success = true, NewQuest = newQuest }
end

function QuestService:Init()
    print("[QuestService] Binding Quest network endpoints...")
    local claimFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestClaimQuestReward)
    claimFn.OnServerInvoke = function(player: Player, questId: string)
        return QuestService.ClaimReward(player, questId)
    end
end

function QuestService:Start()
    print("[QuestService] Rolling Quest Engine active.")
end

return QuestService
