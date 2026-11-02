--!strict
--[[
    UIController.luau
    Central UI orchestrator connecting PlayerController, HUDView, RollCardView,
    InventoryView, and AutoSellModal with network actions.
]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SoundManager = require(Shared:WaitForChild("SoundManager"))

local PlayerController = require(script.Parent.PlayerController)
local HUDView = require(script.Parent.Parent.UI.HUDView)
local RollCardView = require(script.Parent.Parent.UI.RollCardView)
local InventoryView = require(script.Parent.Parent.UI.InventoryView)
local AutoSellModal = require(script.Parent.Parent.UI.AutoSellModal)
local SkillBarView = require(script.Parent.Parent.UI.SkillBarView)
local DungeonModal = require(script.Parent.Parent.UI.DungeonModal)
local DungeonHUDView = require(script.Parent.Parent.UI.DungeonHUDView)
local ShopModal = require(script.Parent.Parent.UI.ShopModal)
local QuestModal = require(script.Parent.Parent.UI.QuestModal)
local RebirthModal = require(script.Parent.Parent.UI.RebirthModal)
local PartyRoomModal = require(script.Parent.Parent.UI.PartyRoomModal)

local UIController = {
    Name = "UIController",
    Priority = 20,
    SkillBar = SkillBarView,
}

local isAutoRolling = false
local isRollingNow = false

--[[
    Sends a roll request to the server.
]]
function UIController.RequestRoll()
    if isRollingNow then return end
    isRollingNow = true

    task.spawn(function()
        local rollFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestRoll)
        local result = rollFn:InvokeServer() :: any

        isRollingNow = false

        if result and result.Success then
            SoundManager.Play("ChestOpen")
            local screenGui = HUDView.GetScreenGui()
            RollCardView.ShowRollResult(screenGui, result)
        elseif result and not result.Success and result.Error then
            print("[UIController] Roll notice:", result.Error)
        end
    end)
end

--[[
    Toggles the continuous Auto-Roll loop.
]]
function UIController.ToggleAutoRoll()
    isAutoRolling = not isAutoRolling
    HUDView.SetAutoRollState(isAutoRolling)

    if isAutoRolling then
        task.spawn(function()
            while isAutoRolling do
                UIController.RequestRoll()
                local cachedData = PlayerController.GetData()
                local interval = if (cachedData and cachedData.FastRollUnlocked) then 0.25 else 0.75
                task.wait(interval)
            end
        end)
    end
end

--[[
    Sends Equip Best request to the server.
]]
function UIController.EquipBest()
    task.spawn(function()
        local equipBestFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestEquipBest)
        equipBestFn:InvokeServer()
    end)
end

--[[
    Sends Upgrade Item request to the server.
]]
function UIController.UpgradeItem(uuid: string)
    task.spawn(function()
        local upgradeFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestUpgradeItem)
        local res = upgradeFn:InvokeServer(uuid) :: any
        if res and not res.Success and res.Error then
            warn("[UIController] Upgrade failed:", res.Error)
        end
    end)
end

--[[
    Sends Sell Item request to the server.
]]
function UIController.SellItem(uuid: string)
    task.spawn(function()
        local sellFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestSellItem)
        sellFn:InvokeServer(uuid)
    end)
end

--[[
    Sends Equip Item request to the server.
]]
function UIController.EquipItem(uuid: string)
    task.spawn(function()
        local equipFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestEquipItem)
        equipFn:InvokeServer(uuid)
    end)
end

--[[
    Sends Unequip Item request to the server.
]]
function UIController.UnequipItem(slot: Types.ItemSlot)
    task.spawn(function()
        local unequipFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestUnequipItem)
        unequipFn:InvokeServer(slot)
    end)
end

--[[
    Saves Auto-Sell filter preferences on server.
]]
function UIController.SaveAutoSell(settings: { [string]: boolean })
    task.spawn(function()
        local autoSellFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestUpdateAutoDelete)
        autoSellFn:InvokeServer(settings)
    end)
end

--[[
    Sends Enter Dungeon request to the server.
]]
function UIController.EnterDungeon(dungeonId: string)
    task.spawn(function()
        local enterFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestEnterDungeon)
        local success: any, err: any = enterFn:InvokeServer(dungeonId)
        if not success and err then
            warn("[UIController] Enter Dungeon failed:", err)
        end
    end)
end

--[[
    Sends Leave Dungeon request to the server.
]]
function UIController.LeaveDungeon()
    task.spawn(function()
        local leaveFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestLeaveDungeon)
        leaveFn:InvokeServer()
    end)
end

--[[
    Sends Buy Shop Item request to the server.
]]
function UIController.BuyShopItem(itemType: string)
    task.spawn(function()
        local buyFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestBuyShopItem)
        local res = buyFn:InvokeServer(itemType) :: any
        if res and res.Success then
            SoundManager.Play("Heal")
        elseif res and res.Error then
            warn("[UIController] Shop notice:", res.Error)
        end
    end)
end

--[[
    Sends Claim Quest Reward request to the server.
]]
function UIController.ClaimQuest(questId: string)
    task.spawn(function()
        local claimFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestClaimQuestReward)
        local res = claimFn:InvokeServer(questId) :: any
        if res and res.Success then
            SoundManager.Play("LevelUp")
        elseif res and res.Error then
            warn("[UIController] Quest notice:", res.Error)
        end
    end)
end

--[[
    Sends Reroll Trait request to the server.
]]
function UIController.RerollTrait(uuid: string)
    task.spawn(function()
        local rerollFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestRerollTrait)
        local res = rerollFn:InvokeServer(uuid) :: any
        if res and res.Success then
            SoundManager.Play("LevelUp")
        elseif res and res.Error then
            warn("[UIController] Trait reroll notice:", res.Error)
        end
    end)
end

--[[
    Sends Reroll Quality request to the server (150 Gold).
]]
function UIController.RerollQuality(uuid: string)
    task.spawn(function()
        local rerollFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestRerollQuality)
        local res = rerollFn:InvokeServer(uuid) :: any
        if res and res.Success then
            SoundManager.Play("LevelUp")
        elseif res and res.Error then
            warn("[UIController] Quality reroll notice:", res.Error)
        end
    end)
end

--[[
    Sends Rebirth request to the server.
]]
function UIController.RequestRebirth()
    task.spawn(function()
        local rebirthFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestRebirth)
        local res = rebirthFn:InvokeServer() :: any
        if res and res.Success then
            SoundManager.Play("Victory")
            RebirthModal.Toggle(false)
        elseif res and res.Error then
            warn("[UIController] Rebirth notice:", res.Error)
        end
    end)
end

--[[
    Checks if any modal overlay is currently open.
]]
function UIController.IsAnyModalOpen(): boolean
    return InventoryView.IsOpen() or AutoSellModal.IsOpen() or DungeonModal.IsOpen() or ShopModal.IsOpen() or QuestModal.IsOpen() or RebirthModal.IsOpen() or PartyRoomModal.IsOpen()
end

--------------------------------------------------------------------------------
-- CONTROLLER LIFECYCLE
--------------------------------------------------------------------------------

function UIController:Init()
    print("[UIController] Initializing Dark Fantasy UI system...")

    local screenGui = HUDView.GetScreenGui()

    -- 1. Build Top-Left HUD
    HUDView.BuildTopHUD(screenGui)

    -- 2. Build Bottom Action Bar (7 controls)
    HUDView.BuildBottomBar(screenGui, {
        OnRoll = function()
            UIController.RequestRoll()
        end,
        OnToggleAutoRoll = function()
            UIController.ToggleAutoRoll()
        end,
        OnOpenInventory = function()
            InventoryView.Toggle()
        end,
        OnOpenAutoSell = function()
            AutoSellModal.Toggle()
        end,
        OnOpenShop = function()
            ShopModal.Toggle()
        end,
        OnOpenQuests = function()
            QuestModal.Toggle()
        end,
        OnOpenRebirth = function()
            RebirthModal.Toggle()
        end,
        OnDungeons = function()
            DungeonModal.Toggle()
        end,
    })

    -- 3. Build Inventory & Equipment Modal
    InventoryView.Build(screenGui, {
        OnEquip = function(uuid: string)
            UIController.EquipItem(uuid)
        end,
        OnUnequip = function(slot: Types.ItemSlot)
            UIController.UnequipItem(slot)
        end,
        OnEquipBest = function()
            UIController.EquipBest()
        end,
        OnUpgrade = function(uuid: string)
            UIController.UpgradeItem(uuid)
        end,
        OnSell = function(uuid: string)
            UIController.SellItem(uuid)
        end,
        OnRerollQuality = function(uuid: string)
            UIController.RerollQuality(uuid)
        end,
        OnRerollTrait = function(uuid: string)
            UIController.RerollTrait(uuid)
        end,
    })

    -- 4. Build Auto-Sell Settings Modal
    AutoSellModal.Build(screenGui, function(newSettings)
        UIController.SaveAutoSell(newSettings)
    end)

    -- 5. Build Dungeon Expeditions Modal & In-Dungeon HUD
    DungeonModal.Build(screenGui, function(dungeonId)
        UIController.EnterDungeon(dungeonId)
    end)

    DungeonHUDView.Build(screenGui, function()
        UIController.LeaveDungeon()
    end)

    -- 6. Build Shop Modal
    ShopModal.Build(screenGui, {
        OnBuy = function(itemType: string)
            UIController.BuyShopItem(itemType)
        end,
    })

    -- 7. Build Quest Modal
    QuestModal.Build(screenGui, {
        OnClaim = function(questId: string)
            UIController.ClaimQuest(questId)
        end,
    })

    -- 8. Build Rebirth & Ascension Modal
    RebirthModal.Build(screenGui, {
        OnRebirth = function()
            UIController.RequestRebirth()
        end,
    })

    -- 8b. Build Multiplayer Custom Party Room Modal
    PartyRoomModal.Build(screenGui, function(action: string, payload: any)
        task.spawn(function()
            local partyActionFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestPartyRoomAction)
            partyActionFn:InvokeServer(action, payload)
        end)
    end)

    -- 9. Build Bottom-Right Skill Bar
    SkillBarView.Build(screenGui, {
        OnM1 = function()
            local combatCtrl = script.Parent:FindFirstChild("CombatController")
            if combatCtrl then
                local cc = (require :: any)(combatCtrl)
                if cc and typeof(cc.TriggerM1) == "function" then
                    cc.TriggerM1()
                end
            end
        end,
        OnWhirlwind = function()
            local combatCtrl = script.Parent:FindFirstChild("CombatController")
            if combatCtrl then
                local cc = (require :: any)(combatCtrl)
                if cc and typeof(cc.TriggerWhirlwind) == "function" then
                    cc.TriggerWhirlwind()
                end
            end
        end,
        OnMeteor = function()
            local combatCtrl = script.Parent:FindFirstChild("CombatController")
            if combatCtrl then
                local cc = (require :: any)(combatCtrl)
                if cc and typeof(cc.TriggerMeteor) == "function" then
                    cc.TriggerMeteor()
                end
            end
        end,
        OnDash = function()
            local combatCtrl = script.Parent:FindFirstChild("CombatController")
            if combatCtrl then
                local cc = (require :: any)(combatCtrl)
                if cc and typeof(cc.TriggerDash) == "function" then
                    cc.TriggerDash()
                end
            end
        end,
        OnHeal = function()
            local combatCtrl = script.Parent:FindFirstChild("CombatController")
            if combatCtrl then
                local cc = (require :: any)(combatCtrl)
                if cc and typeof(cc.TriggerHeal) == "function" then
                    cc.TriggerHeal()
                end
            end
        end,
    })

    -- 9. Bind Key 'B' for Inventory Shortcut
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.B then
            InventoryView.Toggle()
        end
    end)

    -- 10. Hook data updates to refresh all views in realtime
    PlayerController.OnDataChanged(function(data: Types.PlayerData)
        HUDView.Update(data)
        InventoryView.Update(data)
        AutoSellModal.Update(data)
        ShopModal.Update(data)
        QuestModal.Update(data)
        RebirthModal.Update(data)
        HUDView.SetQuestNotification(QuestModal.HasUnclaimedReward(data))
    end)

    -- 11. Hook Dungeon Network Events
    local dungeonStateEvt = Remotes.GetEvent(Constants.REMOTE_EVENTS.DungeonStateChanged)
    dungeonStateEvt.OnClientEvent:Connect(function(state: any)
        if state and typeof(state) == "table" then
            HUDView.SetBottomBarVisible(not state.InDungeon)

            DungeonHUDView.SetState(
                state.InDungeon,
                state.DungeonName,
                state.CurrentWave,
                state.TotalWaves,
                state.RemainingEnemies
            )
        end
    end)

    local dungeonCompEvt = Remotes.GetEvent(Constants.REMOTE_EVENTS.DungeonCompleted)
    dungeonCompEvt.OnClientEvent:Connect(function(data: any)
        if data and typeof(data) == "table" then
            SoundManager.Play("Victory")
            DungeonHUDView.ShowVictory(data)
        end
    end)

    local waveCompEvt = Remotes.GetEvent(Constants.REMOTE_EVENTS.WaveCompleted)
    waveCompEvt.OnClientEvent:Connect(function(_waveNum: any)
        SoundManager.Play("Victory")
    end)

    -- 12. Hook Roll Result Event (Handles roll results from 3D Chest or Dungeon Bonus Roll)
    local rollResultEvt = Remotes.GetEvent(Constants.REMOTE_EVENTS.RollResultReceived)
    rollResultEvt.OnClientEvent:Connect(function(result: any)
        if result and result.Success then
            SoundManager.Play("ChestOpen")
            local screenGui = HUDView.GetScreenGui()
            RollCardView.ShowRollResult(screenGui, result)
        end
    end)

    -- 13. Hook OpenUIModal Event (from 3D ProximityPrompts in Lobby)
    local openModalEvt = Remotes.GetEvent(Constants.REMOTE_EVENTS.OpenUIModal)
    openModalEvt.OnClientEvent:Connect(function(modalName: string)
        if modalName == "Quest" then
            QuestModal.Toggle(true)
        elseif modalName == "Shop" then
            ShopModal.Toggle(true)
        elseif modalName == "Rebirth" then
            RebirthModal.Toggle(true)
        elseif modalName == "Inventory" then
            InventoryView.Toggle(true)
        elseif modalName == "Dungeon" then
            DungeonModal.Toggle(true)
        elseif modalName == "PartyRoom" then
            PartyRoomModal.Toggle(true)
        end
    end)

    -- 14. Hook Custom Party Room Events
    local roomStateEvt = Remotes.GetEvent(Constants.REMOTE_EVENTS.PartyRoomStateUpdated)
    roomStateEvt.OnClientEvent:Connect(function(state: any)
        PartyRoomModal.Update(state)
    end)

    local inviteEvt = Remotes.GetEvent(Constants.REMOTE_EVENTS.PartyInviteReceived)
    inviteEvt.OnClientEvent:Connect(function(invite: any)
        if invite and typeof(invite) == "table" then
            SoundManager.Play("ChestOpen")
            PartyRoomModal.ShowInvitePopup(invite)
        end
    end)
end

function UIController:Start()
    print("[UIController] UI bindings active. Press 'B' for Inventory, or click 'ROLL CHEST'.")
    local initialData = PlayerController.GetData()
    if initialData then
        HUDView.Update(initialData)
        InventoryView.Update(initialData)
        AutoSellModal.Update(initialData)
        ShopModal.Update(initialData)
        QuestModal.Update(initialData)
        RebirthModal.Update(initialData)
        HUDView.SetQuestNotification(QuestModal.HasUnclaimedReward(initialData))
    end
end

return UIController
