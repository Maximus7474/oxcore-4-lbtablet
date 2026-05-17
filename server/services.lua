if Config.Framework ~= "ox" then
    return
end

while not Ox do
    Wait(500)
end

---@param company string
function GetEmployeeList(company)
    local numberTable = Config.LBPhone and (GetPhoneConfig()?.Item?.Unique and "phone_last_phone" or "phone_phones") or nil
    local joinPhone = Config.LBPhone and ("LEFT JOIN %s p ON c.charId %s = p.id"):format(numberTable, UsersCollate) or ""

    local employees = MySQL.query.await([[
        SELECT
            c.charId,
            c.firstName AS firstname,
            c.lastName AS lastname,
            cg.grade AS grade,
            gg.label AS gradeLabel
            ]] .. (Config.LBPhone and ", p.phone_number AS `number`" or "") .. [[

        FROM character_groups cg
        LEFT JOIN characters c ON c.charId = cg.charId
        LEFT JOIN ox_group_grades gg ON gg.group = cg.`name` AND gg.grade = cg.grade
        ]] .. joinPhone .. [[
        WHERE cg.`name` = ?
        ORDER BY cg.grade DESC
    ]], { company })

    for i = 1, #employees do
        local employee = employees[i]

        employee.online = Ox.GetPlayerFromFilter({ charId = employee.charId }) and true or false
    end

    return employees
end

function RefreshCompanies()
    for i = 1, #Config.Services.Companies do
        local jobData = Config.Services.Companies[i]
        local jobKey = ("%s:count"):format(jobData.job)

        jobData.open = (GlobalState[jobKey] or 0) > 0
        debugprint("Job", jobData.job, "is open:", jobData.open)
    end
end

for i = 1, #Config.Services.Companies do
    local jobData = Config.Services.Companies[i]
    local jobKey = ("%s:count"):format(jobData.job)

    AddStateBagChangeHandler(jobKey, "global", function(_, _, value)
        Wait(0) -- prevent print from showing in F8 when using command

        if type(value) ~= "number" then
            return
        end

        local isOpen = value > 0

        if jobData.open ~= isOpen then
            jobData.open = isOpen
            TriggerClientEvent("tablet:services:updateOpen", -1, jobData.job, isOpen)
        end

        debugprint(("Job count for job ^5%s^7 changed. Is open: %s"):format(jobData.job, jobData.open))
    end)
end

---@param group string
---@param grade number
---@return string
local function getGradeRole(group, grade)
    local accountRoles = GlobalState["group." .. group]?.accountRoles
    return accountRoles[tostring(grade)]
end

---@param role string
---@return boolean
local function roleHasPermission(role, permission)
    return GlobalState["accountRole." .. role][permission] == 1
end

local canInteractPermissions = { "addUser", "removeUser", "manageUser" }

---@param group string
---@param grade number
---@return boolean
local function canInteract(group, grade)
    local role = getGradeRole(group, grade)

    for _, permission in pairs(canInteractPermissions) do
        if roleHasPermission(role, permission) then
            return true
        end
    end

    return false
end

---@param playerId number
---@return string?, number?
local function getGroupIfAuthorized(playerId, permission)
    local player = Ox.GetPlayer(playerId)
    local group = player.get("activeGroup")

    if not group then
        return
    end

    local grade = player.getGroup(group)
    local role = getGradeRole(group, grade)

    if roleHasPermission(role, permission) then
        return group, grade
    end
end

BaseCallback("services:getBalance", function(source)
    local player = Ox.GetPlayer(source)
    local group = player.get("activeGroup")

    if not group then
        return 0
    end

    local account = Ox.GetGroupAccount(group)

    if not account then
        return "No account"
    end

    local grade = player.getGroup(group)
    local role = getGradeRole(group, grade)

    if not role then
        return "No permission"
    end

    return account.get("balance")
end)

BaseCallback("services:getEmployees", function(source)
    local group, grade = getGroupIfAuthorized(source, "manageUser")

    if not group then
        return {}
    end

    local employees = MySQL.query.await([[
        SELECT
            c.charId AS id,
            c.fullName AS `name`,
            cg.grade,
            gg.label AS gradeLabel
        FROM character_groups cg
        LEFT JOIN characters c ON cg.charId = c.charId
        LEFT JOIN ox_group_grades gg ON cg.`name` = gg.group AND cg.grade = gg.grade
        WHERE cg.`name` = ?
        ORDER BY cg.grade DESC
    ]], { group })
    local _canInteract = canInteract(group, grade)

    for i = 1, #employees do
        local employee = employees[i]

        employee.canInteract = _canInteract

        employee.online = Ox.GetPlayerFromFilter({ charId = employee.id }) and true or false
    end

    return employees
end)

BaseCallback("services:depositMoney", function(source, phoneNumber, amount)
    local player = Ox.GetPlayer(source)
    local group = getGroupIfAuthorized(source, 'deposit')

    if not group then
        return false, "NO_PERMISSION"
    end

    local formAccount = player.getAccount()
    local toAccount = Ox.GetGroupAccount(group)

    if not formAccount or not toAccount then
        return false, "NO_ACCOUNT"
    end

    local result = formAccount.transferBalance({
        toId = toAccount.get("id"),
        amount = amount,
        message = "Tablet deposit",
        actorId = player.charId
    })
    local balance = result?.success and toAccount.get("balance") or false

    return balance, result?.message
end)

BaseCallback("services:withdrawMoney", function(source, phoneNumber, amount)
    local player = Ox.GetPlayer(source)
    local group = getGroupIfAuthorized(source, 'withdraw')

    if not group then
        return false, "NO_PERMISSION"
    end

    local formAccount = Ox.GetGroupAccount(group)
    local toAccount = player.getAccount()

    if not formAccount or not toAccount then
        return false, "NO_ACCOUNT"
    end

    local result = formAccount.transferBalance({
        toId = toAccount.get("id"),
        amount = amount,
        message = "Tablet withdraw",
        actorId = player.charId
    })
    local balance = result?.success and formAccount.get("balance") or false

    return balance, result?.message
end)

BaseCallback("services:hireEmployee", function(source, phoneNumber, targetSource)
    local group = getGroupIfAuthorized(source, "addUser")

    if not group then
        return false, "NO_PERMISSION"
    end

    local tPlayer = Ox.GetPlayer(targetSource)

    if not tPlayer then
        return false, "PLAYER_DOES_NOT_EXIST"
    end

    if tPlayer.getGroup(group) then
        return false, "PLAYER_ALREADY_EMPLOYED"
    end

    if not tPlayer.setGroup(group, 1) then
        return false, "SOMETHING_WENT_WRONG"
    end

    return {
        name = tPlayer.get("name"),
        id = tPlayer.charId
    }
end)

BaseCallback("services:fireEmployee", function(source, phoneNumber, identifier)
    local group = getGroupIfAuthorized(source, "removeUser")

    if not group then
        return false, "NO_PERMISSION"
    end

    local tPlayer = Ox.GetPlayerFromFilter({ charId = tonumber(identifier) })

    if tPlayer then
        if not tPlayer.setGroup(group, 0) then
            return false, "SOMETHING_WENT_WRONG"
        end
    else
        if not (MySQL.update.await("DELETE FROM character_groups WHERE name = ? AND charId = ?", { group, identifier }) > 0) then
            return false, "EMPLOYEE_NOT_FOUND"
        end
    end

    return true
end)

BaseCallback("services:setGrade", function (source, phoneNumber, identifier, newGrade)
    local group = getGroupIfAuthorized(source, "manageUser")

    if not group then
        return false, "NO_PERMISSION"
    end

    local tPlayer = Ox.GetPlayerFromFilter({ charId = tonumber(identifier) })

    if tPlayer then
        if not tPlayer.setGroup(group, newGrade) then
            return false, "SOMETHING_WENT_WRONG"
        end
    else
        if not (MySQL.update.await("UPDATE character_groups SET grade = ? WHERE name = ? AND charId = ?", { newGrade, group, identifier }) > 0) then
            return false, "EMPLOYEE_NOT_FOUND"
        end
    end

    return true
end)

RegisterNetEvent("tablet:services:toggleDuty", function()
    local player = Ox.GetPlayer(source)

    if not player then return end

    local job = player.getGroupByType('job')
    local activeGroup = player.get('activeGroup')

    if job == activeGroup then
        player.setActiveGroup(nil)
    else
        player.setActiveGroup(job, true)
    end
end)
