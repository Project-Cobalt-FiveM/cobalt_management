local config <const> = require 'config.server'
local db <const> = require 'server.db'
local Members <const> = require 'server.members'
local Util <const> = require 'server.util'
local Archetypes <const> = require 'server.gangs.archetypes'
local GangStore <const> = require 'server.gangs.store'
local Vault <const> = require 'server.gangs.vault'
local Gangs <const> = require 'server.gangs.service'

local core <const> = exports.cobalt_core

local Admin <const> = {}

---@param source integer
---@return boolean
function Admin.allowed(source)
    return core:HasPermission(source, 'admin')
end

---@param source integer
---@return table
function Admin.session(source)
    local gangs <const>, archetypes <const>, online <const> = {}, {}, {}
    local counts <const> = db.memberCounts('gang')

    for name, gang in pairs(GangStore.all()) do
        gangs[#gangs + 1] = {
            name = name,
            label = gang.label,
            archetype = gang.archetype,
            homeTurf = gang.homeTurf,
            blipColor = gang.blipColor,
            members = counts[name] or 0,
            founderName = gang.founderCid and Members.nameOf(gang.founderCid) or nil,
            foundedAt = Util.iso(gang.foundedAt),
        }
    end

    table.sort(gangs, function(a, b) return a.label < b.label end)

    for _, id in ipairs(Archetypes.order) do
        local archetype <const> = Archetypes.get(id)
        local ranks <const> = {}

        for grade = 0, archetype.bossGrade do
            local rank <const> = archetype.ranks[grade]

            ranks[#ranks + 1] = { grade = grade, name = rank.name, isBoss = rank.isBoss == true }
        end

        archetypes[#archetypes + 1] = { id = id, label = archetype.label, ranks = ranks }
    end

    for other, entry in pairs(Members.online()) do
        local gang <const> = entry.gang.name ~= Members.NO_GANG and GangStore.get(entry.gang.name)

        online[#online + 1] = {
            serverId = other,
            citizenid = entry.citizenid,
            name = Members.name(other),
            gangLabel = gang?.label or nil,
        }
    end

    table.sort(online, function(a, b) return a.name < b.name end)

    return {
        mode = 'gangAdmin',
        now = Util.iso(os.time()),
        admin = {
            name = Members.name(source),
            rank = locale(core:HasPermission(source, 'owner') and 'admin.rank_owner' or 'admin.rank_admin'),
        },
        gangs = gangs,
        maxGangs = config.gangs.maxActive,
        nameLength = config.gangs.nameLength,
        archetypes = archetypes,
        zones = Vault.zones(),
        colours = Gangs.colours(),
        onlinePlayers = online,
    }
end

---@param name string
---@return table[]
function Admin.members(name)
    local out <const> = {}

    for _, row in ipairs(db.members('gang', name)) do
        out[#out + 1] = {
            citizenid = row.citizenid,
            name = row.name or locale('member.unknown'),
            grade = row.gang.grade.level,
            online = Members.sourceOf(row.citizenid) ~= nil,
        }
    end

    table.sort(out, function(a, b) return a.grade > b.grade end)

    return out
end

---@param data table
---@return { label: string, archetype: string, homeTurf?: string, blipColor: integer }? spec
---@return string? error
local function details(data)
    local length <const> = config.gangs.nameLength
    local label <const> = Util.text(data.label, length.max)

    if not label or #label < length.min then
        return nil, locale('gang.name_length', length.min, length.max)
    end

    if not Archetypes.exists(data.archetype) then
        return nil, locale('gang.pick_archetype')
    end

    local colour <const> = Util.integer(data.blipColor, 0, 85)

    if not colour then
        return nil, locale('admin.pick_colour')
    end

    local turf <const> = type(data.homeTurf) == 'string' and Vault.zoneExists(data.homeTurf) and data.homeTurf or nil

    return { label = label, archetype = data.archetype, homeTurf = turf, blipColor = colour }
end

---@type table<string, fun(source: integer, data: table): boolean?, string?>
local handlers <const> = {}

handlers['admin:create'] = function(source, data)
    local spec <const>, err <const> = details(data)

    if not spec then return false, err end
    if GangStore.labelTaken(spec.label) then
        return false, locale('gang.name_taken')
    end

    local gang <const> = GangStore.create(spec)

    if not gang then
        return false, locale('admin.create_failed')
    end

    Util.log(gang.name, 'Admin', ('%s created %s'):format(Members.name(source), gang.label))

    return true
end

handlers['admin:save'] = function(source, data)
    local gang <const> = GangStore.get(data.name)
    local spec <const>, err <const> = details(data)

    if not gang then
        return false, locale('admin.gang_gone')
    end

    if not spec then return false, err end

    gang.label = spec.label
    gang.blipColor = spec.blipColor

    if spec.homeTurf or data.homeTurf ~= gang.homeTurf then gang.homeTurf = spec.homeTurf end

    if spec.archetype ~= gang.archetype then
        if not Gangs.switchArchetype(gang, spec.archetype) then
            return false, locale('admin.archetype_failed')
        end
    else
        GangStore.save(gang, nil, nil, { definition = true, map = true })
    end

    Members.refreshGang(gang.name)
    Util.log(gang.name, 'Admin', ('%s edited the gang'):format(Members.name(source)))

    return true
end

handlers['admin:delete'] = function(source, data)
    local gang <const> = GangStore.get(data.name)

    if not gang then
        return false, locale('admin.gang_gone')
    end

    Gangs.disband(gang)
    Util.log(gang.name, 'Admin', ('%s deleted the gang'):format(Members.name(source)))

    return true
end

handlers['admin:assign'] = function(source, data)
    local gang <const> = GangStore.get(data.name)

    if not gang then
        return false, locale('admin.gang_gone')
    end

    if type(data.citizenid) ~= 'string' then
        return false, locale('admin.pick_player')
    end

    local grade <const> = Util.integer(data.grade, 0, Archetypes.get(gang.archetype).bossGrade)

    if not grade then
        return false, locale('common.pick_rank')
    end

    if not Members.assignGang(data.citizenid, gang.name, grade) then
        return false, locale('admin.add_failed')
    end

    local target <const> = Members.sourceOf(data.citizenid)

    if target then Util.notify(target, locale('admin.put_you', gang.label), 'info') end

    Util.log(gang.name, 'Admin', ('%s set %s to grade %d'):format(Members.name(source), Members.nameOf(data.citizenid), grade))

    return true
end

handlers['admin:remove'] = function(source, data)
    local gang <const> = GangStore.get(data.name)

    if not gang or type(data.citizenid) ~= 'string' then
        return false, locale('common.pick_member')
    end

    if db.member(data.citizenid)?.gang?.name ~= gang.name then
        return false, locale('admin.not_in_gang')
    end

    Members.clearGang(data.citizenid)

    local target <const> = Members.sourceOf(data.citizenid)

    if target then Util.notify(target, locale('admin.removed_you', gang.label), 'error') end

    Util.log(gang.name, 'Admin', ('%s removed %s'):format(Members.name(source), Members.nameOf(data.citizenid)))

    return true
end

---@param source integer
---@param name string
---@param data table
---@return table
function Admin.request(source, name, data)
    if not Admin.allowed(source) then
        return { ok = false, error = locale('admin.only') }
    end

    if name == 'admin:members' then
        return type(data.name) == 'string' and Admin.members(data.name) or {}
    end

    local run <const> = handlers[name]

    if not run then
        return { ok = false, error = locale('common.failed') }
    end

    local ok <const>, err <const> = run(source, data)

    if not ok then
        return { ok = false, error = err or locale('common.failed') }
    end

    return { ok = true, session = Admin.session(source) }
end

return Admin
