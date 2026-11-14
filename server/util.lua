local core <const> = exports.cobalt_core

local Util <const> = {}

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

---@param org string
---@param action string
---@param text string
function Util.log(org, action, text)
    core:Log(('management.%s'):format(action), text, { org = org })
end

return Util
