local db <const> = require 'server.db'
local Orgs <const> = require 'server.orgs'
local Members <const> = require 'server.members'

---@class JobEntry
---@field name string
---@field label string
---@field rank string
---@field pay integer
---@field since? string
---@field isMain boolean
---@field onDuty boolean

local SecondJobs <const> = {}

---@param source integer
---@return JobEntry[]
function SecondJobs.list(source)
    local entry <const> = Members.entry(source)

    if not entry then return {} end

    local main <const> = Orgs.get(entry.job.name) and Orgs.grade(entry.job.name, entry.job.grade.level)
    local out <const> = {}

    if main then
        out[1] = {
            name = entry.job.name,
            label = entry.job.label,
            rank = main.name,
            pay = main.pay,
            since = entry.jobSince,
            isMain = true,
            onDuty = entry.job.onduty == true,
        }
    end

    for _, row in ipairs(db.secondJobs(entry.citizenid)) do
        local org <const> = Orgs.get(row.job_name)
        local grade <const> = org and Orgs.feature(row.job_name, 'secondJobs') and Orgs.grade(row.job_name, row.grade)

        if grade then
            out[#out + 1] = {
                name = row.job_name,
                label = org.label,
                rank = grade.name,
                pay = grade.pay,
                since = row.since,
                isMain = false,
                onDuty = false,
            }
        end
    end

    return out
end

---@param source integer
---@param name string
---@return boolean ok
---@return string? error
function SecondJobs.makeMain(source, name)
    local entry <const> = Members.entry(source)
    local row <const> = entry and db.secondJob(entry.citizenid, name)

    if not entry or not row then
        return false, locale('jobs.not_yours')
    end

    if not Orgs.feature(name, 'secondJobs') then
        return false, locale('jobs.second_jobs_off')
    end

    local current <const> = entry.job
    local demoted <const> = Orgs.get(current.name) and { name = current.name, grade = current.grade.level } or nil

    if not Members.setJob(source, name, row.grade, demoted) then
        return false, locale('staff.job_change_failed')
    end

    return true
end

---@param source integer
---@param name string
---@return boolean ok
---@return string? error
function SecondJobs.leave(source, name)
    local citizenid <const> = Members.citizenid(source)

    if not citizenid or not db.removeSecondJob(citizenid, name) then
        return false, locale('jobs.not_yours')
    end

    return true
end

return SecondJobs
