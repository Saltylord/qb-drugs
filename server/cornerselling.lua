local stolenItems = {}

local function getAvailableDrugs(source)
    local AvailableDrugs = {}
    local Player = QBCore.Functions.GetPlayer(source)

    if not Player then return nil end

    for k in pairs(Config.DrugsPrice) do
        if k == 'weed' then
            local items = exports.ox_inventory:Search(source, 'slots', k, false)

            if items then
                for i = 1, #items do
                    AvailableDrugs[#AvailableDrugs + 1] = {
                        item = items[i].name,
                        amount = items[i].count,
                        metadata = items[i].metadata
                    }
                end
            end
        else
            local items = exports.ox_inventory:Search(source, 'slots', k, false)

            if items then
                for i = 1, #items do
                    AvailableDrugs[#AvailableDrugs + 1] = {
                        item = items[i].name,
                        amount = items[i].count,
                        label = items[i].label
                    }
                end
            end
        end
    end

    return table.type(AvailableDrugs) ~= "empty" and AvailableDrugs or nil
end

lib.callback.register('qb-drugs:server:cornerSelling:getAvailableDrugs', function(source)
    local availableDrugs = getAvailableDrugs(source)
    return availableDrugs
end)

RegisterNetEvent('qb-drugs:server:retrieveStolenDrugs', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local cid = Player.PlayerData.citizenid

    if not Player or stolenItems.citizenid ~= cid then return end

    exports.ox_inventory:AddItem(src, stolenItems.offer.item, stolenItems.offer.amount, stolenItems.offer.metadata)
end)

RegisterNetEvent('qb-drugs:server:removeStolenDrugs', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local cid = Player.PlayerData.citizenid

    if not Player or not data.coords then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - vec3(data.coords.x, data.coords.y, data.coords.z)) > 10 then return end
    stolenItems = {
        citizenid = cid,
        items = data
    }

    exports.ox_inventory:RemoveItem(src, data.offer.item, data.offer.amount, data.offer.metadata)
end)

RegisterNetEvent('qb-drugs:server:sellDrugs', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local availableDrugs = getAvailableDrugs(src)

    if not availableDrugs or not Player then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - vec3(data.coords.x, data.coords.y, data.coords.z)) > 5 then return end

    local count = exports.ox_inventory:GetItemCount(src, data.offer.item, data.offer.metadata, true)

    if count >= data.offer.amount then
        TriggerClientEvent('QBCore:Notify', src, Lang:t("success.offer_accepted"), 'success')
        exports.ox_inventory:RemoveItem(src, data.offer.item, data.offer.amount, data.offer.metadata)
        exports.ox_inventory:AddItem(source, 'money', data.offer.price)
    else
        TriggerClientEvent('qb-drugs:client:cornerselling', src)
    end
end)
