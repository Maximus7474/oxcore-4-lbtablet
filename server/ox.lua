if Config.Framework ~= "ox" then
    return
end

debugprint("Loading Ox")

local chunk = LoadResourceFile("ox_core", "lib/init.lua")
load(chunk, "@@ox_core/lib/init.lua", "t")()

while not Ox do
    Wait(500)
end

debugprint("Ox loaded")

---@param source number
---@return string | nil
function GetIdentifier(source)
    local identifier = Ox.GetPlayer(source)?.charId
    return identifier and tostring(identifier) or nil
end

---@param identifier string
---@return number?
function GetSourceFromIdentifier(identifier)
    local player = Ox.GetPlayerFromFilter({ charId = tonumber(identifier) })

    if player then
        return player.source
    end
end

---@param source number
---@return string firstname
---@return string lastname
function GetCharacterName(source)
    local player = Ox.GetPlayer(source)

    return player.get("firstName"), player.get("lastName")
end

---@param identifier string
---@return string?
function GetCharacterNameFromIdentifier(identifier)
    local player = Ox.GetPlayerFromFilter({ charId = tonumber(identifier) })

    if player then
        return player.get("name")
    end

    return MySQL.scalar.await("SELECT fullName FROM characters WHERE charId = ?", { identifier }) or ""
end

---@param source number
function IsAdmin(source)
    return IsPlayerAceAllowed(source, "command.lbtablet_admin") == 1
end

---@param identifier string
---@return { plate: string, type: string, vehicle: string }[]
function GetVehicles(identifier)
    return MySQL.query.await("SELECT `plate`, `data` AS `vehicle`, model, `class` AS `type` FROM `vehicles` WHERE `owner` = ?", { identifier })
end

AddEventHandler("ox:playerLogout", function(playerId)
    PlayerLoggedOut(playerId)
    TriggerClientEvent("tablet:ox:playerLogout", playerId)
end)
