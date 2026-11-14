local config <const> = require 'config.server'
local Members <const> = require 'server.members'
local Util <const> = require 'server.util'
local Archetypes <const> = require 'server.gangs.archetypes'
local GangStore <const> = require 'server.gangs.store'
local Vault <const> = require 'server.gangs.vault'
local Gangs <const> = require 'server.gangs.service'

local charter <const> = config.gangs.charter
local inventory <const> = exports.cobalt_inventory

local Charterer <const> = {}

---@type vector4?
local location

local function roll()
    local choices <const> = {}

    for _, spot in ipairs(charter.locations) do
        if spot ~= location then choices[#choices + 1] = spot end
    end

    if #choices == 0 then return end

    local picked <const> = choices[math.random(1, #choices)]

    location = picked
    GlobalState.cobaltCharterer = { x = picked.x, y = picked.y, z = picked.z, w = picked.w }
    lib.print.info(('charterer moved to %.1f, %.1f, %.1f'):format(picked.x, picked.y, picked.z))
end

---@param source integer
---@return boolean
function Charterer.near(source)
    return location ~= nil and #(GetEntityCoords(GetPlayerPed(source)) - location.xyz) <= charter.range
end

---@param source integer
---@return table? session
---@return string? error
function Charterer.session(source)
    if not Charterer.near(source) then
        return nil, locale('charter.not_here')
    end

    if Members.gang(source) then
        return nil, locale('charter.leave_first')
    end

    local street <const> = Archetypes.get('street')

    return {
        mode = 'charter',
        now = Util.iso(os.time()),
        price = charter.price,
        carried = inventory:GetItemCount(source, charter.item) or 0,
        slotsUsed = GangStore.count(),
        maxSlots = config.gangs.maxActive,
        bossRank = street.ranks[street.bossGrade].name,
        zones = Vault.zones(),
        colours = Gangs.colours(),
        nameLength = config.gangs.nameLength,
    }
end

---@param colour unknown
---@return integer?
local function colourId(colour)
    for _, entry in ipairs(config.gangs.colours) do
        if entry.id == colour then return entry.id end
    end
end

---@param source integer
---@param data table
---@return { ok: boolean, error?: string }
function Charterer.found(source, data)
    if not Charterer.near(source) then
        return { ok = false, error = locale('charter.not_here') }
    end

    if Members.gang(source) then
        return { ok = false, error = locale('gang.leave_first') }
    end

    if GangStore.full() then
        return { ok = false, error = locale('charter.full') }
    end

    local length <const> = config.gangs.nameLength
    local label <const> = Util.text(data.label, length.max)

    if not label or #label < length.min or not label:match('^[%w%s\'%-%.]+$') then
        return { ok = false, error = locale('gang.name_length', length.min, length.max) }
    end

    if GangStore.labelTaken(label) then
        return { ok = false, error = locale('gang.name_taken') }
    end

    local colour <const> = colourId(data.blipColor)
    local turf <const> = type(data.homeTurf) == 'string' and Vault.zoneExists(data.homeTurf) and data.homeTurf or nil

    if not colour or not turf then
        return { ok = false, error = locale('charter.pick_turf_colour') }
    end

    local citizenid <const> = Members.citizenid(source) --[[@as string]]

    if not inventory:RemoveItem(source, charter.item, charter.price, nil, 'gang charter') then
        return { ok = false, error = locale('charter.need_bills', Util.money(charter.price)) }
    end

    local gang <const> = GangStore.create({ label = label, founderCid = citizenid, homeTurf = turf, blipColor = colour })

    if not gang then
        inventory:AddItem(source, charter.item, charter.price, nil, nil, 'gang charter refund')

        return { ok = false, error = locale('charter.failed') }
    end

    local street <const> = Archetypes.get('street')

    Members.setGang(source, gang.name, street.bossGrade)
    Util.notify(source, locale('charter.done', label, street.ranks[street.bossGrade].name), 'success')
    Util.log(gang.name, 'Charter', ('%s founded %s'):format(Members.name(source), label))

    return { ok = true }
end

---@param source integer
---@param amount unknown
function Charterer.deposit(source, amount)
    local count <const> = Util.integer(amount, 1, 100000000)
    local gang <const> = Members.gang(source)

    if not count or not gang or not Charterer.near(source) then return end

    if not inventory:RemoveItem(source, charter.item, count, nil, 'gang vault deposit') then
        return Util.notify(source, locale('charter.not_carrying', Util.money(count)), 'error')
    end

    local credited <const> = Vault.credit(gang.name, count, locale('vault.charter_deposit'), Members.name(source))

    if credited < count then
        inventory:AddItem(source, charter.item, count - credited, nil, nil, 'gang vault deposit refund')

        local refunded <const> = Util.money(count - credited)

        Util.notify(source, locale('charter.vault_full', Util.money(credited), refunded), 'warning')

        return
    end

    Util.notify(source, locale('charter.deposited', Util.money(credited)), 'success')
end

---@param source integer
---@param amount unknown
function Charterer.withdraw(source, amount)
    local count <const> = Util.integer(amount, 1, 100000000)
    local actor <const> = Gangs.actor(source)

    if not count or not actor or not Charterer.near(source) then return end

    local ok <const>, err <const> = Gangs.withdraw(source, actor, count, locale('vault.charter_withdrawal'))

    if not ok then
        return Util.notify(source, err --[[@as string]], 'error')
    end

    Util.notify(source, locale('charter.withdrew', Util.money(count)), 'success')
end

roll()

if #charter.locations > 1 then SetInterval(roll, charter.rotateMinutes * 60000) end

return Charterer
