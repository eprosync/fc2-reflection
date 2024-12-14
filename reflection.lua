local modules = require("modules") -- lib_modules
local json = require("json") -- lib_json
--[[
    FC2 - Reflection
    A simply (and terrible) lua helper, to help you develop stuff.
    Because reloading all lua files is not an option for me - WholeCream
    (Yes you make the editor, idc, make it a vs-code thingy)

    There are two modes: HTTP and PIPE
    HTTP - uses on_http_request to handle information
    PIPE - uses file-based operations to handle requests (yes this is horrible, cry)
    
    -- Format --
    export namespace Reflection {
        export namespace Input {
            export type generic = {
                command: string
            }

            export interface execute extends generic {
                name: string,
                source: string
            }

            export interface reset extends generic {}
        }

        export namespace Output {
            export interface generic {
                command: string
            }

            export interface error extends generic {
                name: string,
                type: string,
                reason: string
            }

            export interface execute extends generic {
                name: string
            }

            export interface reset extends generic {}
        }
    }
]]

local reflection = { -- for now :cry:
    mode = 0, -- modes: http = 0, pipe = 1
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
    print("[Reflection] solution: ", fantasy.solution)

    if fantasy.solution == "Universe4" then
        print("[Reflection] http: http://localhost:9282/luar")
    else
        print("[Reflection] http: http://localhost:9283/luar")
    end

    print("[Reflection] pipe input: ", self.input)
    print("[Reflection] pipe output: ", self.output)
end

function reflection.execute(source, name)
    local func, err = loadstring(source, name)
    if not func then
        print("[Reflection] ERROR: From '" .. name .. "' -> ", err)
        return false, "compile", err
    end

    print("[Reflection] Executing > " .. name)
    local ran, err = xpcall(func, debug.traceback)
    if not ran then
        print("[Reflection] ERROR: From '" .. name .. "' -> ", err)
        return false, "runtime", err
    end
    
    if type(err) == "table" then
        print("[Reflection] Module > " .. name)

        local callback = err["on_loaded"]
        if type(callback) == "function" then

            local mimic = {}
            for k, v in pairs(self.script) do
                mimic[k] = v
            end
            mimic.buffer = source
            mimic.name = name
            mimic.time = os.time()
            mimic.id = math.random(10000000, 99999999) -- probably a bad idea :)

            local ran, err = xpcall(callback, debug.traceback, mimic, self.session)
            if not ran then
                print("[Reflection] ERROR: From '" .. name .. "' -> ", err)
                return false, "on_loaded", err
            end
        end
        
        local runtimes = self.runtimes
        runtimes[#runtimes+1] = {
            name = name,
            self = err
        }
    end

    return true, err
end

function reflection.command(chunk)
    local self = reflection
    local command = chunk.command
    if command == "reset" then
        self.reset()
        return {
            command = "reset"
        }
    elseif command == "execute" then
        local source = chunk.source
        local name = chunk.name or "reflection"
        local ran, type, err = self.execute(source, name)
        if ran then
            return {
                command = "execute",
                name = name
            }
        else
            return {
                command = "error",
                name = name,
                type = type,
                reason = err
            }
        end
    elseif command == "session" then
        -- this is such a dumb hack
        self.session.command = "session"
        local data = json.encode(self.session)
        self.session.command = nil
        return data
    elseif command == "scripts" then
        -- Credits: consteliaxo @ typedev
        local scripts = fantasy.session:api("getAllScripts")
        local members = fantasy.session:api("getMember&scripts&simple")

        local response = {
            command = "scripts"
        }
        local output = {}
        response.list = output
        scripts = json.decode(scripts)
        members = json.decode(members)

        for _, script in pairs(scripts) do
            script["software"] = tonumber( script["software"] )
            script["id"] = tonumber( script["id"] )
            script["last_update"] = tonumber( script["last_update"] )
            script["enabled"] = false

            --[[
            -- 4 = FC2 global
            -- 5 = Universe4
            -- 6 = Constellation4
            -- 7 = Parallax2
            -- etc... (all fc2 solutions)
            --]]
            if script["software"] >= 4 then
                if json_getMember_result["scripts"] ~= nil then
                    for _, enabled_script in pairs( json_getMember_result["scripts"] ) do
                        if script["id"] == enabled_script["id"] then
                            script["enabled"] = true
                        end
                    end
                end

                table.insert(output, script)
            end
        end

        return response
    end
end

-- http://localhost:9283/luar - constellation4
-- http://localhost:9282/luar - universe4
function reflection.on_http_request( data )
    local self = reflection
    if self.mode ~= 0 then return end

    if data["path"] ~= "/luar" or data["script"] ~= self.script.name or not data["params"] or not data["params"]["reflection"] then
        _event = "on_http_request"
        self.event(data)
        return
    end

    local body = data["body"] or ""
    local ran, chunk = pcall(json.decode, body)
    if not ran then
        print("[Reflection] WARNING: Malformed JSON - " .. (chunk or "Unknown Error"))
        return json.encode({
            command = "error",
            name = name,
            type = "json",
            reason = (chunk or "Unknown Error")
        })
    end

    return json.encode(self.command(chunk))
end

local defer = os.clock()
function reflection.on_worker()
    local self = reflection
    _event = "on_worker"
    self.event()

    if self.mode ~= 1 then return end

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
        response[#response+1] = self.command(chunk)
    end

    if #response > 0 then
        modules.file:write(self.output, json.encode(response))
    end
end

return reflection