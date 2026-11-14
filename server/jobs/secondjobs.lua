local Jobs <const> = require 'server.jobs.registry'
local Members <const> = require 'server.members'
local Util <const> = require 'server.util'

---@class JobEntry
---@field name string
---@field label string
---@field rank string
---@field pay integer
---@field since? string
---@field isMain boolean
---@field onDuty boolean

local SecondJobs <const> = {}

local LIMIT <const> = 20

---@param jobs table<string, SecondJob>
---@return string[] names oldest first
local function byAge(jobs)
    local names <const> = {}

    for name in pairs(jobs) do names[#names + 1] = name end

    table.sort(names, function(a, b) return Util.whole(jobs[a].since) < Util.whole(jobs[b].since) end)

    return names
end

---@param citizenid string
---@param jobName string
---@return SecondJob?
function SecondJobs.get(citizenid, jobName)
    return Members.secondJobs(citizenid)[jobName]
end

---@param citizenid string
---@param jobName string
---@param grade integer the grade to hold it at, also for a second job they already hold
---@return boolean added false when the character already holds the most second jobs
function SecondJobs.add(citizenid, jobName, grade)
    local jobs <const> = Members.secondJobs(citizenid)
    local held <const> = jobs[jobName]

    if not held and #byAge(jobs) >= LIMIT then return false end

    jobs[jobName] = { grade = grade, since = held and Util.whole(held.since) or os.time() }

    return Members.saveSecondJobs(citizenid, jobs)
end

---@param citizenid string
---@param jobName string
---@return boolean removed
function SecondJobs.remove(citizenid, jobName)
    local jobs <const> = Members.secondJobs(citizenid)

    if not jobs[jobName] then return false end

    jobs[jobName] = nil

    return Members.saveSecondJobs(citizenid, jobs)
end

---@param source integer
---@return JobEntry[]
function SecondJobs.list(source)
    local entry <const> = Members.entry(source)

    if not entry then return {} end

    local main <const> = Jobs.get(entry.job.name) and Jobs.grade(entry.job.name, entry.job.grade.level)
    local out <const> = {}

    if main then
        out[1] = {
            name = entry.job.name,
            label = entry.job.label,
            rank = main.name,
            pay = main.pay,
            since = Util.iso(entry.job.since),
            isMain = true,
            onDuty = entry.job.onduty == true,
        }
    end

    local held <const> = Members.secondJobs(entry.citizenid)

    for _, name in ipairs(byAge(held)) do
        local job <const> = Jobs.get(name)
        local allowed <const> = job and Jobs.feature(name, 'secondJobs')
        local grade <const> = allowed and Jobs.grade(name, Util.whole(held[name].grade))

        if grade then
            out[#out + 1] = {
                name = name,
                label = job.label,
                rank = grade.name,
                pay = grade.pay,
                since = Util.iso(held[name].since),
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
    local held <const> = entry and SecondJobs.get(entry.citizenid, name)

    if not entry or not held then
        return false, locale('jobs.not_yours')
    end

    if not Jobs.feature(name, 'secondJobs') then
        return false, locale('jobs.second_jobs_off')
    end

    local current <const> = entry.job
    local demoted <const> = Jobs.get(current.name) and { name = current.name, grade = current.grade.level } or nil

    if not Members.setJob(source, name, Util.whole(held.grade), demoted) then
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

    if not citizenid or not SecondJobs.remove(citizenid, name) then
        return false, locale('jobs.not_yours')
    end

    return true
end

return SecondJobs
