if Config.Framework ~= "ox" then
    return
end

---@param source number
function IsOnDuty(source)
    local player = Ox.GetPlayer(source)

    return player and player.getGroupByType('job') == player.get('activeGroup')
end

---@param source number
---@return { name: string, label: string, grade: number, grade_label: string }
function GetJob(source)
    local player = Ox.GetPlayer(source)

    if not player then
        return {}
    end

    local job = {}

    job.name = player.getGroupByType('job')

    if not job.name then
        return {}
    end

    local group = GlobalState["group." .. job.name]

    job.label = group.label
    job.grade = player.getGroup(job.name)
    job.grade_label = group.grades[job.grade]

    return job
end

---@param jobs string | string[]
---@return { grades: { [string]: { grade: number, label: string }[] }, labels: { [string]: string } }
function GetJobGrades(jobs)
    if type(jobs) == "string" then
        jobs = { jobs }
    end

    local grades = {}
    local labels = {}

    for i = 1, #jobs do
        local job = jobs[i]
        local group = GlobalState["group." .. job]

        if not group then
            debugprint("Group not found", job)
            goto continue
        end

        grades[job] = {}
        labels[job] = group.label

        for grade, label in pairs(group.grades) do
            grades[job][grade] = {
                grade = grade,
                label = label
            }
        end

        ::continue::
    end

    return {
        grades = grades,
        labels = labels
    }
end

---@param companies string[]
function GetEmployees(companies)
    local query = ([[
        SELECT c.charId AS id,
        a.callsign,
        a.avatar,
        c.fullName AS `name`,
        cg.`name` AS job,
        cg.grade AS `rank`
        %s

        FROM character_groups cg
        LEFT JOIN characters c ON cg.charId = c.charId
        LEFT JOIN lbtablet_police_accounts a ON a.id = c.charId %s
        %s

        WHERE cg.`name` IN (?)
    ]]):format("%s", UsersCollate, "%s")

    if Config.LBPhone then
        local phoneConfig = GetPhoneConfig()

        if phoneConfig?.Item?.Unique then
            query = query:format(
                ", p.phone_number AS phoneNumber",
                ("LEFT JOIN phone_last_phone p ON c.charId %s = p.id"):format(UsersCollate)
            )
        else
            query = query:format(
                ", p.phone_number AS phoneNumber",
                ("LEFT JOIN phone_phones p ON c.charId %s = p.id"):format(UsersCollate)
            )
        end
    else
        query = query:format("", "")
    end

    return MySQL.query.await(query, { companies })
end

---@param jobs { [string]: any }
---@return { source: number, name: string, rank: string, identifier: string }[]
function GetOnDutyEmployees(jobs)
    local employees = {}
    local groups = {}

    for job in pairs(jobs) do
        groups[#groups+1] = job
    end

    local players = Ox.GetPlayers( { groups = groups } )

    for i = 1, #players do
        local player = players[i]
        local group, grade = player.getGroup(groups)
        local grades = GlobalState["group." .. group].grades

        employees[#employees+1] = {
            source = player.source,
            name = player.get("name"),
            rank = grades[grade],
            identifier = tostring(player.charId)
        }
    end

    return employees
end

---@param jobs string | string[]
---@return string[]
function GetIdentifiersWithJob(jobs)
    if type(jobs) == "string" then
        jobs = { jobs }
    end

    local identifiers = MySQL.query.await("SELECT charId FROM character_groups WHERE name IN (?)", { jobs })
    local result = {}

    for i = 1, #identifiers do
        result[i] = tostring(identifiers[i].charId)
    end

    return result
end

AddEventHandler("ox:setActiveGroup", function(playerId, groupName)
    Wait(0)
    TriggerEvent("lb-tablet:jobUpdated", playerId, groupName, IsOnDuty(playerId))
end)
