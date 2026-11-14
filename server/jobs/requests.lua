local config <const> = require 'config.server'
local db <const> = require 'server.jobs.db'
local Jobs <const> = require 'server.jobs.registry'
local Members <const> = require 'server.members'
local Staff <const> = require 'server.jobs.staff'
local Util <const> = require 'server.util'

---@class RequestView
---@field id integer
---@field kind 'application' | 'leave' | 'report'
---@field status 'open' | 'approved' | 'declined'
---@field citizenid string
---@field name string
---@field title string
---@field message string
---@field startDate? string
---@field endDate? string
---@field createdAt string
---@field reviewedBy? string
---@field reviewedAt? string
---@field applicant? { phone?: string, currentJob?: string, workedHereBefore: boolean, online: boolean }

local Requests <const> = {}

local FEATURE <const> = { application = 'applications', leave = 'leaves', report = 'reports' }

---@param kind 'application' | 'leave' | 'report'
---@param refusal? RequestRefusal
---@return string
local function refused(kind, refusal)
    if not refusal then return locale('requests.failed') end

    return locale(('requests.%s.%s'):format(kind, refusal))
end

---@param row RequestRow
---@return boolean
local function isOpenApplication(row)
    return row.kind == 'application' and row.status == 'open' and row.citizenid ~= nil
end

---@param citizenid string
---@param found? Applicant
---@param workedHere boolean
---@return { phone?: string, currentJob?: string, workedHereBefore: boolean, online: boolean }
local function applicantView(citizenid, found, workedHere)
    local jobName <const> = found?.job
    local current <const> = jobName ~= Members.UNEMPLOYED and Jobs.shared(jobName)

    return {
        phone = found?.phone,
        currentJob = current and current.label or nil,
        workedHereBefore = workedHere,
        online = Members.sourceOf(citizenid) ~= nil,
    }
end

---@param row RequestRow
---@param applicants? table<string, Applicant>
---@param duty? table<string, DutyRecord>
---@return RequestView
local function view(row, applicants, duty)
    local applicant

    if applicants and isOpenApplication(row) then
        applicant = applicantView(row.citizenid, applicants[row.citizenid], duty?[row.citizenid] ~= nil)
    end

    return {
        id = row.id,
        kind = row.kind,
        status = row.status,
        citizenid = row.citizenid or '',
        name = row.player_name,
        title = row.title,
        message = row.message or '',
        startDate = row.start_date,
        endDate = row.end_date,
        createdAt = row.created_at,
        reviewedBy = row.reviewed_by,
        reviewedAt = row.reviewed_at,
        applicant = applicant,
    }
end

---@param jobName string
---@param data? JobRecord the job's row when the caller already read it
---@return RequestView[]
function Requests.list(jobName, data)
    local rows <const>, applicantIds <const> = {}, {}

    for _, row in ipairs(db.requests(jobName, data?.requests)) do
        if Jobs.feature(jobName, FEATURE[row.kind]) then
            rows[#rows + 1] = row

            if isOpenApplication(row) then applicantIds[#applicantIds + 1] = row.citizenid end
        end
    end

    local applicants <const> = Members.applicants(applicantIds)
    local duty <const> = #applicantIds > 0 and (data?.duty or db.duty(jobName)) or nil
    local out <const> = {}

    for index, row in ipairs(rows) do out[index] = view(row, applicants, duty) end

    return out
end

---@param citizenid string
---@param jobName string
---@param data? JobRecord the job's row when the caller already read it
---@return RequestView[]
function Requests.mine(citizenid, jobName, data)
    local out <const> = {}

    for _, row in ipairs(db.requestsBy(citizenid, jobName, data?.requests)) do out[#out + 1] = view(row) end

    return out
end

---@param citizenid string
---@param jobName string
---@return RequestView?
function Requests.pendingApplication(citizenid, jobName)
    local row <const> = db.openApplication(citizenid, jobName)

    return row and view(row) or nil
end

---@param jobName string
---@param text string
local function notifyBosses(jobName, text)
    for _, source in ipairs(Members.sourcesIn(jobName)) do
        if Staff.isBoss(source, jobName) then Util.notify(source, text, 'info') end
    end
end

---@param source integer
---@param jobName string
---@param message unknown
---@return boolean ok
---@return string? error
function Requests.apply(source, jobName, message)
    local job <const> = Jobs.get(jobName)
    local citizenid <const> = Members.citizenid(source)
    local text <const> = Util.text(message, config.limits.message)

    if not job or not citizenid then
        return false, locale('apply.not_taken')
    end

    if not Jobs.feature(jobName, 'applications') then
        return false, locale('apply.closed', job.label)
    end

    if not text then
        return false, locale('apply.need_message')
    end

    if Members.job(source)?.name == jobName then
        return false, locale('common.already_staff')
    end

    if db.openApplication(citizenid, jobName) then
        return false, locale('requests.application.too_many_open')
    end

    local name <const> = Members.name(source)

    local created <const>, refusal <const> = db.createRequest({
        kind = 'application',
        citizenid = citizenid,
        name = name,
        job = jobName,
        title = '',
        message = text,
    })

    if not created then return false, refused('application', refusal) end

    notifyBosses(jobName, locale('requests.application.sent', name, job.label))
    Util.log(jobName, 'Application', ('%s applied'):format(name))

    return true
end

---@param date unknown
---@return boolean
local function isDate(date)
    return type(date) == 'string' and date:match('^%d%d%d%d%-%d%d%-%d%d$') ~= nil
end

---@param actor Actor
---@param from unknown
---@param untilDate unknown
---@param reason unknown
---@return boolean ok
---@return string? error
function Requests.leave(actor, from, untilDate, reason)
    if not Jobs.feature(actor.job.name, 'leaves') then
        return false, locale('requests.leave.off')
    end

    if not isDate(from) or not isDate(untilDate) then
        return false, locale('requests.leave.pick_dates')
    end

    if untilDate < from then
        return false, locale('requests.leave.end_before_start')
    end

    if from < os.date('!%Y-%m-%d') then
        return false, locale('requests.leave.past')
    end

    local text <const> = Util.text(reason, config.limits.reason) or ''

    local created <const>, refusal <const> = db.createRequest({
        kind = 'leave',
        citizenid = actor.citizenid,
        name = actor.name,
        job = actor.job.name,
        message = text,
        startDate = from --[[@as string]],
        endDate = untilDate --[[@as string]],
    })

    if not created then return false, refused('leave', refusal) end

    notifyBosses(actor.job.name, locale('requests.leave.sent', actor.name, from, untilDate))

    return true
end

---@param actor Actor
---@param title unknown
---@param message unknown
---@return boolean ok
---@return string? error
function Requests.report(actor, title, message)
    if not Jobs.feature(actor.job.name, 'reports') then
        return false, locale('requests.report.off')
    end

    local heading <const> = Util.text(title, config.limits.title)
    local text <const> = Util.text(message, config.limits.message)

    if not heading or not text then
        return false, locale('common.title_and_message')
    end

    local created <const>, refusal <const> = db.createRequest({
        kind = 'report',
        citizenid = actor.citizenid,
        name = actor.name,
        job = actor.job.name,
        title = heading,
        message = text,
    })

    if not created then return false, refused('report', refusal) end

    notifyBosses(actor.job.name, locale('requests.report.sent', actor.name, heading))

    return true
end

---@param actor Actor
---@param id integer
---@param approve boolean
---@param grade? integer
---@return boolean ok
---@return string? error
function Requests.answer(actor, id, approve, grade)
    local row <const> = db.request(id, actor.job.name)

    if not row or row.status ~= 'open' then
        return false, locale('requests.answered')
    end

    local hiring <const> = approve and row.kind == 'application'

    if hiring and not row.citizenid then
        return false, locale('requests.no_character')
    end

    local answer <const> = approve and 'approved' or 'declined'

    if not db.answerRequest(id, actor.job.name, answer, actor.name) then
        return false, locale('requests.answered')
    end

    if hiring then
        local ok <const>, err <const> = Staff.hireBy(actor, row.citizenid --[[@as string]], grade or 0, false)

        if not ok then
            db.answerRequest(id, actor.job.name, 'open', nil, 'approved')

            return false, err
        end
    end

    local source <const> = row.citizenid and Members.sourceOf(row.citizenid)

    if source and row.kind ~= 'application' then
        local key <const> = ('requests.%s.%s'):format(row.kind, answer)

        Util.notify(source, locale(key, actor.name), approve and 'success' or 'info')
    elseif source and not approve then
        Util.notify(source, locale('requests.application.declined', actor.job.label), 'info')
    end

    Util.log(actor.job.name, 'Request', ('%s %s %s from %s'):format(actor.name, answer, row.kind, row.player_name))

    return true
end

return Requests
