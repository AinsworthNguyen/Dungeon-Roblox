--!strict
--[[
    PlayerController.luau
    Client-side manager for the local player's data, inventory, and stats cache.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SoundManager = require(Shared:WaitForChild("SoundManager"))

local PlayerController: Types.Controller = {
    Name = "PlayerController",
    Priority = 10,
}

local currentData: Types.PlayerData? = nil
local onDataChangedCallbacks: { (Types.PlayerData) -> () } = {}

function PlayerController:Init()
    print("[PlayerController] Initializing network listeners...")

    -- Listen for server push updates
    local loadedEvent = Remotes.GetEvent(Constants.REMOTE_EVENTS.PlayerDataLoaded)
    loadedEvent.OnClientEvent:Connect(function(data: Types.PlayerData)
        self:SetData(data)
    end)

    local updatedEvent = Remotes.GetEvent(Constants.REMOTE_EVENTS.PlayerDataUpdated)
    updatedEvent.OnClientEvent:Connect(function(data: Types.PlayerData)
        self:SetData(data)
    end)
end

function PlayerController:Start()
    print("[PlayerController] Fetching initial data from Server...")
    task.spawn(function()
        local requestDataFn = Remotes.GetFunction(Constants.REMOTE_FUNCTIONS.RequestPlayerData)
        local data = requestDataFn:InvokeServer() :: Types.PlayerData?
        if data then
            self:SetData(data)
            print(string.format("[PlayerController] Data synced successfully! Level: %d, Gold: %d, Rolls: %d", data.Level, data.Gold, data.RollCount))
        end
    end)
end

function PlayerController:SetData(newData: Types.PlayerData)
    if currentData and newData.Level > currentData.Level then
        SoundManager.Play("LevelUp")
    end
    currentData = newData
    for _, callback in ipairs(onDataChangedCallbacks) do
        task.spawn(callback, newData)
    end
end

function PlayerController.GetData(): Types.PlayerData?
    return currentData
end

PlayerController.GetCachedData = PlayerController.GetData

function PlayerController.OnDataChanged(callback: (Types.PlayerData) -> ())
    table.insert(onDataChangedCallbacks, callback)
    if currentData then
        task.spawn(callback, currentData)
    end
end

return PlayerController
