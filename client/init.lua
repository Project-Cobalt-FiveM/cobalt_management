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

    Nui.open('job')
end

---@param jobName? string
local function openApplication(jobName)
    if jobName then return Nui.open('apply', { job = jobName }) end

    local jobs <const> = lib.callback.await('cobalt_management:applicable', false) or {}

    if #jobs == 0 then
        return core:Notify({ description = locale('apply.no_openings'), type = 'info' })
    end

    local options <const> = {}

    for _, job in ipairs(jobs) do
        options[#options + 1] = { title = job.label, onSelect = function() Nui.open('apply', { job = job.name }) end }
    end

    core:RegisterContext({ id = 'cobalt_management:apply', title = locale('apply.menu_title'), options = options })
    core:ShowContext('cobalt_management:apply')
end

---@param jobLabel string
---@param rank string
---@param boss string
---@param asSecondJob boolean
---@return string
local function offerText(jobLabel, rank, boss, asSecondJob)
    if asSecondJob then
        return locale('offer.body_second', boss, jobLabel, rank)
    end

    if employed() then
        return locale('offer.body_replace', boss, jobLabel, rank, Membership.job()?.label)
    end

    return locale('offer.body', boss, jobLabel, rank)
end

RegisterCommand(config.openCommand, openMain, false)
RegisterKeyMapping(config.openCommand, locale('menu.keybind'), 'keyboard', config.openKey)

RegisterNetEvent('cobalt_management:apply', openApplication)

RegisterNetEvent('cobalt_management:jobOffer', function(jobName, jobLabel, rank, boss, asSecondJob)
    local answer <const> = core:AlertDialog({
        header = locale('offer.title'),
        content = offerText(jobLabel, rank, boss, asSecondJob == true),
        centered = true,
        cancel = true,
        labels = { confirm = locale('offer.accept'), cancel = locale('offer.decline') },
    }, 60000)

    TriggerServerEvent('cobalt_management:answerOffer', jobName, answer == 'confirm')
end)

exports('GetJob', Membership.job)
exports('GetGang', Membership.gang)
exports('GetDuty', Membership.onDuty)

exports('OpenMenu', function(mode, data)
    return Nui.open(mode or 'job', data)
end)
