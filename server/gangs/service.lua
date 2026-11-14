local config <const> = require 'config.server'
local db <const> = require 'server.db'
local Members <const> = require 'server.members'
local Util <const> = require 'server.util'
local Archetypes <const> = require 'server.gangs.archetypes'
local GangStore <const> = require 'server.gangs.store'
local Vault <const> = require 'server.gangs.vault'

local DAY <const> = 86400
local HOUR <const> = 3600

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

---@type table<string, true>
local changing <const> = {}

---@type { id: integer, label: string, hex: string }[]
local COLOURS <const> = {}

for index, colour in ipairs(config.gangs.colours) do
    COLOURS[index] = { id = colour.id, label = locale(('gang.colour.%d'):format(colour.id)), hex = colour.hex }
end

---@return { id: integer, label: string, hex: string }[]
function Gangs.colours()
    return COLOURS
end

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
        isBoss = Archetypes.get(gang.archetype).ranks[grade]?.isBoss == true,
    }
end

---@param source integer
---@param permission string
---@return boolean
function Gangs.hasPermission(source, permission)
    local actor <const> = Gangs.actor(source)

    return actor ~= nil and Archetypes.has(actor.gang.archetype, actor.grade, permission, actor.gang.permissions)
end

---@param gang GangRecord
---@param members MemberRow[]
local function handover(gang, members)
    local archetype <const> = Archetypes.get(gang.archetype)

    table.sort(members, function(a, b)
        local gradeA <const>, gradeB <const> = a.gang.grade.level, b.gang.grade.level

        if gradeA ~= gradeB then return gradeA > gradeB end

        return (a.gangSince or '') < (b.gangSince or '')
    end)

    local heir <const> = members[1]

    if not heir then return end

    Members.assignGang(heir.citizenid, gang.name, archetype.bossGrade)

    local source <const> = Members.sourceOf(heir.citizenid)
    local boss <const> = archetype.ranks[archetype.bossGrade].name

    if source then Util.notify(source, locale('gang.handover', boss, gang.label), 'success') end

    Util.log(gang.name, 'Handover', ('%s became %s'):format(Members.nameOf(heir.citizenid), boss))
end

Members.onGangLeft(function(_, _, left)
    local gang <const> = GangStore.get(left.name)

    if not gang then return end

    local members <const> = db.members('gang', gang.name)

    if #members == 0 then
        lib.print.info(('%s dissolved, its last member left'):format(gang.name))
        GangStore.dissolve(gang.name)

        return
    end

    if not left.isboss then return end

    for _, member in ipairs(members) do
        if member.gang.isboss then return end
    end

    handover(gang, members)
end)

---@param gang GangRecord
---@param archetypeId string
---@param debit? VaultDebit
---@return boolean switched
local function switchArchetype(gang, archetypeId, debit)
    local archetype <const> = Archetypes.get(archetypeId)
    local definition <const> = { label = gang.label, grades = Archetypes.gradesTable(archetypeId) }
    local regrades <const> = {}

    for _, member in ipairs(db.members('gang', gang.name)) do
        local grade = math.min(member.gang.grade.level, archetype.bossGrade)

        if member.gang.isboss then
            grade = archetype.bossGrade
        elseif grade == archetype.bossGrade then
            grade -= 1
        end

        regrades[member.citizenid] = Members.gangShape(gang.name, grade, definition)
    end

    local previous <const> = { archetype = gang.archetype, archetypeChangedAt = gang.archetypeChangedAt, permissions = gang.permissions }

    gang.archetype = archetypeId
    gang.archetypeChangedAt = os.time()
    gang.permissions = nil

    if not GangStore.save(gang, regrades, debit, { definition = true, map = true }) then
        gang.archetype, gang.archetypeChangedAt, gang.permissions = previous.archetype, previous.archetypeChangedAt, previous.permissions

        return false
    end

    for citizenid, snapshot in pairs(regrades) do Members.syncSavedGang(citizenid, snapshot) end

    return true
end

Gangs.switchArchetype = switchArchetype

---@param since? integer
---@param hours number
---@return integer? endsAt
local function cooldownEnds(since, hours)
    if not since then return end

    local ends <const> = since + math.floor(hours * HOUR)

    return ends > os.time() and ends or nil
end

---@param actor GangActor
---@return table
function Gangs.session(actor)
    local gang <const> = actor.gang
    local archetype <const> = Archetypes.get(gang.archetype)
    local can <const> = function(permission) return Archetypes.has(gang.archetype, actor.grade, permission, gang.permissions) end
    local balance <const> = Vault.balance(gang.name)
    local ranks <const>, permissions <const>, members <const> = {}, {}, {}

    for grade = 0, archetype.bossGrade do
        local rank <const> = archetype.ranks[grade]

        ranks[#ranks + 1] = { grade = grade, name = rank.name, isBoss = rank.isBoss == true }
        permissions[tostring(grade)] = Archetypes.permissions(gang.archetype, grade, gang.permissions)
    end

    for _, row in ipairs(db.members('gang', gang.name)) do
        local level <const> = row.gang.grade.level

        members[#members + 1] = {
            citizenid = row.citizenid,
            name = row.name or locale('member.unknown'),
            grade = level,
            rank = archetype.ranks[level]?.name or row.gang.grade.name,
            isBoss = row.gang.isboss == true,
            online = Members.sourceOf(row.citizenid) ~= nil,
            joinedAt = row.gangSince,
        }
    end

    table.sort(members, function(a, b)
        if a.grade ~= b.grade then return a.grade > b.grade end

        return a.name < b.name
    end)

    local catalog <const>, allowed <const> = {}, {}

    for _, permission in ipairs(archetype.catalog) do allowed[permission] = true end

    for _, definition in ipairs(Archetypes.catalogDefinitions()) do
        if allowed[definition.id] then catalog[#catalog + 1] = definition end
    end

    local archetypes <const> = {}

    for _, id in ipairs(Archetypes.order) do
        local option <const> = Archetypes.get(id)

        archetypes[#archetypes + 1] = {
            id = id,
            label = option.label,
            summary = option.summary,
            ranks = option.bossGrade + 1,
            price = config.gangs.upgrade.costs[id] or 0,
            current = id == gang.archetype,
        }
    end

    local upgrade <const> = config.gangs.upgrade

    return {
        mode = 'gang',
        now = Util.iso(os.time()),
        gang = {
            name = gang.name,
            label = gang.label,
            archetype = gang.archetype,
            archetypeLabel = archetype.label,
            foundedAt = Util.iso(gang.foundedAt),
        },
        me = {
            citizenid = actor.citizenid,
            name = actor.name,
            grade = actor.grade,
            rank = archetype.ranks[actor.grade]?.name or '',
            isBoss = actor.isBoss,
            isFounder = gang.founderCid == actor.citizenid,
            permissions = Archetypes.permissions(gang.archetype, actor.grade, gang.permissions),
        },
        ranks = ranks,
        members = members,
        inviteRadius = config.inviteRadius,
        permissionCatalog = catalog,
        permissions = permissions,
        vault = {
            balance = can('vault_view') and balance or 0,
            canSee = can('vault_view'),
            canWithdraw = can('vault_withdraw'),
            canSeeHistory = can('vault_audit'),
            history = can('vault_audit') and Vault.history(gang.name) or {},
        },
        turf = {
            zone = gang.homeTurf,
            zones = Vault.zones(),
            cost = config.gangs.turf.cost,
            cooldownHours = config.gangs.turf.cooldownHours,
            cooldownEndsAt = Util.iso(cooldownEnds(gang.turfMovedAt, config.gangs.turf.cooldownHours)),
            canMove = can('turf_set'),
        },
        hq = {
            label = gang.hq?.label,
            movedAt = Util.iso(gang.hqMovedAt),
            cost = config.gangs.hq.cost,
            cooldownEndsAt = Util.iso(cooldownEnds(gang.hqMovedAt, config.gangs.hq.cooldownHours)),
            canMove = can('turf_set'),
        },
        archetypes = archetypes,
        upgrade = {
            ageDays = math.floor((os.time() - gang.foundedAt) / DAY),
            minAgeDays = upgrade.minAgeDays,
            members = #members,
            minMembers = upgrade.minMembers,
            vault = actor.isBoss and balance or 0,
            minVault = upgrade.minVault,
            lastChangeAt = Util.iso(gang.archetypeChangedAt),
            cooldownDays = upgrade.cooldownDays,
            cooldownEndsAt = Util.iso(cooldownEnds(gang.archetypeChangedAt, upgrade.cooldownDays * 24)),
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
    if not Archetypes.has(actor.gang.archetype, actor.grade, 'gang_invite', actor.gang.permissions) then
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
    if not Archetypes.has(inviter.gang.archetype, inviter.grade, 'gang_invite', inviter.gang.permissions) then return end

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

    local member <const> = db.member(citizenid)

    if member?.gang?.name ~= actor.gang.name then
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

    local member <const> = db.member(citizenid)

    if member?.gang?.name ~= actor.gang.name then
        return false, locale('gang.not_in_your_gang')
    end

    local archetype <const> = Archetypes.get(actor.gang.archetype)

    Members.assignGang(citizenid, actor.gang.name, archetype.bossGrade)
    Members.setGang(actor.source, actor.gang.name, archetype.bossGrade - 1)

    local source <const> = Members.sourceOf(citizenid)

    if source then
        local boss <const> = archetype.ranks[archetype.bossGrade].name

        Util.notify(source, locale('gang.leader_now', boss, actor.gang.label), 'success')
    end

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

    local overrides <const> = Archetypes.cleanOverrides(actor.gang.archetype, value)

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
    if not Archetypes.has(actor.gang.archetype, actor.grade, 'vault_withdraw', actor.gang.permissions) then
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

---@param amount integer
---@param what string
---@param who string
---@return VaultDebit?
local function vaultDebit(amount, what, who)
    if amount <= 0 then return end

    return { amount = amount, what = what, who = who }
end

---@generic F: function
---@param change F
---@return F
local function oneAtATime(change)
    return function(actor, ...)
        local name <const> = actor.gang.name

        if changing[name] then
            return false, locale('gang.change_pending')
        end

        changing[name] = true

        local ran <const>, result <const>, err <const> = pcall(change, actor, ...)

        changing[name] = nil

        if not ran then
            error(result, 0)
        end

        return result, err
    end
end

---@param actor GangActor
---@param zone unknown
---@return boolean ok
---@return string? error
local function moveTurf(actor, zone)
    local gang <const> = actor.gang

    if not Archetypes.has(gang.archetype, actor.grade, 'turf_set', gang.permissions) then
        return false, locale('gang.cannot_move_turf')
    end

    if type(zone) ~= 'string' or not Vault.zoneExists(zone) then
        return false, locale('gang.pick_zone')
    end

    if zone == gang.homeTurf then
        return false, locale('gang.same_turf')
    end

    if cooldownEnds(gang.turfMovedAt, config.gangs.turf.cooldownHours) then
        return false, locale('gang.turf_cooldown')
    end

    local cost <const> = config.gangs.turf.cost
    local debit <const> = vaultDebit(cost, locale('vault.turf_moved', Vault.zoneLabel(zone)), actor.name)
    local previous <const> = { homeTurf = gang.homeTurf, turfMovedAt = gang.turfMovedAt }

    gang.homeTurf = zone
    gang.turfMovedAt = os.time()

    if not GangStore.save(gang, nil, debit) then
        gang.homeTurf, gang.turfMovedAt = previous.homeTurf, previous.turfMovedAt

        return false, locale('gang.vault_needs', Util.money(cost))
    end

    return true
end

---@param actor GangActor
---@return string? refusal
local function hqRefusal(actor)
    local gang <const> = actor.gang

    if not Archetypes.has(gang.archetype, actor.grade, 'turf_set', gang.permissions) then
        return locale('gang.cannot_move_hq')
    end

    if cooldownEnds(gang.hqMovedAt, config.gangs.hq.cooldownHours) then
        return locale('gang.hq_cooldown')
    end
end

---@param actor GangActor
---@return boolean ok
---@return string? error
function Gangs.canMoveHq(actor)
    local refusal <const> = hqRefusal(actor)

    if refusal then return false, refusal end

    if Vault.balance(actor.gang.name) < config.gangs.hq.cost then
        return false, locale('gang.vault_needs', Util.money(config.gangs.hq.cost))
    end

    return true
end

---@param actor GangActor
---@param coords { x: number, y: number, z: number, w?: number }
---@param label string
---@return boolean ok
---@return string? error
local function moveHq(actor, coords, label)
    local refusal <const> = hqRefusal(actor)

    if refusal then return false, refusal end

    local x <const>, y <const>, z <const> = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)

    if not x or not y or not z then
        return false, locale('gang.pick_spot')
    end

    local ped <const> = GetPlayerPed(actor.source)
    local point <const> = vec3(x, y, z)

    if #(GetEntityCoords(ped) - point) > config.gangs.hq.maxDistance + 5.0 then
        return false, locale('gang.spot_too_far')
    end

    local gang <const> = actor.gang
    local cost <const> = config.gangs.hq.cost
    local debit <const> = vaultDebit(cost, locale('vault.hq_moved', label), actor.name)
    local previous <const> = { hq = gang.hq, hqMovedAt = gang.hqMovedAt }

    gang.hq = { x = x, y = y, z = z, w = tonumber(coords.w) or 0.0, label = label }
    gang.hqMovedAt = os.time()

    if not GangStore.save(gang, nil, debit, { map = true }) then
        gang.hq, gang.hqMovedAt = previous.hq, previous.hqMovedAt

        return false, locale('gang.vault_needs', Util.money(cost))
    end

    return true
end

---@param actor GangActor
---@param target unknown
---@return boolean ok
---@return string? error
local function changeArchetype(actor, target)
    local gang <const> = actor.gang
    local upgrade <const> = config.gangs.upgrade

    if not actor.isBoss then
        return false, locale('gang.boss_archetype')
    end

    if type(target) ~= 'string' or not Archetypes.exists(target) or target == 'street' then
        return false, locale('gang.pick_archetype')
    end

    if target == gang.archetype then
        return false, locale('gang.already_archetype')
    end

    if os.time() - gang.foundedAt < upgrade.minAgeDays * DAY then
        return false, locale('gang.too_young', upgrade.minAgeDays)
    end

    if cooldownEnds(gang.archetypeChangedAt, upgrade.cooldownDays * 24) then
        return false, locale('gang.archetype_cooldown')
    end

    if db.countMembers('gang', gang.name) < upgrade.minMembers then
        return false, locale('gang.need_members', upgrade.minMembers)
    end

    local cost <const> = upgrade.costs[target] or 0
    local balance <const> = Vault.balance(gang.name)

    if balance < upgrade.minVault then
        return false, locale('gang.vault_min', Util.money(upgrade.minVault))
    end

    if balance < cost then
        return false, locale('gang.vault_short', Util.money(cost - balance))
    end

    local label <const> = Archetypes.get(target).label
    local debit <const> = vaultDebit(cost, locale('vault.archetype_changed', label), actor.name)

    if not switchArchetype(gang, target, debit) then
        return false, locale('gang.debit_failed')
    end

    Util.log(gang.name, 'Archetype', ('%s made the gang a %s'):format(actor.name, label))

    return true
end

Gangs.moveTurf = oneAtATime(moveTurf)
Gangs.moveHq = oneAtATime(moveHq)
Gangs.upgrade = oneAtATime(changeArchetype)

AddEventHandler('playerDropped', function()
    invites[source] = nil
end)

return Gangs
