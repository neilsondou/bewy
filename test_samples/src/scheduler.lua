local json = require("cjson")

---@class EventEmitter
local EventEmitter = {}
EventEmitter.__index = EventEmitter

function EventEmitter:new()
    local instance = setmetatable({}, self)
    instance.listeners = {}
    return instance
end

function EventEmitter:on(event, callback)
    if not self.listeners[event] then
        self.listeners[event] = {}
    end
    table.insert(self.listeners[event], callback)
    return self
end

function EventEmitter:emit(event, ...)
    local callbacks = self.listeners[event]
    if callbacks then
        for _, cb in ipairs(callbacks) do
            cb(...)
        end
    end
end

-- Coroutine-based task scheduler
local Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler:new()
    local instance = setmetatable({}, self)
    instance.tasks = {}
    return instance
end

function Scheduler:add(name, fn)
    local co = coroutine.create(fn)
    table.insert(self.tasks, { name = name, co = co })
    return self
end

function Scheduler:run()
    while #self.tasks > 0 do
        local remaining = {}
        for _, task in ipairs(self.tasks) do
            local ok, msg = coroutine.resume(task.co)
            if coroutine.status(task.co) ~= "dead" then
                table.insert(remaining, task)
            else
                print(string.format("[%s] completed: %s", task.name, tostring(msg)))
            end
        end
        self.tasks = remaining
    end
end

-- Usage
local bus = EventEmitter:new()
bus:on("log", function(msg) print("LOG: " .. msg) end)
bus:emit("log", "Hello from Lua!")

local sched = Scheduler:new()
sched:add("task_a", function()
    for i = 1, 3 do
        print("A step " .. i)
        coroutine.yield()
    end
    return "done A"
end)
sched:add("task_b", function()
    for i = 1, 2 do
        print("B step " .. i)
        coroutine.yield()
    end
    return "done B"
end)
sched:run()
