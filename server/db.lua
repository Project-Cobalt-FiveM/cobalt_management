local Util <const> = require 'server.util'

---@alias MembershipField 'job' | 'gang'

---@class MemberRow
---@field citizenid string
---@field job? table
---@field gang? table
---@field jobSince? string
---@field gangSince? string
---@field name? string
---@field updatedAt string

---@class RequestRow
---@field id integer
---@field kind 'application' | 'leave' | 'report'
---@field citizenid? string
---@field player_name string
---@field org_name string
---@field title string
---@field message? string
---@field start_date? string
---@field end_date? string
---@field status 'open' | 'approved' | 'declined'
---@field reviewed_by? string
---@field created_at string
---@field reviewed_at? string

---@class StoredRequest
---@field id integer
---@field kind 'application' | 'leave' | 'report'
---@field citizenid? string
---@field name string
---@field title string
---@field message? string
---@field startDate? string
---@field endDate? string
---@field status 'open' | 'approved' | 'declined'
---@field reviewedBy? string
---@field createdAt integer
---@field reviewedAt? integer

---@class VaultDebit
---@field amount integer
---@field what string
---@field who string

local db <const> = {}

local FIELDS <const> = { job = true, gang = true }
local DAY <const> = 86400
local REQUEST_DAYS <const> = 30
local LIMITS <const> = {
    requests = 200,
    openPerCitizen = { application = 1, leave = 3, report = 3 },
    announcements = 20,
    bonuses = 200,
    vaultLog = 50,
    fleet = 100,
    secondJobs = 20,
}

local NULL <const> = json.null

---@param value unknown
---@return unknown
local function scrub(value)
    if value == NULL or type(value) == 'userdata' then return nil end
    if type(value) ~= 'table' then return value end

    for key, inner in pairs(value) do value[key] = scrub(inner) end

    return value
end

---@param value unknown
---@return table?
local function decode(value)
    if type(value) == 'string' then value = json.decode(value) end

    return type(value) == 'table' and scrub(value) --[[@as table]] or nil
end

---@param name string
---@return string
local function key(name)
    assert(type(name) == 'string' and name:find('^[%w_%- ]+$'), ('invalid json key %s'):format(tostring(name)))

    return ('$."%s"'):format(name)
end

---@param field MembershipField
---@return MembershipField
local function column(field)
    assert(FIELDS[field], ('unknown membership field %s'):format(tostring(field)))
    return field
end

---@param name 'vault_log' | 'announcements' | 'bonuses'
---@return string
local function push(name)
    return ([[seq = seq + 1, %s = JSON_ARRAY_APPEND(
        IF(JSON_LENGTH(COALESCE(%s, JSON_ARRAY())) >= ?, JSON_REMOVE(%s, '$[0]'), COALESCE(%s, JSON_ARRAY())),
        '$', JSON_SET(JSON_EXTRACT(?, '$'), '$.id', seq)
    )]]):format(name, name, name, name)
end

local ENSURE_ORG <const> = 'INSERT IGNORE INTO management_orgs (name) VALUES (?)'
local PUSH_ANNOUNCEMENT <const> = 'UPDATE management_orgs SET ' .. push('announcements') .. ' WHERE name = ?'
local PUSH_BONUS <const> = 'UPDATE management_orgs SET ' .. push('bonuses') .. ' WHERE name = ?'
local DEBIT_VAULT <const> = 'UPDATE management_orgs SET vault_balance = vault_balance - ?, ' .. push('vault_log') .. ' WHERE name = ? AND vault_balance >= ?'
local CREDIT_VAULT <const> = 'UPDATE management_orgs SET vault_balance = vault_balance + ?, ' .. push('vault_log') .. ' WHERE name = ?'

---@param orgName string
---@param name string
---@return table?
local function orgColumn(orgName, name)
    return decode(MySQL.scalar.await(('SELECT %s FROM management_orgs WHERE name = ?'):format(name), { orgName }))
end

---@class OrgData
---@field requests table<string, StoredRequest>
---@field bonuses table[]

---@param orgName string
---@return OrgData
function db.orgData(orgName)
    local row <const> = MySQL.single.await('SELECT requests, bonuses FROM management_orgs WHERE name = ?', { orgName })

    return { requests = decode(row?.requests) or {}, bonuses = decode(row?.bonuses) or {} }
end

---@param row? table
---@return MemberRow?
local function memberRow(row)
    if not row then return end

    row.job, row.gang = decode(row.job), decode(row.gang)

    return row
end

local MEMBER_COLUMNS <const> = [[
    m.citizenid, m.job, m.gang, p.fullname AS name,
    DATE_FORMAT(CONVERT_TZ(m.job_since, @@session.time_zone, '+00:00'), '%Y-%m-%dT%TZ') AS jobSince,
    DATE_FORMAT(CONVERT_TZ(m.gang_since, @@session.time_zone, '+00:00'), '%Y-%m-%dT%TZ') AS gangSince,
    DATE_FORMAT(CONVERT_TZ(m.updated_at, @@session.time_zone, '+00:00'), '%Y-%m-%dT%TZ') AS updatedAt
]]

---@param citizenid string
---@return MemberRow?
function db.member(citizenid)
    return memberRow(MySQL.single.await(
        'SELECT ' .. MEMBER_COLUMNS .. ' FROM management_members m LEFT JOIN players p ON p.citizenid = m.citizenid WHERE m.citizenid = ?',
        { citizenid }
    ))
end

---@param field MembershipField
---@param orgName string
---@return MemberRow[]
function db.members(field, orgName)
    local rows <const> = MySQL.query.await(
        ('SELECT %s FROM management_members m LEFT JOIN players p ON p.citizenid = m.citizenid WHERE m.%s_name = ? ORDER BY m.%s_since LIMIT 500')
            :format(MEMBER_COLUMNS, column(field), field),
        { orgName }
    ) or {}

    for _, row in ipairs(rows) do memberRow(row) end

    return rows
end

---@param citizenids string[]
---@return { citizenid: string, job?: table, gang?: table }[]
function db.membershipsOf(citizenids)
    if #citizenids == 0 then return {} end

    local rows <const> = MySQL.query.await('SELECT citizenid, job, gang FROM management_members WHERE citizenid IN (?)', { citizenids }) or {}

    for _, row in ipairs(rows) do row.job, row.gang = decode(row.job), decode(row.gang) end

    return rows
end

---@param field MembershipField
---@param orgName string
---@return integer
function db.countMembers(field, orgName)
    return MySQL.scalar.await(('SELECT COUNT(*) FROM management_members WHERE %s_name = ?'):format(column(field)), { orgName }) or 0
end

---@param field 'job' | 'gang'
---@return table<string, integer> counts members per org name
function db.memberCounts(field)
    local name <const> = column(field) .. '_name'
    local rows <const> = MySQL.query.await(('SELECT %s AS name, COUNT(*) AS members FROM management_members WHERE %s IS NOT NULL GROUP BY %s'):format(name, name, name)) or {}
    local counts <const> = {}

    for _, row in ipairs(rows) do counts[row.name] = row.members end

    return counts
end

---@param citizenid string
---@param job table
---@param gang table
function db.saveMember(citizenid, job, gang)
    MySQL.insert.await([[
        INSERT INTO management_members (citizenid, job, gang, job_since, gang_since) VALUES (?, ?, ?, NOW(), NOW())
        ON DUPLICATE KEY UPDATE job = VALUES(job), gang = VALUES(gang)
    ]], { citizenid, json.encode(job), json.encode(gang) })
end

---@param citizenid string
---@param field MembershipField
---@param value table
---@param joined boolean
---@param demoted? { name: string, grade: integer } the previous main job, kept as a second job
function db.saveMembership(citizenid, field, value, joined, demoted)
    local name <const> = column(field)
    local since <const> = joined and ('%s_since = NOW()'):format(name) or ('%s_since = COALESCE(%s_since, NOW())'):format(name, name)
    local params <const> = { citizenid, json.encode(value) }
    local secondJobs = ''

    if field == 'job' then
        local jobs = 'JSON_REMOVE(COALESCE(second_jobs, JSON_OBJECT()), ?)'

        params[#params + 1] = key(value.name)

        if demoted then
            jobs = ('JSON_SET(%s, ?, JSON_OBJECT(\'grade\', ?, \'since\', UNIX_TIMESTAMP()))'):format(jobs)
            params[#params + 1] = key(demoted.name)
            params[#params + 1] = demoted.grade
        end

        secondJobs = (', second_jobs = %s'):format(jobs)
    end

    MySQL.insert.await(
        ('INSERT INTO management_members (citizenid, %s, %s_since) VALUES (?, ?, NOW()) ON DUPLICATE KEY UPDATE %s = VALUES(%s), %s%s')
            :format(name, name, name, name, since, secondJobs),
        params
    )
end

---@param gangName string
---@param value table
function db.resetGang(gangName, value)
    MySQL.update.await('UPDATE management_members SET gang = ?, gang_since = NULL WHERE gang_name = ?', { json.encode(value), gangName })
end

---@param citizenid string
---@param jobName string
function db.clockIn(citizenid, jobName)
    MySQL.insert.await([[
        INSERT INTO management_duty (citizenid, job_name)
        SELECT ?, ? FROM DUAL
        WHERE NOT EXISTS (SELECT 1 FROM management_duty WHERE citizenid = ? AND job_name = ? AND clock_out IS NULL)
    ]], { citizenid, jobName, citizenid, jobName })
end

---@param citizenid string
---@param jobName? string
function db.clockOut(citizenid, jobName)
    MySQL.update.await(([[
        UPDATE management_duty SET clock_out = NOW(), minutes = TIMESTAMPDIFF(MINUTE, clock_in, NOW())
        WHERE citizenid = ? AND clock_out IS NULL %s
    ]]):format(jobName and 'AND job_name = ?' or ''), { citizenid, jobName })
end

function db.tickShifts()
    MySQL.update.await('UPDATE management_duty SET minutes = TIMESTAMPDIFF(MINUTE, clock_in, NOW()) WHERE clock_out IS NULL')
end

---@param graceMinutes integer minutes past the last tick a shift may run, never past now
---@return integer closed
function db.closeOpenShifts(graceMinutes)
    return MySQL.update.await([[
        UPDATE management_duty
        SET clock_out = LEAST(NOW(), clock_in + INTERVAL (COALESCE(minutes, 0) + ?) MINUTE),
            minutes = LEAST(TIMESTAMPDIFF(MINUTE, clock_in, NOW()), COALESCE(minutes, 0) + ?)
        WHERE clock_out IS NULL
    ]], { graceMinutes, graceMinutes }) or 0
end

---@class DutySummary
---@field week integer
---@field lastWeek integer
---@field shiftStartedAt? string

---@param jobName string
---@param days integer
---@return table<string, DutySummary>
function db.dutySummary(jobName, days)
    local rows <const> = MySQL.query.await([[
        SELECT citizenid,
            CAST(SUM(CASE WHEN clock_in >= NOW() - INTERVAL ? DAY THEN IF(clock_out IS NULL, TIMESTAMPDIFF(MINUTE, clock_in, NOW()), minutes) ELSE 0 END) AS SIGNED) AS week,
            CAST(SUM(CASE WHEN clock_in < NOW() - INTERVAL ? DAY THEN COALESCE(minutes, 0) ELSE 0 END) AS SIGNED) AS lastWeek,
            DATE_FORMAT(CONVERT_TZ(MAX(CASE WHEN clock_out IS NULL THEN clock_in END), @@session.time_zone, '+00:00'), '%Y-%m-%dT%TZ') AS shiftStartedAt
        FROM management_duty
        WHERE job_name = ? AND clock_in >= NOW() - INTERVAL ? DAY
        GROUP BY citizenid
    ]], { days, days, jobName, days * 2 }) or {}

    local out <const> = {}

    for _, row in ipairs(rows) do
        out[row.citizenid] = { week = row.week or 0, lastWeek = row.lastWeek or 0, shiftStartedAt = row.shiftStartedAt }
    end

    return out
end

---@param citizenids string[]
---@param jobName string
---@param days integer
---@return table<string, integer> minutes by citizenid, 0 for each one without shifts
function db.dutyMinutes(citizenids, jobName, days)
    local out <const> = {}

    for _, citizenid in ipairs(citizenids) do out[citizenid] = 0 end

    if #citizenids == 0 then return out end

    local rows <const> = MySQL.query.await([[
        SELECT citizenid, CAST(SUM(IF(clock_out IS NULL, TIMESTAMPDIFF(MINUTE, clock_in, NOW()), minutes)) AS SIGNED) AS minutes
        FROM management_duty
        WHERE citizenid IN (?) AND job_name = ? AND clock_in >= NOW() - INTERVAL ? DAY
        GROUP BY citizenid
    ]], { citizenids, jobName, days }) or {}

    for _, row in ipairs(rows) do out[row.citizenid] = tonumber(row.minutes) or 0 end

    return out
end

---@class ApplicantRow
---@field job? table
---@field phone? string
---@field workedHere boolean

---@param citizenids string[]
---@param jobName string
---@return table<string, ApplicantRow>
function db.applicants(citizenids, jobName)
    local out <const> = {}

    if #citizenids == 0 then return out end

    local rows <const> = MySQL.query.await([[
        SELECT p.citizenid, p.phone_number, m.job,
            EXISTS (SELECT 1 FROM management_duty d WHERE d.citizenid = p.citizenid AND d.job_name = ?) AS workedHere
        FROM players p
        LEFT JOIN management_members m ON m.citizenid = p.citizenid
        WHERE p.citizenid IN (?)
    ]], { jobName, citizenids }) or {}

    for _, row in ipairs(rows) do
        out[row.citizenid] = {
            job = decode(row.job),
            phone = row.phone_number,
            workedHere = row.workedHere == 1,
        }
    end

    return out
end

---@param request StoredRequest
---@param orgName string
---@return RequestRow
local function requestRow(request, orgName)
    return {
        id = request.id,
        kind = request.kind,
        citizenid = request.citizenid,
        player_name = request.name,
        org_name = orgName,
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

---@param orgName string
---@param keep? fun(request: StoredRequest): boolean
---@param stored? table<string, StoredRequest>
---@return RequestRow[]
local function findRequests(orgName, keep, stored)
    local now <const> = os.time()
    local found <const> = {}

    for _, request in pairs(stored or orgColumn(orgName, 'requests') or {}) do
        if current(request, now) and (not keep or keep(request)) then found[#found + 1] = request end
    end

    table.sort(found, function(a, b) return a.id > b.id end)

    local out <const> = {}

    for index, request in ipairs(found) do out[index] = requestRow(request, orgName) end

    return out
end

---@alias RequestRefusal 'inbox_full' | 'too_many_open'

---@param request { kind: 'application' | 'leave' | 'report', citizenid: string, name: string, org: string, title?: string, message: string, startDate?: string, endDate?: string }
---@return boolean created
---@return RequestRefusal? refusal
function db.createRequest(request)
    MySQL.insert.await(ENSURE_ORG, { request.org })

    local refusal

    local created <const> = MySQL.startTransaction(function(query)
        local row <const> = query('SELECT seq, requests FROM management_orgs WHERE name = ? FOR UPDATE', { request.org })[1]
        local now <const> = os.time()
        local kept <const> = {}
        local open, mine = 0, 0

        for id, stored in pairs(decode(row.requests) or {}) do
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

        query('UPDATE management_orgs SET seq = ?, requests = ? WHERE name = ?', { id, json.encode(kept), request.org })
    end) == true

    return created, refusal
end

---@param orgName string
---@param stored? table<string, StoredRequest>
---@return RequestRow[]
function db.requests(orgName, stored)
    return findRequests(orgName, nil, stored)
end

---@param citizenid string
---@param orgName string
---@param stored? table<string, StoredRequest>
---@return RequestRow[]
function db.requestsBy(citizenid, orgName, stored)
    local rows <const> = findRequests(orgName, function(request) return request.citizenid == citizenid end, stored)

    for index = #rows, 21, -1 do rows[index] = nil end

    return rows
end

---@param id integer
---@param orgName string
---@return RequestRow?
function db.request(id, orgName)
    local stored <const> = decode(MySQL.scalar.await(
        'SELECT JSON_EXTRACT(requests, ?) FROM management_orgs WHERE name = ?',
        { key(tostring(math.tointeger(id))), orgName }
    ))

    return stored and requestRow(stored --[[@as StoredRequest]], orgName) or nil
end

---@param citizenid string
---@param orgName string
---@return RequestRow?
function db.openApplication(citizenid, orgName)
    return findRequests(orgName, function(request)
        return request.citizenid == citizenid and request.kind == 'application' and request.status == 'open'
    end)[1]
end

---@param citizenids string[]
---@param orgName string
---@return table<string, string> appliedAt by citizenid
function db.openApplicationsFor(citizenids, orgName)
    local wanted <const> = {}

    for _, citizenid in ipairs(citizenids) do wanted[citizenid] = true end

    local out <const> = {}
    local open <const> = findRequests(orgName, function(request)
        return request.kind == 'application' and request.status == 'open' and wanted[request.citizenid] == true
    end)

    for _, row in ipairs(open) do
        if not out[row.citizenid] then out[row.citizenid] = row.created_at end
    end

    return out
end

---@param id integer
---@param orgName string
---@param status 'open' | 'approved' | 'declined'
---@param reviewer? string
---@param from? 'open' | 'approved' | 'declined'
---@return boolean
function db.answerRequest(id, orgName, status, reviewer, from)
    local path <const> = key(tostring(math.tointeger(id)))

    return MySQL.update.await([[
        UPDATE management_orgs SET requests = JSON_SET(requests, CONCAT(?, '.status'), ?, CONCAT(?, '.reviewedBy'), ?, CONCAT(?, '.reviewedAt'), ?)
        WHERE name = ? AND JSON_VALUE(requests, CONCAT(?, '.status')) = ?
    ]], {
        path, status, path, reviewer, path, reviewer and os.time() or nil,
        orgName, path, from or 'open',
    }) == 1
end

---@param orgName string
---@param stored? table<string, StoredRequest>
---@return table<string, true>
function db.onLeave(orgName, stored)
    local today <const> = os.date('!%Y-%m-%d')
    local out <const> = {}

    for _, request in pairs(stored or orgColumn(orgName, 'requests') or {}) do
        local active <const> = request.kind == 'leave' and request.status == 'approved' and request.citizenid
            and request.startDate and request.endDate and request.startDate <= today and today <= request.endDate

        if active then out[request.citizenid] = true end
    end

    return out
end

---@param bonus { citizenid: string, name: string, org: string, amount: integer, reason: string, by: string }
function db.addBonus(bonus)
    local entry <const> = { at = os.time(), citizenid = bonus.citizenid, name = bonus.name, amount = bonus.amount, reason = bonus.reason, by = bonus.by }

    MySQL.insert.await(ENSURE_ORG, { bonus.org })
    MySQL.update.await(PUSH_BONUS, { LIMITS.bonuses, json.encode(entry), bonus.org })
end

---@param orgName string
---@param stored? table[]
---@return table<string, integer> month bonuses by citizenid
---@return integer week total
function db.bonusSummary(orgName, stored)
    local now <const> = os.time()
    local byCitizen <const>, week = {}, 0

    for _, bonus in ipairs(stored or orgColumn(orgName, 'bonuses') or {}) do
        local age <const> = now - (bonus.at or 0)
        local amount <const> = math.floor(tonumber(bonus.amount) or 0)

        if age <= 30 * DAY and bonus.citizenid then byCitizen[bonus.citizenid] = (byCitizen[bonus.citizenid] or 0) + amount end
        if age <= 7 * DAY then week += amount end
    end

    return byCitizen, week
end

---@param vehicle { plate: string, org: string, model: string, label: string, price: integer, by: string }
---@return boolean
function db.addVehicle(vehicle)
    local path <const> = key(vehicle.plate)
    local entry <const> = {
        plate = vehicle.plate,
        model = vehicle.model,
        label = vehicle.label,
        price = vehicle.price,
        boughtBy = vehicle.by,
        boughtAt = os.time(),
    }

    MySQL.insert.await(ENSURE_ORG, { vehicle.org })

    return MySQL.update.await([[
        UPDATE management_orgs SET fleet = JSON_SET(COALESCE(fleet, JSON_OBJECT()), ?, JSON_EXTRACT(?, '$'))
        WHERE name = ? AND JSON_LENGTH(COALESCE(fleet, JSON_OBJECT())) < ? AND NOT JSON_CONTAINS_PATH(COALESCE(fleet, JSON_OBJECT()), 'one', ?)
    ]], { path, json.encode(entry), vehicle.org, LIMITS.fleet, path }) == 1
end

---@param orgName string
---@param plate string
function db.removeVehicle(orgName, plate)
    MySQL.update.await('UPDATE management_orgs SET fleet = JSON_REMOVE(fleet, ?) WHERE name = ?', { key(plate), orgName })
end

---@return table<string, true> plates every org's fleet uses
function db.fleetPlates()
    local out <const> = {}

    for _, row in ipairs(MySQL.query.await('SELECT JSON_KEYS(fleet) AS plates FROM management_orgs WHERE fleet IS NOT NULL') or {}) do
        for _, plate in ipairs(decode(row.plates) or {}) do out[plate] = true end
    end

    return out
end

---@param orgName string
---@return { plate: string, model: string, label: string, boughtBy: string, boughtAt: string }[]
function db.fleet(orgName)
    local vehicles <const> = {}

    for _, vehicle in pairs(orgColumn(orgName, 'fleet') or {}) do vehicles[#vehicles + 1] = vehicle end

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

---@param announcement { org: string, author: string, title: string, message: string }
function db.addAnnouncement(announcement)
    local entry <const> = { at = os.time(), author = announcement.author, title = announcement.title, message = announcement.message }

    MySQL.insert.await(ENSURE_ORG, { announcement.org })
    MySQL.update.await(PUSH_ANNOUNCEMENT, { LIMITS.announcements, json.encode(entry), announcement.org })
end

---@param orgName string
---@return { id: integer, title: string, message: string, author: string, createdAt: string }[]
function db.announcements(orgName)
    local stored <const> = orgColumn(orgName, 'announcements') or {}
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
    local rows <const> = MySQL.query.await('SELECT name, settings FROM management_orgs WHERE settings IS NOT NULL ORDER BY name') or {}

    for _, row in ipairs(rows) do row.settings = decode(row.settings) or {} end

    return rows
end

---@param orgName string
---@param settings { logoUrl?: string, features: table, pay: table, permissions: table }
---@param by string
function db.saveSettings(orgName, settings, by)
    local stored <const> = {
        logoUrl = settings.logoUrl,
        features = settings.features,
        pay = settings.pay,
        permissions = settings.permissions,
        updatedBy = by,
    }

    MySQL.insert.await(
        'INSERT INTO management_orgs (name, settings) VALUES (?, ?) ON DUPLICATE KEY UPDATE settings = VALUES(settings)',
        { orgName, json.encode(stored) }
    )
end

---@param citizenid string
---@return { job_name: string, grade: integer, since: string }[]
function db.secondJobs(citizenid)
    local jobs <const> = decode(MySQL.scalar.await('SELECT second_jobs FROM management_members WHERE citizenid = ?', { citizenid })) or {}
    local names <const> = {}

    for name in pairs(jobs) do names[#names + 1] = name end

    table.sort(names, function(a, b) return (tonumber(jobs[a].since) or 0) < (tonumber(jobs[b].since) or 0) end)

    local out <const> = {}

    for index, name in ipairs(names) do
        out[index] = { job_name = name, grade = math.floor(tonumber(jobs[name].grade) or 0), since = Util.iso(tonumber(jobs[name].since)) }
    end

    return out
end

---@param citizenid string
---@param jobName string
---@return { job_name: string, grade: integer, since: string }?
function db.secondJob(citizenid, jobName)
    for _, job in ipairs(db.secondJobs(citizenid)) do
        if job.job_name == jobName then return job end
    end
end

---@param jobName string
---@return { citizenid: string, name?: string, grade: integer, since?: string }[]
function db.secondJobHolders(jobName)
    local path <const> = key(jobName)
    local rows <const> = MySQL.query.await([[
        SELECT m.citizenid, p.fullname AS name,
            CAST(JSON_VALUE(m.second_jobs, CONCAT(?, '.grade')) AS SIGNED) AS grade,
            CAST(JSON_VALUE(m.second_jobs, CONCAT(?, '.since')) AS UNSIGNED) AS since
        FROM management_members m
        LEFT JOIN players p ON p.citizenid = m.citizenid
        WHERE JSON_CONTAINS_PATH(m.second_jobs, 'one', ?)
        ORDER BY since
        LIMIT 500
    ]], { path, path, path }) or {}
    local out <const> = {}

    for index, row in ipairs(rows) do
        out[index] = { citizenid = row.citizenid, name = row.name, grade = row.grade, since = Util.iso(row.since) }
    end

    return out
end

---@param citizenid string
---@param jobName string
---@param grade integer
---@return boolean added false when the character already holds the most second jobs
function db.addSecondJob(citizenid, jobName, grade)
    local path <const> = key(jobName)

    MySQL.update.await([[
        INSERT INTO management_members (citizenid, second_jobs) VALUES (?, JSON_OBJECT(?, JSON_OBJECT('grade', ?, 'since', UNIX_TIMESTAMP())))
        ON DUPLICATE KEY UPDATE second_jobs = IF(
            JSON_LENGTH(COALESCE(second_jobs, JSON_OBJECT())) >= ? AND NOT JSON_CONTAINS_PATH(COALESCE(second_jobs, JSON_OBJECT()), 'one', ?),
            second_jobs,
            JSON_SET(COALESCE(second_jobs, JSON_OBJECT()), ?, JSON_OBJECT('grade', ?, 'since', COALESCE(CAST(JSON_VALUE(second_jobs, CONCAT(?, '.since')) AS UNSIGNED), UNIX_TIMESTAMP())))
        )
    ]], { citizenid, jobName, grade, LIMITS.secondJobs, path, path, grade, path })

    return db.secondJob(citizenid, jobName)?.grade == grade
end

---@param citizenid string
---@param jobName string
---@return boolean
function db.removeSecondJob(citizenid, jobName)
    local path <const> = key(jobName)

    return MySQL.update.await(
        "UPDATE management_members SET second_jobs = JSON_REMOVE(second_jobs, ?) WHERE citizenid = ? AND JSON_CONTAINS_PATH(second_jobs, 'one', ?)",
        { path, citizenid, path }
    ) == 1
end

---@param row { name: string, gang: unknown }
---@return GangRecord?
local function gangRecord(row)
    local stored <const> = decode(row.gang)

    if not stored then return end

    local hq <const> = type(stored.hq) == 'table' and stored.hq or nil

    return {
        name = row.name,
        label = stored.label or row.name,
        archetype = stored.archetype or 'street',
        founderCid = stored.founderCid,
        homeTurf = stored.homeTurf,
        hq = hq,
        blipColor = math.floor(tonumber(stored.blipColor) or 27),
        permissions = type(stored.permissions) == 'table' and stored.permissions or nil,
        foundedAt = math.floor(tonumber(stored.foundedAt) or os.time()),
        turfMovedAt = tonumber(stored.turfMovedAt) and math.floor(stored.turfMovedAt),
        hqMovedAt = tonumber(stored.hqMovedAt) and math.floor(stored.hqMovedAt),
        archetypeChangedAt = tonumber(stored.archetypeChangedAt) and math.floor(stored.archetypeChangedAt),
    }
end

---@param gang GangRecord
---@return string
local function encodeGang(gang)
    return json.encode({
        label = gang.label,
        archetype = gang.archetype,
        founderCid = gang.founderCid,
        homeTurf = gang.homeTurf,
        hq = gang.hq,
        blipColor = gang.blipColor,
        permissions = gang.permissions,
        foundedAt = gang.foundedAt,
        turfMovedAt = gang.turfMovedAt,
        hqMovedAt = gang.hqMovedAt,
        archetypeChangedAt = gang.archetypeChangedAt,
    })
end

---@return GangRecord[]
function db.gangs()
    local out <const> = {}

    for _, row in ipairs(MySQL.query.await('SELECT name, gang FROM management_orgs WHERE gang IS NOT NULL ORDER BY name') or {}) do
        out[#out + 1] = gangRecord(row)
    end

    return out
end

---@param gang GangRecord
---@return boolean
function db.insertGang(gang)
    MySQL.insert.await(ENSURE_ORG, { gang.name })

    return MySQL.update.await('UPDATE management_orgs SET gang = ? WHERE name = ? AND gang IS NULL', { encodeGang(gang), gang.name }) == 1
end

---@param gang GangRecord
---@param regrades? table<string, table> new gang snapshot by citizenid, written in the same transaction
---@param debit? VaultDebit taken from the vault in the same transaction
---@return boolean
function db.saveGang(gang, regrades, debit)
    if not regrades and not debit then
        MySQL.update.await('UPDATE management_orgs SET gang = ? WHERE name = ?', { encodeGang(gang), gang.name })

        return true
    end

    return MySQL.startTransaction(function(query)
        if debit then
            local entry <const> = json.encode({ at = os.time(), what = debit.what, who = debit.who, amount = -debit.amount })
            local result <const> = query(DEBIT_VAULT, { debit.amount, LIMITS.vaultLog, entry, gang.name, debit.amount })

            if result.affectedRows ~= 1 then return false end
        end

        query('UPDATE management_orgs SET gang = ? WHERE name = ?', { encodeGang(gang), gang.name })

        for citizenid, snapshot in pairs(regrades or {}) do
            query('UPDATE management_members SET gang = ? WHERE citizenid = ?', { json.encode(snapshot), citizenid })
        end
    end) == true
end

---@param name string
function db.deleteGang(name)
    MySQL.update.await('DELETE FROM management_orgs WHERE name = ?', { name })
end

---@param gangName string
---@return integer
function db.vaultBalance(gangName)
    return MySQL.scalar.await('SELECT vault_balance FROM management_orgs WHERE name = ?', { gangName }) or 0
end

---@param gangName string
---@param amount integer
---@param what string
---@param who string
---@return boolean debited
function db.debitVault(gangName, amount, what, who)
    local entry <const> = json.encode({ at = os.time(), what = what, who = who, amount = -amount })

    return MySQL.update.await(DEBIT_VAULT, { amount, LIMITS.vaultLog, entry, gangName, amount }) == 1
end

---@param gangName string
---@param amount integer
---@param cap integer
---@param what string
---@param who string
---@return integer credited
function db.creditVault(gangName, amount, cap, what, who)
    local credited = 0

    local committed <const> = MySQL.startTransaction(function(query)
        local row <const> = query('SELECT vault_balance FROM management_orgs WHERE name = ? FOR UPDATE', { gangName })[1]

        if not row then return false end

        credited = math.max(0, math.min(amount, cap - row.vault_balance))

        if credited == 0 then return false end

        local entry <const> = json.encode({ at = os.time(), what = what, who = who, amount = credited })

        query(CREDIT_VAULT, { credited, LIMITS.vaultLog, entry, gangName })
    end)

    return committed and credited or 0
end

---@param gangName string
---@return { id: integer, at: string, what: string, who: string, amount: integer }[]
function db.vaultLog(gangName)
    local stored <const> = orgColumn(gangName, 'vault_log') or {}
    local out <const> = {}

    for index = #stored, 1, -1 do
        local entry <const> = stored[index]

        out[#out + 1] = { id = entry.id, at = Util.iso(entry.at) --[[@as string]], what = entry.what, who = entry.who, amount = entry.amount }
    end

    return out
end

return db
