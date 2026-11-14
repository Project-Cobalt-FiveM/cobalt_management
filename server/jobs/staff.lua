local config <const> = require 'config.server'
local db <const> = require 'server.jobs.db'
local Jobs <const> = require 'server.jobs.registry'
local Duty <const> = require 'server.jobs.duty'
local Members <const> = require 'server.members'
local SecondJobs <const> = require 'server.jobs.secondjobs'
local Society <const> = require 'server.jobs.society'
local Util <const> = require 'server.util'

---@class Actor
---@field source integer
---@field citizenid string
---@field name string
---@field job JobDefinition
---@field grade integer
---@field isBoss boolean
---@field permissions table<RankPermission, true>

---@class Employee
---@field citizenid string
---@field name string
---@field grade integer
---@field rank string
---@field pay integer
---@field isBoss boolean
---@field online boolean
---@field onDuty boolean
---@field onLeave boolean
---@field joinedAt? string
---@field shiftStartedAt? string
---@field weekMinutes integer
---@field lastWeekMinutes integer
---@field monthBonuses integer
---@field source? integer
---@field secondJob? boolean

---@class StaffMember
---@field citizenid string
---@field name string
---@field grade integer
---@field source? integer
---@field secondJob? boolean

---@class RosterOptions
---@field summary? boolean skips the duty, leave and bonus totals
---@field data? JobData the job's row when the caller already read it

---@class JobOffer
---@field citizenid string
---@field job string
---@field grade integer
---@field asSecondJob boolean
---@field by integer
---@field byCitizen string
---@field expires integer

local Staff <const> = {}

local OFFER_SECONDS <const> = 60

---@type table<integer, JobOffer>
local offers <const> = {}

---@param source integer
---@return Actor?
function Staff.actor(source)
    local entry <const> = Members.entry(source)
    local job <const> = entry and Jobs.get(entry.job.name)

    if not job then return end

    local grade <const> = entry.job.grade.level

    return {
        source = source,
        citizenid = entry.citizenid,
        name = Members.name(source),
        job = job,
        grade = grade,
        isBoss = Jobs.grade(job.name, grade)?.isBoss == true,
        permissions = Jobs.rankPermissions(job.name, grade),
    }
end

---@param source integer
---@param jobName string
---@return boolean
function Staff.isBoss(source, jobName)
    local job <const> = Members.job(source)

    return job?.name == jobName and Jobs.grade(jobName, job.grade.level)?.isBoss == true
end

---@param jobName string
---@param options? RosterOptions
---@return Employee[]
function Staff.roster(jobName, options)
    if not Jobs.get(jobName) then return {} end

    local data <const> = options?.summary ~= true and (options?.data or db.data(jobName)) or nil
    local duty <const> = data and Duty.summary(jobName, data.duty) or {}
    local leave <const> = data and db.onLeave(jobName, data.requests) or {}
    local bonuses <const> = data and db.bonusSummary(jobName, data.bonuses) or {}
    local out <const> = {}

    for _, row in ipairs(Members.roster('job', jobName)) do
        local source <const> = Members.sourceOf(row.citizenid)
        local current <const> = row.membership
        local level <const> = math.tointeger(current.grade?.level) or 0
        local grade <const> = Jobs.grade(jobName, level)
        local summary <const> = duty[row.citizenid]

        out[#out + 1] = {
            citizenid = row.citizenid,
            name = row.name or locale('member.unknown'),
            grade = level,
            rank = grade?.name or current.grade?.name or '',
            pay = grade?.pay or 0,
            isBoss = grade?.isBoss == true,
            online = source ~= nil,
            onDuty = source ~= nil and current.onduty == true,
            onLeave = leave[row.citizenid] == true,
            joinedAt = Util.iso(current.since),
            shiftStartedAt = source and Util.iso(summary?.shiftStartedAt) or nil,
            weekMinutes = summary?.week or 0,
            lastWeekMinutes = summary?.lastWeek or 0,
            monthBonuses = bonuses[row.citizenid] or 0,
            source = source,
        }
    end

    table.sort(out, function(a, b)
        if a.grade ~= b.grade then return a.grade > b.grade end

        return a.name < b.name
    end)

    return out
end

---@param jobName string
---@param monthBonuses table<string, integer> by citizenid
---@return Employee[]
function Staff.secondJobHolders(jobName, monthBonuses)
    local out <const> = {}

    for _, row in ipairs(Members.secondJobHolders(jobName)) do
        local source <const> = Members.sourceOf(row.citizenid)
        local grade <const> = Jobs.grade(jobName, row.grade)

        out[#out + 1] = {
            citizenid = row.citizenid,
            name = row.name or locale('member.unknown'),
            grade = row.grade,
            rank = grade?.name or locale('job.grade_fallback', row.grade),
            pay = grade?.pay or 0,
            isBoss = grade?.isBoss == true,
            online = source ~= nil,
            onDuty = false,
            onLeave = false,
            joinedAt = Util.iso(row.since),
            weekMinutes = 0,
            lastWeekMinutes = 0,
            monthBonuses = monthBonuses[row.citizenid] or 0,
            source = source,
            secondJob = true,
        }
    end

    return out
end

---@param jobName string
---@param citizenid string
---@return StaffMember?
function Staff.employee(jobName, citizenid)
    if not Jobs.get(jobName) then return end

    local current <const> = Members.stored(citizenid, 'job')
    local source <const> = Members.sourceOf(citizenid)

    if current?.name == jobName then
        return {
            citizenid = citizenid,
            name = Members.nameOf(citizenid),
            grade = math.tointeger(current.grade?.level) or 0,
            source = source,
        }
    end

    local second <const> = SecondJobs.get(citizenid, jobName)

    if not second then return end

    return {
        citizenid = citizenid,
        name = Members.nameOf(citizenid),
        grade = Util.whole(second.grade),
        source = source,
        secondJob = true,
    }
end

---@param actor Actor
---@param target StaffMember
---@return string? error
local function outranks(actor, target)
    if target.citizenid == actor.citizenid then
        return locale('staff.own_job')
    end

    if target.grade >= actor.grade and actor.grade < actor.job.topGrade then
        return locale('staff.outranked')
    end
end

---@param jobName string
---@param citizenid string
---@param grade integer
---@return boolean ok
---@return string? error
function Staff.hire(jobName, citizenid, grade)
    if not Jobs.get(jobName) then
        return false, locale('staff.no_job')
    end

    if not Jobs.grade(jobName, grade) then
        return false, locale('staff.no_rank')
    end

    if not exports.cobalt_core:GetName(citizenid) then
        return false, locale('staff.no_citizen')
    end

    if not Members.assignJob(citizenid, jobName, grade) then
        return false, locale('staff.job_change_failed')
    end

    return true
end

---@param jobName string
---@param citizenid string
---@return boolean ok
---@return string? error
function Staff.fire(jobName, citizenid)
    if Members.stored(citizenid, 'job')?.name ~= jobName then
        if SecondJobs.remove(citizenid, jobName) then return true end

        return false, locale('staff.not_employee')
    end

    if not Members.clearJob(citizenid) then
        return false, locale('staff.job_change_failed')
    end

    return true
end

---@param jobName string
---@param citizenid string
---@param grade integer
---@return boolean ok
---@return string? error
function Staff.setGrade(jobName, citizenid, grade)
    if not Jobs.grade(jobName, grade) then
        return false, locale('staff.no_rank')
    end

    if Members.stored(citizenid, 'job')?.name ~= jobName then
        if not SecondJobs.get(citizenid, jobName) then
            return false, locale('staff.not_employee')
        end

        if not SecondJobs.add(citizenid, jobName, grade) then
            return false, locale('staff.rank_change_failed')
        end

        return true
    end

    if not Members.assignJob(citizenid, jobName, grade) then
        return false, locale('staff.rank_change_failed')
    end

    return true
end

---@param actor Actor
---@param citizenid string
---@param grade integer
---@param asSecondJob boolean
---@return string? refusal
local function hireRefusal(actor, citizenid, grade, asSecondJob)
    if citizenid == actor.citizenid then
        return locale('common.already_staff')
    end

    if grade >= actor.grade and actor.grade < actor.job.topGrade then
        return locale('staff.hire_below')
    end

    if not Jobs.grade(actor.job.name, grade) then
        return locale('staff.no_rank')
    end

    if Members.stored(citizenid, 'job')?.name == actor.job.name then
        return locale('staff.already_employee')
    end

    if asSecondJob and not Jobs.feature(actor.job.name, 'secondJobs') then
        return locale('staff.second_jobs_off')
    end
end

---@param actor Actor
---@param citizenid string
---@param grade integer
---@param asSecondJob boolean
---@return boolean ok
---@return string? error
function Staff.hireBy(actor, citizenid, grade, asSecondJob)
    local refusal <const> = hireRefusal(actor, citizenid, grade, asSecondJob)

    if refusal then return false, refusal end

    local jobName <const> = actor.job.name

    if asSecondJob then
        if not exports.cobalt_core:GetName(citizenid) then
            return false, locale('staff.no_citizen')
        end

        if not SecondJobs.add(citizenid, jobName, grade) then
            return false, locale('staff.second_jobs_full')
        end
    else
        local ok <const>, err <const> = Staff.hire(jobName, citizenid, grade)

        if not ok then return false, err end
    end

    local source <const> = Members.sourceOf(citizenid)
    local name <const> = Members.nameOf(citizenid)
    local rank <const> = Jobs.grade(jobName, grade) --[[@as JobGrade]]

    if source then
        Util.notify(source, locale('staff.hired_you', actor.name, actor.job.label, rank.name), 'success')
    end

    Util.log(jobName, 'Hire', ('%s hired %s as %s%s'):format(actor.name, name, rank.name, asSecondJob and ' (second job)' or ''))

    return true
end

---@param actor Actor
---@param target integer
---@param grade integer
---@param asSecondJob boolean
---@return boolean ok
---@return string? error
function Staff.offer(actor, target, grade, asSecondJob)
    local citizenid <const> = Members.citizenid(target)

    if not citizenid then
        return false, locale('job.hire_too_far')
    end

    local refusal <const> = hireRefusal(actor, citizenid, grade, asSecondJob)

    if refusal then return false, refusal end

    local pending <const> = offers[target]

    if pending and pending.expires >= os.time() then
        return false, locale('offer.pending')
    end

    local rank <const> = Jobs.grade(actor.job.name, grade) --[[@as JobGrade]]

    offers[target] = {
        citizenid = citizenid,
        job = actor.job.name,
        grade = grade,
        asSecondJob = asSecondJob,
        by = actor.source,
        byCitizen = actor.citizenid,
        expires = os.time() + OFFER_SECONDS,
    }

    TriggerClientEvent(
        'cobalt_management:jobOffer',
        target,
        actor.job.name,
        actor.job.label,
        rank.name,
        actor.name,
        asSecondJob
    )

    return true
end

---@param offer JobOffer
---@return Actor?
local function offeredBy(offer)
    if Members.citizenid(offer.by) ~= offer.byCitizen then return end

    local actor <const> = Staff.actor(offer.by)

    if not actor or actor.job.name ~= offer.job or not actor.isBoss then return end

    return actor
end

---@param source integer
---@param jobName unknown
---@param accept boolean
function Staff.answerOffer(source, jobName, accept)
    local offer <const> = offers[source]

    if not offer or type(jobName) ~= 'string' or offer.job ~= jobName then return end

    offers[source] = nil

    if Members.citizenid(source) ~= offer.citizenid then return end

    local actor <const> = offer.expires >= os.time() and offeredBy(offer) or nil
    local name <const> = Members.name(source)

    if not accept then
        if actor then Util.notify(actor.source, locale('offer.declined', name), 'info') end

        return
    end

    if not actor then
        return Util.notify(source, locale('offer.expired'), 'error')
    end

    if Util.distance(actor.source, source) > config.hireRadius then
        Util.notify(source, locale('offer.failed'), 'error')

        return Util.notify(actor.source, locale('job.hire_too_far'), 'error')
    end

    local ok <const>, err <const> = Staff.hireBy(actor, offer.citizenid, offer.grade, offer.asSecondJob)

    if not ok then
        Util.notify(source, locale('offer.failed'), 'error')

        return Util.notify(actor.source, err --[[@as string]], 'error')
    end

    Util.notify(actor.source, locale('offer.accepted', name), 'success')
end

---@param actor Actor
---@param citizenid string
---@param reason string?
---@return boolean ok
---@return string? error
function Staff.fireBy(actor, citizenid, reason)
    local target <const> = Staff.employee(actor.job.name, citizenid)

    if not target then
        return false, locale('staff.not_employee')
    end

    local refused <const> = outranks(actor, target)

    if refused then return false, refused end

    local ok <const>, err <const> = Staff.fire(actor.job.name, citizenid)

    if not ok then return false, err end

    if target.source then
        local message <const> = reason and locale('staff.fired_you_reason', actor.job.label, reason)
            or locale('staff.fired_you', actor.job.label)

        Util.notify(target.source, message, 'error')
    end

    Util.log(actor.job.name, 'Fire', ('%s fired %s%s'):format(actor.name, target.name, reason and (', ' .. reason) or ''))

    return true
end

---@param actor Actor
---@param citizenid string
---@param grade integer
---@return boolean ok
---@return string? error
function Staff.setGradeBy(actor, citizenid, grade)
    local target <const> = Staff.employee(actor.job.name, citizenid)

    if not target then
        return false, locale('staff.not_employee')
    end

    local refused <const> = outranks(actor, target)

    if refused then return false, refused end

    if grade >= actor.grade and actor.grade < actor.job.topGrade then
        return false, locale('staff.promote_below')
    end

    local ok <const>, err <const> = Staff.setGrade(actor.job.name, citizenid, grade)

    if not ok then return false, err end

    local rank <const> = Jobs.grade(actor.job.name, grade) --[[@as JobGrade]]
    local promoted <const> = grade > target.grade

    if target.source then
        Util.notify(target.source, locale(promoted and 'staff.promoted_you' or 'staff.moved_you', rank.name), 'info')
    end

    local verb <const> = promoted and 'promoted' or 'moved'

    Util.log(actor.job.name, 'Rank', ('%s %s %s to %s'):format(actor.name, verb, target.name, rank.name))

    return true
end

---@param actor Actor
---@param citizenid string
---@param amount integer
---@param reason? string
---@return boolean ok
---@return string? error
function Staff.bonus(actor, citizenid, amount, reason)
    local target <const> = Staff.employee(actor.job.name, citizenid)

    if not target then
        return false, locale('staff.not_employee')
    end

    if target.citizenid == actor.citizenid then
        return false, locale('staff.bonus_self')
    end

    if not actor.isBoss and target.grade >= actor.grade then
        return false, locale('staff.bonus_lower')
    end

    local note <const> = locale('society.bonus_to', target.name)
    local ok <const>, err <const> = Society.pay(actor.job.name, citizenid, amount, note, actor.citizenid)

    if not ok then return false, err --[[@as string?]] end

    db.addBonus({
        citizenid = citizenid,
        name = target.name,
        job = actor.job.name,
        amount = amount,
        reason = reason,
        by = actor.name,
    })

    local paid <const> = Util.money(amount)

    if target.source then
        local message <const> = reason and locale('staff.bonus_you_reason', actor.name, paid, reason)
            or locale('staff.bonus_you', actor.name, paid)

        Util.notify(target.source, message, 'success')
    end

    Util.log(actor.job.name, 'Bonus', ('%s gave %s %s%s'):format(actor.name, target.name, paid, reason and (', ' .. reason) or ''))

    return true
end

AddEventHandler('playerDropped', function()
    offers[source] = nil
end)

return Staff
