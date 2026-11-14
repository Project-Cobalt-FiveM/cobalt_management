local Util <const> = require 'server.util'

local banking <const> = exports.cobalt_banking

---@class SocietyTransaction
---@field id integer
---@field at string
---@field description string
---@field by string
---@field amount integer

local Society <const> = {}

---@param jobName string
---@return string accountId
function Society.accountId(jobName)
    return 'society_' .. jobName
end

---@param jobName string
---@return integer
function Society.balance(jobName)
    return banking:GetBalance(Society.accountId(jobName))
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

---@param jobName string
---@param viewer string the citizenid reading the history
---@param limit integer
---@return SocietyTransaction[]
function Society.history(jobName, viewer, limit)
    local page <const> = banking:GetStatement(viewer, Society.accountId(jobName), { limit = limit })
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

---@param jobName string
---@param citizenid string
---@param amount integer
---@param description string
---@param by string
---@return boolean ok
---@return string|integer? errorOrBalance
function Society.pay(jobName, citizenid, amount, description, by)
    return banking:Transfer(Society.accountId(jobName), citizenid, amount, { note = description, initiator = by })
end

---@param jobName string
---@param citizenid string
---@param amount integer
---@param description string
---@param by string
---@return boolean ok
---@return string|integer? errorOrBalance
function Society.collect(jobName, citizenid, amount, description, by)
    return banking:Transfer(citizenid, Society.accountId(jobName), amount, {
        note = description,
        initiator = by,
        bill = true,
    })
end

---@param jobName string
---@param amount integer
---@param description string
---@param by string
---@return boolean ok
---@return string? error
function Society.spend(jobName, amount, description, by)
    local ok <const>, result <const> = banking:Withdraw(Society.accountId(jobName), amount, { note = description, initiator = by })

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
