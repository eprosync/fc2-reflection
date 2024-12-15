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
        export const version = 0x001;
        export let active: boolean = false;

        export interface script {
            author: string,
            core: string,
            elapsed: string,
            enabled: boolean,
            forums: string,
            id: number,
            last_bonus: string,
            last_update: number,
            library: string,
            name: string,
            script: string,
            software: number,
            team: string[],
            update_notes: string
        }

        export interface session {
            avatar: string,
            directory: string,
            fid: number,
            is_media: number,
            is_sdk: number,
            level: number,
            license: string,
            link: number,
            minimum_mode: number,
            os: string,
            posts: number,
            protection: number,
            score: number,
            server: string,
            superstar: number,
            uid: number,
            unlink: number,
            unread_alerts: number,
            unread_conversations: number,
            username: string,
        }

        export namespace Input {
            export type generic = {
                command: string,
                [key: string]: any
            }

            export interface version extends generic {}
            export interface session extends generic {}

            export interface execute extends generic {
                name: string,
                source: string
            }
            export interface reset extends generic {}
            export interface reload extends generic {}

            export interface scripts extends generic {}
            export interface script_toggle extends generic {
                id: number
            }
        }

        export namespace Output {
            export interface generic {
                command: string,
                [key: string]: any
            }

            export interface version extends generic {
                version: number
            }
            
            export interface session extends generic, Reflection.session {}

            export interface error extends generic {
                name: string,
                type: string,
                reason: string
            }

            export interface execute extends generic {
                name: string
            }

            export interface reset extends generic {}

            export interface reload extends generic {
                script: string | boolean
            }

            export interface scripts extends generic {
                list: script[]
            }

            export interface script_toggle extends generic {
                id: number
            }
        }
    }
]]

local reflection_version = 0x001
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
    local self = reflection
    local func, err = loadstring(source, name)
    if not func then
        print("[Reflection] ERROR: From '" .. name .. "' -> " .. err)
        return false, "compile", err
    end

    print("[Reflection] Executing > " .. name)
    local ran, err = xpcall(func, debug.traceback)
    if not ran then
        print("[Reflection] ERROR: From '" .. name .. "' -> " .. err)
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
                print("[Reflection] ERROR: From '" .. name .. "' -> " .. err)
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
    if command == "version" then
        return {
            command = "version",
            version = reflection_version
        }
    elseif command == "reset" then
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
    elseif command == "reload" then
        if type(chunk.script) == "string" then
            print("[Reflection] Reloading script " .. chunk.script)
            fantasy.scripts():reload( chunk.script )
            return {
                command = "reload",
                script = chunk.script
            }
        else
            print("[Reflection] Reloading all scripts")
            fantasy.scripts():reset( true )
            return {
                command = "reload",
                script = true
            }
        end
    elseif command == "session" then
        -- this is such a dumb hack
        local t = {
            command = "session"
        }
        for k, v in pairs(self.session) do
            if type(v) ~= "function" then
                t[k] = v
            end
        end
        return t
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
                if members["scripts"] ~= nil then
                    for _, enabled_script in pairs( members["scripts"] ) do
                        if script["id"] == enabled_script["id"] then
                            script["enabled"] = true
                        end
                    end
                end

                table.insert(output, script)
            end
        end

        return response
    elseif command == "script_toggle" then
        if not type(chunk.id) == "number" then
            return {
                command = "error",
                name = self.script.name,
                type = "script_toggle",
                reason = "id is not a number"
            }
        end

        fantasy.session:api( fantasy.fmt( "toggleScriptStatus&id={}", chunk.id ) )

        return {
            command = "script_toggle",
            id = chunk.id
        }
    end

    return {
        command = "error",
        name = self.script.name,
        type = "command",
        reason = command .. " is not a command"
    }
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
            name = self.script.name,
            type = "json",
            reason = (chunk or "Unknown Error")
        })
    end

    local ran, err = xpcall(self.command, debug.traceback, chunk)
    if not ran then
        return json.encode({
            command = "error",
            name = self.script.name,
            type = "internal",
            reason = (err or "Unknown Error")
        })
    end

    return json.encode(err)
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
        local ran, err = xpcall(self.command, debug.traceback, chunk)
        if not ran then
            response[#response+1] = {
                command = "error",
                name = self.script.name,
                type = "internal",
                reason = (err or "Unknown Error")
            }
        else
            response[#response+1] = err
        end
    end

    if #response > 0 then
        modules.file:write(self.output, json.encode(response))
    end
end

return reflection