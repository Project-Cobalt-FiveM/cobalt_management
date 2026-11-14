local db <const> = require 'server.jobs.db'
local Jobs <const> = require 'server.jobs.registry'
local Society <const> = require 'server.jobs.society'
local Util <const> = require 'server.util'

local core <const> = exports.cobalt_core

---@class CatalogueVehicle
---@field model string
---@field label string
---@field use string
---@field minGrade integer
---@field minRank string
---@field price integer

local Vehicles <const> = {}

local RANDOM_PLATE_TRIES <const> = 10

---@param model string
---@return string
local function labelOf(model)
    return core:GetShared('Vehicles', model)?.name or model
end

---@param jobName string
---@return CatalogueVehicle[]
function Vehicles.catalogue(jobName)
    local out <const> = {}

    for _, vehicle in ipairs(Jobs.vehicles(jobName)?.catalogue or {}) do
        local grade <const> = Jobs.grade(jobName, vehicle.grade)
        local minRank <const> = vehicle.grade == 0 and locale('vehicles.everyone')
            or grade?.name
            or locale('job.grade_fallback', vehicle.grade)

        out[#out + 1] = {
            model = vehicle.model,
            label = labelOf(vehicle.model),
            use = locale(('vehicles.role.%s'):format(vehicle.role)),
            minGrade = vehicle.grade,
            minRank = minRank,
            price = vehicle.price,
        }
    end

    return out
end

---@param jobName string
---@return string
local function nextPlate(jobName)
    local prefix <const> = (Jobs.vehicles(jobName)?.plate or jobName:sub(1, 4)):upper():sub(1, 4)
    local fleet <const> = db.fleetPlates()

    ---@param plate string
    ---@return boolean
    local function free(plate)
        return not fleet[plate] and not core:GetVehicleOwnerByPlate(plate)
    end

    for number = 0, 99 do
        local plate <const> = ('%s %02d'):format(prefix, number)

        if free(plate) then return plate end
    end

    for _ = 1, RANDOM_PLATE_TRIES do
        local plate <const> = ('%s%04d'):format(prefix, math.random(0, 9999)):sub(1, 8)

        if free(plate) then return plate end
    end

    return core:GeneratePlate()
end

---@param actor Actor
---@param model unknown
---@return boolean ok
---@return string? error
function Vehicles.buy(actor, model)
    local jobName <const> = actor.job.name
    local vehicle

    for _, entry in ipairs(Jobs.vehicles(jobName)?.catalogue or {}) do
        if entry.model == model then vehicle = entry end
    end

    if not vehicle then
        return false, locale('vehicles.not_for_sale')
    end

    local plate <const> = nextPlate(jobName)
    local label <const> = labelOf(vehicle.model)
    local description <const> = locale('society.vehicle_bought', label, plate)
    local reserved <const> = db.addVehicle({
        plate = plate,
        job = jobName,
        model = vehicle.model,
        label = label,
        price = vehicle.price,
        by = actor.name,
    })

    if not reserved then
        return false, locale('vehicles.fleet_full')
    end

    if vehicle.price > 0 then
        local ok <const>, err <const> = Society.spend(jobName, vehicle.price, description, actor.citizenid)

        if not ok then
            db.removeVehicle(jobName, plate)

            return false, err
        end
    end

    local cost <const> = Util.money(vehicle.price)

    Util.log(jobName, 'Vehicle', ('%s bought %s, plate %s, for %s'):format(actor.name, label, plate, cost))

    return true
end

---@param jobName string
---@return { plate: string, model: string, label: string, boughtBy: string, boughtAt: string }[]
function Vehicles.fleet(jobName)
    return db.fleet(jobName)
end

return Vehicles
