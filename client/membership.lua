local Membership <const> = {}

---@type ManagementJob?
local job

---@type ManagementGang?
local gang

---@param nextJob? ManagementJob
---@param nextGang? ManagementGang
local function store(nextJob, nextGang)
    job = nextJob
    gang = nextGang
end

---@return ManagementJob?
function Membership.job()
    return job
end

---@return ManagementGang? gang nil when the player is in no gang
function Membership.gang()
    if not gang or gang.name == 'none' then return end

    return gang
end

---@return boolean
function Membership.onDuty()
    return job?.onduty == true
end

RegisterNetEvent('cobalt_management:membershipChanged', store)

RegisterNetEvent('cobalt_core:Client:OnPlayerUnload', function() store(nil, nil) end)

local playerData <const> = exports.cobalt_core:GetPlayerData()

store(playerData?.job, playerData?.gang)

return Membership
