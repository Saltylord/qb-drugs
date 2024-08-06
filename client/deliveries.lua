local dealers = require 'data.dealers'
local peds = {}


function createDealers()

    for k,v in pairs(dealers) do

        for i = 1, #v.coords do
            QBCore.Functions.LoadModel(v.model)
            local ped = CreatePed(0, v.model, v.coords[i].x, v.coords[i].y, v.coords[i].z - 1, false, false)
            print(ped)
            PlaceObjectOnGroundProperly(ped)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            FreezeEntityPosition(ped, true)

            local dealer = {
                id = ped,
                type = k,
                coords = vec3(v.coords[i].x, v.coords[i].y, v.coords[i].z)
            }

            peds[#peds + 1] = dealer

            local option = {
                name = k..'_dealer_'..i,
                icon = 'fa-solid fa-id-card',
                distance = 2.0,
                label = 'Speaker to dealer',
                onSelect = function()
                    print('test')
                end
            }

            exports.ox_target:addLocalEntity(dealer.id, option)
        end

    end
end
