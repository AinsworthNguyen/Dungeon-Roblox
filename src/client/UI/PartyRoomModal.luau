--!strict
--[[
    PartyRoomModal.luau
    Dark Fantasy Dungeon Party Room Controller & Invitation Modal.
    
    Features:
    - Floor Selection (Floor 1: Goblin Crypt, Floor 2: Cursed Citadel, Floor 3: Abyssal Sanctum)
    - Room Configuration: Max Players (1-4) & Friends Only toggle
    - Active Members roster with Host indicator, Level, and Combat Power (CP)
    - Player Invitation panel with online server player list
    - Bottom Action Controls: [⚔️ START DUNGEON] (Host only) and [🚪 LEAVE ROOM]
    - Non-intrusive Popup card for incoming Party Invitations ([✓ ACCEPT] / [✗ DECLINE])
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Constants = require(Shared:WaitForChild("Constants"))

local UITheme = require(script.Parent.UITheme)

local PartyRoomModal = {}

local localPlayer = Players.LocalPlayer

-- Modal frames & components
local modalFrame: Frame? = nil
local screenGuiRef: ScreenGui? = nil
local invitePopupFrame: Frame? = nil
local inviteListOverlay: Frame? = nil

-- UI Reference handles
local titleLabel: TextLabel? = nil
local hostBadgeLabel: TextLabel? = nil
local floorCards: { [string]: { Frame: Frame, Button: TextButton, Stroke: UIStroke, Desc: TextLabel } } = {}
local maxPlayersLabel: TextLabel? = nil
local minusBtn: TextButton? = nil
local plusBtn: TextButton? = nil
local friendsOnlyBtn: TextButton? = nil
local memberSlotFrames: { { Frame: Frame, NameLabel: TextLabel, StatLabel: TextLabel, BadgeLabel: TextLabel } } = {}
local startBtn: TextButton? = nil
local playerListContainer: ScrollingFrame? = nil

-- State caches
local currentRoomState: Types.PartyRoomClientState? = nil
local onActionCallback: ((action: string, payload: any) -> ())? = nil

local FLOOR_INFOS = {
    {
        Id = "floor_1",
        Name = "Floor 1: Goblin Crypt",
        Theme = "Level 1+ • Rec. CP: 15+",
        Color = Color3.fromRGB(75, 215, 110),
    },
    {
        Id = "floor_2",
        Name = "Floor 2: Cursed Citadel",
        Theme = "Level 10+ • Rec. CP: 200+",
        Color = Color3.fromRGB(175, 75, 255),
    },
    {
        Id = "floor_3",
        Name = "Floor 3: Abyssal Sanctum",
        Theme = "Level 25+ • Rec. CP: 1,000+",
        Color = Color3.fromRGB(255, 60, 90),
    },
}

function PartyRoomModal.IsOpen(): boolean
    local frame = modalFrame
    return if frame then frame.Visible else false
end

function PartyRoomModal.Toggle(isOpen: boolean?)
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
            if modalFrame and not targetOpen then
                modalFrame.Visible = false
                if inviteListOverlay then inviteListOverlay.Visible = false end
            end
        end)
    end
end

--[[
    Displays an incoming Party Invitation Popup card at top of screen.
]]
function PartyRoomModal.ShowInvitePopup(invite: Types.PartyInviteInfo)
    local screenGui = screenGuiRef
    if not screenGui then return end

    if invitePopupFrame then
        invitePopupFrame:Destroy()
        invitePopupFrame = nil
    end

    local popup = UITheme.CreatePanel({
        Name = "PartyInvitePopup",
        Size = UDim2.new(0, 380, 0, 110),
        Position = UDim2.new(0.5, 0, 0, -120),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = Color3.fromRGB(18, 22, 34),
        StrokeColor = Color3.fromRGB(255, 200, 60),
        StrokeThickness = 2.0,
        CornerRadius = UDim.new(0, 12),
        Parent = screenGui,
    })
    popup.ZIndex = 50
    invitePopupFrame = popup

    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0, 36, 0, 36)
    icon.Position = UDim2.new(0, 12, 0, 12)
    icon.BackgroundTransparency = 1
    icon.Font = Constants.THEME.FONT_TITLE
    icon.Text = "📨"
    icon.TextSize = 24
    icon.ZIndex = 51
    icon.Parent = popup

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 0, 20)
    title.Position = UDim2.new(0, 52, 0, 10)
    title.BackgroundTransparency = 1
    title.Font = Constants.THEME.FONT_TITLE
    title.Text = "DUNGEON PARTY INVITATION"
    title.TextColor3 = Color3.fromRGB(255, 215, 60)
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 51
    title.Parent = popup

    local body = Instance.new("TextLabel")
    body.Size = UDim2.new(1, -60, 0, 32)
    body.Position = UDim2.new(0, 52, 0, 30)
    body.BackgroundTransparency = 1
    body.Font = Constants.THEME.FONT_BODY
    body.Text = string.format("%s invited you to Room #%d (%s)!", invite.HostName, invite.RoomId, invite.FloorName)
    body.TextColor3 = Color3.fromRGB(230, 235, 245)
    body.TextSize = 11
    body.TextWrapped = true
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.ZIndex = 51
    body.Parent = popup

    -- Accept & Decline Buttons
    local acceptBtn = UITheme.CreateButton({
        Name = "AcceptBtn",
        Text = "[OK] ACCEPT",
        Size = UDim2.new(0, 130, 0, 28),
        Position = UDim2.new(0.5, -135, 1, -36),
        BackgroundColor3 = Color3.fromRGB(40, 160, 75),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 12,
        Parent = popup,
        OnClick = function()
            if onActionCallback then
                onActionCallback("AcceptInvite", { RoomId = invite.RoomId })
            end
            popup:Destroy()
            invitePopupFrame = nil
        end,
    })
    acceptBtn.ZIndex = 52

    local declineBtn = UITheme.CreateButton({
        Name = "DeclineBtn",
        Text = "[X] DECLINE",
        Size = UDim2.new(0, 130, 0, 28),
        Position = UDim2.new(0.5, 5, 1, -36),
        BackgroundColor3 = Color3.fromRGB(70, 35, 45),
        TextColor3 = Color3.fromRGB(255, 150, 150),
        TextSize = 12,
        Parent = popup,
        OnClick = function()
            popup:Destroy()
            invitePopupFrame = nil
        end,
    })
    declineBtn.ZIndex = 52

    -- Slide down
    TweenService:Create(popup, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0, 24)
    }):Play()

    -- Auto-dismiss after 15s
    task.delay(15, function()
        if invitePopupFrame == popup then
            local tween = TweenService:Create(popup, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, 0, 0, -130)
            })
            tween:Play()
            tween.Completed:Connect(function()
                popup:Destroy()
                if invitePopupFrame == popup then
                    invitePopupFrame = nil
                end
            end)
        end
    end)
end

--[[
    Refreshes the online player list inside the Invite Players overlay.
]]
local function refreshInviteList()
    local container = playerListContainer
    if not container then return end

    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    local otherPlayers: { Player } = {}
    local currentMemberIds: { [number]: boolean } = {}
    if currentRoomState then
        for _, m in ipairs(currentRoomState.Members) do
            currentMemberIds[m.UserId] = true
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer and not currentMemberIds[p.UserId] then
            table.insert(otherPlayers, p)
        end
    end

    if #otherPlayers == 0 then
        local emptyNote = Instance.new("Frame")
        emptyNote.Size = UDim2.new(1, 0, 0, 80)
        emptyNote.BackgroundTransparency = 1
        emptyNote.Parent = container

        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.Size = UDim2.new(1, 0, 0, 40)
        emptyLabel.Position = UDim2.new(0, 0, 0, 0)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.Font = Constants.THEME.FONT_BODY
        emptyLabel.Text = "No other players in server right now.\n(Start solo or invite friends!)"
        emptyLabel.TextColor3 = Color3.fromRGB(170, 180, 205)
        emptyLabel.TextSize = 12
        emptyLabel.ZIndex = 42
        emptyLabel.Parent = emptyNote

        -- Demo button for testing invite popup solo
        local testBtn = UITheme.CreateButton({
            Name = "TestInviteBtn",
            Text = "📨 Test Demo Invite Popup",
            Size = UDim2.new(0, 200, 0, 30),
            Position = UDim2.new(0.5, -100, 0, 44),
            BackgroundColor3 = Color3.fromRGB(45, 60, 95),
            TextColor3 = Color3.fromRGB(255, 215, 60),
            TextSize = 12,
            Parent = emptyNote,
            OnClick = function()
                PartyRoomModal.ShowInvitePopup({
                    RoomId = if currentRoomState then currentRoomState.RoomId else 1,
                    HostName = "Test Host",
                    FloorId = "floor_1",
                    FloorName = "Floor 1: Goblin Crypt",
                })
            end,
        })
        testBtn.ZIndex = 42
        container.CanvasSize = UDim2.new(0, 0, 0, 100)
        return
    end

    local rowHeight = 44
    for i, p in ipairs(otherPlayers) do
        local row = Instance.new("Frame")
        row.Name = "PlayerRow_" .. p.UserId
        row.Size = UDim2.new(1, 0, 0, rowHeight - 6)
        row.Position = UDim2.new(0, 0, 0, (i - 1) * rowHeight)
        row.BackgroundColor3 = Color3.fromRGB(24, 28, 42)
        row.BorderSizePixel = 0
        row.ZIndex = 42
        row.Parent = container

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = row

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(0.65, 0, 1, 0)
        nameLbl.Position = UDim2.new(0, 12, 0, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Font = Constants.THEME.FONT_TITLE
        nameLbl.Text = p.DisplayName .. " (@" .. p.Name .. ")"
        nameLbl.TextColor3 = Color3.fromRGB(240, 245, 255)
        nameLbl.TextSize = 12
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.ZIndex = 43
        nameLbl.Parent = row

        local sendInviteBtn: TextButton? = nil
        sendInviteBtn = UITheme.CreateButton({
            Name = "SendInviteBtn",
            Text = "📨 Invite",
            Size = UDim2.new(0, 80, 0, 26),
            Position = UDim2.new(1, -90, 0.5, -13),
            BackgroundColor3 = Color3.fromRGB(45, 80, 140),
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextSize = 11,
            Parent = row,
            OnClick = function()
                if onActionCallback then
                    onActionCallback("Invite", { TargetUserId = p.UserId })
                end
                -- visual confirmation
                if sendInviteBtn then
                    sendInviteBtn.Text = "Sent!"
                    sendInviteBtn.BackgroundColor3 = Color3.fromRGB(40, 120, 60)
                end
            end,
        })
        if sendInviteBtn then
            sendInviteBtn.ZIndex = 43
        end
    end

    container.CanvasSize = UDim2.new(0, 0, 0, #otherPlayers * rowHeight)
end

--[[
    Builds the main Party Room Modal GUI.
]]
function PartyRoomModal.Build(parent: ScreenGui, onAction: (action: string, payload: any) -> ())
    screenGuiRef = parent
    onActionCallback = onAction

    local frame = UITheme.CreatePanel({
        Name = "PartyRoomModal",
        Size = UDim2.new(0, 720, 0, 520),
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

    -- Top Header
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -200, 0, 32)
    title.Position = UDim2.new(0, 24, 0, 14)
    title.BackgroundTransparency = 1
    title.Font = Constants.THEME.FONT_TITLE
    title.Text = "⚔️ PARTY ROOM #1"
    title.TextColor3 = Constants.THEME.TEXT_PRIMARY
    title.TextSize = 19
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 36
    title.Parent = frame
    titleLabel = title

    local hostBadge = Instance.new("TextLabel")
    hostBadge.Size = UDim2.new(0, 140, 0, 26)
    hostBadge.Position = UDim2.new(1, -190, 0, 17)
    hostBadge.BackgroundColor3 = Color3.fromRGB(35, 42, 65)
    hostBadge.Font = Constants.THEME.FONT_TITLE
    hostBadge.Text = "[👑 HOST]"
    hostBadge.TextColor3 = Color3.fromRGB(255, 215, 60)
    hostBadge.TextSize = 12
    hostBadge.ZIndex = 36
    hostBadge.Parent = frame
    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(0, 6)
    badgeCorner.Parent = hostBadge
    hostBadgeLabel = hostBadge

    local subTitle = Instance.new("TextLabel")
    subTitle.Size = UDim2.new(1, -48, 0, 20)
    subTitle.Position = UDim2.new(0, 24, 0, 46)
    subTitle.BackgroundTransparency = 1
    subTitle.Font = Constants.THEME.FONT_BODY
    subTitle.Text = "Assemble your squad, select the dungeon tier, and conquer the depths together!"
    subTitle.TextColor3 = Constants.THEME.TEXT_SECONDARY
    subTitle.TextSize = 12
    subTitle.TextXAlignment = Enum.TextXAlignment.Left
    subTitle.ZIndex = 36
    subTitle.Parent = frame

    -- 1. Floor Selection Section (Horizontal Cards)
    local floorSecTitle = Instance.new("TextLabel")
    floorSecTitle.Size = UDim2.new(1, -48, 0, 20)
    floorSecTitle.Position = UDim2.new(0, 24, 0, 72)
    floorSecTitle.BackgroundTransparency = 1
    floorSecTitle.Font = Constants.THEME.FONT_TITLE
    floorSecTitle.Text = "SELECT DUNGEON FLOOR (Host Only)"
    floorSecTitle.TextColor3 = Color3.fromRGB(220, 225, 240)
    floorSecTitle.TextSize = 12
    floorSecTitle.TextXAlignment = Enum.TextXAlignment.Left
    floorSecTitle.ZIndex = 36
    floorSecTitle.Parent = frame

    local floorCardWidth = 216
    local floorCardGap = 12
    for i, fInfo in ipairs(FLOOR_INFOS) do
        local card = Instance.new("Frame")
        card.Name = "FloorCard_" .. fInfo.Id
        card.Size = UDim2.new(0, floorCardWidth, 0, 68)
        card.Position = UDim2.new(0, 24 + (i - 1) * (floorCardWidth + floorCardGap), 0, 94)
        card.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
        card.BorderSizePixel = 0
        card.ZIndex = 36
        card.Parent = frame

        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(0, 8)
        cCorner.Parent = card

        local cStroke = Instance.new("UIStroke")
        cStroke.Thickness = 1.5
        cStroke.Color = Color3.fromRGB(45, 50, 70)
        cStroke.Parent = card

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Font = Constants.THEME.FONT_TITLE
        btn.Text = ""
        btn.ZIndex = 38
        btn.Parent = card

        local nameL = Instance.new("TextLabel")
        nameL.Size = UDim2.new(1, -16, 0, 24)
        nameL.Position = UDim2.new(0, 8, 0, 8)
        nameL.BackgroundTransparency = 1
        nameL.Font = Constants.THEME.FONT_TITLE
        nameL.Text = fInfo.Name
        nameL.TextColor3 = fInfo.Color
        nameL.TextSize = 13
        nameL.TextXAlignment = Enum.TextXAlignment.Left
        nameL.ZIndex = 37
        nameL.Parent = card

        local descL = Instance.new("TextLabel")
        descL.Size = UDim2.new(1, -16, 0, 20)
        descL.Position = UDim2.new(0, 8, 0, 34)
        descL.BackgroundTransparency = 1
        descL.Font = Constants.THEME.FONT_BODY
        descL.Text = fInfo.Theme
        descL.TextColor3 = Color3.fromRGB(160, 170, 190)
        descL.TextSize = 11
        descL.TextXAlignment = Enum.TextXAlignment.Left
        descL.ZIndex = 37
        descL.Parent = card

        btn.MouseButton1Click:Connect(function()
            if currentRoomState and currentRoomState.IsHost then
                if onActionCallback then
                    onActionCallback("SetFloor", { FloorId = fInfo.Id })
                end
            end
        end)

        floorCards[fInfo.Id] = { Frame = card, Button = btn, Stroke = cStroke, Desc = descL }
    end

    -- 2. Room Settings Row (Max Players & Friends Only & Invite Button)
    local settingsRow = Instance.new("Frame")
    settingsRow.Name = "SettingsRow"
    settingsRow.Size = UDim2.new(1, -48, 0, 40)
    settingsRow.Position = UDim2.new(0, 24, 0, 172)
    settingsRow.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
    settingsRow.BorderSizePixel = 0
    settingsRow.ZIndex = 36
    settingsRow.Parent = frame

    local setCorner = Instance.new("UICorner")
    setCorner.CornerRadius = UDim.new(0, 8)
    setCorner.Parent = settingsRow

    -- Max Players Controls
    local mpTitle = Instance.new("TextLabel")
    mpTitle.Size = UDim2.new(0, 100, 1, 0)
    mpTitle.Position = UDim2.new(0, 14, 0, 0)
    mpTitle.BackgroundTransparency = 1
    mpTitle.Font = Constants.THEME.FONT_TITLE
    mpTitle.Text = "MAX SQUAD:"
    mpTitle.TextColor3 = Color3.fromRGB(200, 210, 230)
    mpTitle.TextSize = 12
    mpTitle.TextXAlignment = Enum.TextXAlignment.Left
    mpTitle.ZIndex = 37
    mpTitle.Parent = settingsRow

    local mBtn = UITheme.CreateButton({
        Name = "MinusBtn",
        Text = "-",
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(0, 105, 0.5, -14),
        BackgroundColor3 = Color3.fromRGB(35, 40, 60),
        TextColor3 = Color3.fromRGB(240, 245, 255),
        TextSize = 14,
        Parent = settingsRow,
        OnClick = function()
            if currentRoomState and currentRoomState.IsHost then
                local nextVal = math.max(1, currentRoomState.MaxPlayers - 1)
                if onActionCallback then onActionCallback("SetMaxPlayers", { MaxPlayers = nextVal }) end
            end
        end,
    })
    mBtn.ZIndex = 37
    minusBtn = mBtn

    local mpLabel = Instance.new("TextLabel")
    mpLabel.Size = UDim2.new(0, 50, 1, 0)
    mpLabel.Position = UDim2.new(0, 137, 0, 0)
    mpLabel.BackgroundTransparency = 1
    mpLabel.Font = Constants.THEME.FONT_TITLE
    mpLabel.Text = "4 / 4"
    mpLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
    mpLabel.TextSize = 13
    mpLabel.ZIndex = 37
    mpLabel.Parent = settingsRow
    maxPlayersLabel = mpLabel

    local pBtn = UITheme.CreateButton({
        Name = "PlusBtn",
        Text = "+",
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(0, 190, 0.5, -14),
        BackgroundColor3 = Color3.fromRGB(35, 40, 60),
        TextColor3 = Color3.fromRGB(240, 245, 255),
        TextSize = 14,
        Parent = settingsRow,
        OnClick = function()
            if currentRoomState and currentRoomState.IsHost then
                local nextVal = math.min(4, currentRoomState.MaxPlayers + 1)
                if onActionCallback then onActionCallback("SetMaxPlayers", { MaxPlayers = nextVal }) end
            end
        end,
    })
    pBtn.ZIndex = 37
    plusBtn = pBtn

    -- Friends Only Toggle Button
    local foBtn = UITheme.CreateButton({
        Name = "FriendsOnlyBtn",
        Text = "[ ] Public Room",
        Size = UDim2.new(0, 160, 0, 28),
        Position = UDim2.new(0, 235, 0.5, -14),
        BackgroundColor3 = Color3.fromRGB(35, 40, 60),
        TextColor3 = Color3.fromRGB(200, 210, 230),
        TextSize = 12,
        Parent = settingsRow,
        OnClick = function()
            if currentRoomState and currentRoomState.IsHost then
                local nextState = not currentRoomState.FriendsOnly
                if onActionCallback then onActionCallback("SetFriendsOnly", { FriendsOnly = nextState }) end
            end
        end,
    })
    foBtn.ZIndex = 37
    friendsOnlyBtn = foBtn

    -- Invite Players Trigger
    local invBtn = UITheme.CreateButton({
        Name = "InvitePlayersBtn",
        Text = "📨 INVITE PLAYERS",
        Size = UDim2.new(0, 160, 0, 28),
        Position = UDim2.new(1, -170, 0.5, -14),
        BackgroundColor3 = Color3.fromRGB(45, 75, 120),
        TextColor3 = Color3.fromRGB(245, 245, 255),
        TextSize = 12,
        Parent = settingsRow,
        OnClick = function()
            if inviteListOverlay then
                inviteListOverlay.Visible = not inviteListOverlay.Visible
                if inviteListOverlay.Visible then
                    refreshInviteList()
                end
            end
        end,
    })
    invBtn.ZIndex = 37

    -- 3. Room Members Roster (4 Slots)
    local membersTitle = Instance.new("TextLabel")
    membersTitle.Size = UDim2.new(1, -48, 0, 20)
    membersTitle.Position = UDim2.new(0, 24, 0, 222)
    membersTitle.BackgroundTransparency = 1
    membersTitle.Font = Constants.THEME.FONT_TITLE
    membersTitle.Text = "SQUAD MEMBERS (1 - 4 PLAYERS)"
    membersTitle.TextColor3 = Color3.fromRGB(220, 225, 240)
    membersTitle.TextSize = 12
    membersTitle.TextXAlignment = Enum.TextXAlignment.Left
    membersTitle.ZIndex = 36
    membersTitle.Parent = frame

    local slotWidth = 160
    local slotGap = 10
    for i = 1, 4 do
        local slot = Instance.new("Frame")
        slot.Name = "MemberSlot_" .. i
        slot.Size = UDim2.new(0, slotWidth, 0, 160)
        slot.Position = UDim2.new(0, 24 + (i - 1) * (slotWidth + slotGap), 0, 246)
        slot.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
        slot.BorderSizePixel = 0
        slot.ZIndex = 36
        slot.Parent = frame

        local sCorner = Instance.new("UICorner")
        sCorner.CornerRadius = UDim.new(0, 8)
        sCorner.Parent = slot

        local sStroke = Instance.new("UIStroke")
        sStroke.Thickness = 1.2
        sStroke.Color = Color3.fromRGB(40, 45, 62)
        sStroke.Parent = slot

        local bLabel = Instance.new("TextLabel")
        bLabel.Size = UDim2.new(1, -12, 0, 22)
        bLabel.Position = UDim2.new(0, 6, 0, 8)
        bLabel.BackgroundColor3 = Color3.fromRGB(30, 36, 52)
        bLabel.Font = Constants.THEME.FONT_TITLE
        bLabel.Text = "[👑 HOST]"
        bLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
        bLabel.TextSize = 11
        bLabel.ZIndex = 37
        bLabel.Parent = slot
        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 4)
        bCorner.Parent = bLabel

        local nLabel = Instance.new("TextLabel")
        nLabel.Size = UDim2.new(1, -12, 0, 36)
        nLabel.Position = UDim2.new(0, 6, 0, 42)
        nLabel.BackgroundTransparency = 1
        nLabel.Font = Constants.THEME.FONT_TITLE
        nLabel.Text = "Waiting..."
        nLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
        nLabel.TextSize = 12
        nLabel.TextWrapped = true
        nLabel.ZIndex = 37
        nLabel.Parent = slot

        local statL = Instance.new("TextLabel")
        statL.Size = UDim2.new(1, -12, 0, 60)
        statL.Position = UDim2.new(0, 6, 0, 85)
        statL.BackgroundTransparency = 1
        statL.Font = Constants.THEME.FONT_BODY
        statL.Text = "LVL --\nCP: --"
        statL.TextColor3 = Color3.fromRGB(160, 175, 200)
        statL.TextSize = 11
        statL.TextWrapped = true
        statL.ZIndex = 37
        statL.Parent = slot

        table.insert(memberSlotFrames, {
            Frame = slot,
            NameLabel = nLabel,
            StatLabel = statL,
            BadgeLabel = bLabel,
        })
    end

    -- 4. Bottom Main Action Bar
    local lBtn = UITheme.CreateButton({
        Name = "LeaveRoomBtn",
        Text = "🚪 LEAVE ROOM",
        Size = UDim2.new(0, 180, 0, 44),
        Position = UDim2.new(0, 24, 1, -58),
        BackgroundColor3 = Color3.fromRGB(60, 30, 40),
        TextColor3 = Color3.fromRGB(255, 140, 140),
        TextSize = 13,
        Parent = frame,
        OnClick = function()
            if onActionCallback then
                onActionCallback("Leave", {})
            end
            PartyRoomModal.Toggle(false)
        end,
    })
    lBtn.ZIndex = 36

    local sBtn = UITheme.CreateButton({
        Name = "StartDungeonBtn",
        Text = "⚔️ START DUNGEON",
        Size = UDim2.new(0, 260, 0, 44),
        Position = UDim2.new(1, -284, 1, -58),
        BackgroundColor3 = Color3.fromRGB(35, 140, 65),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        Parent = frame,
        OnClick = function()
            if currentRoomState and currentRoomState.IsHost then
                if onActionCallback then
                    onActionCallback("StartDungeon", {})
                end
            end
        end,
    })
    sBtn.ZIndex = 36
    startBtn = sBtn

    -- 5. Invite Overlay Popup (Subpanel sliding on right side)
    local overlay = UITheme.CreatePanel({
        Name = "InvitePlayersOverlay",
        Size = UDim2.new(0, 320, 0, 320),
        Position = UDim2.new(1, -344, 0, 160),
        BackgroundColor3 = Color3.fromRGB(16, 20, 30),
        StrokeColor = Color3.fromRGB(55, 75, 120),
        StrokeThickness = 1.8,
        CornerRadius = UDim.new(0, 10),
        Parent = frame,
    })
    overlay.Visible = false
    overlay.ZIndex = 40
    inviteListOverlay = overlay

    local ovTitle = Instance.new("TextLabel")
    ovTitle.Size = UDim2.new(1, -40, 0, 30)
    ovTitle.Position = UDim2.new(0, 12, 0, 8)
    ovTitle.BackgroundTransparency = 1
    ovTitle.Font = Constants.THEME.FONT_TITLE
    ovTitle.Text = "INVITE PLAYERS"
    ovTitle.TextColor3 = Color3.fromRGB(240, 245, 255)
    ovTitle.TextSize = 13
    ovTitle.TextXAlignment = Enum.TextXAlignment.Left
    ovTitle.ZIndex = 41
    ovTitle.Parent = overlay

    local ovClose = UITheme.CreateButton({
        Name = "CloseOverlayBtn",
        Text = "X",
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(1, -32, 0, 8),
        BackgroundColor3 = Color3.fromRGB(35, 40, 55),
        TextColor3 = Color3.fromRGB(240, 120, 120),
        TextSize = 11,
        Parent = overlay,
        OnClick = function()
            overlay.Visible = false
        end,
    })
    ovClose.ZIndex = 41

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "PlayerScroll"
    scroll.Size = UDim2.new(1, -20, 1, -50)
    scroll.Position = UDim2.new(0, 10, 0, 40)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Color3.fromRGB(60, 80, 120)
    scroll.ZIndex = 41
    scroll.Parent = overlay
    playerListContainer = scroll
end

--[[
    Updates all fields of the modal according to the latest PartyRoomClientState.
]]
function PartyRoomModal.Update(state: Types.PartyRoomClientState?)
    currentRoomState = state
    if not state then
        PartyRoomModal.Toggle(false)
        return
    end

    if not state.IsInRoom then
        PartyRoomModal.Toggle(false)
        return
    end

    -- If not yet visible, reveal modal
    if not PartyRoomModal.IsOpen() then
        PartyRoomModal.Toggle(true)
    end

    -- Title
    if titleLabel then
        titleLabel.Text = string.format("⚔️ PARTY ROOM #%d", state.RoomId)
    end

    -- Host Badge
    if hostBadgeLabel then
        if state.IsHost then
            hostBadgeLabel.Text = "[👑 HOST]"
            hostBadgeLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
            hostBadgeLabel.BackgroundColor3 = Color3.fromRGB(50, 42, 25)
        else
            hostBadgeLabel.Text = "[MEMBER]"
            hostBadgeLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
            hostBadgeLabel.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
        end
    end

    -- Floor Cards Highlight
    for fId, cardObj in pairs(floorCards) do
        local isSelected = (state.SelectedFloor == fId)
        if isSelected then
            cardObj.Stroke.Thickness = 2.2
            cardObj.Stroke.Color = Color3.fromRGB(255, 215, 60)
            cardObj.Frame.BackgroundColor3 = Color3.fromRGB(32, 38, 55)
        else
            cardObj.Stroke.Thickness = 1.2
            cardObj.Stroke.Color = Color3.fromRGB(40, 45, 65)
            cardObj.Frame.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
        end
    end

    -- Max Players Label
    if maxPlayersLabel then
        maxPlayersLabel.Text = string.format("%d / 4", state.MaxPlayers)
    end
    if minusBtn then
        minusBtn.Visible = state.IsHost
    end
    if plusBtn then
        plusBtn.Visible = state.IsHost
    end

    -- Friends Only Toggle
    if friendsOnlyBtn then
        friendsOnlyBtn.Visible = state.IsHost
        if state.FriendsOnly then
            friendsOnlyBtn.Text = "[🔒] Friends Only"
            friendsOnlyBtn.TextColor3 = Color3.fromRGB(255, 190, 60)
            friendsOnlyBtn.BackgroundColor3 = Color3.fromRGB(50, 38, 20)
        else
            friendsOnlyBtn.Text = "[✓] Public Room"
            friendsOnlyBtn.TextColor3 = Color3.fromRGB(130, 220, 160)
            friendsOnlyBtn.BackgroundColor3 = Color3.fromRGB(25, 45, 35)
        end
    end

    -- Member Roster Slots
    for i = 1, 4 do
        local slotUi = memberSlotFrames[i]
        if slotUi then
            local member = state.Members[i]
            if member then
                slotUi.Frame.Visible = true
                slotUi.NameLabel.Text = member.DisplayName
                slotUi.StatLabel.Text = string.format("Level %d\nCP: %d", member.Level, member.CombatPower)
                if member.IsHost then
                    slotUi.BadgeLabel.Visible = true
                    slotUi.BadgeLabel.Text = "👑 HOST"
                    slotUi.BadgeLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
                    slotUi.BadgeLabel.BackgroundColor3 = Color3.fromRGB(45, 38, 22)
                else
                    slotUi.BadgeLabel.Visible = true
                    slotUi.BadgeLabel.Text = "MEMBER"
                    slotUi.BadgeLabel.TextColor3 = Color3.fromRGB(160, 190, 240)
                    slotUi.BadgeLabel.BackgroundColor3 = Color3.fromRGB(26, 34, 50)
                end
            else
                if i > state.MaxPlayers then
                    -- Slot locked by max players
                    slotUi.BadgeLabel.Visible = false
                    slotUi.NameLabel.Text = "[Locked Slot]"
                    slotUi.StatLabel.Text = "(Cap: " .. state.MaxPlayers .. ")"
                else
                    slotUi.BadgeLabel.Visible = false
                    slotUi.NameLabel.Text = "+ Open Slot"
                    slotUi.StatLabel.Text = "Waiting for player..."
                end
            end
        end
    end

    -- Start Button (Host only)
    if startBtn then
        startBtn.Visible = state.IsHost
        if state.Countdown ~= nil then
            startBtn.Text = string.format("🔥 STARTING (%ds)...", state.Countdown)
            startBtn.BackgroundColor3 = Color3.fromRGB(210, 80, 40)
        else
            startBtn.Text = "⚔️ START DUNGEON"
            startBtn.BackgroundColor3 = Color3.fromRGB(35, 140, 65)
        end
    end

    -- Refresh invite overlay if open
    if inviteListOverlay and inviteListOverlay.Visible then
        refreshInviteList()
    end
end

return PartyRoomModal
