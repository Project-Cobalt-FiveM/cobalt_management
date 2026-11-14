local config <const> = require 'config.server'
local db <const> = require 'server.db'
local Orgs <const> = require 'server.orgs'
local Members <const> = require 'server.members'
local Society <const> = require 'server.society'
local Util <const> = require 'server.util'

---@class Actor
---@field source integer
---@field citizenid string
---@field name string
---@field org OrgDefinition
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
---@field data? OrgData the org's data when the caller already read it

---@class JobOffer
---@field citizenid string
---@field org string
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

    if not entry then return end

    local org <const> = Orgs.get(entry.job.name)

    if not org or org.isGang then return end

    local grade <const> = entry.job.grade.level

    return {
        source = source,
        citizenid = entry.citizenid,
        name = Members.name(source),
        org = org,
        grade = grade,
        isBoss = Orgs.grade(org.name, grade)?.isBoss == true,
        permissions = Orgs.rankPermissions(org.name, grade),
    }
end

---@param source integer
---@param orgName string
---@return integer? grade
---@return boolean isGang
local function membership(source, orgName)
    local entry <const> = Members.entry(source)

    if not entry then return nil, false end

    if entry.job.name == orgName then return entry.job.grade.level, false end
    if entry.gang.name == orgName then return entry.gang.grade.level, true end

    return nil, false
end

---@param source integer
---@param orgName string
---@return boolean
function Staff.isBoss(source, orgName)
    local grade <const> = membership(source, orgName)

    return grade ~= nil and Orgs.grade(orgName, grade)?.isBoss == true
end

---@param source integer
---@param orgName string
---@param permission RankPermission
---@return boolean
function Staff.hasPermission(source, orgName, permission)
    local grade <const> = membership(source, orgName)

    return grade ~= nil and Orgs.rankPermissions(orgName, grade)[permission] == true
end

---@param orgName string
---@param options? RosterOptions
---@return Employee[]
function Staff.roster(orgName, options)
    local org <const> = Orgs.get(orgName)

    if not org then return {} end

    local field <const> = org.isGang and 'gang' or 'job'
    local totals <const> = options?.summary ~= true
    local duty <const> = totals and db.dutySummary(orgName, config.dutyPeriodDays) or {}
    local leave <const> = totals and db.onLeave(orgName, options?.data?.requests) or {}
    local bonuses <const> = totals and db.bonusSummary(orgName, options?.data?.bonuses) or {}
    local out <const> = {}

    for _, row in ipairs(db.members(field, orgName)) do
        local source <const> = Members.sourceOf(row.citizenid)
        local live <const> = source and Members.entry(source)
        local current <const> = live and live[field] or row[field]
        local level <const> = current.grade.level
        local grade <const> = Orgs.grade(orgName, level)
        local summary <const> = duty[row.citizenid]

        out[#out + 1] = {
            citizenid = row.citizenid,
            name = row.name or locale('member.unknown'),
            grade = level,
            rank = grade?.name or current.grade.name,
            pay = grade?.pay or 0,
            isBoss = grade?.isBoss == true,
            online = source ~= nil,
            onDuty = source ~= nil and (org.isGang or current.onduty == true),
            onLeave = leave[row.citizenid] == true,
            joinedAt = org.isGang and row.gangSince or row.jobSince,
            shiftStartedAt = source and summary?.shiftStartedAt or nil,
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

---@param orgName string
---@param monthBonuses table<string, integer> by citizenid
---@return Employee[]
function Staff.secondJobHolders(orgName, monthBonuses)
    local out <const> = {}

    for _, row in ipairs(db.secondJobHolders(orgName)) do
        local source <const> = Members.sourceOf(row.citizenid)
        local grade <const> = Orgs.grade(orgName, row.grade)

        out[#out + 1] = {
            citizenid = row.citizenid,
            name = row.name or locale('member.unknown'),
            grade = row.grade,
            rank = grade?.name or locale('org.grade_fallback', row.grade),
            pay = grade?.pay or 0,
            isBoss = grade?.isBoss == true,
            online = source ~= nil,
            onDuty = false,
            onLeave = false,
            joinedAt = row.since,
            weekMinutes = 0,
            lastWeekMinutes = 0,
            monthBonuses = monthBonuses[row.citizenid] or 0,
            source = source,
            secondJob = true,
        }
    end

    return out
end

---@param orgName string
---@param citizenid string
---@return StaffMember?
function Staff.employee(orgName, citizenid)
    local org <const> = Orgs.get(orgName)

    if not org then return end

    local field <const> = org.isGang and 'gang' or 'job'
    local row <const> = db.member(citizenid)

    if row?[field]?.name ~= orgName then
        local second <const> = not org.isGang and db.secondJob(citizenid, orgName)

        if not second then return end

        return {
            citizenid = citizenid,
            name = Members.nameOf(citizenid),
            grade = second.grade,
            source = Members.sourceOf(citizenid),
            secondJob = true,
        }
    end

    local source <const> = Members.sourceOf(citizenid)
    local live <const> = source and Members.entry(source)
    local current <const> = live and live[field] or row[field]

    return {
        citizenid = citizenid,
        name = row.name or locale('member.unknown'),
        grade = current.grade.level,
        source = source,
    }
end

---@param actor Actor
---@param target StaffMember
---@return string? error
local function outranks(actor, target)
    if target.citizenid == actor.citizenid then
        return locale('staff.own_job')
    end

    if target.grade >= actor.grade and actor.grade < actor.org.topGrade then
        return locale('staff.outranked')
    end
end

---@param orgName string
---@param citizenid string
---@param grade integer
---@return boolean ok
---@return string? error
function Staff.hire(orgName, citizenid, grade)
    local org <const> = Orgs.get(orgName)

    if not org or org.isGang then
        return false, locale('staff.no_job')
    end

    if not Orgs.grade(orgName, grade) then
        return false, locale('staff.no_rank')
    end

    if not exports.cobalt_core:GetName(citizenid) then
        return false, locale('staff.no_citizen')
    end

    if not Members.assignJob(citizenid, orgName, grade) then
        return false, locale('staff.job_change_failed')
    end

    return true
end

---@param orgName string
---@param citizenid string
---@return boolean ok
---@return string? error
function Staff.fire(orgName, citizenid)
    local source <const> = Members.sourceOf(citizenid)
    local current <const> = source and Members.job(source) or db.member(citizenid)?.job

    if current?.name ~= orgName then
        if db.removeSecondJob(citizenid, orgName) then return true end

        return false, locale('staff.not_employee')
    end

    if not Members.clearJob(citizenid) then
        return false, locale('staff.job_change_failed')
    end

    return true
end

---@param orgName string
---@param citizenid string
---@param grade integer
---@return boolean ok
---@return string? error
function Staff.setGrade(orgName, citizenid, grade)
    if not Orgs.grade(orgName, grade) then
        return false, locale('staff.no_rank')
    end

    local source <const> = Members.sourceOf(citizenid)
    local current <const> = source and Members.job(source) or db.member(citizenid)?.job

    if current?.name ~= orgName then
        if not db.secondJob(citizenid, orgName) then
            return false, locale('staff.not_employee')
        end

        if not db.addSecondJob(citizenid, orgName, grade) then
            return false, locale('staff.rank_change_failed')
        end

        return true
    end

    if not Members.assignJob(citizenid, orgName, grade) then
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

    if grade >= actor.grade and actor.grade < actor.org.topGrade then
        return locale('staff.hire_below')
    end

    if not Orgs.grade(actor.org.name, grade) then
        return locale('staff.no_rank')
    end

    local source <const> = Members.sourceOf(citizenid)
    local current <const> = source and Members.job(source) or db.member(citizenid)?.job

    if current?.name == actor.org.name then
        return locale('staff.already_employee')
    end

    if asSecondJob and not Orgs.feature(actor.org.name, 'secondJobs') then
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

    local orgName <const> = actor.org.name
    local source <const> = Members.sourceOf(citizenid)

    if asSecondJob then
        if not exports.cobalt_core:GetName(citizenid) then
            return false, locale('staff.no_citizen')
        end

        if not db.addSecondJob(citizenid, orgName, grade) then
            return false, locale('staff.second_jobs_full')
        end
    else
        local ok <const>, err <const> = Staff.hire(orgName, citizenid, grade)

        if not ok then return false, err end
    end

    local name <const> = Members.nameOf(citizenid)
    local rank <const> = Orgs.grade(orgName, grade) --[[@as OrgGrade]]

    if source then
        Util.notify(source, locale('staff.hired_you', actor.name, actor.org.label, rank.name), 'success')
    end

    Util.log(orgName, 'Hire', ('%s hired %s as %s%s'):format(actor.name, name, rank.name, asSecondJob and ' (second job)' or ''))

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
        return false, locale('org.hire_too_far')
    end

    local refusal <const> = hireRefusal(actor, citizenid, grade, asSecondJob)

    if refusal then return false, refusal end

    local pending <const> = offers[target]

    if pending and pending.expires >= os.time() then
        return false, locale('offer.pending')
    end

    local rank <const> = Orgs.grade(actor.org.name, grade) --[[@as OrgGrade]]

    offers[target] = {
        citizenid = citizenid,
        org = actor.org.name,
        grade = grade,
        asSecondJob = asSecondJob,
        by = actor.source,
        byCitizen = actor.citizenid,
        expires = os.time() + OFFER_SECONDS,
    }

    TriggerClientEvent(
        'cobalt_management:jobOffer',
        target,
        actor.org.name,
        actor.org.label,
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

    if not actor or actor.org.name ~= offer.org or not actor.isBoss then return end

    return actor
end

---@param source integer
---@param orgName unknown
---@param accept boolean
function Staff.answerOffer(source, orgName, accept)
    local offer <const> = offers[source]

    if not offer or type(orgName) ~= 'string' or offer.org ~= orgName then return end

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

        return Util.notify(actor.source, locale('org.hire_too_far'), 'error')
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
    local target <const> = Staff.employee(actor.org.name, citizenid)

    if not target then
        return false, locale('staff.not_employee')
    end

    local refused <const> = outranks(actor, target)

    if refused then return false, refused end

    local ok <const>, err <const> = Staff.fire(actor.org.name, citizenid)

    if not ok then return false, err end

    if target.source then
        local message <const> = reason and locale('staff.fired_you_reason', actor.org.label, reason)
            or locale('staff.fired_you', actor.org.label)

        Util.notify(target.source, message, 'error')
    end

    Util.log(actor.org.name, 'Fire', ('%s fired %s%s'):format(actor.name, target.name, reason and (', ' .. reason) or ''))

    return true
end

---@param actor Actor
---@param citizenid string
---@param grade integer
---@return boolean ok
---@return string? error
function Staff.setGradeBy(actor, citizenid, grade)
    local target <const> = Staff.employee(actor.org.name, citizenid)

    if not target then
        return false, locale('staff.not_employee')
    end

    local refused <const> = outranks(actor, target)

    if refused then return false, refused end

    if grade >= actor.grade and actor.grade < actor.org.topGrade then
        return false, locale('staff.promote_below')
    end

    local ok <const>, err <const> = Staff.setGrade(actor.org.name, citizenid, grade)

    if not ok then return false, err end

    local rank <const> = Orgs.grade(actor.org.name, grade) --[[@as OrgGrade]]
    local promoted <const> = grade > target.grade

    if target.source then
        Util.notify(target.source, locale(promoted and 'staff.promoted_you' or 'staff.moved_you', rank.name), 'info')
    end

    local verb <const> = promoted and 'promoted' or 'moved'

    Util.log(actor.org.name, 'Rank', ('%s %s %s to %s'):format(actor.name, verb, target.name, rank.name))

    return true
end

---@param actor Actor
---@param citizenid string
---@param amount integer
---@param reason? string
---@return boolean ok
---@return string? error
function Staff.bonus(actor, citizenid, amount, reason)
    local target <const> = Staff.employee(actor.org.name, citizenid)

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
    local ok <const>, err <const> = Society.pay(actor.org.name, citizenid, amount, note, actor.citizenid)

    if not ok then return false, err --[[@as string?]] end

    db.addBonus({
        citizenid = citizenid,
        name = target.name,
        org = actor.org.name,
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

    Util.log(actor.org.name, 'Bonus', ('%s gave %s %s%s'):format(actor.name, target.name, paid, reason and (', ' .. reason) or ''))

    return true
end

AddEventHandler('playerDropped', function()
    offers[source] = nil
end)

return Staff
