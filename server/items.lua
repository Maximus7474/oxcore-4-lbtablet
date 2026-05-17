if Config.Framework ~= "ox" then
    return
end

while not Ox do
    Wait(500)
end

---@param source number
---@param itemName string
function HasItem(source, itemName)
    return (exports.ox_inventory:Search(source, "count", itemName) or 0) > 0
end

---@param weapon string
---@return string?
function GetWeaponName(weapon)
    return exports.ox_inventory:Items(weapon)?.label
end

---@param weapon string
---@return string?
function GetWeaponImage(weapon)
    weapon = weapon:upper()

    local fileName = "web/images/" .. weapon .. ".png"
    local fileExists = LoadResourceFile("ox_inventory", fileName)

    if fileExists then
        return "https://cfx-nui-ox_inventory/" .. fileName
    end
end
