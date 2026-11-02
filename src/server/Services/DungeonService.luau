--!strict
--[[
    DungeonService.luau
    Authoritative Dungeon Crawler engine:
    - Procedural 140x140 Dungeon Arena at Vector3.new(600, 0, 0).
    - 3-Wave progression per floor (Normal -> Elite -> Boss + Minions).
    - Procedural 3D Enemy & Boss Models placed in Workspace.Enemies.
    - Enemy AI Finite State Machine on Heartbeat (Pathfinding, Melee Attack, Attack Telegraph AoE).
    - Boss Telegraph Mechanic (Pulsing 14-stud red zone that explodes after 2.0s).
    - Authoritative victory rewards (Gold, XP, Level progression, and auto-return).
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local DungeonConfig = require(Shared:WaitForChild("DungeonConfig"))

local DungeonService = {
    Name = "DungeonService",
    Priority = 5,
}

local ARENA_CENTER = Vector3.new(600, 0, 0)
local ARENA_SPAWN = Vector3.new(600, 4, 45)
local LOBBY_SPAWN = Vector3.new(0, 4, 0)

-- Active player dungeon sessions
type ActiveDungeonSession = {
    Player: Player, -- Host / Leader
    Players: { Player }, -- All party members (1 to 4)
    DungeonId: string,
    Config: DungeonConfig.DungeonDifficulty,
    CurrentWave: number,
    AliveEnemies: { [Model]: boolean },
    NextBossAoE: number,
    IsCompleted: boolean,
}

local activeSessions: { [number]: ActiveDungeonSession } = {}
local enemyAttackCooldowns: { [Model]: number } = {}

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
    Generates the 140x140 Dungeon Arena at (600, 0, 0) with perimeter walls and 8 flaming torch pillars.
]]
local function buildDungeonArena()
    local existingArena = Workspace:FindFirstChild("DungeonArena")
    if existingArena then return end

    local arenaModel = Instance.new("Model")
    arenaModel.Name = "DungeonArena"

    -- 1. Arena Stone Floor
    local floor = Instance.new("Part")
    floor.Name = "DungeonArenaFloor"
    floor.Size = Vector3.new(140, 4, 140)
    floor.CFrame = CFrame.new(ARENA_CENTER.X, -2, ARENA_CENTER.Z)
    floor.Anchored = true
    floor.Material = Enum.Material.Cobblestone
    floor.Color = Color3.fromRGB(38, 42, 58)
    floor.TopSurface = Enum.SurfaceType.Smooth
    floor.Parent = arenaModel

    -- 2. Perimeter Walls
    local function createWall(name: string, size: Vector3, cf: CFrame)
        local wall = Instance.new("Part")
        wall.Name = name
        wall.Size = size
        wall.CFrame = cf
        wall.Anchored = true
        wall.Material = Enum.Material.Slate
        wall.Color = Color3.fromRGB(30, 34, 48)
        wall.TopSurface = Enum.SurfaceType.Smooth
        wall.Parent = arenaModel
    end

    createWall("NorthWall", Vector3.new(144, 16, 4), CFrame.new(ARENA_CENTER.X, 8, ARENA_CENTER.Z - 70))
    createWall("SouthWall", Vector3.new(144, 16, 4), CFrame.new(ARENA_CENTER.X, 8, ARENA_CENTER.Z + 70))
    createWall("WestWall",  Vector3.new(4, 16, 144), CFrame.new(ARENA_CENTER.X - 70, 8, ARENA_CENTER.Z))
    createWall("EastWall",  Vector3.new(4, 16, 144), CFrame.new(ARENA_CENTER.X + 70, 8, ARENA_CENTER.Z))

    -- 3. 8 Perimeter Torch Light Pillars
    local torchOffsets = {
        Vector3.new(-55, 0, -55),
        Vector3.new(0,   0, -62),
        Vector3.new(55,  0, -55),
        Vector3.new(-62, 0, 0),
        Vector3.new(62,  0, 0),
        Vector3.new(-55, 0, 55),
        Vector3.new(0,   0, 62),
        Vector3.new(55,  0, 55),
    }

    for i, offset in ipairs(torchOffsets) do
        local pillarPos = ARENA_CENTER + offset

        local pillar = Instance.new("Part")
        pillar.Name = string.format("TorchPillar_%d", i)
        pillar.Size = Vector3.new(2.4, 10, 2.4)
        pillar.CFrame = CFrame.new(pillarPos.X, 5, pillarPos.Z)
        pillar.Anchored = true
        pillar.Material = Enum.Material.Cobblestone
        pillar.Color = Color3.fromRGB(48, 52, 70)
        pillar.Parent = arenaModel

        local brazier = Instance.new("Part")
        brazier.Name = "Brazier"
        brazier.Size = Vector3.new(3.0, 1.2, 3.0)
        brazier.CFrame = CFrame.new(pillarPos.X, 10.4, pillarPos.Z)
        brazier.Anchored = true
        brazier.Material = Enum.Material.Metal
        brazier.Color = Color3.fromRGB(60, 64, 80)
        brazier.Parent = arenaModel

        local firePart = Instance.new("Part")
        firePart.Name = "TorchFire"
        firePart.Size = Vector3.new(1, 1, 1)
        firePart.CFrame = CFrame.new(pillarPos.X, 11.2, pillarPos.Z)
        firePart.Anchored = true
        firePart.Transparency = 1
        firePart.CanCollide = false
        firePart.Parent = arenaModel

        local fireLight = Instance.new("PointLight")
        fireLight.Name = "TorchLight"
        fireLight.Range = 55
        fireLight.Brightness = 3.0
        fireLight.Color = Color3.fromRGB(255, 175, 75)
        fireLight.Shadows = true
        fireLight.Parent = firePart

        local emitter = Instance.new("ParticleEmitter")
        emitter.Rate = 14
        emitter.Lifetime = NumberRange.new(0.8, 1.5)
        emitter.Speed = NumberRange.new(2, 4)
        emitter.Acceleration = Vector3.new(0, 5, 0)
        emitter.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 90)),
            ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 110, 20)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 20, 10)),
        })
        emitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.4),
            NumberSequenceKeypoint.new(0.7, 1.0),
            NumberSequenceKeypoint.new(1, 0),
        })
        emitter.Parent = firePart
    end

    arenaModel.Parent = Workspace
end

--[[
    Spawns a procedural 3D Enemy or Boss Model into Workspace.Enemies.
]]
local function buildEnemy(cfg: DungeonConfig.EnemySpawnConfig, spawnPos: Vector3): Model
    local scale = cfg.Scale or 1.0
    local isBoss = cfg.IsBoss == true

    local enemyModel = Instance.new("Model")
    enemyModel.Name = cfg.Name
    enemyModel:SetAttribute("EnemyName", cfg.Name)
    enemyModel:SetAttribute("Damage", cfg.Damage)
    enemyModel:SetAttribute("IsBoss", isBoss)

    -- 1. HumanoidRootPart
    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(2 * scale, 3 * scale, 1.2 * scale)
    hrp.CFrame = CFrame.new(spawnPos.X, spawnPos.Y + 2 * scale, spawnPos.Z)
    hrp.Transparency = 1
    hrp.CanCollide = false
    hrp.Parent = enemyModel
    enemyModel.PrimaryPart = hrp

    -- 2. Torso
    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2.4 * scale, 3.0 * scale, 1.4 * scale)
    torso.CFrame = hrp.CFrame
    torso.Color = cfg.BodyColor
    torso.Material = if isBoss then Enum.Material.Metal else Enum.Material.SmoothPlastic
    torso.CanCollide = true
    torso.Parent = enemyModel

    local torsoWeld = Instance.new("WeldConstraint")
    torsoWeld.Part0 = hrp
    torsoWeld.Part1 = torso
    torsoWeld.Parent = torso

    -- 3. Head
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1.4 * scale, 1.4 * scale, 1.4 * scale)
    head.CFrame = torso.CFrame * CFrame.new(0, 2.2 * scale, 0)
    head.Color = cfg.BodyColor
    head.Material = torso.Material
    head.CanCollide = false
    head.Parent = enemyModel

    local headWeld = Instance.new("WeldConstraint")
    headWeld.Part0 = torso
    headWeld.Part1 = head
    headWeld.Parent = head

    -- Glowing eyes
    local eyeL = Instance.new("Part")
    eyeL.Name = "EyeL"
    eyeL.Size = Vector3.new(0.2 * scale, 0.2 * scale, 0.2 * scale)
    eyeL.Color = if isBoss then Color3.fromRGB(255, 30, 30) else Color3.fromRGB(255, 200, 30)
    eyeL.Material = Enum.Material.Neon
    eyeL.CFrame = head.CFrame * CFrame.new(-0.35 * scale, 0.1 * scale, -0.72 * scale)
    eyeL.CanCollide = false
    eyeL.Parent = enemyModel

    local eyeLWeld = Instance.new("WeldConstraint")
    eyeLWeld.Part0 = head
    eyeLWeld.Part1 = eyeL
    eyeLWeld.Parent = eyeL

    local eyeR = Instance.new("Part")
    eyeR.Name = "EyeR"
    eyeR.Size = Vector3.new(0.2 * scale, 0.2 * scale, 0.2 * scale)
    eyeR.Color = eyeL.Color
    eyeR.Material = Enum.Material.Neon
    eyeR.CFrame = head.CFrame * CFrame.new(0.35 * scale, 0.1 * scale, -0.72 * scale)
    eyeR.CanCollide = false
    eyeR.Parent = enemyModel

    local eyeRWeld = Instance.new("WeldConstraint")
    eyeRWeld.Part0 = head
    eyeRWeld.Part1 = eyeR
    eyeRWeld.Parent = eyeR

    -- 4. Arms
    local rightArm = Instance.new("Part")
    rightArm.Name = "RightArm"
    rightArm.Size = Vector3.new(0.9 * scale, 2.8 * scale, 0.9 * scale)
    rightArm.CFrame = torso.CFrame * CFrame.new(1.65 * scale, 0, 0)
    rightArm.Color = cfg.BodyColor
    rightArm.Material = torso.Material
    rightArm.CanCollide = false
    rightArm.Parent = enemyModel

    local rArmWeld = Instance.new("WeldConstraint")
    rArmWeld.Part0 = torso
    rArmWeld.Part1 = rightArm
    rArmWeld.Parent = rightArm

    local leftArm = Instance.new("Part")
    leftArm.Name = "LeftArm"
    leftArm.Size = Vector3.new(0.9 * scale, 2.8 * scale, 0.9 * scale)
    leftArm.CFrame = torso.CFrame * CFrame.new(-1.65 * scale, 0, 0)
    leftArm.Color = cfg.BodyColor
    leftArm.Material = torso.Material
    leftArm.CanCollide = false
    leftArm.Parent = enemyModel

    local lArmWeld = Instance.new("WeldConstraint")
    lArmWeld.Part0 = torso
    lArmWeld.Part1 = leftArm
    lArmWeld.Parent = leftArm

    -- 5. Monster Weapon (Blade / Spiked Club)
    local weapon = Instance.new("Part")
    weapon.Name = "EnemyWeapon"
    weapon.Size = Vector3.new(0.5 * scale, 3.4 * scale, 0.5 * scale)
    weapon.Color = Color3.fromRGB(50, 45, 55)
    weapon.Material = Enum.Material.Metal
    weapon.CFrame = rightArm.CFrame * CFrame.new(0, -1.0 * scale, -0.8 * scale) * CFrame.Angles(math.rad(60), 0, 0)
    weapon.CanCollide = false
    weapon.Parent = enemyModel

    local wpnWeld = Instance.new("WeldConstraint")
    wpnWeld.Part0 = rightArm
    wpnWeld.Part1 = weapon
    wpnWeld.Parent = weapon

    -- 6. Humanoid (Hide default overhead name/health to prevent duplicate text with EnemyHUD)
    local humanoid = Instance.new("Humanoid")
    humanoid.MaxHealth = cfg.MaxHP
    humanoid.Health = cfg.MaxHP
    humanoid.WalkSpeed = cfg.MoveSpeed
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
    humanoid.Parent = enemyModel

    -- 7. Overhead Billboard Health Bar
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "EnemyHUD"
    billboard.Size = UDim2.new(0, if isBoss then 190 else 140, 0, if isBoss then 46 else 38)
    billboard.StudsOffset = Vector3.new(0, 3.6 * scale, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 90
    billboard.Adornee = head
    billboard.Parent = enemyModel

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Name = "Title"
    titleLbl.Size = UDim2.new(1, 0, 0, if isBoss then 20 else 16)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.Text = if isBoss then string.format("👑 [BOSS] %s", cfg.Name) else cfg.Name
    titleLbl.TextColor3 = if isBoss then Color3.fromRGB(255, 80, 80) else Color3.fromRGB(255, 230, 160)
    titleLbl.TextSize = if isBoss then 13 else 11
    titleLbl.Parent = billboard

    local titleStroke = Instance.new("UIStroke")
    titleStroke.Color = Color3.fromRGB(15, 17, 26)
    titleStroke.Thickness = 2.0
    titleStroke.Parent = titleLbl

    local hpBg = Instance.new("Frame")
    hpBg.Name = "HPBg"
    hpBg.Size = UDim2.new(1, -12, 0, if isBoss then 13 else 10)
    hpBg.Position = UDim2.new(0, 6, 0, if isBoss then 22 else 18)
    hpBg.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
    hpBg.BorderSizePixel = 0
    hpBg.Parent = billboard

    local hpBgCorner = Instance.new("UICorner")
    hpBgCorner.CornerRadius = UDim.new(0, 5)
    hpBgCorner.Parent = hpBg

    local hpFill = Instance.new("Frame")
    hpFill.Name = "HPFill"
    hpFill.Size = UDim2.new(1, 0, 1, 0)
    hpFill.BackgroundColor3 = if isBoss then Color3.fromRGB(255, 60, 60) else Color3.fromRGB(60, 215, 90)
    hpFill.BorderSizePixel = 0
    hpFill.Parent = hpBg

    local hpFillCorner = Instance.new("UICorner")
    hpFillCorner.CornerRadius = UDim.new(0, 5)
    hpFillCorner.Parent = hpFill

    local hpTxt = Instance.new("TextLabel")
    hpTxt.Name = "HPTxt"
    hpTxt.Size = UDim2.new(1, 0, 1, 0)
    hpTxt.BackgroundTransparency = 1
    hpTxt.Font = Enum.Font.GothamBold
    hpTxt.Text = string.format("%d / %d", cfg.MaxHP, cfg.MaxHP)
    hpTxt.TextColor3 = Color3.fromRGB(255, 255, 255)
    hpTxt.TextSize = 9
    hpTxt.Parent = hpBg

    -- Health changed hook
    humanoid.HealthChanged:Connect(function(health)
        local ratio = math.clamp(health / humanoid.MaxHealth, 0, 1)
        hpFill.Size = UDim2.new(ratio, 0, 1, 0)
        hpTxt.Text = string.format("%d / %d", math.max(0, math.round(health)), humanoid.MaxHealth)
    end)

    CollectionService:AddTag(enemyModel, "Enemy")
    CollectionService:AddTag(enemyModel, "Damageable")

    -- Place in Workspace.Enemies
    local enemiesFolder = Workspace:FindFirstChild("Enemies")
    if not enemiesFolder then
        enemiesFolder = Instance.new("Folder")
        enemiesFolder.Name = "Enemies"
        enemiesFolder.Parent = Workspace
    end

    enemyModel.Parent = enemiesFolder
    return enemyModel
end

--[[
    Executes Boss Telegraph AoE Attack (Pulsing 14-stud red circle under player, explodes in 2.0s).
]]
local function executeBossTelegraphAoE(bossModel: Model, targetPlayer: Player)
    local targetChar = targetPlayer.Character
    if not targetChar then return end

    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not targetRoot then return end

    local targetPos = targetRoot.Position
    local aoePos = Vector3.new(targetPos.X, 0.3, targetPos.Z)

    -- Warning Telegraph Zone Part
    local warningZone = Instance.new("Part")
    warningZone.Name = "BossTelegraphZone"
    warningZone.Shape = Enum.PartType.Cylinder
    warningZone.Size = Vector3.new(0.2, 28, 28)
    warningZone.CFrame = CFrame.new(aoePos) * CFrame.Angles(0, 0, math.rad(90))
    warningZone.Color = Color3.fromRGB(255, 30, 30)
    warningZone.Material = Enum.Material.Neon
    warningZone.Transparency = 0.4
    warningZone.Anchored = true
    warningZone.CanCollide = false
    warningZone.Parent = Workspace

    -- Pulsing warning tween
    local pulseTween = TweenService:Create(warningZone, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true), {
        Transparency = 0.15,
        Size = Vector3.new(0.2, 30, 30)
    })
    pulseTween:Play()

    -- Detonation after 2.0 seconds
    task.delay(2.0, function()
        if not warningZone.Parent then return end
        warningZone:Destroy()

        -- Explosion Blast VFX
        local blast = Instance.new("Part")
        blast.Name = "TelegraphExplosion"
        blast.Shape = Enum.PartType.Cylinder
        blast.Size = Vector3.new(0.5, 6, 6)
        blast.CFrame = CFrame.new(aoePos) * CFrame.Angles(0, 0, math.rad(90))
        blast.Color = Color3.fromRGB(255, 80, 20)
        blast.Material = Enum.Material.Neon
        blast.Anchored = true
        blast.CanCollide = false
        blast.Parent = Workspace

        TweenService:Create(blast, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = Vector3.new(0.2, 34, 34),
            Transparency = 1,
        }):Play()

        task.delay(0.4, function()
            blast:Destroy()
        end)

        -- Check damage on player
        local curChar = targetPlayer.Character
        if curChar then
            local curRoot = curChar:FindFirstChild("HumanoidRootPart") :: BasePart?
            local curHum = curChar:FindFirstChildOfClass("Humanoid")
            if curRoot and curHum and curHum.Health > 0 then
                local dist = (Vector3.new(curRoot.Position.X, 0, curRoot.Position.Z) - Vector3.new(aoePos.X, 0, aoePos.Z)).Magnitude
                if dist <= 14.0 then
                    if curChar:GetAttribute("Invulnerable") ~= true then
                        local bossDmg = (bossModel:GetAttribute("Damage") :: number?) or 50
                        local totalBlastDamage = math.round(bossDmg * 2.2)
                        curHum:TakeDamage(totalBlastDamage)

                        -- Knockback
                        curRoot.AssemblyLinearVelocity = Vector3.new(0, 30, 0) + (curRoot.Position - aoePos).Unit * 45
                    end
                end
            end
        end
    end)
end

--[[
    Spawns all enemies for the current wave of an active dungeon session.
]]
local function spawnWave(session: ActiveDungeonSession)
    local waveConfig = session.Config.Waves[session.CurrentWave]
    if not waveConfig then return end

    session.AliveEnemies = {}

    local spawnRadius = 24
    local count = #waveConfig.Enemies

    for i, enemyCfg in ipairs(waveConfig.Enemies) do
        local angle = (i / count) * math.pi * 2
        local spawnX = ARENA_CENTER.X + math.cos(angle) * spawnRadius
        local spawnZ = ARENA_CENTER.Z + math.sin(angle) * spawnRadius - 10

        local enemyModel = buildEnemy(enemyCfg, Vector3.new(spawnX, 2, spawnZ))
        session.AliveEnemies[enemyModel] = true

        -- Listen for death
        local hum = enemyModel:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.Died:Connect(function()
                session.AliveEnemies[enemyModel] = nil
                enemyAttackCooldowns[enemyModel] = nil

                task.delay(0.5, function()
                    if enemyModel.Parent then
                        enemyModel:Destroy()
                    end
                end)

                -- Count remaining
                local remainingCount = 0
                for _ in pairs(session.AliveEnemies) do
                    remainingCount += 1
                end

                -- Replicate HUD state to all players in party
                local stateEvent = Remotes.GetEvent(Constants.REMOTE_EVENTS.DungeonStateChanged)
                for _, p in ipairs(session.Players) do
                    if p.Parent then
                        stateEvent:FireClient(p, {
                            InDungeon = true,
                            DungeonId = session.DungeonId,
                            DungeonName = session.Config.Name,
                            CurrentWave = session.CurrentWave,
                            TotalWaves = #session.Config.Waves,
                            RemainingEnemies = remainingCount,
                        })
                    end
                end

                -- Progress Monster Kill Quest for all party members
                local qs = getQuestService()
                if qs and typeof(qs.OnMonsterKilled) == "function" then
                    for _, p in ipairs(session.Players) do
                        if p.Parent then
                            qs.OnMonsterKilled(p)
                        end
                    end
                end

                -- Check Wave Completion
                if remainingCount == 0 then
                    if session.CurrentWave < #session.Config.Waves then
                        -- Advance to next wave
                        local waveCompEvent = Remotes.GetEvent(Constants.REMOTE_EVENTS.WaveCompleted)
                        for _, p in ipairs(session.Players) do
                            if p.Parent then
                                waveCompEvent:FireClient(p, session.CurrentWave)
                            end
                        end

                        task.delay(3.0, function()
                            if activeSessions[session.Player.UserId] == session then
                                session.CurrentWave += 1
                                spawnWave(session)
                            end
                        end)
                    else
                        -- VICTORY! Dungeon Completed
                        session.IsCompleted = true

                        local ds = getDataService()
                        local gemReward = session.Config.Rewards.Gems or (if session.Config.FloorNumber == 3 then 12 elseif session.Config.FloorNumber == 2 then 5 else 2)

                        for _, p in ipairs(session.Players) do
                            if p.Parent then
                                local goldReward = session.Config.Rewards.Gold
                                if ds then
                                    local data = ds.GetData(p)
                                    if data and data.ActiveBuffs and os.time() < (data.ActiveBuffs.GoldBoostEndTime or 0) then
                                        goldReward *= 2
                                    end
                                    ds.AddGold(p, goldReward)
                                    ds.AddXP(p, session.Config.Rewards.XP)
                                    ds.AddGems(p, gemReward)
                                end

                                if qs and typeof(qs.OnDungeonCleared) == "function" then
                                    qs.OnDungeonCleared(p)
                                end

                                local completedEvent = Remotes.GetEvent(Constants.REMOTE_EVENTS.DungeonCompleted)
                                completedEvent:FireClient(p, {
                                    DungeonName = session.Config.Name,
                                    GoldEarned = goldReward,
                                    XPEarned = session.Config.Rewards.XP,
                                    BonusText = string.format("%s (+%d Gems)", session.Config.Rewards.BonusRollText, gemReward),
                                })

                                -- Grant bonus lucky roll upon dungeon victory!
                                task.delay(1.5, function()
                                    if p and p.Parent then
                                        local rollServiceModule = script.Parent:FindFirstChild("RollService")
                                        if rollServiceModule then
                                            local rs = (require :: any)(rollServiceModule)
                                            if rs and typeof(rs.RollItem) == "function" then
                                                rs.RollItem(p, true)
                                            end
                                        end
                                    end
                                end)

                                -- Teleport back to lobby after 5 seconds
                                task.delay(5.0, function()
                                    DungeonService.LeaveDungeon(p)
                                end)
                            end
                        end
                    end
                end
            end)
        end
    end

    -- Initial wave HUD notification for all party players
    local stateEvent = Remotes.GetEvent(Constants.REMOTE_EVENTS.DungeonStateChanged)
    for _, p in ipairs(session.Players) do
        if p.Parent then
            stateEvent:FireClient(p, {
                InDungeon = true,
                DungeonId = session.DungeonId,
                DungeonName = session.Config.Name,
                CurrentWave = session.CurrentWave,
                TotalWaves = #session.Config.Waves,
                RemainingEnemies = count,
            })
        end
    end
end

--[[
    Enters a dungeon with a party of 1 to 4 players.
]]
function DungeonService.EnterPartyDungeon(partyPlayers: { Player }, dungeonId: string): (boolean, string?)
    local config = DungeonConfig.Get(dungeonId)
    if not config then
        return false, "Invalid dungeon floor."
    end

    local validPlayers: { Player } = {}
    local ds = getDataService()

    for i, p in ipairs(partyPlayers) do
        if p and p.Parent then
            local char = p.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
                local hum = char:FindFirstChildOfClass("Humanoid")
                if root and hum then
                    -- Clean previous session if any without sending false InDungeon event
                    local oldSession = activeSessions[p.UserId]
                    if oldSession then
                        for enemy in pairs(oldSession.AliveEnemies) do
                            if enemy.Parent then enemy:Destroy() end
                        end
                        activeSessions[p.UserId] = nil
                    end

                    -- Heal to full
                    if ds and typeof(ds.ApplyStatsToCharacter) == "function" then
                        ds.ApplyStatsToCharacter(p)
                    else
                        hum.Health = hum.MaxHealth
                    end

                    -- Restore movement speeds and clear party room lock
                    hum.WalkSpeed = 16
                    hum.JumpPower = 50
                    hum.JumpHeight = 7.2
                    p:SetAttribute("InPartyRoom", false)
                    p:SetAttribute("PartyRoomId", nil)

                    -- Reliable character teleportation to Arena
                    local targetPos = ARENA_SPAWN + Vector3.new((i - 1) * 6, 2, 0)
                    char:PivotTo(CFrame.new(targetPos))
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero

                    table.insert(validPlayers, p)
                end
            end
        end
    end

    if #validPlayers == 0 then
        return false, "No valid players in party."
    end

    -- Create Session
    local session: ActiveDungeonSession = {
        Player = validPlayers[1],
        Players = validPlayers,
        DungeonId = dungeonId,
        Config = config,
        CurrentWave = 1,
        AliveEnemies = {},
        NextBossAoE = os.clock() + 5.0,
        IsCompleted = false,
    }

    for _, p in ipairs(validPlayers) do
        activeSessions[p.UserId] = session
    end

    print(string.format("[DungeonService] Party of %d players initiated dungeon '%s'!", #validPlayers, dungeonId))

    -- Spawn Wave 1 & broadcast state
    spawnWave(session)
    return true, nil
end

--[[
    Enters a dungeon for a single player.
]]
function DungeonService.EnterDungeon(player: Player, dungeonId: string): (boolean, string?)
    return DungeonService.EnterPartyDungeon({ player }, dungeonId)
end

--[[
    Leaves active dungeon and returns player to Lobby spawn safely.
]]
function DungeonService.LeaveDungeon(player: Player): boolean
    local session = activeSessions[player.UserId]
    if session then
        -- Clean remaining enemies
        for enemy in pairs(session.AliveEnemies) do
            if enemy.Parent then
                enemy:Destroy()
            end
        end
        activeSessions[player.UserId] = nil
    end

    -- Teleport back to Lobby
    local char = player.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if root then
            root.CFrame = CFrame.new(LOBBY_SPAWN)
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
            hum.JumpHeight = 7.2
        end
        player:SetAttribute("InPartyRoom", false)
        player:SetAttribute("PartyRoomId", nil)

        local ds = getDataService()
        if ds and typeof(ds.ApplyStatsToCharacter) == "function" then
            ds.ApplyStatsToCharacter(player)
        end
    end

    -- Notify Client
    local stateEvent = Remotes.GetEvent(Constants.REMOTE_EVENTS.DungeonStateChanged)
    stateEvent:FireClient(player, {
        InDungeon = false,
        DungeonId = "",
        DungeonName = "",
        CurrentWave = 0,
        TotalWaves = 0,
        RemainingEnemies = 0,
    })

    return true
end

function DungeonService:Init()
    print("[DungeonService] Initializing Dungeon Arena & AI loop...")
    buildDungeonArena()

    -- 1. RemoteFunction: RequestEnterDungeon
    local enterFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestEnterDungeon)
    enterFn.OnServerInvoke = function(player: Player, dungeonId: any)
        local id = tostring(dungeonId or "goblin_crypt")
        local success, err = DungeonService.EnterDungeon(player, id)
        return { Success = success, Error = err }
    end

    -- 2. RemoteFunction: RequestLeaveDungeon
    local leaveFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestLeaveDungeon)
    leaveFn.OnServerInvoke = function(player: Player)
        local success = DungeonService.LeaveDungeon(player)
        return { Success = success }
    end

    -- 3. Player cleanup
    Players.PlayerRemoving:Connect(function(player: Player)
        DungeonService.LeaveDungeon(player)
    end)
end

function DungeonService:Start()
    print("[DungeonService] Starting Enemy AI Heartbeat engine...")

    -- AI Heartbeat update loop (runs every ~0.12s)
    local lastTick = 0
    RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - lastTick < 0.12 then return end
        lastTick = now

        local processedSessions: { [ActiveDungeonSession]: boolean } = {}
        for _, session in pairs(activeSessions) do
            if processedSessions[session] then continue end
            processedSessions[session] = true

            -- Collect alive party players
            local alivePlayers: { Player } = {}
            for _, p in ipairs(session.Players) do
                local c = p.Character
                if c then
                    local r = c:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local h = c:FindFirstChildOfClass("Humanoid")
                    if r and h and h.Health > 0 then
                        table.insert(alivePlayers, p)
                    end
                end
            end

            if #alivePlayers == 0 then
                -- All party players died or left
                for _, p in ipairs(session.Players) do
                    DungeonService.LeaveDungeon(p)
                end
                continue
            end

            for enemy in pairs(session.AliveEnemies) do
                if not enemy.Parent then continue end

                local enemyRoot = enemy.PrimaryPart or enemy:FindFirstChild("HumanoidRootPart") :: BasePart?
                local enemyHum = enemy:FindFirstChildOfClass("Humanoid")
                if not enemyRoot or not enemyHum or enemyHum.Health <= 0 then continue end

                local enemyPos = enemyRoot.Position
                -- Find closest alive player
                local closestPlayer = alivePlayers[1]
                local closestDist = math.huge
                for _, p in ipairs(alivePlayers) do
                    local c = p.Character
                    if c then
                        local r = c:FindFirstChild("HumanoidRootPart") :: BasePart?
                        if r then
                            local d = (Vector3.new(enemyPos.X, 0, enemyPos.Z) - Vector3.new(r.Position.X, 0, r.Position.Z)).Magnitude
                            if d < closestDist then
                                closestDist = d
                                closestPlayer = p
                            end
                        end
                    end
                end

                local targetChar = closestPlayer.Character
                if not targetChar then continue end

                local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
                local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
                if not targetRoot or not targetHum then continue end

                local playerPos = targetRoot.Position
                -- 1. Movement AI
                if closestDist > 4.5 then
                    enemyHum:MoveTo(playerPos)
                else
                    -- 2. Melee Attack Check (1.5s cooldown)
                    local lastAttack = enemyAttackCooldowns[enemy] or 0
                    if now - lastAttack >= 1.5 then
                        enemyAttackCooldowns[enemy] = now
                        if targetChar:GetAttribute("Invulnerable") ~= true then
                            local dmg = (enemy:GetAttribute("Damage") :: number?) or 10
                            targetHum:TakeDamage(dmg)
                        end
                    end
                end

                -- 3. Boss Telegraph AoE Attack
                local isBoss = enemy:GetAttribute("IsBoss") == true
                if isBoss and now >= session.NextBossAoE then
                    session.NextBossAoE = now + 6.0
                    local randPlayer = alivePlayers[math.random(1, #alivePlayers)]
                    executeBossTelegraphAoE(enemy, randPlayer)
                end
            end
        end
    end)
end

return DungeonService
