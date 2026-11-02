--!strict
--[[
    LobbyService.luau
    Major Upgrade: Valley Greenery, 4 Cobblestone Crossroads,
    Adventurer's Guild Hall with 4-Player Party Dungeon Pods,
    Reforge Sanctuary, Training Grounds & Trading Plaza.
    
    Features:
    1. Anti-Glare Daytime Lighting (Brightness 1.0, ExposureCompensation -0.35, soft Ambient, Bloom 0.05).
    2. Expanded 360x360 Green Meadow Baseplate (LeafyGrass #417341) with natural procedural Trees & Boulders.
    3. Central Cobblestone Plaza (50x50) with Spawn Pad & Mystic Loot Chest.
    4. 4 Cobblestone Crossroads (18 studs wide with Rock borders) to 4 Cardinal Directions:
       - North: Adventurer's Guild Hall & 4-Player Party Pods.
       - East: Training Grounds (Wooden Fences, Weapon Racks, 3 Training Dummies).
       - West: Reforge & Trait Sanctuary (Blacksmith Forge, Anvil, Arcane Enchanting Table).
       - South: Trading Plaza (Welcome Archway, Fountain, Market Stalls, Coming Soon Billboard).
    5. Adventurer's Guild Hall (70x26x50) at (0, 0, -85):
       - Front open grand archway & red carpet.
       - 2 Leaderboard Monuments (TOP COMBAT POWER & TOP TREASURE ROLLERS) mounted on front facade.
       - Left Corner: Guild Reception Desk & Bounty Board (ProximityPrompt: View Quests).
       - Right Corner: Alchemist Stall (ProximityPrompt: Open Shop) & Ascension Altar (ProximityPrompt: Ascend / Rebirth).
       - Center Great Hall: 3 Multiplayer Party Pods (Floor 1, 2, 3) for up to 4 players with 5s countdown.
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local _TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ItemConfig = require(Shared:WaitForChild("ItemConfig"))
local RarityConfig = require(Shared:WaitForChild("RarityConfig"))

local LobbyService = {
    Name = "LobbyService",
    Priority = 1, -- Runs first to guarantee map readiness
}

local DUMMY_MAX_HEALTH = 500

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

-- Lazy DungeonService accessor
local function getDungeonService(): any
    local dsModule = script.Parent:FindFirstChild("DungeonService")
    if dsModule then
        return (require :: any)(dsModule)
    end
    local Server = script.Parent.Parent
    if Server then
        local Services = Server:FindFirstChild("Services")
        if Services then
            local ds = Services:FindFirstChild("DungeonService")
            if ds then
                return (require :: any)(ds)
            end
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- 1. 3D MYSTIC LOOT CHEST
--------------------------------------------------------------------------------

local function buildMysticChest(): Model
    local chestModel = Instance.new("Model")
    chestModel.Name = "MysticLootChest"

    -- 1. Stone Plinth / Dais at (0, 0.4, -12)
    local plinth = Instance.new("Part")
    plinth.Name = "Plinth"
    plinth.Size = Vector3.new(10, 0.8, 8)
    plinth.CFrame = CFrame.new(0, 0.4, -12)
    plinth.Anchored = true
    plinth.Material = Enum.Material.Cobblestone
    plinth.Color = Color3.fromRGB(48, 54, 76)
    plinth.TopSurface = Enum.SurfaceType.Smooth
    plinth.Parent = chestModel

    -- 2. Chest Body (Dark Wood)
    local body = Instance.new("Part")
    body.Name = "ChestBody"
    body.Size = Vector3.new(5.5, 2.4, 3.6)
    body.CFrame = CFrame.new(0, 2.0, -12)
    body.Anchored = true
    body.Material = Enum.Material.WoodPlanks
    body.Color = Color3.fromRGB(48, 32, 22)
    body.TopSurface = Enum.SurfaceType.Smooth
    body.Parent = chestModel

    -- 3. Chest Lid (Arched Top)
    local lid = Instance.new("Part")
    lid.Name = "ChestLid"
    lid.Size = Vector3.new(5.7, 1.2, 3.8)
    lid.CFrame = CFrame.new(0, 3.3, -12)
    lid.Anchored = true
    lid.Material = Enum.Material.WoodPlanks
    lid.Color = Color3.fromRGB(58, 38, 26)
    lid.TopSurface = Enum.SurfaceType.Smooth
    lid.Parent = chestModel

    -- 4. Gold Trim Bands (SmoothPlastic to avoid glare)
    local function createTrim(xOffset: number): Part
        local trim = Instance.new("Part")
        trim.Name = "GoldTrim"
        trim.Size = Vector3.new(0.4, 2.6, 3.75)
        trim.CFrame = CFrame.new(xOffset, 2.1, -12)
        trim.Anchored = true
        trim.Material = Enum.Material.SmoothPlastic
        trim.Color = Color3.fromRGB(235, 185, 45)
        trim.TopSurface = Enum.SurfaceType.Smooth
        trim.Parent = chestModel
        return trim
    end
    createTrim(-2.0)
    createTrim(2.0)

    -- 5. Front Latch (SmoothPlastic, soft warm glow)
    local latch = Instance.new("Part")
    latch.Name = "GoldenLock"
    latch.Size = Vector3.new(0.9, 1.1, 0.4)
    latch.CFrame = CFrame.new(0, 2.5, -10.0)
    latch.Anchored = true
    latch.Material = Enum.Material.SmoothPlastic
    latch.Color = Color3.fromRGB(240, 195, 50)
    latch.TopSurface = Enum.SurfaceType.Smooth
    latch.Parent = chestModel

    local chestLight = Instance.new("PointLight")
    chestLight.Name = "ChestGazeLight"
    chestLight.Range = 16
    chestLight.Brightness = 0.5
    chestLight.Color = Color3.fromRGB(245, 210, 110)
    chestLight.Shadows = false
    chestLight.Parent = latch

    -- 6. Sparkling Particle Emitter (Subtle, LightEmission 0.15)
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "ChestSparkles"
    emitter.Rate = 8
    emitter.LightEmission = 0.15
    emitter.Lifetime = NumberRange.new(1.5, 2.5)
    emitter.Speed = NumberRange.new(1.5, 3.0)
    emitter.SpreadAngle = Vector2.new(45, 45)
    emitter.Acceleration = Vector3.new(0, 2.0, 0)
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.5, 0.5),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(245, 215, 90)),
        ColorSequenceKeypoint.new(0.6, Color3.fromRGB(230, 160, 40)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 80, 230)),
    })
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.4),
        NumberSequenceKeypoint.new(1, 1),
    })
    emitter.Parent = latch

    -- 7. BillboardGui
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ChestTitle"
    billboard.Size = UDim2.new(0, 260, 0, 75)
    billboard.StudsOffset = Vector3.new(0, 4.8, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 60
    billboard.Adornee = lid
    billboard.Parent = chestModel

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, 0, 0, 34)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = "MYSTIC LOOT CHEST"
    titleLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
    titleLabel.TextSize = 20
    titleLabel.Parent = billboard

    local titleStroke = Instance.new("UIStroke")
    titleStroke.Color = Color3.fromRGB(15, 17, 26)
    titleStroke.Thickness = 2.5
    titleStroke.Parent = titleLabel

    local subLabel = Instance.new("TextLabel")
    subLabel.Name = "Subtitle"
    subLabel.Size = UDim2.new(1, 0, 0, 24)
    subLabel.Position = UDim2.new(0, 0, 0, 32)
    subLabel.BackgroundTransparency = 1
    subLabel.Font = Enum.Font.GothamMedium
    subLabel.Text = "Roll for Legendary & Secret Loot"
    subLabel.TextColor3 = Color3.fromRGB(180, 195, 230)
    subLabel.TextSize = 13
    subLabel.Parent = billboard

    local subStroke = Instance.new("UIStroke")
    subStroke.Color = Color3.fromRGB(15, 17, 26)
    subStroke.Thickness = 1.8
    subStroke.Parent = subLabel

    -- 8. ProximityPrompt for Physical Interaction
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "ChestPrompt"
    prompt.ActionText = "Roll Item"
    prompt.ObjectText = "Mystic Chest"
    prompt.MaxActivationDistance = 14
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false
    prompt.Parent = body

    chestModel.PrimaryPart = body
    chestModel.Parent = Workspace
    return chestModel
end

--------------------------------------------------------------------------------
-- 2. LIGHT PILLARS (ANTI-GLARE: SmoothPlastic & Brightness 0.6)
--------------------------------------------------------------------------------

local function createLightPillar(position: Vector3, parent: Instance)
    local pillarModel = Instance.new("Model")
    pillarModel.Name = "LightPillar"

    local base = Instance.new("Part")
    base.Name = "PillarBase"
    base.Size = Vector3.new(3.6, 1.2, 3.6)
    base.CFrame = CFrame.new(position.X, 0.6, position.Z)
    base.Anchored = true
    base.Material = Enum.Material.Cobblestone
    base.Color = Color3.fromRGB(55, 62, 82)
    base.TopSurface = Enum.SurfaceType.Smooth
    base.Parent = pillarModel

    local col = Instance.new("Part")
    col.Name = "PillarShaft"
    col.Size = Vector3.new(2.0, 9.0, 2.0)
    col.CFrame = CFrame.new(position.X, 5.7, position.Z)
    col.Anchored = true
    col.Material = Enum.Material.Cobblestone
    col.Color = Color3.fromRGB(75, 84, 110)
    col.TopSurface = Enum.SurfaceType.Smooth
    col.Parent = pillarModel

    local cap = Instance.new("Part")
    cap.Name = "PillarCap"
    cap.Size = Vector3.new(3.0, 1.0, 3.0)
    cap.CFrame = CFrame.new(position.X, 10.7, position.Z)
    cap.Anchored = true
    cap.Material = Enum.Material.Cobblestone
    cap.Color = Color3.fromRGB(55, 62, 82)
    cap.TopSurface = Enum.SurfaceType.Smooth
    cap.Parent = pillarModel

    -- SmoothPlastic lantern with gentle warm glow
    local crystal = Instance.new("Part")
    crystal.Name = "PillarLantern"
    crystal.Size = Vector3.new(1.6, 2.2, 1.6)
    crystal.CFrame = CFrame.new(position.X, 12.3, position.Z)
    crystal.Anchored = true
    crystal.Material = Enum.Material.SmoothPlastic
    crystal.Color = Color3.fromRGB(240, 205, 120)
    crystal.TopSurface = Enum.SurfaceType.Smooth
    crystal.Parent = pillarModel

    local light = Instance.new("PointLight")
    light.Name = "PillarLight"
    light.Range = 28
    light.Brightness = 0.6
    light.Color = Color3.fromRGB(245, 215, 140)
    light.Shadows = true
    light.Parent = crystal

    pillarModel.PrimaryPart = col
    pillarModel.Parent = parent
end

local function buildLightPillars()
    local folder = Workspace:FindFirstChild("LobbyPillars")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "LobbyPillars"
        folder.Parent = Workspace
    end

    local pillarCoords = {
        Vector3.new(-20, 0, -20),
        Vector3.new(20, 0, -20),
        Vector3.new(-20, 0, 20),
        Vector3.new(20, 0, 20),
    }

    for _, pos in ipairs(pillarCoords) do
        createLightPillar(pos, folder)
    end
end

--------------------------------------------------------------------------------
-- 3. 4 COBBLESTONE CROSSROADS (18 STUDS WIDE WITH ROCK BORDERS)
--------------------------------------------------------------------------------

local function buildRoads()
    local folder = Workspace:FindFirstChild("LobbyRoads")
    if folder then folder:Destroy() end
    folder = Instance.new("Folder")
    folder.Name = "LobbyRoads"
    folder.Parent = Workspace

    local function createRoadSegment(startPos: Vector3, endPos: Vector3)
        local center = (startPos + endPos) / 2
        local diff = endPos - startPos
        local length = diff.Magnitude
        local angle = math.atan2(diff.X, diff.Z)

        -- Central Cobblestone Road
        local road = Instance.new("Part")
        road.Name = "RoadSegment"
        road.Size = Vector3.new(18, 0.4, length)
        road.CFrame = CFrame.new(center.X, 0.2, center.Z) * CFrame.Angles(0, angle, 0)
        road.Anchored = true
        road.Material = Enum.Material.Cobblestone
        road.Color = Color3.fromRGB(85, 88, 95)
        road.TopSurface = Enum.SurfaceType.Smooth
        road.Parent = folder

        -- Left Rock Kerb Border
        local leftKerb = Instance.new("Part")
        leftKerb.Name = "RoadKerbLeft"
        leftKerb.Size = Vector3.new(1.4, 0.6, length)
        leftKerb.CFrame = CFrame.new(center.X, 0.3, center.Z) * CFrame.Angles(0, angle, 0) * CFrame.new(-9.7, 0, 0)
        leftKerb.Anchored = true
        leftKerb.Material = Enum.Material.Rock
        leftKerb.Color = Color3.fromRGB(60, 62, 70)
        leftKerb.TopSurface = Enum.SurfaceType.Smooth
        leftKerb.Parent = folder

        -- Right Rock Kerb Border
        local rightKerb = Instance.new("Part")
        rightKerb.Name = "RoadKerbRight"
        rightKerb.Size = Vector3.new(1.4, 0.6, length)
        rightKerb.CFrame = CFrame.new(center.X, 0.3, center.Z) * CFrame.Angles(0, angle, 0) * CFrame.new(9.7, 0, 0)
        rightKerb.Anchored = true
        rightKerb.Material = Enum.Material.Rock
        rightKerb.Color = Color3.fromRGB(60, 62, 70)
        rightKerb.TopSurface = Enum.SurfaceType.Smooth
        rightKerb.Parent = folder
    end

    -- 1. North Road: Leads from Central Plaza to Adventurer's Guild Hall
    createRoadSegment(Vector3.new(0, 0, -25), Vector3.new(0, 0, -50))

    -- 2. East Road: Leads to Training Grounds
    createRoadSegment(Vector3.new(25, 0, 0), Vector3.new(68, 0, 0))

    -- 3. West Road: Leads to Reforge & Trait Sanctuary
    createRoadSegment(Vector3.new(-25, 0, 0), Vector3.new(-68, 0, 0))

    -- 4. South Road: Leads to Trading Plaza
    createRoadSegment(Vector3.new(0, 0, 25), Vector3.new(0, 0, 68))
end

--------------------------------------------------------------------------------
-- 4. DIRECTION 2 (EAST): TRAINING GROUNDS & DAMAGE TEST DUMMIES
--------------------------------------------------------------------------------

local function buildTrainingGrounds()
    local folder = Workspace:FindFirstChild("TrainingGroundsArea")
    if folder then folder:Destroy() end
    folder = Instance.new("Folder")
    folder.Name = "TrainingGroundsArea"
    folder.Parent = Workspace

    -- Stone & dirt training yard
    local yard = Instance.new("Part")
    yard.Name = "YardFloor"
    yard.Size = Vector3.new(38, 0.4, 38)
    yard.CFrame = CFrame.new(85, 0.2, 0)
    yard.Anchored = true
    yard.Material = Enum.Material.Cobblestone
    yard.Color = Color3.fromRGB(80, 82, 90)
    yard.TopSurface = Enum.SurfaceType.Smooth
    yard.Parent = folder

    -- Wooden fence around perimeter (3 sides)
    local function createFenceSection(startPos: Vector3, endPos: Vector3)
        local center = (startPos + endPos) / 2
        local length = (endPos - startPos).Magnitude
        local angle = math.atan2(endPos.X - startPos.X, endPos.Z - startPos.Z)

        local rail = Instance.new("Part")
        rail.Size = Vector3.new(0.4, 0.8, length)
        rail.CFrame = CFrame.new(center.X, 2.2, center.Z) * CFrame.Angles(0, angle, 0)
        rail.Anchored = true
        rail.Material = Enum.Material.WoodPlanks
        rail.Color = Color3.fromRGB(70, 50, 35)
        rail.Parent = folder

        local lowerRail = Instance.new("Part")
        lowerRail.Size = Vector3.new(0.4, 0.8, length)
        lowerRail.CFrame = CFrame.new(center.X, 1.0, center.Z) * CFrame.Angles(0, angle, 0)
        lowerRail.Anchored = true
        lowerRail.Material = Enum.Material.WoodPlanks
        lowerRail.Color = Color3.fromRGB(70, 50, 35)
        lowerRail.Parent = folder
    end

    createFenceSection(Vector3.new(68, 0, 19), Vector3.new(104, 0, 19))
    createFenceSection(Vector3.new(104, 0, 19), Vector3.new(104, 0, -19))
    createFenceSection(Vector3.new(104, 0, -19), Vector3.new(68, 0, -19))

    -- Weapon Racks with training swords
    local rack = Instance.new("Part")
    rack.Name = "WeaponRack"
    rack.Size = Vector3.new(6.0, 3.5, 1.2)
    rack.CFrame = CFrame.new(101, 1.75, 8)
    rack.Anchored = true
    rack.Material = Enum.Material.WoodPlanks
    rack.Color = Color3.fromRGB(55, 38, 25)
    rack.Parent = folder

    -- 3 Training Dummies at (80, 0, -8), (85, 0, 0), (80, 0, 8)
    local dummiesFolder = Workspace:FindFirstChild("TrainingDummies")
    if dummiesFolder then dummiesFolder:Destroy() end
    dummiesFolder = Instance.new("Folder")
    dummiesFolder.Name = "TrainingDummies"
    dummiesFolder.Parent = Workspace

    local dummyPositions = {
        Vector3.new(80, 0, -8),
        Vector3.new(85, 0, 0),
        Vector3.new(80, 0, 8),
    }

    for i, pos in ipairs(dummyPositions) do
        local dummyModel = Instance.new("Model")
        dummyModel.Name = ""
        dummyModel:SetAttribute("Health", DUMMY_MAX_HEALTH)
        dummyModel:SetAttribute("MaxHealth", DUMMY_MAX_HEALTH)
        dummyModel:SetAttribute("IsDummy", true)
        CollectionService:AddTag(dummyModel, "TrainingDummy")

        -- Post Base
        local post = Instance.new("Part")
        post.Name = "PostBase"
        post.Size = Vector3.new(0.8, 1.6, 0.8)
        post.CFrame = CFrame.new(pos.X, 0.8, pos.Z)
        post.Anchored = true
        post.Material = Enum.Material.Wood
        post.Color = Color3.fromRGB(60, 42, 28)
        post.Parent = dummyModel

        -- Torso
        local torso = Instance.new("Part")
        torso.Name = "Torso"
        torso.Size = Vector3.new(2.4, 3.2, 1.4)
        torso.CFrame = CFrame.new(pos.X, 3.2, pos.Z)
        torso.Anchored = true
        torso.CanCollide = true
        torso.Material = Enum.Material.Fabric
        torso.Color = Color3.fromRGB(160, 130, 90)
        torso.TopSurface = Enum.SurfaceType.Smooth
        torso.Parent = dummyModel

        -- Head
        local head = Instance.new("Part")
        head.Name = "Head"
        head.Size = Vector3.new(1.4, 1.4, 1.4)
        head.CFrame = CFrame.new(pos.X, 5.5, pos.Z)
        head.Anchored = true
        head.CanCollide = true
        head.Material = Enum.Material.Fabric
        head.Color = Color3.fromRGB(180, 150, 105)
        head.TopSurface = Enum.SurfaceType.Smooth
        head.Parent = dummyModel

        -- Target ring decal
        local targetMark = Instance.new("Part")
        targetMark.Name = "TargetMark"
        targetMark.Shape = Enum.PartType.Cylinder
        targetMark.Size = Vector3.new(0.05, 1.6, 1.6)
        targetMark.CFrame = CFrame.new(pos.X - 0.72, 3.4, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
        targetMark.Anchored = true
        targetMark.CanCollide = false
        targetMark.Material = Enum.Material.Neon
        targetMark.Color = Color3.fromRGB(220, 50, 50)
        targetMark.Parent = dummyModel

        -- Crossbar Arms
        local arms = Instance.new("Part")
        arms.Name = "Arms"
        arms.Size = Vector3.new(0.8, 0.8, 4.6)
        arms.CFrame = CFrame.new(pos.X, 4.0, pos.Z)
        arms.Anchored = true
        arms.Material = Enum.Material.Wood
        arms.Color = Color3.fromRGB(90, 62, 40)
        arms.TopSurface = Enum.SurfaceType.Smooth
        arms.Parent = dummyModel

        -- Overhead Billboard Health Bar
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "DummyHUD"
        billboard.Size = UDim2.new(0, 140, 0, 42)
        billboard.StudsOffset = Vector3.new(0, 4.4, 0)
        billboard.AlwaysOnTop = true
        billboard.MaxDistance = 55
        billboard.Adornee = head
        billboard.Parent = dummyModel

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "DummyName"
        nameLabel.Size = UDim2.new(1, 0, 0, 18)
        nameLabel.Position = UDim2.new(0, 0, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.Text = string.format("🎯 DUMMY #%d", i)
        nameLabel.TextColor3 = Color3.fromRGB(255, 225, 130)
        nameLabel.TextSize = 11
        nameLabel.Parent = billboard

        local hpBg = Instance.new("Frame")
        hpBg.Name = "HPBarBg"
        hpBg.Size = UDim2.new(1, -12, 0, 12)
        hpBg.Position = UDim2.new(0, 6, 0, 20)
        hpBg.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
        hpBg.BorderSizePixel = 0
        hpBg.Parent = billboard

        local hpCorner = Instance.new("UICorner")
        hpCorner.CornerRadius = UDim.new(0, 6)
        hpCorner.Parent = hpBg

        local hpFill = Instance.new("Frame")
        hpFill.Name = "HPBarFill"
        hpFill.Size = UDim2.new(1, 0, 1, 0)
        hpFill.BackgroundColor3 = Color3.fromRGB(55, 215, 95)
        hpFill.BorderSizePixel = 0
        hpFill.Parent = hpBg

        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(0, 6)
        fillCorner.Parent = hpFill

        local hpText = Instance.new("TextLabel")
        hpText.Name = "HPText"
        hpText.Size = UDim2.new(1, 0, 1, 0)
        hpText.BackgroundTransparency = 1
        hpText.Font = Enum.Font.GothamBold
        hpText.Text = string.format("%d / %d", DUMMY_MAX_HEALTH, DUMMY_MAX_HEALTH)
        hpText.TextColor3 = Color3.fromRGB(255, 255, 255)
        hpText.TextSize = 9
        hpText.Parent = hpBg

        -- Humanoid for damage detection (disable default Roblox overhead display)
        local hum = Instance.new("Humanoid")
        hum.MaxHealth = DUMMY_MAX_HEALTH
        hum.Health = DUMMY_MAX_HEALTH
        hum.WalkSpeed = 0
        hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
        hum.Parent = dummyModel

        hum.HealthChanged:Connect(function(newHealth)
            local ratio = math.clamp(newHealth / DUMMY_MAX_HEALTH, 0, 1)
            hpFill.Size = UDim2.new(ratio, 0, 1, 0)
            hpText.Text = string.format("%d / %d", math.max(0, math.round(newHealth)), DUMMY_MAX_HEALTH)
            if newHealth <= 0 then
                task.delay(1.5, function()
                    if hum and hum.Parent then
                        hum.Health = DUMMY_MAX_HEALTH
                    end
                end)
            end
        end)

        CollectionService:AddTag(dummyModel, "Enemy")
        CollectionService:AddTag(dummyModel, "Damageable")
        dummyModel.PrimaryPart = torso
        dummyModel.Parent = dummiesFolder
    end
end

--------------------------------------------------------------------------------
-- 5. DIRECTION 3 (WEST): REFORGE & TRAIT SANCTUARY
--------------------------------------------------------------------------------

local function buildReforgeSanctuary()
    local folder = Workspace:FindFirstChild("ReforgeSanctuaryArea")
    if folder then folder:Destroy() end
    folder = Instance.new("Folder")
    folder.Name = "ReforgeSanctuaryArea"
    folder.Parent = Workspace

    -- Slate Platform
    local yard = Instance.new("Part")
    yard.Name = "SanctuaryFloor"
    yard.Size = Vector3.new(38, 0.4, 38)
    yard.CFrame = CFrame.new(-85, 0.2, 0)
    yard.Anchored = true
    yard.Material = Enum.Material.Slate
    yard.Color = Color3.fromRGB(50, 54, 65)
    yard.TopSurface = Enum.SurfaceType.Smooth
    yard.Parent = folder

    -- Blacksmith Stone Furnace (Hearth & Chimney)
    local hearth = Instance.new("Part")
    hearth.Name = "ForgeHearth"
    hearth.Size = Vector3.new(8, 5, 6)
    hearth.CFrame = CFrame.new(-98, 2.7, 0)
    hearth.Anchored = true
    hearth.Material = Enum.Material.Cobblestone
    hearth.Color = Color3.fromRGB(45, 48, 58)
    hearth.Parent = folder

    local embers = Instance.new("Part")
    embers.Name = "ForgeEmbers"
    embers.Size = Vector3.new(5, 1.2, 3)
    embers.CFrame = CFrame.new(-96, 2.5, 0)
    embers.Anchored = true
    embers.Material = Enum.Material.Neon
    embers.Color = Color3.fromRGB(220, 85, 25)
    embers.Parent = folder

    -- Iron Anvil on Stump
    local stump = Instance.new("Part")
    stump.Name = "AnvilStump"
    stump.Size = Vector3.new(3, 2, 3)
    stump.CFrame = CFrame.new(-85, 1.2, -6)
    stump.Anchored = true
    stump.Material = Enum.Material.Wood
    stump.Color = Color3.fromRGB(60, 42, 28)
    stump.Parent = folder

    local anvil = Instance.new("Part")
    anvil.Name = "BlacksmithAnvil"
    anvil.Size = Vector3.new(2.4, 1.4, 1.2)
    anvil.CFrame = CFrame.new(-85, 2.9, -6)
    anvil.Anchored = true
    anvil.Material = Enum.Material.Metal
    anvil.Color = Color3.fromRGB(40, 42, 50)
    anvil.Parent = folder

    local anvilPrompt = Instance.new("ProximityPrompt")
    anvilPrompt.Name = "ReforgePrompt"
    anvilPrompt.ActionText = "Open Reforge & Traits"
    anvilPrompt.ObjectText = "Master Blacksmith Anvil"
    anvilPrompt.MaxActivationDistance = 12
    anvilPrompt.HoldDuration = 0
    anvilPrompt.Parent = anvil

    anvilPrompt.Triggered:Connect(function(player: Player)
        local openUIEvt = Remotes.GetEvent(Constants.REMOTE_EVENTS.OpenUIModal)
        openUIEvt:FireClient(player, "Inventory")
    end)

    -- Arcane Enchanting Table
    local tablePart = Instance.new("Part")
    tablePart.Name = "ArcaneTable"
    tablePart.Size = Vector3.new(5, 2.2, 4)
    tablePart.CFrame = CFrame.new(-85, 1.3, 6)
    tablePart.Anchored = true
    tablePart.Material = Enum.Material.WoodPlanks
    tablePart.Color = Color3.fromRGB(50, 36, 65)
    tablePart.Parent = folder

    local gem = Instance.new("Part")
    gem.Name = "FloatingGem"
    gem.Shape = Enum.PartType.Ball
    gem.Size = Vector3.new(1.4, 1.4, 1.4)
    gem.CFrame = CFrame.new(-85, 3.4, 6)
    gem.Anchored = true
    gem.Material = Enum.Material.Glass
    gem.Color = Color3.fromRGB(180, 70, 255)
    gem.Parent = folder

    -- Signpost with Billboard
    local signPost = Instance.new("Part")
    signPost.Size = Vector3.new(0.8, 6, 0.8)
    signPost.CFrame = CFrame.new(-72, 3.2, -10)
    signPost.Anchored = true
    signPost.Material = Enum.Material.Wood
    signPost.Color = Color3.fromRGB(60, 42, 28)
    signPost.Parent = folder

    local signBoard = Instance.new("BillboardGui")
    signBoard.Size = UDim2.new(0, 240, 0, 50)
    signBoard.StudsOffset = Vector3.new(0, 3.5, 0)
    signBoard.AlwaysOnTop = true
    signBoard.MaxDistance = 50
    signBoard.Adornee = signPost
    signBoard.Parent = signPost

    local signLbl = Instance.new("TextLabel")
    signLbl.Size = UDim2.new(1, 0, 1, 0)
    signLbl.BackgroundTransparency = 1
    signLbl.Font = Enum.Font.GothamBold
    signLbl.Text = "🔨 REFORGE & TRAIT SANCTUARY"
    signLbl.TextColor3 = Color3.fromRGB(255, 215, 60)
    signLbl.TextSize = 13
    signLbl.Parent = signBoard
end

--------------------------------------------------------------------------------
-- 6. DIRECTION 4 (SOUTH): TRADING PLAZA & COMING SOON BILLBOARD
--------------------------------------------------------------------------------

local function buildTradingPlaza()
    local folder = Workspace:FindFirstChild("TradingPlazaArea")
    if folder then folder:Destroy() end
    folder = Instance.new("Folder")
    folder.Name = "TradingPlazaArea"
    folder.Parent = Workspace

    -- Stone Plaza Floor
    local plaza = Instance.new("Part")
    plaza.Name = "PlazaFloor"
    plaza.Size = Vector3.new(44, 0.4, 44)
    plaza.CFrame = CFrame.new(0, 0.2, 85)
    plaza.Anchored = true
    plaza.Material = Enum.Material.Cobblestone
    plaza.Color = Color3.fromRGB(80, 82, 90)
    plaza.TopSurface = Enum.SurfaceType.Smooth
    plaza.Parent = folder

    -- Welcome Archway at (0, 0, 68)
    local postL = Instance.new("Part")
    postL.Size = Vector3.new(2, 10, 2)
    postL.CFrame = CFrame.new(-8, 5, 68)
    postL.Anchored = true
    postL.Material = Enum.Material.Cobblestone
    postL.Color = Color3.fromRGB(65, 70, 85)
    postL.Parent = folder

    local postR = Instance.new("Part")
    postR.Size = Vector3.new(2, 10, 2)
    postR.CFrame = CFrame.new(8, 5, 68)
    postR.Anchored = true
    postR.Material = Enum.Material.Cobblestone
    postR.Color = Color3.fromRGB(65, 70, 85)
    postR.Parent = folder

    local archBeam = Instance.new("Part")
    archBeam.Size = Vector3.new(20, 2, 2.4)
    archBeam.CFrame = CFrame.new(0, 11, 68)
    archBeam.Anchored = true
    archBeam.Material = Enum.Material.WoodPlanks
    archBeam.Color = Color3.fromRGB(65, 45, 30)
    archBeam.Parent = folder

    -- Central Stone Water Fountain
    local fountainBase = Instance.new("Part")
    fountainBase.Name = "FountainBase"
    fountainBase.Shape = Enum.PartType.Cylinder
    fountainBase.Size = Vector3.new(1.6, 12, 12)
    fountainBase.CFrame = CFrame.new(0, 0.8, 85) * CFrame.Angles(0, 0, math.rad(90))
    fountainBase.Anchored = true
    fountainBase.Material = Enum.Material.Cobblestone
    fountainBase.Color = Color3.fromRGB(60, 65, 80)
    fountainBase.Parent = folder

    local water = Instance.new("Part")
    water.Name = "FountainWater"
    water.Shape = Enum.PartType.Cylinder
    water.Size = Vector3.new(0.4, 10.5, 10.5)
    water.CFrame = CFrame.new(0, 1.5, 85) * CFrame.Angles(0, 0, math.rad(90))
    water.Anchored = true
    water.Material = Enum.Material.Glass
    water.Color = Color3.fromRGB(40, 140, 225)
    water.Transparency = 0.3
    water.Parent = folder

    -- 2 Merchant Stalls
    local function createStall(xPos: number)
        local counter = Instance.new("Part")
        counter.Size = Vector3.new(8, 2.4, 3.5)
        counter.CFrame = CFrame.new(xPos, 1.4, 85)
        counter.Anchored = true
        counter.Material = Enum.Material.WoodPlanks
        counter.Color = Color3.fromRGB(75, 52, 35)
        counter.Parent = folder

        local canopy = Instance.new("Part")
        canopy.Size = Vector3.new(9, 0.8, 4.5)
        canopy.CFrame = CFrame.new(xPos, 4.6, 85)
        canopy.Anchored = true
        canopy.Material = Enum.Material.Fabric
        canopy.Color = Color3.fromRGB(180, 45, 45)
        canopy.Parent = folder
    end
    createStall(-14)
    createStall(14)

    -- Large Coming Soon Billboard at (0, 7.5, 102)
    local boardFrame = Instance.new("Part")
    boardFrame.Size = Vector3.new(24, 6, 1.2)
    boardFrame.CFrame = CFrame.new(0, 6.5, 102)
    boardFrame.Anchored = true
    boardFrame.Material = Enum.Material.WoodPlanks
    boardFrame.Color = Color3.fromRGB(40, 30, 20)
    boardFrame.Parent = folder

    local sGui = Instance.new("SurfaceGui")
    sGui.Face = Enum.NormalId.Front
    sGui.CanvasSize = Vector2.new(800, 200)
    sGui.LightInfluence = 0.1
    sGui.Parent = boardFrame

    local sLbl = Instance.new("TextLabel")
    sLbl.Size = UDim2.new(1, 0, 1, 0)
    sLbl.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
    sLbl.Font = Enum.Font.GothamBold
    sLbl.Text = "⚖️ PLAYER TRADING HUB\n[ COMING SOON ]"
    sLbl.TextColor3 = Color3.fromRGB(255, 205, 50)
    sLbl.TextSize = 28
    sLbl.Parent = sGui
end

--------------------------------------------------------------------------------
-- 7. PROCEDURAL VALLEY TREES & BOULDERS
--------------------------------------------------------------------------------

local function buildFoliage()
    local folder = Workspace:FindFirstChild("LobbyFoliage")
    if folder then folder:Destroy() end
    folder = Instance.new("Folder")
    folder.Name = "LobbyFoliage"
    folder.Parent = Workspace

    -- Exclusion zone for Adventurer's Guild Hall: X from -62 to 62 and Z from -42 to -145
    local function isInsideGuildHallZone(pos: Vector3): boolean
        return pos.X >= -62 and pos.X <= 62 and pos.Z <= -42 and pos.Z >= -145
    end

    local function createTree(pos: Vector3, scale: number)
        if isInsideGuildHallZone(pos) then return end

        local treeModel = Instance.new("Model")
        treeModel.Name = "ValleyTree"

        local trunk = Instance.new("Part")
        trunk.Size = Vector3.new(1.8 * scale, 12 * scale, 1.8 * scale)
        trunk.CFrame = CFrame.new(pos.X, 6 * scale, pos.Z)
        trunk.Anchored = true
        trunk.Material = Enum.Material.Wood
        trunk.Color = Color3.fromRGB(65, 45, 30)
        trunk.Parent = treeModel

        local tiers = {
            { y = 10 * scale, size = 11 * scale, color = Color3.fromRGB(45, 95, 45) },
            { y = 14 * scale, size = 8.5 * scale, color = Color3.fromRGB(55, 110, 50) },
            { y = 17 * scale, size = 6.0 * scale, color = Color3.fromRGB(65, 125, 55) },
        }

        for _, t in ipairs(tiers) do
            local crown = Instance.new("Part")
            crown.Size = Vector3.new(t.size, 3.5 * scale, t.size)
            crown.CFrame = CFrame.new(pos.X, t.y, pos.Z)
            crown.Anchored = true
            crown.Material = Enum.Material.Grass
            crown.Color = t.color
            crown.TopSurface = Enum.SurfaceType.Smooth
            crown.Parent = treeModel
        end

        treeModel.Parent = folder
    end

    local function createBoulder(pos: Vector3, size: Vector3)
        if isInsideGuildHallZone(pos) then return end

        local boulder = Instance.new("Part")
        boulder.Size = size
        boulder.CFrame = CFrame.new(pos.X, size.Y / 2, pos.Z) * CFrame.Angles(math.rad(math.random(-15, 15)), math.rad(math.random(0, 180)), math.rad(math.random(-15, 15)))
        boulder.Anchored = true
        boulder.Material = Enum.Material.Rock
        boulder.Color = Color3.fromRGB(75, 78, 85)
        boulder.TopSurface = Enum.SurfaceType.Smooth
        boulder.Parent = folder
    end

    -- Scatter Trees in grassy areas away from center & roads (strictly outside Guild Hall)
    local treeCoords = {
        Vector3.new(45, 0, 45), Vector3.new(75, 0, 45), Vector3.new(110, 0, 60),
        Vector3.new(-45, 0, 45), Vector3.new(-85, 0, 45), Vector3.new(-110, 0, 70),
        Vector3.new(45, 0, -45), Vector3.new(75, 0, -45), Vector3.new(110, 0, -60),
        Vector3.new(-45, 0, -45), Vector3.new(-85, 0, -45), Vector3.new(-110, 0, -70),
        Vector3.new(130, 0, 15), Vector3.new(130, 0, -15),
        Vector3.new(-130, 0, 15), Vector3.new(-130, 0, -15),
        Vector3.new(20, 0, 120), Vector3.new(-20, 0, 120),
    }

    for i, c in ipairs(treeCoords) do
        local scale = 0.85 + (i % 3) * 0.15
        createTree(c, scale)
    end

    -- Scatter boulders
    local boulderCoords = {
        { pos = Vector3.new(32, 0, 28), size = Vector3.new(4, 3, 4) },
        { pos = Vector3.new(-32, 0, 28), size = Vector3.new(5, 3.5, 4.5) },
        { pos = Vector3.new(28, 0, -32), size = Vector3.new(4.5, 3, 3.5) },
        { pos = Vector3.new(-28, 0, -32), size = Vector3.new(3.8, 2.8, 4) },
        { pos = Vector3.new(55, 0, 22), size = Vector3.new(6, 4, 5) },
        { pos = Vector3.new(-55, 0, 22), size = Vector3.new(5.5, 3.8, 5) },
    }

    for _, b in ipairs(boulderCoords) do
        createBoulder(b.pos, b.size)
    end
end

--------------------------------------------------------------------------------
-- 8. ADVENTURER'S GUILD HALL (HỘI QUÁN MẠO HIỂM GIẢ & 4-PLAYER PARTY PODS)
--------------------------------------------------------------------------------

local FLOOR_CONFIGS: { [string]: { Name: string, FullName: string, Color: Color3 } } = {
    floor_1 = {
        Name = "Floor 1: Goblin Crypt",
        FullName = "FLOOR 1: GOBLIN CRYPT",
        Color = Color3.fromRGB(75, 215, 110),
    },
    floor_2 = {
        Name = "Floor 2: Cursed Citadel",
        FullName = "FLOOR 2: CURSED CITADEL",
        Color = Color3.fromRGB(175, 75, 255),
    },
    floor_3 = {
        Name = "Floor 3: Abyssal Sanctum",
        FullName = "FLOOR 3: ABYSSAL SANCTUM",
        Color = Color3.fromRGB(255, 60, 90),
    },
}

local EMPTY_ROOM_COLOR = Color3.fromRGB(140, 150, 165)

type CustomPartyRoom = {
    RoomId: number,
    Position: Vector3,
    Host: Player?,
    Members: { Player },
    SelectedFloor: string,
    MaxPlayers: number,
    FriendsOnly: boolean,
    InvitedUserIds: { [number]: boolean },
    Countdown: number?,
    PadFloor: Part?,
    PadRing: Part?,
    TableTop: Part?,
    TitleLabel: TextLabel?,
    CountLabel: TextLabel?,
    StatusLabel: TextLabel?,
}

local customPartyRooms: { CustomPartyRoom } = {
    -- Floor 1: 3 Tavern Party Rooms along X = 35
    {
        RoomId = 1,
        Position = Vector3.new(35, 0.5, -70),
        Host = nil,
        Members = {},
        SelectedFloor = "floor_1",
        MaxPlayers = 4,
        FriendsOnly = false,
        InvitedUserIds = {},
        Countdown = nil,
        PadFloor = nil,
        PadRing = nil,
        TableTop = nil,
        TitleLabel = nil,
        CountLabel = nil,
        StatusLabel = nil,
    },
    {
        RoomId = 2,
        Position = Vector3.new(35, 0.5, -92),
        Host = nil,
        Members = {},
        SelectedFloor = "floor_1",
        MaxPlayers = 4,
        FriendsOnly = false,
        InvitedUserIds = {},
        Countdown = nil,
        PadFloor = nil,
        PadRing = nil,
        TableTop = nil,
        TitleLabel = nil,
        CountLabel = nil,
        StatusLabel = nil,
    },
    {
        RoomId = 3,
        Position = Vector3.new(35, 0.5, -114),
        Host = nil,
        Members = {},
        SelectedFloor = "floor_1",
        MaxPlayers = 4,
        FriendsOnly = false,
        InvitedUserIds = {},
        Countdown = nil,
        PadFloor = nil,
        PadRing = nil,
        TableTop = nil,
        TitleLabel = nil,
        CountLabel = nil,
        StatusLabel = nil,
    },
    -- Floor 2 (Mezzanine Corridor at Y = 18): 3 Tavern Party Rooms along X = 35
    {
        RoomId = 4,
        Position = Vector3.new(35, 18.5, -70),
        Host = nil,
        Members = {},
        SelectedFloor = "floor_1",
        MaxPlayers = 4,
        FriendsOnly = false,
        InvitedUserIds = {},
        Countdown = nil,
        PadFloor = nil,
        PadRing = nil,
        TableTop = nil,
        TitleLabel = nil,
        CountLabel = nil,
        StatusLabel = nil,
    },
    {
        RoomId = 5,
        Position = Vector3.new(35, 18.5, -92),
        Host = nil,
        Members = {},
        SelectedFloor = "floor_1",
        MaxPlayers = 4,
        FriendsOnly = false,
        InvitedUserIds = {},
        Countdown = nil,
        PadFloor = nil,
        PadRing = nil,
        TableTop = nil,
        TitleLabel = nil,
        CountLabel = nil,
        StatusLabel = nil,
    },
    {
        RoomId = 6,
        Position = Vector3.new(35, 18.5, -114),
        Host = nil,
        Members = {},
        SelectedFloor = "floor_1",
        MaxPlayers = 4,
        FriendsOnly = false,
        InvitedUserIds = {},
        Countdown = nil,
        PadFloor = nil,
        PadRing = nil,
        TableTop = nil,
        TitleLabel = nil,
        CountLabel = nil,
        StatusLabel = nil,
    },
}

local playerLeaveCooldown: { [number]: number } = {}

-- 4 chair offsets around tavern table (radius 3.2 studs): South (Host), West, East, North
local ROOM_SLOT_OFFSETS = {
    Vector3.new(0, 0.8, 3.2),   -- Member 1 (Host): South chair, facing North
    Vector3.new(-3.2, 0.8, 0),  -- Member 2: West chair, facing East
    Vector3.new(3.2, 0.8, 0),   -- Member 3: East chair, facing West
    Vector3.new(0, 0.8, -3.2),  -- Member 4: North chair, facing South
}

local function buildAdventurersGuildHall()
    local folder = Workspace:FindFirstChild("AdventurersGuildHall")
    if folder then folder:Destroy() end
    folder = Instance.new("Folder")
    folder.Name = "AdventurersGuildHall"
    folder.Parent = Workspace

    -- Dimensions: 110 wide (X = -55 to 55), 38 high (Y = 0 to 38), 90 deep (Z = -50 to -140) centered at (0, 0, -95)
    local hallPos = Vector3.new(0, 0, -95)

    -- 1. Main Interior Ground Floor (110 x 0.6 x 90)
    local floor = Instance.new("Part")
    floor.Name = "GuildFloor"
    floor.Size = Vector3.new(110, 0.6, 90)
    floor.CFrame = CFrame.new(hallPos.X, 0.3, hallPos.Z)
    floor.Anchored = true
    floor.Material = Enum.Material.Cobblestone
    floor.Color = Color3.fromRGB(70, 72, 80)
    floor.TopSurface = Enum.SurfaceType.Smooth
    floor.Parent = folder

    -- 2. Royal Red Carpet Crossroads (Hệ thống Thảm Đỏ Hoàng Gia Chữ Thập)
    -- Main Axis: From Entrance (0, 0.2, -50) to Ascension Altar (0, 0.2, -128) -> Length 78, Center Z = -89
    local carpetMain = Instance.new("Part")
    carpetMain.Name = "RedCarpetMain"
    carpetMain.Size = Vector3.new(12, 0.2, 78)
    carpetMain.CFrame = CFrame.new(0, 0.65, -89)
    carpetMain.Anchored = true
    carpetMain.Material = Enum.Material.Fabric
    carpetMain.Color = Color3.fromRGB(150, 30, 35)
    carpetMain.TopSurface = Enum.SurfaceType.Smooth
    carpetMain.Parent = folder

    local function createCarpetTrim(size: Vector3, cframe: CFrame)
        local trim = Instance.new("Part")
        trim.Name = "GoldCarpetTrim"
        trim.Size = size
        trim.CFrame = cframe
        trim.Anchored = true
        trim.Material = Enum.Material.SmoothPlastic
        trim.Color = Color3.fromRGB(240, 195, 50)
        trim.TopSurface = Enum.SurfaceType.Smooth
        trim.CanCollide = false
        trim.Parent = folder
    end

    -- Main Carpet gold borders
    createCarpetTrim(Vector3.new(0.4, 0.22, 78), CFrame.new(-6.1, 0.66, -89))
    createCarpetTrim(Vector3.new(0.4, 0.22, 78), CFrame.new(6.1, 0.66, -89))

    -- Crossroad Branch Left (at Z = -88): leads to Bounty Board & Alchemist Counter (X = -6 to X = -42)
    local carpetBranchL = Instance.new("Part")
    carpetBranchL.Name = "RedCarpetBranchL"
    carpetBranchL.Size = Vector3.new(36, 0.2, 8)
    carpetBranchL.CFrame = CFrame.new(-24, 0.65, -88)
    carpetBranchL.Anchored = true
    carpetBranchL.Material = Enum.Material.Fabric
    carpetBranchL.Color = Color3.fromRGB(150, 30, 35)
    carpetBranchL.TopSurface = Enum.SurfaceType.Smooth
    carpetBranchL.Parent = folder

    createCarpetTrim(Vector3.new(36, 0.22, 0.4), CFrame.new(-24, 0.66, -92.1))
    createCarpetTrim(Vector3.new(36, 0.22, 0.4), CFrame.new(-24, 0.66, -83.9))

    -- Crossroad Branch Right (at Z = -88): leads to Party Rooms, stopping neatly at X = 24 (outside Room #2)
    local carpetBranchR = Instance.new("Part")
    carpetBranchR.Name = "RedCarpetBranchR"
    carpetBranchR.Size = Vector3.new(18, 0.2, 8)
    carpetBranchR.CFrame = CFrame.new(15, 0.65, -88)
    carpetBranchR.Anchored = true
    carpetBranchR.Material = Enum.Material.Fabric
    carpetBranchR.Color = Color3.fromRGB(150, 30, 35)
    carpetBranchR.TopSurface = Enum.SurfaceType.Smooth
    carpetBranchR.Parent = folder

    createCarpetTrim(Vector3.new(18, 0.22, 0.4), CFrame.new(15, 0.66, -92.1))
    createCarpetTrim(Vector3.new(18, 0.22, 0.4), CFrame.new(15, 0.66, -83.9))
    createCarpetTrim(Vector3.new(0.4, 0.22, 8.4), CFrame.new(24.1, 0.66, -88))

    -- 3. Perimeter Stone Walls (Height = 38 studs, Y = 0 to 38)
    -- Back Wall (North at Z = -140)
    local backWall = Instance.new("Part")
    backWall.Name = "BackWall"
    backWall.Size = Vector3.new(110, 38, 2)
    backWall.CFrame = CFrame.new(0, 19, -140)
    backWall.Anchored = true
    backWall.Material = Enum.Material.Cobblestone
    backWall.Color = Color3.fromRGB(60, 62, 70)
    backWall.Parent = folder

    -- Left Wall (West at X = -55)
    local leftWall = Instance.new("Part")
    leftWall.Name = "LeftWall"
    leftWall.Size = Vector3.new(2, 38, 90)
    leftWall.CFrame = CFrame.new(-55, 19, -95)
    leftWall.Anchored = true
    leftWall.Material = Enum.Material.Cobblestone
    leftWall.Color = Color3.fromRGB(60, 62, 70)
    leftWall.Parent = folder

    -- Right Wall (East at X = 55)
    local rightWall = Instance.new("Part")
    rightWall.Name = "RightWall"
    rightWall.Size = Vector3.new(2, 38, 90)
    rightWall.CFrame = CFrame.new(55, 19, -95)
    rightWall.Anchored = true
    rightWall.Material = Enum.Material.Cobblestone
    rightWall.Color = Color3.fromRGB(60, 62, 70)
    rightWall.Parent = folder

    -- Front Wall (South at Z = -50) with Grand Entrance (X = -15 to 15 open)
    local frontWallL = Instance.new("Part")
    frontWallL.Name = "FrontWallL"
    frontWallL.Size = Vector3.new(40, 38, 2)
    frontWallL.CFrame = CFrame.new(-35, 19, -50)
    frontWallL.Anchored = true
    frontWallL.Material = Enum.Material.Cobblestone
    frontWallL.Color = Color3.fromRGB(60, 62, 70)
    frontWallL.Parent = folder

    local frontWallR = Instance.new("Part")
    frontWallR.Name = "FrontWallR"
    frontWallR.Size = Vector3.new(40, 38, 2)
    frontWallR.CFrame = CFrame.new(35, 19, -50)
    frontWallR.Anchored = true
    frontWallR.Material = Enum.Material.Cobblestone
    frontWallR.Color = Color3.fromRGB(60, 62, 70)
    frontWallR.Parent = folder

    -- Overhead Entrance Arch Beam & Signboard
    local archBeam = Instance.new("Part")
    archBeam.Name = "EntranceArch"
    archBeam.Size = Vector3.new(34, 10, 3)
    archBeam.CFrame = CFrame.new(0, 33, -50)
    archBeam.Anchored = true
    archBeam.Material = Enum.Material.WoodPlanks
    archBeam.Color = Color3.fromRGB(65, 45, 30)
    archBeam.Parent = folder

    local signGui = Instance.new("SurfaceGui")
    signGui.Face = Enum.NormalId.Front
    signGui.CanvasSize = Vector2.new(900, 220)
    signGui.LightInfluence = 0.1
    signGui.Parent = archBeam

    local signText = Instance.new("TextLabel")
    signText.Size = UDim2.new(1, 0, 1, 0)
    signText.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
    signText.Font = Enum.Font.GothamBold
    signText.Text = "⚔️ ADVENTURER'S GUILD HALL ⚔️"
    signText.TextColor3 = Color3.fromRGB(255, 205, 50)
    signText.TextSize = 38
    signText.Parent = signGui

    -- 4. Castle Flat Roof & Battlements (at Y = 38)
    local roofSlab = Instance.new("Part")
    roofSlab.Name = "RoofSlab"
    roofSlab.Size = Vector3.new(114, 2, 94)
    roofSlab.CFrame = CFrame.new(0, 38, -95)
    roofSlab.Anchored = true
    roofSlab.Material = Enum.Material.Slate
    roofSlab.Color = Color3.fromRGB(45, 48, 55)
    roofSlab.Parent = folder

    local roofCornice = Instance.new("Part")
    roofCornice.Name = "RoofCornice"
    roofCornice.Size = Vector3.new(116, 1.2, 96)
    roofCornice.CFrame = CFrame.new(0, 37.4, -95)
    roofCornice.Anchored = true
    roofCornice.Material = Enum.Material.Cobblestone
    roofCornice.Color = Color3.fromRGB(60, 62, 70)
    roofCornice.Parent = folder

    -- Corner Turret Posts
    local turretOffsets = {
        Vector3.new(-56, 40.5, -48),
        Vector3.new(56, 40.5, -48),
        Vector3.new(-56, 40.5, -142),
        Vector3.new(56, 40.5, -142),
    }
    for _, tPos in ipairs(turretOffsets) do
        local turret = Instance.new("Part")
        turret.Name = "CornerTurret"
        turret.Size = Vector3.new(5, 6, 5)
        turret.CFrame = CFrame.new(tPos)
        turret.Anchored = true
        turret.Material = Enum.Material.Cobblestone
        turret.Color = Color3.fromRGB(55, 58, 66)
        turret.Parent = folder
    end

    -- Parapet walls along roof edges
    local function createParapet(size: Vector3, cf: CFrame)
        local p = Instance.new("Part")
        p.Size = size
        p.CFrame = cf
        p.Anchored = true
        p.Material = Enum.Material.Cobblestone
        p.Color = Color3.fromRGB(55, 58, 66)
        p.Parent = folder
    end
    createParapet(Vector3.new(110, 2.5, 1.6), CFrame.new(0, 39.5, -48))
    createParapet(Vector3.new(110, 2.5, 1.6), CFrame.new(0, 39.5, -142))
    createParapet(Vector3.new(1.6, 2.5, 92), CFrame.new(-56, 39.5, -95))
    createParapet(Vector3.new(1.6, 2.5, 92), CFrame.new(56, 39.5, -95))

    -- Cathedral Grand Support Columns on West Side (Ceiling height 38)
    for _, zCol in ipairs({ -68, -112 }) do
        local col = Instance.new("Part")
        col.Name = "CathedralPillar"
        col.Size = Vector3.new(2.8, 38, 2.8)
        col.CFrame = CFrame.new(-16, 19, zCol)
        col.Anchored = true
        col.Material = Enum.Material.Cobblestone
        col.Color = Color3.fromRGB(55, 58, 68)
        col.Parent = folder
    end

    -- 5. North Center: GRAND ASCENSION ALTAR at Vector3.new(0, 0, -130)
    -- 3-Step Black Marble Dais
    local stepSizes = {
        { Size = Vector3.new(18, 0.8, 14), Y = 0.4, Color = Color3.fromRGB(25, 26, 34) },
        { Size = Vector3.new(14, 0.8, 11), Y = 1.2, Color = Color3.fromRGB(32, 34, 44) },
        { Size = Vector3.new(10, 0.8, 8),  Y = 2.0, Color = Color3.fromRGB(40, 42, 54) },
    }
    for _, s in ipairs(stepSizes) do
        local dais = Instance.new("Part")
        dais.Name = "AltarDaisStep"
        dais.Size = s.Size
        dais.CFrame = CFrame.new(0, s.Y, -130)
        dais.Anchored = true
        dais.Material = Enum.Material.Slate
        dais.Color = s.Color
        dais.TopSurface = Enum.SurfaceType.Smooth
        dais.Parent = folder
    end

    -- Magic Rune Circle on top of step 3
    local runeCircle = Instance.new("Part")
    runeCircle.Name = "AltarRuneCircle"
    runeCircle.Shape = Enum.PartType.Cylinder
    runeCircle.Size = Vector3.new(0.08, 7.6, 7.6)
    runeCircle.CFrame = CFrame.new(0, 2.45, -130) * CFrame.Angles(0, 0, math.rad(90))
    runeCircle.Anchored = true
    runeCircle.Material = Enum.Material.Neon
    runeCircle.Color = Color3.fromRGB(255, 215, 60)
    runeCircle.Transparency = 0.35
    runeCircle.CanCollide = false
    runeCircle.Parent = folder

    -- 4 Ancient Rune Pillars with Eternal Braziers
    local pillarPositions = {
        Vector3.new(-7.2, 4.2, -134.5),
        Vector3.new(7.2, 4.2, -134.5),
        Vector3.new(-7.2, 4.2, -125.5),
        Vector3.new(7.2, 4.2, -125.5),
    }
    for _, pPos in ipairs(pillarPositions) do
        local p = Instance.new("Part")
        p.Name = "AltarRunePillar"
        p.Size = Vector3.new(2.0, 6.0, 2.0)
        p.CFrame = CFrame.new(pPos)
        p.Anchored = true
        p.Material = Enum.Material.Cobblestone
        p.Color = Color3.fromRGB(45, 48, 60)
        p.Parent = folder

        local bowl = Instance.new("Part")
        bowl.Name = "BrazierBowl"
        bowl.Size = Vector3.new(2.4, 0.6, 2.4)
        bowl.CFrame = CFrame.new(pPos.X, 7.5, pPos.Z)
        bowl.Anchored = true
        bowl.Material = Enum.Material.SmoothPlastic
        bowl.Color = Color3.fromRGB(50, 42, 35)
        bowl.Parent = folder

        local flame = Instance.new("Part")
        flame.Name = "SacredFlame"
        flame.Size = Vector3.new(1.0, 1.0, 1.0)
        flame.CFrame = CFrame.new(pPos.X, 8.1, pPos.Z)
        flame.Anchored = true
        flame.Material = Enum.Material.Neon
        flame.Color = Color3.fromRGB(255, 150, 40)
        flame.CanCollide = false
        flame.Parent = folder

        local flameLight = Instance.new("PointLight")
        flameLight.Range = 12
        flameLight.Brightness = 0.5
        flameLight.Color = Color3.fromRGB(255, 170, 50)
        flameLight.Shadows = false
        flameLight.Parent = flame

        local pEmitter = Instance.new("ParticleEmitter")
        pEmitter.Rate = 5
        pEmitter.LightEmission = 0.6
        pEmitter.Lifetime = NumberRange.new(0.8, 1.4)
        pEmitter.Speed = NumberRange.new(1.0, 2.2)
        pEmitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.8),
            NumberSequenceKeypoint.new(1, 0.1),
        })
        pEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 180, 50), Color3.fromRGB(255, 80, 20))
        pEmitter.Parent = flame
    end

    -- Floating Rotating Golden Crystal in Center
    local crystal = Instance.new("Part")
    crystal.Name = "AscensionCrystal"
    crystal.Size = Vector3.new(2.4, 3.8, 2.4)
    crystal.CFrame = CFrame.new(0, 5.2, -130)
    crystal.Anchored = true
    crystal.Material = Enum.Material.Glass
    crystal.Color = Color3.fromRGB(255, 215, 50)
    crystal.Transparency = 0.15
    crystal.Parent = folder

    local crystalLight = Instance.new("PointLight")
    crystalLight.Range = 18
    crystalLight.Brightness = 0.8
    crystalLight.Color = Color3.fromRGB(255, 220, 120)
    crystalLight.Shadows = false
    crystalLight.Parent = crystal

    local crystalSparkles = Instance.new("ParticleEmitter")
    crystalSparkles.Rate = 6
    crystalSparkles.LightEmission = 0.3
    crystalSparkles.Lifetime = NumberRange.new(1.5, 2.5)
    crystalSparkles.Speed = NumberRange.new(0.5, 1.5)
    crystalSparkles.Color = ColorSequence.new(Color3.fromRGB(255, 230, 140))
    crystalSparkles.Parent = crystal

    -- Smooth floating crystal rotation
    task.spawn(function()
        while crystal and crystal.Parent do
            crystal.CFrame = crystal.CFrame * CFrame.Angles(0, math.rad(1), 0)
            task.wait(0.04)
        end
    end)

    local rebirthPrompt = Instance.new("ProximityPrompt")
    rebirthPrompt.Name = "RebirthPrompt"
    rebirthPrompt.ActionText = "Ascend / Rebirth"
    rebirthPrompt.ObjectText = "Ascension Altar"
    rebirthPrompt.MaxActivationDistance = 14
    rebirthPrompt.HoldDuration = 0
    rebirthPrompt.Parent = crystal

    rebirthPrompt.Triggered:Connect(function(player: Player)
        local openUIEvt = Remotes.GetEvent(Constants.REMOTE_EVENTS.OpenUIModal)
        openUIEvt:FireClient(player, "Rebirth")
    end)

    -- 6. West Wall: BOUNTY BOARD & ALCHEMIST COUNTER (at X = -46, Z from -70 to -110)
    -- 6A. Bounty Board at (-46, 0, -76)
    local boardModel = Instance.new("Model")
    boardModel.Name = "BountyBoardFacility"

    -- 2 Oak posts
    for _, zPost in ipairs({ -79.5, -72.5 }) do
        local post = Instance.new("Part")
        post.Name = "BountyPost"
        post.Size = Vector3.new(1.4, 10.0, 1.4)
        post.CFrame = CFrame.new(-46, 5.0, zPost)
        post.Anchored = true
        post.Material = Enum.Material.Wood
        post.Color = Color3.fromRGB(65, 42, 28)
        post.Parent = boardModel

        -- Hanging warm lantern
        local lantern = Instance.new("Part")
        lantern.Name = "HangingLantern"
        lantern.Size = Vector3.new(0.8, 1.0, 0.8)
        lantern.CFrame = CFrame.new(-45.0, 8.5, zPost)
        lantern.Anchored = true
        lantern.Material = Enum.Material.SmoothPlastic
        lantern.Color = Color3.fromRGB(35, 30, 25)
        lantern.Parent = boardModel

        local bulb = Instance.new("Part")
        bulb.Name = "LanternBulb"
        bulb.Size = Vector3.new(0.4, 0.5, 0.4)
        bulb.CFrame = CFrame.new(-45.0, 8.4, zPost)
        bulb.Anchored = true
        bulb.Material = Enum.Material.Neon
        bulb.Color = Color3.fromRGB(255, 215, 120)
        bulb.CanCollide = false
        bulb.Parent = boardModel

        local lanternLight = Instance.new("PointLight")
        lanternLight.Range = 12
        lanternLight.Brightness = 0.5
        lanternLight.Color = Color3.fromRGB(255, 210, 120)
        lanternLight.Shadows = false
        lanternLight.Parent = bulb
    end

    -- Shingled roof overhang
    local roofOverhang = Instance.new("Part")
    roofOverhang.Name = "BountyRoof"
    roofOverhang.Size = Vector3.new(3.8, 1.2, 8.4)
    roofOverhang.CFrame = CFrame.new(-46, 10.6, -76)
    roofOverhang.Anchored = true
    roofOverhang.Material = Enum.Material.Slate
    roofOverhang.Color = Color3.fromRGB(75, 40, 25)
    roofOverhang.Parent = boardModel

    -- Main Wooden Bounty Board
    local bountyBoard = Instance.new("Part")
    bountyBoard.Name = "BountyBoard"
    bountyBoard.Size = Vector3.new(1.0, 7.5, 7.0)
    bountyBoard.CFrame = CFrame.new(-46, 5.5, -76)
    bountyBoard.Anchored = true
    bountyBoard.Material = Enum.Material.WoodPlanks
    bountyBoard.Color = Color3.fromRGB(90, 60, 40)
    bountyBoard.Parent = boardModel

    -- Wanted Posters & Parchment Scrolls on East face (+X direction facing hall)
    local posters = {
        { Pos = Vector3.new(-45.45, 7.2, -77.5), Size = Vector3.new(0.08, 2.0, 1.5), Color = Color3.fromRGB(235, 220, 190) },
        { Pos = Vector3.new(-45.45, 7.0, -75.0), Size = Vector3.new(0.08, 2.2, 1.6), Color = Color3.fromRGB(225, 210, 180) },
        { Pos = Vector3.new(-45.45, 4.4, -77.8), Size = Vector3.new(0.08, 1.8, 1.4), Color = Color3.fromRGB(240, 230, 205) },
        { Pos = Vector3.new(-45.45, 4.2, -74.8), Size = Vector3.new(0.08, 2.1, 1.6), Color = Color3.fromRGB(230, 215, 185) },
        { Pos = Vector3.new(-45.45, 5.8, -73.2), Size = Vector3.new(0.08, 1.9, 1.3), Color = Color3.fromRGB(245, 235, 210) },
    }
    for i, pDef in ipairs(posters) do
        local poster = Instance.new("Part")
        poster.Name = "WantedPoster_" .. i
        poster.Size = pDef.Size
        poster.CFrame = CFrame.new(pDef.Pos)
        poster.Anchored = true
        poster.Material = Enum.Material.SmoothPlastic
        poster.Color = pDef.Color
        poster.CanCollide = false
        poster.Parent = boardModel

        -- Wanted ink portrait/stamp mark
        local stamp = Instance.new("Part")
        stamp.Name = "PosterStamp"
        stamp.Size = Vector3.new(0.09, pDef.Size.Y * 0.45, pDef.Size.Z * 0.5)
        stamp.CFrame = CFrame.new(pDef.Pos.X + 0.01, pDef.Pos.Y + 0.2, pDef.Pos.Z)
        stamp.Anchored = true
        stamp.Material = Enum.Material.SmoothPlastic
        stamp.Color = if i % 2 == 1 then Color3.fromRGB(130, 30, 30) else Color3.fromRGB(45, 40, 35)
        stamp.CanCollide = false
        stamp.Parent = boardModel
    end

    local bPrompt = Instance.new("ProximityPrompt")
    bPrompt.Name = "QuestPrompt"
    bPrompt.ActionText = "View Quests"
    bPrompt.ObjectText = "Bounty Board"
    bPrompt.MaxActivationDistance = 14
    bPrompt.HoldDuration = 0
    bPrompt.Parent = bountyBoard

    bPrompt.Triggered:Connect(function(player: Player)
        local openUIEvt = Remotes.GetEvent(Constants.REMOTE_EVENTS.OpenUIModal)
        openUIEvt:FireClient(player, "Quest")
    end)
    boardModel.Parent = folder

    -- 6B. Alchemist Counter at (-46, 0, -102)
    local alchemistModel = Instance.new("Model")
    alchemistModel.Name = "AlchemistFacility"

    -- L-Shaped Wooden Counter: Main counter along Z, L-branch towards west wall
    local counterMain = Instance.new("Part")
    counterMain.Name = "CounterMain"
    counterMain.Size = Vector3.new(3.0, 3.2, 10.0)
    counterMain.CFrame = CFrame.new(-44, 1.6, -102)
    counterMain.Anchored = true
    counterMain.Material = Enum.Material.WoodPlanks
    counterMain.Color = Color3.fromRGB(65, 42, 28)
    counterMain.Parent = alchemistModel

    local counterTopMain = Instance.new("Part")
    counterTopMain.Name = "CounterTopMain"
    counterTopMain.Size = Vector3.new(3.4, 0.4, 10.4)
    counterTopMain.CFrame = CFrame.new(-44, 3.3, -102)
    counterTopMain.Anchored = true
    counterTopMain.Material = Enum.Material.WoodPlanks
    counterTopMain.Color = Color3.fromRGB(85, 55, 36)
    counterTopMain.Parent = alchemistModel

    local counterBranch = Instance.new("Part")
    counterBranch.Name = "CounterBranch"
    counterBranch.Size = Vector3.new(7.0, 3.2, 3.0)
    counterBranch.CFrame = CFrame.new(-49, 1.6, -106.5)
    counterBranch.Anchored = true
    counterBranch.Material = Enum.Material.WoodPlanks
    counterBranch.Color = Color3.fromRGB(65, 42, 28)
    counterBranch.Parent = alchemistModel

    local counterTopBranch = Instance.new("Part")
    counterTopBranch.Name = "CounterTopBranch"
    counterTopBranch.Size = Vector3.new(7.4, 0.4, 3.4)
    counterTopBranch.CFrame = CFrame.new(-49, 3.3, -106.5)
    counterTopBranch.Anchored = true
    counterTopBranch.Material = Enum.Material.WoodPlanks
    counterTopBranch.Color = Color3.fromRGB(85, 55, 36)
    counterTopBranch.Parent = alchemistModel

    -- 3-Tier Shelving Cabinet against West Wall at (-52.5, 5.0, -102)
    local cabinet = Instance.new("Part")
    cabinet.Name = "PotionCabinet"
    cabinet.Size = Vector3.new(1.8, 10.0, 11.0)
    cabinet.CFrame = CFrame.new(-52.5, 5.0, -102)
    cabinet.Anchored = true
    cabinet.Material = Enum.Material.WoodPlanks
    cabinet.Color = Color3.fromRGB(50, 32, 20)
    cabinet.Parent = alchemistModel

    -- Shelves and Potion Bottles
    local potionColors = {
        Color3.fromRGB(240, 50, 60),  -- Health (Red)
        Color3.fromRGB(50, 140, 255), -- Mana (Blue)
        Color3.fromRGB(50, 230, 90),  -- Stamina (Green)
        Color3.fromRGB(180, 60, 240), -- Void (Purple)
        Color3.fromRGB(255, 215, 50), -- Ambrosia (Gold)
    }

    local shelfHeights = { 3.0, 6.0, 9.0 }
    for sIdx, sY in ipairs(shelfHeights) do
        local shelfPlank = Instance.new("Part")
        shelfPlank.Name = "ShelfPlank_" .. sIdx
        shelfPlank.Size = Vector3.new(2.2, 0.3, 11.2)
        shelfPlank.CFrame = CFrame.new(-52.3, sY, -102)
        shelfPlank.Anchored = true
        shelfPlank.Material = Enum.Material.WoodPlanks
        shelfPlank.Color = Color3.fromRGB(75, 48, 30)
        shelfPlank.Parent = alchemistModel

        -- Place 6 potion bottles per shelf
        for b = 1, 6 do
            local bColor = potionColors[((sIdx * 3 + b) % #potionColors) + 1]
            local bZ = -106.5 + (b * 1.3)
            local bottle = Instance.new("Part")
            bottle.Name = "PotionBottle"
            bottle.Shape = Enum.PartType.Cylinder
            bottle.Size = Vector3.new(0.8, 0.55, 0.55)
            bottle.CFrame = CFrame.new(-51.8, sY + 0.55, bZ) * CFrame.Angles(0, 0, math.rad(90))
            bottle.Anchored = true
            bottle.Material = Enum.Material.Glass
            bottle.Color = bColor
            bottle.Transparency = 0.2
            bottle.CanCollide = false
            bottle.Parent = alchemistModel
        end
    end

    -- Bubbling Alchemy Cauldron at (-44, 1.4, -94)
    local cauldron = Instance.new("Part")
    cauldron.Name = "AlchemyCauldron"
    cauldron.Size = Vector3.new(3.2, 2.6, 3.2)
    cauldron.CFrame = CFrame.new(-44, 1.4, -94)
    cauldron.Anchored = true
    cauldron.Material = Enum.Material.Metal
    cauldron.Color = Color3.fromRGB(35, 36, 42)
    cauldron.Parent = alchemistModel

    local liquid = Instance.new("Part")
    liquid.Name = "CauldronLiquid"
    liquid.Shape = Enum.PartType.Cylinder
    liquid.Size = Vector3.new(0.2, 2.8, 2.8)
    liquid.CFrame = CFrame.new(-44, 2.6, -94) * CFrame.Angles(0, 0, math.rad(90))
    liquid.Anchored = true
    liquid.Material = Enum.Material.Neon
    liquid.Color = Color3.fromRGB(160, 60, 240)
    liquid.Transparency = 0.25
    liquid.CanCollide = false
    liquid.Parent = alchemistModel

    local cSmoke = Instance.new("ParticleEmitter")
    cSmoke.Rate = 5
    cSmoke.Speed = NumberRange.new(1.0, 2.0)
    cSmoke.Lifetime = NumberRange.new(1.8, 2.5)
    cSmoke.Color = ColorSequence.new(Color3.fromRGB(190, 90, 255), Color3.fromRGB(110, 50, 180))
    cSmoke.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.6),
        NumberSequenceKeypoint.new(1, 1.6),
    })
    cSmoke.Transparency = NumberSequence.new(0.4, 1.0)
    cSmoke.Parent = liquid

    local cLight = Instance.new("PointLight")
    cLight.Range = 8
    cLight.Brightness = 0.4
    cLight.Color = Color3.fromRGB(180, 80, 255)
    cLight.Shadows = false
    cLight.Parent = liquid

    local shopPrompt = Instance.new("ProximityPrompt")
    shopPrompt.Name = "ShopPrompt"
    shopPrompt.ActionText = "Open Shop"
    shopPrompt.ObjectText = "Alchemist Counter"
    shopPrompt.MaxActivationDistance = 14
    shopPrompt.HoldDuration = 0
    shopPrompt.Parent = counterTopMain

    shopPrompt.Triggered:Connect(function(player: Player)
        local openUIEvt = Remotes.GetEvent(Constants.REMOTE_EVENTS.OpenUIModal)
        openUIEvt:FireClient(player, "Shop")
    end)
    alchemistModel.Parent = folder

    -- 7. North-East: SOLID GRAND STAIRCASE TO UPPER MEZZANINE (X = 16 to 40, Z = -128.5 to -139.5)
    local stairsModel = Instance.new("Model")
    stairsModel.Name = "UpperMezzanineStairs"

    local totalSteps = 18
    local stairStartX = 16.0
    local stairEndX = 40.0
    local stairSpanX = stairEndX - stairStartX -- 24.0 studs
    local stepWidth = stairSpanX / totalSteps  -- 1.3333 studs per step in X
    local stepHeight = 18.0 / totalSteps      -- 1.0 stud rise per step in Y
    local stepZ = -134.0                      -- Centered between Z = -128.5 and Z = -139.5
    local stepDepth = 11.0                    -- 11.0 studs wide staircase in Z

    for i = 1, totalSteps do
        local stepX = stairStartX + (i - 0.5) * stepWidth
        local foundationHeight = i * stepHeight -- Solid block from ground Y = 0 up to Y = i

        -- Solid Stone Foundation Step (from ground up to Y = i)
        local stoneBase = Instance.new("Part")
        stoneBase.Name = "StairStoneBase_" .. i
        stoneBase.Size = Vector3.new(stepWidth + 0.05, foundationHeight, stepDepth)
        stoneBase.CFrame = CFrame.new(stepX, foundationHeight / 2, stepZ)
        stoneBase.Anchored = true
        stoneBase.Material = Enum.Material.Slate
        stoneBase.Color = Color3.fromRGB(48, 50, 60)
        stoneBase.TopSurface = Enum.SurfaceType.Smooth
        stoneBase.Parent = stairsModel

        -- Oak Wood Tread on Top (Thickness 0.4 studs, from Y = i to Y = i + 0.4)
        local oakTread = Instance.new("Part")
        oakTread.Name = "StairOakTread_" .. i
        oakTread.Size = Vector3.new(stepWidth + 0.05, 0.4, stepDepth)
        oakTread.CFrame = CFrame.new(stepX, foundationHeight + 0.2, stepZ)
        oakTread.Anchored = true
        oakTread.Material = Enum.Material.WoodPlanks
        oakTread.Color = Color3.fromRGB(75, 48, 30)
        oakTread.TopSurface = Enum.SurfaceType.Smooth
        oakTread.Parent = stairsModel

        -- Gold Edge Trim on outer hall edge (at Z = -128.5)
        local goldTrim = Instance.new("Part")
        goldTrim.Name = "StairGoldTrim_" .. i
        goldTrim.Size = Vector3.new(stepWidth + 0.05, 0.42, 0.25)
        goldTrim.CFrame = CFrame.new(stepX, foundationHeight + 0.2, -128.4)
        goldTrim.Anchored = true
        goldTrim.Material = Enum.Material.SmoothPlastic
        goldTrim.Color = Color3.fromRGB(240, 195, 50)
        goldTrim.Parent = stairsModel

        -- Stepped Outer Baluster Post (at Z = -128.5, height 3.2 studs from step surface)
        local post = Instance.new("Part")
        post.Name = "StairBalusterPost_" .. i
        post.Size = Vector3.new(0.35, 3.2, 0.35)
        post.CFrame = CFrame.new(stepX, foundationHeight + 0.4 + 1.6, -128.5)
        post.Anchored = true
        post.Material = Enum.Material.WoodPlanks
        post.Color = Color3.fromRGB(55, 38, 25)
        post.Parent = stairsModel

        -- Golden Finial Sphere on top of baluster post
        local finial = Instance.new("Part")
        finial.Name = "StairBalusterFinial_" .. i
        finial.Shape = Enum.PartType.Ball
        finial.Size = Vector3.new(0.55, 0.55, 0.55)
        finial.CFrame = CFrame.new(stepX, foundationHeight + 0.4 + 3.2 + 0.25, -128.5)
        finial.Anchored = true
        finial.Material = Enum.Material.SmoothPlastic
        finial.Color = Color3.fromRGB(245, 205, 50)
        finial.Parent = stairsModel
    end

    -- Directional sign at foot of stairs: shifted to X = 14, Z = -125.5 facing South (+Z)
    local signPost = Instance.new("Part")
    signPost.Name = "StairsSignPost"
    signPost.Size = Vector3.new(0.6, 4.5, 0.6)
    signPost.CFrame = CFrame.new(14, 2.25, -125.5)
    signPost.Anchored = true
    signPost.Material = Enum.Material.Wood
    signPost.Color = Color3.fromRGB(55, 38, 26)
    signPost.Parent = stairsModel

    -- Sign board positioned 0.4 studs forward (Z = -125.1) so the post is completely behind the board
    local signBoard = Instance.new("Part")
    signBoard.Name = "StairsSignBoard"
    signBoard.Size = Vector3.new(4.2, 1.4, 0.3)
    signBoard.CFrame = CFrame.new(14, 3.8, -125.1) * CFrame.Angles(0, math.rad(180), 0)
    signBoard.Anchored = true
    signBoard.Material = Enum.Material.WoodPlanks
    signBoard.Color = Color3.fromRGB(65, 45, 30)
    signBoard.Parent = stairsModel

    local stairSignGui = Instance.new("SurfaceGui")
    stairSignGui.Face = Enum.NormalId.Front
    stairSignGui.CanvasSize = Vector2.new(450, 150)
    stairSignGui.LightInfluence = 0.2
    stairSignGui.Parent = signBoard

    local stairSignText = Instance.new("TextLabel")
    stairSignText.Size = UDim2.new(1, 0, 1, 0)
    stairSignText.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
    stairSignText.Font = Enum.Font.GothamBold
    stairSignText.Text = "⬆️ STAIRS TO UPPER ROOMS"
    stairSignText.TextColor3 = Color3.fromRGB(255, 215, 60)
    stairSignText.TextSize = 22
    stairSignText.Parent = stairSignGui

    stairsModel.Parent = folder

    -- 8. UPPER MEZZANINE CORRIDOR (Y = 18, X = 16 to 54.8, Z = -50.2 to -139.8)
    local mezzanineModel = Instance.new("Model")
    mezzanineModel.Name = "UpperMezzanineCorridor"

    -- Main Mezzanine Floor Slab (X = 16 to 54.8: Width 38.8, Z = -50.2 to -128: Length 77.8, Y = 17.5)
    -- Flush against East Wall (X = 54.8) and Front South Wall (Z = -50.2)
    local mezzFloor = Instance.new("Part")
    mezzFloor.Name = "MezzanineFloor"
    mezzFloor.Size = Vector3.new(38.8, 1.0, 77.8)
    mezzFloor.CFrame = CFrame.new(35.4, 17.5, -89.1)
    mezzFloor.Anchored = true
    mezzFloor.Material = Enum.Material.WoodPlanks
    mezzFloor.Color = Color3.fromRGB(68, 48, 32)
    mezzFloor.TopSurface = Enum.SurfaceType.Smooth
    mezzFloor.Parent = mezzanineModel

    -- North Landing Platform (X = 40 to 54.8: Width 14.8, Z = -128 to -139.8: Length 11.8, Y = 17.5)
    -- Meets Step 18 at X = 40, East Wall at X = 54.8, Back North Wall at Z = -139.8: 100% FLUSH!
    local landingPlatform = Instance.new("Part")
    landingPlatform.Name = "StairLandingPlatform"
    landingPlatform.Size = Vector3.new(14.8, 1.0, 11.8)
    landingPlatform.CFrame = CFrame.new(47.4, 17.5, -133.9)
    landingPlatform.Anchored = true
    landingPlatform.Material = Enum.Material.WoodPlanks
    landingPlatform.Color = Color3.fromRGB(68, 48, 32)
    landingPlatform.TopSurface = Enum.SurfaceType.Smooth
    landingPlatform.Parent = mezzanineModel

    -- Under-Floor Support Pillars at X = 16.5 from Y = 0 to 18 (Z = -60, -82, -104, -126)
    for _, zPill in ipairs({ -60, -82, -104, -126 }) do
        local p = Instance.new("Part")
        p.Name = "MezzanineSupportPillar"
        p.Size = Vector3.new(2.2, 17.0, 2.2)
        p.CFrame = CFrame.new(16.5, 8.5, zPill)
        p.Anchored = true
        p.Material = Enum.Material.Cobblestone
        p.Color = Color3.fromRGB(55, 58, 68)
        p.Parent = mezzanineModel
    end

    -- Support Beam along X = 16.5 from Z = -50.2 to Z = -128
    local mezzBeam = Instance.new("Part")
    mezzBeam.Name = "MezzanineBeam"
    mezzBeam.Size = Vector3.new(2.4, 2.0, 77.8)
    mezzBeam.CFrame = CFrame.new(16.5, 16.5, -89.1)
    mezzBeam.Anchored = true
    mezzBeam.Material = Enum.Material.WoodPlanks
    mezzBeam.Color = Color3.fromRGB(55, 38, 25)
    mezzBeam.Parent = mezzanineModel

    -- Inner Balustrade / Railing along X = 16 overlooking the Great Hall (Z = -50.2 to -128)
    local topRail = Instance.new("Part")
    topRail.Name = "BalustradeTopRail"
    topRail.Size = Vector3.new(0.8, 0.5, 77.8)
    topRail.CFrame = CFrame.new(16, 21.3, -89.1)
    topRail.Anchored = true
    topRail.Material = Enum.Material.WoodPlanks
    topRail.Color = Color3.fromRGB(80, 52, 35)
    topRail.Parent = mezzanineModel

    local baseRail = Instance.new("Part")
    baseRail.Name = "BalustradeBaseRail"
    baseRail.Size = Vector3.new(0.8, 0.5, 77.8)
    baseRail.CFrame = CFrame.new(16, 18.25, -89.1)
    baseRail.Anchored = true
    baseRail.Material = Enum.Material.WoodPlanks
    baseRail.Color = Color3.fromRGB(60, 40, 26)
    baseRail.Parent = mezzanineModel

    -- Baluster posts along X = 16 railing every 5 studs
    for zB = -128, -50.2, 5.0 do
        local baluster = Instance.new("Part")
        baluster.Name = "BalustradePost"
        baluster.Size = Vector3.new(0.4, 2.6, 0.4)
        baluster.CFrame = CFrame.new(16, 19.8, zB)
        baluster.Anchored = true
        baluster.Material = Enum.Material.WoodPlanks
        baluster.Color = Color3.fromRGB(65, 42, 28)
        baluster.Parent = mezzanineModel
    end

    -- Safety Balustrade along stairwell edge at Z = -128 (X = 16 to 40, leaves X = 40..54.8 open for smooth entry)
    local stairWellRail = Instance.new("Part")
    stairWellRail.Name = "StairWellTopRail"
    stairWellRail.Size = Vector3.new(24, 0.5, 0.8)
    stairWellRail.CFrame = CFrame.new(28, 21.3, -128)
    stairWellRail.Anchored = true
    stairWellRail.Material = Enum.Material.WoodPlanks
    stairWellRail.Color = Color3.fromRGB(80, 52, 35)
    stairWellRail.Parent = mezzanineModel

    local stairWellBase = Instance.new("Part")
    stairWellBase.Name = "StairWellBaseRail"
    stairWellBase.Size = Vector3.new(24, 0.5, 0.8)
    stairWellBase.CFrame = CFrame.new(28, 18.25, -128)
    stairWellBase.Anchored = true
    stairWellBase.Material = Enum.Material.WoodPlanks
    stairWellBase.Color = Color3.fromRGB(60, 40, 26)
    stairWellBase.Parent = mezzanineModel

    for xB = 16, 38.5, 4.8 do
        local bPost = Instance.new("Part")
        bPost.Name = "StairWellBaluster"
        bPost.Size = Vector3.new(0.4, 2.6, 0.4)
        bPost.CFrame = CFrame.new(xB, 19.8, -128)
        bPost.Anchored = true
        bPost.Material = Enum.Material.WoodPlanks
        bPost.Color = Color3.fromRGB(65, 42, 28)
        bPost.Parent = mezzanineModel
    end
    mezzanineModel.Parent = folder

    -- 9. 6 TAVERN-STYLE DUNGEON PARTY ROOMS (Rooms 1..3 on Floor 1, Rooms 4..6 on Mezzanine)
    for _, room in ipairs(customPartyRooms) do
        local podModel = Instance.new("Model")
        podModel.Name = "PartyRoom_" .. room.RoomId

        -- Single thin translucent disc under party room table & chairs (Diameter 14 studs, SmoothPlastic, Transparency 0.84)
        local pad = Instance.new("Part")
        pad.Name = "PadFloor"
        pad.Shape = Enum.PartType.Cylinder
        pad.Size = Vector3.new(0.2, 14, 14)
        pad.CFrame = CFrame.new(room.Position.X, room.Position.Y + 0.1, room.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
        pad.Anchored = true
        pad.Material = Enum.Material.SmoothPlastic
        pad.Color = Color3.fromRGB(140, 150, 165)
        pad.Transparency = 0.84
        pad.TopSurface = Enum.SurfaceType.Smooth
        pad.CanCollide = false
        pad.Parent = podModel
        room.PadFloor = pad
        room.PadRing = nil

        -- Center Oak Tavern Table
        local tablePedestal = Instance.new("Part")
        tablePedestal.Name = "TablePedestal"
        tablePedestal.Size = Vector3.new(1.6, 2.6, 1.6)
        tablePedestal.CFrame = CFrame.new(room.Position.X, room.Position.Y + 1.3, room.Position.Z)
        tablePedestal.Anchored = true
        tablePedestal.Material = Enum.Material.Wood
        tablePedestal.Color = Color3.fromRGB(60, 40, 26)
        tablePedestal.Parent = podModel

        local tableTop = Instance.new("Part")
        tableTop.Name = "TableTop"
        tableTop.Shape = Enum.PartType.Cylinder
        tableTop.Size = Vector3.new(0.4, 4.6, 4.6)
        tableTop.CFrame = CFrame.new(room.Position.X, room.Position.Y + 2.7, room.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
        tableTop.Anchored = true
        tableTop.Material = Enum.Material.WoodPlanks
        tableTop.Color = Color3.fromRGB(85, 55, 36)
        tableTop.Parent = podModel
        room.TableTop = tableTop

        -- 4 Wooden Chairs around table (radius 3.2 studs): South, West, East, North
        local chairConfigs = {
            { Offset = Vector3.new(0, 0, 3.2),  BackOffset = Vector3.new(0, 0, 0.75),  BackSize = Vector3.new(1.6, 1.6, 0.3) }, -- South chair
            { Offset = Vector3.new(-3.2, 0, 0), BackOffset = Vector3.new(-0.75, 0, 0), BackSize = Vector3.new(0.3, 1.6, 1.6) }, -- West chair
            { Offset = Vector3.new(3.2, 0, 0),  BackOffset = Vector3.new(0.75, 0, 0),  BackSize = Vector3.new(0.3, 1.6, 1.6) }, -- East chair
            { Offset = Vector3.new(0, 0, -3.2), BackOffset = Vector3.new(0, 0, -0.75), BackSize = Vector3.new(1.6, 1.6, 0.3) }, -- North chair
        }

        for cIdx, cCfg in ipairs(chairConfigs) do
            local chairSeatPos = room.Position + cCfg.Offset + Vector3.new(0, 1.0, 0)
            local seat = Instance.new("Part")
            seat.Name = "TavernChairSeat_" .. cIdx
            seat.Size = Vector3.new(1.6, 0.3, 1.6)
            seat.CFrame = CFrame.new(chairSeatPos)
            seat.Anchored = true
            seat.Material = Enum.Material.WoodPlanks
            seat.Color = Color3.fromRGB(75, 48, 30)
            seat.Parent = podModel

            -- Backrest facing into table center
            local backrest = Instance.new("Part")
            backrest.Name = "TavernChairBack_" .. cIdx
            backrest.Size = cCfg.BackSize
            backrest.CFrame = CFrame.new(chairSeatPos + cCfg.BackOffset + Vector3.new(0, 0.9, 0))
            backrest.Anchored = true
            backrest.Material = Enum.Material.WoodPlanks
            backrest.Color = Color3.fromRGB(65, 40, 25)
            backrest.Parent = podModel

            -- 4 Chair legs
            for _, legX in ipairs({ -0.6, 0.6 }) do
                for _, legZ in ipairs({ -0.6, 0.6 }) do
                    local leg = Instance.new("Part")
                    leg.Name = "ChairLeg"
                    leg.Size = Vector3.new(0.3, 0.9, 0.3)
                    leg.CFrame = CFrame.new(chairSeatPos.X + legX, room.Position.Y + 0.45, chairSeatPos.Z + legZ)
                    leg.Anchored = true
                    leg.Material = Enum.Material.Wood
                    leg.Color = Color3.fromRGB(55, 35, 22)
                    leg.Parent = podModel
                end
            end
        end

        -- 4 Wooden Tankards / Mugs on tabletop
        local mugOffsets = {
            Vector3.new(-0.9, 0, -0.7),
            Vector3.new(0.8, 0, -0.8),
            Vector3.new(-0.7, 0, 0.9),
            Vector3.new(0.9, 0, 0.7),
        }
        for mIdx, mOff in ipairs(mugOffsets) do
            local mugPos = room.Position + mOff + Vector3.new(0, 3.1, 0)
            local mug = Instance.new("Part")
            mug.Name = "WoodenTankard_" .. mIdx
            mug.Shape = Enum.PartType.Cylinder
            mug.Size = Vector3.new(0.65, 0.55, 0.55)
            mug.CFrame = CFrame.new(mugPos) * CFrame.Angles(0, 0, math.rad(90))
            mug.Anchored = true
            mug.Material = Enum.Material.Wood
            mug.Color = Color3.fromRGB(80, 52, 34)
            mug.CanCollide = false
            mug.Parent = podModel

            -- White foam / golden brew on top
            local foam = Instance.new("Part")
            foam.Name = "TankardFoam"
            foam.Shape = Enum.PartType.Cylinder
            foam.Size = Vector3.new(0.12, 0.52, 0.52)
            foam.CFrame = CFrame.new(mugPos.X, mugPos.Y + 0.34, mugPos.Z) * CFrame.Angles(0, 0, math.rad(90))
            foam.Anchored = true
            foam.Material = Enum.Material.SmoothPlastic
            foam.Color = Color3.fromRGB(255, 250, 220)
            foam.CanCollide = false
            foam.Parent = podModel
        end

        -- Overhead Billboard: elevated neatly above table to StudsOffset = (0, 6.5, 0)
        local bb = Instance.new("BillboardGui")
        bb.Name = "PartyStatusGui"
        bb.Size = UDim2.new(0, 280, 0, 85)
        bb.StudsOffset = Vector3.new(0, 6.5, 0)
        bb.AlwaysOnTop = false
        bb.MaxDistance = 32
        bb.Adornee = tableTop
        bb.Parent = podModel

        local tLabel = Instance.new("TextLabel")
        tLabel.Size = UDim2.new(1, 0, 0, 26)
        tLabel.BackgroundTransparency = 1
        tLabel.Font = Enum.Font.GothamBold
        tLabel.Text = string.format("✨ PARTY ROOM #%d [OPEN]", room.RoomId)
        tLabel.TextColor3 = EMPTY_ROOM_COLOR
        tLabel.TextSize = 14
        tLabel.Parent = bb
        room.TitleLabel = tLabel

        local cLabel = Instance.new("TextLabel")
        cLabel.Size = UDim2.new(1, 0, 0, 24)
        cLabel.Position = UDim2.new(0, 0, 0, 26)
        cLabel.BackgroundTransparency = 1
        cLabel.Font = Enum.Font.GothamBold
        cLabel.Text = "Players: 0 / 4"
        cLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
        cLabel.TextSize = 13
        cLabel.Parent = bb
        room.CountLabel = cLabel

        local sLabel = Instance.new("TextLabel")
        sLabel.Size = UDim2.new(1, 0, 0, 24)
        sLabel.Position = UDim2.new(0, 0, 0, 50)
        sLabel.BackgroundTransparency = 1
        sLabel.Font = Enum.Font.GothamBold
        sLabel.Text = "Step to Party Table to Create Room"
        sLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
        sLabel.TextSize = 12
        sLabel.Parent = bb
        room.StatusLabel = sLabel

        podModel.Parent = folder
    end
end

--------------------------------------------------------------------------------
-- 9. 3D MONUMENT LEADERBOARDS (FLANKING GUILD HALL ENTRANCE FACADE)
--------------------------------------------------------------------------------

local cpBoardList: Frame? = nil
local rollsBoardList: Frame? = nil

local function buildMonumentLeaderboards()
    local existingBoards = Workspace:FindFirstChild("LobbyLeaderboards")
    if existingBoards then
        existingBoards:Destroy()
    end

    local folder = Instance.new("Folder")
    folder.Name = "LobbyLeaderboards"
    folder.Parent = Workspace

    local function createBoard(name: string, position: Vector3, lookTarget: Vector3, titleText: string, subtitleText: string, headerCols: { string }): (Model, Frame)
        local boardModel = Instance.new("Model")
        boardModel.Name = name

        local pedestal = Instance.new("Part")
        pedestal.Name = "Pedestal"
        pedestal.Size = Vector3.new(16, 2.0, 3.5)
        pedestal.CFrame = CFrame.lookAt(Vector3.new(position.X, 1.0, position.Z), Vector3.new(lookTarget.X, 1.0, lookTarget.Z))
        pedestal.Anchored = true
        pedestal.Material = Enum.Material.Cobblestone
        pedestal.Color = Color3.fromRGB(36, 42, 58)
        pedestal.Parent = boardModel

        local tablet = Instance.new("Part")
        tablet.Name = "Tablet"
        tablet.Size = Vector3.new(15.5, 13.5, 1.6)
        tablet.CFrame = CFrame.lookAt(position, lookTarget)
        tablet.Anchored = true
        tablet.Material = Enum.Material.SmoothPlastic
        tablet.Color = Color3.fromRGB(15, 17, 26)
        tablet.Parent = boardModel

        local trim = Instance.new("Part")
        trim.Name = "GoldBorder"
        trim.Size = Vector3.new(15.9, 13.9, 1.0)
        trim.CFrame = tablet.CFrame
        trim.Anchored = true
        trim.Material = Enum.Material.SmoothPlastic
        trim.Color = Color3.fromRGB(240, 195, 50)
        trim.CanCollide = false
        trim.Parent = boardModel

        local surfaceGui = Instance.new("SurfaceGui")
        surfaceGui.Name = "LeaderboardGui"
        surfaceGui.Face = Enum.NormalId.Front
        surfaceGui.CanvasSize = Vector2.new(900, 750)
        surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
        surfaceGui.LightInfluence = 0.05
        surfaceGui.Parent = tablet

        local root = Instance.new("Frame")
        root.Name = "Root"
        root.Size = UDim2.new(1, 0, 1, 0)
        root.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
        root.BorderSizePixel = 0
        root.Parent = surfaceGui

        local rootCorner = Instance.new("UICorner")
        rootCorner.CornerRadius = UDim.new(0, 16)
        rootCorner.Parent = root

        local rootStroke = Instance.new("UIStroke")
        rootStroke.Color = Color3.fromRGB(255, 204, 50)
        rootStroke.Thickness = 4
        rootStroke.Parent = root

        -- Header
        local headerFrame = Instance.new("Frame")
        headerFrame.Name = "Header"
        headerFrame.Size = UDim2.new(1, 0, 0, 100)
        headerFrame.BackgroundColor3 = Color3.fromRGB(24, 28, 44)
        headerFrame.BorderSizePixel = 0
        headerFrame.Parent = root

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, 0, 0, 48)
        titleLabel.Position = UDim2.new(0, 0, 0, 14)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.Text = titleText
        titleLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
        titleLabel.TextSize = 28
        titleLabel.Parent = headerFrame

        local subLabel = Instance.new("TextLabel")
        subLabel.Size = UDim2.new(1, 0, 0, 24)
        subLabel.Position = UDim2.new(0, 0, 0, 62)
        subLabel.BackgroundTransparency = 1
        subLabel.Font = Enum.Font.GothamMedium
        subLabel.Text = subtitleText
        subLabel.TextColor3 = Color3.fromRGB(150, 160, 190)
        subLabel.TextSize = 15
        subLabel.Parent = headerFrame

        -- Columns Bar
        local colBar = Instance.new("Frame")
        colBar.Size = UDim2.new(1, -40, 0, 36)
        colBar.Position = UDim2.new(0, 20, 0, 108)
        colBar.BackgroundColor3 = Color3.fromRGB(32, 36, 56)
        colBar.BorderSizePixel = 0
        colBar.Parent = root

        local colCorner = Instance.new("UICorner")
        colCorner.CornerRadius = UDim.new(0, 8)
        colCorner.Parent = colBar

        local colWidths = { 0.15, 0.35, 0.25, 0.25 }
        local xOffset = 0
        for i, colName in ipairs(headerCols) do
            local w = colWidths[i] or 0.25
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(w, 0, 1, 0)
            lbl.Position = UDim2.new(xOffset, 0, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamBold
            lbl.Text = colName
            lbl.TextColor3 = Color3.fromRGB(200, 210, 240)
            lbl.TextSize = 16
            lbl.Parent = colBar
            xOffset += w
        end

        local listContainer = Instance.new("Frame")
        listContainer.Name = "ListContainer"
        listContainer.Size = UDim2.new(1, -40, 1, -160)
        listContainer.Position = UDim2.new(0, 20, 0, 152)
        listContainer.BackgroundTransparency = 1
        listContainer.Parent = root

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 8)
        layout.Parent = listContainer

        boardModel.Parent = folder
        return boardModel, listContainer
    end

    -- Mounted side-by-side on the North Wall (Left of Altar) facing South into the Great Hall
    -- Board 1: TOP COMBAT POWER at X = -38, Z = -137, facing South (+Z)
    local _, cpList = createBoard(
        "CombatPowerBoard",
        Vector3.new(-38, 9.5, -137),
        Vector3.new(-38, 9.5, -136),
        "🏆 TOP COMBAT POWER",
        "Server Strongest Champions • Refreshes every 5s",
        { "RANK", "PLAYER", "LEVEL", "COMBAT POWER" }
    )
    cpBoardList = cpList

    -- Board 2: TOP TREASURE ROLLERS at X = -20, Z = -137, facing South (+Z)
    local _, rollsList = createBoard(
        "TreasureRollersBoard",
        Vector3.new(-20, 9.5, -137),
        Vector3.new(-20, 9.5, -136),
        "🎲 TOP TREASURE ROLLERS",
        "Master Vault Openers • Refreshes every 5s",
        { "RANK", "PLAYER", "TOTAL ROLLS", "HIGHEST TIER" }
    )
    rollsBoardList = rollsList
end

local function renderLeaderboardRow(parent: Frame, order: number, rankStr: string, rankColor: Color3, nameStr: string, stat1Str: string, stat2Str: string, stat2Color: Color3?)
    local row = Instance.new("Frame")
    row.Name = string.format("Row_%d", order)
    row.Size = UDim2.new(1, 0, 0, 52)
    row.LayoutOrder = order
    row.BackgroundColor3 = if order % 2 == 1 then Color3.fromRGB(22, 26, 40) else Color3.fromRGB(28, 33, 50)
    row.BorderSizePixel = 0
    row.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = row

    local colWidths = { 0.15, 0.35, 0.25, 0.25 }

    local rLbl = Instance.new("TextLabel")
    rLbl.Size = UDim2.new(colWidths[1], 0, 1, 0)
    rLbl.Position = UDim2.new(0, 0, 0, 0)
    rLbl.BackgroundTransparency = 1
    rLbl.Font = Enum.Font.GothamBold
    rLbl.Text = rankStr
    rLbl.TextColor3 = rankColor
    rLbl.TextSize = 18
    rLbl.Parent = row

    local nLbl = Instance.new("TextLabel")
    nLbl.Size = UDim2.new(colWidths[2], 0, 1, 0)
    nLbl.Position = UDim2.new(colWidths[1], 0, 0, 0)
    nLbl.BackgroundTransparency = 1
    nLbl.Font = Enum.Font.GothamMedium
    nLbl.Text = nameStr
    nLbl.TextColor3 = Color3.fromRGB(240, 244, 255)
    nLbl.TextSize = 16
    nLbl.TextXAlignment = Enum.TextXAlignment.Center
    nLbl.Parent = row

    local s1Lbl = Instance.new("TextLabel")
    s1Lbl.Size = UDim2.new(colWidths[3], 0, 1, 0)
    s1Lbl.Position = UDim2.new(colWidths[1] + colWidths[2], 0, 0, 0)
    s1Lbl.BackgroundTransparency = 1
    s1Lbl.Font = Enum.Font.GothamMedium
    s1Lbl.Text = stat1Str
    s1Lbl.TextColor3 = Color3.fromRGB(180, 190, 220)
    s1Lbl.TextSize = 16
    s1Lbl.Parent = row

    local s2Lbl = Instance.new("TextLabel")
    s2Lbl.Size = UDim2.new(colWidths[4], 0, 1, 0)
    s2Lbl.Position = UDim2.new(colWidths[1] + colWidths[2] + colWidths[3], 0, 0, 0)
    s2Lbl.BackgroundTransparency = 1
    s2Lbl.Font = Enum.Font.GothamBold
    s2Lbl.Text = stat2Str
    s2Lbl.TextColor3 = stat2Color or Color3.fromRGB(255, 205, 50)
    s2Lbl.TextSize = 16
    s2Lbl.Parent = row
end

local function refreshServerLeaderboards()
    if not cpBoardList or not rollsBoardList then return end

    local DataService = getDataService()
    if not DataService then return end

    local allPlayers = Players:GetPlayers()
    if #allPlayers == 0 then return end

    local cpEntries = {}
    local rollEntries = {}

    for _, p in ipairs(allPlayers) do
        local data = DataService.GetData(p)
        if data then
            local stats = DataService.GetTotalStats(p)
            local cp = math.round((stats.MaxHP * 1.0) + (stats.Damage * 3.5) + (stats.CritChance * 600) + (stats.LuckBonus * 80))
            table.insert(cpEntries, { Player = p, Level = data.Level, CP = cp })

            local highestRank = 1
            local highestTierName = "Common"
            for _, item in pairs(data.Inventory) do
                local def = ItemConfig.Get(item.ItemId)
                if def then
                    local rCfg = RarityConfig.Get(def.Rarity)
                    if rCfg and rCfg.Rank > highestRank then
                        highestRank = rCfg.Rank
                        highestTierName = def.Rarity
                    end
                end
            end

            table.insert(rollEntries, { Player = p, Rolls = data.RollCount or 0, HighestTier = highestTierName })
        end
    end

    table.sort(cpEntries, function(a, b) return a.CP > b.CP end)
    table.sort(rollEntries, function(a, b) return a.Rolls > b.Rolls end)

    for _, child in ipairs(cpBoardList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    for _, child in ipairs(rollsBoardList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local rankColors = {
        [1] = Color3.fromRGB(255, 215, 0),
        [2] = Color3.fromRGB(215, 215, 225),
        [3] = Color3.fromRGB(205, 127, 50),
    }

    local maxRows = math.min(5, #cpEntries)
    for i = 1, maxRows do
        local entry = cpEntries[i]
        local rankColor = rankColors[i] or Color3.fromRGB(180, 190, 220)
        local rankIcon = if i == 1 then "🥇 #1" elseif i == 2 then "🥈 #2" elseif i == 3 then "🥉 #3" else string.format("#%d", i)
        renderLeaderboardRow(cpBoardList, i, rankIcon, rankColor, entry.Player.DisplayName, string.format("LVL %d", entry.Level), string.format("%d CP", entry.CP), Color3.fromRGB(255, 120, 60))
    end

    local maxRollRows = math.min(5, #rollEntries)
    for i = 1, maxRollRows do
        local entry = rollEntries[i]
        local rankColor = rankColors[i] or Color3.fromRGB(180, 190, 220)
        local rankIcon = if i == 1 then "🥇 #1" elseif i == 2 then "🥈 #2" elseif i == 3 then "🥉 #3" else string.format("#%d", i)
        local tierCfg = RarityConfig.Get(entry.HighestTier :: any)
        local tierColor = if tierCfg then tierCfg.Color else Color3.fromRGB(255, 205, 50)
        renderLeaderboardRow(rollsBoardList, i, rankIcon, rankColor, entry.Player.DisplayName, string.format("%d Rolls", entry.Rolls), entry.HighestTier, tierColor)
    end
end

--------------------------------------------------------------------------------
-- 10. MULTIPLAYER CUSTOM PARTY ROOMS LOGIC & LIFECYCLE
--------------------------------------------------------------------------------

local function getRoomByPlayer(player: Player): CustomPartyRoom?
    for _, room in ipairs(customPartyRooms) do
        for _, member in ipairs(room.Members) do
            if member == player then
                return room
            end
        end
    end
    return nil
end

local function sendNotification(player: Player, message: string)
    local notifEvt = Remotes.GetEvent(Constants.REMOTE_EVENTS.NotificationSent)
    notifEvt:FireClient(player, message)
end

local function updateRoomVisuals(room: CustomPartyRoom)
    local padFloor = room.PadFloor
    local titleLbl = room.TitleLabel
    local countLbl = room.CountLabel
    local statusLbl = room.StatusLabel

    if room.Host == nil or #room.Members == 0 then
        -- Empty open room
        if padFloor then
            padFloor.Material = Enum.Material.SmoothPlastic
            padFloor.Color = Color3.fromRGB(140, 150, 165)
            padFloor.Transparency = 0.84
        end
        if titleLbl then
            titleLbl.Text = string.format("✨ PARTY ROOM #%d [OPEN]", room.RoomId)
            titleLbl.TextColor3 = Color3.fromRGB(180, 205, 230)
        end
        if countLbl then
            countLbl.Text = "Players: 0 / 4"
            countLbl.TextColor3 = Color3.fromRGB(240, 245, 255)
        end
        if statusLbl then
            statusLbl.Text = "Step to Party Table to Create Room"
            statusLbl.TextColor3 = Color3.fromRGB(255, 215, 60)
        end
    else
        -- Active party room
        local floorCfg = FLOOR_CONFIGS[room.SelectedFloor] or FLOOR_CONFIGS["floor_1"]
        if padFloor then
            padFloor.Material = Enum.Material.SmoothPlastic
            padFloor.Color = floorCfg.Color
            padFloor.Transparency = 0.80
        end
        if titleLbl then
            titleLbl.Text = string.format("🏰 %s", floorCfg.FullName)
            titleLbl.TextColor3 = floorCfg.Color
        end
        if countLbl then
            local hostName = if room.Host then room.Host.DisplayName else "Unknown"
            local friendsTag = if room.FriendsOnly then " [🔒 FRIENDS ONLY]" else ""
            countLbl.Text = string.format("Host: %s%s • %d / %d", hostName, friendsTag, #room.Members, room.MaxPlayers)
            countLbl.TextColor3 = if #room.Members >= room.MaxPlayers then Color3.fromRGB(255, 215, 60) else Color3.fromRGB(240, 245, 255)
        end
        if statusLbl then
            if room.Countdown ~= nil then
                statusLbl.Text = string.format("🔥 Starting in %ds...", room.Countdown)
                statusLbl.TextColor3 = Color3.fromRGB(255, 120, 50)
            else
                statusLbl.Text = "Waiting for Host to start..."
                statusLbl.TextColor3 = Color3.fromRGB(140, 225, 255)
            end
        end
    end
end

local function buildMemberInfoList(room: CustomPartyRoom): { Types.PartyMemberInfo }
    local DataService = getDataService()
    local membersList: { Types.PartyMemberInfo } = {}
    for _, m in ipairs(room.Members) do
        local lvl = 1
        local cp = 10
        if DataService then
            local pData = DataService.GetData(m)
            if pData then
                lvl = pData.Level
                local stats = DataService.GetTotalStats(m)
                cp = math.round((stats.MaxHP * 1.0) + (stats.Damage * 3.5) + (stats.CritChance * 600) + (stats.LuckBonus * 80))
            end
        end
        table.insert(membersList, {
            UserId = m.UserId,
            DisplayName = m.DisplayName,
            Name = m.Name,
            Level = lvl,
            CombatPower = cp,
            IsHost = (m == room.Host),
        })
    end
    return membersList
end

local function sendPartyRoomStateTo(player: Player, room: CustomPartyRoom, isInRoom: boolean)
    local floorCfg = FLOOR_CONFIGS[room.SelectedFloor] or FLOOR_CONFIGS["floor_1"]
    local stateEvt = Remotes.GetEvent(Constants.REMOTE_EVENTS.PartyRoomStateUpdated)
    local membersList = if isInRoom then buildMemberInfoList(room) else {}

    local clientState: Types.PartyRoomClientState = {
        RoomId = room.RoomId,
        HostUserId = if (room.Host and isInRoom) then room.Host.UserId else nil,
        HostName = if (room.Host and isInRoom) then room.Host.DisplayName else nil,
        SelectedFloor = room.SelectedFloor,
        FloorName = floorCfg.Name,
        MaxPlayers = room.MaxPlayers,
        FriendsOnly = room.FriendsOnly,
        Members = membersList,
        Countdown = room.Countdown,
        IsInRoom = isInRoom,
        IsHost = (room.Host == player and isInRoom),
    }
    stateEvt:FireClient(player, clientState)
end

local function broadcastPartyRoomState(room: CustomPartyRoom)
    local floorCfg = FLOOR_CONFIGS[room.SelectedFloor] or FLOOR_CONFIGS["floor_1"]
    local stateEvt = Remotes.GetEvent(Constants.REMOTE_EVENTS.PartyRoomStateUpdated)
    local membersList = buildMemberInfoList(room)

    for _, p in ipairs(room.Members) do
        local clientState: Types.PartyRoomClientState = {
            RoomId = room.RoomId,
            HostUserId = if room.Host then room.Host.UserId else nil,
            HostName = if room.Host then room.Host.DisplayName else nil,
            SelectedFloor = room.SelectedFloor,
            FloorName = floorCfg.Name,
            MaxPlayers = room.MaxPlayers,
            FriendsOnly = room.FriendsOnly,
            Members = membersList,
            Countdown = room.Countdown,
            IsInRoom = true,
            IsHost = (p == room.Host),
        }
        stateEvt:FireClient(p, clientState)
    end
end

function LobbyService.LeavePartyRoom(player: Player): boolean
    local room = getRoomByPlayer(player)
    if not room then
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.WalkSpeed == 0 then
                hum.WalkSpeed = 16
                hum.JumpPower = 50
                hum.JumpHeight = 7.2
            end
        end
        player:SetAttribute("InPartyRoom", false)
        player:SetAttribute("PartyRoomId", nil)
        return false
    end

    local newMembers: { Player } = {}
    for _, m in ipairs(room.Members) do
        if m ~= player then
            table.insert(newMembers, m)
        end
    end
    room.Members = newMembers

    if room.Host == player then
        if #room.Members > 0 then
            room.Host = room.Members[1]
            room.Countdown = nil
        else
            room.Host = nil
            room.Members = {}
            room.SelectedFloor = "floor_1"
            room.MaxPlayers = 4
            room.FriendsOnly = false
            room.InvitedUserIds = {}
            room.Countdown = nil
        end
    end

    player:SetAttribute("InPartyRoom", false)
    player:SetAttribute("PartyRoomId", nil)
    playerLeaveCooldown[player.UserId] = os.clock()

    local char = player.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
            hum.JumpHeight = 7.2
        end
        if root then
            -- Safe egress to the walkway outside the tavern table
            char:PivotTo(CFrame.new(22, room.Position.Y + 2.0, room.Position.Z))
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end

    sendPartyRoomStateTo(player, room, false)
    updateRoomVisuals(room)
    broadcastPartyRoomState(room)
    return true
end

local function lockPlayerInRoom(room: CustomPartyRoom, player: Player, slotIndex: number)
    local slotOffset = ROOM_SLOT_OFFSETS[slotIndex] or ROOM_SLOT_OFFSETS[1]
    local slotPos = room.Position + slotOffset
    local tableCenter = room.Position + Vector3.new(0, 0.8, 0)
    local char = player.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        local hum = char:FindFirstChildOfClass("Humanoid")
        if root and hum then
            -- Face towards the table center so all 4 party members look at each other
            char:PivotTo(CFrame.lookAt(slotPos, tableCenter))
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            hum.WalkSpeed = 0
            hum.JumpPower = 0
            hum.JumpHeight = 0
            player:SetAttribute("InPartyRoom", true)
            player:SetAttribute("PartyRoomId", room.RoomId)
        end
    end

    local openUIEvt = Remotes.GetEvent(Constants.REMOTE_EVENTS.OpenUIModal)
    openUIEvt:FireClient(player, "PartyRoom")
end

local function updatePartyRooms()
    local dungeonService = getDungeonService()

    for _, room in ipairs(customPartyRooms) do
        -- 1. Scan players standing in the tavern party room pad
        for _, player in ipairs(Players:GetPlayers()) do
            local inRoom = getRoomByPlayer(player)
            if inRoom then continue end

            local lastLeave = playerLeaveCooldown[player.UserId] or 0
            if os.clock() - lastLeave < 2.0 then continue end

            local char = player.Character
            if not char then continue end
            local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
            if not root then continue end

            local horizontalDist = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(room.Position.X, 0, room.Position.Z)).Magnitude
            local verticalDist = math.abs(root.Position.Y - room.Position.Y)

            -- Check horizontal (radius <= 7.0 studs) and vertical height (within 7 studs for 2-story separation)
            if horizontalDist <= 7.0 and verticalDist <= 7.0 then
                local egressPos = Vector3.new(22, room.Position.Y + 2.0, room.Position.Z)

                -- Check room full
                if #room.Members >= room.MaxPlayers then
                    char:PivotTo(CFrame.new(egressPos))
                    root.AssemblyLinearVelocity = Vector3.zero
                    sendNotification(player, "Room is full!")
                    continue
                end

                -- Check Friends Only
                if room.FriendsOnly and room.Host ~= nil and room.Host ~= player then
                    local isFriend = false
                    local hostPlayer = room.Host
                    if hostPlayer and hostPlayer.Parent then
                        pcall(function()
                            isFriend = hostPlayer:IsFriendsWithAsync(player.UserId)
                        end)
                    end
                    local isInvited = room.InvitedUserIds[player.UserId] == true
                    if not isFriend and not isInvited then
                        char:PivotTo(CFrame.new(egressPos))
                        root.AssemblyLinearVelocity = Vector3.zero
                        sendNotification(player, "This room is Friends Only!")
                        continue
                    end
                end

                -- Valid to enter
                if room.Host == nil then
                    room.Host = player
                    room.SelectedFloor = "floor_1"
                    room.MaxPlayers = 4
                    room.FriendsOnly = false
                    room.InvitedUserIds = {}
                    room.Countdown = nil
                end

                table.insert(room.Members, player)
                lockPlayerInRoom(room, player, #room.Members)
                updateRoomVisuals(room)
                broadcastPartyRoomState(room)
            end
        end

        -- 2. Countdown handling
        if room.Countdown ~= nil then
            room.Countdown -= 1
            if room.Countdown <= 0 then
                room.Countdown = nil
                local partyToEnter = table.clone(room.Members)
                local chosenFloor = room.SelectedFloor

                -- Reset room state
                room.Host = nil
                room.Members = {}
                room.SelectedFloor = "floor_1"
                room.MaxPlayers = 4
                room.FriendsOnly = false
                room.InvitedUserIds = {}
                room.Countdown = nil

                for _, p in ipairs(partyToEnter) do
                    p:SetAttribute("InPartyRoom", false)
                    p:SetAttribute("PartyRoomId", nil)
                    local char = p.Character
                    if char then
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        if hum then
                            hum.WalkSpeed = 16
                            hum.JumpPower = 50
                            hum.JumpHeight = 7.2
                        end
                    end
                    sendPartyRoomStateTo(p, room, false)
                end

                updateRoomVisuals(room)

                if dungeonService then
                    task.spawn(function()
                        dungeonService.EnterPartyDungeon(partyToEnter, chosenFloor)
                    end)
                end
            else
                updateRoomVisuals(room)
                broadcastPartyRoomState(room)
            end
        else
            updateRoomVisuals(room)
        end
    end
end

--------------------------------------------------------------------------------
-- SERVICE LIFECYCLE
--------------------------------------------------------------------------------

function LobbyService:Init()
    print("[LobbyService] Initializing Valley Greenery Lobby & Adventurer's Guild Hall...")

    -- 1. Expanded Valley Baseplate (360x360 LeafyGrass)
    local existingBaseplate = Workspace:FindFirstChild("LobbyBaseplate") :: Part?
    if not existingBaseplate then
        local baseplate = Instance.new("Part")
        baseplate.Name = "LobbyBaseplate"
        baseplate.Size = Vector3.new(360, 4, 360)
        baseplate.CFrame = CFrame.new(0, -2, 0)
        baseplate.Anchored = true
        baseplate.CanCollide = true
        baseplate.Material = Enum.Material.LeafyGrass
        baseplate.Color = Color3.fromRGB(65, 115, 65)
        baseplate.TopSurface = Enum.SurfaceType.Smooth
        baseplate.BottomSurface = Enum.SurfaceType.Smooth
        baseplate.Parent = Workspace
    else
        existingBaseplate.Size = Vector3.new(360, 4, 360)
        existingBaseplate.Material = Enum.Material.LeafyGrass
        existingBaseplate.Color = Color3.fromRGB(65, 115, 65)
    end

    -- 2. Central Stone Plaza (50x50 Cobblestone)
    local existingPlaza = Workspace:FindFirstChild("LobbyPlaza")
    if not existingPlaza then
        local plaza = Instance.new("Part")
        plaza.Name = "LobbyPlaza"
        plaza.Size = Vector3.new(50, 0.4, 50)
        plaza.CFrame = CFrame.new(0, 0.2, 0)
        plaza.Anchored = true
        plaza.CanCollide = true
        plaza.Material = Enum.Material.Cobblestone
        plaza.Color = Color3.fromRGB(80, 80, 85)
        plaza.TopSurface = Enum.SurfaceType.Smooth
        plaza.Parent = Workspace
    end

    -- 3. Spawn Platform in Central Plaza
    local existingSpawn = Workspace:FindFirstChild("LobbySpawn")
    if not existingSpawn then
        local spawn = Instance.new("SpawnLocation")
        spawn.Name = "LobbySpawn"
        spawn.Size = Vector3.new(14, 1, 14)
        spawn.CFrame = CFrame.new(0, 0.5, 6)
        spawn.Anchored = true
        spawn.CanCollide = true
        spawn.Neutral = true
        spawn.Duration = 3
        spawn.Material = Enum.Material.Cobblestone
        spawn.Color = Color3.fromRGB(70, 75, 85)
        spawn.TopSurface = Enum.SurfaceType.Smooth
        spawn.Parent = Workspace
    end

    -- 4. 3D Mystic Loot Chest at (0, 0.4, -12)
    local existingChest = Workspace:FindFirstChild("MysticLootChest")
    if not existingChest then
        buildMysticChest()
    end

    -- 5. 4 Light Pillars around Central Plaza
    buildLightPillars()

    -- 6. 4 Cobblestone Crossroads
    buildRoads()

    -- 7. East: Training Grounds & Dummies
    buildTrainingGrounds()

    -- 8. West: Reforge & Trait Sanctuary
    buildReforgeSanctuary()

    -- 9. South: Trading Plaza
    buildTradingPlaza()

    -- 10. Procedural Foliage (Trees & Rocks)
    buildFoliage()

    -- 11. North: Adventurer's Guild Hall & Party Pods
    buildAdventurersGuildHall()

    -- 12. 3D Leaderboards
    buildMonumentLeaderboards()

    -- 13. ANTI-GLARE DAYTIME LIGHTING SETUP
    Lighting.ClockTime = 14.5
    Lighting.Brightness = 1.0
    Lighting.ExposureCompensation = -0.35
    Lighting.Ambient = Color3.fromRGB(80, 85, 95)
    Lighting.OutdoorAmbient = Color3.fromRGB(100, 105, 115)

    local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
    if not bloom then
        bloom = Instance.new("BloomEffect")
        bloom.Name = "LobbyBloom"
        bloom.Parent = Lighting
    end
    bloom.Intensity = 0.05
    bloom.Threshold = 3.0
    bloom.Size = 16
    bloom.Enabled = true

    -- 14. MULTIPLAYER CUSTOM PARTY ROOM REMOTE FUNCTION
    local partyActionFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestPartyRoomAction)
    partyActionFn.OnServerInvoke = function(player: Player, action: any, payload: any)
        local act = tostring(action or "")
        local data = if typeof(payload) == "table" then payload else {}

        if act == "Leave" then
            LobbyService.LeavePartyRoom(player)
            return { Success = true }
        elseif act == "SetFloor" then
            local room = getRoomByPlayer(player)
            if room and room.Host == player and data.FloorId and FLOOR_CONFIGS[data.FloorId] then
                room.SelectedFloor = data.FloorId
                updateRoomVisuals(room)
                broadcastPartyRoomState(room)
                return { Success = true }
            end
            return { Success = false, Error = "Unauthorized or invalid floor" }
        elseif act == "SetMaxPlayers" then
            local room = getRoomByPlayer(player)
            if room and room.Host == player and typeof(data.MaxPlayers) == "number" then
                local mp = math.clamp(math.round(data.MaxPlayers), 1, 4)
                room.MaxPlayers = math.max(#room.Members, mp)
                updateRoomVisuals(room)
                broadcastPartyRoomState(room)
                return { Success = true }
            end
            return { Success = false, Error = "Unauthorized" }
        elseif act == "SetFriendsOnly" then
            local room = getRoomByPlayer(player)
            if room and room.Host == player then
                room.FriendsOnly = (data.FriendsOnly == true)
                updateRoomVisuals(room)
                broadcastPartyRoomState(room)
                return { Success = true }
            end
            return { Success = false, Error = "Unauthorized" }
        elseif act == "StartDungeon" then
            local room = getRoomByPlayer(player)
            if room and room.Host == player and #room.Members > 0 then
                room.Countdown = 3
                updateRoomVisuals(room)
                broadcastPartyRoomState(room)
                return { Success = true }
            end
            return { Success = false, Error = "Cannot start" }
        elseif act == "Invite" then
            local room = getRoomByPlayer(player)
            if room and typeof(data.TargetUserId) == "number" then
                local target = Players:GetPlayerByUserId(data.TargetUserId)
                if target and target.Parent then
                    room.InvitedUserIds[target.UserId] = true
                    local floorCfg = FLOOR_CONFIGS[room.SelectedFloor] or FLOOR_CONFIGS["floor_1"]
                    local invEvt = Remotes.GetEvent(Constants.REMOTE_EVENTS.PartyInviteReceived)
                    invEvt:FireClient(target, {
                        RoomId = room.RoomId,
                        HostName = player.DisplayName,
                        FloorId = room.SelectedFloor,
                        FloorName = floorCfg.Name,
                    })
                    return { Success = true }
                end
            end
            return { Success = false, Error = "Player not found" }
        elseif act == "AcceptInvite" then
            if typeof(data.RoomId) == "number" then
                local targetRoom: CustomPartyRoom? = nil
                for _, r in ipairs(customPartyRooms) do
                    if r.RoomId == data.RoomId then
                        targetRoom = r
                        break
                    end
                end
                if targetRoom and #targetRoom.Members < targetRoom.MaxPlayers then
                    LobbyService.LeavePartyRoom(player)
                    table.insert(targetRoom.Members, player)
                    lockPlayerInRoom(targetRoom, player, #targetRoom.Members)
                    updateRoomVisuals(targetRoom)
                    broadcastPartyRoomState(targetRoom)
                    return { Success = true }
                end
            end
            return { Success = false, Error = "Room full or expired" }
        end

        return { Success = false, Error = "Unknown action" }
    end

    Players.PlayerRemoving:Connect(function(player: Player)
        LobbyService.LeavePartyRoom(player)
    end)

    print("[LobbyService] Complete Valley Lobby & Guild Hall generated successfully.")
end

function LobbyService:Start()
    -- Hook Mystic Chest prompt
    local chestModel = Workspace:FindFirstChild("MysticLootChest")
    if chestModel then
        local body = chestModel:FindFirstChild("ChestBody")
        if body then
            local prompt = body:FindFirstChildOfClass("ProximityPrompt")
            if prompt then
                prompt.Triggered:Connect(function(player: Player)
                    local rollServiceModule = script.Parent:FindFirstChild("RollService")
                    if rollServiceModule then
                        local rollService = (require :: any)(rollServiceModule)
                        if rollService and typeof(rollService.RollItem) == "function" then
                            rollService.RollItem(player, true)
                        end
                    end
                end)
            end
        end
    end

    -- Real-time Leaderboards refresh loop (every 5 seconds)
    task.spawn(function()
        task.wait(2.0)
        while true do
            refreshServerLeaderboards()
            task.wait(5.0)
        end
    end)

    -- Real-time Multiplayer Party Rooms loop (every 1.0 second)
    task.spawn(function()
        task.wait(2.0)
        while true do
            updatePartyRooms()
            task.wait(1.0)
        end
    end)
end

return LobbyService
