local config <const> = require 'config.server'
local Members <const> = require 'server.members'
local Util <const> = require 'server.util'
local Ranks <const> = require 'server.gangs.ranks'
local GangStore <const> = require 'server.gangs.store'
local Vault <const> = require 'server.gangs.vault'

---@class GangActor
---@field source integer
---@field citizenid string
---@field name string
---@field gang GangRecord
---@field grade integer
---@field isBoss boolean

local Gangs <const> = {}

---@type table<integer, { inviter: integer, gang: string, expires: integer }>
local invites <const> = {}

---@param source integer
---@return GangActor?
function Gangs.actor(source)
    local membership <const> = Members.gang(source)

    if not membership then return end

    local gang <const> = GangStore.get(membership.name)

    if not gang then return end

    local grade <const> = membership.grade.level

    return {
        source = source,
        citizenid = Members.citizenid(source) --[[@as string]],
        name = Members.name(source),
        gang = gang,
        grade = grade,
        isBoss = Ranks.rank(gang.name, grade)?.isBoss == true,
    }
end

---@param source integer
---@param permission string
---@return boolean
function Gangs.hasPermission(source, permission)
    local actor <const> = Gangs.actor(source)

    return actor ~= nil and Ranks.has(actor.gang, actor.grade, permission)
end

---@class GangMember
---@field citizenid string
---@field name string
---@field grade integer
---@field rank string
---@field isBoss boolean
---@field online boolean
---@field joinedAt? string
---@field since integer unix seconds, 0 when unknown
---@field source? integer

---@param gangName string
---@return GangMember[] members online or not, highest grade first
function Gangs.roster(gangName)
    local ladder <const> = Ranks.ladder(gangName)
    local out <const> = {}

    for _, row in ipairs(Members.roster('gang', gangName)) do
        local level <const> = math.tointeger(row.membership.grade?.level) or 0
        local source <const> = Members.sourceOf(row.citizenid)

        out[#out + 1] = {
            citizenid = row.citizenid,
            name = row.name or locale('member.unknown'),
            grade = level,
            rank = ladder.ranks[level + 1]?.name or row.membership.grade?.name or '',
            isBoss = row.membership.isboss == true,
            online = source ~= nil,
            joinedAt = Util.iso(row.membership.since),
            since = Util.whole(row.membership.since),
            source = source,
        }
    end

    table.sort(out, function(a, b)
        if a.grade ~= b.grade then return a.grade > b.grade end

        return a.name < b.name
    end)

    return out
end

---@param gang GangRecord
---@param members GangMember[]
local function handover(gang, members)
    table.sort(members, function(a, b)
        if a.grade ~= b.grade then return a.grade > b.grade end

        return a.since < b.since
    end)

    local heir <const> = members[1]

    if not heir then return end

    local boss <const> = Ranks.boss(gang.name)

    Members.assignGang(heir.citizenid, gang.name, boss.grade)

    local source <const> = Members.sourceOf(heir.citizenid)

    if source then Util.notify(source, locale('gang.handover', boss.name, gang.label), 'success') end

    Util.log(gang.name, 'Handover', ('%s became %s'):format(Members.nameOf(heir.citizenid), boss.name))
end

Members.onGangLeft(function(left)
    local gang <const> = GangStore.get(left.name)

    if not gang then return end

    local members <const> = Gangs.roster(gang.name)

    if #members == 0 then
        lib.print.info(('%s dissolved, its last member left'):format(gang.name))
        GangStore.dissolve(gang.name)

        return
    end

    if not left.isboss then return end

    for _, member in ipairs(members) do
        if member.isBoss then return end
    end

    handover(gang, members)
end)

---@param actor GangActor
---@return table
function Gangs.session(actor)
    local gang <const> = actor.gang
    local ladder <const> = Ranks.ladder(gang.name)
    local can <const> = function(permission) return Ranks.has(gang, actor.grade, permission) end
    local ranks <const>, permissions <const> = {}, {}

    for _, rank in ipairs(ladder.ranks) do
        ranks[#ranks + 1] = { grade = rank.grade, name = rank.name, isBoss = rank.isBoss }
        permissions[tostring(rank.grade)] = Ranks.permissions(gang, rank.grade)
    end

    return {
        mode = 'gang',
        now = Util.iso(os.time()),
        gang = {
            name = gang.name,
            label = gang.label,
            foundedAt = Util.iso(gang.foundedAt),
        },
        me = {
            citizenid = actor.citizenid,
            name = actor.name,
            grade = actor.grade,
            rank = ladder.ranks[actor.grade + 1]?.name or '',
            isBoss = actor.isBoss,
            isFounder = gang.founderCid == actor.citizenid,
            permissions = Ranks.permissions(gang, actor.grade),
        },
        ranks = ranks,
        members = Gangs.roster(gang.name),
        inviteRadius = config.inviteRadius,
        permissionCatalog = Ranks.catalog(),
        permissions = permissions,
        vault = {
            balance = can('vault_view') and Vault.balance(gang.name) or 0,
            canSee = can('vault_view'),
            canDeposit = can('vault_deposit'),
            canWithdraw = can('vault_withdraw'),
            canSeeHistory = can('vault_audit'),
            history = can('vault_audit') and Vault.history(gang.name) or {},
        },
    }
end

---@param source integer
---@param radius number
---@return table[]
function Gangs.nearby(source, radius)
    local found <const> = {}

    for other, entry in pairs(Members.online()) do
        if other ~= source and GetVehiclePedIsIn(GetPlayerPed(other), false) == 0 then
            local distance <const> = Util.distance(source, other)

            if distance <= radius then
                local gang <const> = entry.gang.name ~= Members.NO_GANG and GangStore.get(entry.gang.name)

                found[#found + 1] = {
                    serverId = other,
                    name = Members.name(other),
                    distance = math.floor(distance * 10 + 0.5) / 10,
                    gangLabel = gang?.label or nil,
                }
            end
        end
    end

    table.sort(found, function(a, b) return a.distance < b.distance end)

    return found
end

---@param actor GangActor
---@param target integer
---@return boolean ok
---@return string? error
function Gangs.invite(actor, target)
    if not Ranks.has(actor.gang, actor.grade, 'gang_invite') then
        return false, locale('gang.cannot_invite')
    end

    if target == actor.source or not Members.entry(target) then
        return false, locale('gang.not_around')
    end

    if Members.gang(target) then
        return false, locale('gang.target_in_gang')
    end

    if Util.distance(actor.source, target) > config.inviteRadius then
        return false, locale('gang.get_closer')
    end

    local pending <const> = invites[target]

    if pending and pending.expires >= os.time() then
        return false, locale('gang.invite_pending')
    end

    invites[target] = { inviter = actor.source, gang = actor.gang.name, expires = os.time() + 60 }
    TriggerClientEvent('cobalt_management:gangInvite', target, actor.gang.name, actor.gang.label, actor.name)

    return true
end

---@param source integer
---@param gangName unknown
---@param accept boolean
function Gangs.answerInvite(source, gangName, accept)
    local invite <const> = invites[source]

    if not invite or type(gangName) ~= 'string' or invite.gang ~= gangName then return end

    invites[source] = nil

    if invite.expires < os.time() or not accept then return end

    local inviter <const> = Gangs.actor(invite.inviter)

    if not inviter or inviter.gang.name ~= invite.gang then return end
    if not Ranks.has(inviter.gang, inviter.grade, 'gang_invite') then return end

    if Members.gang(source) then
        return Util.notify(source, locale('gang.leave_first'), 'error')
    end

    Members.setGang(source, invite.gang, 0)
    Util.notify(source, locale('gang.welcome', inviter.gang.label), 'success')
    Util.notify(invite.inviter, locale('gang.joined', Members.name(source)), 'success')
end

---@param actor GangActor
---@param citizenid string
---@return boolean ok
---@return string? error
function Gangs.kick(actor, citizenid)
    if not actor.isBoss then
        return false, locale('gang.boss_kick')
    end

    if citizenid == actor.citizenid then
        return false, locale('gang.pass_first')
    end

    if Members.stored(citizenid, 'gang')?.name ~= actor.gang.name then
        return false, locale('gang.not_in_your_gang')
    end

    Members.clearGang(citizenid)

    local source <const> = Members.sourceOf(citizenid)

    if source then Util.notify(source, locale('gang.kicked', actor.gang.label), 'error') end

    return true
end

---@param actor GangActor
---@return boolean ok
---@return string? error
function Gangs.leave(actor)
    if actor.isBoss then
        return false, locale('gang.boss_cant_leave')
    end

    Members.clearGang(actor.citizenid)
    Util.notify(actor.source, locale('gang.left', actor.gang.label), 'info')
    Util.log(actor.gang.name, 'Leave', ('%s left the gang'):format(actor.name))

    return true
end

---@param actor GangActor
---@param citizenid string
---@return boolean ok
---@return string? error
function Gangs.passLeadership(actor, citizenid)
    if not actor.isBoss then
        return false, locale('gang.boss_pass')
    end

    if citizenid == actor.citizenid then
        return false, locale('gang.pick_other')
    end

    if Members.stored(citizenid, 'gang')?.name ~= actor.gang.name then
        return false, locale('gang.not_in_your_gang')
    end

    local boss <const> = Ranks.boss(actor.gang.name)

    Members.assignGang(citizenid, actor.gang.name, boss.grade)
    Members.setGang(actor.source, actor.gang.name, math.max(boss.grade - 1, 0))

    local source <const> = Members.sourceOf(citizenid)

    if source then Util.notify(source, locale('gang.leader_now', boss.name, actor.gang.label), 'success') end

    return true
end

---@param gang GangRecord
---@param by? string the boss who disbanded it, nil for an admin
function Gangs.disband(gang, by)
    local message <const> = by and locale('gang.disbanded_by', gang.label, by)
        or locale('gang.disbanded_admin', gang.label)

    for _, source in ipairs(Members.sourcesIn(gang.name)) do
        Util.notify(source, message, 'error')
    end

    Members.clearWholeGang(gang.name)
    GangStore.dissolve(gang.name)
end

---@param actor GangActor
---@param value unknown
---@return boolean ok
---@return string? error
function Gangs.savePermissions(actor, value)
    if not actor.isBoss then
        return false, locale('gang.boss_permissions')
    end

    local overrides <const> = Ranks.cleanOverrides(actor.gang, value)

    if not overrides then
        return false, locale('gang.nothing_to_save')
    end

    actor.gang.permissions = overrides
    GangStore.save(actor.gang)

    return true
end

---@param actor GangActor
---@return boolean ok
---@return string? error
function Gangs.resetPermissions(actor)
    if not actor.isBoss then
        return false, locale('gang.boss_permissions')
    end

    actor.gang.permissions = nil
    GangStore.save(actor.gang)

    return true
end

---@param source integer
---@param actor GangActor
---@param amount integer
---@param what string
---@return boolean ok
---@return string? error
function Gangs.withdraw(source, actor, amount, what)
    if not Ranks.has(actor.gang, actor.grade, 'vault_withdraw') then
        return false, locale('gang.cannot_withdraw')
    end

    local item <const> = config.gangs.charter.item
    local inventory <const> = exports.cobalt_inventory

    if not inventory:CanCarry(source, item, amount) then
        return false, locale('gang.no_room')
    end

    if not Vault.debit(actor.gang.name, amount, what, actor.name) then
        return false, locale('gang.vault_short_amount')
    end

    if not inventory:AddItem(source, item, amount, nil, nil, 'gang vault withdrawal') then
        Vault.credit(actor.gang.name, amount, locale('vault.refund'), actor.name)

        return false, locale('gang.no_room')
    end

    return true
end

---@param source integer
---@param actor GangActor
---@param amount integer
---@param what string
---@return boolean ok
---@return string? error
---@return integer? credited less than amount when the vault filled up; the rest went back to the player
function Gangs.deposit(source, actor, amount, what)
    if not Ranks.has(actor.gang, actor.grade, 'vault_deposit') then
        return false, locale('gang.cannot_deposit')
    end

    local item <const> = config.gangs.charter.item
    local inventory <const> = exports.cobalt_inventory

    if not inventory:RemoveItem(source, item, amount, nil, 'gang vault deposit') then
        return false, locale('charter.not_carrying', Util.money(amount))
    end

    local credited <const> = Vault.credit(actor.gang.name, amount, what, actor.name)

    if credited < amount then
        inventory:AddItem(source, item, amount - credited, nil, nil, 'gang vault deposit refund')
    end

    return true, nil, credited
end

AddEventHandler('playerDropped', function()
    invites[source] = nil
end)

return Gangs
