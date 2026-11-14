local config <const> = require 'config.server'
local db <const> = require 'server.gangs.db'

local Vault <const> = {}

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

return Vault
