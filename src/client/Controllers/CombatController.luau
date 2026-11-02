--!strict
--[[
    CombatController.luau
    Client combat controller handling input clicks/keybinds, weapon swinging animations,
    skill VFX (Whirlwind, Meteor), and dynamic Floating Damage Popups (DamagePopup).
    
    Standards:
    - Pure procedural creation & TweenService animations.
    - Zero interference with UI clicks or open modal windows.
    - Responsive M1 (0.35s rhythm), Skill E/Q (Whirlwind 5s), Skill R (Meteor 10s).
    - Floating damage numbers with distinctive Critical Strike punch.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SoundManager = require(Shared:WaitForChild("SoundManager"))

local CombatController = {
    Name = "CombatController",
    Priority = 15,
}

local localPlayer = Players.LocalPlayer

-- Combat state
local m1Step = 0
local lastM1Time = 0
local lastWhirlwindTime = 0
local lastMeteorTime = 0
local lastDashTime = 0
local lastHealTime = 0

-- Lazy accessor for UIController
local function getUIController(): any
    local Controllers = script.Parent
    local uiModule = Controllers:FindFirstChild("UIController")
    if uiModule then
        return (require :: any)(uiModule)
    end
    return nil
end

--[[
    Creates a floating damage number billboard in the 3D world.
]]
local function spawnDamagePopup(payload: Types.CombatFeedbackData)
    local jitter = Vector3.new(
        math.random(-12, 12) / 10,
        2.2 + math.random(0, 10) / 10,
        math.random(-12, 12) / 10
    )
    local spawnPos = payload.Position + jitter

    -- Temporary visual anchor
    local anchor = Instance.new("Part")
    anchor.Name = "DamageAnchor"
    anchor.Size = Vector3.new(0.1, 0.1, 0.1)
    anchor.CFrame = CFrame.new(spawnPos)
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.Transparency = 1
    anchor.Parent = Workspace

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "DamageBillboard"
    billboard.Size = UDim2.new(0, 160, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 0, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 80
    billboard.Adornee = anchor
    billboard.Parent = anchor

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1

    local stroke = Instance.new("UIStroke")
    stroke.Parent = label

    if payload.SkillType == "Heal" then
        label.Font = Enum.Font.GothamBlack
        label.Text = string.format("💚 +%d HP", payload.Damage)
        label.TextSize = 20
        label.TextColor3 = Color3.fromRGB(80, 255, 140)
        stroke.Color = Color3.fromRGB(15, 60, 30)
        stroke.Thickness = 2.0
    elseif payload.IsCrit then
        label.Font = Enum.Font.GothamBlack
        label.Text = string.format("💥 CRIT! -%d", payload.Damage)
        label.TextSize = 22
        label.TextColor3 = Color3.fromRGB(255, 185, 30)
        stroke.Color = Color3.fromRGB(180, 40, 10)
        stroke.Thickness = 2.2
    else
        label.Font = Enum.Font.GothamBold
        label.Text = string.format("-%d", payload.Damage)
        label.TextSize = 17
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        stroke.Color = Color3.fromRGB(18, 20, 28)
        stroke.Thickness = 1.8
    end

    label.Parent = billboard

    -- Float upward animation
    local tweenInfo = TweenInfo.new(0.65, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    local floatTween = TweenService:Create(billboard, tweenInfo, {
        StudsOffset = Vector3.new(0, 3.2, 0)
    })
    floatTween:Play()

    -- Fade out
    task.delay(0.35, function()
        local fadeInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        TweenService:Create(label, fadeInfo, { TextTransparency = 1 }):Play()
        TweenService:Create(stroke, fadeInfo, { Transparency = 1 }):Play()
    end)

    task.delay(0.7, function()
        anchor:Destroy()
    end)
end

--[[
    Spawns a glowing weapon slash arc in front of the character.
]]
local function playSlashVFX(character: Model, comboStep: number)
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then return end

    local arc = Instance.new("Part")
    arc.Name = "SlashArc"
    arc.Shape = Enum.PartType.Cylinder
    arc.Size = Vector3.new(0.1, 4.5, 4.5)
    arc.Material = Enum.Material.Neon
    arc.Color = if comboStep == 3 then Color3.fromRGB(255, 215, 60) else Color3.fromRGB(240, 245, 255)
    arc.Anchored = true
    arc.CanCollide = false
    arc.Transparency = 0.2

    local angleY = if comboStep == 1 then math.rad(-35) elseif comboStep == 2 then math.rad(35) else 0
    arc.CFrame = root.CFrame * CFrame.new(0, 0, -3.2) * CFrame.Angles(0, angleY, math.rad(90))
    arc.Parent = Workspace

    local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(arc, tweenInfo, {
        Size = Vector3.new(0.05, 8.5, 8.5),
        Transparency = 1,
    })
    tween:Play()
    tween.Completed:Connect(function()
        arc:Destroy()
    end)
end

--[[
    Plays the Whirlwind 360 spinning visual wave.
]]
local function playWhirlwindVFX(character: Model)
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then return end

    local ring = Instance.new("Part")
    ring.Name = "WhirlwindRing"
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.2, 6, 6)
    ring.Material = Enum.Material.Neon
    ring.Color = Color3.fromRGB(75, 190, 255)
    ring.Anchored = true
    ring.CanCollide = false
    ring.Transparency = 0.25
    ring.CFrame = root.CFrame * CFrame.Angles(0, 0, math.rad(90))
    ring.Parent = Workspace

    local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(ring, tweenInfo, {
        Size = Vector3.new(0.1, 28, 28),
        Transparency = 1,
    })
    tween:Play()
    tween.Completed:Connect(function()
        ring:Destroy()
    end)
end

--[[
    Plays the Meteor ground impact shockwave.
]]
local function playMeteorVFX(character: Model)
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then return end

    local impactPos = root.CFrame * CFrame.new(0, -2, -7.0)

    local blast = Instance.new("Part")
    blast.Name = "MeteorBlast"
    blast.Shape = Enum.PartType.Cylinder
    blast.Size = Vector3.new(0.4, 4, 4)
    blast.Material = Enum.Material.Neon
    blast.Color = Color3.fromRGB(255, 120, 25)
    blast.Anchored = true
    blast.CanCollide = false
    blast.Transparency = 0.1
    blast.CFrame = impactPos * CFrame.Angles(0, 0, math.rad(90))
    blast.Parent = Workspace

    local tweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    local tween = TweenService:Create(blast, tweenInfo, {
        Size = Vector3.new(0.2, 34, 34),
        Transparency = 1,
    })
    tween:Play()
    tween.Completed:Connect(function()
        blast:Destroy()
    end)
end

-- Procedural Transform animation state for AvatarJointUpgrade compliance
local activeSwingStartTime = 0
local activeSwingDuration = 0
local activeRecoverDuration = 0
local activeTargetArm = CFrame.identity
local activeTargetGrip = CFrame.identity

--[[
    Performs an instant client-side range check against nearby enemies or training dummies
    to trigger frame-perfect Hit-feel audio (0ms network delay).
]]
local function checkTargetInRange(hitCenter: Vector3, maxRadius: number): boolean
    local char = localPlayer.Character
    local dummyFolder = Workspace:FindFirstChild("TrainingDummies")
    if dummyFolder then
        for _, child in ipairs(dummyFolder:GetChildren()) do
            if child:IsA("Model") and child ~= char then
                local root = child.PrimaryPart or child:FindFirstChild("HumanoidRootPart") or child:FindFirstChild("Torso")
                if root and root:IsA("BasePart") then
                    if (root.Position - hitCenter).Magnitude <= maxRadius then
                        return true
                    end
                end
            end
        end
    end

    local enemiesFolder = Workspace:FindFirstChild("Enemies")
    if enemiesFolder then
        for _, child in ipairs(enemiesFolder:GetChildren()) do
            if child:IsA("Model") and child ~= char then
                local hum = child:FindFirstChildOfClass("Humanoid")
                local root = child.PrimaryPart or child:FindFirstChild("HumanoidRootPart") or child:FindFirstChild("Torso")
                if root and root:IsA("BasePart") then
                    if not hum or hum.Health > 0 then
                        if (root.Position - hitCenter).Magnitude <= maxRadius then
                            return true
                        end
                    end
                end
            end
        end
    end

    return false
end

--[[
    Skeletal weapon swing animation via RightShoulder and WeaponGrip Motor6D Transform.
    Uses RunService.Stepped to blend procedural swing transforms without modifying read-only C0.
    Step 1: Slash right-to-left.
    Step 2: Reverse slash left-to-right.
    Step 3: High overhead power smash downward.
]]
local function animateWeaponSwing(character: Model, comboStep: number)
    activeSwingStartTime = os.clock()

    if comboStep == 1 then
        -- Nhịp 1: Chém chéo từ phải sang trái
        activeTargetArm = CFrame.Angles(math.rad(30), math.rad(-50), math.rad(-25))
        activeTargetGrip = CFrame.Angles(math.rad(25), math.rad(-30), math.rad(-15))
        activeSwingDuration = 0.10
        activeRecoverDuration = 0.12
    elseif comboStep == 2 then
        -- Nhịp 2: Chém vòng ngược lại từ trái sang phải
        activeTargetArm = CFrame.Angles(math.rad(25), math.rad(55), math.rad(20))
        activeTargetGrip = CFrame.Angles(math.rad(-20), math.rad(35), math.rad(15))
        activeSwingDuration = 0.10
        activeRecoverDuration = 0.12
    else
        -- Nhịp 3: Giơ kiếm cao lên rồi bổ mạnh từ trên xuống phía trước
        activeTargetArm = CFrame.Angles(math.rad(95), math.rad(-10), math.rad(10))
        activeTargetGrip = CFrame.Angles(math.rad(45), 0, 0)
        activeSwingDuration = 0.12
        activeRecoverDuration = 0.14
    end

    -- Instant 0ms sword swing sound
    SoundManager.Play("SwordSwing")
end

--[[
    Triggers M1 basic attack sequence.
]]
function CombatController.TriggerM1()
    local character = localPlayer.Character
    if not character then return end

    local now = os.clock()
    if now - lastM1Time < Constants.COMBAT.M1_COOLDOWN then
        return
    end

    if now - lastM1Time > Constants.COMBAT.M1_COMBO_RESET_TIME then
        m1Step = 1
    else
        m1Step = (m1Step % 3) + 1
    end
    lastM1Time = now

    -- Update UI
    local ui = getUIController()
    if ui and ui.SkillBar then
        ui.SkillBar.SetM1Combo(m1Step)
    end

    -- Play local visual animation & slash arc
    animateWeaponSwing(character, m1Step)
    playSlashVFX(character, m1Step)

    -- Client-side Hit Prediction: Play HitSlash at frame of impact (0.06s)
    local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if rootPart then
        local forwardPoint = (rootPart.CFrame * CFrame.new(0, 0, -3.5)).Position
        if checkTargetInRange(forwardPoint, 5.5) then
            task.delay(0.06, function()
                SoundManager.Play("HitSlash")
            end)
        end
    end

    -- Notify Server
    local attackEvent = Remotes.GetEvent(Constants.REMOTE_EVENTS.PerformAttack)
    attackEvent:FireServer("M1")
end

--[[
    Triggers Skill E / Q (Whirlwind Slash).
]]
function CombatController.TriggerWhirlwind()
    local character = localPlayer.Character
    if not character then return end

    local now = os.clock()
    if now - lastWhirlwindTime < Constants.COMBAT.WHIRLWIND_COOLDOWN then
        return
    end
    lastWhirlwindTime = now

    -- Update UI Cooldown
    local ui = getUIController()
    if ui and ui.SkillBar then
        ui.SkillBar.StartCooldown("Whirlwind", Constants.COMBAT.WHIRLWIND_COOLDOWN)
    end

    -- Play Whirlwind SFX & Arm Swing immediately
    SoundManager.Play("Explosion", nil, 0.85)
    activeSwingStartTime = os.clock()
    activeTargetArm = CFrame.Angles(math.rad(80), math.rad(-60), math.rad(-15))
    activeTargetGrip = CFrame.Angles(math.rad(25), 0, 0)
    activeSwingDuration = 0.16
    activeRecoverDuration = 0.28
    playWhirlwindVFX(character)

    -- Client-side Hit Prediction in 14 studs radius
    local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if rootPart and checkTargetInRange(rootPart.Position, Constants.COMBAT.WHIRLWIND_RADIUS) then
        task.delay(0.06, function()
            SoundManager.Play("HitSlash")
        end)
    end

    -- Notify Server
    local attackEvent = Remotes.GetEvent(Constants.REMOTE_EVENTS.PerformAttack)
    attackEvent:FireServer("Whirlwind")
end

--[[
    Triggers Skill R (Meteor Strike).
]]
function CombatController.TriggerMeteor()
    local character = localPlayer.Character
    if not character then return end

    local now = os.clock()
    if now - lastMeteorTime < Constants.COMBAT.METEOR_COOLDOWN then
        return
    end
    lastMeteorTime = now

    -- Update UI Cooldown
    local ui = getUIController()
    if ui and ui.SkillBar then
        ui.SkillBar.StartCooldown("Meteor", Constants.COMBAT.METEOR_COOLDOWN)
    end

    -- Play leap / slam VFX & Arm Raise immediately
    SoundManager.Play("Explosion", nil, 1.25)
    activeSwingStartTime = os.clock()
    activeTargetArm = CFrame.Angles(math.rad(135), math.rad(-10), math.rad(10))
    activeTargetGrip = CFrame.Angles(math.rad(35), 0, 0)
    activeSwingDuration = 0.20
    activeRecoverDuration = 0.35

    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if root then
        root.AssemblyLinearVelocity = Vector3.new(0, 16, 0)
        local impactPoint = (root.CFrame * CFrame.new(0, 0, -8.0)).Position
        if checkTargetInRange(impactPoint, Constants.COMBAT.METEOR_RADIUS) then
            task.delay(0.22, function()
                SoundManager.Play("HitSlash")
            end)
        end
    end

    task.delay(0.2, function()
        playMeteorVFX(character)
    end)

    -- Notify Server
    local attackEvent = Remotes.GetEvent(Constants.REMOTE_EVENTS.PerformAttack)
    attackEvent:FireServer("Meteor")
end

--[[
    Triggers Dash / Dodge (Shift / F) with speed impulse, trail VFX, and server I-Frames.
]]
function CombatController.TriggerDash()
    local character = localPlayer.Character
    if not character then return end

    local now = os.clock()
    if now - lastDashTime < Constants.COMBAT.DASH_COOLDOWN then
        return
    end
    lastDashTime = now

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not humanoid or not root or humanoid.Health <= 0 then return end

    -- Update UI Cooldown
    local ui = getUIController()
    if ui and ui.SkillBar then
        ui.SkillBar.StartCooldown("Dash", Constants.COMBAT.DASH_COOLDOWN)
    end

    -- Determine dash direction
    local moveDir = humanoid.MoveDirection
    if moveDir.Magnitude < 0.1 then
        moveDir = root.CFrame.LookVector
    else
        moveDir = moveDir.Unit
    end

    -- Play Dash SFX & VFX
    SoundManager.Play("Dash")

    -- 1. Wind burst ring
    local ring = Instance.new("Part")
    ring.Name = "DashRing"
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.2, 4, 4)
    ring.CFrame = root.CFrame * CFrame.Angles(0, 0, math.rad(90))
    ring.Color = Color3.fromRGB(150, 225, 255)
    ring.Material = Enum.Material.Neon
    ring.Anchored = true
    ring.CanCollide = false
    ring.Parent = Workspace

    TweenService:Create(ring, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.1, 12, 12),
        Transparency = 1,
    }):Play()

    task.delay(0.25, function()
        ring:Destroy()
    end)

    -- 2. Wind blur trail
    local a0 = Instance.new("Attachment")
    a0.Position = Vector3.new(0, 1.2, 0)
    a0.Parent = root

    local a1 = Instance.new("Attachment")
    a1.Position = Vector3.new(0, -1.2, 0)
    a1.Parent = root

    local trail = Instance.new("Trail")
    trail.Attachment0 = a0
    trail.Attachment1 = a1
    trail.Lifetime = 0.2
    trail.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 240, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 140, 255)),
    })
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1.0),
    })
    trail.Parent = root

    task.delay(0.25, function()
        trail:Destroy()
        a0:Destroy()
        a1:Destroy()
    end)

    -- 3. High-velocity directional dash impulse
    local dashVelocity = moveDir * (Constants.COMBAT.DASH_DISTANCE / Constants.COMBAT.DASH_DURATION)
    local bv = Instance.new("BodyVelocity")
    bv.Name = "DashImpulse"
    bv.MaxForce = Vector3.new(1e5, 0, 1e5)
    bv.Velocity = dashVelocity
    bv.Parent = root

    task.delay(Constants.COMBAT.DASH_DURATION, function()
        if bv.Parent then
            bv:Destroy()
        end
    end)

    -- Notify Server for authoritative I-Frames
    local attackEvent = Remotes.GetEvent(Constants.REMOTE_EVENTS.PerformAttack)
    attackEvent:FireServer("Dash")
end

--[[
    Triggers Heal Potion (H / 1) instantly recovering 35% MaxHP.
]]
function CombatController.TriggerHeal()
    local character = localPlayer.Character
    if not character then return end

    local now = os.clock()
    if now - lastHealTime < Constants.COMBAT.HEAL_COOLDOWN then
        return
    end
    lastHealTime = now

    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then return end

    -- Update UI Cooldown
    local ui = getUIController()
    if ui and ui.SkillBar then
        ui.SkillBar.StartCooldown("Heal", Constants.COMBAT.HEAL_COOLDOWN)
    end

    -- Play Heal SFX & VFX
    SoundManager.Play("Heal")

    -- Rising emerald healing circle
    local ring = Instance.new("Part")
    ring.Name = "HealRing"
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.3, 5, 5)
    ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
    ring.Color = Color3.fromRGB(80, 255, 140)
    ring.Material = Enum.Material.Neon
    ring.Anchored = true
    ring.CanCollide = false
    ring.Parent = Workspace

    TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.1, 10, 10),
        CFrame = CFrame.new(root.Position + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
        Transparency = 1,
    }):Play()

    task.delay(0.5, function()
        ring:Destroy()
    end)

    -- Notify Server
    local attackEvent = Remotes.GetEvent(Constants.REMOTE_EVENTS.PerformAttack)
    attackEvent:FireServer("Heal")
end

function CombatController:Init()
    print("[CombatController] Initializing client combat inputs and VFX listeners...")

    -- 1. Mouse Click & Keybind Listeners
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end

        local ui = getUIController()
        if ui and typeof(ui.IsAnyModalOpen) == "function" and ui.IsAnyModalOpen() then
            return -- Do not swing while inspecting inventory or settings
        end

        if localPlayer:GetAttribute("InPartyRoom") == true then
            return -- Locked inside party room, disable attacks and dash
        end

        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            CombatController.TriggerM1()
        elseif input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Q then
            CombatController.TriggerWhirlwind()
        elseif input.KeyCode == Enum.KeyCode.R then
            CombatController.TriggerMeteor()
        elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.F then
            CombatController.TriggerDash()
        elseif input.KeyCode == Enum.KeyCode.H or input.KeyCode == Enum.KeyCode.One then
            CombatController.TriggerHeal()
        end
    end)

    -- 2. Combat Feedback Remote Listener (Damage Popups & Hit VFX)
    local feedbackRemote = Remotes.GetEvent(Constants.REMOTE_EVENTS.CombatFeedback)
    feedbackRemote.OnClientEvent:Connect(function(payload: any)
        if payload and typeof(payload.Position) == "Vector3" and typeof(payload.Damage) == "number" then
            spawnDamagePopup(payload :: Types.CombatFeedbackData)
        end
    end)

    -- 3. Procedural Weapon Swing via Motor6D.Transform on Stepped
    RunService.Stepped:Connect(function()
        local now = os.clock()
        local elapsed = now - activeSwingStartTime
        local totalDur = activeSwingDuration + activeRecoverDuration

        if elapsed >= totalDur then return end

        local curArmOffset: CFrame
        local curGripOffset: CFrame

        if elapsed <= activeSwingDuration then
            local alpha = math.clamp(elapsed / activeSwingDuration, 0, 1)
            local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            curArmOffset = CFrame.identity:Lerp(activeTargetArm, eased)
            curGripOffset = CFrame.identity:Lerp(activeTargetGrip, eased)
        else
            local recElapsed = elapsed - activeSwingDuration
            local alpha = math.clamp(recElapsed / activeRecoverDuration, 0, 1)
            local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            curArmOffset = activeTargetArm:Lerp(CFrame.identity, eased)
            curGripOffset = activeTargetGrip:Lerp(CFrame.identity, eased)
        end

        local char = localPlayer.Character
        if not char then return end

        -- RightShoulder (Arm)
        local rightUpperArm = char:FindFirstChild("RightUpperArm")
        local shoulder = if rightUpperArm then (rightUpperArm:FindFirstChild("RightShoulder") :: Motor6D?) else nil
        if not shoulder then
            local torso = char:FindFirstChild("Torso")
            if torso then
                shoulder = (torso:FindFirstChild("Right Shoulder") or torso:FindFirstChild("RightShoulder")) :: Motor6D?
            end
        end

        if shoulder then
            shoulder.Transform = shoulder.Transform * curArmOffset
        end

        -- WeaponGrip (Sword tilt)
        local rightHand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
        if rightHand then
            local grip = rightHand:FindFirstChild("WeaponGrip") :: Motor6D?
            if grip then
                grip.Transform = curGripOffset
            end
        end
    end)
end

function CombatController:Start()
    print("[CombatController] Combat Controller active. M1 to attack, Q/E for Whirlwind, R for Meteor.")
end

return CombatController
