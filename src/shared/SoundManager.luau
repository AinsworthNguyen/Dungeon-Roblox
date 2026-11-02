--!strict
--[[
    SoundManager.luau
    Zero-Latency Audio System for Dark Fantasy RPG.
    
    Architectural Highlights:
    1. Preloaded Sound Pool: Pre-creates multiple Sound instances per effect inside SoundService.
    2. RAM Preload via ContentProvider:PreloadAsync() to decode audio buffers at Client startup.
    3. Leading Silence Trimming: Sets precise TimePosition (StartOffset) before :Play() to skip dead air.
    4. Fast Round-Robin Pooling: 0ms execution without runtime Instance.new overhead.
]]

local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local SoundManager = {}

export type SoundDef = {
    SoundId: string,
    Volume: number,
    BasePitch: number,
    PitchVariance: number,
    StartOffset: number, -- Seconds of leading silence trimmed
}

local SOUND_CATALOG: { [string]: SoundDef } = {
    SwordSwing = {
        SoundId = "rbxassetid://12222216",
        Volume = 0.60,
        BasePitch = 1.25,
        PitchVariance = 0.05,
        StartOffset = 0.07,
    },
    HitSlash = {
        SoundId = "rbxassetid://12222208",
        Volume = 0.70,
        BasePitch = 1.15,
        PitchVariance = 0.05,
        StartOffset = 0.05,
    },
    Explosion = {
        SoundId = "rbxassetid://12222084",
        Volume = 0.75,
        BasePitch = 1.10,
        PitchVariance = 0.04,
        StartOffset = 0.07,
    },
    Dash = {
        SoundId = "rbxassetid://12222216",
        Volume = 0.65,
        BasePitch = 1.35,
        PitchVariance = 0.04,
        StartOffset = 0.06,
    },
    Heal = {
        SoundId = "rbxassetid://12222253",
        Volume = 0.70,
        BasePitch = 1.10,
        PitchVariance = 0.03,
        StartOffset = 0.04,
    },
    ChestOpen = {
        SoundId = "rbxassetid://12222253",
        Volume = 0.65,
        BasePitch = 1.10,
        PitchVariance = 0.03,
        StartOffset = 0.04,
    },
    LevelUp = {
        SoundId = "rbxassetid://12222253",
        Volume = 0.80,
        BasePitch = 1.35,
        PitchVariance = 0.0,
        StartOffset = 0.0,
    },
    Victory = {
        SoundId = "rbxassetid://12222253",
        Volume = 0.90,
        BasePitch = 1.0,
        PitchVariance = 0.0,
        StartOffset = 0.0,
    },
}

type SoundPoolEntry = {
    Instances: { Sound },
    Cursor: number,
}

local POOL_SIZE_PER_SOUND = 4
local soundPools: { [string]: SoundPoolEntry } = {}
local isInitialized = false

--[[
    Initializes and warms the Sound Pool in SoundService, preloading all audio buffers into RAM.
]]
function SoundManager.Init()
    if isInitialized then return end
    isInitialized = true

    local poolFolder = SoundService:FindFirstChild("DungeonSoundPool")
    if not poolFolder then
        poolFolder = Instance.new("Folder")
        poolFolder.Name = "DungeonSoundPool"
        poolFolder.Parent = SoundService
    end

    local assetsToPreload: { Instance } = {}

    for name, def in pairs(SOUND_CATALOG) do
        local entry: SoundPoolEntry = {
            Instances = {},
            Cursor = 1,
        }

        for i = 1, POOL_SIZE_PER_SOUND do
            local sound = Instance.new("Sound")
            sound.Name = string.format("%s_%d", name, i)
            sound.SoundId = def.SoundId
            sound.Volume = def.Volume
            sound.PlaybackSpeed = def.BasePitch
            sound.RollOffMaxDistance = 100
            sound.RollOffMinDistance = 10
            sound.Parent = poolFolder

            table.insert(entry.Instances, sound)
            table.insert(assetsToPreload, sound)
        end

        soundPools[name] = entry
    end

    -- Asynchronously preload and decode audio into RAM
    task.spawn(function()
        pcall(function()
            ContentProvider:PreloadAsync(assetsToPreload)
        end)
    end)
end

--[[
    Plays a 2D sound with zero latency from the preloaded pool, trimming leading silence.
]]
function SoundManager.Play(name: string, parent: Instance?, volumeMultiplier: number?): Sound?
    if not isInitialized then
        SoundManager.Init()
    end

    local def = SOUND_CATALOG[name]
    local pool = soundPools[name]
    if not def or not pool or #pool.Instances == 0 then
        return nil
    end

    local sound = pool.Instances[pool.Cursor]
    pool.Cursor = (pool.Cursor % #pool.Instances) + 1

    -- Apply dynamic pitch variance
    local variance = (math.random() * 2 - 1) * def.PitchVariance
    local finalPitch = math.clamp(def.BasePitch + variance, 0.5, 2.5)
    local finalVolume = def.Volume * (volumeMultiplier or 1.0)

    sound.Volume = finalVolume
    sound.PlaybackSpeed = finalPitch

    -- Trim leading silence for frame-perfect audio hit
    sound.TimePosition = def.StartOffset
    sound:Play()

    return sound
end

--[[
    Plays a 3D positional sound at the specified World coordinates with zero delay.
]]
function SoundManager.PlayAtPosition(name: string, position: Vector3, volumeMultiplier: number?): Sound?
    if not isInitialized then
        SoundManager.Init()
    end

    local def = SOUND_CATALOG[name]
    local pool = soundPools[name]
    if not def or not pool or #pool.Instances == 0 then
        return nil
    end

    -- Clone from preloaded template to inherit pre-decoded RAM buffer
    local template = pool.Instances[1]
    local sound = template:Clone()

    local variance = (math.random() * 2 - 1) * def.PitchVariance
    sound.PlaybackSpeed = math.clamp(def.BasePitch + variance, 0.5, 2.5)
    sound.Volume = def.Volume * (volumeMultiplier or 1.0)
    sound.RollOffMaxDistance = 90
    sound.RollOffMinDistance = 8

    local anchor = Instance.new("Part")
    anchor.Name = "3DSoundAnchor"
    anchor.Size = Vector3.new(0.1, 0.1, 0.1)
    anchor.CFrame = CFrame.new(position)
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.Transparency = 1
    anchor.Parent = Workspace

    sound.Parent = anchor
    sound.TimePosition = def.StartOffset
    sound:Play()

    sound.Ended:Connect(function()
        anchor:Destroy()
    end)

    task.delay(2.5, function()
        if anchor.Parent then
            anchor:Destroy()
        end
    end)

    return sound
end

-- Auto-initialize if running on Client
if RunService:IsClient() then
    task.spawn(SoundManager.Init)
end

return SoundManager
