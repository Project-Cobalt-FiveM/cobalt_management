local config <const> = require 'config.server'
local Members <const> = require 'server.members'
local Util <const> = require 'server.util'
local Ranks <const> = require 'server.gangs.ranks'
local GangStore <const> = require 'server.gangs.store'
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

    return {
        mode = 'charter',
        now = Util.iso(os.time()),
        price = charter.price,
        carried = inventory:GetItemCount(source, charter.item) or 0,
        slotsUsed = GangStore.count(),
        maxSlots = config.gangs.maxActive,
        bossRank = Ranks.boss().name,
        nameLength = config.gangs.nameLength,
    }
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

    local citizenid <const> = Members.citizenid(source) --[[@as string]]

    if not inventory:RemoveItem(source, charter.item, charter.price, nil, 'gang charter') then
        return { ok = false, error = locale('charter.need_bills', Util.money(charter.price)) }
    end

    local gang <const> = GangStore.create({ label = label, founderCid = citizenid })

    if not gang then
        inventory:AddItem(source, charter.item, charter.price, nil, nil, 'gang charter refund')

        return { ok = false, error = locale('charter.failed') }
    end

    local boss <const> = Ranks.boss()

    Members.setGang(source, gang.name, boss.grade)
    Util.notify(source, locale('charter.done', label, boss.name), 'success')
    Util.log(gang.name, 'Charter', ('%s founded %s'):format(Members.name(source), label))

    return { ok = true }
end

---@param source integer
---@param amount unknown
function Charterer.deposit(source, amount)
    local count <const> = Util.integer(amount, 1, 100000000)
    local actor <const> = Gangs.actor(source)

    if not count or not actor or not Charterer.near(source) then return end

    local ok <const>, err <const>, credited <const> = Gangs.deposit(source, actor, count, locale('vault.charter_deposit'))

    if not ok then
        return Util.notify(source, err --[[@as string]], 'error')
    end

    if credited < count then
        local refunded <const> = Util.money(count - credited)

        return Util.notify(source, locale('charter.vault_full', Util.money(credited), refunded), 'warning')
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
