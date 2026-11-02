--!strict
--[[
    RebirthService.luau
    Authoritative Player Rebirth & Ascension Engine.
    
    Formula:
    - Required Level: 5 + (Rebirths * 5)
    - Required Gold: 5,000 * (Rebirths + 1)
    
    Perks (Stacking Permanently):
    - +35% Total Damage per Rebirth
    - +35% Total MaxHP per Rebirth
    - +1.5 Base Luck per Rebirth
    
    On Rebirth:
    - Resets Level to 1, XP to 0, subtracts Gold.
    - KEEPS all items, equipped gear, enchants, traits, multi-roll tiers, fast roll pass.
    - Triggers glorious Golden Light Pillar VFX and LevelUp/Victory SFX.
]]

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local _Types = require(Shared:WaitForChild("Types"))
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SoundManager = require(Shared:WaitForChild("SoundManager"))

local RebirthService = {
    Name = "RebirthService",
    Priority = 6,
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
    Calculates requirements for the next rebirth.
]]
function RebirthService.GetRequirements(rebirths: number): (number, number)
    local reqLevel = 5 + (rebirths * 5)
    local reqGold = 5000 * (rebirths + 1)
    return reqLevel, reqGold
end

--[[
    Spawns glorious golden light beam VFX from the sky onto character.
]]
local function playRebirthVFX(character: Model)
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then return end

    local charPos = root.Position

    -- 1. Golden Light Beam Cylinder
    local beam = Instance.new("Part")
    beam.Name = "RebirthPillar"
    beam.Shape = Enum.PartType.Cylinder
    beam.Size = Vector3.new(120, 8, 8) -- In Roblox cylinder, X is length/height
    beam.CFrame = CFrame.new(charPos.X, charPos.Y + 45, charPos.Z) * CFrame.Angles(0, 0, math.rad(90))
    beam.Anchored = true
    beam.CanCollide = false
    beam.Material = Enum.Material.Neon
    beam.Color = Color3.fromRGB(240, 190, 50)
    beam.Transparency = 0.55
    beam.Parent = Workspace

    -- 2. Ascending Sparkles Emitter (Soft light emission, no PointLight)
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "AscensionSparkles"
    emitter.Rate = 60
    emitter.Lifetime = NumberRange.new(1.5, 2.5)
    emitter.Speed = NumberRange.new(8, 16)
    emitter.SpreadAngle = Vector2.new(30, 30)
    emitter.Acceleration = Vector3.new(0, 10, 0)
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.4),
        NumberSequenceKeypoint.new(0.5, 1.2),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 200)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 215, 60)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 140, 20)),
    })
    emitter.Parent = beam

    -- Play 3D Sound
    SoundManager.PlayAtPosition("LevelUp", charPos, 1.5)

    -- Animate fading out after 2 seconds
    task.delay(1.5, function()
        emitter.Enabled = false
        local fadeTween = TweenService:Create(beam, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Transparency = 1,
            Size = Vector3.new(120, 1, 1),
        })
        fadeTween:Play()
        fadeTween.Completed:Connect(function()
            beam:Destroy()
        end)
    end)
end

--[[
    Executes authoritatively the rebirth for the player.
]]
function RebirthService.PerformRebirth(player: Player): { Success: boolean, Error: string?, NewRebirths: number? }
    local DataService = getDataService()
    if not DataService then
        return { Success = false, Error = "DataService unavailable" }
    end

    local data = DataService.GetData(player)
    if not data then
        return { Success = false, Error = "Player data not loaded" }
    end

    local currentRebirths = data.Rebirths or 0
    local reqLevel, reqGold = RebirthService.GetRequirements(currentRebirths)

    if data.Level < reqLevel then
        return { Success = false, Error = string.format("Level %d required for Rebirth (Current: %d)!", reqLevel, data.Level) }
    end

    if data.Gold < reqGold then
        return { Success = false, Error = string.format("Need %s Gold for Rebirth (Current: %d)!", string.format("%d", reqGold), data.Gold) }
    end

    -- Deduct gold & reset level progression
    data.Gold -= reqGold
    data.Level = 1
    data.XP = 0
    data.NextLevelXP = 100
    data.Rebirths = currentRebirths + 1

    -- Sync data to client & recalculate stats
    DataService.SyncData(player)
    DataService.ApplyStatsToCharacter(player)

    -- Trigger Ascension VFX on Character
    if player.Character then
        playRebirthVFX(player.Character)
    end

    print(string.format("[RebirthService] %s ascended to Rebirth %d!", player.Name, data.Rebirths))
    return { Success = true, NewRebirths = data.Rebirths }
end

function RebirthService:Init()
    print("[RebirthService] Registering Rebirth remote endpoint...")

    local rebirthFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestRebirth)
    rebirthFn.OnServerInvoke = function(player: Player)
        return RebirthService.PerformRebirth(player)
    end
end

function RebirthService:Start()
    print("[RebirthService] Ascension & Rebirth engine active.")
end

return RebirthService
