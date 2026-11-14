local config <const> = require 'config.server'
local db <const> = require 'server.db'
local Archetypes <const> = require 'server.gangs.archetypes'
local builtInGangs <const> = lib.load('@cobalt_core.data.gangs') --[[@as table<string, table>]]

local core <const> = exports.cobalt_core

---@class GangRecord
---@field name string
---@field label string
---@field archetype string
---@field founderCid? string
---@field foundedAt integer
---@field homeTurf? string
---@field hq? { x: number, y: number, z: number, w: number, label?: string }
---@field blipColor integer
---@field turfMovedAt? integer
---@field hqMovedAt? integer
---@field archetypeChangedAt? integer
---@field permissions? table<string, string[]>

local GangStore <const> = {}

---@type table<string, GangRecord>
local gangs = {}

---@param gang GangRecord
local function register(gang)
    local existing <const> = core:GetShared('Gangs', gang.name)
    local definition <const> = {}

    for key, value in pairs(existing or {}) do definition[key] = value end

    definition.label = gang.label
    definition.grades = Archetypes.gradesTable(gang.archetype)
    definition.archetype = gang.archetype
    definition.society = true

    if existing then
        core:UpdateGang(gang.name, definition)
    else
        core:AddGang(gang.name, definition)
    end
end

---@type table<string, table>?
local published

local function publish()
    local hqs <const> = {}

    for name, gang in pairs(gangs) do
        if gang.hq then
            hqs[name] = { x = gang.hq.x, y = gang.hq.y, z = gang.hq.z, label = gang.label, colour = gang.blipColor }
        end
    end

    if published and lib.table.matches(hqs, published) then return end

    published = hqs
    GlobalState.cobaltGangHqs = hqs
end

---@param name string
---@param label string
---@return GangRecord
local function seedRecord(name, label)
    local archetype <const> = Archetypes.seeds[name] or 'street'

    return {
        name = name,
        label = label,
        archetype = archetype,
        foundedAt = os.time(),
        blipColor = Archetypes.get(archetype).blipColor,
    }
end

local function seed()
    for name, definition in pairs(core:GetShared('Gangs') or {}) do
        if definition.society and not gangs[name] then
            local gang <const> = seedRecord(name, definition.label or name)

            if db.insertGang(gang) then
                gangs[name] = gang
                lib.print.info(('seeded gang %s as %s'):format(name, gang.archetype))
            end
        end
    end
end

function GangStore.load()
    gangs = {}

    for _, gang in ipairs(db.gangs()) do gangs[gang.name] = gang end

    seed()

    for _, gang in pairs(gangs) do register(gang) end

    publish()
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

---@param spec { label: string, archetype?: string, founderCid?: string, homeTurf?: string, blipColor?: integer }
---@return GangRecord?
function GangStore.create(spec)
    local archetype <const> = Archetypes.exists(spec.archetype or '') and spec.archetype or 'street'
    local gang <const> = {
        name = GangStore.slug(spec.label),
        label = spec.label,
        archetype = archetype,
        founderCid = spec.founderCid,
        foundedAt = os.time(),
        homeTurf = spec.homeTurf,
        blipColor = spec.blipColor or Archetypes.get(archetype).blipColor,
    }

    if not db.insertGang(gang) then return end

    gangs[gang.name] = gang
    register(gang)

    return gang
end

---@class GangChanges
---@field definition? boolean the label, grades or archetype changed, so core's gang definition is refreshed
---@field map? boolean the HQ or map colour changed, so every client's HQ blips are refreshed

---@param gang GangRecord
---@param regrades? table<string, table> new gang snapshot by citizenid, saved in the same transaction
---@param debit? VaultDebit taken from the vault in the same transaction
---@param changes? GangChanges
---@return boolean saved
function GangStore.save(gang, regrades, debit, changes)
    if not db.saveGang(gang, regrades, debit) then return false end

    if changes?.definition then register(gang) end
    if changes?.map then publish() end

    return true
end

---@param name string
function GangStore.dissolve(name)
    if not gangs[name] then return end

    db.deleteGang(name)
    gangs[name] = nil

    local builtIn <const> = builtInGangs[name]

    if not builtIn then
        core:RemoveGang(name)
    elseif builtIn.society then
        local fresh <const> = seedRecord(name, builtIn.label or name)

        if db.insertGang(fresh) then
            gangs[name] = fresh
            register(fresh)
        end
    end

    publish()
end

return GangStore
