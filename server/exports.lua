local config <const> = require 'config.server'
local db <const> = require 'server.jobs.db'
local Jobs <const> = require 'server.jobs.registry'
local Duty <const> = require 'server.jobs.duty'
local Staff <const> = require 'server.jobs.staff'
local Members <const> = require 'server.members'
local Ranks <const> = require 'server.gangs.ranks'
local GangStore <const> = require 'server.gangs.store'
local Gangs <const> = require 'server.gangs.service'

local core <const> = exports.cobalt_core

---@param source integer
---@return table?
local function gangWithPermissions(source)
    local gang <const> = Members.gang(source)

    if not gang then return end

    local record <const> = GangStore.get(gang.name)
    local out <const> = {}

    for key, value in pairs(gang) do out[key] = value end

    if record then
        out.permissions = Ranks.permissions(record, gang.grade.level)
        out.founderCid = record.founderCid
    end

    return out
end

---@param name unknown
---@return boolean
local function isName(name)
    return type(name) == 'string' and #name > 0 and #name <= 50
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

    if type(citizenids) ~= 'table' or #citizenids == 0 then return out end

    local jobs <const> = core:GetMetaData(citizenids, 'job')
    local gangs <const> = core:GetMetaData(citizenids, 'gang')

    for _, citizenid in ipairs(citizenids) do
        local job <const>, gang <const> = jobs[citizenid], gangs[citizenid]

        if job or gang then out[citizenid] = { job = job, gang = gang } end
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

exports('HasPermission', function(source, name, permission)
    local entry <const> = Members.entry(source)

    if not entry then return false end

    if entry.job.name == name then
        return Jobs.rankPermissions(name, entry.job.grade.level)[permission] == true
    end

    return entry.gang.name == name and Ranks.rank(name, entry.gang.grade.level)?.isBoss == true
end)

exports('GetEmployees', function(name, options)
    if Jobs.get(name) then
        return Staff.roster(name, { summary = type(options) == 'table' and options.summary == true })
    end

    if not GangStore.get(name) then return {} end

    local out <const> = {}

    for index, member in ipairs(Gangs.roster(name)) do
        out[index] = {
            citizenid = member.citizenid,
            name = member.name,
            grade = member.grade,
            rank = member.rank,
            pay = 0,
            isBoss = member.isBoss,
            online = member.online,
            onDuty = member.online,
            onLeave = false,
            joinedAt = member.joinedAt,
            weekMinutes = 0,
            lastWeekMinutes = 0,
            monthBonuses = 0,
            source = member.source,
        }
    end

    return out
end)

exports('GetOnlineMembers', Members.sourcesIn)

exports('SetGrade', function(citizenid, jobName, grade)
    return Staff.setGrade(jobName, citizenid, math.tointeger(tonumber(grade)) or 0)
end)

exports('GetDutyMinutes', function(citizenid, jobName, days)
    local period <const> = math.tointeger(tonumber(days)) or config.dutyPeriodDays

    if type(citizenid) == 'table' then return Duty.minutes(citizenid, jobName, period) end

    return Duty.minutes({ citizenid }, jobName, period)[citizenid] or 0
end)

exports('HasGangPermission', Gangs.hasPermission)

exports('GetFleet', function(jobName)
    local grades <const> = {}

    for _, vehicle in ipairs(Jobs.vehicles(jobName)?.catalogue or {}) do grades[vehicle.model] = vehicle.grade end

    local out <const> = {}

    for _, vehicle in ipairs(db.fleet(jobName)) do
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
    TriggerClientEvent('cobalt_management:open', source, mode or 'job', data)
end)

exports('GetJobStatus', function(names)
    local wanted <const> = {}

    for _, name in ipairs(type(names) == 'table' and names or {}) do
        if isName(name) then wanted[#wanted + 1] = name end
    end

    return db.status(wanted)
end)

exports('SetJobOpen', function(name, open)
    if not isName(name) or type(open) ~= 'boolean' then return false end

    db.setOpen(name, open)

    return true
end)

exports('AddJobPayout', function(name, amount)
    local paid <const> = math.tointeger(tonumber(amount))

    if not isName(name) or not paid or paid <= 0 then return false end

    db.addPayout(name, paid)

    return true
end)
