QBCore = exports['qb-core']:GetCoreObject()
local availableDrugs = {}
local currentOffers = {}

local function getAvailableDrugs(source)
    local drugs = {}

    for k in pairs(Config.DrugsPrice) do
        local items = exports.ox_inventory:Search(source, 'slots', k, false)

        for i = 1, #items do
            if not next(items[i].metadata) then
                drugs[#drugs + 1] = {
                    item = items[i].name,
                    amount = items[i].count,
                    label = items[i].label
                }
            else
                drugs[#drugs + 1] = {
                    item = items[i].name,
                    amount = items[i].count,
                    metadata = items[i].metadata
                }
            end
        end
    end

    return table.type(drugs) ~= "empty" and drugs or nil
end

RegisterNetEvent('qb-drugs:server:retrieveDrugsFromNPC', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local cid = Player.PlayerData.citizenid

    if not Player or not currentOffers[cid].stolen then return end

    if currentOffers[cid].metadata then
        exports.ox_inventory:AddItem(src, currentOffers[cid].item, currentOffers[cid].amount, currentOffers[cid].metadata)
    else
        exports.ox_inventory:AddItem(src, currentOffers[cid].item, currentOffers[cid].amount)
    end

    currentOffers[cid] = {}
end)

RegisterNetEvent('qb-drugs:server:stealDrugsFromPlayer', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local cid = Player.PlayerData.citizenid

    if not Player or not currentOffers[cid].item then return end

    if currentOffers[cid].metadata then
        exports.ox_inventory:RemoveItem(src, currentOffers[cid].item, currentOffers[cid].amount, currentOffers[cid].metadata)
    else
        exports.ox_inventory:RemoveItem(src, currentOffers[cid].item, currentOffers[cid].amount)
    end

    currentOffers[cid].stolen = true
end)

RegisterNetEvent('qb-drugs:server:sellDrugs', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local cid = Player.PlayerData.citizenid

    if not Player or not currentOffers[cid].item then return end

    TriggerClientEvent('QBCore:Notify', src, Lang:t("success.offer_accepted"), 'success')

    if currentOffers[cid].metadata then
        exports.ox_inventory:RemoveItem(src, currentOffers[cid].item, currentOffers[cid].amount, currentOffers[cid].metadata)
        exports.ox_inventory:AddItem(source, 'money', currentOffers[cid].price)
    else
        exports.ox_inventory:RemoveItem(src, currentOffers[cid].item, currentOffers[cid].amount)
        exports.ox_inventory:AddItem(source, 'money', currentOffers[cid].price)
    end

    currentOffers[cid] = {}
end)

RegisterNetEvent('qb-drugs:server:createOffer', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local cid = Player.PlayerData.citizenid

    if not next(availableDrugs[cid]) or not Player then return end

    local drug = math.random(1, #availableDrugs[cid])
    local amount = math.random(1, availableDrugs[cid][drug].amount)
    if amount > 15 then amount = math.random(9, 15) end

    local drugPrice = Config.DrugsPrice[availableDrugs[cid][drug].item]
    local randomPrice = math.random(drugPrice.min, drugPrice.max) * amount
    if math.random(1, 100) <= Config.ScamChance then randomPrice = math.random(3, 10) * amount end

    if not availableDrugs[cid][drug].metadata then
        currentOffers[cid] = {
            stolen = false,
            item = availableDrugs[cid][drug].item,
            label = availableDrugs[cid][drug].label,
            amount = amount,
            price = randomPrice
        }
        return
    end

    currentOffers[cid] = {
        stolen = false,
        item = availableDrugs[cid][drug].item,
        metadata = availableDrugs[cid][drug].metadata,
        amount = amount,
        price = randomPrice
    }
end)

RegisterNetEvent('qb-drugs:server:setAvailableDrugs', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local cid = Player.PlayerData.citizenid

    if not Player then return end

    local drugs = getAvailableDrugs(src)

    if not drugs then
        TriggerClientEvent('QBCore:Notify', src, Lang:t("error.has_no_drugs"), 'error')
        TriggerClientEvent('qb-drugs:client:stopCornerSelling', src)
        return
    end

    availableDrugs[cid] = drugs
    TriggerClientEvent('QBCore:Notify', src, Lang:t("info.started_selling_drugs"))
end)

RegisterNetEvent('qb-drugs:server:clearOffer', function()
    local Player = QBCore.Functions.GetPlayer(source)
    local cid = Player.PlayerData.citizenid

    if not Player then return end

    currentOffers[cid] = {}
end)

RegisterNetEvent('qb-drugs:server:cancelSelling', function()
    local Player = QBCore.Functions.GetPlayer(source)
    local cid = Player.PlayerData.citizenid

    if not Player then return end

    if not currentOffers[cid].stolen then
        currentOffers[cid] = {}
    end

    availableDrugs[cid] = {}
end)

lib.callback.register('qb-drugs:callback:getCurrentOffer', function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    local cid = Player.PlayerData.citizenid
    return currentOffers[cid]
end)