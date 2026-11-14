local Util <const> = require 'server.util'

local db <const> = {}

local VAULT_LOG_LIMIT <const> = 50

local DEBIT_VAULT <const> = 'UPDATE gangs SET vault_balance = vault_balance - ?, ' .. Util.appendCapped('vault_log') .. ' WHERE name = ? AND vault_balance >= ?'
local CREDIT_VAULT <const> = 'UPDATE gangs SET vault_balance = vault_balance + ?, ' .. Util.appendCapped('vault_log') .. ' WHERE name = ?'

---@param gang GangRecord
---@return string?
local function encodePermissions(gang)
    return gang.permissions and json.encode(gang.permissions) or nil
end

---@return GangRecord[]
function db.all()
    local rows <const> = MySQL.query.await(
        'SELECT name, label, founder, UNIX_TIMESTAMP(founded_at) AS foundedAt, permissions FROM gangs'
    ) or {}
    local out <const> = {}

    for index, row in ipairs(rows) do
        out[index] = {
            name = row.name,
            label = row.label,
            founderCid = row.founder,
            foundedAt = Util.whole(row.foundedAt),
            permissions = Util.decode(row.permissions),
        }
    end

    return out
end

---@param gang GangRecord
---@return boolean inserted false when the name or label is taken
function db.insert(gang)
    return MySQL.update.await(
        'INSERT IGNORE INTO gangs (name, label, founder, founded_at, permissions) VALUES (?, ?, ?, FROM_UNIXTIME(?), ?)',
        { gang.name, gang.label, gang.founderCid, gang.foundedAt, encodePermissions(gang) }
    ) == 1
end

---@param gang GangRecord
function db.save(gang)
    MySQL.update.await(
        'UPDATE gangs SET label = ?, permissions = ? WHERE name = ?',
        { gang.label, encodePermissions(gang), gang.name }
    )
end

---@param name string
function db.delete(name)
    MySQL.update.await('DELETE FROM gangs WHERE name = ?', { name })
end

---@param gangName string
---@return integer
function db.vaultBalance(gangName)
    return MySQL.scalar.await('SELECT vault_balance FROM gangs WHERE name = ?', { gangName }) or 0
end

---@param gangName string
---@param amount integer
---@param what string
---@param who string
---@return boolean debited
function db.debitVault(gangName, amount, what, who)
    local entry <const> = json.encode({ at = os.time(), what = what, who = who, amount = -amount })

    return MySQL.update.await(DEBIT_VAULT, { amount, VAULT_LOG_LIMIT, entry, gangName, amount }) == 1
end

---@param gangName string
---@param amount integer
---@param cap integer
---@param what string
---@param who string
---@return integer credited
function db.creditVault(gangName, amount, cap, what, who)
    local credited = 0

    local committed <const> = MySQL.startTransaction(function(query)
        local row <const> = query('SELECT vault_balance FROM gangs WHERE name = ? FOR UPDATE', { gangName })[1]

        if not row then return false end

        credited = math.max(0, math.min(amount, cap - row.vault_balance))

        if credited == 0 then return false end

        local entry <const> = json.encode({ at = os.time(), what = what, who = who, amount = credited })

        query(CREDIT_VAULT, { credited, VAULT_LOG_LIMIT, entry, gangName })
    end)

    return committed and credited or 0
end

---@param gangName string
---@return { id: integer, at: string, what: string, who: string, amount: integer }[]
function db.vaultLog(gangName)
    local stored <const> = Util.decode(MySQL.scalar.await('SELECT vault_log FROM gangs WHERE name = ?', { gangName })) or {}
    local out <const> = {}

    for index = #stored, 1, -1 do
        local entry <const> = stored[index]

        out[#out + 1] = { id = entry.id, at = Util.iso(entry.at) --[[@as string]], what = entry.what, who = entry.who, amount = entry.amount }
    end

    return out
end

return db
