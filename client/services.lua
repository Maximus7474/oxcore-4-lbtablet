if Config.Framework ~= "ox" then
    return
end

while not Ox do
    Wait(500)
    debugprint("Services: Waiting for Ox to load")
end

---@return string
function GetJob()
    return OxPlayer.getGroupByType('job') or 'unemployed'
end

---@return boolean
function IsOnDuty()
    return OxPlayer.get("activeGroup") == GetJob()
end

---@return number
function GetJobGrade()
    local job = OxPlayer.getGroupByType('job')

    if not job then
        return 0
    end

    return OxPlayer.getGroup(job)
end

RegisterNetEvent("ox:player:activeGroup", function(value)
    print('ox:player:activeGroup', value)
    if GetJob() == value then
        SendNUIAction("services:setDuty", job.onDuty)
        return
    end

    Wait(0)
    TriggerEvent("lb-tablet:jobUpdated")
    SendNUIAction("services:setCompany", GetCompanyData())
end)

RegisterNetEvent("ox:setGroup", function(groupName, grade)
    local groupData = GlobalState["group." .. groupName]
    if groupData.type ~= "job" then return end

    Wait(0)

    TriggerEvent("lb-tablet:jobUpdated")
    SendNUIAction("services:setCompany", GetCompanyData())
end)

function GetCompanyData()
    local companyData = {
        duty = true,
        receiveCalls = GetCompanyCallsStatus and GetCompanyCallsStatus()
    }

    companyData.job = OxPlayer.get("activeGroup")

    if not companyData.job then
        return {}
    end

    local myGrade = OxPlayer.getGroup(companyData.job)
    local group = GlobalState["group." .. companyData.job]
    local grades = {}

    for grade, label in pairs(group.grades) do
        grades[grade] = {
            label = label,
            grade = grade
        }
    end

    companyData.jobLabel = group?.label
    companyData.isBoss = group?.accountRoles[tostring(myGrade)] and true or false
    companyData.balance = AwaitCallback("services:getBalance")
    companyData.employees = AwaitCallback("services:getEmployees")
    companyData.grades = grades

    local timeout = GetGameTimer() + 2000

    while not companyData.balance or not companyData.employees or not companyData.grades do
        Wait(0)

        if GetGameTimer() > timeout then
            infoprint("error", "Failed to get company data (timed out after 2s)")
            print("balance: " .. tostring(companyData.balance))
            print("employees: " .. tostring(companyData.employees))
            print("grades: " .. tostring(companyData.grades))

            companyData.employees = companyData.employees or {}
            companyData.balance = companyData.balance or 0
            companyData.grades = companyData.grades or {}
            break
        end
    end

    return companyData
end

function DepositMoney(amount)
    local balance, errMsg = AwaitCallback("services:depositMoney", amount)

    if errMsg then
        Wait(500)

        exports["lb-tablet"]:SetPopUp({
            title = L("APPS.SERVICES.DEPOSIT_POPUP.TITLE"),
            description = L("APPS.SERVICES.DEPOSIT_POPUP." .. errMsg:upper()),
            buttons = {
                {
                    title = "OK"
                }
            },
            close = function() end
        })
    end

    return balance
end

function WithdrawMoney(amount)
    local balance, errMsg = AwaitCallback("services:withdrawMoney", amount)

    if errMsg then
        Wait(500)

        exports["lb-tablet"]:SetPopUp({
            title = L("APPS.SERVICES.WITHDRAW_POPUP.TITLE"),
            description = L("APPS.SERVICES.WITHDRAW_POPUP." .. errMsg:upper()),
            buttons = {
                {
                    title = "OK"
                }
            },
            close = function() end
        })
    end

    return balance
end

function HireEmployee(source)
    local employee, errMsg = AwaitCallback("services:hireEmployee", source)

    if errMsg then
        Wait(500)

        exports["lb-tablet"]:SetPopUp({
            title = L("APPS.SERVICES.HIRE_POPUP.TITLE"),
            description = L("APPS.SERVICES.HIRE_POPUP." .. errMsg:upper()),
            buttons = {
                {
                    title = "OK"
                }
            },
            close = function() end
        })
    end

    return employee
end

function FireEmployee(id)
    local success, errMsg = AwaitCallback("services:fireEmployee", id)

    if errMsg then
        Wait(500)

        exports["lb-tablet"]:SetPopUp({
            title = L("APPS.SERVICES.FIRE_POPUP.TITLE"),
            description = L("APPS.SERVICES.FIRE_POPUP." .. errMsg:upper()),
            buttons = {
                {
                    title = "OK"
                }
            },
            close = function() end
        })
    end

    return success
end

function SetGrade(id, grade)
    local success, errMsg = AwaitCallback("services:setGrade", id, grade)

    if errMsg then
        Wait(500)

        exports["lb-tablet"]:SetPopUp({
            title = L("APPS.SERVICES.GRADE_POPUP.TITLE"),
            description = L("APPS.SERVICES.GRADE_POPUP." .. errMsg:upper()),
            buttons = {
                {
                    title = "OK"
                }
            },
            close = function() end
        })
    end

    return success
end

function ToggleDuty()
    TriggerServerEvent("tablet:services:toggleDuty")
end
