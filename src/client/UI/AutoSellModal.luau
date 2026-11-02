--!strict
--[[
    AutoSellModal.luau
    Settings popup allowing players to toggle auto-selling for each rarity tier.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Constants = require(Shared:WaitForChild("Constants"))
local RarityConfig = require(Shared:WaitForChild("RarityConfig"))

local UITheme = require(script.Parent.UITheme)

local AutoSellModal = {}

local modalFrame: Frame? = nil
local activeToggles: { [string]: boolean } = {}
local toggleButtons: { [string]: TextButton } = {}

local onSaveCallback: ((settings: { [string]: boolean }) -> ())? = nil

function AutoSellModal.Toggle(isOpen: boolean?)
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
        frame.Visible = false
    end
end

function AutoSellModal.IsOpen(): boolean
    local frame = modalFrame
    return if frame then frame.Visible else false
end

function AutoSellModal.Build(parent: ScreenGui, onSave: (settings: { [string]: boolean }) -> ())
    onSaveCallback = onSave

    local frame = UITheme.CreatePanel({
        Name = "AutoSellModal",
        Size = UDim2.new(0, 360, 0, 420),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Constants.THEME.BACKGROUND_DARK,
        StrokeColor = Constants.THEME.STROKE_DEFAULT,
        StrokeThickness = 2.0,
        CornerRadius = UDim.new(0, 16),
        Parent = parent,
    })
    frame.Visible = false
    frame.ZIndex = 35
    modalFrame = frame

    -- Header
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 0, 40)
    title.Position = UDim2.new(0, 18, 0, 10)
    title.BackgroundTransparency = 1
    title.Font = Constants.THEME.FONT_TITLE
    title.Text = "⚙️ AUTO-SELL FILTER"
    title.TextColor3 = Constants.THEME.TEXT_PRIMARY
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 36
    title.Parent = frame

    local closeBtn = UITheme.CreateButton({
        Name = "CloseButton",
        Text = "X",
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -40, 0, 10),
        BackgroundColor3 = Color3.fromRGB(35, 40, 60),
        TextColor3 = Color3.fromRGB(255, 120, 120),
        TextSize = 14,
        Parent = frame,
        OnClick = function()
            AutoSellModal.Toggle(false)
        end,
    })
    closeBtn.ZIndex = 36

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -36, 0, 30)
    desc.Position = UDim2.new(0, 18, 0, 46)
    desc.BackgroundTransparency = 1
    desc.Font = Constants.THEME.FONT_BODY
    desc.Text = "Select rarities to immediately sell for Gold upon rolling:"
    desc.TextColor3 = Constants.THEME.TEXT_SECONDARY
    desc.TextSize = 12
    desc.TextWrapped = true
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.ZIndex = 36
    desc.Parent = frame

    -- Toggles List
    local listContainer = Instance.new("Frame")
    listContainer.Size = UDim2.new(1, -36, 0, 270)
    listContainer.Position = UDim2.new(0, 18, 0, 84)
    listContainer.BackgroundTransparency = 1
    listContainer.ZIndex = 36
    listContainer.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, 6)
    layout.Parent = listContainer

    local orderedTiers = RarityConfig.GetAllTiers()
    for _, tier in ipairs(orderedTiers) do
        local tierStr = tostring(tier)
        local tierCfg = RarityConfig.Get(tier)
        local color = if tierCfg then tierCfg.Color else Color3.fromRGB(200, 200, 200)

        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 32)
        row.BackgroundColor3 = Constants.THEME.SURFACE_PANEL
        row.BorderSizePixel = 0
        row.ZIndex = 36
        row.Parent = listContainer

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = row

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -90, 1, 0)
        label.Position = UDim2.new(0, 12, 0, 0)
        label.BackgroundTransparency = 1
        label.Font = Constants.THEME.FONT_TITLE
        label.Text = tierStr
        label.TextColor3 = color
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.ZIndex = 37
        label.Parent = row

        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Name = "Toggle_" .. tierStr
        toggleBtn.Size = UDim2.new(0, 70, 0, 24)
        toggleBtn.Position = UDim2.new(1, -76, 0, 4)
        toggleBtn.BackgroundColor3 = Color3.fromRGB(45, 50, 68)
        toggleBtn.BorderSizePixel = 0
        toggleBtn.Font = Constants.THEME.FONT_TITLE
        toggleBtn.Text = "KEEP"
        toggleBtn.TextColor3 = Color3.fromRGB(180, 190, 215)
        toggleBtn.TextSize = 11
        toggleBtn.ZIndex = 37
        toggleBtn.Parent = row

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = toggleBtn

        toggleButtons[tierStr] = toggleBtn

        toggleBtn.MouseButton1Click:Connect(function()
            local current = activeToggles[tierStr] == true
            activeToggles[tierStr] = not current

            if activeToggles[tierStr] then
                toggleBtn.Text = "SELL"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 60)
                toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                toggleBtn.Text = "KEEP"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(45, 50, 68)
                toggleBtn.TextColor3 = Color3.fromRGB(180, 190, 215)
            end

            if onSaveCallback then
                onSaveCallback(activeToggles)
            end
        end)
    end

    -- Bottom Save/Close button
    local saveBtn = UITheme.CreateButton({
        Name = "SaveAutoSellBtn",
        Text = "SAVE & CLOSE",
        Size = UDim2.new(1, -36, 0, 38),
        Position = UDim2.new(0, 18, 1, -48),
        BackgroundColor3 = Color3.fromRGB(35, 120, 210),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 13,
        Parent = frame,
        OnClick = function()
            if onSaveCallback then
                onSaveCallback(activeToggles)
            end
            AutoSellModal.Toggle(false)
        end,
    })
    saveBtn.ZIndex = 36
end

function AutoSellModal.Update(data: Types.PlayerData)
    activeToggles = data.AutoDeleteRarities or {}
    for tier, btn in pairs(toggleButtons) do
        if activeToggles[tier] then
            btn.Text = "SELL"
            btn.BackgroundColor3 = Color3.fromRGB(180, 50, 60)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btn.Text = "KEEP"
            btn.BackgroundColor3 = Color3.fromRGB(45, 50, 68)
            btn.TextColor3 = Color3.fromRGB(180, 190, 215)
        end
    end
end

return AutoSellModal
