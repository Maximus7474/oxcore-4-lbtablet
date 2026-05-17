if Config.Framework ~= "ox" then
    return
end

while not Ox do
    Wait(500)
end

---@type { label: string, type: string, pointsLimit?: number | false }[]
local licenses
---@type { [string]: { label: string, type: string, pointsLimit?: number | false } }
local licenseLookup = {}

MySQL.ready(function()
    licenses = MySQL.query.await("SELECT `name` AS `type`, `label` FROM ox_licenses")

    for i = 1, #licenses do
        local license = licenses[i]
        local maxPoints = Config.MDT.MaxLicensePoints[license.type]

        if maxPoints == nil then
            maxPoints = Config.MDT.DefaultMaxLicensePoints
        end

        license.pointsLimit = maxPoints
        licenseLookup[license.type] = license
    end
end)

---@param licenseType string
---@return boolean
local function DoesLicenseExist(licenseType)
    for i = 1, #licenses do
        if licenses[i].type == licenseType then
            return true
        end
    end

    return false
end

---@param identifier string
---@param licenseType string
---@return boolean
function RevokeLicense(identifier, licenseType)
    if not DoesLicenseExist(licenseType) then
        return false
    end

    local player = Ox.GetPlayerFromFilter({ charId = tonumber(identifier) })

    if player then
        return player.removeLicense(licenseType)
    end

    return MySQL.update.await("DELETE FROM character_licenses WHERE charId = ? AND name = ?", { identifier, licenseType }) > 0
end

---@param identifier string
---@param licenseType string
---@return boolean
function AddLicense(identifier, licenseType)
    if not DoesLicenseExist(licenseType) then
        return false
    end

    local data = { }
    if licenseLookup[licenseType].pointsLimit then
        data.points = 0
    end

    local player = Ox.GetPlayerFromFilter({ charId = tonumber(identifier) })

    if player then
        local success = player.addLicense(licenseType)

        if not success then return false end

        return player.updateLicense(licenseType, 'points', data.points)
    end

    return MySQL.update.await("INSERT INTO character_licenses (charId, name, data) VALUES (?, ?, ?)", { identifier, licenseType, json.encode(data) }) > 0
end

---@param licenseType string
---@return string
function GetLicenseLabel(licenseType)
    return licenseLookup[licenseType]?.label or licenseType
end

---@return { label: string, type: string, pointsLimit?: number | false }[]
function GetAllLicenses()
    return licenses
end

---@param identifier string
---@return { type: string, label: string, points?: number, pointsLimit?: number }[]
function GetPlayerLicenses(identifier)
    local player = Ox.GetPlayerFromFilter({ charId = tonumber(identifier) })

    if player then
        local _playerLicenses = player.getLicenses()

        local playerLicenses = {}
        for k, v in pairs(_playerLicenses) do
            local licenseData = licenseLookup[k]

            playerLicenses[#playerLicenses+1] = {
                type = k,
                label = GetLicenseLabel(k),
                points = v.points,
                pointsLimit = licenseData.pointsLimit,
            }
        end

        return playerLicenses
    end

    local playerLicenses = MySQL.query.await("SELECT `name`, `data` FROM character_licenses WHERE charid = ?", { identifier })

    for i = 1, #playerLicenses do
        local license = playerLicenses[i]
        local licenseData = licenseLookup[license.name]
        local data = license.data and json.decode(license.data) or {}

        license.type = license.name
        license.label = licenseData.label
        license.points = data.points
        license.pointsLimit = licenseData.pointsLimit

        license.name = nil
        license.data = nil
    end

    return playerLicenses
end

---@param identifiers string[]
---@return { [string]: { type: string, label: string, points?: number, pointsLimit?: number }[] }
function GetMultiplePlayersLicenses(identifiers)
    if #identifiers == 0 then
        return {}
    end

    ---@type { [string]: { type: string, label: string, points?: number, pointsLimit?: number }[] }
    local identifierToLicense = {}
    ---@type string[]
    local identifiersToFetch = {}

    for i = 1, #identifiers do
        local charId = identifiers[i]
        local player = Ox.GetPlayerFromFilter({ charId = tonumber(charId) })

        if player then
            local _playerLicenses = player.getLicenses()
            identifierToLicense[charId] = {}

            debugprint('_playerLicenses', _playerLicenses)

            for licenseType, data in pairs(_playerLicenses) do
                local licenseData = licenseLookup[licenseType]

                table.insert(identifierToLicense[charId], {
                    type = licenseType,
                    label = licenseData?.label or licenseType,
                    points = data.points or (licenseData?.pointsLimit and 0 or nil),
                    pointsLimit = licenseData?.pointsLimit
                })
            end
        else
            identifiersToFetch[#identifiersToFetch + 1] = charId
        end
    end

    if #identifiersToFetch > 0 then
        ---@type { charid: number, name: string, data?: string }[]
        local playerLicenses = MySQL.query.await(
            "SELECT charid, name, data FROM character_licenses WHERE charid IN (?)",
            { identifiersToFetch }
        )

        for i = 1, #playerLicenses do
            local row = playerLicenses[i]
            local charIdStr = tostring(row.charid)
            local licenseType = row.name
            local data = row.data and json.decode(row.data) or {}
            local licenseData = licenseLookup[licenseType]

            identifierToLicense[charIdStr] = identifierToLicense[charIdStr] or {}

            table.insert(identifierToLicense[charIdStr], {
                type = licenseType,
                label = licenseData?.label or licenseType,
                points = data.points or (licenseData?.pointsLimit and 0 or nil),
                pointsLimit = licenseData?.pointsLimit
            })
        end
    end

    return identifierToLicense
end

---@param identifier string
---@param license string
---@param points number
---@return boolean
function SetPlayerLicensePoints(identifier, license, points)
    local charId = tonumber(identifier)
    local player = Ox.GetPlayerFromFilter({ charId = charId })

    if player then
        return player.updateLicense(license, 'points', points)
    else
        return MySQL.update.await([[
            UPDATE character_licenses 
            SET data = JSON_SET(IFNULL(data, '{}'), '$.points', ?) 
            WHERE charid = ? AND name = ?
        ]], { points, charId, license }) > 0
    end
end
