--!strict
--[[
    Remotes.luau
    Central networking utility for Roblox RNG + Dungeon Crawler.
    
    Guarantees:
    - Auto-generates the "Remotes" folder in ReplicatedStorage on Server startup.
    - Lazily or proactively creates RemoteEvents and RemoteFunctions on Server.
    - Reliably awaits Remotes on Client with timeout detection and clear warnings.
    - Caches instances locally for high performance without repeatedly querying the DOM.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(script.Parent.Constants)

local Remotes = {}

local IS_SERVER = RunService:IsServer()
local FOLDER_NAME = "Remotes"
local CLIENT_TIMEOUT = 12

-- Caches
local eventCache: { [string]: RemoteEvent } = {}
local functionCache: { [string]: RemoteFunction } = {}

-- Folder reference
local remotesFolder: Folder? = nil

local function getRemotesFolder(): Folder
    if remotesFolder then
        return remotesFolder
    end

    if IS_SERVER then
        local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
        if existing and existing:IsA("Folder") then
            remotesFolder = existing
        else
            local newFolder = Instance.new("Folder")
            newFolder.Name = FOLDER_NAME
            newFolder.Parent = ReplicatedStorage
            remotesFolder = newFolder
        end
    else
        local found = ReplicatedStorage:WaitForChild(FOLDER_NAME, CLIENT_TIMEOUT)
        if not found or not found:IsA("Folder") then
            error(string.format("[Remotes:Client] Fatal: '%s' folder not found in ReplicatedStorage after %d seconds!", FOLDER_NAME, CLIENT_TIMEOUT))
        end
        remotesFolder = found :: Folder
    end

    local folder = remotesFolder
    if not folder then
        error("[Remotes] Failed to initialize remotes folder!")
    end
    return folder
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--[[
    Retrieves or generates a RemoteEvent by name.
    Server: Creates if absent.
    Client: Awaits the event with a timeout.
]]
function Remotes.GetEvent(name: string): RemoteEvent
    local cached = eventCache[name]
    if cached and cached.Parent ~= nil then
        return cached
    end

    local folder = getRemotesFolder()

    if IS_SERVER then
        local instance = folder:FindFirstChild(name)
        if instance and instance:IsA("RemoteEvent") then
            eventCache[name] = instance
            return instance
        end

        local newEvent = Instance.new("RemoteEvent")
        newEvent.Name = name
        newEvent.Parent = folder
        eventCache[name] = newEvent
        return newEvent
    else
        local instance = folder:WaitForChild(name, CLIENT_TIMEOUT)
        if not instance or not instance:IsA("RemoteEvent") then
            error(string.format("[Remotes:Client] Failed to acquire RemoteEvent '%s' within %d seconds!", name, CLIENT_TIMEOUT))
        end
        eventCache[name] = instance
        return instance
    end
end

--[[
    Retrieves or generates a RemoteFunction by name.
    Server: Creates if absent.
    Client: Awaits the function with a timeout.
]]
function Remotes.GetFunction(name: string): RemoteFunction
    local cached = functionCache[name]
    if cached and cached.Parent ~= nil then
        return cached
    end

    local folder = getRemotesFolder()

    if IS_SERVER then
        local instance = folder:FindFirstChild(name)
        if instance and instance:IsA("RemoteFunction") then
            functionCache[name] = instance
            return instance
        end

        local newFunction = Instance.new("RemoteFunction")
        newFunction.Name = name
        newFunction.Parent = folder
        functionCache[name] = newFunction
        return newFunction
    else
        local instance = folder:WaitForChild(name, CLIENT_TIMEOUT)
        if not instance or not instance:IsA("RemoteFunction") then
            error(string.format("[Remotes:Client] Failed to acquire RemoteFunction '%s' within %d seconds!", name, CLIENT_TIMEOUT))
        end
        functionCache[name] = instance
        return instance
    end
end

--[[
    Server-only utility to pre-instantiate all known remotes defined in Constants.
    Eliminates client-side wait latency when connecting right at player spawn.
]]
function Remotes.PreloadAll(): ()
    if not IS_SERVER then
        warn("[Remotes] PreloadAll() should only be called on the Server.")
        return
    end

    for _, eventName in pairs(Constants.REMOTE_EVENTS) do
        Remotes.GetEvent(eventName)
    end

    for _, funcName in pairs(Constants.REMOTE_FUNCTIONS) do
        Remotes.GetFunction(funcName)
    end
end

-- Expose predefined names for safe references
Remotes.Events = Constants.REMOTE_EVENTS
Remotes.Functions = Constants.REMOTE_FUNCTIONS

return Remotes
