local config <const> = require 'config.server'
local db <const> = require 'server.jobs.db'
local Jobs <const> = require 'server.jobs.registry'
local Members <const> = require 'server.members'
local Staff <const> = require 'server.jobs.staff'
local Society <const> = require 'server.jobs.society'
local Requests <const> = require 'server.jobs.requests'
local Vehicles <const> = require 'server.jobs.vehicles'
local SecondJobs <const> = require 'server.jobs.secondjobs'
local Util <const> = require 'server.util'

---@class Access
---@field overview boolean
---@field employees boolean
---@field bonus boolean
---@field manageStaff boolean
---@field requests boolean
---@field society boolean
---@field vehicles boolean
---@field announce boolean
---@field ranks boolean
---@field settings boolean

local Menu <const> = {}

local LOGO_HOSTS <const> = config.logoHosts

---@param url unknown
---@return boolean
local function logoAllowed(url)
    if type(url) ~= 'string' or #url > 512 then return false end

    local host <const>, rest <const> = url:match('^https://([%w%.%-]+)(.*)$')

    if not host or (rest ~= '' and not rest:find('^[/?#]')) then return false end

    return lib.table.contains(LOGO_HOSTS, host:lower())
end

---@param jobName string
---@return string?
local function logoOf(jobName)
    local url <const> = Jobs.settings(jobName).logoUrl

    return logoAllowed(url) and url or nil
end

---@param actor Actor
---@return Access
local function accessOf(actor)
    local can <const> = actor.permissions
    local open <const> = can.open_menu == true
    local features <const> = Jobs.features(actor.job.name)
    local society <const> = open and can.society == true and features.society

    return {
        overview = open and can.view_dashboard == true,
        employees = open and can.view_dashboard == true,
        bonus = open and can.give_bonus == true and features.society,
        manageStaff = actor.isBoss,
        requests = actor.isBoss and (features.applications or features.leaves or features.reports),
        society = society,
        vehicles = society and features.vehicles,
        announce = actor.isBoss and features.announcements,
        ranks = actor.isBoss,
        settings = actor.isBoss,
    }
end

---@param roster Employee[]
---@return string[]
local function bossNames(roster)
    local out <const> = {}

    for _, employee in ipairs(roster) do
        if employee.isBoss then out[#out + 1] = employee.name end
    end

    return out
end

---@param actor Actor
---@return table
function Menu.session(actor)
    local jobName <const> = actor.job.name
    local access <const> = accessOf(actor)
    local features <const> = Jobs.features(jobName)
    local data <const> = db.data(jobName)
    local roster <const> = Staff.roster(jobName, { data = data })
    local me

    for _, employee in ipairs(roster) do
        if employee.citizenid == actor.citizenid then me = employee end
    end

    local people <const>, onDuty, weekMinutes = {}, 0, 0

    for _, employee in ipairs(roster) do
        people[employee.grade] = (people[employee.grade] or 0) + 1
        weekMinutes += employee.weekMinutes

        if employee.onDuty then onDuty += 1 end
    end

    local ranks <const>, payroll = {}, 0

    for _, grade in ipairs(Jobs.grades(jobName)) do
        local permissions <const> = {}

        for permission in pairs(Jobs.rankPermissions(jobName, grade.grade)) do permissions[#permissions + 1] = permission end

        ranks[#ranks + 1] = {
            grade = grade.grade,
            name = grade.name,
            pay = grade.pay,
            isBoss = grade.isBoss,
            people = people[grade.grade] or 0,
            permissions = permissions,
        }
        payroll += grade.pay * (people[grade.grade] or 0)
    end

    local fleet <const> = features.vehicles and Vehicles.fleet(jobName) or {}
    local nextPayday <const> = Society.nextPayday()
    local monthBonuses <const>, weekBonuses <const> = db.bonusSummary(jobName, data.bonuses)
    local employees <const> = access.employees and table.move(roster, 1, #roster, 1, {}) or nil

    if employees and features.secondJobs then
        for _, holder in ipairs(Staff.secondJobHolders(jobName, monthBonuses)) do employees[#employees + 1] = holder end
    end

    return {
        mode = 'job',
        now = Util.iso(os.time()),
        job = {
            name = jobName,
            label = actor.job.label,
            type = actor.job.type,
            typeLabel = Jobs.typeLabel(jobName),
            logoUrl = logoOf(jobName),
        },
        me = {
            citizenid = actor.citizenid,
            name = actor.name,
            grade = actor.grade,
            rank = me?.rank or '',
            pay = me?.pay or 0,
            isBoss = actor.isBoss,
            onDuty = Members.job(actor.source)?.onduty == true,
            shiftStartedAt = me and me.shiftStartedAt,
            joinedAt = me and me.joinedAt,
            weekMinutes = me?.weekMinutes or 0,
            monthBonuses = me?.monthBonuses or 0,
        },
        access = access,
        features = features,
        bosses = bossNames(roster),
        ranks = ranks,
        stats = access.overview and {
            total = #roster,
            onDuty = onDuty,
            weekMinutes = weekMinutes,
            weekBonuses = weekBonuses,
            fleet = #fleet,
        } or nil,
        employees = employees,
        requests = access.requests and Requests.list(jobName, data) or nil,
        society = (access.society or access.overview) and features.society and {
            accountId = Society.accountId(jobName),
            balance = Society.balance(jobName),
            payroll = payroll,
            nextPaydayAt = Util.iso(nextPayday),
            transactions = access.society and Society.history(jobName, actor.citizenid, 50) or {},
        } or nil,
        vehicles = access.vehicles and {
            catalogue = Vehicles.catalogue(jobName),
            fleet = fleet,
        } or nil,
        announcements = features.announcements and db.announcements(jobName) or {},
        myRequests = Requests.mine(actor.citizenid, jobName, data),
        myJobs = features.secondJobs and SecondJobs.list(actor.source) or {},
        hireRadius = config.hireRadius,
        logoHosts = LOGO_HOSTS,
        limits = {
            bonus = config.limits.bonus,
            message = config.limits.message,
            title = config.limits.title,
            reason = config.limits.reason,
        },
    }
end

---@alias JobHandler fun(actor: Actor, data: table): boolean?, string?

---@type table<string, JobHandler>
local handlers <const> = {}

---@param name string
---@param requirement? fun(access: Access, actor: Actor): boolean
---@param run JobHandler
local function handle(name, requirement, run)
    handlers[name] = function(actor, data)
        if requirement and not requirement(accessOf(actor), actor) then
            return false, locale('job.rank_cannot')
        end

        return run(actor, data)
    end
end

handle('setDuty', nil, function(actor, data)
    if not Jobs.feature(actor.job.name, 'duty') then
        return false, locale('job.duty_off')
    end

    return Members.setDuty(actor.source, data.onDuty == true)
end)

handle('hire', function(access) return access.manageStaff end, function(actor, data)
    local citizenid <const> = Util.text(data.citizenid, 50)
    local grade <const> = Util.integer(data.grade, 0, actor.job.topGrade)

    if not citizenid or not grade then
        return false, locale('job.pick_person_rank')
    end

    local target <const> = Members.sourceOf(citizenid:upper())

    if not target or Util.distance(actor.source, target) > config.hireRadius then
        return false, locale('job.hire_too_far')
    end

    return Staff.offer(actor, target, grade, data.asSecondJob == true)
end)

handle('fire', function(access) return access.manageStaff end, function(actor, data)
    local citizenid <const> = Util.text(data.citizenid, 50)

    if not citizenid then
        return false, locale('job.pick_fire')
    end

    return Staff.fireBy(actor, citizenid, Util.text(data.reason, config.limits.reason))
end)

handle('setGrade', function(access) return access.manageStaff end, function(actor, data)
    local citizenid <const> = Util.text(data.citizenid, 50)
    local grade <const> = Util.integer(data.grade, 0, actor.job.topGrade)

    if not citizenid or not grade then
        return false, locale('common.pick_rank')
    end

    return Staff.setGradeBy(actor, citizenid, grade)
end)

handle('giveBonus', function(access) return access.bonus end, function(actor, data)
    local citizenid <const> = Util.text(data.citizenid, 50)
    local amount <const> = Util.integer(data.amount, 1, config.limits.bonus)

    if not citizenid or not amount then
        return false, locale('job.bonus_range', Util.money(config.limits.bonus))
    end

    return Staff.bonus(actor, citizenid, amount, Util.text(data.reason, config.limits.reason))
end)

handle('answerRequest', function(access) return access.requests end, function(actor, data)
    local id <const> = Util.integer(data.id, 1, math.maxinteger)

    if not id then
        return false, locale('job.pick_request')
    end

    local grade <const> = data.grade ~= nil and Util.integer(data.grade, 0, actor.job.topGrade) or nil

    return Requests.answer(actor, id, data.approve == true, grade)
end)

---@param direction 'deposit' | 'withdraw'
---@return JobHandler
local function moveFunds(direction)
    local depositing <const> = direction == 'deposit'
    local action <const> = depositing and 'Deposit' or 'Withdrawal'
    local labelKey <const> = depositing and 'society.deposit' or 'society.withdrawal'
    local move <const> = depositing and Society.collect or Society.pay

    return function(actor, data)
        local amount <const> = Util.integer(data.amount, 1, 100000000)

        if not amount then
            return false, locale('common.enter_amount')
        end

        local note <const> = Util.text(data.note, 120)
        local label <const> = locale(labelKey)
        local description <const> = note and locale('society.with_note', label, note) or label
        local ok <const>, err <const> = move(actor.job.name, actor.citizenid, amount, description, actor.citizenid)

        if not ok then return false, err --[[@as string?]] end

        Util.log(actor.job.name, action, ('%s, %s by %s'):format(Util.money(amount), note or 'no note', actor.name))

        return true
    end
end

handle('deposit', function(access) return access.society end, moveFunds('deposit'))
handle('withdraw', function(access) return access.society end, moveFunds('withdraw'))

handle('saveRank', function(access) return access.ranks end, function(actor, data)
    local grade <const> = Util.integer(data.grade, 0, actor.job.topGrade)
    local pay <const> = Util.integer(data.pay, 0, 1000000)

    if not grade or not pay or not Jobs.grade(actor.job.name, grade) then
        return false, locale('job.pay_whole')
    end

    local settings <const> = Jobs.settings(actor.job.name)

    settings.pay[tostring(grade)] = pay
    settings.permissions[tostring(grade)] = Jobs.cleanPermissions(data.permissions)
    Jobs.saveSettings(actor.job.name, actor.name)
    Members.refreshPay(actor.job.name, grade)
    Util.log(actor.job.name, 'Rank', ('%s set grade %d to %s per payday'):format(actor.name, grade, Util.money(pay)))

    return true
end)

handle('buyVehicle', function(access) return access.vehicles end, function(actor, data)
    return Vehicles.buy(actor, data.model)
end)

handle('postAnnouncement', function(access) return access.announce end, function(actor, data)
    local title <const> = Util.text(data.title, config.limits.title)
    local message <const> = Util.text(data.message, config.limits.message)

    if not title or not message then
        return false, locale('common.title_and_message')
    end

    db.addAnnouncement({ job = actor.job.name, author = actor.name, title = title, message = message })

    for _, source in ipairs(Members.sourcesIn(actor.job.name)) do
        if source ~= actor.source and Members.job(source)?.name == actor.job.name then
            Util.notify(source, locale('job.announcement', actor.job.label, title), 'info')
        end
    end

    return true
end)

handle('saveLogo', function(access) return access.settings end, function(actor, data)
    local raw <const> = type(data.url) == 'string' and data.url or ''
    local url <const> = #raw <= 1024 and Util.trim(raw) or raw

    if url ~= '' and not logoAllowed(url) then
        if #LOGO_HOSTS == 0 then return false, locale('job.logos_off') end

        return false, locale('job.logo_host', table.concat(LOGO_HOSTS, ', '))
    end

    Jobs.settings(actor.job.name).logoUrl = url ~= '' and url or nil
    Jobs.saveSettings(actor.job.name, actor.name)

    return true
end)

handle('setFeature', function(access) return access.settings end, function(actor, data)
    if config.features[data.feature] == nil then
        return false, locale('job.unknown_feature')
    end

    Jobs.settings(actor.job.name).features[data.feature] = data.enabled == true
    Jobs.saveSettings(actor.job.name, actor.name)

    return true
end)

handle('sendLeave', nil, function(actor, data)
    return Requests.leave(actor, data.from, data['until'], data.reason)
end)

handle('sendReport', nil, function(actor, data)
    return Requests.report(actor, data.title, data.message)
end)

---Requests about the player's own second jobs, which work even while their main job is unemployed
---@type table<string, fun(source: integer, jobName: string): boolean, string?>
local personal <const> = {
    makeMainJob = SecondJobs.makeMain,
    leaveJob = SecondJobs.leave,
}

---@param source integer
---@param name string
---@param data table
---@return table
function Menu.request(source, name, data)
    local own <const> = personal[name]

    if own then
        if type(data?.name) ~= 'string' or not Jobs.get(data.name) then
            return { ok = false, error = locale('job.pick_job') }
        end

        local ok <const>, err <const> = own(source, data.name)

        if not ok then
            return { ok = false, error = err or locale('common.failed') }
        end

        local after <const> = Staff.actor(source)

        return { ok = true, session = after and Menu.session(after) or nil }
    end

    local run <const> = handlers[name]
    local actor <const> = Staff.actor(source)

    if not run or not actor then
        return { ok = false, error = locale('job.not_staff') }
    end

    local ok <const>, err <const> = run(actor, data)

    if not ok then
        return { ok = false, error = err or locale('common.failed') }
    end

    local after <const> = Staff.actor(source)

    if not after then
        return { ok = false, error = locale('job.no_longer_staff') }
    end

    return { ok = true, session = Menu.session(after) }
end

---@param source integer
---@param radius number
---@return table[]
function Menu.nearby(source, radius)
    local actor <const> = Staff.actor(source)

    if not actor or not accessOf(actor).manageStaff then return {} end

    local found <const>, citizenids <const> = {}, {}

    for other, entry in pairs(Members.online()) do
        if other ~= source then
            local distance <const> = Util.distance(source, other)

            if distance <= radius then
                local job <const> = entry.job.name ~= Members.UNEMPLOYED and entry.job.label or nil

                found[#found + 1] = {
                    serverId = other,
                    citizenid = entry.citizenid,
                    name = Members.name(other),
                    distance = math.floor(distance * 10 + 0.5) / 10,
                    job = job,
                }
                citizenids[#citizenids + 1] = entry.citizenid
            end
        end
    end

    local applied <const> = db.openApplicationsFor(citizenids, actor.job.name)

    for _, player in ipairs(found) do player.appliedAt = applied[player.citizenid] end

    table.sort(found, function(a, b) return a.distance < b.distance end)

    return found
end

---@param source integer
---@param jobName string
---@return table? session
---@return string? error
function Menu.applySession(source, jobName)
    local job <const> = Jobs.get(jobName)
    local citizenid <const> = Members.citizenid(source)

    if not job or not citizenid then
        return nil, locale('apply.not_taken')
    end

    if not Jobs.feature(jobName, 'applications') then
        return nil, locale('apply.closed', job.label)
    end

    if Members.job(source)?.name == jobName then
        return nil, locale('common.already_staff')
    end

    local roster <const> = Staff.roster(jobName, { summary = true })
    local start <const> = Jobs.grade(jobName, 0)

    return {
        mode = 'apply',
        now = Util.iso(os.time()),
        job = {
            name = jobName,
            label = job.label,
            type = job.type,
            typeLabel = Jobs.typeLabel(jobName),
            logoUrl = logoOf(jobName),
        },
        reviewers = bossNames(roster),
        startingRank = start?.name or '',
        startingPay = start?.pay or 0,
        staff = #roster,
        maxLength = config.limits.message,
        pending = Requests.pendingApplication(citizenid, jobName),
    }
end

---@param source integer
---@param jobName string
---@param message unknown
---@return table
function Menu.apply(source, jobName, message)
    local ok <const>, err <const> = Requests.apply(source, jobName, message)

    if not ok then return { ok = false, error = err } end

    return { ok = true, session = Menu.applySession(source, jobName) }
end

return Menu
