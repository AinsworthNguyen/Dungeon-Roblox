--!strict
--[[
    CombatService.luau
    Authoritative server combat coordinator, hit detection, and damage calculations.
    
    Features:
    - M1 Combo tracking (3-step rhythm with 1.0x, 1.1x, 1.35x scaling).
    - Skill E (Whirlwind Slash): 360 AoE 14-stud radius, 1.8x Damage, 5.0s Cooldown.
    - Skill R (Meteor Strike): Ground blast 18-stud radius, 3.0x Damage, 10.0s Cooldown.
    - Spatial hit detection via Workspace:GetPartBoundsInBox() (no .Touched).
    - Integrated with DataService.GetTotalStats(player) for Damage & CritChance.
    - Broadcasts CombatFeedback for visual slashes, explosions, and floating DamagePopups.
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local CombatService = {
    Name = "CombatService",
    Priority = 6,
}

-- Per-player tracking tables
type ComboState = {
    Step: number,
    LastTimestamp: number,
}

type CooldownState = {
    Whirlwind: number,
    Meteor: number,
    Dash: number,
    Heal: number,
}

local playerCombos: { [number]: ComboState } = {}
local playerCooldowns: { [number]: CooldownState } = {}
local playerIFrames: { [number]: number } = {}

-- Lazy service accessors
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

local function getLobbyService(): any
    local Server = script.Parent.Parent
    local Services = Server:FindFirstChild("Services")
    if Services then
        local lbModule = Services:FindFirstChild("LobbyService")
        if lbModule then
            return (require :: any)(lbModule)
        end
    end
    return nil
end

--[[
    Finds unique damageable models within a specified bounding box.
]]
local function queryDamageableTargets(boxCFrame: CFrame, boxSize: Vector3, attackerChar: Model): { Model }
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Include

    local targetContainers: { Instance } = {}
    local dummiesFolder = Workspace:FindFirstChild("TrainingDummies")
    if dummiesFolder then
        table.insert(targetContainers, dummiesFolder)
    end

    local enemiesFolder = Workspace:FindFirstChild("Enemies")
    if enemiesFolder then
        table.insert(targetContainers, enemiesFolder)
    end

    -- Also query any tagged instances in Workspace
    for _, item in ipairs(CollectionService:GetTagged("Damageable")) do
        if item:IsA("Model") and item ~= attackerChar then
            table.insert(targetContainers, item)
        end
    end

    params.FilterDescendantsInstances = targetContainers

    local hitParts = Workspace:GetPartBoundsInBox(boxCFrame, boxSize, params)
    local uniqueModels: { [Model]: boolean } = {}
    local result: { Model } = {}

    for _, part in ipairs(hitParts) do
        local model = part:FindFirstAncestorOfClass("Model")
        if model and model ~= attackerChar and not uniqueModels[model] then
            uniqueModels[model] = true
            table.insert(result, model)
        end
    end

    return result
end

--[[
    Executes combat logic for a player action (M1, Whirlwind, Meteor).
]]
local function handleAttack(player: Player, actionType: any)
    local skillType = tostring(actionType or "M1") :: Types.AttackSkillType
    local character = player.Character
    if not character then return end

    local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not rootPart or not humanoid or humanoid.Health <= 0 then return end

    local userId = player.UserId
    local now = os.clock()

    -- 1. Initialize states if absent
    if not playerCombos[userId] then
        playerCombos[userId] = { Step = 0, LastTimestamp = 0 }
    end
    if not playerCooldowns[userId] then
        playerCooldowns[userId] = { Whirlwind = 0, Meteor = 0, Dash = 0, Heal = 0 }
    end

    local combo = playerCombos[userId]
    local cooldowns = playerCooldowns[userId]

    -- 2. Validate Cooldowns & Combo Steps
    local skillMultiplier = 1.0
    local hitboxCFrame = rootPart.CFrame
    local hitboxSize = Vector3.new(7, 6, 7)

    if skillType == "M1" then
        if now - combo.LastTimestamp < Constants.COMBAT.M1_COOLDOWN then
            return -- Too fast
        end

        if now - combo.LastTimestamp > Constants.COMBAT.M1_COMBO_RESET_TIME then
            combo.Step = 1
        else
            combo.Step = (combo.Step % 3) + 1
        end
        combo.LastTimestamp = now

        if combo.Step == 1 then
            skillMultiplier = 1.0
        elseif combo.Step == 2 then
            skillMultiplier = 1.1
        else
            skillMultiplier = 1.35
        end

        hitboxCFrame = rootPart.CFrame * CFrame.new(0, 0, -3.8)
        hitboxSize = Vector3.new(7, 6, 7.5)

    elseif skillType == "Whirlwind" then
        if now - cooldowns.Whirlwind < Constants.COMBAT.WHIRLWIND_COOLDOWN then
            return
        end
        cooldowns.Whirlwind = now
        skillMultiplier = Constants.COMBAT.WHIRLWIND_MULT

        hitboxCFrame = rootPart.CFrame
        hitboxSize = Vector3.new(Constants.COMBAT.WHIRLWIND_RADIUS * 2, 6, Constants.COMBAT.WHIRLWIND_RADIUS * 2)

    elseif skillType == "Meteor" then
        if now - cooldowns.Meteor < Constants.COMBAT.METEOR_COOLDOWN then
            return
        end
        cooldowns.Meteor = now
        skillMultiplier = Constants.COMBAT.METEOR_MULT

        hitboxCFrame = rootPart.CFrame * CFrame.new(0, 0, -8.0)
        hitboxSize = Vector3.new(Constants.COMBAT.METEOR_RADIUS * 2, 8, Constants.COMBAT.METEOR_RADIUS * 2)

    elseif skillType == "Dash" then
        if now - (cooldowns.Dash or 0) < Constants.COMBAT.DASH_COOLDOWN then
            return
        end
        cooldowns.Dash = now

        -- Server I-Frames (0.3s invulnerability)
        playerIFrames[userId] = now + Constants.COMBAT.DASH_IFRAME_DURATION
        character:SetAttribute("Invulnerable", true)
        task.delay(Constants.COMBAT.DASH_IFRAME_DURATION, function()
            if character.Parent and os.clock() >= (playerIFrames[userId] or 0) then
                character:SetAttribute("Invulnerable", nil)
            end
        end)
        return

    elseif skillType == "Heal" then
        if now - (cooldowns.Heal or 0) < Constants.COMBAT.HEAL_COOLDOWN then
            return
        end
        cooldowns.Heal = now

        -- Instantly heal 35% MaxHP
        local healAmount = math.round(humanoid.MaxHealth * Constants.COMBAT.HEAL_PERCENT)
        humanoid.Health = math.clamp(humanoid.Health + healAmount, 1, humanoid.MaxHealth)

        local feedbackRemote = Remotes.GetEvent(Constants.REMOTE_EVENTS.CombatFeedback)
        feedbackRemote:FireAllClients({
            Position = rootPart.Position,
            Damage = healAmount,
            IsCrit = false,
            SkillType = "Heal",
            TargetName = player.DisplayName,
        } :: Types.CombatFeedbackData)
        return
    else
        return
    end

    -- 3. Retrieve Player's Current Total Stats
    local ds = getDataService()
    local stats = if ds and typeof(ds.GetTotalStats) == "function" then ds.GetTotalStats(player) else { Damage = 10, CritChance = 0.05 }
    local baseDamage = stats.Damage or 10
    local critChance = stats.CritChance or 0.05

    -- 4. Query Overlapping Targets
    local targets = queryDamageableTargets(hitboxCFrame, hitboxSize, character)
    local feedbackRemote = Remotes.GetEvent(Constants.REMOTE_EVENTS.CombatFeedback)
    local lb = getLobbyService()

    for _, targetModel in ipairs(targets) do
        local rawRoot = targetModel.PrimaryPart or targetModel:FindFirstChild("Torso") or targetModel:FindFirstChild("HumanoidRootPart")
        local targetRoot = if rawRoot and rawRoot:IsA("BasePart") then rawRoot else nil
        local targetPos = if targetRoot then targetRoot.Position else hitboxCFrame.Position

        -- Roll Critical Strike
        local isCrit = math.random() <= critChance
        local critFactor = if isCrit then Constants.COMBAT.CRIT_MULT else 1.0
        local finalDamage = math.max(1, math.round(baseDamage * skillMultiplier * critFactor))

        -- Apply Damage to Target
        if targetModel:GetAttribute("IsDummy") or CollectionService:HasTag(targetModel, "TrainingDummy") then
            if lb and typeof(lb.DamageDummy) == "function" then
                lb.DamageDummy(targetModel, finalDamage)
            end
        else
            local targetHum = targetModel:FindFirstChildOfClass("Humanoid")
            if targetHum and targetHum.Health > 0 then
                targetHum:TakeDamage(finalDamage)
            end
        end

        -- Replicate Combat VFX & Damage Popup
        feedbackRemote:FireAllClients({
            Position = targetPos,
            Damage = finalDamage,
            IsCrit = isCrit,
            SkillType = skillType,
            TargetName = targetModel.Name,
        } :: Types.CombatFeedbackData)
    end
end

function CombatService:Init()
    print("[CombatService] Initializing authoritative combat network listener...")

    local attackEvent = Remotes.GetEvent(Constants.REMOTE_EVENTS.PerformAttack)
    attackEvent.OnServerEvent:Connect(function(player: Player, actionType: any)
        handleAttack(player, actionType)
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        playerCombos[player.UserId] = nil
        playerCooldowns[player.UserId] = nil
        playerIFrames[player.UserId] = nil
    end)
end

--[[
    Checks if a player is currently in I-Frames (during Dash dodge).
]]
function CombatService.IsPlayerInvulnerable(player: Player): boolean
    local untilTime = playerIFrames[player.UserId] or 0
    return os.clock() < untilTime
end

function CombatService:Start()
    print("[CombatService] Combat engine active. Ready for M1 combos, Whirlwind, and Meteor strikes.")
end

return CombatService
