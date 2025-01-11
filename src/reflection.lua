local chalk = require("chalk")
local color = require("color4")
local modules = require("modules") -- lib_modules
local json = require("json") -- lib_json
--[[
    FC2 - Reflection
    A simple (and terrible) lua helper, to help you develop stuff.
    Because reloading all lua files is not an option for me - WholeCream
    Source: https://github.com/eprosync/fc2-reflection

    There are two modes: HTTP and PIPE
    HTTP - uses on_http_request to handle information
    PIPE - uses file-based operations to handle requests (yes this is horrible, cry)
    
    -- Format --
    export namespace Reflection {
        export const version = 0x008;
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

        export interface perk {
            name: string,
            id: number,
            description: string,
            enabled: boolean
        }

        export interface runtime {
            name: string,
            source: string,
            time: number,
            id: number
        }

        export interface config {
            [key: string]: {
                [key: string]: boolean | number | string
            }
        }

        export interface configs {
            solution: string,
            Constellation4?: config,
            Universe4?: config,
            Reflection?: config,
            [key: string]: config | undefined | string
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
            export interface uplift extends generic {
                delay?: number
            }
            export interface message extends generic {
                color?: {
                    r: number,
                    g: number,
                    b: number
                },
                message: string
            }
            export interface reload extends generic {}

            export interface session extends generic {}
            export interface perks extends generic {}

            export interface execute extends generic {
                name: string,
                source: string
            }
            export interface runtimes extends generic {}
            export interface runtimes_reset extends generic {}
            export interface runtime_kill extends generic {
                id: number
            }

            export interface scripts extends generic {}
            export interface script_toggle extends generic {
                id: number
            }

            export interface configs extends generic {}
            export interface config_update extends generic {
                solution: string,
                runtime: number,
                script: string,
                key: string,
                value: boolean | number | string,
                type: "boolean" | "number" | "string"
            }
        }

        export namespace Output {
            export interface generic {
                command: string,
                [key: string]: any
            }

            export interface error extends generic {
                name: string,
                type: string,
                reason: string
            }

            export interface version extends generic {
                version: number
            }
            export interface uplift extends generic {
                delay: number,
                input: string,
                output: string
            }
            export interface message extends generic {
                color?: {
                    r: number,
                    g: number,
                    b: number
                },
                message: string
            }
            export interface reload extends generic {
                script: string | boolean
            }

            export interface session extends generic, Reflection.session {}
            export interface perks extends generic {
                list: perk[]
            }

            export interface execute extends generic {
                name: string
            }
            export interface runtimes extends generic {
                list: runtime[]
            }
            export interface runtime_kill extends generic {
                name?: string,
                id: number
            }
            export interface runtimes_reset extends generic {}

            export interface scripts extends generic {
                list: script[]
            }
            export interface script_toggle extends generic {
                id: number
            }

            export interface configs extends generic, Reflection.configs {}
            export interface config_update extends generic {
                solution: string,
                runtime: number,
                script: string,
                key: string,
                value: boolean | number | string,
                type: string
            }
        }
    }
]]

local reflection_version = 0x008
local reflection = { -- for now :cry:
    input = modules.file:current_directory() .. "\\reflection_input.txt",
    output = modules.file:current_directory() .. "\\reflection_output.txt",
    delay = 1
}

local explode
do
    local totable = string.ToTable
    local string_sub = string.sub
    local string_find = string.find
    local string_len = string.len

    explode = function( separator, str, withpattern )
        if ( separator == "" ) then return totable( str ) end
        if ( withpattern == nil ) then withpattern = false end

        local ret = {}
        local current_pos = 1

        for i = 1, string_len( str ) do
            local start_pos, end_pos = string_find( str, separator, current_pos, not withpattern )
            if ( not start_pos ) then break end
            ret[ i ] = string_sub( str, current_pos, start_pos - 1 )
            current_pos = end_pos + 1
        end

        ret[ #ret + 1 ] = string_sub( str, current_pos )

        return ret
    end
end

function reflection.print(...)
    local t = {...}
    table.insert(t, 1, "] ")
    table.insert(t, 1, color.rgba(255,255,255))
    table.insert(t, 1, "Reflection")
    table.insert(t, 1, color.rgba(0,192,192))
    table.insert(t, 1, "[")
    return chalk.print(unpack(t))
end
local print = reflection.print

function reflection.log(...)
    return chalk.log(...)
end

-- lil hack to get any events you want :)
-- yes complain all you want
local _event = ""
setmetatable(reflection, {
    __index = function(s, index)
        _event = index
        return rawget(s, "event")
    end
})

function reflection.nameid(tracker)
    return "'" .. (tracker.name or "unknown") .. "'#" .. tracker.id
end

function reflection.hash(str)
    local hash = 0
    local prime = 31
    for i = 1, #str do
        local char = str:byte(i)
        hash = (hash * prime + char) % 2^32
    end
    return hash
end

reflection.runtimes = {}
function reflection.event(...)
    local self = reflection
    local runtimes = self.runtimes
    local responses
    local c = 0
    for i=1, #runtimes do
        local runtime = runtimes[i]
        local callback = runtime.self[_event]
        if type(callback) == "function" then
            local returns = {xpcall(callback, debug.traceback, ...)}
            local ran = table.remove(returns, 1)
            if not ran then
                local err = table.remove(returns, 1)
                local stack = #explode("\n", debug.traceback())
                local trace = explode("\n", err)
                for i=1, stack do trace[#trace] = nil end
                err = table.concat(trace, "\n")
                local nameid = self.nameid(runtime.script)
                self.enqueue({
                    command = "error",
                    name = nameid,
                    type = _event,
                    reason = err
                })
                print(chalk.theme.error, "ERROR: From '" .. nameid .. " -> ", err)
                print("Removing '" .. nameid.. " from runtime (make sure to error isolate your code!)")
                table.remove(runtimes, i-c) c = c + 1
            else
                if not responses and returns[1] ~= nil then
                    responses = returns
                end
            end
        end
    end
    if responses then
        return unpack(responses)
    end
end

function reflection.vsc_download()
    -- code --install-extension [path]
    -- code --list-extensions --show-versions
    -- https://api.github.com/repos/eprosync/fc2-reflection/releases/latest
    local self = reflection
    local result = fantasy.terminal("code --version")
    if string.find(result, "'code' is not recognized") or string.find(result, "command not found") then
        print("VSC not found") 
    else
        print("VSC - " .. explode("\n", result)[1])

        print("Looking for extensions...")
        local data = fantasy.terminal( "curl -H \"User-Agent: fc2-reflection/1.0\" https://api.github.com/repos/eprosync/fc2-reflection/releases/latest")
        local ran, data = pcall(json.decode, data)
        if ran then
            local location = modules.file:current_directory() .. "\\reflection.vsix"
            local cache = modules.file:current_directory() .. "\\reflection-extension.txt"
            if self.session.os ~= "windows" then
                location = location:gsub("\\", "/")
                cache = cache:gsub("\\", "/")
            end

            local extensions = fantasy.terminal( "code --list-extensions --show-versions" )
            extensions = explode("\n", extensions)
            
            local installed = "none"
            for i=1, #extensions do
                local entry = extensions[i]
                local version = string.match(entry, "wholecream.fc2%-reflection@(%d+%.%d+%.%d+)$")
                if version then
                    installed = version
                end
            end
    
            if installed ~= data.tag_name then
                print("VSC installed extension deviates from file")
                should = true
            end

            if not should and modules.file:exists(cache) then
                local ran, cache = pcall(json.decode, modules.file:read(cache))
                if not ran then
                    should = true
                else
                    if data.tag_name ~= cache.tag_name then
                        should = true
                    end
                end

                if should then
                    print("Extension has a deviation on file")
                end
            else
                should = true
            end
    
            if should then
                print("Downloading...")
                modules.file:write(cache, json.encode(data))
                
                local asset
                local assets = data.assets
                for i=1, #assets do
                    local v = assets[i]
                    if v.content_type == "application/vsix" then
                        asset = v
                        break
                    end
                end
        
                if asset then
                    fantasy.terminal( "curl -L -H \"User-Agent: fc2-reflection/1.0\" " .. asset.browser_download_url .. " --output " .. location)
                    print("Extension downloaded, installing...")
                    local result = fantasy.terminal( "code --install-extension " .. location)
                    if string.find(result, "Extension 'reflection.vsix' was successfully installed.") then
                        print("VSC Extension Installed, you may reload your IDE to view changes")
                        return true
                    else
                        print("Error installing VSC Extension, please check the error here:")
                        print(result)
                    end
                else
                    print("Unable to find latest fc2-reflection vsix release")
                end
            else
                print("Looks like you are running the latest vsix release")
                return true
            end
        else
            print("Unable to decode latest fc2-reflection release - " .. data)
        end
    end
end

function reflection.on_loaded(script, session)
    local self = reflection
    self.session = session
    self.script = script

    if self.session.os ~= "windows" then
        self.input = self.input:gsub("\\", "/")
        self.output = self.output:gsub("\\", "/")
    end

    modules.file:write(self.input, "")
    modules.file:write(self.output, "")
    print("solution: ", fantasy.solution)

    if fantasy.solution == "Universe4" then
        print("http: http://localhost:9282/luar")
    else
        print("http: http://localhost:9283/luar")
    end

    print("pipe input: ", self.input)
    print("pipe output: ", self.output)

    local installed = self.vsc_download()
    if installed then
        local found = false
        local processes = modules.process:list()
        for k, v in pairs(processes) do
            if v.name:lower() == "code.exe" or v.name:lower() == "code" then
                found = true
                break
            end
        end
        if not found then
            print("VSCode is not running, opening...")
            fantasy.terminal("code")
        end
    end
end

function reflection.on_solution_calibrated(data)
    local self = reflection
    self.calibration = data
    _event = "on_solution_calibrated"
    self.event(data)
end

function reflection.execute(source, name)
    local self = reflection
    local func, err = loadstring("local reflection=({...})[1];local reply=reflection.reply;local print=reflection.print;".. source, name)
    if not func then
        print(chalk.theme.error, "ERROR: From '" .. name .. "' -> " .. err)
        return false, "compile", err
    end

    print("Executing > " .. name)
    local stack = #explode("\n", debug.traceback())
    local returns = {xpcall(func, debug.traceback, self)}
    local ran = table.remove(returns, 1)
    if not ran then
        local err = table.remove(returns, 1)
        local stack = #explode("\n", debug.traceback())
        local trace = explode("\n", err)
        for i=1, stack do trace[#trace] = nil end
        err = table.concat(trace, "\n")
        print(chalk.theme.error, "ERROR: From '" .. name .. "' -> " .. err)
        return false, "runtime", err
    end
    
    local module = returns[1]
    if type(module) == "table" then
        print("Module > " .. name)

        local tracker = {}
        for k, v in pairs(self.script) do
            tracker[k] = v
        end
        tracker.buffer = source
        tracker.name = name
        tracker.time = os.time()
        tracker.id = self.hash(name)
        local nameid = self.nameid(tracker)

        local callback = module["on_loaded"]
        if type(callback) == "function" then
            local ran, err = xpcall(callback, debug.traceback, tracker, self.session)

            if not ran then
                local trace = explode("\n", err)
                for i=1, stack do trace[#trace] = nil end
                err = table.concat(trace, "\n")
                print(chalk.theme.error, "ERROR: From " .. nameid .. " -> " .. err)
                print("Not adding to runtime due to error")
                return false, "on_loaded", err
            end

            if err == false then
                print("" .. nameid .. " returned false on load, so it won't be ran")
                return true, err
            end
        end

        local callback = module["on_scripts_loaded"]
        if type(callback) == "function" then
            local ran, err = xpcall(callback, debug.traceback, tracker, self.session)
            if not ran then
                local trace = explode("\n", err)
                for i=1, stack do trace[#trace] = nil end
                err = table.concat(trace, "\n")
                print(chalk.theme.error, "ERROR: From " .. nameid .. " -> " .. err)
                print("Not adding to runtime due to error")
                return false, "on_scripts_loaded", err
            end
        end

        local callback = module["on_solution_calibrated"]
        if type(callback) == "function" then
            local ran, err = xpcall(callback, debug.traceback, tracker, self.calibration)
            if not ran then
                local trace = explode("\n", err)
                for i=1, stack do trace[#trace] = nil end
                err = table.concat(trace, "\n")
                print(chalk.theme.error, "ERROR: From " .. nameid .. " -> " .. err)
                print("Not adding to runtime due to error")
                return false, "on_solution_calibrated", err
            end

            if err == false then
                print("" .. nameid .. " returned false on calibration, so it won't be ran")
                return true, err
            end
        end
        
        local runtimes = self.runtimes

        for i=1, #runtimes do
            local runtime = runtimes[i]
            if runtime.script.id == tracker.id then
                local nameid = self.nameid(tracker)
                print("" .. nameid .. " already exists, reloading runtime")
                table.remove(runtimes, i)
                break
            end
        end

        runtimes[#runtimes+1] = {
            script = tracker,
            self = module
        }
    end

    return true, returns
end

function reflection.command(chunk)
    local self = reflection
    local command = chunk.command
    if command == "version" then
        return {
            command = "version",
            version = reflection_version
        }
	elseif command == "uplift" then
		if chunk.delay then self.delay = chunk.delay end
		return {
			command = "uplift",
			input = self.input,
			output = self.output,
			delay = self.delay
		}
	elseif command == "message" then
		reflection.print(chunk.message)
		return {
            command = "null"
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
    elseif command == "configs" then
        local dataset = json.decode(modules.configuration:get_local())
        dataset.command = "configs"

        local runtimes = self.runtimes
        local t = {}

        -- generated runtime configurations
        for i=1, #runtimes do
            local runtime = runtimes[i]
            local handle = runtime.self
            local data = {}
            for k, v in pairs(handle) do
                local ktype = type(k)
                local ntype = type(v)
                if ktype == "string" and (ntype == "number" or ntype == "string" or ntype == "boolean") then
                    data[k] = v
                end
            end
            t[runtime.script.name .. "#" .. runtime.script.id] = data -- for some reason json parser doesn't like numbers not in iteration
        end

        dataset.solution = fantasy.solution
        dataset.Reflection = t

        return dataset
    elseif command == "config_update" then
        local solution = chunk.solution
        local runtime_id = chunk.runtime
        local script = chunk.script
        local key = chunk.key
        local value = chunk.value
        local datatype = chunk.type

        if runtime_id and runtime_id ~= 0 then
            if type(runtime_id) ~= "number" then
                return  {
                    command = "error",
                    name = self.script.name,
                    type = "config_update",
                    reason = "id is not a number"
                }
            end

            local runtimes = self.runtimes
            local dataset
            for i=1, #runtimes do
                local runtime = runtimes[i]
                if runtime.script.id == runtime_id then
                    dataset = runtime
                    break
                end
            end

            if not dataset then
                return {
                    command = "error",
                    name = self.script.name,
                    type = "config_update",
                    reason = "cannot change invalid runtime '" .. runtime_id .. "'"
                }
            end

            dataset = dataset.self

            if dataset[key] == nil then
                return {
                    command = "error",
                    name = self.script.name,
                    type = "config_update",
                    reason = "runtime '" .. runtime_id .. "' doesn't seem to have configuration key '" .. key .. "'"
                }
            end

            if datatype ~= type(dataset[key]) then
                return {
                    command = "error",
                    name = self.script.name,
                    type = "config_update",
                    reason = "runtime '" .. runtime_id .. "' datatype doesn't match from '" .. key .. "' > " .. datatype .. " - " .. type(dataset[key])
                }
            end

            dataset[key] = value

            return chunk
        end

        local base = json.decode(modules.configuration:get_local())
        local dataset = base[solution]
        if not dataset then
            return {
                command = "error",
                name = self.script.name,
                type = "config_update",
                reason = "cannot change invalid solution '" .. solution .. "'"
            }
        end

        dataset = dataset[script]
        if not dataset then
            return {
                command = "error",
                name = self.script.name,
                type = "config_update",
                reason = "cannot change invalid script '" .. script .. "'"
            }
        end

        if dataset[key] == nil then
            return {
                command = "error",
                name = self.script.name,
                type = "config_update",
                reason = "script '" .. script .. "' doesn't seem to have configuration key '" .. key .. "'"
            }
        end

        if datatype ~= type(dataset[key]) then
            return {
                command = "error",
                name = self.script.name,
                type = "config_update",
                reason = "script '" .. script .. "' datatype doesn't match from '" .. key .. "' > " .. datatype .. " - " .. type(dataset[key])
            }
        end

        dataset[key] = value
        modules.configuration:overwrite(json.encode(base))

        return chunk
    elseif command == "runtimes" then
        local runtimes = self.runtimes
        local t = {}
        for i=1, #runtimes do
            local runtime = runtimes[i]
            t[#t+1] = {
                name = runtime.script.name,
                source = runtime.script.buffer,
                time = runtime.script.time,
                id = runtime.script.id
            }
        end
        return {
            command = "runtimes",
            list = t
        }
    elseif command == "runtimes_reset" then
        self.runtimes = {}
        print("Runtimes have been killed")
        return {
            command = "runtimes_reset"
        }
    elseif command == "runtime_kill" then
        local id = chunk.id
        if not type(id) == "number" then
            return {
                command = "error",
                name = self.script.name,
                type = "runtime_kill",
                reason = "id is not a number"
            }
        end

        local runtimes = self.runtimes
        for i=1, #runtimes do
            local runtime = runtimes[i]
            if runtime.script.id == id then
                local nameid = self.nameid(runtime.script)
                print("" .. nameid .. " killed")
                table.remove(runtimes, i)
                return {
                    command = "runtime_kill",
                    name = runtime.script.name,
                    id = id
                }
            end
        end

        return {
            command = "runtime_kill",
            id = id
        }
    elseif command == "reload" then
        if type(chunk.script) == "string" then
            print("Reloading script " .. chunk.script)
            fantasy.scripts():reload( chunk.script )
            return {
                command = "reload",
                script = chunk.script
            }
        else
            print("Reloading all scripts")
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

        --[[
            1 = zombie
            2 = kernel
            3 = ?
        ]]
        for k, v in pairs(self.session) do
            if type(v) ~= "function" then
                t[k] = v
            end
        end
        return t
    elseif command == "perks" then
        local perks = fantasy.session:api("listPerks")
        perks = json.decode(perks)

        -- session.has_perk appears to be having issues...?
        local perks_active = self.session.get_perks()
        for k, v in pairs(perks) do
            v.id = tonumber(v.id)
            for kk, vv in pairs(perks_active) do
                if vv.id == v.id then
                    v.enabled = true
                end
            end
            if v.enabled == nil then
                v.enabled = false
            end
        end

        return {
            command = "perks",
            list = perks
        }
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

function reflection.reply(...)
    reflection.enqueue({
        command = "message",
        color = {r = 255, g = 255, b = 255},
        message = chalk.string(...)
    })
end

-- http://localhost:9283/luar - constellation4
-- http://localhost:9282/luar - universe4
function reflection.on_http_request( data )
    local self = reflection

    if data["path"] ~= "/luar" or data["script"] ~= self.script.name or not data["params"] or not data["params"]["reflection"] then
        _event = "on_http_request"
        return self.event(data)
    end

    local body = data["body"] or ""
    local ran, chunk = pcall(json.decode, body)
    if not ran then
        print("WARNING: Malformed JSON - " .. (chunk or "Unknown Error"))
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

    return json.encode(err or {})
end

reflection.queue = {}
function reflection.enqueue(command)
    local queue = reflection.queue
    queue[#queue+1] = command
end

function reflection.pipe_write()
    local self = reflection
    if #self.queue > 0 and modules.file:is_empty(self.output) then
        local queue = self.queue
        self.queue = {}
        modules.file:write(self.output, json.encode(queue))
    end
end

function reflection.pipe_read()
    local self = reflection
    if not modules.file:exists(self.input) then return end
    local data = modules.file:read(self.input)
    if #data < 1 then return end
    modules.file:write(self.input, "")

    local ran, chunks = pcall(json.decode, data)
    if not ran then
        print("WARNING: Malformed JSON - " .. (chunks or "Unknown Error"))
        return
    end

    if type(chunks) ~= "table" or #chunks == 0 then
        print("WARNING: Malformed JSON - Table is not in array form")
        return
    end

    for i=1, #chunks do
        local chunk = chunks[i]
        if type(chunk) ~= "table" then
            print("WARNING: Malformed JSON - Array contents is not a table")
            return 
        end
    end

    for i=1, #chunks do
        local chunk = chunks[i]
        local ran, err = xpcall(self.command, debug.traceback, chunk)
        if not ran then
            self.enqueue({
                command = "error",
                name = self.script.name,
                type = "internal",
                reason = (err or "Unknown Error")
            })
        elseif err then
            self.enqueue(err)
        end
    end
end

local defer = os.clock()
function reflection.on_worker(...)
    local self = reflection

    local t = os.clock()
    if defer + self.delay < t then
        defer = t
        self.pipe_read()
        self.pipe_write()
    end

    _event = "on_worker"
    self.event(...)
end

return reflection