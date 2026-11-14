local config <const> = require 'config.client'
local Nui <const> = require 'client.nui'
local Membership <const> = require 'client.membership'

local core <const> = exports.cobalt_core
local charter <const> = config.charter

---@alias ChartererSpot { x: number, y: number, z: number, w: number }

---@type integer?
local chartererPed

---@type CPoint?
local chartererPoint

---@type ChartererSpot?
local chartererSpot

local placement = 0

---@return boolean
local function inGang()
    return Membership.gang() ~= nil
end

---@param title string
---@param label string
---@return integer?
local function askAmount(title, label)
    local values <const> = core:InputDialog(title, { { type = 'number', label = label, required = true, min = 1 } })
    local amount <const> = values and math.tointeger(tonumber(values[1]))

    return amount and amount > 0 and amount or nil
end

local function removeCharterer()
    placement += 1

    if chartererPed and DoesEntityExist(chartererPed) then
        exports.ox_target:removeLocalEntity(chartererPed)
        DeleteEntity(chartererPed)
    end

    chartererPed = nil
end

---@param ped integer
local function addChartererOptions(ped)
    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'cobalt_management:charter',
            label = locale('charter.target'),
            icon = 'fas fa-flag',
            distance = 2.5,
            canInteract = function() return not inGang() end,
            onSelect = function() Nui.open('charter') end,
        },
        {
            name = 'cobalt_management:vaultDeposit',
            label = locale('charter.deposit_target'),
            icon = 'fas fa-arrow-down',
            distance = 2.5,
            canInteract = inGang,
            onSelect = function()
                local amount <const> = askAmount(locale('charter.deposit_title'), locale('charter.amount_label'))

                if amount then TriggerServerEvent('cobalt_management:charterDeposit', amount) end
            end,
        },
        {
            name = 'cobalt_management:vaultWithdraw',
            label = locale('charter.withdraw_target'),
            icon = 'fas fa-arrow-up',
            distance = 2.5,
            canInteract = inGang,
            onSelect = function()
                local amount <const> = askAmount(locale('charter.withdraw_title'), locale('charter.amount_label'))

                if amount then TriggerServerEvent('cobalt_management:charterWithdraw', amount) end
            end,
        },
    })
end

---@param location ChartererSpot
local function spawnCharterer(location)
    removeCharterer()

    local current <const> = placement

    CreateThread(function()
        lib.requestModel(charter.ped)

        if current ~= placement then
            SetModelAsNoLongerNeeded(charter.ped)

            return
        end

        local ped <const> = CreatePed(4, charter.ped, location.x, location.y, location.z - 1.0, location.w, false, false)

        SetModelAsNoLongerNeeded(charter.ped)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        TaskStartScenarioInPlace(ped, charter.scenario, 0, true)
        chartererPed = ped
        addChartererOptions(ped)
    end)
end

---@param a? ChartererSpot
---@param b? ChartererSpot
---@return boolean
local function sameSpot(a, b)
    if not a or not b then return a == b end

    return a.x == b.x and a.y == b.y and a.z == b.z and a.w == b.w
end

local function removeChartererPoint()
    if chartererPoint then chartererPoint:remove() end

    chartererPoint = nil
    removeCharterer()
end

---@param location? ChartererSpot
local function placeCharterer(location)
    if sameSpot(location, chartererSpot) then return end

    removeChartererPoint()
    chartererSpot = location

    if not location then return end

    chartererPoint = lib.points.new({
        coords = vec3(location.x, location.y, location.z),
        distance = charter.spawnDistance,
        onEnter = function() spawnCharterer(location) end,
        onExit = removeCharterer,
    })
end

AddStateBagChangeHandler('cobaltCharterer', 'global', function(_, _, value) placeCharterer(value) end)

CreateThread(function()
    placeCharterer(GlobalState.cobaltCharterer)
end)

exports.ox_target:addGlobalPlayer({
    {
        name = 'cobalt_management:invite',
        label = locale('gang.invite_target'),
        icon = 'fas fa-handshake',
        distance = 2.5,
        canInteract = inGang,
        onSelect = function(data)
            local target <const> = data.entity and NetworkGetPlayerIndexFromPed(data.entity)

            if not target or target == -1 then return end

            local result <const> = Nui.request('gang:invite', { serverId = GetPlayerServerId(target) })

            core:Notify({
                description = result?.ok and locale('gang.invite_sent') or result?.error or locale('gang.invite_failed'),
                type = result?.ok and 'success' or 'error',
            })
        end,
    },
})

RegisterNetEvent('cobalt_management:gangInvite', function(gangName, gangLabel, inviter)
    local answer <const> = core:AlertDialog({
        header = locale('gang.invite_title'),
        content = locale('gang.invite_body', inviter, gangLabel),
        centered = true,
        cancel = true,
        labels = { confirm = locale('gang.invite_join'), cancel = locale('gang.invite_decline') },
    }, 60000)

    TriggerServerEvent('cobalt_management:answerInvite', gangName, answer == 'confirm')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    removeChartererPoint()
end)
