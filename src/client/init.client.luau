--!strict
--[[
    init.client.luau
    Central Client Lifecycle Manager (Loader).
    
    Execution Lifecycle:
    1. Wait for player session and replication readiness.
    2. Discover and require all Controller modules in `script.Controllers`.
    3. Execute `:Init()` for all Controllers in sequence.
    4. Execute `:Start()` for all Controllers asynchronously (task.spawn).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))

local Client = {
    Controllers = {} :: { [string]: Types.Controller },
}

local function log(message: string)
    print(string.format("[Client:Core] %s", message))
end

local function warnLog(message: string)
    warn(string.format("[Client:Core] %s", message))
end

-- Controller Registry Accessor
function Client.GetController(controllerName: string): any
    local controller = Client.Controllers[controllerName]
    if not controller then
        error(string.format("[Client:Core] Controller '%s' is not registered or failed to load!", controllerName))
    end
    return controller
end

local function bootstrap()
    local startTime = os.clock()
    log("==================================================")
    log("Starting Dungeon Crawler Client Engine (Phase 0)...")
    log("==================================================")

    -- 1. Locate Controllers Folder
    local controllersFolder = script:WaitForChild("Controllers")
    local controllerList: { Types.Controller } = {}

    -- 2. Require Controller Modules
    for _, child in ipairs(controllersFolder:GetChildren()) do
        if child:IsA("ModuleScript") then
            local success, controller = pcall(function()
                return (require :: any)(child)
            end)

            if success and type(controller) == "table" then
                local controllerName = controller.Name or child.Name
                controller.Name = controllerName
                Client.Controllers[controllerName] = controller
                table.insert(controllerList, controller)
                log(string.format("Loaded Controller Module: %s", controllerName))
            else
                warnLog(string.format("Failed to load controller module %s: %s", child.Name, tostring(controller)))
            end
        end
    end

    -- Sort controllers by priority (lowest integer executes first, default 100)
    table.sort(controllerList, function(a, b)
        local pA = a.Priority or 100
        local pB = b.Priority or 100
        return pA < pB
    end)

    -- 3. Synchronous :Init() Phase
    log("--- Executing :Init() for all controllers ---")
    for _, controller in ipairs(controllerList) do
        local initFn = controller.Init
        if typeof(initFn) == "function" then
            local ctrlStart = os.clock()
            local ok, err = xpcall(function()
                initFn(controller)
            end, debug.traceback)

            if ok then
                local elapsed = (os.clock() - ctrlStart) * 1000
                log(string.format("  [OK] %s:Init() completed (%.2f ms)", controller.Name, elapsed))
            else
                warnLog(string.format("  [FAIL] %s:Init() crashed:\n%s", controller.Name, tostring(err)))
            end
        end
    end

    -- 4. Asynchronous :Start() Phase
    log("--- Executing :Start() for all controllers ---")
    for _, controller in ipairs(controllerList) do
        local startFn = controller.Start
        if typeof(startFn) == "function" then
            task.spawn(function()
                local ok, err = xpcall(function()
                    startFn(controller)
                end, debug.traceback)

                if not ok then
                    warnLog(string.format("  [FAIL] %s:Start() crashed:\n%s", controller.Name, tostring(err)))
                end
            end)
            log(string.format("  [SPAWN] %s:Start() dispatched", controller.Name))
        end
    end

    local totalElapsed = (os.clock() - startTime) * 1000
    log(string.format("Client startup completed successfully in %.2f ms!", totalElapsed))
    log("==================================================")
end

bootstrap()
