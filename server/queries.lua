if Config.Framework ~= "ox" then
    return
end

while not Ox do
    Wait(500)
end

MySQL.ready(function()
    while not GetCollationsForTables do
        Wait(0)
    end

    local collations = GetCollationsForTables({
        users = "charId",
        owned_vehicles = "plate"
    })

    UsersCollate = collations.users or ""
    VehiclesCollate = collations.owned_vehicles or ""
end)

Queries = {}

Queries.Users = {}

Queries.Users = {}
Queries.Users.Table = "characters"
Queries.Users.Select = {
    identifier = "CAST(user.charId AS CHAR)",
    name = "user.fullName",
    dob = "CAST(DATE_FORMAT(user.dateOfBirth, '%d/%m/%Y') AS CHAR)",
    isMale = "user.gender = 'male'",
}

Queries.Users.Filter = {}
Queries.Users.Filter.Jobs = "EXISTS (SELECT 1 FROM character_groups `group` WHERE group.charId = user.charId AND `name` IN (?))"
Queries.Users.Filter.Gender = "user.gender = ?"
Queries.Users.Filter.License = "EXISTS (SELECT 1 FROM character_licenses license WHERE license.owner = user.charId AND license.`name` = ?)"

-- if Config.JailScript == "qalle" then
--     Queries.Users.Filter.ExcludeJailed = "user.jail = 0"
-- elseif Config.JailScript == "esx" then
--     Queries.Users.Filter.ExcludeJailed = "user.jail_time = 0"
-- elseif Config.JailScript == "pickle" then
--     Queries.Users.Filter.ExcludeJailed = "NOT EXISTS (SELECT 1 FROM pickle_prisons WHERE identifier = user.identifier {USERS_COLLATE})"
-- elseif Config.JailScript == "rcore" then
--     Queries.Users.Filter.ExcludeJailed = "NOT EXISTS (SELECT 1 FROM rcore_prison WHERE owner = user.identifier {USERS_COLLATE})"
-- end

Queries.Users.FetchProfile = [[
    SELECT
        CAST(user.charId AS CHAR) AS id,
        profile.id AS profileId,
        profile.avatar,
        user.fullName AS `name`,
        CAST(DATE_FORMAT(user.dateOfBirth, '%d/%m/%Y') AS CHAR) AS dob,
        NULL as height,
        user.gender = "male" AS isMale,
        grade.label AS jobGrade,
        grp.label AS job

    FROM characters user

    LEFT JOIN lbtablet_mdt_profiles profile ON
        profile.profile_id = user.charId {USERS_COLLATE}
        AND profile.profile_type = 'player'
        AND profile.department = ?

    LEFT JOIN character_groups user_group ON user_group.charId = user.charId AND isActive = 1
    LEFT JOIN ox_groups grp ON grp.`name` = user_group.`name`
    LEFT JOIN ox_group_grades grade ON grade.`group` = user_group.name

    WHERE user.charId = ?

    GROUP BY user.charId, user.fullName, user.dateOfBirth, user.gender, profile.avatar
]]

Queries.Vehicles = {}
Queries.Vehicles.Table = "vehicles"
Queries.Vehicles.Select = {
    plate = "vehicle.plate",
    owner = "vehicle.owner",
    vehicle = "vehicle.data",
    model = "vehicle.model",
}

Queries.Vehicles.BasicFetch = "SELECT data AS vehicle FROM vehicles WHERE plate = ?"
