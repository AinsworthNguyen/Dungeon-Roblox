--!strict
--[[
    InventoryView.luau
    Full Dark Fantasy Inventory & Equipment Modal.
    
    Structure:
    - Left Column: 3 Equipped Slots (Weapon, Armor, Accessory) + "✨ Equip Best" button.
    - Right Area: 50-slot grid layout with scrolling and rarity-tinted item boxes.
    - Detail Drawer: Item Inspection panel with stats breakdown, Enchant Level, Quality %,
      and action buttons: [Equip/Unequip], [Upgrade (+10%)], [Sell for Gold].
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Constants = require(Shared:WaitForChild("Constants"))
local RarityConfig = require(Shared:WaitForChild("RarityConfig"))
local ItemConfig = require(Shared:WaitForChild("ItemConfig"))
local TraitConfig = require(Shared:WaitForChild("TraitConfig"))

local UITheme = require(script.Parent.UITheme)

local InventoryView = {}

local modalFrame: Frame? = nil
local gridContainer: ScrollingFrame? = nil
local equippedSlots: { [string]: Frame } = {}

-- Selected item state
local selectedUUID: string? = nil

-- Callbacks
local callbacksRef: {
    OnEquip: (uuid: string) -> (),
    OnUnequip: (slot: Types.ItemSlot) -> (),
    OnEquipBest: () -> (),
    OnUpgrade: (uuid: string) -> (),
    OnSell: (uuid: string) -> (),
    OnRerollQuality: (uuid: string) -> (),
    OnRerollTrait: (uuid: string) -> (),
}? = nil

-- Detail Panel UI elements
local detailName: TextLabel? = nil
local detailRarity: TextLabel? = nil
local detailStats: TextLabel? = nil
local detailQualityLabel: TextLabel? = nil
local detailTraitLabel: TextLabel? = nil
local detailActionBtn: TextButton? = nil
local detailUpgradeBtn: TextButton? = nil
local detailRerollQualityBtn: TextButton? = nil
local detailRerollTraitBtn: TextButton? = nil
local detailSellBtn: TextButton? = nil

--[[
    Toggles the modal visibility.
]]
function InventoryView.Toggle(isOpen: boolean?)
    local frame = modalFrame
    if not frame then return end

    local targetOpen = if isOpen ~= nil then isOpen else not frame.Visible
    if targetOpen then
        frame.Visible = true
        frame.Position = UDim2.new(0.5, 0, 0.55, 0)
        TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, 0, 0.5, 0)
        }):Play()
    else
        local tween = TweenService:Create(frame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, 0, 0.55, 0)
        })
        tween:Play()
        tween.Completed:Connect(function()
            if modalFrame then modalFrame.Visible = false end
        end)
    end
end

function InventoryView.IsOpen(): boolean
    local frame = modalFrame
    return if frame then frame.Visible else false
end

--[[
    Builds the complete Inventory Modal.
]]
function InventoryView.Build(parent: ScreenGui, callbacks: {
    OnEquip: (uuid: string) -> (),
    OnUnequip: (slot: Types.ItemSlot) -> (),
    OnEquipBest: () -> (),
    OnUpgrade: (uuid: string) -> (),
    OnSell: (uuid: string) -> (),
    OnRerollQuality: (uuid: string) -> (),
    OnRerollTrait: (uuid: string) -> (),
})
    callbacksRef = callbacks

    local frame = UITheme.CreatePanel({
        Name = "InventoryModal",
        Size = UDim2.new(0, 780, 0, 480),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Constants.THEME.BACKGROUND_DARK,
        StrokeColor = Constants.THEME.STROKE_DEFAULT,
        StrokeThickness = 2.0,
        CornerRadius = UDim.new(0, 16),
        Parent = parent,
    })
    frame.Visible = false
    frame.ZIndex = 30
    modalFrame = frame

    -- Modal Header
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 48)
    header.BackgroundTransparency = 1
    header.ZIndex = 31
    header.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.new(0, 20, 0, 0)
    title.BackgroundTransparency = 1
    title.Font = Constants.THEME.FONT_TITLE
    title.Text = "INVENTORY & EQUIPMENT"
    title.TextColor3 = Constants.THEME.TEXT_PRIMARY
    title.TextSize = 17
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 32
    title.Parent = header

    -- Close Button [X]
    local closeBtn = UITheme.CreateButton({
        Name = "CloseButton",
        Text = "X",
        Size = UDim2.new(0, 32, 0, 32),
        Position = UDim2.new(1, -44, 0, 8),
        BackgroundColor3 = Color3.fromRGB(35, 40, 60),
        TextColor3 = Color3.fromRGB(255, 120, 120),
        TextSize = 16,
        Parent = header,
        OnClick = function()
            InventoryView.Toggle(false)
        end,
    })
    closeBtn.ZIndex = 32

    ----------------------------------------------------------------------------
    -- LEFT COLUMN: EQUIPPED GEAR (Weapon, Armor, Accessory)
    ----------------------------------------------------------------------------
    local leftCol = Instance.new("Frame")
    leftCol.Name = "LeftColumn"
    leftCol.Size = UDim2.new(0, 210, 1, -64)
    leftCol.Position = UDim2.new(0, 18, 0, 52)
    leftCol.BackgroundColor3 = Constants.THEME.SURFACE_PANEL
    leftCol.BorderSizePixel = 0
    leftCol.ZIndex = 31
    leftCol.Parent = frame

    local leftCorner = Instance.new("UICorner")
    leftCorner.CornerRadius = UDim.new(0, 10)
    leftCorner.Parent = leftCol

    local leftStroke = Instance.new("UIStroke")
    leftStroke.Color = Constants.THEME.STROKE_DEFAULT
    leftStroke.Thickness = 1.2
    leftStroke.Parent = leftCol

    local equippedTitle = Instance.new("TextLabel")
    equippedTitle.Size = UDim2.new(1, 0, 0, 30)
    equippedTitle.BackgroundTransparency = 1
    equippedTitle.Font = Constants.THEME.FONT_TITLE
    equippedTitle.Text = "EQUIPPED GEAR"
    equippedTitle.TextColor3 = Color3.fromRGB(160, 175, 210)
    equippedTitle.TextSize = 13
    equippedTitle.ZIndex = 32
    equippedTitle.Parent = leftCol

    local function createEquipSlot(slotName: Types.ItemSlot, yPos: number): Frame
        local slotFrame = Instance.new("Frame")
        slotFrame.Name = slotName .. "Slot"
        slotFrame.Size = UDim2.new(1, -20, 0, 80)
        slotFrame.Position = UDim2.new(0, 10, 0, yPos)
        slotFrame.BackgroundColor3 = Color3.fromRGB(17, 20, 30)
        slotFrame.BorderSizePixel = 0
        slotFrame.ZIndex = 32
        slotFrame.Parent = leftCol

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = slotFrame

        local stroke = Instance.new("UIStroke")
        stroke.Name = "SlotStroke"
        stroke.Color = Constants.THEME.STROKE_DEFAULT
        stroke.Thickness = 1.2
        stroke.Parent = slotFrame

        local slotTag = Instance.new("TextLabel")
        slotTag.Name = "SlotTag"
        slotTag.Size = UDim2.new(1, -12, 0, 18)
        slotTag.Position = UDim2.new(0, 8, 0, 6)
        slotTag.BackgroundTransparency = 1
        slotTag.Font = Constants.THEME.FONT_BODY
        slotTag.Text = string.upper(slotName)
        slotTag.TextColor3 = Constants.THEME.TEXT_MUTED
        slotTag.TextSize = 11
        slotTag.TextXAlignment = Enum.TextXAlignment.Left
        slotTag.ZIndex = 33
        slotTag.Parent = slotFrame

        local itemName = Instance.new("TextLabel")
        itemName.Name = "ItemName"
        itemName.Size = UDim2.new(1, -12, 0, 26)
        itemName.Position = UDim2.new(0, 8, 0, 26)
        itemName.BackgroundTransparency = 1
        itemName.Font = Constants.THEME.FONT_TITLE
        itemName.Text = "[Empty Slot]"
        itemName.TextColor3 = Color3.fromRGB(120, 125, 145)
        itemName.TextSize = 13
        itemName.TextXAlignment = Enum.TextXAlignment.Left
        itemName.ZIndex = 33
        itemName.Parent = slotFrame

        local itemSub = Instance.new("TextLabel")
        itemSub.Name = "ItemSub"
        itemSub.Size = UDim2.new(1, -12, 0, 18)
        itemSub.Position = UDim2.new(0, 8, 0, 52)
        itemSub.BackgroundTransparency = 1
        itemSub.Font = Constants.THEME.FONT_BODY
        itemSub.Text = "None equipped"
        itemSub.TextColor3 = Constants.THEME.TEXT_MUTED
        itemSub.TextSize = 11
        itemSub.TextXAlignment = Enum.TextXAlignment.Left
        itemSub.ZIndex = 33
        itemSub.Parent = slotFrame

        -- Click to unequip
        local slotBtn = Instance.new("TextButton")
        slotBtn.Size = UDim2.new(1, 0, 1, 0)
        slotBtn.BackgroundTransparency = 1
        slotBtn.Text = ""
        slotBtn.ZIndex = 34
        slotBtn.Parent = slotFrame
        slotBtn.MouseButton1Click:Connect(function()
            if callbacksRef then
                callbacksRef.OnUnequip(slotName)
            end
        end)

        equippedSlots[slotName] = slotFrame
        return slotFrame
    end

    createEquipSlot("Weapon", 34)
    createEquipSlot("Armor", 122)
    createEquipSlot("Accessory", 210)

    -- "✨ Equip Best" Button
    local equipBestBtn = UITheme.CreateButton({
        Name = "EquipBestButton",
        Text = "✨ EQUIP BEST",
        Size = UDim2.new(1, -20, 0, 42),
        Position = UDim2.new(0, 10, 1, -52),
        BackgroundColor3 = Color3.fromRGB(30, 120, 210),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 13,
        Parent = leftCol,
        OnClick = function()
            if callbacksRef then callbacksRef.OnEquipBest() end
        end,
    })
    equipBestBtn.ZIndex = 33

    ----------------------------------------------------------------------------
    -- RIGHT AREA: 50-SLOT GRID & DETAIL PANEL
    ----------------------------------------------------------------------------
    local rightArea = Instance.new("Frame")
    rightArea.Name = "RightArea"
    rightArea.Size = UDim2.new(1, -250, 1, -64)
    rightArea.Position = UDim2.new(0, 236, 0, 52)
    rightArea.BackgroundTransparency = 1
    rightArea.ZIndex = 31
    rightArea.Parent = frame

    -- Grid ScrollingFrame (Max 50 Slots)
    local scroller = Instance.new("ScrollingFrame")
    scroller.Name = "GridContainer"
    scroller.Size = UDim2.new(1, 0, 0, 240)
    scroller.Position = UDim2.new(0, 0, 0, 0)
    scroller.BackgroundColor3 = Constants.THEME.SURFACE_PANEL
    scroller.BorderSizePixel = 0
    scroller.ScrollBarThickness = 6
    scroller.ScrollBarImageColor3 = Color3.fromRGB(70, 75, 100)
    scroller.CanvasSize = UDim2.new(0, 0, 0, 380)
    scroller.ZIndex = 32
    scroller.Parent = rightArea
    gridContainer = scroller

    local gridCorner = Instance.new("UICorner")
    gridCorner.CornerRadius = UDim.new(0, 10)
    gridCorner.Parent = scroller

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 84, 0, 68)
    gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = scroller

    local gridPadding = Instance.new("UIPadding")
    gridPadding.PaddingTop = UDim.new(0, 8)
    gridPadding.PaddingLeft = UDim.new(0, 8)
    gridPadding.PaddingRight = UDim.new(0, 8)
    gridPadding.PaddingBottom = UDim.new(0, 8)
    gridPadding.Parent = scroller

    ----------------------------------------------------------------------------
    -- BOTTOM DETAIL PANEL: INSPECTION & ACTIONS
    ----------------------------------------------------------------------------
    local panel = Instance.new("Frame")
    panel.Name = "DetailPanel"
    panel.Size = UDim2.new(1, 0, 1, -248)
    panel.Position = UDim2.new(0, 0, 0, 246)
    panel.BackgroundColor3 = Constants.THEME.SURFACE_PANEL
    panel.BorderSizePixel = 0
    panel.ZIndex = 32
    panel.Parent = rightArea

    local detailCorner = Instance.new("UICorner")
    detailCorner.CornerRadius = UDim.new(0, 10)
    detailCorner.Parent = panel

    local detailStroke = Instance.new("UIStroke")
    detailStroke.Color = Constants.THEME.STROKE_DEFAULT
    detailStroke.Thickness = 1.2
    detailStroke.Parent = panel

    local dName = Instance.new("TextLabel")
    dName.Name = "DetailName"
    dName.Size = UDim2.new(0.6, 0, 0, 26)
    dName.Position = UDim2.new(0, 14, 0, 10)
    dName.BackgroundTransparency = 1
    dName.Font = Constants.THEME.FONT_TITLE
    dName.Text = "Select an item to inspect"
    dName.TextColor3 = Constants.THEME.TEXT_PRIMARY
    dName.TextSize = 15
    dName.TextXAlignment = Enum.TextXAlignment.Left
    dName.ZIndex = 33
    dName.Parent = panel
    detailName = dName

    local dRarity = Instance.new("TextLabel")
    dRarity.Name = "DetailRarity"
    dRarity.Size = UDim2.new(0.35, 0, 0, 26)
    dRarity.Position = UDim2.new(0.62, 0, 0, 10)
    dRarity.BackgroundTransparency = 1
    dRarity.Font = Constants.THEME.FONT_TITLE
    dRarity.Text = ""
    dRarity.TextColor3 = Color3.fromRGB(255, 255, 255)
    dRarity.TextSize = 13
    dRarity.TextXAlignment = Enum.TextXAlignment.Right
    dRarity.ZIndex = 33
    dRarity.Parent = panel
    detailRarity = dRarity

    local dStats = Instance.new("TextLabel")
    dStats.Name = "DetailStats"
    dStats.Size = UDim2.new(0.50, 0, 0, 34)
    dStats.Position = UDim2.new(0, 14, 0, 34)
    dStats.BackgroundTransparency = 1
    dStats.Font = Constants.THEME.FONT_BODY
    dStats.Text = "No item selected"
    dStats.TextColor3 = Constants.THEME.TEXT_SECONDARY
    dStats.TextSize = 12
    dStats.TextXAlignment = Enum.TextXAlignment.Left
    dStats.TextYAlignment = Enum.TextYAlignment.Top
    dStats.ZIndex = 33
    dStats.Parent = panel
    detailStats = dStats

    -- Quality Label
    local dQuality = Instance.new("TextLabel")
    dQuality.Name = "DetailQuality"
    dQuality.Size = UDim2.new(0.50, 0, 0, 20)
    dQuality.Position = UDim2.new(0, 14, 0, 68)
    dQuality.BackgroundTransparency = 1
    dQuality.Font = Constants.THEME.FONT_TITLE
    dQuality.Text = ""
    dQuality.TextColor3 = Constants.THEME.TEXT_MUTED
    dQuality.TextSize = 12
    dQuality.TextXAlignment = Enum.TextXAlignment.Left
    dQuality.ZIndex = 33
    dQuality.Parent = panel
    detailQualityLabel = dQuality

    -- Trait Badge Label
    local dTrait = Instance.new("TextLabel")
    dTrait.Name = "DetailTrait"
    dTrait.Size = UDim2.new(0.50, 0, 0, 20)
    dTrait.Position = UDim2.new(0, 14, 0, 90)
    dTrait.BackgroundTransparency = 1
    dTrait.Font = Constants.THEME.FONT_TITLE
    dTrait.Text = ""
    dTrait.TextColor3 = Constants.THEME.TEXT_MUTED
    dTrait.TextSize = 12
    dTrait.TextXAlignment = Enum.TextXAlignment.Left
    dTrait.ZIndex = 33
    dTrait.Parent = panel
    detailTraitLabel = dTrait

    -- Action Buttons (Right of Detail Panel in 2 columns)
    -- Row 1: Equip (Col 1) & Upgrade (Col 2)
    local actionBtn = UITheme.CreateButton({
        Name = "EquipActionBtn",
        Text = "EQUIP",
        Size = UDim2.new(0, 114, 0, 32),
        Position = UDim2.new(1, -242, 0, 10),
        BackgroundColor3 = Color3.fromRGB(40, 140, 70),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 12,
        Parent = panel,
        OnClick = function()
            if selectedUUID and callbacksRef then
                callbacksRef.OnEquip(selectedUUID)
            end
        end,
    })
    actionBtn.ZIndex = 33
    actionBtn.Visible = false
    detailActionBtn = actionBtn

    local upgBtn = UITheme.CreateButton({
        Name = "UpgradeBtn",
        Text = "UPGRADE (+10%)",
        Size = UDim2.new(0, 114, 0, 32),
        Position = UDim2.new(1, -122, 0, 10),
        BackgroundColor3 = Color3.fromRGB(160, 90, 20),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 11,
        Parent = panel,
        OnClick = function()
            if selectedUUID and callbacksRef then
                callbacksRef.OnUpgrade(selectedUUID)
            end
        end,
    })
    upgBtn.ZIndex = 33
    upgBtn.Visible = false
    detailUpgradeBtn = upgBtn

    -- Row 2: Reroll Quality (150 Gold) & Reroll Trait (1 Gem)
    local rerollQualBtn = UITheme.CreateButton({
        Name = "RerollQualityBtn",
        Text = "🔨 QUAL (150G)",
        Size = UDim2.new(0, 114, 0, 32),
        Position = UDim2.new(1, -242, 0, 46),
        BackgroundColor3 = Color3.fromRGB(180, 110, 25),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 10,
        Parent = panel,
        OnClick = function()
            if selectedUUID and callbacksRef then
                callbacksRef.OnRerollQuality(selectedUUID)
            end
        end,
    })
    rerollQualBtn.ZIndex = 33
    rerollQualBtn.Visible = false
    detailRerollQualityBtn = rerollQualBtn

    local rerollTrtBtn = UITheme.CreateButton({
        Name = "RerollTraitBtn",
        Text = "💎 TRAIT (1 GEM)",
        Size = UDim2.new(0, 114, 0, 32),
        Position = UDim2.new(1, -122, 0, 46),
        BackgroundColor3 = Color3.fromRGB(130, 45, 180),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 10,
        Parent = panel,
        OnClick = function()
            if selectedUUID and callbacksRef then
                callbacksRef.OnRerollTrait(selectedUUID)
            end
        end,
    })
    rerollTrtBtn.ZIndex = 33
    rerollTrtBtn.Visible = false
    detailRerollTraitBtn = rerollTrtBtn

    -- Row 3: Sell Button across bottom
    local sBtn = UITheme.CreateButton({
        Name = "SellBtn",
        Text = "SELL",
        Size = UDim2.new(0, 234, 0, 30),
        Position = UDim2.new(1, -242, 0, 82),
        BackgroundColor3 = Color3.fromRGB(120, 35, 45),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 12,
        Parent = panel,
        OnClick = function()
            if selectedUUID and callbacksRef then
                callbacksRef.OnSell(selectedUUID)
            end
        end,
    })
    sBtn.ZIndex = 33
    sBtn.Visible = false
    detailSellBtn = sBtn
end

--[[
    Populates the inventory grid and equipped gear based on PlayerData.
]]
function InventoryView.Update(data: Types.PlayerData)
    local scroller = gridContainer
    if not modalFrame or not scroller then return end

    -- 1. Update Equipped Slots
    local slotNames = { "Weapon", "Armor", "Accessory" }
    for _, slotName in ipairs(slotNames) do
        local slotFrame = equippedSlots[slotName]
        if slotFrame then
            local uuid = (data.Equipped :: any)[slotName] :: string?
            local invItem = if uuid then data.Inventory[uuid] else nil
            local itemDef = if invItem then ItemConfig.Get(invItem.ItemId) else nil

            local nameLbl = slotFrame:FindFirstChild("ItemName") :: TextLabel?
            local subLbl = slotFrame:FindFirstChild("ItemSub") :: TextLabel?
            local stroke = slotFrame:FindFirstChild("SlotStroke") :: UIStroke?

            if itemDef and invItem then
                local tierCfg = RarityConfig.Get(itemDef.Rarity)
                local color = if tierCfg then tierCfg.Color else Color3.fromRGB(255, 255, 255)
                if nameLbl then
                    nameLbl.Text = string.format("%s%s", itemDef.Name, if invItem.EnchantLevel > 0 then string.format(" +%d", invItem.EnchantLevel) else "")
                    nameLbl.TextColor3 = color
                end
                if subLbl then
                    subLbl.Text = string.format("%s (Click to unequip)", itemDef.Rarity)
                    subLbl.TextColor3 = Constants.THEME.TEXT_SECONDARY
                end
                if stroke then stroke.Color = color end
            else
                if nameLbl then
                    nameLbl.Text = "[Empty Slot]"
                    nameLbl.TextColor3 = Color3.fromRGB(120, 125, 145)
                end
                if subLbl then
                    subLbl.Text = "None equipped"
                    subLbl.TextColor3 = Constants.THEME.TEXT_MUTED
                end
                if stroke then stroke.Color = Constants.THEME.STROKE_DEFAULT end
            end
        end
    end

    -- 2. Clear & Rebuild Grid Boxes (Up to 50 slots)
    for _, child in ipairs(scroller:GetChildren()) do
        if child:IsA("Frame") and child.Name:match("^Slot_") then
            child:Destroy()
        end
    end

    local index = 0
    for uuid, invItem in pairs(data.Inventory) do
        index += 1
        local itemDef = ItemConfig.Get(invItem.ItemId)
        if itemDef then
            local tierCfg = RarityConfig.Get(itemDef.Rarity)
            local rarityColor = if tierCfg then tierCfg.Color else Color3.fromRGB(200, 200, 200)

            local box = Instance.new("Frame")
            box.Name = "Slot_" .. uuid
            box.Size = UDim2.new(0, 84, 0, 68)
            box.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
            box.BorderSizePixel = 0
            box.ZIndex = 33
            box.Parent = scroller

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 6)
            corner.Parent = box

            local stroke = Instance.new("UIStroke")
            stroke.Color = rarityColor
            stroke.Thickness = 1.2
            stroke.Parent = box

            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size = UDim2.new(1, -6, 0, 32)
            nameLbl.Position = UDim2.new(0, 3, 0, 4)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Font = Constants.THEME.FONT_TITLE
            nameLbl.Text = itemDef.Name
            nameLbl.TextColor3 = rarityColor
            nameLbl.TextSize = 10
            nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
            nameLbl.ZIndex = 34
            nameLbl.Parent = box

            local traitDef = if invItem.Trait then TraitConfig.Get(invItem.Trait) else nil
            local traitTag = if traitDef then string.format("[%s]", traitDef.DisplayName) else ""
            local levelText = if invItem.EnchantLevel > 0 then string.format("+%d ", invItem.EnchantLevel) else ""

            local levelLbl = Instance.new("TextLabel")
            levelLbl.Size = UDim2.new(1, -6, 0, 18)
            levelLbl.Position = UDim2.new(0, 3, 1, -22)
            levelLbl.BackgroundTransparency = 1
            levelLbl.Font = Constants.THEME.FONT_BODY
            levelLbl.Text = if traitTag ~= "" then string.format("%s%s", levelText, traitTag) elseif invItem.EnchantLevel > 0 then levelText else itemDef.Slot
            levelLbl.TextColor3 = if traitDef then traitDef.Color else Constants.THEME.TEXT_MUTED
            levelLbl.TextSize = 10
            levelLbl.ZIndex = 34
            levelLbl.Parent = box

            -- Click to inspect
            local clickBtn = Instance.new("TextButton")
            clickBtn.Size = UDim2.new(1, 0, 1, 0)
            clickBtn.BackgroundTransparency = 1
            clickBtn.Text = ""
            clickBtn.ZIndex = 35
            clickBtn.Parent = box
            clickBtn.MouseButton1Click:Connect(function()
                selectedUUID = uuid
                InventoryView.InspectItem(uuid, invItem, itemDef, data)
            end)
        end
    end

    -- If currently selected item was modified/removed, re-inspect
    if selectedUUID and data.Inventory[selectedUUID] then
        local invItem = data.Inventory[selectedUUID]
        local itemDef = ItemConfig.Get(invItem.ItemId)
        if itemDef then
            InventoryView.InspectItem(selectedUUID, invItem, itemDef, data)
        end
    else
        selectedUUID = nil
        if detailName then detailName.Text = "Select an item to inspect" end
        if detailRarity then detailRarity.Text = "" end
        if detailStats then detailStats.Text = "No item selected" end
        if detailQualityLabel then detailQualityLabel.Text = "" end
        if detailTraitLabel then detailTraitLabel.Text = "" end
        if detailActionBtn then detailActionBtn.Visible = false end
        if detailUpgradeBtn then detailUpgradeBtn.Visible = false end
        if detailRerollQualityBtn then detailRerollQualityBtn.Visible = false end
        if detailRerollTraitBtn then detailRerollTraitBtn.Visible = false end
        if detailSellBtn then detailSellBtn.Visible = false end
    end
end

--[[
    Updates the detail inspection drawer.
]]
function InventoryView.InspectItem(uuid: string, invItem: Types.InventoryItem, itemDef: Types.ItemDefinition, data: Types.PlayerData)
    local tierCfg = RarityConfig.Get(itemDef.Rarity)
    local color = if tierCfg then tierCfg.Color else Color3.fromRGB(255, 255, 255)
    local rarityMult = RarityConfig.GetMultiplier(itemDef.Rarity)
    local rawQuality = invItem.Quality or 50
    local qualityMult = 0.5 + (rawQuality / 100) * 1.0
    local enchantBonus = 1.0 + (invItem.EnchantLevel * 0.1)

    if detailName then
        detailName.Text = string.format("%s%s", itemDef.Name, if invItem.EnchantLevel > 0 then string.format(" +%d", invItem.EnchantLevel) else "")
        detailName.TextColor3 = color
    end

    if detailRarity then
        detailRarity.Text = string.format("%s • %s", itemDef.Rarity, itemDef.Slot)
        detailRarity.TextColor3 = color
    end

    local statsLines = {}
    if (itemDef.BaseStats.MaxHP or 0) > 0 then
        table.insert(statsLines, string.format("HP: +%d", math.round(itemDef.BaseStats.MaxHP * rarityMult * qualityMult * enchantBonus)))
    end
    if (itemDef.BaseStats.Damage or 0) > 0 then
        table.insert(statsLines, string.format("DMG: +%d", math.round(itemDef.BaseStats.Damage * rarityMult * qualityMult * enchantBonus)))
    end
    if (itemDef.BaseStats.CritChance or 0) > 0 then
        table.insert(statsLines, string.format("Crit: +%.1f%%", (itemDef.BaseStats.CritChance * rarityMult * qualityMult) * 100))
    end
    if (itemDef.BaseStats.LuckBonus or 0) > 0 then
        table.insert(statsLines, string.format("Luck: +%.1fx", itemDef.BaseStats.LuckBonus * rarityMult * qualityMult))
    end

    if detailStats then
        detailStats.Text = table.concat(statsLines, "  |  ")
    end

    -- Quality Color Coding (<40% Gray, 40-70% Green, 71-89% Purple, 90-100% Golden Yellow)
    local qualityColor = Color3.fromRGB(150, 155, 170)
    local qualityTierName = "STANDARD"
    if rawQuality >= 90 then
        qualityColor = Color3.fromRGB(255, 205, 40)
        qualityTierName = "PERFECT"
    elseif rawQuality >= 71 then
        qualityColor = Color3.fromRGB(180, 80, 255)
        qualityTierName = "SUPERIOR"
    elseif rawQuality >= 40 then
        qualityColor = Color3.fromRGB(80, 220, 120)
        qualityTierName = "REFINED"
    end

    if detailQualityLabel then
        detailQualityLabel.Text = string.format("Quality: %d%% [%s]", rawQuality, qualityTierName)
        detailQualityLabel.TextColor3 = qualityColor
    end

    -- Trait display
    if detailTraitLabel then
        if invItem.Trait then
            local traitDef = TraitConfig.Get(invItem.Trait)
            if traitDef then
                detailTraitLabel.Text = string.format("🔮 Trait: %s  •  %s", traitDef.DisplayName, traitDef.Description)
                detailTraitLabel.TextColor3 = traitDef.Color
            else
                detailTraitLabel.Text = string.format("🔮 Trait: %s", invItem.Trait)
                detailTraitLabel.TextColor3 = Color3.fromRGB(220, 220, 255)
            end
        else
            detailTraitLabel.Text = "🔮 Trait: None (Use Gem to add Trait!)"
            detailTraitLabel.TextColor3 = Constants.THEME.TEXT_MUTED
        end
    end

    -- Check if equipped
    local isEquipped = (data.Equipped[itemDef.Slot] == uuid)
    if detailActionBtn then
        detailActionBtn.Visible = true
        if isEquipped then
            detailActionBtn.Text = "UNEQUIP"
            detailActionBtn.BackgroundColor3 = Color3.fromRGB(150, 45, 45)
        else
            detailActionBtn.Text = "EQUIP"
            detailActionBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 70)
        end
    end

    -- Reroll buttons
    if detailRerollQualityBtn then
        detailRerollQualityBtn.Visible = true
        detailRerollQualityBtn.Text = "🔨 QUAL (150G)"
    end

    if detailRerollTraitBtn then
        detailRerollTraitBtn.Visible = true
        detailRerollTraitBtn.Text = "💎 TRAIT (1 GEM)"
    end

    -- Upgrade button with Gold cost
    local upgradeCost = math.round(120 * (1.7 ^ invItem.EnchantLevel))
    if detailUpgradeBtn then
        detailUpgradeBtn.Visible = true
        detailUpgradeBtn.Text = string.format("UPGRADE (%dG)", upgradeCost)
    end

    -- Sell button with Gold earnings
    local sellPrice = math.round(itemDef.SellPrice * (1.0 + invItem.EnchantLevel * 0.25))
    if detailSellBtn then
        detailSellBtn.Visible = true
        detailSellBtn.Text = string.format("SELL (+%dG)", sellPrice)
    end
end

return InventoryView
