local config <const> = require 'config.server'
local Members <const> = require 'server.members'
local Util <const> = require 'server.util'
local Ranks <const> = require 'server.gangs.ranks'
local GangStore <const> = require 'server.gangs.store'
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
    local gangs <const>, online <const>, names <const> = {}, {}, {}

    for name in pairs(GangStore.all()) do names[#names + 1] = name end

    local counts <const> = Members.gangCounts(names)

    for name, gang in pairs(GangStore.all()) do
        local ranks <const> = {}

        for _, rank in ipairs(Ranks.ladder(name).ranks) do
            ranks[#ranks + 1] = { grade = rank.grade, name = rank.name, isBoss = rank.isBoss }
        end

        gangs[#gangs + 1] = {
            name = name,
            label = gang.label,
            ranks = ranks,
            members = counts[name] or 0,
            founderName = gang.founderCid and Members.nameOf(gang.founderCid) or nil,
            foundedAt = Util.iso(gang.foundedAt),
        }
    end

    table.sort(gangs, function(a, b) return a.label < b.label end)

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
        onlinePlayers = online,
    }
end

---@param data table
---@return string? label
---@return string? error
local function validLabel(data)
    local length <const> = config.gangs.nameLength
    local label <const> = Util.text(data.label, length.max)

    if not label or #label < length.min then
        return nil, locale('gang.name_length', length.min, length.max)
    end

    return label
end

---@type table<string, fun(source: integer, data: table): boolean?, string?>
local handlers <const> = {}

handlers['admin:create'] = function(source, data)
    local label <const>, err <const> = validLabel(data)

    if not label then return false, err end
    if GangStore.labelTaken(label) then
        return false, locale('gang.name_taken')
    end

    local gang <const> = GangStore.create({ label = label })

    if not gang then
        return false, locale('admin.create_failed')
    end

    Util.log(gang.name, 'Admin', ('%s created %s'):format(Members.name(source), gang.label))

    return true
end

handlers['admin:save'] = function(source, data)
    local gang <const> = GangStore.get(data.name)
    local label <const>, err <const> = validLabel(data)

    if not gang then
        return false, locale('admin.gang_gone')
    end

    if not label then return false, err end

    if label:lower() ~= gang.label:lower() and GangStore.labelTaken(label) then
        return false, locale('gang.name_taken')
    end

    gang.label = label
    GangStore.save(gang, true)

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

    local grade <const> = Util.integer(data.grade, 0, Ranks.ladder(gang.name).bossGrade)

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

    if Members.stored(data.citizenid, 'gang')?.name ~= gang.name then
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
        return type(data.name) == 'string' and Gangs.roster(data.name) or {}
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
