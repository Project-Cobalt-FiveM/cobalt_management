local config <const> = require 'config.server'
local db <const> = require 'server.jobs.db'

---@alias JobFeature 'society' | 'applications' | 'leaves' | 'reports' | 'vehicles' | 'announcements' | 'duty' | 'secondJobs'
---@alias RankPermission 'open_menu' | 'view_dashboard' | 'give_bonus' | 'society'

---@class JobGrade
---@field grade integer
---@field name string
---@field pay integer
---@field isBoss boolean

---@class JobDefinition
---@field name string
---@field label string
---@field type string
---@field grades table<integer, JobGrade>
---@field topGrade integer

---@class JobSettings
---@field logoUrl? string
---@field features table<string, boolean>
---@field pay table<string, integer>
---@field permissions table<string, RankPermission[]>

local Jobs <const> = {}

---@type RankPermission[]
Jobs.PERMISSIONS = { 'open_menu', 'view_dashboard', 'give_bonus', 'society' }

local PERMISSION_SET <const> = {}

for _, permission in ipairs(Jobs.PERMISSIONS) do PERMISSION_SET[permission] = true end

---@type table<string, JobDefinition>
local definitions = {}

---@type table<string, JobSettings>
local settings <const> = {}

---@param name string
---@param source table
---@return JobDefinition
local function define(name, source)
    local grades <const>, top = {}, 0

    for key, grade in pairs(source.grades or {}) do
        local level <const> = tonumber(key) --[[@as integer]]

        grades[level] = {
            grade = level,
            name = grade.name or locale('job.grade_fallback', level),
            pay = math.floor(tonumber(grade.payment) or 0),
            isBoss = grade.isboss == true,
        }

        if level > top then top = level end
    end

    return {
        name = name,
        label = source.label or name,
        type = source.type or 'job',
        grades = grades,
        topGrade = top,
    }
end

function Jobs.refresh()
    local found <const> = {}

    for name, job in pairs(exports.cobalt_core:GetShared('Jobs') or {}) do
        if job.society then found[name] = define(name, job) end
    end

    definitions = found
end

---@param name? string
---@return JobDefinition? definition nil for a job without a management menu
function Jobs.get(name)
    return name and definitions[name] or nil
end

---@return table<string, JobDefinition>
function Jobs.all()
    return definitions
end

---@param name? string
---@return table? definition cobalt_core's definition, for any job
function Jobs.shared(name)
    return name and exports.cobalt_core:GetShared('Jobs', name) or nil
end

---@param name string
---@return JobSettings
function Jobs.settings(name)
    local entry = settings[name]

    if not entry then
        entry = { features = {}, pay = {}, permissions = {} }
        settings[name] = entry
    end

    return entry
end

---@param name string
---@param by string
function Jobs.saveSettings(name, by)
    db.saveSettings(name, Jobs.settings(name), by)
end

---Vehicle settings for a job: its own entry in config.vehicles, else the entry for its job type
---@param name string
---@return { plate?: string, catalogue: table[] }?
function Jobs.vehicles(name)
    return config.vehicles[name] or config.vehicles[Jobs.get(name)?.type or '']
end

---@param name string
---@param grade integer
---@return JobGrade?
function Jobs.grade(name, grade)
    local job <const> = definitions[name]
    local base <const> = job and job.grades[grade]

    if not base then return end

    local pay <const> = Jobs.settings(name).pay[tostring(grade)]

    return { grade = base.grade, name = base.name, isBoss = base.isBoss, pay = pay or base.pay }
end

---@param name string
---@return JobGrade[]
function Jobs.grades(name)
    local job <const> = definitions[name]
    local out <const> = {}

    if not job then return out end

    for level = 0, job.topGrade do
        local grade <const> = Jobs.grade(name, level)

        if grade then out[#out + 1] = grade end
    end

    return out
end

---@param name string
---@param feature JobFeature
---@return boolean
function Jobs.feature(name, feature)
    local value <const> = Jobs.settings(name).features[feature]

    if value == nil then return config.features[feature] == true end

    return value
end

---@param name string
---@return table<JobFeature, boolean>
function Jobs.features(name)
    local out <const> = {}

    for feature in pairs(config.features) do out[feature] = Jobs.feature(name, feature) end

    return out
end

---@param name string
---@param grade integer
---@return table<RankPermission, true>
function Jobs.rankPermissions(name, grade)
    local out <const> = {}
    local base <const> = Jobs.grade(name, grade)

    if base?.isBoss then
        for _, permission in ipairs(Jobs.PERMISSIONS) do out[permission] = true end

        return out
    end

    for _, permission in ipairs(Jobs.settings(name).permissions[tostring(grade)] or {}) do
        if PERMISSION_SET[permission] then out[permission] = true end
    end

    return out
end

---@param value unknown
---@return RankPermission[]
function Jobs.cleanPermissions(value)
    local out <const> = {}

    if type(value) ~= 'table' then return out end

    for _, permission in ipairs(value) do
        if PERMISSION_SET[permission] then out[#out + 1] = permission end
    end

    return out
end

---@param name string
---@return string
function Jobs.typeLabel(name)
    local key <const> = ('job_type.%s'):format(definitions[name]?.type or 'business')

    return lib.getLocales()[key] or locale('job_type.business')
end

function Jobs.loadSettings()
    for _, row in ipairs(db.settings()) do
        local stored <const> = row.settings

        settings[row.name] = {
            logoUrl = type(stored.logoUrl) == 'string' and stored.logoUrl or nil,
            features = stored.features or {},
            pay = stored.pay or {},
            permissions = stored.permissions or {},
        }
    end
end

AddEventHandler('cobalt_core:server:jobsChanged', Jobs.refresh)

return Jobs
