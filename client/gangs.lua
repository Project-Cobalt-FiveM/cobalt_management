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

---@type table<string, { blip: integer, zone: integer? }>
local hqs <const> = {}

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

---@param name string
local function removeHq(name)
    local hq <const> = hqs[name]

    if not hq then return end

    RemoveBlip(hq.blip)

    if hq.zone then exports.ox_target:removeZone(hq.zone) end

    hqs[name] = nil
end

---@param name string
---@param hq { x: number, y: number, z: number, label: string, colour: integer }
local function placeHq(name, hq)
    local blip <const> = AddBlipForCoord(hq.x, hq.y, hq.z)

    SetBlipSprite(blip, 492)
    SetBlipColour(blip, hq.colour or 0)
    SetBlipScale(blip, 0.75)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(hq.label)
    EndTextCommandSetBlipName(blip)

    local zone <const> = exports.ox_target:addSphereZone({
        coords = vec3(hq.x, hq.y, hq.z),
        radius = 1.5,
        options = {
            {
                name = 'cobalt_management:hq:' .. name,
                label = locale('gang.hq_target'),
                icon = 'fas fa-flag',
                distance = 2.5,
                canInteract = function() return Membership.inGang(name) end,
                onSelect = function() Nui.open('gang') end,
            },
        },
    })

    hqs[name] = { blip = blip, zone = zone }
end

---@param list? table<string, { x: number, y: number, z: number, label: string, colour: integer }>
local function syncHqs(list)
    for name in pairs(hqs) do removeHq(name) end

    for name, hq in pairs(list or {}) do placeHq(name, hq) end
end

AddStateBagChangeHandler('cobaltCharterer', 'global', function(_, _, value) placeCharterer(value) end)
AddStateBagChangeHandler('cobaltGangHqs', 'global', function(_, _, value) syncHqs(value) end)

CreateThread(function()
    placeCharterer(GlobalState.cobaltCharterer)
    syncHqs(GlobalState.cobaltGangHqs)
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

local picking = false

---@param maxDistance number meters
---@param color integer[] r, g, b, a
---@return vector3?
local function aimAtPoint(maxDistance, color)
    while picking do
        local hit <const>, _, coords <const> = lib.raycast.fromCamera(511, 4, maxDistance)

        DisableControlAction(0, 24, true)

        if hit and coords then
            DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.4, 0.4, 0.4,
                color[1], color[2], color[3], color[4], false, false, 2, false)

            if IsDisabledControlJustPressed(0, 24) then return coords end
        end

        if IsControlJustPressed(0, 73) then return end

        Wait(0)
    end
end

---@param prompt string
---@param maxDistance number meters
---@param color integer[] r, g, b, a
---@return vector3?
local function pickPoint(prompt, maxDistance, color)
    if LocalPlayer.state.isDead or LocalPlayer.state.cuffed then return end

    picking = true
    core:ShowTextUI(prompt)

    local coords <const> = aimAtPoint(maxDistance, color)

    picking = false
    core:HideTextUI()

    return coords
end

---@param value any
local function cancelPickWhenRestrained(_, _, value)
    if value then picking = false end
end

AddStateBagChangeHandler('isDead', ('player:%s'):format(cache.serverId), cancelPickWhenRestrained)
AddStateBagChangeHandler('cuffed', ('player:%s'):format(cache.serverId), cancelPickWhenRestrained)

RegisterNetEvent('cobalt_core:Client:OnPlayerUnload', function()
    picking = false
end)

local HQ_MARKER <const> = { 80, 120, 215, 200 }

RegisterNetEvent('cobalt_management:pickHq', function(maxDistance)
    local coords <const> = pickPoint(locale('gang.hq_prompt'), maxDistance, HQ_MARKER)

    if not coords then return end

    local street <const> = GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
    local area <const> = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))

    TriggerServerEvent('cobalt_management:hqPicked', {
        x = coords.x, y = coords.y, z = coords.z, w = GetEntityHeading(cache.ped),
    }, ('%s, %s'):format(street, area))
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    removeChartererPoint()

    for name in pairs(hqs) do removeHq(name) end

    if picking then core:HideTextUI() end
end)
