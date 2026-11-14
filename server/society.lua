local Util <const> = require 'server.util'

local banking <const> = exports.cobalt_banking

---@class SocietyTransaction
---@field id integer
---@field at string
---@field description string
---@field by string
---@field amount integer

local Society <const> = {}

---@param orgName string
---@return string accountId
function Society.accountId(orgName)
    return 'society_' .. orgName
end

---@param orgName string
---@return integer
function Society.balance(orgName)
    return banking:GetBalance(Society.accountId(orgName))
end

---@param initiator? { citizenid: string, name: string? }
---@return string
local function initiatorName(initiator)
    if not initiator then
        return locale('society.bank')
    end

    if initiator.citizenid == 'payroll' then
        return locale('society.payroll')
    end

    return initiator.name or initiator.citizenid
end

---@param orgName string
---@param viewer string the citizenid reading the history
---@param limit integer
---@return SocietyTransaction[]
function Society.history(orgName, viewer, limit)
    local page <const> = banking:GetStatement(viewer, Society.accountId(orgName), { limit = limit })
    local out <const> = {}

    for i, entry in ipairs(page.ok and page.entries or {}) do
        out[i] = {
            id = entry.id,
            at = Util.iso(entry.createdAt),
            description = entry.note or entry.type,
            by = initiatorName(entry.initiator),
            amount = entry.amount,
        }
    end

    return out
end

---@param orgName string
---@param citizenid string
---@param amount integer
---@param description string
---@param by string
---@return boolean ok
---@return string|integer? errorOrBalance
function Society.pay(orgName, citizenid, amount, description, by)
    return banking:Transfer(Society.accountId(orgName), citizenid, amount, { note = description, initiator = by })
end

---@param orgName string
---@param citizenid string
---@param amount integer
---@param description string
---@param by string
---@return boolean ok
---@return string|integer? errorOrBalance
function Society.collect(orgName, citizenid, amount, description, by)
    return banking:Transfer(citizenid, Society.accountId(orgName), amount, {
        note = description,
        initiator = by,
        bill = true,
    })
end

---@param orgName string
---@param amount integer
---@param description string
---@param by string
---@return boolean ok
---@return string? error
function Society.spend(orgName, amount, description, by)
    local ok <const>, result <const> = banking:Withdraw(Society.accountId(orgName), amount, { note = description, initiator = by })

    if not ok then
        return false, type(result) == 'string' and result or locale('society.cannot_cover')
    end

    return true
end

---@return integer epoch seconds
---@return integer minutes between paydays
function Society.nextPayday()
    return banking:GetNextPayday()
end

return Society
