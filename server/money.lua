if Config.Framework ~= "ox" then
    return
end

while not Ox do
    Wait(500)
end

---@param source any
---@param amount integer
---@return boolean
function RemoveMoney(source, amount)
    local player = Ox.GetPlayer(source)
    local account = player.getAccount()

    if not account then
        return false
    end

    return account.removeBalance({ amount = amount, message = "Tablet" })?.success
end

---@param billerIdentifier string
---@param billedIdentifier string
---@param job "police" | "ambulance"
---@param amount number
---@param reason? string
---@return boolean success
function FrameworkBillPlayer(billerIdentifier, billedIdentifier, job, amount, reason)
    local jobAccount = Ox.GetGroupAccount(job)

    if not jobAccount then
        return false
    end

    local billedPlayer = Ox.GetPlayerFromFilter({ charId = tonumber(billedIdentifier) })
    local toAccount

    if billedPlayer then
        local billedPlayerAccount = billedPlayer.getAccount()

        toAccount = billedPlayerAccount.get("id")
    else
        toAccount = MySQL.scalar.await("SELECT `id` FROM `accounts` WHERE `owner` = ? AND isDefault = 1 LIMIT 1", {
            billedIdentifier
        })
    end

    local duePeriod = 7 * 24 * 60 * 60
    local object = jobAccount.createInvoice({
        actorId = billerIdentifier,
        toAccount = toAccount,
        amount = amount,
        message = reason,
        dueDate = os.date("%Y-%m-%d %H:%M:%S", os.time() + duePeriod),
    })

    return object.success
end
