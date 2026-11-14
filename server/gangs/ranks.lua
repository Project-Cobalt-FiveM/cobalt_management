local config <const> = require 'config.server'
local builtInGangs <const> = lib.load('@cobalt_core.data.gangs') --[[@as table<string, GangDefinition>]]

---@class GangRank
---@field grade integer
---@field name string
---@field isBoss boolean
---@field permissions GangPermission[] what the rank holds until the boss changes it

---@class GangLadder
---@field ranks GangRank[] indexed by grade + 1
---@field bossGrade integer

---@type GangPermission[]
local PERMISSIONS <const> = { 'vault_view', 'vault_deposit', 'vault_withdraw', 'vault_audit', 'gang_invite' }

local KNOWN <const> = {}

---@type { id: GangPermission, label: string }[]
local CATALOG <const> = {}

for index, id in ipairs(PERMISSIONS) do
    KNOWN[id] = true
    CATALOG[index] = { id = id, label = locale(('gang.permission.%s'):format(id)) }
end

---@param permissions? string[]
---@return GangPermission[]
local function known(permissions)
    local out <const> = {}

    for _, permission in ipairs(permissions or {}) do
        if KNOWN[permission] then out[#out + 1] = permission end
    end

    return out
end

---@return GangLadder
local function configLadder()
    local ranks <const> = {}

    for index, rank in ipairs(config.gangs.ranks) do
        local isBoss <const> = index == #config.gangs.ranks

        ranks[index] = {
            grade = index - 1,
            name = rank.name,
            isBoss = isBoss,
            permissions = isBoss and PERMISSIONS or known(rank.permissions),
        }
    end

    return { ranks = ranks, bossGrade = #ranks - 1 }
end

---@param grades table<string, GangGradeDefinition>
---@return GangLadder
local function coreLadder(grades)
    local top, boss = 0, nil

    for key, grade in pairs(grades) do
        local level <const> = math.tointeger(tonumber(key)) or 0

        top = math.max(top, level)

        if grade.isboss then boss = level end
    end

    boss = boss or top

    local ranks <const> = {}

    for level = 0, boss do
        local isBoss <const> = level == boss

        ranks[level + 1] = {
            grade = level,
            name = grades[tostring(level)]?.name or tostring(level),
            isBoss = isBoss,
            permissions = isBoss and PERMISSIONS or known(config.gangs.builtInPermissions),
        }
    end

    return { ranks = ranks, bossGrade = boss }
end

local PLAYER_MADE <const> = configLadder()

---@type table<string, GangLadder>
local BUILT_IN <const> = {}

for name, definition in pairs(builtInGangs) do
    if definition.society then BUILT_IN[name] = coreLadder(definition.grades) end
end

local Ranks <const> = {}

---@param gangName? string nil for the ladder every player-made gang uses
---@return GangLadder
function Ranks.ladder(gangName)
    return BUILT_IN[gangName] or PLAYER_MADE
end

---@param gangName string
---@return boolean
function Ranks.isBuiltIn(gangName)
    return BUILT_IN[gangName] ~= nil
end

---@param gangName? string
---@return GangRank
function Ranks.boss(gangName)
    local ladder <const> = Ranks.ladder(gangName)

    return ladder.ranks[ladder.bossGrade + 1]
end

---@param gangName string
---@param grade integer
---@return GangRank?
function Ranks.rank(gangName, grade)
    return Ranks.ladder(gangName).ranks[grade + 1]
end

---@return table<string, { name: string, isboss: boolean }>
function Ranks.gradesTable()
    local out <const> = {}

    for _, rank in ipairs(PLAYER_MADE.ranks) do
        out[tostring(rank.grade)] = { name = rank.name, isboss = rank.isBoss }
    end

    return out
end

---@param gang GangRecord
---@param grade integer
---@return GangPermission[]
function Ranks.permissions(gang, grade)
    local rank <const> = Ranks.rank(gang.name, grade)

    if not rank then return {} end
    if rank.isBoss then return PERMISSIONS end

    return gang.permissions?[tostring(grade)] or rank.permissions
end

---@param gang GangRecord
---@param grade integer
---@param permission GangPermission
---@return boolean
function Ranks.has(gang, grade, permission)
    for _, granted in ipairs(Ranks.permissions(gang, grade)) do
        if granted == permission then return true end
    end

    return false
end

---@param gang GangRecord
---@param value unknown
---@return table<string, GangPermission[]>?
function Ranks.cleanOverrides(gang, value)
    if type(value) ~= 'table' then return end

    local out <const> = {}

    for _, rank in ipairs(Ranks.ladder(gang.name).ranks) do
        local list <const> = value[tostring(rank.grade)]

        if not rank.isBoss and type(list) == 'table' then out[tostring(rank.grade)] = known(list) end
    end

    return out
end

---@return { id: GangPermission, label: string }[]
function Ranks.catalog()
    return CATALOG
end

return Ranks
