local config <const> = require 'config.client'
local Nui <const> = require 'client.nui'
local Membership <const> = require 'client.membership'

require 'client.gangs'

local core <const> = exports.cobalt_core

---@return boolean
local function employed()
    local job <const> = Membership.job()

    return job ~= nil and job.name ~= 'unemployed'
end

local function openMain()
    if Nui.mode() then return Nui.close() end

    if Membership.gang() and not employed() then return Nui.open('gang') end

    Nui.open('org')
end

---@param org? string
local function openApplication(org)
    if org then return Nui.open('apply', { org = org }) end

    local jobs <const> = lib.callback.await('cobalt_management:applicable', false) or {}

    if #jobs == 0 then
        return core:Notify({ description = locale('apply.no_openings'), type = 'info' })
    end

    local options <const> = {}

    for _, job in ipairs(jobs) do
        options[#options + 1] = { title = job.label, onSelect = function() Nui.open('apply', { org = job.name }) end }
    end

    core:RegisterContext({ id = 'cobalt_management:apply', title = locale('apply.menu_title'), options = options })
    core:ShowContext('cobalt_management:apply')
end

---@param orgLabel string
---@param rank string
---@param boss string
---@param asSecondJob boolean
---@return string
local function offerText(orgLabel, rank, boss, asSecondJob)
    if asSecondJob then
        return locale('offer.body_second', boss, orgLabel, rank)
    end

    if employed() then
        return locale('offer.body_replace', boss, orgLabel, rank, Membership.job()?.label)
    end

    return locale('offer.body', boss, orgLabel, rank)
end

RegisterCommand(config.openCommand, openMain, false)
RegisterKeyMapping(config.openCommand, locale('menu.keybind'), 'keyboard', config.openKey)

RegisterNetEvent('cobalt_management:apply', openApplication)

RegisterNetEvent('cobalt_management:jobOffer', function(orgName, orgLabel, rank, boss, asSecondJob)
    local answer <const> = core:AlertDialog({
        header = locale('offer.title'),
        content = offerText(orgLabel, rank, boss, asSecondJob == true),
        centered = true,
        cancel = true,
        labels = { confirm = locale('offer.accept'), cancel = locale('offer.decline') },
    }, 60000)

    TriggerServerEvent('cobalt_management:answerOffer', orgName, answer == 'confirm')
end)

exports('GetJob', Membership.job)
exports('GetDuty', Membership.onDuty)

exports('OpenMenu', function(mode, data)
    return Nui.open(mode or 'org', data)
end)
