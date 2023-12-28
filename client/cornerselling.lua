local cornerSelling = false
local npcs = {
    selected = {
        ped = nil,
        coords = nil
    },
    available = {},
    used = {}
}

local CurrentCops = 0

local function cancelSelling()
    QBCore.Functions.Notify(Lang:t("error.too_far_away"), 'error')
    LocalPlayer.state.invBusy = false
    npcs.selected.ped = nil
    cornerSelling = false
end

-- Fixed:
-- swapped the condition to `random <= Config.PoliceCallChance` so "Config.PoliceCallChance", represents the call probability.
local function PoliceCall()
    local random = math.random(1, 100)
    if random <= Config.PoliceCallChance then
        TriggerServerEvent('police:server:policeAlert', 'Drug sale in progress')
    end
end

local function acceptOffer(offer)
    local ped = PlayerPedId()

    if IsPedInAnyVehicle(ped, false) then
        QBCore.Functions.Notify(Lang:t("error.in_vehicle"), 'error')
        SetPedKeepTask(npcs.selected.ped, false)
        SetEntityAsNoLongerNeeded(npcs.selected.ped)
        ClearPedTasksImmediately(npcs.selected.ped)
        npcs.used[#npcs.used + 1] = npcs.selected.ped
        return
    end

    if math.random(1,100) <= Config.RobberyChance then
        local coords = GetEntityCoords(player)
        local npcCoords = GetEntityCoords(npcs.selected.ped)
        local selectedCoords = {x = coords.x + math.random(100, 500), y = coords.y + math.random(100, 500), z = coords.z}
        local stealing = true
        local data = {
            offer = offer,
            coords = npcCoords
        }

        TriggerServerEvent('qb-drugs:server:removeStolenDrugs', data)
        npcs.used[#npcs.used + 1] = npcs.selected.ped
        ClearPedTasksImmediately(npcs.selected.ped)
        TaskGoStraightToCoord(npcs.selected.ped, selectedCoords.x, selectedCoords.y, selectedCoords.z, 15.0, -1, 0.0, 0.0)
        exports.ox_target:removeLocalEntity(npcs.selected.ped)

        local option = {
            name = 'stealing_npc',
            icon = 'fa-solid fa-user',
            distance = 2.0,
            label = 'Retrieve Drugs',
            onSelect = function()
                if lib.progressBar({ duration = 2000, label = 'Retrieve Drugs', useWhileDead = false, canCancel = false, disable = { move = false, combat = false, car = false, }, anim = { dict = 'pickup_object', clip = 'pickup_low'},}) then
                    local data = {
                        offer = offer,
                        coords = npcs.selected.coords
                    }
                    TriggerServerEvent('qb-drugs:server:retrieveStolenDrugs', data)
                    ClearPedTasks(ped)
                    npcs.selected.ped = nil
                    stealing = false
                end
            end
        }

        exports.ox_target:addLocalEntity(npcs.selected.ped, option)
        QBCore.Functions.Notify(Lang:t("info.has_been_robbed", {bags = offer.amount, drugType = offer.metadata.strain}))

        CreateThread(function()
            while stealing do
                local coords = GetEntityCoords(ped)
                local npcCoords = GetEntityCoords(npcs.selected.ped)
                local dist = #(coords - npcCoords)

                if not IsPedDeadOrDying(npcs.selected.ped) then
                    npcs.selected.coords = npcCoords
                end

                if dist > 100 then
                    exports.ox_target:removeLocalEntity(npcs.selected.ped)
                    stealing = false
                    npcs.selected.ped = nil
                end
                Wait(250)
            end
        end)
        return
    end

    if lib.progressBar({ duration = 5000, label = 'Handing over products', useWhileDead = false, canCancel = false, disable = { move = false, combat = false, car = false, }, anim = { dict = 'gestures@f@standing@casual', clip = 'gesture_point'},}) then
        local npcCoords = GetEntityCoords(npcs.selected.ped)
        local data = {
            offer = offer,
            coords = npcCoords
        }
        PoliceCall()
        TriggerServerEvent('qb-drugs:server:sellDrugs', data)
    end

    SetPedKeepTask(npcs.selected.ped, false)
    SetEntityAsNoLongerNeeded(npcs.selected.ped)
    ClearPedTasksImmediately(npcs.selected.ped)
    npcs.used[#npcs.used + 1] = npcs.selected.ped
    exports.ox_target:removeLocalEntity(npcs.selected.ped)
    npcs.selected.ped = nil
    npcs.selected.coords = nil
end

local function declineOffer()
    QBCore.Functions.Notify(Lang:t("error.offer_declined"), 'error')
    SetPedKeepTask(npcs.selected.ped, false)
    SetEntityAsNoLongerNeeded(npcs.selected.pedpc)
    ClearPedTasksImmediately(npcs.selected.ped)
    npcs.used[#npcs.used + 1] = npcs.selected.ped
    exports.ox_target:removeLocalEntity(npcs.selected.ped)
    npcs.selected.ped = nil
    npcs.selected.coords = nil
end

local function generateNPCOffer(offer)
    lib.registerContext({
        id = 'offer_menu',
        title = 'Local Offer',
        options = {
          {
            title = 'Type: '..offer.metadata.strain,
            description = 'Amount: '..offer.amount..' \n Price: '..offer.price,
          },
          {
            title = 'Accept Offer',
            description = 'This button is disabled',
            icon = 'circle-check',
            onSelect = function()
                acceptOffer(offer)
            end,
          },
          {
            title = 'Decline Offer',
            description = 'Example button description',
            icon = 'circle-xmark',
            onSelect = function()
                declineOffer()
            end
          },
        }
    })

    lib.showContext('offer_menu')
end

local function selectTarget()
    local walking = false

    for _, v in pairs(npcs.used) do
        if v == npcs.selected.ped then
            npcs.selected.ped = nil
            return
        end
    end

    if math.random(1, 100) <= Config.SuccessChance then
        npcs.selected.ped = nil
        return
    end

    local availableDrugs = lib.callback.await('qb-drugs:server:cornerSelling:getAvailableDrugs', false)
    local drug = math.random(1, #availableDrugs)
    local amount = math.random(1, availableDrugs[drug].amount)
    if amount > 15 then amount = math.random(9, 15) end

    local drugPrice = Config.DrugsPrice[availableDrugs[drug].item]
    local randomPrice = math.random(drugPrice.min, drugPrice.max) * amount
    if math.random(1, 100) <= Config.ScamChance then randomPrice = math.random(3, 10) * amount end

    SetEntityAsNoLongerNeeded(npcs.selected.ped)
    ClearPedTasks(npcs.selected.ped)
    walking = true

    CreateThread(function()
        while walking do
            local player = PlayerPedId()
            local coords = GetEntityCoords(player, true)
            local npcCoords = GetEntityCoords(npcs.selected.ped)
            local npcDist = #(coords - npcCoords)

            if not cornerSelling then
                exports.ox_target:removeLocalEntity(npcs.selected.ped)
                LocalPlayer.state.invBusy = false
                npcs.selected.ped = nil
                cornerSelling = false
            end

            TaskGoStraightToCoord(npcs.selected.ped, coords, 1.2, -1, 0.0, 0.0)

            if npcDist < 1.5 then
                local option = {
                    {
                        name = 'buying_npc',
                        icon = 'fa-solid fa-user',
                        distance = 2.0,
                        label = 'View Offer',
                        onSelect = function()
                            local offer = {
                                item = availableDrugs[drug].item,
                                metadata = availableDrugs[drug].metadata,
                                amount = amount,
                                price = randomPrice
                            }

                            generateNPCOffer(offer)
                        end
                    }
                }

                TaskLookAtEntity(npcs.selected.ped, player, 5500.0, 2048, 3)
                TaskTurnPedToFaceEntity(npcs.selected.ped, player, 5500)
                TaskStartScenarioInPlace(npcs.selected.ped, "WORLD_HUMAN_STAND_IMPATIENT_UPRIGHT", 0, false)
                exports.ox_target:addLocalEntity(npcs.selected.ped, option)
                walking = false
            end
            Wait(100)
        end
    end)
end

local function startSelling()
    local ped = PlayerPedId()

    if cornerSelling then return end
    cornerSelling = true
    LocalPlayer.state.invBusy = true
    QBCore.Functions.Notify(Lang:t("info.started_selling_drugs"))
    local startingCoords = GetEntityCoords(ped)

    while cornerSelling do
        local currentCoords = GetEntityCoords(ped)

        if not npcs.selected.ped then
            for _, activeNpc in ipairs(GetActivePlayers()) do
                local npc = GetPlayerPed(activeNpc)
                npcs.available[#npcs.available + 1] = npc
            end

            local closestPed, closestDistance = QBCore.Functions.GetClosestPed(currentCoords, npcs.available)

            if closestDistance < 15.0 and not IsPedDeadOrDying(closestPed) and closestPed ~= 0 and not IsPedInAnyVehicle(closestPed) and GetPedType(closestPed) ~= 28 then
                npcs.selected.ped = closestPed
                selectTarget()
            end
        end

        if #(startingCoords - currentCoords) > 10 then
            cancelSelling()
        end

        Wait(1000)
    end
end

-- Events
RegisterNetEvent('qb-drugs:client:cornerselling', function()
    lib.callback('qb-drugs:server:cornerSelling:getAvailableDrugs', false, function(result)
        if not result then
            QBCore.Functions.Notify(Lang:t("error.has_no_drugs"), 'error')
            return
        end

        -- if CurrentCops <= Config.MinimumDrugSalePolice then
        --     QBCore.Functions.Notify(Lang:t("error.not_enough_police", {polices = Config.MinimumDrugSalePolice}), "error")
        --     return
        -- end

        if IsPedInAnyVehicle(PlayerPedId(), false) then
            QBCore.Functions.Notify(Lang:t("error.in_vehicle"), 'error')
            return
        end

        startSelling()
    end)
end)

RegisterNetEvent('police:SetCopCount', function(amount)
    CurrentCops = amount
end)