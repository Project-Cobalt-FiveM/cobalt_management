local config <const> = require 'config.server'
local db <const> = require 'server.db'
local Orgs <const> = require 'server.orgs'
local Members <const> = require 'server.members'
local Staff <const> = require 'server.staff'
local Archetypes <const> = require 'server.gangs.archetypes'
local GangStore <const> = require 'server.gangs.store'
local Gangs <const> = require 'server.gangs.service'

---@param source integer
---@return table?
local function gangWithPermissions(source)
    local gang <const> = Members.gang(source)

    if not gang then return end

    local record <const> = GangStore.get(gang.name)
    local out <const> = {}

    for key, value in pairs(gang) do out[key] = value end

    if record then
        out.archetype = record.archetype
        out.permissions = Archetypes.permissions(record.archetype, gang.grade.level, record.permissions)
        out.homeTurf = record.homeTurf
        out.founderCid = record.founderCid
    end

    return out
end

exports('GetJob', Members.job)
exports('GetGang', gangWithPermissions)

exports('SetJob', function(source, name, grade)
    if type(name) ~= 'string' then return false end

    return Members.setJob(source, name:lower(), math.tointeger(tonumber(grade)) or 0)
end)

exports('SetGang', function(source, name, grade)
    if type(name) ~= 'string' then return false end

    return Members.setGang(source, name:lower(), math.tointeger(tonumber(grade)) or 0)
end)

exports('GetAffiliations', function(citizenids)
    local out <const> = {}

    if type(citizenids) ~= 'table' then return out end

    for _, row in ipairs(db.membershipsOf(citizenids)) do
        local source <const> = Members.sourceOf(row.citizenid)
        local live <const> = source and Members.entry(source)

        out[row.citizenid] = { job = live?.job or row.job, gang = live?.gang or row.gang }
    end

    return out
end)

exports('GetDuty', function(source)
    return Members.job(source)?.onduty == true
end)

exports('GetDutyCount', function(job)
    local onDuty, offDuty = 0, 0

    for _, entry in pairs(Members.online()) do
        local current <const> = entry.job

        if current.name == job or current.type == job then
            if current.onduty then
                onDuty += 1
            else
                offDuty += 1
            end
        end
    end

    return onDuty, offDuty
end)

exports('SetDuty', function(source, onDuty)
    return Members.setDuty(source, onDuty == true)
end)

exports('HasPermission', Staff.hasPermission)

exports('GetEmployees', function(orgName, options)
    return Staff.roster(orgName, { summary = type(options) == 'table' and options.summary == true })
end)

exports('GetOnlineMembers', Members.sourcesIn)

exports('SetGrade', function(citizenid, orgName, grade)
    return Staff.setGrade(orgName, citizenid, math.tointeger(tonumber(grade)) or 0)
end)

exports('GetDutyMinutes', function(citizenid, jobName, days)
    local period <const> = math.tointeger(tonumber(days)) or config.dutyPeriodDays

    if type(citizenid) == 'table' then return db.dutyMinutes(citizenid, jobName, period) end

    return db.dutyMinutes({ citizenid }, jobName, period)[citizenid] or 0
end)

exports('HasGangPermission', Gangs.hasPermission)

exports('GetFleet', function(orgName)
    local grades <const> = {}

    for _, vehicle in ipairs(Orgs.vehicles(orgName)?.catalogue or {}) do grades[vehicle.model] = vehicle.grade end

    local out <const> = {}

    for _, vehicle in ipairs(db.fleet(orgName)) do
        out[#out + 1] = {
            plate = vehicle.plate,
            model = vehicle.model,
            label = vehicle.label,
            minGrade = grades[vehicle.model] or 0,
        }
    end

    return out
end)

exports('OpenMenu', function(source, mode, data)
    TriggerClientEvent('cobalt_management:open', source, mode or 'org', data)
end)
