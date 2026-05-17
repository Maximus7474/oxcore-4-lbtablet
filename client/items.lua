if Config.Framework ~= "ox" then
    return
end

while not Ox do
    Wait(500)
    debugprint("Item: Waiting for Ox to load")
end

---@return boolean
function HasItem()
    return (exports.ox_inventory:Search("count", Config.Item.Name) or 0) > 0
end

AddEventHandler("ox_inventory:itemCount", function(itemName, totalCount)
    if not Config.Item.Require or itemName ~= Config.Item.Name or totalCount > 0 then
        return
    end

    OnItemCountChange()
end)
