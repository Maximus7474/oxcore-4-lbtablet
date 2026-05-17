if Config.Framework ~= "ox" then
    return
end

debugprint("Loading Ox")

local chunk = LoadResourceFile("ox_core", "lib/init.lua")
load(chunk, "@@ox_core/lib/init.lua", "t")()

OxPlayer = Ox.GetPlayer()

RegisterNetEvent("ox:playerLoaded", function()
    TriggerServerEvent("lb-tablet:frameworkLoaded")
end)

RegisterNetEvent("tablet:ox:playerLogout", function()
    FrameworkLoaded = false

    LogOut()

    repeat
        OxPlayer = Ox.GetPlayer()
        Wait(500)
    until OxPlayer.charId

    FrameworkLoaded = true
    FetchTabletData()
end)

while not OxPlayer.charId do
    Wait(500)
end

TriggerServerEvent("lb-tablet:frameworkLoaded")

function FormatVehicle(vehicle)
    vehicle.model = GetVehicleLabel(vehicle.model)

    local properties = json.decode(vehicle.vehicle)?.properties
    vehicle.vehicle = nil

    if properties then
        vehicle.color = GetVehicleColor(properties.color1 or properties.color2)
    end

    if vehicle.name then
        vehicle.owner = {
            name = vehicle.name,
            identifier = vehicle.owner
        }

        vehicle.name = nil
    end

    return vehicle
end

---@return boolean
function IsAdmin()
    ---@diagnostic disable-next-line: redundant-return-value
    return AwaitCallback("isAdmin")
end

local weaponList

function GetWeaponsList()
    if weaponList then
        return weaponList
    end

    weaponList = {}

    local invchunk = LoadResourceFile("ox_inventory", "data/weapons.lua")
    local rawweapondata = load(invchunk, "@@ox_inventory/data/weapons.lua", "t")()

    for spawn, data in pairs(rawweapondata.Weapons) do
        local label = data.label
        local model = spawn

        if label and model then
            weaponList[#weaponList + 1] = {
                model = model,
                label = label
            }
        end
    end

    table.sort(weaponList, function(a, b)
        return a.label < b.label
    end)

    return weaponList
end

debugprint("Ox loaded")

FrameworkLoaded = true
