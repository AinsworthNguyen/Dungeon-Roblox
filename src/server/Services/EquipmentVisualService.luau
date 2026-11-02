--!strict
--[[
    EquipmentVisualService.luau
    Renders 3D procedural equipment models and radiant rarity auras directly on characters.
    
    Features:
    - 3D Weapon assembly (Handle, Crossguard, Glowing Blade with Trail) welded to RightHand/Right Arm.
    - 3D Armor plate / pauldrons welded to UpperTorso/Torso.
    - 3D Accessory (Halo, Floating Celestial Orb, or Diadem) welded to Head.
    - Dynamic ParticleEmitter Aura around feet/body if equipped gear is Legendary, Mythic, or Secret.
    - Automatic cleanup upon unequip, death, or respawn.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local RarityConfig = require(Shared:WaitForChild("RarityConfig"))
local ItemConfig = require(Shared:WaitForChild("ItemConfig"))

local EquipmentVisualService = {
    Name = "EquipmentVisualService",
    Priority = 8,
}

local VISUALS_FOLDER_NAME = "EquippedVisuals"

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
    return nil
end

--[[
    Clears existing visual gear on character.
]]
local function clearVisuals(character: Model)
    local existingFolder = character:FindFirstChild(VISUALS_FOLDER_NAME)
    if existingFolder then
        existingFolder:Destroy()
    end

    local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
    if hand then
        local grip = hand:FindFirstChild("WeaponGrip")
        if grip then
            grip:Destroy()
        end
    end
end

--[[
    Builds a 3D procedural weapon model attached via Motor6D WeaponGrip.
    Points forward and angled slightly upward (+15 deg) from standard right hand.
]]
local function buildWeaponVisual(itemDef: Types.ItemDefinition, handPart: BasePart, folder: Folder)
    local weaponModel = Instance.new("Model")
    weaponModel.Name = "Weapon"

    -- Remove any previous grip
    local oldGrip = handPart:FindFirstChild("WeaponGrip")
    if oldGrip then oldGrip:Destroy() end

    -- 1. Handle (Hilt) - PrimaryPart
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(0.3, 1.0, 0.3)
    handle.Color = Color3.fromRGB(45, 34, 26)
    handle.Material = Enum.Material.Wood
    handle.CanCollide = false
    handle.Massless = true
    handle.Parent = weaponModel
    weaponModel.PrimaryPart = handle

    -- 2. Motor6D WeaponGrip
    local grip = Instance.new("Motor6D")
    grip.Name = "WeaponGrip"
    grip.Part0 = handPart
    grip.Part1 = handle
    -- Forward-pointing grip with +15 deg upward tilt
    grip.C0 = CFrame.new(0, -0.15, -0.3) * CFrame.Angles(math.rad(-75), 0, 0)
    grip.C1 = CFrame.new(0, 0, 0)
    grip.Parent = handPart

    -- Set initial handle position
    handle.CFrame = handPart.CFrame * grip.C0

    -- 3. Crossguard
    local guard = Instance.new("Part")
    guard.Name = "Crossguard"
    guard.Size = Vector3.new(1.1, 0.22, 0.4)
    guard.Color = Color3.fromRGB(70, 75, 90)
    guard.Material = Enum.Material.Metal
    guard.CanCollide = false
    guard.Massless = true
    guard.CFrame = handle.CFrame * CFrame.new(0, 0.52, 0)
    guard.Parent = weaponModel

    local guardWeld = Instance.new("WeldConstraint")
    guardWeld.Part0 = handle
    guardWeld.Part1 = guard
    guardWeld.Parent = guard

    -- 4. Blade (Anti-Glare: Metal body with Reflectance = 0.2, subtle subdued Neon edge)
    local bladeSize = itemDef.Visual.Size or Vector3.new(0.5, 3.2, 0.15)
    local origC = itemDef.Visual.Color
    local dimmedC = Color3.fromRGB(
        math.clamp(math.round(origC.R * 255 * 0.65), 20, 175),
        math.clamp(math.round(origC.G * 255 * 0.65), 20, 175),
        math.clamp(math.round(origC.B * 255 * 0.65), 20, 175)
    )

    local blade = Instance.new("Part")
    blade.Name = "Blade"
    blade.Size = bladeSize
    blade.Color = dimmedC
    blade.Material = Enum.Material.Metal
    blade.Reflectance = 0.2
    blade.CanCollide = false
    blade.Massless = true
    blade.CFrame = handle.CFrame * CFrame.new(0, 0.52 + bladeSize.Y / 2, 0)
    blade.Parent = weaponModel

    local bladeWeld = Instance.new("WeldConstraint")
    bladeWeld.Part0 = handle
    bladeWeld.Part1 = blade
    bladeWeld.Parent = blade

    -- Subtle Thin Neon Edge
    local edge = Instance.new("Part")
    edge.Name = "BladeEdge"
    edge.Size = Vector3.new(bladeSize.X * 0.25, bladeSize.Y * 0.95, bladeSize.Z * 1.05)
    edge.Color = dimmedC
    edge.Material = Enum.Material.Neon
    edge.CanCollide = false
    edge.Massless = true
    edge.CFrame = blade.CFrame
    edge.Parent = weaponModel

    local edgeWeld = Instance.new("WeldConstraint")
    edgeWeld.Part0 = blade
    edgeWeld.Part1 = edge
    edgeWeld.Parent = edge

    -- 5. Swing Trail
    local att0 = Instance.new("Attachment")
    att0.Name = "TrailTop"
    att0.Position = Vector3.new(0, bladeSize.Y / 2, 0)
    att0.Parent = blade

    local att1 = Instance.new("Attachment")
    att1.Name = "TrailBottom"
    att1.Position = Vector3.new(0, -bladeSize.Y / 2, 0)
    att1.Parent = blade

    local trail = Instance.new("Trail")
    trail.Attachment0 = att0
    trail.Attachment1 = att1
    trail.Color = ColorSequence.new(itemDef.Visual.Color)
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.25),
        NumberSequenceKeypoint.new(1, 1),
    })
    trail.Lifetime = 0.22
    trail.Parent = blade

    weaponModel.Parent = folder
end

--[[
    Builds compact 3D armor: 2 shoulder pauldrons + back shield emblem.
    Leaves avatar clothes, torso, and front 100% visible and unblocked.
]]
local function buildArmorVisual(itemDef: Types.ItemDefinition, torsoPart: BasePart, folder: Folder)
    local armorModel = Instance.new("Model")
    armorModel.Name = "Armor"

    -- 1. Left & Right Shoulder Pauldrons (Compact, Metal)
    local function createPauldron(xOffset: number, name: string): Part
        local pauldron = Instance.new("Part")
        pauldron.Name = name
        pauldron.Size = Vector3.new(0.7, 0.4, 0.8)
        pauldron.Color = itemDef.Visual.Color
        pauldron.Material = Enum.Material.Metal
        pauldron.CanCollide = false
        pauldron.Massless = true
        pauldron.CFrame = torsoPart.CFrame * CFrame.new(xOffset, 0.65, 0)
        pauldron.Parent = armorModel

        local weld = Instance.new("WeldConstraint")
        weld.Part0 = torsoPart
        weld.Part1 = pauldron
        weld.Parent = pauldron
        return pauldron
    end

    createPauldron(-1.15, "PauldronL")
    createPauldron(1.15, "PauldronR")

    -- 2. Small Back Shield Emblem (Behind character only)
    local backEmblem = Instance.new("Part")
    backEmblem.Name = "BackEmblem"
    backEmblem.Size = Vector3.new(0.9, 1.1, 0.2)
    backEmblem.Color = itemDef.Visual.Color
    backEmblem.Material = Enum.Material.Metal
    backEmblem.CanCollide = false
    backEmblem.Massless = true
    backEmblem.CFrame = torsoPart.CFrame * CFrame.new(0, 0.2, 0.65)
    backEmblem.Parent = armorModel

    local sWeld = Instance.new("WeldConstraint")
    sWeld.Part0 = torsoPart
    sWeld.Part1 = backEmblem
    sWeld.Parent = backEmblem

    armorModel.Parent = folder
end

--[[
    Builds a subtle, floating sacred relic behind/above head.
    Low glare (Material.Glass, Transparency 0.25) so character face and hair remain crisp.
]]
local function buildAccessoryVisual(itemDef: Types.ItemDefinition, headPart: BasePart, folder: Folder)
    local accModel = Instance.new("Model")
    accModel.Name = "Accessory"

    local relic = Instance.new("Part")
    relic.Name = "FloatingRelic"
    relic.Shape = Enum.PartType.Cylinder
    relic.Size = Vector3.new(0.18, 1.2, 1.2)
    relic.Color = itemDef.Visual.Color
    relic.Material = Enum.Material.Glass
    relic.Transparency = 0.25
    relic.CanCollide = false
    relic.Massless = true
    relic.CFrame = headPart.CFrame * CFrame.new(0, 1.35, -0.45) * CFrame.Angles(0, 0, math.rad(90))
    relic.Parent = accModel

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = headPart
    weld.Part1 = relic
    weld.Parent = relic

    accModel.Parent = folder
end

--[[
    Spawns radiant particle aura around root if highest rarity is Legendary+.
]]
local function applyRarityAura(rootPart: BasePart, highestRarity: Types.RarityTier, folder: Folder)
    local auraPart = Instance.new("Part")
    auraPart.Name = "AuraEmitterPart"
    auraPart.Size = Vector3.new(1, 1, 1)
    auraPart.Transparency = 1
    auraPart.CanCollide = false
    auraPart.Massless = true
    auraPart.CFrame = rootPart.CFrame * CFrame.new(0, -2.5, 0)
    auraPart.Parent = folder

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = rootPart
    weld.Part1 = auraPart
    weld.Parent = auraPart

    local auraColor = RarityConfig.GetColor(highestRarity)

    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "LegendaryAura"
    emitter.Rate = 12
    emitter.LightEmission = 0.15
    emitter.Lifetime = NumberRange.new(1.0, 1.8)
    emitter.Speed = NumberRange.new(1.5, 3.5)
    emitter.SpreadAngle = Vector2.new(30, 30)
    emitter.Acceleration = Vector3.new(0, 3, 0)
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.4),
        NumberSequenceKeypoint.new(0.6, 0.9),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.Color = ColorSequence.new(auraColor)
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.4),
        NumberSequenceKeypoint.new(1, 1),
    })
    emitter.Parent = auraPart
end

--[[
    Creates and updates 3D dynamic Overhead Rank Tag above player's head.
]]
local function updateOverheadRankTag(character: Model, player: Player, data: Types.PlayerData)
    local head = character:FindFirstChild("Head") :: BasePart?
    if not head then return end

    local tag: BillboardGui
    local existingTag = head:FindFirstChild("OverheadRankTag")
    if existingTag and existingTag:IsA("BillboardGui") then
        tag = existingTag
    else
        local newTag = Instance.new("BillboardGui")
        newTag.Name = "OverheadRankTag"
        newTag.Size = UDim2.new(0, 260, 0, 72)
        newTag.StudsOffset = Vector3.new(0, 3.2, 0)
        newTag.AlwaysOnTop = true
        newTag.MaxDistance = 80
        newTag.Adornee = head
        newTag.Parent = head

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.VerticalAlignment = Enum.VerticalAlignment.Center
        layout.Padding = UDim.new(0, 2)
        layout.Parent = newTag

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Name = "RankTitle"
        titleLbl.Size = UDim2.new(1, 0, 0, 22)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.TextSize = 13
        titleLbl.LayoutOrder = 1
        titleLbl.Parent = newTag

        local titleStroke = Instance.new("UIStroke")
        titleStroke.Thickness = 1.6
        titleStroke.Color = Color3.fromRGB(12, 14, 20)
        titleStroke.Parent = titleLbl

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Name = "PlayerName"
        nameLbl.Size = UDim2.new(1, 0, 0, 22)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextColor3 = Color3.fromRGB(245, 245, 255)
        nameLbl.TextSize = 14
        nameLbl.LayoutOrder = 2
        nameLbl.Parent = newTag

        local nameStroke = Instance.new("UIStroke")
        nameStroke.Thickness = 1.6
        nameStroke.Color = Color3.fromRGB(12, 14, 20)
        nameStroke.Parent = nameLbl

        local cpLbl = Instance.new("TextLabel")
        cpLbl.Name = "CPLabel"
        cpLbl.Size = UDim2.new(1, 0, 0, 20)
        cpLbl.BackgroundTransparency = 1
        cpLbl.Font = Enum.Font.GothamBold
        cpLbl.TextColor3 = Color3.fromRGB(255, 180, 50)
        cpLbl.TextSize = 12
        cpLbl.LayoutOrder = 3
        cpLbl.Parent = newTag

        local cpStroke = Instance.new("UIStroke")
        cpStroke.Thickness = 1.4
        cpStroke.Color = Color3.fromRGB(12, 14, 20)
        cpStroke.Parent = cpLbl

        tag = newTag
    end

    local titleLbl = tag:FindFirstChild("RankTitle") :: TextLabel?
    local nameLbl = tag:FindFirstChild("PlayerName") :: TextLabel?
    local cpLbl = tag:FindFirstChild("CPLabel") :: TextLabel?

    local ds = getDataService()
    local totalStats = if ds then ds.GetTotalStats(player) else { Damage = 10, MaxHP = 100, CritChance = 0.05, LuckBonus = 1.0 }
    local cp = math.round((totalStats.Damage * 3.5) + (totalStats.MaxHP * 1.0) + (totalStats.CritChance * 600) + (totalStats.LuckBonus * 80))

    local rebirths = data.Rebirths or 0
    local titleText = "[🌱 Novice]"
    local titleColor = Color3.fromRGB(160, 220, 140)

    if rebirths >= 3 then
        titleText = string.format("[🌌 Celestial God - Rebirth %d]", rebirths)
        titleColor = Color3.fromRGB(255, 60, 140)
    elseif rebirths == 2 then
        titleText = "[⚡ Mythic Overlord - Rebirth II]"
        titleColor = Color3.fromRGB(180, 80, 255)
    elseif rebirths == 1 then
        titleText = "[🔥 Awakened God - Rebirth I]"
        titleColor = Color3.fromRGB(255, 140, 40)
    else
        if cp >= 3000 then
            titleText = "[👑 Warlord]"
            titleColor = Color3.fromRGB(255, 215, 60)
        elseif cp >= 1000 then
            titleText = "[🛡️ Champion]"
            titleColor = Color3.fromRGB(170, 110, 255)
        elseif cp >= 200 then
            titleText = "[⚔️ Slayer]"
            titleColor = Color3.fromRGB(60, 190, 255)
        end
    end

    if titleLbl then
        titleLbl.Text = titleText
        titleLbl.TextColor3 = titleColor
    end

    if nameLbl then
        nameLbl.Text = string.format("%s  [Lv. %d]", player.DisplayName or player.Name, data.Level)
    end

    if cpLbl then
        cpLbl.Text = string.format("⚔️ %s CP", tostring(cp))
    end
end

--------------------------------------------------------------------------------
-- PUBLIC UPDATE API
--------------------------------------------------------------------------------

function EquipmentVisualService.UpdateVisuals(player: Player)
    local character = player.Character
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local DataService = getDataService()
    if not DataService then return end

    local data = DataService.GetData(player)
    if not data then return end

    -- Update 3D Overhead Rank Tag (Rank, Level, CP)
    updateOverheadRankTag(character, player, data)

    clearVisuals(character)

    local visualsFolder = Instance.new("Folder")
    visualsFolder.Name = VISUALS_FOLDER_NAME
    visualsFolder.Parent = character

    local handPart = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
    local torsoPart = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    local headPart = character:FindFirstChild("Head")
    local rootPart = character:FindFirstChild("HumanoidRootPart")

    local highestRank = 0
    local highestRarity: Types.RarityTier = "Common"

    -- 1. Weapon Visual
    local wpnUUID = data.Equipped.Weapon
    if wpnUUID and handPart and handPart:IsA("BasePart") then
        local invItem = data.Inventory[wpnUUID]
        if invItem then
            local itemDef = ItemConfig.Get(invItem.ItemId)
            if itemDef then
                buildWeaponVisual(itemDef, handPart, visualsFolder)
                local tierData = RarityConfig.Get(itemDef.Rarity)
                local rank = if tierData then tierData.Rank else 1
                if rank > highestRank then
                    highestRank = rank
                    highestRarity = itemDef.Rarity
                end
            end
        end
    end

    -- 2. Armor Visual
    local armUUID = data.Equipped.Armor
    if armUUID and torsoPart and torsoPart:IsA("BasePart") then
        local invItem = data.Inventory[armUUID]
        if invItem then
            local itemDef = ItemConfig.Get(invItem.ItemId)
            if itemDef then
                buildArmorVisual(itemDef, torsoPart, visualsFolder)
                local tierData = RarityConfig.Get(itemDef.Rarity)
                local rank = if tierData then tierData.Rank else 1
                if rank > highestRank then
                    highestRank = rank
                    highestRarity = itemDef.Rarity
                end
            end
        end
    end

    -- 3. Accessory Visual
    local accUUID = data.Equipped.Accessory
    if accUUID and headPart and headPart:IsA("BasePart") then
        local invItem = data.Inventory[accUUID]
        if invItem then
            local itemDef = ItemConfig.Get(invItem.ItemId)
            if itemDef then
                buildAccessoryVisual(itemDef, headPart, visualsFolder)
                local tierData = RarityConfig.Get(itemDef.Rarity)
                local rank = if tierData then tierData.Rank else 1
                if rank > highestRank then
                    highestRank = rank
                    highestRarity = itemDef.Rarity
                end
            end
        end
    end

    -- 4. Legendary+ Radiant Aura Effect (Rank 5 = Legendary, 6 = Mythic, 7 = Secret)
    if highestRank >= 5 and rootPart and rootPart:IsA("BasePart") then
        applyRarityAura(rootPart, highestRarity, visualsFolder)
    end
end

--------------------------------------------------------------------------------
-- SERVICE LIFECYCLE
--------------------------------------------------------------------------------

function EquipmentVisualService:Init()
    print("[EquipmentVisualService] Initializing 3D equipment rendering hooks...")

    Players.PlayerAdded:Connect(function(player: Player)
        player.CharacterAdded:Connect(function(character: Model)
            character:WaitForChild("HumanoidRootPart", 5)
            task.wait(0.25)
            EquipmentVisualService.UpdateVisuals(player)
        end)
    end)
end

function EquipmentVisualService:Start()
    -- Hook into existing characters
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            task.spawn(function()
                EquipmentVisualService.UpdateVisuals(player)
            end)
        end
        player.CharacterAdded:Connect(function()
            task.wait(0.25)
            EquipmentVisualService.UpdateVisuals(player)
        end)
    end

    -- Periodic check / listener
    task.spawn(function()
        while true do
            task.wait(2.0)
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then
                    EquipmentVisualService.UpdateVisuals(player)
                end
            end
        end
    end)
end

return EquipmentVisualService
