local Util <const> = require 'server.util'

---@alias RequestKind 'application' | 'leave' | 'report'
---@alias RequestStatus 'open' | 'approved' | 'declined'

---@class RequestRow
---@field id integer
---@field kind RequestKind
---@field citizenid? string
---@field player_name string
---@field job_name string
---@field title string
---@field message? string
---@field start_date? string
---@field end_date? string
---@field status RequestStatus
---@field reviewed_by? string
---@field created_at string
---@field reviewed_at? string

---@class StoredRequest
---@field id integer
---@field kind RequestKind
---@field citizenid? string
---@field name string
---@field title string
---@field message? string
---@field startDate? string
---@field endDate? string
---@field status RequestStatus
---@field reviewedBy? string
---@field createdAt integer
---@field reviewedAt? integer

---@class DutyRecord
---@field total integer every minute the character spent on duty for the job
---@field days table<string, integer> minutes per UTC day number, for the days the job keeps

---@class JobData
---@field requests table<string, StoredRequest>
---@field bonuses table[]
---@field duty table<string, DutyRecord> by citizenid

---@class JobStatus
---@field open boolean
---@field paidToday integer

local db <const> = {}

local DAY <const> = 86400
local REQUEST_DAYS <const> = 30
local LIMITS <const> = {
    requests = 200,
    openPerCitizen = { application = 1, leave = 3, report = 3 },
    announcements = 20,
    bonuses = 200,
    fleet = 100,
}

local ENSURE_JOB <const> = 'INSERT IGNORE INTO jobs (name) VALUES (?)'
local PUSH_ANNOUNCEMENT <const> = 'UPDATE jobs SET ' .. Util.appendCapped('announcements') .. ' WHERE name = ?'
local PUSH_BONUS <const> = 'UPDATE jobs SET ' .. Util.appendCapped('bonuses') .. ' WHERE name = ?'
local ADD_PAYOUT <const> = [[
    INSERT INTO jobs (name, payout_date, payout_total) VALUES (?, CURDATE(), ?)
    ON DUPLICATE KEY UPDATE
        payout_total = IF(payout_date = CURDATE(), payout_total + VALUES(payout_total), VALUES(payout_total)),
        payout_date = CURDATE()
]]

---@param jobName string
---@param name 'requests' | 'announcements' | 'bonuses' | 'fleet' | 'duty'
---@return table?
local function jobColumn(jobName, name)
    return Util.decode(MySQL.scalar.await(('SELECT %s FROM jobs WHERE name = ?'):format(name), { jobName }))
end

---@param jobName string
---@return JobData
function db.data(jobName)
    local row <const> = MySQL.single.await('SELECT requests, bonuses, duty FROM jobs WHERE name = ?', { jobName })

    return {
        requests = Util.decode(row?.requests) or {},
        bonuses = Util.decode(row?.bonuses) or {},
        duty = Util.decode(row?.duty) or {},
    }
end

---@param request StoredRequest
---@param jobName string
---@return RequestRow
local function requestRow(request, jobName)
    return {
        id = request.id,
        kind = request.kind,
        citizenid = request.citizenid,
        player_name = request.name,
        job_name = jobName,
        title = request.title or '',
        message = request.message,
        start_date = request.startDate,
        end_date = request.endDate,
        status = request.status,
        reviewed_by = request.reviewedBy,
        created_at = Util.iso(request.createdAt) --[[@as string]],
        reviewed_at = Util.iso(request.reviewedAt),
    }
end

---@param request StoredRequest
---@param now integer
---@return boolean
local function current(request, now)
    return request.status == 'open' or (request.createdAt or 0) >= now - REQUEST_DAYS * DAY
end

---@param jobName string
---@param keep? fun(request: StoredRequest): boolean
---@param stored? table<string, StoredRequest>
---@return RequestRow[]
local function findRequests(jobName, keep, stored)
    local now <const> = os.time()
    local found <const> = {}

    for _, request in pairs(stored or jobColumn(jobName, 'requests') or {}) do
        if current(request, now) and (not keep or keep(request)) then found[#found + 1] = request end
    end

    table.sort(found, function(a, b) return a.id > b.id end)

    local out <const> = {}

    for index, request in ipairs(found) do out[index] = requestRow(request, jobName) end

    return out
end

---@alias RequestRefusal 'inbox_full' | 'too_many_open'

---@param request { kind: RequestKind, citizenid: string, name: string, job: string, title?: string, message: string, startDate?: string, endDate?: string }
---@return boolean created
---@return RequestRefusal? refusal
function db.createRequest(request)
    MySQL.insert.await(ENSURE_JOB, { request.job })

    local refusal

    local created <const> = MySQL.startTransaction(function(query)
        local row <const> = query('SELECT seq, requests FROM jobs WHERE name = ? FOR UPDATE', { request.job })[1]
        local now <const> = os.time()
        local kept <const> = {}
        local open, mine = 0, 0

        for id, stored in pairs(Util.decode(row.requests) or {}) do
            if current(stored, now) then
                kept[id] = stored
            end

            if stored.status == 'open' then
                open += 1

                if stored.citizenid == request.citizenid and stored.kind == request.kind then mine += 1 end
            end
        end

        if open >= LIMITS.requests then
            refusal = 'inbox_full'
            return false
        end

        if mine >= LIMITS.openPerCitizen[request.kind] then
            refusal = 'too_many_open'
            return false
        end

        local id <const> = row.seq + 1

        kept[tostring(id)] = {
            id = id,
            kind = request.kind,
            citizenid = request.citizenid,
            name = request.name,
            title = request.title or '',
            message = request.message,
            startDate = request.startDate,
            endDate = request.endDate,
            status = 'open',
            createdAt = now,
        }

        query('UPDATE jobs SET seq = ?, requests = ? WHERE name = ?', { id, json.encode(kept), request.job })
    end) == true

    return created, refusal
end

---@param jobName string
---@param stored? table<string, StoredRequest>
---@return RequestRow[]
function db.requests(jobName, stored)
    return findRequests(jobName, nil, stored)
end

---@param citizenid string
---@param jobName string
---@param stored? table<string, StoredRequest>
---@return RequestRow[]
function db.requestsBy(citizenid, jobName, stored)
    local rows <const> = findRequests(jobName, function(request) return request.citizenid == citizenid end, stored)

    for index = #rows, 21, -1 do rows[index] = nil end

    return rows
end

---@param id integer
---@param jobName string
---@return RequestRow?
function db.request(id, jobName)
    local stored <const> = Util.decode(MySQL.scalar.await(
        'SELECT JSON_EXTRACT(requests, ?) FROM jobs WHERE name = ?',
        { Util.jsonPath(tostring(math.tointeger(id))), jobName }
    ))

    return stored and requestRow(stored --[[@as StoredRequest]], jobName) or nil
end

---@param citizenid string
---@param jobName string
---@return RequestRow?
function db.openApplication(citizenid, jobName)
    return findRequests(jobName, function(request)
        return request.citizenid == citizenid and request.kind == 'application' and request.status == 'open'
    end)[1]
end

---@param citizenids string[]
---@param jobName string
---@return table<string, string> appliedAt by citizenid
function db.openApplicationsFor(citizenids, jobName)
    local wanted <const> = {}

    for _, citizenid in ipairs(citizenids) do wanted[citizenid] = true end

    local out <const> = {}
    local open <const> = findRequests(jobName, function(request)
        return request.kind == 'application' and request.status == 'open' and wanted[request.citizenid] == true
    end)

    for _, row in ipairs(open) do
        if not out[row.citizenid] then out[row.citizenid] = row.created_at end
    end

    return out
end

---@param id integer
---@param jobName string
---@param status RequestStatus
---@param reviewer? string
---@param from? RequestStatus
---@return boolean
function db.answerRequest(id, jobName, status, reviewer, from)
    local path <const> = Util.jsonPath(tostring(math.tointeger(id)))

    return MySQL.update.await([[
        UPDATE jobs SET requests = JSON_SET(requests, CONCAT(?, '.status'), ?, CONCAT(?, '.reviewedBy'), ?, CONCAT(?, '.reviewedAt'), ?)
        WHERE name = ? AND JSON_VALUE(requests, CONCAT(?, '.status')) = ?
    ]], {
        path, status, path, reviewer, path, reviewer and os.time() or nil,
        jobName, path, from or 'open',
    }) == 1
end

---@param jobName string
---@param stored? table<string, StoredRequest>
---@return table<string, true>
function db.onLeave(jobName, stored)
    local today <const> = os.date('!%Y-%m-%d')
    local out <const> = {}

    for _, request in pairs(stored or jobColumn(jobName, 'requests') or {}) do
        local active <const> = request.kind == 'leave' and request.status == 'approved' and request.citizenid
            and request.startDate and request.endDate and request.startDate <= today and today <= request.endDate

        if active then out[request.citizenid] = true end
    end

    return out
end

---@param bonus { citizenid: string, name: string, job: string, amount: integer, reason: string, by: string }
function db.addBonus(bonus)
    local entry <const> = { at = os.time(), citizenid = bonus.citizenid, name = bonus.name, amount = bonus.amount, reason = bonus.reason, by = bonus.by }

    MySQL.insert.await(ENSURE_JOB, { bonus.job })
    MySQL.update.await(PUSH_BONUS, { LIMITS.bonuses, json.encode(entry), bonus.job })
end

---@param jobName string
---@param stored? table[]
---@return table<string, integer> month bonuses by citizenid
---@return integer week total
function db.bonusSummary(jobName, stored)
    local now <const> = os.time()
    local byCitizen <const>, week = {}, 0

    for _, bonus in ipairs(stored or jobColumn(jobName, 'bonuses') or {}) do
        local age <const> = now - (bonus.at or 0)
        local amount <const> = Util.whole(bonus.amount)

        if age <= 30 * DAY and bonus.citizenid then byCitizen[bonus.citizenid] = (byCitizen[bonus.citizenid] or 0) + amount end
        if age <= 7 * DAY then week += amount end
    end

    return byCitizen, week
end

---@param vehicle { plate: string, job: string, model: string, label: string, price: integer, by: string }
---@return boolean
function db.addVehicle(vehicle)
    local path <const> = Util.jsonPath(vehicle.plate)
    local entry <const> = {
        plate = vehicle.plate,
        model = vehicle.model,
        label = vehicle.label,
        price = vehicle.price,
        boughtBy = vehicle.by,
        boughtAt = os.time(),
    }

    MySQL.insert.await(ENSURE_JOB, { vehicle.job })

    return MySQL.update.await([[
        UPDATE jobs SET fleet = JSON_SET(COALESCE(fleet, JSON_OBJECT()), ?, JSON_EXTRACT(?, '$'))
        WHERE name = ? AND JSON_LENGTH(COALESCE(fleet, JSON_OBJECT())) < ? AND NOT JSON_CONTAINS_PATH(COALESCE(fleet, JSON_OBJECT()), 'one', ?)
    ]], { path, json.encode(entry), vehicle.job, LIMITS.fleet, path }) == 1
end

---@param jobName string
---@param plate string
function db.removeVehicle(jobName, plate)
    MySQL.update.await('UPDATE jobs SET fleet = JSON_REMOVE(fleet, ?) WHERE name = ?', { Util.jsonPath(plate), jobName })
end

---@return table<string, true> plates every job's fleet uses
function db.fleetPlates()
    local out <const> = {}

    for _, row in ipairs(MySQL.query.await('SELECT JSON_KEYS(fleet) AS plates FROM jobs WHERE fleet IS NOT NULL') or {}) do
        for _, plate in ipairs(Util.decode(row.plates) or {}) do out[plate] = true end
    end

    return out
end

---@param jobName string
---@return { plate: string, model: string, label: string, boughtBy: string, boughtAt: string }[]
function db.fleet(jobName)
    local vehicles <const> = {}

    for _, vehicle in pairs(jobColumn(jobName, 'fleet') or {}) do vehicles[#vehicles + 1] = vehicle end

    table.sort(vehicles, function(a, b) return (a.boughtAt or 0) > (b.boughtAt or 0) end)

    local out <const> = {}

    for index, vehicle in ipairs(vehicles) do
        out[index] = {
            plate = vehicle.plate,
            model = vehicle.model,
            label = vehicle.label,
            boughtBy = vehicle.boughtBy,
            boughtAt = Util.iso(vehicle.boughtAt) --[[@as string]],
        }
    end

    return out
end

---@param announcement { job: string, author: string, title: string, message: string }
function db.addAnnouncement(announcement)
    local entry <const> = { at = os.time(), author = announcement.author, title = announcement.title, message = announcement.message }

    MySQL.insert.await(ENSURE_JOB, { announcement.job })
    MySQL.update.await(PUSH_ANNOUNCEMENT, { LIMITS.announcements, json.encode(entry), announcement.job })
end

---@param jobName string
---@return { id: integer, title: string, message: string, author: string, createdAt: string }[]
function db.announcements(jobName)
    local stored <const> = jobColumn(jobName, 'announcements') or {}
    local out <const> = {}

    for index = #stored, 1, -1 do
        local entry <const> = stored[index]

        out[#out + 1] = {
            id = entry.id,
            title = entry.title,
            message = entry.message or '',
            author = entry.author,
            createdAt = Util.iso(entry.at) --[[@as string]],
        }
    end

    return out
end

---@return { name: string, settings: table }[]
function db.settings()
    local rows <const> = MySQL.query.await('SELECT name, settings FROM jobs WHERE settings IS NOT NULL') or {}

    for _, row in ipairs(rows) do row.settings = Util.decode(row.settings) or {} end

    return rows
end

---@param jobName string
---@param settings { logoUrl?: string, features: table, pay: table, permissions: table }
---@param by string
function db.saveSettings(jobName, settings, by)
    local stored <const> = {
        logoUrl = settings.logoUrl,
        features = settings.features,
        pay = settings.pay,
        permissions = settings.permissions,
        updatedBy = by,
    }

    MySQL.insert.await(
        'INSERT INTO jobs (name, settings) VALUES (?, ?) ON DUPLICATE KEY UPDATE settings = VALUES(settings)',
        { jobName, json.encode(stored) }
    )
end

---@param jobName string
---@return table<string, DutyRecord> by citizenid
function db.duty(jobName)
    return jobColumn(jobName, 'duty') or {}
end

---@param jobName string
---@param minutes table<string, integer> minutes to add by citizenid
---@param day integer UTC day number the minutes fall on
---@param keepDays integer days of daily totals the row keeps, today included
function db.addDuty(jobName, minutes, day, keepDays)
    local key <const> = tostring(day)
    local oldest <const> = day - keepDays + 1

    MySQL.insert.await(ENSURE_JOB, { jobName })
    MySQL.startTransaction(function(query)
        local row <const> = query('SELECT duty FROM jobs WHERE name = ? FOR UPDATE', { jobName })[1]
        local duty <const> = Util.decode(row?.duty) or {}

        for citizenid, added in pairs(minutes) do
            local record <const> = duty[citizenid] or {}
            local days <const> = record.days or {}

            days[key] = Util.whole(days[key]) + added
            record.days = days
            record.total = Util.whole(record.total) + added
            duty[citizenid] = record
        end

        for _, record in pairs(duty) do
            for stamp in pairs(record.days or {}) do
                if (tonumber(stamp) or 0) < oldest then record.days[stamp] = nil end
            end
        end

        query('UPDATE jobs SET duty = ? WHERE name = ?', { json.encode(duty), jobName })
    end)
end

---@param names string[]
---@return table<string, JobStatus> by job name, open with nothing paid for a job without a row
function db.status(names)
    local out <const> = {}

    for _, name in ipairs(names) do out[name] = { open = true, paidToday = 0 } end

    if #names == 0 then return out end

    local rows <const> = MySQL.query.await(
        'SELECT name, open, IF(payout_date = CURDATE(), payout_total, 0) AS paidToday FROM jobs WHERE name IN (?)',
        { names }
    ) or {}

    for _, row in ipairs(rows) do
        out[row.name] = { open = row.open == true or row.open == 1, paidToday = Util.whole(row.paidToday) }
    end

    return out
end

---@param jobName string
---@param open boolean
function db.setOpen(jobName, open)
    MySQL.insert.await(
        'INSERT INTO jobs (name, open) VALUES (?, ?) ON DUPLICATE KEY UPDATE open = VALUES(open)',
        { jobName, open and 1 or 0 }
    )
end

---@param jobName string
---@param amount integer
function db.addPayout(jobName, amount)
    MySQL.insert(ADD_PAYOUT, { jobName, amount })
end

return db
