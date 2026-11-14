local config <const> = require 'config.server'
local Util <const> = require 'server.util'
local Ranks <const> = require 'server.gangs.ranks'
local Gangs <const> = require 'server.gangs.service'

---@alias GangHandler fun(actor: GangActor, data: table): boolean?, string?

---@type table<string, GangHandler>
local handlers <const> = {}

handlers['gang:invite'] = function(actor, data)
    local target <const> = Util.integer(data.serverId, 1, 65535)

    if not target then
        return false, locale('gang.pick_nearby')
    end

    return Gangs.invite(actor, target)
end

handlers['gang:kick'] = function(actor, data)
    if type(data.citizenid) ~= 'string' then
        return false, locale('common.pick_member')
    end

    return Gangs.kick(actor, data.citizenid)
end

handlers['gang:passLeadership'] = function(actor, data)
    if type(data.citizenid) ~= 'string' then
        return false, locale('common.pick_member')
    end

    return Gangs.passLeadership(actor, data.citizenid)
end

handlers['gang:savePermissions'] = function(actor, data)
    return Gangs.savePermissions(actor, data.permissions)
end

handlers['gang:resetPermissions'] = function(actor)
    return Gangs.resetPermissions(actor)
end

handlers['gang:withdraw'] = function(actor, data)
    local amount <const> = Util.integer(data.amount, 1, 100000000)

    if not amount then
        return false, locale('common.enter_amount')
    end

    return Gangs.withdraw(actor.source, actor, amount, locale('vault.withdrawal'))
end

local GangMenu <const> = {}

---@param source integer
---@return table?
function GangMenu.open(source)
    local actor <const> = Gangs.actor(source)

    return actor and Gangs.session(actor) or nil
end

---@param source integer
---@param name string
---@param data table
---@return table
function GangMenu.request(source, name, data)
    local actor <const> = Gangs.actor(source)

    if not actor then
        return { ok = false, error = locale('gang.no_longer_member') }
    end

    if name == 'gang:nearby' then
        if not Ranks.has(actor.gang, actor.grade, 'gang_invite') then
            return {}
        end

        return Gangs.nearby(source, config.inviteRadius)
    end

    if name == 'gang:leave' then
        local ok <const>, err <const> = Gangs.leave(actor)

        return { ok = ok, error = err }
    end

    if name == 'gang:disband' then
        if not actor.isBoss then
            return { ok = false, error = locale('gang.boss_disband') }
        end

        Gangs.disband(actor.gang, actor.name)
        Util.log(actor.gang.name, 'Disband', ('%s disbanded the gang'):format(actor.name))

        return { ok = true }
    end

    local run <const> = handlers[name]

    if not run then
        return { ok = false, error = locale('common.failed') }
    end

    local ok <const>, err <const> = run(actor, data)

    if not ok then
        return { ok = false, error = err or locale('common.failed') }
    end

    local after <const> = Gangs.actor(source)

    if not after then
        return { ok = false, error = locale('gang.no_longer_member') }
    end

    return { ok = true, session = Gangs.session(after) }
end

return GangMenu
