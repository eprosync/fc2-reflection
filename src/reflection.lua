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

--[[
    ~COLOR4
    CC: WholeCream
    For now this isn't a lib since its strictly for reflection.
]]
local color = {}
do
    function color.rgba(r, g, b, a)
        return setmetatable({
            r = tonumber(r) or 255,
            g = tonumber(g) or 255,
            b = tonumber(b) or 255,
            a = tonumber(a) or 255
        }, color.meta)
    end

    function color.rgb(r, g, b)
        return color.rgba(r, g, b, 255)
    end

    function color.hex(hex)
        local r, g, b, a = string_match(hex, '#(..)(..)(..)(..)')
        return color.rgba(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16), tonumber(a, 16))
    end

    function color.encoded(num, alpha)
        if alpha then
            return color.rgb(
                bit.band(bit.rshift(num, 16), 0xFF),
                bit.band(bit.rshift(num, 8), 0xFF),
                bit.band(num, 0xFF),
                bit.band(bit.rshift(num, 24), 0xFF)
            )
        else
            return color.rgb(
                bit.band(bit.rshift(num, 16), 0xFF),
                bit.band(bit.rshift(num, 8), 0xFF),
                bit.band(num, 0xFF)
            )
        end
    end

    local function hueToRGB(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < 1 / 6 then return p + (q - p) * 6 * t end
        if t < 1 / 2 then return q end
        if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
        return p
    end

    function color.hsl(h, s, l, a)
        h = tonumber(h) or 0
        s = tonumber(s) or 1
        l = tonumber(l) or 1
        a = tonumber(a) or 1

        local r, g, b
    
        if s == 0 then
            r, g, b = l, l, l
        else
            local q = (l < 0.5) and (l * (1 + s)) or (l + s - l * s)
            local p = 2 * l - q
    
            r = hueToRGB(p, q, h / 360 + 1 / 3)
            g = hueToRGB(p, q, h / 360)
            b = hueToRGB(p, q, h / 360 - 1 / 3)
        end
    
        return color.rgba(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), a * 255)
    end

    function color.hsv(h, s, l, a)
        h = tonumber(h) or 0
        s = tonumber(s) or 1
        v = tonumber(v) or 1
        a = tonumber(a) or 1

        local r, g, b
    
        local i = math.floor(h / 60) % 6
        local f = (h / 60) - i
        local p = v * (1 - s)
        local q = v * (1 - f * s)
        local t = v * (1 - (1 - f) * s)
    
        if i == 0 then
            r, g, b = v, t, p
        elseif i == 1 then
            r, g, b = q, v, p
        elseif i == 2 then
            r, g, b = p, v, t
        elseif i == 3 then
            r, g, b = p, q, v
        elseif i == 4 then
            r, g, b = t, p, v
        elseif i == 5 then
            r, g, b = v, p, q
        end
    
        return color.rgba(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), a * 255)
    end

    local function remap( value, inMin, inMax, outMin, outMax )
        return outMin + ( ( ( value - inMin ) / ( inMax - inMin ) ) * ( outMax - outMin ) )
    end

    function color.range(delta, ...)
        local list = {...}
        local length = #list
        
        local range = 1 / (length - 1)
        local index = math.floor(delta / range) + 1
        
        if index >= length then
            return list[length]
        end
        
        local first = list[index]
        local last = list[index + 1]
        
        local diff = (delta - (index - 1) * range) / range
        
        return color.new(
            remap(diff, 0, 1, first.r, last.r),
            remap(diff, 0, 1, first.g, last.g),
            remap(diff, 0, 1, first.b, last.b),
            remap(diff, 0, 1, first.a, last.a)
        )
    end

    function color.ansi_reset()
        return "\27[0m"
    end

    function color.is(data)
        return type(data) == "table" and data._color
    end

    do
        local meta = {}
        color.meta = meta
        meta._color = true
        meta.class = "color"
        meta.__index = meta

        function meta:copy()
            return color.new(self.r, self.g, self.b, self.a)
        end

        function meta:unpack()
            return self.r, self.g, self.b, self.a
        end

        function meta:hex(alpha)
            if alpha then
                return string_format('#%02X%02X%02X%02X', self.r, self.g, self.b, self.a)
            else
                return string_format('#%02X%02X%02X', self.r, self.g, self.b)
            end
        end

        function meta:number(alpha)
            if alpha then
                return (self.r * 256^3) + (self.g * 256^2) + (self.b * 256) + self.a
            else
                return (self.r * 256^2) + (self.g * 256) + self.b
            end
        end

        function meta:encoded(alpha)
            if alpha then
                return ((self.a * 0x100 + self.r) * 0x100 + self.g) * 0x100 + self.b
            else
                return (self.r * 0x100 + self.g) * 0x100 + self.b
            end
        end

        function meta:hsl()
            local r, g, b = self.r / 255, self.g / 255, self.b / 255
            local max = math.max(r, g, b)
            local min = math.min(r, g, b)
            local delta = max - min
        
            local h, s, l
            l = (max + min) / 2
        
            if delta == 0 then
                h = 0
                s = 0
            else
                s = (l <= 0.5) and (delta / (max + min)) or (delta / (2 - max - min))
        
                if max == r then
                    h = ((g - b) / delta) % 6
                elseif max == g then
                    h = ((b - r) / delta) + 2
                else
                    h = ((r - g) / delta) + 4
                end
        
                h = h * 60
                if h < 0 then h = h + 360 end
            end
        
            return h, s, l, self.a / 255
        end

        function meta:hsv()
            local r, g, b = self.r / 255, self.g / 255, self.b / 255
            local max = math.max(r, g, b)
            local min = math.min(r, g, b)
            local delta = max - min
        
            local h, s, v
            v = max
        
            if delta == 0 then
                h = 0
                s = 0
            else
                s = delta / max
        
                if max == r then
                    h = ((g - b) / delta) % 6
                elseif max == g then
                    h = ((b - r) / delta) + 2
                else
                    h = ((r - g) / delta) + 4
                end
        
                h = h * 60
                if h < 0 then h = h + 360 end
            end
        
            return h, s, v, self.a / 255
        end

        function meta:ansi()
            return string.format("\27[38;2;%d;%d;%dm", self.r, self.g, self.b)
        end

        function meta:lit()
            local _, _, l = self:hsl(self)
            return l >= .5
        end

        function meta:inverse(other, snap)
            assert(color.is(other), "color.inverse - provided input is not a color standard")
            local _, _, l = self:hsl()
            local h, s, _ = other:hsl()
        
            return color.hsl(h, s, snap and math.floor(1 - l + 0.5) or (1 - l))
        end

        function meta:__tostring()
            return "color: " .. self.r .. ", " .. self.g .. ", " .. self.b .. ", " .. self.a
        end
    end
end

--[[
    ~CHALK
    CC: WholeCream
    For now this isn't a lib since its strictly for reflection.
]]
local chalk = {}
do
    chalk.theme = {
        white           = color.rgba(255, 255, 255, 255),
        black           = color.rgba(0, 0, 0, 255),
        red             = color.rgba(255, 0, 0, 255),
        green           = color.rgba(0, 255, 0, 255),
        blue            = color.rgba(0, 0, 255, 255),
        error           = color.rgba(255, 100, 100, 255),

        datatype        = color.rgba(0x82, 0xAF, 0xF9),
        boolean         = color.rgba(0x98, 0x81, 0xF5),
        ['function']    = color.rgba(0x00, 0xC0, 0xB6),
        number          = color.rgba(0xF9, 0xD0, 0x8B),
        string          = color.rgba(0xF9, 0x8D, 0x81),
        table           = color.rgba(040, 175, 140),
        etc             = color.rgba(0xF0, 0xF0, 0xF0),
        unk             = color.rgba(255, 255, 255),
        com             = color.rgba(0x00, 0xB0, 0x00),
    }

    chalk.replacements = {
        ['\n']	= '\\n',
        ['\r']	= '\\r',
        ['\v']	= '\\v',
        ['\f']	= '\\f',
        ['\x00']= '\\x00',
        ['\\']	= '\\\\',
        ['\'']	= '\\\'',
    }

    chalk.conversions = {
        string = function(obj, iscom)
            return {chalk.theme.string, '\''..string.gsub(obj, '.', chalk.replacements)..'\''} -- took from string.lua
        end,
        ['function'] = function(obj, iscom)
            local d = debug.getinfo(obj)
            if d.what == 'C' then
                local str = tostring(obj)
                local builtin = str:match("builtin#(%d+)")
                if builtin then
                    return {chalk.theme['function'], 'builtin: ' .. builtin}
                else
                    return {chalk.theme['function'], 'cfunction: ' .. str:match("0x[%da-fA-F]+")}
                end
            else
                return {chalk.theme['function'], 'function: ' .. d.source .. "#" .. d.linedefined}
            end
        end,
        color = function(obj, iscom)
            return {chalk.theme.datatype, 'color.rgba', chalk.theme.etc, '(', chalk.theme.number, tostring(obj.r), chalk.theme.etc, ', ', chalk.theme.number,
                tostring(obj.g), chalk.theme.etc, ', ', chalk.theme.number, tostring(obj.b), chalk.theme.etc, ', ', chalk.theme.number, 
                    tostring(obj.a), chalk.theme.etc, ')'}, true
        end,
        -- FC2
        FC2Address = function(obj, iscom)
            return {chalk.theme.datatype, 'address.new', chalk.theme.etc, '(', chalk.theme.number, tostring(obj.address):match("0x[%da-fA-F]+"), chalk.theme.etc, ')'}
        end,
        FC2Entity = function(obj, iscom)
            return {chalk.theme.datatype, 'entity.new', chalk.theme.etc, '(', chalk.theme.number, tostring(obj.address):match("0x[%da-fA-F]+"), chalk.theme.etc, ')'}
        end,
        FC2Vector = function(obj, iscom)
            return {chalk.theme.datatype, 'vector:new', chalk.theme.etc, '(', chalk.theme.number, tostring(obj.x), chalk.theme.etc, ', ',
            chalk.theme.number, tostring(obj.y), chalk.theme.etc, ', ', chalk.theme.number, tostring(obj.z), chalk.theme.etc, ')'}
        end,
    }

    function chalk.typeof(x)
        local t = type(x)
        if t == "table" then
            if color.is(x) then return 'color' end
            local class = x.class
            if class then return class end
        end
        return t
    end

    function chalk.tostring(obj, iscom)
        local datatype = chalk.typeof(obj)
        if chalk.conversions[datatype] then
            return chalk.conversions[datatype](obj, iscom)
        end
        if not chalk.theme[datatype] then
            if type(obj) == "table" and not iscom then
                local ctr = {chalk.theme.unk, '('..datatype..') '}
                local ran, data = chalk.serialize(obj)
                if ran then
                    if #data > 0 then
                        for k=1, #data do
                            ctr[#ctr+1] = data[k]
                        end
                    end
                else
                    return {chalk.theme.unk, '('..datatype..') '..tostring(obj)}
                end
                return ctr
            else
                return {chalk.theme.unk, '('..datatype..') '..tostring(obj)}
            end
        else
            return {chalk.theme[datatype], tostring(obj)}
        end
    end

    function chalk.tostring_concat(obj, iscom)
        local ret = ''
        local rets, osc = chalk.tostring(obj, iscom)
        for i = 2, #rets, 2 do
            ret = ret .. rets[i]
        end
        return ret
    end

    do
        local function GetTextSize(x)
            return x:len(), 1
        end

        local function FixTabs(x, width)
            local curw = GetTextSize(x)
            local ret = ''
            while(curw < width) do -- not using string.rep since linux
                x 		= x..' '
                ret 	= ret..' '
                curw 	= GetTextSize(x)
            end
            return ret
        end
        
        function chalk.stringify(tbl, spaces, done, construct)
            local typecol = chalk.theme
            
            local count = 0
            local buffer = {}
            local rbuf = {}
            local maxwidth = 0
            local spaces = spaces or 0
            local done = done or {}
            local construct = construct or {}

            local function MsgC(...)
                local t = {...}
                local l = #construct
                for i=1, #t do
                    construct[l+i] = t[i]
                end
            end
            
            local function MsgN(...)
                local t = {..., "\n"}
                local l = #construct
                for i=1, #t do
                    construct[l+i] = t[i]
                end
            end

            done[tbl] = true

            for key,val in pairs(tbl) do
                rbuf[#rbuf + 1]  = key
                buffer[#buffer + 1] = '['..chalk.tostring_concat(key)..'] '
                maxwidth = math.max(GetTextSize(buffer[#buffer]), maxwidth)
                count = count + 1
                if count > 30 then break end
            end

            local str = string.rep(' ', spaces)
            MsgC(typecol.etc, '{\n')
            local tabbed = str..string.rep(' ', 4)
            
            for i = 1, #buffer do
                local overridesc = false
                local key = rbuf[i]
                local value = tbl[key]
                MsgC(typecol.etc, tabbed..'[')
                MsgC(unpack((chalk.tostring(key))))
                MsgC(typecol.etc, '] '..FixTabs(buffer[i], maxwidth), typecol.etc, '= ')
                if(spaces < 4 and chalk.typeof(value) == 'table' and not done[value]) then
                    chalk.stringify(value, spaces + 4, done, construct)
                else
                    local args, osc = chalk.tostring(value, true)
                    overridesc = osc
                    MsgC(unpack(args))
                end
                if(not overridesc) then
                    MsgC(typecol.etc, ',')
                end
                MsgN''
            end

            MsgC(typecol.etc, str..'}')

            return construct
        end
    end

    function chalk.serialize(tbl)
        local parsed = tostring(tbl)
        local ran, res = pcall(chalk.stringify, tbl)
        if not ran then
            parsed = parsed .. " - " .. res
        else
            parsed = res
        end
        return ran, parsed
    end
        
    function chalk.construct(...)
        local tbl = {...}
        local ctr = {}
        local color = chalk.theme.white
        for i=1, #tbl do
            local entry = tbl[i]
            if entry == nil then break end

            local type = chalk.typeof(entry)
            if i == 1 and type ~= "color" then
                ctr[#ctr+1] = color
            end
            
            if type == "string" then
                ctr[#ctr+1] = entry
            elseif type == "color" then
                color = entry
                ctr[#ctr+1] = entry
            elseif type == "table" then
                local ran, data = chalk.serialize(entry)
                if ran then
                    if #data > 0 then
                        local l = #ctr
                        for k=1, #data do
                            ctr[l+k] = data[k]
                        end
                        ctr[#ctr+1] = color
                    end
                else
                    ctr[i] = data
                end
            else
                local data = chalk.tostring(entry)
                if #data > 0 then
                    local l = #ctr
                    for k=1, #data do
                        ctr[l+k] = data[k]
                    end
                    ctr[#ctr+1] = color
                end
            end
        end

        return ctr
    end

    function chalk.string(...)
        local t = chalk.construct(...)
        local s = ""
        for i=1, #t do
            local ss = t[i]
            if type(ss) == "string" then
                s = s .. ss
            end
        end
        return s
    end

    function chalk.format(...)
        local t = chalk.construct(...)
        local s = ""
        local sa = ""
        for i=1, #t do
            local ss = t[i]
            if type(ss) == "string" then
                s = s .. ss
                sa = sa .. ss
            elseif color.is(ss) then
                s = s .. ss:ansi()
            end
        end
        return s, sa
    end

    function chalk.print(...)
        local s, sa = chalk.format(...)
        print(s)
        return s, sa
    end

    function chalk.log(...)
        local s, sa = chalk.format(...)
        fantasy.log(s)
        return s, sa
    end
end

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
function reflection.on_worker()
    local self = reflection

    local t = os.clock()
    if defer + self.delay < t then
        defer = t
        self.pipe_read()
        self.pipe_write()
    end

    _event = "on_worker"
    self.event()
end

return reflection