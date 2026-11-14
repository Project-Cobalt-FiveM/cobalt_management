local core <const> = exports.cobalt_core

local REQUESTS <const> = {
    'setDuty', 'nearbyPlayers', 'hire', 'fire', 'setGrade', 'giveBonus', 'answerRequest',
    'deposit', 'withdraw', 'saveRank', 'buyVehicle', 'postAnnouncement', 'saveLogo', 'setFeature',
    'sendLeave', 'sendReport', 'makeMainJob', 'leaveJob',
    'gang:nearby', 'gang:invite', 'gang:kick', 'gang:passLeadership', 'gang:leave', 'gang:disband',
    'gang:savePermissions', 'gang:resetPermissions', 'gang:withdraw', 'gang:moveTurf', 'gang:pickHq', 'gang:upgrade',
    'admin:members', 'admin:create', 'admin:save', 'admin:delete', 'admin:assign', 'admin:remove',
    'apply:send', 'charter:send',
}

local CLOSES_ON_SUCCESS <const> = {
    ['gang:pickHq'] = true,
    ['gang:leave'] = true,
    ['gang:disband'] = true,
    ['charter:send'] = true,
}

---@alias MenuMode 'org' | 'gang' | 'gangAdmin' | 'apply' | 'charter'

local Nui <const> = {}

---@type MenuMode?
local openMode

---@type table?
local openData

---@type table<string, string>?
local uiStrings

local pending = 0
local opening = false

---@return table<string, string>
local function uiLocales()
    if uiStrings then return uiStrings end

    local strings <const> = {}

    for key, value in pairs(lib.getLocales()) do
        if key:sub(1, 3) == 'ui.' then strings[key] = value end
    end

    uiStrings = strings

    return strings
end

---@param mode MenuMode
---@param data? table
---@return boolean
function Nui.open(mode, data)
    if openMode or opening then return false end

    local state <const> = LocalPlayer.state

    if state.isDead or state.cuffed or state.jailed then return false end

    opening = true

    local ok <const>, session <const>, err <const> = pcall(lib.callback.await, 'cobalt_management:open', false, mode, data)

    opening = false

    if not ok or not session then
        core:Notify({ description = ok and err or locale('menu.unavailable'), type = 'error' })

        return false
    end

    openMode, openData = mode, data
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = session, locales = uiLocales() })

    return true
end

function Nui.close()
    if not openMode then return end

    openMode, openData = nil, nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

---@return MenuMode?
function Nui.mode()
    return openMode
end

function Nui.reload()
    if not openMode then return end

    local session <const> = lib.callback.await('cobalt_management:open', false, openMode, openData)

    if not session then return Nui.close() end

    SendNUIMessage({ action = 'update', data = session })
end

---@param name string
---@param data? table
---@return any
function Nui.request(name, data)
    pending += 1

    local ok <const>, result <const> = pcall(lib.callback.await, 'cobalt_management:request', false, name, data or {})

    pending -= 1

    return ok and result or nil
end

for _, name in ipairs(REQUESTS) do
    local closes <const> = CLOSES_ON_SUCCESS[name]

    RegisterNUICallback(name, function(data, cb)
        local result <const> = Nui.request(name, data)

        if closes and result?.ok then Nui.close() end

        cb(result or { ok = false, error = locale('menu.no_answer') })
    end)
end

RegisterNUICallback('close', function(_, cb)
    Nui.close()
    cb({ ok = true })
end)

RegisterNetEvent('cobalt_management:open', Nui.open)

RegisterNetEvent('cobalt_management:membershipChanged', function()
    if pending == 0 and (openMode == 'org' or openMode == 'gang') then Nui.reload() end
end)

---@param value any
local function closeWhenRestrained(_, _, value)
    if value then Nui.close() end
end

AddStateBagChangeHandler('isDead', ('player:%s'):format(cache.serverId), closeWhenRestrained)
AddStateBagChangeHandler('cuffed', ('player:%s'):format(cache.serverId), closeWhenRestrained)
AddStateBagChangeHandler('jailed', ('player:%s'):format(cache.serverId), closeWhenRestrained)

RegisterNetEvent('cobalt_core:Client:OnPlayerUnload', Nui.close)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then Nui.close() end
end)

return Nui
