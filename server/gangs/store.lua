local config <const> = require 'config.server'
local db <const> = require 'server.gangs.db'
local Ranks <const> = require 'server.gangs.ranks'
local builtInGangs <const> = lib.load('@cobalt_core.data.gangs') --[[@as table<string, table>]]

local core <const> = exports.cobalt_core

---@class GangRecord
---@field name string
---@field label string
---@field founderCid? string
---@field foundedAt integer
---@field permissions? table<string, GangPermission[]> the boss's changes to each rank's permissions, by grade

local GangStore <const> = {}

---@type table<string, GangRecord>
local gangs = {}

---@param gang GangRecord
local function register(gang)
    local existing <const> = core:GetShared('Gangs', gang.name)
    local definition <const> = {}

    for key, value in pairs(existing or {}) do definition[key] = value end

    definition.label = gang.label
    definition.society = true

    if not Ranks.isBuiltIn(gang.name) then definition.grades = Ranks.gradesTable() end

    if existing then
        core:UpdateGang(gang.name, definition)
    else
        core:AddGang(gang.name, definition)
    end
end

---@param name string
---@param label string
---@return GangRecord
local function seedRecord(name, label)
    return { name = name, label = label, foundedAt = os.time() }
end

local function seed()
    for name, definition in pairs(core:GetShared('Gangs') or {}) do
        if definition.society and not gangs[name] then
            local gang <const> = seedRecord(name, definition.label or name)

            if db.insert(gang) then
                gangs[name] = gang
                lib.print.info(('seeded gang %s'):format(name))
            end
        end
    end
end

function GangStore.load()
    gangs = {}

    for _, gang in ipairs(db.all()) do gangs[gang.name] = gang end

    seed()

    for _, gang in pairs(gangs) do register(gang) end

    lib.print.info(('loaded %d gangs'):format(GangStore.count()))
end

---@param name? string
---@return GangRecord?
function GangStore.get(name)
    return name and gangs[name] or nil
end

---@return table<string, GangRecord>
function GangStore.all()
    return gangs
end

---@return integer
function GangStore.count()
    local count = 0

    for _ in pairs(gangs) do count += 1 end

    return count
end

---@return boolean
function GangStore.full()
    return GangStore.count() >= config.gangs.maxActive
end

---@param label string
---@return string
function GangStore.slug(label)
    local base = label:lower():gsub('[^%w]+', '_'):gsub('^_+', ''):gsub('_+$', ''):sub(1, 40)

    if base == '' then base = 'gang' end

    local slug, suffix = base, 1

    while gangs[slug] or core:GetShared('Gangs', slug) or core:GetShared('Jobs', slug) do
        suffix += 1
        slug = ('%s_%d'):format(base, suffix)
    end

    return slug
end

---@param label string
---@return boolean
function GangStore.labelTaken(label)
    local wanted <const> = label:lower()

    for _, gang in pairs(gangs) do
        if gang.label:lower() == wanted then return true end
    end

    return false
end

---@param spec { label: string, founderCid?: string }
---@return GangRecord?
function GangStore.create(spec)
    local gang <const> = {
        name = GangStore.slug(spec.label),
        label = spec.label,
        founderCid = spec.founderCid,
        foundedAt = os.time(),
    }

    if not db.insert(gang) then return end

    gangs[gang.name] = gang
    register(gang)

    return gang
end

---@param gang GangRecord
---@param relabelled? boolean the label changed, so core's gang definition is refreshed
function GangStore.save(gang, relabelled)
    db.save(gang)

    if relabelled then register(gang) end
end

---@param name string
function GangStore.dissolve(name)
    if not gangs[name] then return end

    db.delete(name)
    gangs[name] = nil

    local builtIn <const> = builtInGangs[name]

    if not builtIn then
        core:RemoveGang(name)
    elseif builtIn.society then
        local fresh <const> = seedRecord(name, builtIn.label or name)

        if db.insert(fresh) then
            gangs[name] = fresh
            register(fresh)
        end
    end
end

return GangStore
