local config <const> = require 'config.server'
local db <const> = require 'server.db'
local Orgs <const> = require 'server.orgs'
local Members <const> = require 'server.members'
local Menu <const> = require 'server.menu'
local Staff <const> = require 'server.staff'
local Util <const> = require 'server.util'
local GangStore <const> = require 'server.gangs.store'
local Gangs <const> = require 'server.gangs.service'
local GangMenu <const> = require 'server.gangs.menu'
local GangAdmin <const> = require 'server.gangs.admin'
local Charterer <const> = require 'server.gangs.charterer'

require 'server.exports'
require 'server.commands'

local Cobalt <const> = exports.cobalt_core:GetCoreObject()

local SHIFT_TICK_MINUTES <const> = 5

---@type table<string, fun(source: integer, data: table): table?, string?>
local opens <const> = {
    org = function(source)
        local actor <const> = Staff.actor(source)

        if not actor then
            return nil, locale('menu.no_job')
        end

        return Menu.session(actor)
    end,
    gang = function(source)
        local session <const> = GangMenu.open(source)

        if not session then
            return nil, locale('gang.not_member')
        end

        return session
    end,
    gangAdmin = function(source)
        if not GangAdmin.allowed(source) then
            return nil, locale('admin.only')
        end

        return GangAdmin.session(source)
    end,
    apply = function(source, data)
        if type(data.org) ~= 'string' then
            return nil, locale('apply.pick_job')
        end

        return Menu.applySession(source, data.org)
    end,
    charter = function(source)
        return Charterer.session(source)
    end,
}

lib.callback.register('cobalt_management:open', function(source, mode, data)
    local open <const> = opens[mode]

    if not open then
        return nil, locale('menu.unknown')
    end

    return open(source, type(data) == 'table' and data or {})
end)

lib.callback.register('cobalt_management:request', function(source, name, data)
    if type(name) ~= 'string' then return end

    data = type(data) == 'table' and data or {}

    if name:sub(1, 5) == 'gang:' then return GangMenu.request(source, name, data) end
    if name:sub(1, 6) == 'admin:' then return GangAdmin.request(source, name, data) end
    if name == 'apply:send' then return Menu.apply(source, data.org, data.message) end
    if name == 'charter:send' then return Charterer.found(source, data) end
    if name == 'nearbyPlayers' then return Menu.nearby(source, config.hireRadius) end

    return Menu.request(source, name, data)
end)

lib.callback.register('cobalt_management:applicable', function()
    local out <const> = {}

    for name, org in pairs(Orgs.all()) do
        if not org.isGang and Orgs.feature(name, 'applications') then out[#out + 1] = { name = name, label = org.label } end
    end

    table.sort(out, function(a, b) return a.label < b.label end)

    return out
end)

RegisterNetEvent('cobalt_management:answerInvite', function(gangName, accept)
    Gangs.answerInvite(source, gangName, accept == true)
end)

RegisterNetEvent('cobalt_management:answerOffer', function(orgName, accept)
    Staff.answerOffer(source, orgName, accept == true)
end)

RegisterNetEvent('cobalt_management:charterDeposit', function(amount)
    Charterer.deposit(source, amount)
end)

RegisterNetEvent('cobalt_management:charterWithdraw', function(amount)
    Charterer.withdraw(source, amount)
end)

RegisterNetEvent('cobalt_management:hqPicked', function(coords, label)
    local source <const> = source
    local actor <const> = Gangs.actor(source)

    if not actor or type(coords) ~= 'table' then return end
    if type(coords.x) ~= 'number' or type(coords.y) ~= 'number' or type(coords.z) ~= 'number' then return end

    local ok <const>, err <const> = Gangs.moveHq(actor, coords, Util.text(label, 80) or locale('gang.unknown_spot'))

    Util.notify(source, ok and locale('gang.hq_moved') or err --[[@as string]], ok and 'success' or 'error')
end)

local function bootstrap()
    local players <const> = Cobalt.Functions.GetPlayers() or {}
    local loaded = 0

    for _, source in ipairs(players) do
        if Members.load(source) then loaded += 1 end
    end

    lib.print.info(('[bootstrap] loaded %d of %d online players'):format(loaded, #players))
end

CreateThread(function()
    MySQL.ready.await()
    Orgs.refresh()
    Orgs.loadSettings()
    GangStore.load()
    Orgs.refresh()

    local closed <const> = db.closeOpenShifts(SHIFT_TICK_MINUTES)

    if closed > 0 then lib.print.info(('closed %d shifts left open by the last run'):format(closed)) end

    bootstrap()
    SetInterval(db.tickShifts, SHIFT_TICK_MINUTES * 60000)
end)
