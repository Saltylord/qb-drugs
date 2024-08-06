QBCore = exports['qb-core']:GetCoreObject()

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        createDealers()
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    createDealers()
end)