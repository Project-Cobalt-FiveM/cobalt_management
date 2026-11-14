local config <const> = require 'config.server'
local db <const> = require 'server.db'

---@alias OrgFeature 'society' | 'applications' | 'leaves' | 'reports' | 'vehicles' | 'announcements' | 'duty' | 'secondJobs'
---@alias RankPermission 'open_menu' | 'view_dashboard' | 'give_bonus' | 'society'

---@class OrgGrade
---@field grade integer
---@field name string
---@field pay integer
---@field isBoss boolean

---@class OrgDefinition
---@field name string
---@field label string
---@field type string
---@field isGang boolean
---@field offDutyPay boolean
---@field grades table<integer, OrgGrade>
---@field topGrade integer

---@class OrgSettings
---@field logoUrl? string
---@field features table<string, boolean>
---@field pay table<string, integer>
---@field permissions table<string, RankPermission[]>

local Orgs <const> = {}

---@type RankPermission[]
Orgs.PERMISSIONS = { 'open_menu', 'view_dashboard', 'give_bonus', 'society' }

local PERMISSION_SET <const> = {}

for _, permission in ipairs(Orgs.PERMISSIONS) do PERMISSION_SET[permission] = true end

---@type table<string, OrgDefinition>
local definitions = {}

---@type table<string, OrgSettings>
local settings <const> = {}

---@param name string
---@param source table
---@param isGang boolean
---@return OrgDefinition
local function define(name, source, isGang)
    local grades <const>, top = {}, 0

    for key, grade in pairs(source.grades or {}) do
        local level <const> = tonumber(key) --[[@as integer]]

        grades[level] = {
            grade = level,
            name = grade.name or locale('org.grade_fallback', level),
            pay = math.floor(tonumber(grade.payment) or 0),
            isBoss = grade.isboss == true,
        }

        if level > top then top = level end
    end

    return {
        name = name,
        label = source.label or name,
        type = isGang and 'gang' or (source.type or 'job'),
        isGang = isGang,
        offDutyPay = source.offDutyPay == true,
        grades = grades,
        topGrade = top,
    }
end

function Orgs.refresh()
    local core <const> = exports.cobalt_core
    local found <const> = {}

    for name, job in pairs(core:GetShared('Jobs') or {}) do
        if job.society then found[name] = define(name, job, false) end
    end

    for name, gang in pairs(core:GetShared('Gangs') or {}) do
        if gang.society then found[name] = define(name, gang, true) end
    end

    definitions = found
end

---@param name? string
---@return OrgDefinition?
function Orgs.get(name)
    return name and definitions[name] or nil
end

---@return table<string, OrgDefinition>
function Orgs.all()
    return definitions
end

---@param name? string
---@return table?
function Orgs.sharedJob(name)
    return name and exports.cobalt_core:GetShared('Jobs', name) or nil
end

---@param name? string
---@return table?
function Orgs.sharedGang(name)
    return name and exports.cobalt_core:GetShared('Gangs', name) or nil
end

---@param name string
---@return OrgSettings
function Orgs.settings(name)
    local entry = settings[name]

    if not entry then
        entry = { features = {}, pay = {}, permissions = {} }
        settings[name] = entry
    end

    return entry
end

---@param name string
---@param by string
function Orgs.saveSettings(name, by)
    db.saveSettings(name, Orgs.settings(name), by)
end

---Vehicle settings for an org: its own entry in config.vehicles, else the entry for its job type
---@param name string
---@return { plate?: string, catalogue: table[] }?
function Orgs.vehicles(name)
    return config.vehicles[name] or config.vehicles[Orgs.get(name)?.type or '']
end

---@param name string
---@param grade integer
---@return OrgGrade?
function Orgs.grade(name, grade)
    local org <const> = definitions[name]
    local base <const> = org and org.grades[grade]

    if not base then return end

    local pay <const> = Orgs.settings(name).pay[tostring(grade)]

    return { grade = base.grade, name = base.name, isBoss = base.isBoss, pay = pay or base.pay }
end

---@param name string
---@return OrgGrade[]
function Orgs.grades(name)
    local org <const> = definitions[name]
    local out <const> = {}

    if not org then return out end

    for level = 0, org.topGrade do
        local grade <const> = Orgs.grade(name, level)

        if grade then out[#out + 1] = grade end
    end

    return out
end

---@param name string
---@param feature OrgFeature
---@return boolean
function Orgs.feature(name, feature)
    local value <const> = Orgs.settings(name).features[feature]

    if value == nil then return config.features[feature] == true end

    return value
end

---@param name string
---@return table<OrgFeature, boolean>
function Orgs.features(name)
    local out <const> = {}

    for feature in pairs(config.features) do out[feature] = Orgs.feature(name, feature) end

    return out
end

---@param name string
---@param grade integer
---@return table<RankPermission, true>
function Orgs.rankPermissions(name, grade)
    local out <const> = {}
    local base <const> = Orgs.grade(name, grade)

    if base?.isBoss then
        for _, permission in ipairs(Orgs.PERMISSIONS) do out[permission] = true end

        return out
    end

    for _, permission in ipairs(Orgs.settings(name).permissions[tostring(grade)] or {}) do
        if PERMISSION_SET[permission] then out[permission] = true end
    end

    return out
end

---@param value unknown
---@return RankPermission[]
function Orgs.cleanPermissions(value)
    local out <const> = {}

    if type(value) ~= 'table' then return out end

    for _, permission in ipairs(value) do
        if PERMISSION_SET[permission] then out[#out + 1] = permission end
    end

    return out
end

---@param name string
---@return string
function Orgs.typeLabel(name)
    local key <const> = ('org_type.%s'):format(definitions[name]?.type or 'business')

    return lib.getLocales()[key] or locale('org_type.business')
end

function Orgs.loadSettings()
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

AddEventHandler('cobalt_core:server:jobsChanged', Orgs.refresh)
AddEventHandler('cobalt_core:server:gangsChanged', Orgs.refresh)

return Orgs
