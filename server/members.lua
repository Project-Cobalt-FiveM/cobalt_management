local db <const> = require 'server.db'
local Orgs <const> = require 'server.orgs'
local Util <const> = require 'server.util'

local Cobalt <const> = exports.cobalt_core:GetCoreObject()

---@class Membership
---@field citizenid string
---@field job ManagementJob
---@field gang ManagementGang
---@field jobSince? string
---@field gangSince? string

---@alias GangLeftHandler fun(source: integer?, citizenid: string, gang: ManagementGang)

local Members <const> = {}

Members.UNEMPLOYED = 'unemployed'
Members.NO_GANG = 'none'

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
    local definition <const> = Orgs.sharedJob(name)

    if not definition then return end

    local grade <const> = definition.grades?[tostring(level)]

    if not grade then return end

    local paid <const> = Orgs.grade(name, level)

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
---@param definition? table the gang definition to shape from, defaulting to core's
---@return ManagementGang?
function Members.gangShape(name, level, definition)
    definition = definition or Orgs.sharedGang(name)

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

    if not job then return unemployed() end

    local definition <const> = Orgs.sharedJob(job.name)
    local forceDuty <const> = Cobalt.Shared.ForceJobDefaultDutyAtLogin

    if forceDuty and definition and definition.defaultDuty ~= nil then
        job.onduty = definition.defaultDuty
    else
        job.onduty = stored.onduty == true
    end

    return job
end

---@param stored? table
---@return ManagementGang
local function currentGang(stored)
    return stored and Members.gangShape(stored.name, math.tointeger(stored.grade?.level) or 0) or Members.noGang()
end

---@param citizenid string
---@param job ManagementJob
local function clockInIfOnDuty(citizenid, job)
    if job.onduty and Orgs.get(job.name) and Orgs.feature(job.name, 'duty') then db.clockIn(citizenid, job.name) end
end

---@param source integer
---@return Membership?
function Members.load(source)
    local player <const> = Cobalt.Functions.GetPlayer(source)
    local citizenid <const> = player?.PlayerData?.citizenid

    if not player or not citizenid then return end

    local row <const> = db.member(citizenid)
    local job <const> = currentJob(row?.job)
    local gang <const> = currentGang(row?.gang)

    if differs(job, row?.job) or differs(gang, row?.gang) then db.saveMember(citizenid, job, gang) end

    clockInIfOnDuty(citizenid, job)

    local entry <const> = { citizenid = citizenid, job = job, gang = gang, jobSince = row?.jobSince, gangSince = row?.gangSince }

    bySource[source] = entry
    sourceByCitizen[citizenid] = source

    player.Functions.SetPlayerData({ job = job, gang = gang })
    announce(source, entry)

    return entry
end

---@param source integer
function Members.unload(source)
    local entry <const> = bySource[source]

    if not entry then return end

    db.clockOut(entry.citizenid)
    sourceByCitizen[entry.citizenid] = nil
    bySource[source] = nil
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
    return exports.cobalt_core:GetName(source) or locale('member.unknown')
end

---@param citizenid string
---@return string
function Members.nameOf(citizenid)
    return exports.cobalt_core:GetName(citizenid) or citizenid
end

---@return table<integer, Membership>
function Members.online()
    return bySource
end

---@param orgName string
---@return integer[]
function Members.sourcesIn(orgName)
    local out <const> = {}

    for source, entry in pairs(bySource) do
        if entry.job.name == orgName or entry.gang.name == orgName then out[#out + 1] = source end
    end

    return out
end

---@param source integer
---@param job ManagementJob
---@param joined boolean
---@param demoted? { name: string, grade: integer }
local function writeJob(source, job, joined, demoted)
    local entry <const> = bySource[source]
    local player <const> = Cobalt.Functions.GetPlayer(source)

    if entry.job.name ~= job.name then db.clockOut(entry.citizenid, entry.job.name) end

    entry.job = job

    if joined then entry.jobSince = Util.iso(os.time()) end

    db.saveMembership(entry.citizenid, 'job', job, joined, demoted)
    clockInIfOnDuty(entry.citizenid, job)

    player?.Functions.SetPlayerData('job', job)
    TriggerClientEvent('cobalt_core:Client:OnJobUpdate', source, job)
    announce(source, entry)
end

---@param citizenid string
---@param gang ManagementGang
---@param source? integer
local function gangLeft(citizenid, gang, source)
    for _, handler in ipairs(gangLeftHandlers) do handler(source, citizenid, gang) end
end

---@param source integer
---@param gang ManagementGang
---@param joined boolean
---@param saved? boolean true when the caller already wrote the gang to the database
local function writeGang(source, gang, joined, saved)
    local entry <const> = bySource[source]
    local previous <const> = entry.gang
    local player <const> = Cobalt.Functions.GetPlayer(source)

    entry.gang = gang

    if joined then entry.gangSince = Util.iso(os.time()) end
    if not saved then db.saveMembership(entry.citizenid, 'gang', gang, joined) end

    player?.Functions.SetPlayerData('gang', gang)
    TriggerEvent('cobalt_core:Server:OnGangUpdate', source, gang)
    TriggerClientEvent('cobalt_core:Client:OnGangUpdate', source, gang)
    announce(source, entry)

    if previous.name ~= Members.NO_GANG and previous.name ~= gang.name then
        gangLeft(entry.citizenid, previous, source)
    end
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
    if not bySource[source] then return false end

    local job <const> = Members.jobShape(name, grade)

    if not job then return false end

    local current <const> = bySource[source].job

    if current.name == name then job.onduty = current.onduty end

    writeJob(source, job, current.name ~= name, demoted)

    return true
end

---@param source integer
---@param name string
---@param grade integer
---@return boolean
function Members.setGang(source, name, grade)
    if not bySource[source] then return false end

    local gang <const> = Members.gangShape(name, grade)

    if not gang then return false end

    writeGang(source, gang, bySource[source].gang.name ~= name)

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

    if not job or not exports.cobalt_core:GetName(citizenid) then return false end

    local row <const> = db.member(citizenid)
    local joined <const> = row?.job?.name ~= name

    if not joined then job.onduty = row.job.onduty end

    db.saveMembership(citizenid, 'job', job, joined)

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

    if not gang or not exports.cobalt_core:GetName(citizenid) then return false end

    local previous <const> = db.member(citizenid)?.gang

    db.saveMembership(citizenid, 'gang', gang, previous?.name ~= name)

    if previous and previous.name ~= Members.NO_GANG and previous.name ~= name then gangLeft(citizenid, previous) end

    return true
end

---@param citizenid string
---@param gang ManagementGang
function Members.syncSavedGang(citizenid, gang)
    local source <const> = sourceByCitizen[citizenid]

    if source then writeGang(source, gang, false, true) end
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

---@param gangName string
function Members.clearWholeGang(gangName)
    db.resetGang(gangName, Members.noGang())

    for _, source in ipairs(Members.sourcesIn(gangName)) do
        if bySource[source].gang.name == gangName then writeGang(source, Members.noGang(), false, true) end
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
    db.saveMembership(entry.citizenid, 'job', entry.job, false)

    if not onDuty then
        db.clockOut(entry.citizenid, entry.job.name)
    elseif Orgs.get(entry.job.name) and Orgs.feature(entry.job.name, 'duty') then
        db.clockIn(entry.citizenid, entry.job.name)
    end

    Cobalt.Functions.GetPlayer(source)?.Functions.SetPlayerData('job', entry.job)
    TriggerClientEvent('cobalt_core:Client:OnJobUpdate', source, entry.job)
    TriggerEvent('cobalt_management:dutyChanged', source, onDuty)
    TriggerClientEvent('cobalt_management:dutyChanged', source, onDuty)
    announce(source, entry)

    return true
end

---@param orgName string
---@param grade integer
function Members.refreshPay(orgName, grade)
    for source, entry in pairs(bySource) do
        if entry.job.name == orgName and entry.job.grade.level == grade then
            local job <const> = Members.jobShape(orgName, grade)

            if job and job.grade.payment ~= entry.job.grade.payment then
                job.onduty = entry.job.onduty
                writeJob(source, job, false)
            end
        end
    end
end

---@param gangName string
function Members.refreshGang(gangName)
    for source, entry in pairs(bySource) do
        if entry.gang.name == gangName then
            local gang <const> = Members.gangShape(gangName, entry.gang.grade.level)

            if gang then writeGang(source, gang, false) end
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
