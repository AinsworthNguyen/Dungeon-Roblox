--!strict
--[[
    init.server.luau
    Central Server Lifecycle Manager (Loader).
    
    Execution Lifecycle:
    1. Preload Network Remotes.
    2. Discover and require all Service modules in `script.Services`.
    3. Execute `:Init()` for all Services in sequence.
    4. Execute `:Start()` for all Services asynchronously (task.spawn).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Server = {
    Services = {} :: { [string]: Types.Service },
}

local function log(message: string)
    print(string.format("[Server:Core] %s", message))
end

local function warnLog(message: string)
    warn(string.format("[Server:Core] %s", message))
end

-- Service Registry Accessor
function Server.GetService(serviceName: string): any
    local service = Server.Services[serviceName]
    if not service then
        error(string.format("[Server:Core] Service '%s' is not registered or failed to load!", serviceName))
    end
    return service
end

local function bootstrap()
    local startTime = os.clock()
    log("==================================================")
    log("Starting Dungeon Crawler Server Engine (Phase 0)...")
    log("==================================================")

    -- 1. Initialize Network Remotes
    log("Preloading Remotes in ReplicatedStorage...")
    Remotes.PreloadAll()

    -- 2. Locate Services Folder
    local servicesFolder = script:WaitForChild("Services")
    local serviceList: { Types.Service } = {}

    -- 3. Require Service Modules
    for _, child in ipairs(servicesFolder:GetChildren()) do
        if child:IsA("ModuleScript") then
            local success, service = pcall(function()
                return (require :: any)(child)
            end)

            if success and type(service) == "table" then
                local serviceName = service.Name or child.Name
                service.Name = serviceName
                Server.Services[serviceName] = service
                table.insert(serviceList, service)
                log(string.format("Loaded Service Module: %s", serviceName))
            else
                warnLog(string.format("Failed to load module %s: %s", child.Name, tostring(service)))
            end
        end
    end

    -- Sort services by priority (lowest integer executes first, default 100)
    table.sort(serviceList, function(a, b)
        local pA = a.Priority or 100
        local pB = b.Priority or 100
        return pA < pB
    end)

    -- 4. Synchronous :Init() Phase
    log("--- Executing :Init() for all services ---")
    for _, service in ipairs(serviceList) do
        local initFn = service.Init
        if typeof(initFn) == "function" then
            local serviceStart = os.clock()
            local ok, err = xpcall(function()
                initFn(service)
            end, debug.traceback)

            if ok then
                local elapsed = (os.clock() - serviceStart) * 1000
                log(string.format("  [OK] %s:Init() completed (%.2f ms)", service.Name, elapsed))
            else
                warnLog(string.format("  [FAIL] %s:Init() crashed:\n%s", service.Name, tostring(err)))
            end
        end
    end

    -- 5. Asynchronous :Start() Phase
    log("--- Executing :Start() for all services ---")
    for _, service in ipairs(serviceList) do
        local startFn = service.Start
        if typeof(startFn) == "function" then
            task.spawn(function()
                local ok, err = xpcall(function()
                    startFn(service)
                end, debug.traceback)

                if not ok then
                    warnLog(string.format("  [FAIL] %s:Start() crashed:\n%s", service.Name, tostring(err)))
                end
            end)
            log(string.format("  [SPAWN] %s:Start() dispatched", service.Name))
        end
    end

    local totalElapsed = (os.clock() - startTime) * 1000
    log(string.format("Server startup completed successfully in %.2f ms!", totalElapsed))
    log("==================================================")
end

bootstrap()
