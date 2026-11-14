local db <const> = require 'server.db'
local Orgs <const> = require 'server.orgs'
local Society <const> = require 'server.society'
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

---@param orgName string
---@return CatalogueVehicle[]
function Vehicles.catalogue(orgName)
    local out <const> = {}

    for _, vehicle in ipairs(Orgs.vehicles(orgName)?.catalogue or {}) do
        local grade <const> = Orgs.grade(orgName, vehicle.grade)
        local minRank <const> = vehicle.grade == 0 and locale('vehicles.everyone')
            or grade?.name
            or locale('org.grade_fallback', vehicle.grade)

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

---@param orgName string
---@return string
local function nextPlate(orgName)
    local prefix <const> = (Orgs.vehicles(orgName)?.plate or orgName:sub(1, 4)):upper():sub(1, 4)
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
    local orgName <const> = actor.org.name
    local vehicle

    for _, entry in ipairs(Orgs.vehicles(orgName)?.catalogue or {}) do
        if entry.model == model then vehicle = entry end
    end

    if not vehicle then
        return false, locale('vehicles.not_for_sale')
    end

    local plate <const> = nextPlate(orgName)
    local label <const> = labelOf(vehicle.model)
    local description <const> = locale('society.vehicle_bought', label, plate)
    local reserved <const> = db.addVehicle({
        plate = plate,
        org = orgName,
        model = vehicle.model,
        label = label,
        price = vehicle.price,
        by = actor.name,
    })

    if not reserved then
        return false, locale('vehicles.fleet_full')
    end

    if vehicle.price > 0 then
        local ok <const>, err <const> = Society.spend(orgName, vehicle.price, description, actor.citizenid)

        if not ok then
            db.removeVehicle(orgName, plate)

            return false, err
        end
    end

    local cost <const> = Util.money(vehicle.price)

    Util.log(orgName, 'Vehicle', ('%s bought %s, plate %s, for %s'):format(actor.name, label, plate, cost))

    return true
end

---@param orgName string
---@return { plate: string, model: string, label: string, boughtBy: string, boughtAt: string }[]
function Vehicles.fleet(orgName)
    return db.fleet(orgName)
end

return Vehicles
