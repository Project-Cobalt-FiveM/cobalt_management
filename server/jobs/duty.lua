local config <const> = require 'config.server'
local db <const> = require 'server.jobs.db'
local Jobs <const> = require 'server.jobs.registry'
local Util <const> = require 'server.util'

---@class Shift
---@field job string
---@field startedAt integer
---@field countedAt integer the minutes before this are already on the job's row

---@class DutySummary
---@field week integer minutes in the last `dutyPeriodDays` days, today included
---@field lastWeek integer minutes in the period before that
---@field shiftStartedAt? integer

local Duty <const> = {}

local DAY <const> = 86400
local PERIOD <const> = config.dutyPeriodDays
local KEEP_DAYS <const> = PERIOD * 2
local COUNT_MINUTES <const> = 5

---@type table<string, Shift> by citizenid
local shifts <const> = {}

---@return integer
local function today()
    return os.time() // DAY
end

---@param shift Shift
---@param now integer
---@return integer
local function uncounted(shift, now)
    return (now - shift.countedAt) // 60
end

---@param citizenid string
---@param shift Shift
local function count(citizenid, shift)
    local minutes <const> = uncounted(shift, os.time())

    if minutes <= 0 then return end

    shift.countedAt += minutes * 60
    db.addDuty(shift.job, { [citizenid] = minutes }, today(), KEEP_DAYS)
end

---@param citizenid string
---@param jobName string ends a shift for another job first; starts none when the job doesn't track duty
function Duty.clockIn(citizenid, jobName)
    local current <const> = shifts[citizenid]

    if current?.job == jobName then return end

    shifts[citizenid] = nil

    if Jobs.get(jobName) and Jobs.feature(jobName, 'duty') then
        local now <const> = os.time()

        shifts[citizenid] = { job = jobName, startedAt = now, countedAt = now }
    end

    if current then count(citizenid, current) end
end

---@param citizenid string
function Duty.clockOut(citizenid)
    local shift <const> = shifts[citizenid]

    if not shift then return end

    shifts[citizenid] = nil
    count(citizenid, shift)
end

---@param jobName string
---@param records table<string, DutyRecord> the job's duty records
---@return table<string, DutySummary> by citizenid
function Duty.summary(jobName, records)
    local day <const> = today()
    local out <const> = {}

    for citizenid, record in pairs(records) do
        local week, lastWeek = 0, 0

        for stamp, minutes in pairs(record.days or {}) do
            local age <const> = day - (tonumber(stamp) or 0)

            if age < PERIOD then
                week += Util.whole(minutes)
            elseif age < KEEP_DAYS then
                lastWeek += Util.whole(minutes)
            end
        end

        out[citizenid] = { week = week, lastWeek = lastWeek }
    end

    local now <const> = os.time()

    for citizenid, shift in pairs(shifts) do
        if shift.job == jobName then
            local summary <const> = out[citizenid] or { week = 0, lastWeek = 0 }

            summary.week += uncounted(shift, now)
            summary.shiftStartedAt = shift.startedAt
            out[citizenid] = summary
        end
    end

    return out
end

---@param citizenids string[]
---@param jobName string
---@param days integer up to twice `dutyPeriodDays` sums the daily totals; longer returns every minute on record
---@return table<string, integer> minutes by citizenid
function Duty.minutes(citizenids, jobName, days)
    local records <const> = db.duty(jobName)
    local day <const>, now <const> = today(), os.time()
    local out <const> = {}

    for _, citizenid in ipairs(citizenids) do
        local record <const> = records[citizenid]
        local minutes = 0

        if record and days > KEEP_DAYS then
            minutes = Util.whole(record.total)
        elseif record then
            for stamp, value in pairs(record.days or {}) do
                if day - (tonumber(stamp) or 0) < days then minutes += Util.whole(value) end
            end
        end

        local shift <const> = shifts[citizenid]

        if shift?.job == jobName then minutes += uncounted(shift, now) end

        out[citizenid] = minutes
    end

    return out
end

local function countOpenShifts()
    local now <const>, day <const> = os.time(), today()
    local byJob <const> = {}

    for citizenid, shift in pairs(shifts) do
        local minutes <const> = uncounted(shift, now)

        if minutes > 0 then
            local added <const> = byJob[shift.job] or {}

            shift.countedAt += minutes * 60
            added[citizenid] = minutes
            byJob[shift.job] = added
        end
    end

    for jobName, added in pairs(byJob) do db.addDuty(jobName, added, day, KEEP_DAYS) end
end

SetInterval(countOpenShifts, COUNT_MINUTES * 60000)

return Duty
