local core <const> = exports.cobalt_core

local Util <const> = {}

local NULL <const> = json.null

---@param value unknown
---@return unknown
local function scrub(value)
    if value == NULL or type(value) == 'userdata' then return nil end
    if type(value) ~= 'table' then return value end

    for key, inner in pairs(value) do value[key] = scrub(inner) end

    return value
end

---@param value unknown JSON text or an already decoded table
---@return table?
function Util.decode(value)
    if type(value) == 'string' then value = json.decode(value) end

    return type(value) == 'table' and scrub(value) --[[@as table]] or nil
end

---@param ... string object keys, outermost first
---@return string path a JSON path such as `$."secondjobs"."police"`
function Util.jsonPath(...)
    local keys <const> = { ... }

    for index, name in ipairs(keys) do
        assert(type(name) == 'string' and name:find('^[%w_%- ]+$'), ('invalid json key %s'):format(tostring(name)))
        keys[index] = ('"%s"'):format(name)
    end

    return '$.' .. table.concat(keys, '.')
end

---@param column 'announcements' | 'bonuses' | 'vault_log'
---@return string assignment bumps `seq` and appends the JSON entry parameter with `seq` as its id, dropping the oldest past the limit parameter
function Util.appendCapped(column)
    return ([[seq = seq + 1, %s = JSON_ARRAY_APPEND(
        IF(JSON_LENGTH(COALESCE(%s, JSON_ARRAY())) >= ?, JSON_REMOVE(%s, '$[0]'), COALESCE(%s, JSON_ARRAY())),
        '$', JSON_SET(JSON_EXTRACT(?, '$'), '$.id', seq)
    )]]):format(column, column, column, column)
end

---@param value unknown
---@return integer
function Util.whole(value)
    return math.floor(tonumber(value) or 0)
end

---@param source integer
---@param description string
---@param kind? 'success' | 'error' | 'info' | 'warning'
function Util.notify(source, description, kind)
    core:Notify(source, { title = locale('notify.title'), description = description, type = kind or 'info' })
end

---@param epoch? number
---@return string?
function Util.iso(epoch)
    return epoch and os.date('!%Y-%m-%dT%H:%M:%SZ', math.floor(epoch)) --[[@as string]] or nil
end

---@param value string
---@return string
function Util.trim(value)
    local first <const> = value:find('%S')

    if not first then return '' end

    local last <const> = #value - value:reverse():find('%S') + 1

    return value:sub(first, last)
end

---@param value unknown
---@param max integer
---@return string?
function Util.text(value, max)
    if type(value) ~= 'string' or #value > max * 2 then return end

    local trimmed <const> = Util.trim(value)

    if trimmed == '' or #trimmed > max then return end

    return trimmed
end

---@param value unknown
---@param min integer
---@param max integer
---@return integer?
function Util.integer(value, min, max)
    local number <const> = math.tointeger(tonumber(value))

    if not number or number < min or number > max then return end

    return number
end

---@param amount integer
---@return string
function Util.money(amount)
    local formatted <const> = tostring(math.floor(amount)):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')

    return '$' .. formatted
end

---@param source integer
---@param target integer
---@return number
function Util.distance(source, target)
    return #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(GetPlayerPed(target)))
end

---@param name string the job or gang
---@param action string
---@param text string
function Util.log(name, action, text)
    core:Log(('management.%s'):format(action), text, { name = name })
end

return Util
