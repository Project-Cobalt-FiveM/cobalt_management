local Jobs <const> = require 'server.jobs.registry'
local Duty <const> = require 'server.jobs.duty'
local Util <const> = require 'server.util'

local core <const> = exports.cobalt_core
local Cobalt <const> = core:GetCoreObject()

---@alias MembershipField 'job' | 'gang'

---@class Membership
---@field citizenid string
---@field job ManagementJob
---@field gang ManagementGang

---@class MemberRow
---@field citizenid string
---@field name? string
---@field membership ManagementJob | ManagementGang

---@class SecondJob
---@field grade integer
---@field since integer unix seconds

---@class Applicant
---@field phone? string
---@field job? string the name of their main job

---@alias GangLeftHandler fun(gang: ManagementGang)

local Members <const> = {}

Members.UNEMPLOYED = 'unemployed'
Members.NO_GANG = 'none'

---@type table<MembershipField, string>
local ROSTER <const> = {
    job = [[
        SELECT citizenid, fullname AS name, JSON_EXTRACT(metadata, '$.job') AS membership
        FROM players WHERE job_name = ? ORDER BY id LIMIT 500
    ]],
    gang = [[
        SELECT citizenid, fullname AS name, JSON_EXTRACT(metadata, '$.gang') AS membership
        FROM players WHERE gang_name = ? ORDER BY id LIMIT 500
    ]],
}

local GANG_COUNTS <const> = [[
    SELECT gang_name AS name, COUNT(*) AS members FROM players
    WHERE gang_name IN (?) GROUP BY gang_name
]]

local SECOND_JOB_HOLDERS <const> = [[
    SELECT citizenid, fullname AS name,
        CAST(JSON_VALUE(metadata, CONCAT(?, '.grade')) AS SIGNED) AS grade,
        CAST(JSON_VALUE(metadata, CONCAT(?, '.since')) AS UNSIGNED) AS since
    FROM players
    WHERE JSON_CONTAINS_PATH(metadata, 'one', ?)
    ORDER BY since
    LIMIT 500
]]

---@type table<integer, Membership>
local bySource <const> = {}

---@type table<string, integer>
local sourceByCitizen <const> = {}

---@type GangLeftHandler[]
local gangLeftHandlers <const> = {}

---@param name string
---@param level integer
---@return ManagementJob?
function Members.jobShape(name, level)
    local definition <const> = Jobs.shared(name)

    if not definition then return end

    local grade <const> = definition.grades?[tostring(level)]

    if not grade then return end

    local paid <const> = Jobs.grade(name, level)

    return {
        name = name,
        label = definition.label or name,
        type = definition.type or 'none',
        onduty = definition.defaultDuty == true,
        isboss = grade.isboss == true,
        grade = {
            name = grade.name or locale('member.no_grade'),
            level = level,
            payment = paid?.pay or math.floor(tonumber(grade.payment) or 0),
            isboss = grade.isboss == true,
        },
    }
end

---@param name string
---@param level integer
---@return ManagementGang?
function Members.gangShape(name, level)
    local definition <const> = core:GetShared('Gangs', name)

    if not definition then return end

    local grade <const> = definition.grades?[tostring(level)]

    if not grade then return end

    return {
        name = name,
        label = definition.label or name,
        isboss = grade.isboss == true,
        grade = { name = grade.name or locale('member.no_grade'), level = level, isboss = grade.isboss == true },
    }
end

---@return ManagementJob
local function unemployed()
    return Members.jobShape(Members.UNEMPLOYED, 0) or {
        name = Members.UNEMPLOYED,
        label = locale('member.civilian'),
        type = 'none',
        onduty = true,
        isboss = false,
        grade = { name = locale('member.freelancer'), level = 0, payment = 0, isboss = false },
    }
end

---@return ManagementGang
function Members.noGang()
    return Members.gangShape(Members.NO_GANG, 0) or {
        name = Members.NO_GANG,
        label = locale('member.no_gang'),
        isboss = false,
        grade = { name = locale('member.unaffiliated'), level = 0, isboss = false },
    }
end

---@param source integer
---@param entry Membership
local function announce(source, entry)
    TriggerEvent('cobalt_management:membershipChanged', source, entry.job, entry.gang)
    TriggerClientEvent('cobalt_management:membershipChanged', source, entry.job, entry.gang)
end

---@param fresh table
---@param stored? table
---@return boolean
local function differs(fresh, stored)
    if type(stored) ~= 'table' then return true end

    for key, value in pairs(fresh) do
        if type(value) == 'table' then
            if differs(value, stored[key]) then return true end
        elseif stored[key] ~= value then
            return true
        end
    end

    return false
end

---@param stored? table
---@return ManagementJob
local function currentJob(stored)
    local job <const> = stored and Members.jobShape(stored.name, math.tointeger(stored.grade?.level) or 0)

    if not job then
        local fresh <const> = unemployed()

        fresh.since = os.time()

        return fresh
    end

    local defaultDuty <const> = Jobs.shared(job.name)?.defaultDuty

    if not Cobalt.Shared.ForceJobDefaultDutyAtLogin or defaultDuty == nil then
        job.onduty = stored.onduty == true
    end

    job.since = math.tointeger(stored.since) or os.time()

    return job
end

---@param stored? table
---@return ManagementGang
local function currentGang(stored)
    local gang <const> = stored and Members.gangShape(stored.name, math.tointeger(stored.grade?.level) or 0)

    if not gang then return Members.noGang() end

    if gang.name ~= Members.NO_GANG then gang.since = math.tointeger(stored.since) or os.time() end

    return gang
end

---@param source integer
---@return Membership?
function Members.load(source)
    local data <const> = Cobalt.Functions.GetPlayer(source)?.PlayerData
    local citizenid <const> = data?.citizenid

    if not citizenid then return end

    local stored <const> = data.metadata or {}
    local entry <const> = { citizenid = citizenid, job = currentJob(stored.job), gang = currentGang(stored.gang) }

    bySource[source] = entry
    sourceByCitizen[citizenid] = source

    if differs(entry.job, stored.job) then core:SetMetaData(citizenid, 'job', entry.job) end
    if differs(entry.gang, stored.gang) then core:SetMetaData(citizenid, 'gang', entry.gang) end
    if entry.job.onduty then Duty.clockIn(citizenid, entry.job.name) end

    announce(source, entry)

    return entry
end

---@param source integer
function Members.unload(source)
    local entry <const> = bySource[source]

    if not entry then return end

    sourceByCitizen[entry.citizenid] = nil
    bySource[source] = nil
    Duty.clockOut(entry.citizenid)
end

---@param source integer
---@return Membership?
function Members.entry(source)
    return bySource[source]
end

---@param source integer
---@return ManagementJob?
function Members.job(source)
    return bySource[source]?.job
end

---@param source integer
---@return ManagementGang?
function Members.gang(source)
    local gang <const> = bySource[source]?.gang

    if not gang or gang.name == Members.NO_GANG then return end

    return gang
end

---@param source integer
---@return string?
function Members.citizenid(source)
    return bySource[source]?.citizenid
end

---@param citizenid string
---@return integer?
function Members.sourceOf(citizenid)
    return sourceByCitizen[citizenid]
end

---@param source integer
---@return string
function Members.name(source)
    return core:GetName(source) or locale('member.unknown')
end

---@param citizenid string
---@return string
function Members.nameOf(citizenid)
    return core:GetName(citizenid) or citizenid
end

---@return table<integer, Membership>
function Members.online()
    return bySource
end

---@param name string a job or gang
---@return integer[]
function Members.sourcesIn(name)
    local out <const> = {}

    for source, entry in pairs(bySource) do
        if entry.job.name == name or entry.gang.name == name then out[#out + 1] = source end
    end

    return out
end

---@param citizenid string
---@param field MembershipField
---@return table? membership from memory while the character is online, else from `players.metadata`
function Members.stored(citizenid, field)
    local source <const> = sourceByCitizen[citizenid]

    if source then return bySource[source][field] end

    return core:GetMetaData({ citizenid }, field)[citizenid]
end

---@param field MembershipField
---@param name string
---@return MemberRow[] rows everyone holding it, online or not, with the live membership of those online
function Members.roster(field, name)
    local rows <const> = MySQL.query.await(ROSTER[field], { name }) or {}

    for _, row in ipairs(rows) do
        local source <const> = sourceByCitizen[row.citizenid]

        row.membership = source and bySource[source][field] or Util.decode(row.membership)
    end

    return rows
end

---@param names string[]
---@return table<string, integer> members by gang name
function Members.gangCounts(names)
    local counts <const> = {}

    if #names == 0 then return counts end

    for _, row in ipairs(MySQL.query.await(GANG_COUNTS, { names }) or {}) do counts[row.name] = row.members end

    return counts
end

---@param citizenids string[]
---@return table<string, Applicant> by citizenid
function Members.applicants(citizenids)
    local out <const> = {}

    if #citizenids == 0 then return out end

    local rows <const> = MySQL.query.await(
        'SELECT citizenid, phone_number AS phone, job_name AS job FROM players WHERE citizenid IN (?)',
        { citizenids }
    ) or {}

    for _, row in ipairs(rows) do out[row.citizenid] = { phone = row.phone, job = row.job } end

    return out
end

---@param citizenid string
---@return table<string, SecondJob> by job name
function Members.secondJobs(citizenid)
    local jobs <const> = core:GetMetaData({ citizenid }, 'secondjobs')[citizenid]

    return type(jobs) == 'table' and jobs or {}
end

---@param citizenid string
---@param jobs table<string, SecondJob>
---@return boolean written
function Members.saveSecondJobs(citizenid, jobs)
    return core:SetMetaData(citizenid, 'secondjobs', jobs)
end

---@param jobName string
---@return { citizenid: string, name?: string, grade: integer, since?: integer }[]
function Members.secondJobHolders(jobName)
    local path <const> = Util.jsonPath('secondjobs', jobName)

    return MySQL.query.await(SECOND_JOB_HOLDERS, { path, path, path }) or {}
end

---@param citizenid string
---@param mainJob string no longer held as a second job
---@param demoted? { name: string, grade: integer } the main job they leave, kept as a second job
local function keepSecondJobs(citizenid, mainJob, demoted)
    local jobs <const> = Members.secondJobs(citizenid)

    if not jobs[mainJob] and not demoted then return end

    jobs[mainJob] = nil

    if demoted then jobs[demoted.name] = { grade = demoted.grade, since = os.time() } end

    Members.saveSecondJobs(citizenid, jobs)
end

---@param source integer
---@param job ManagementJob
---@param demoted? { name: string, grade: integer }
local function writeJob(source, job, demoted)
    local entry <const> = bySource[source]
    local changed <const> = entry.job.name ~= job.name

    entry.job = job

    if changed then Duty.clockOut(entry.citizenid) end

    core:SetMetaData(entry.citizenid, 'job', job)

    if changed or demoted then keepSecondJobs(entry.citizenid, job.name, demoted) end
    if job.onduty then Duty.clockIn(entry.citizenid, job.name) end

    TriggerClientEvent('cobalt_core:Client:OnJobUpdate', source, job)
    announce(source, entry)
end

---@param gang ManagementGang
local function gangLeft(gang)
    if gang.name == Members.NO_GANG then return end

    for _, handler in ipairs(gangLeftHandlers) do handler(gang) end
end

---@param source integer
---@param gang ManagementGang
---@return ManagementGang previous
local function writeGang(source, gang)
    local entry <const> = bySource[source]
    local previous <const> = entry.gang

    entry.gang = gang
    core:SetMetaData(entry.citizenid, 'gang', gang)

    TriggerEvent('cobalt_core:Server:OnGangUpdate', source, gang)
    TriggerClientEvent('cobalt_core:Client:OnGangUpdate', source, gang)
    announce(source, entry)

    return previous
end

---@param handler GangLeftHandler
function Members.onGangLeft(handler)
    gangLeftHandlers[#gangLeftHandlers + 1] = handler
end

---@param source integer
---@param name string
---@param grade integer
---@param demoted? { name: string, grade: integer } the current main job to keep as a second job
---@return boolean
function Members.setJob(source, name, grade, demoted)
    local entry <const> = bySource[source]
    local job <const> = entry and Members.jobShape(name, grade)

    if not job then return false end

    if entry.job.name == name then
        job.onduty = entry.job.onduty
        job.since = entry.job.since
    else
        job.since = os.time()
    end

    writeJob(source, job, demoted)

    return true
end

---@param source integer
---@param name string
---@param grade integer
---@return boolean
function Members.setGang(source, name, grade)
    local entry <const> = bySource[source]
    local gang <const> = entry and Members.gangShape(name, grade)

    if not gang then return false end

    if name == entry.gang.name then
        gang.since = entry.gang.since
    elseif name ~= Members.NO_GANG then
        gang.since = os.time()
    end

    local previous <const> = writeGang(source, gang)

    if previous.name ~= name then gangLeft(previous) end

    return true
end

---@param citizenid string
---@param name string
---@param grade integer
---@return boolean
function Members.assignJob(citizenid, name, grade)
    local source <const> = sourceByCitizen[citizenid]

    if source then return Members.setJob(source, name, grade) end

    local job <const> = Members.jobShape(name, grade)

    if not job then return false end

    local previous <const> = Members.stored(citizenid, 'job')
    local joined <const> = previous?.name ~= name

    job.since = not joined and math.tointeger(previous.since) or os.time()

    if not core:SetMetaData(citizenid, 'job', job) then return false end
    if joined then keepSecondJobs(citizenid, name) end

    return true
end

---@param citizenid string
---@param name string
---@param grade integer
---@return boolean
function Members.assignGang(citizenid, name, grade)
    local source <const> = sourceByCitizen[citizenid]

    if source then return Members.setGang(source, name, grade) end

    local gang <const> = Members.gangShape(name, grade)

    if not gang then return false end

    local previous <const> = Members.stored(citizenid, 'gang')
    local joined <const> = previous?.name ~= name

    if name ~= Members.NO_GANG then gang.since = not joined and math.tointeger(previous.since) or os.time() end

    if not core:SetMetaData(citizenid, 'gang', gang) then return false end
    if previous and joined then gangLeft(previous) end

    return true
end

---@param citizenid string
---@return boolean
function Members.clearJob(citizenid)
    return Members.assignJob(citizenid, Members.UNEMPLOYED, 0)
end

---@param citizenid string
---@return boolean
function Members.clearGang(citizenid)
    return Members.assignGang(citizenid, Members.NO_GANG, 0)
end

---@param gangName string a gang being dissolved; the gang-left handlers don't run
function Members.clearWholeGang(gangName)
    for _, row in ipairs(Members.roster('gang', gangName)) do
        local source <const> = sourceByCitizen[row.citizenid]

        if source then
            writeGang(source, Members.noGang())
        else
            core:SetMetaData(row.citizenid, 'gang', Members.noGang())
        end
    end
end

---@param source integer
---@param onDuty boolean
---@return boolean
function Members.setDuty(source, onDuty)
    local entry <const> = bySource[source]

    if not entry then return false end
    if entry.job.onduty == onDuty then return true end

    entry.job.onduty = onDuty
    Cobalt.Functions.GetPlayer(source)?.Functions.SetMetaData('job', entry.job)

    if onDuty then
        Duty.clockIn(entry.citizenid, entry.job.name)
    else
        Duty.clockOut(entry.citizenid)
    end

    TriggerClientEvent('cobalt_core:Client:OnJobUpdate', source, entry.job)
    TriggerEvent('cobalt_management:dutyChanged', source, onDuty)
    TriggerClientEvent('cobalt_management:dutyChanged', source, onDuty)
    announce(source, entry)

    return true
end

---@param jobName string
---@param grade integer
function Members.refreshPay(jobName, grade)
    for source, entry in pairs(bySource) do
        if entry.job.name == jobName and entry.job.grade.level == grade then
            local job <const> = Members.jobShape(jobName, grade)

            if job and job.grade.payment ~= entry.job.grade.payment then
                job.onduty = entry.job.onduty
                job.since = entry.job.since
                writeJob(source, job)
            end
        end
    end
end

---@param gangName string
function Members.refreshGang(gangName)
    for source, entry in pairs(bySource) do
        if entry.gang.name == gangName then
            local gang <const> = Members.gangShape(gangName, entry.gang.grade.level)

            if gang then
                gang.since = entry.gang.since
                writeGang(source, gang)
            end
        end
    end
end

AddEventHandler('cobalt_core:Server:PlayerLoaded', function(player)
    local source <const> = player?.PlayerData?.source

    if source then Members.load(source) end
end)

AddEventHandler('cobalt_core:Server:OnPlayerUnload', Members.unload)

AddEventHandler('playerDropped', function()
    Members.unload(source)
end)

return Members
