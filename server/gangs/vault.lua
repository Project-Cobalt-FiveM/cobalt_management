local config <const> = require 'config.server'
local db <const> = require 'server.db'

local Vault <const> = {}

---@return boolean
local function crimeStarted()
    return GetResourceState('cobalt_crime') == 'started'
end

---@param gangName string
---@return integer
function Vault.balance(gangName)
    return db.vaultBalance(gangName)
end

---@param gangName string
---@param amount integer
---@param what string
---@param who string
---@return boolean
function Vault.debit(gangName, amount, what, who)
    if amount <= 0 then return true end

    return db.debitVault(gangName, amount, what, who)
end

---@param gangName string
---@param amount integer
---@param what string
---@param who string
---@return integer credited
function Vault.credit(gangName, amount, what, who)
    if amount <= 0 then return 0 end

    return db.creditVault(gangName, amount, config.gangs.vaultCap, what, who)
end

---@param gangName string
---@return { id: integer, at: string, what: string, who: string, amount: integer }[]
function Vault.history(gangName)
    return db.vaultLog(gangName)
end

---@return { id: string, label: string }[]
function Vault.zones()
    if not crimeStarted() then return {} end

    local out <const> = {}

    for _, zone in ipairs(exports.cobalt_crime:GetZones()) do
        out[#out + 1] = { id = zone.id, label = zone.label }
    end

    table.sort(out, function(a, b) return a.label < b.label end)

    return out
end

---@param id string
---@return boolean
function Vault.zoneExists(id)
    return crimeStarted() and exports.cobalt_crime:GetZone(id) ~= nil
end

---@param id? string
---@return string?
function Vault.zoneLabel(id)
    if not id or not crimeStarted() then return id end

    return exports.cobalt_crime:GetZone(id)?.label or id
end

return Vault
