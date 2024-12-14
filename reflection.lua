local modules = require("modules") -- lib_modules
local json = require("json") -- lib_json
--[[
    FC2 - Reflection
    A simply (and terrible) file-based loadstring, to help you develop stuff.
    Because reloading all lua files is not an option for me - WholeCream
    (Yes you make the editor, idc, make it a vs-code thingy)
    
    -- Format --
    type reflection_input = {
        name: string | undefined,
        source: string | undefined,
        command: string | undefined
    }[]

    type reflection_output = {
        error: string | undefined,
        reason: string | undefined
    }[]

    -- Example (paste into the input file) --
    [
        {
            "name": "a",
            "source": "return {on_worker = function() print('on_worker!') end}",
            "comment": "example of running a worker just like normal"
        },
        {
            "name": "b",
            "source": "return {on_loaded = function() print('on_loaded!') error('this is intentional!') end}",
            "comment": "example of on_loaded being called"
        },
        {
            "command": "reset",
            "comment": "example to clear all executed scripts from runtime"
        }
    ]
]]

local reflection = { -- for now :cry:
    input = modules.file:current_directory() .. "\\reflection_input.txt",
    output = modules.file:current_directory() .. "\\reflection_output.txt",
    delay = 1
}

-- lil hack to get any events you want :)
-- yes complain all you want
local _event = ""
setmetatable(reflection, {
    __index = function(s, index)
        _event = index
        return rawget(s, "event")
    end
})

reflection.runtimes = {}
function reflection.event(...)
    local self = reflection
    local runtimes = self.runtimes
    for i=1, #runtimes do
        local script = runtimes[i]
        local callback = script.self[_event]
        if type(callback) == "function" then
            local ran, err = xpcall(callback, debug.traceback, ...)
            if not ran then
                print("[Reflection] ERROR: From '" .. (script.name or "unknown") .. "' -> ", err)
            end
        end
    end
end

function reflection.reset()
    reflection.runtimes = {}
end

function reflection.on_loaded(script, session)
    local self = reflection
    self.session = session
    self.script = script
    modules.file:write(self.input, "")
    modules.file:write(self.output, "")
    print("[Reflection] pipe input: ", self.input)
    print("[Reflection] pipe output: ", self.output)
end

local defer = os.clock()
function reflection.on_worker()
    local self = reflection
    _event = "on_worker"
    self.event()

    local t = os.clock()
    if defer + self.delay > t then return end
    defer = t

    if not modules.file:exists(self.input) then return end
    local data = modules.file:read(self.input)
    if #data < 1 then return end
    modules.file:write(self.input, "")

    local ran, chunks = pcall(json.decode, data)
    if not ran then
        print("[Reflection] WARNING: Malformed JSON - " .. (chunks or "Unknown Error"))
        return
    end

    if type(chunks) ~= "table" or #chunks == 0 then
        print("[Reflection] WARNING: Malformed JSON - Table is not in array form")
        return
    end

    for i=1, #chunks do
        local chunk = chunks[i]
        if type(chunk) ~= "table" then
            print("[Reflection] WARNING: Malformed JSON - Array contents is not a table")
            return 
        end
    end

    local response = {}
    local runtimes = self.runtimes

    for i=1, #chunks do
        local chunk = chunks[i]
        if chunk.command == "reset" then
            self.reset()
        else
            local source = chunk.source
            local name = chunk.name or "reflection"
            local func, err = loadstring(source, name)
            if not func then
                print("[Reflection] ERROR: From '" .. name .. "' -> ", err)
                response[#response+1] = {
                    error = "compile",
                    reason = err
                }
                goto continue
            end

            print("[Reflection] Executing > " .. name)
            local ran, err = xpcall(func, debug.traceback)
            if not ran then
                print("[Reflection] ERROR: From '" .. name .. "' -> ", err)
                response[#response+1] = {
                    error = "runtime",
                    reason = err
                }
                goto continue
            end

            if type(err) == "table" then
                print("[Reflection] Module > " .. name)
                runtimes[#runtimes+1] = {
                    name = name,
                    self = err
                }

                local callback = err["on_loaded"]
                if type(callback) == "function" then
                    local mimic = {}
                    for k, v in pairs(self.script) do
                        mimic[k] = v
                    end
                    mimic.buffer = source
                    mimic.name = name
                    mimic.time = os.time()
                    mimic.id = math.random(10000000, 99999999) -- probably a bad idea
                    local ran, err = xpcall(callback, debug.traceback, mimic, self.session)
                    if not ran then
                        print("[Reflection] ERROR: From '" .. name .. "' -> ", err)
                        response[#response+1] = {
                            error = "runtime",
                            reason = err
                        }
                    end
                end
            end

            ::continue::
        end
    end

    if #response > 0 then
        modules.file:write(self.output, json.encode(response))
    end
end

return reflection