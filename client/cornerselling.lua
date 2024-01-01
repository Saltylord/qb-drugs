QBCore = exports['qb-core']:GetCoreObject()
local cornerSelling = false
local stealing = false
local currentCops = 0
local npcs = {
    selected = {
        ped = nil
    },
    available = {},
    used = {}
}

local function cancelSelling()
    if not stealing then
        ClearPedTasks(npcs.selected.ped)
        exports.ox_target:removeLocalEntity(npcs.selected.ped)
        npcs.selected.ped = nil
    end

    LocalPlayer.state.invBusy = false
    cornerSelling = false
    TriggerServerEvent('qb-drugs:server:cancelSelling')
end

local function alertPolice()
    local random = math.random(1, 100)
    if random <= Config.PoliceCallChance then
        TriggerServerEvent('police:server:policeAlert', 'Drug sale in progress')
    end
end

local function acceptOffer()
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
        stealing = true

        TriggerServerEvent('qb-drugs:server:stealDrugsFromPlayer')
        npcs.used[#npcs.used + 1] = npcs.selected.ped
        ClearPedTasksImmediately(npcs.selected.ped)
        TaskGoStraightToCoord(npcs.selected.ped, selectedCoords.x, selectedCoords.y, selectedCoords.z, 15.0, -1, 0.0, 0.0)
        exports.ox_target:removeLocalEntity(npcs.selected.ped)
        cancelSelling()

        local option = {
            name = 'stealing_npc',
            icon = 'fa-solid fa-user',
            distance = 2.0,
            label = 'Retrieve Drugs',
            onSelect = function()
                if lib.progressBar({ duration = 2000, label = 'Retrieve Drugs', useWhileDead = false, canCancel = false, disable = { move = false, combat = false, car = false, }, anim = { dict = 'pickup_object', clip = 'pickup_low'},}) then
                    TriggerServerEvent('qb-drugs:server:retrieveDrugsFromNPC')
                    ClearPedTasks(ped)
                    npcs.selected.ped = nil
                    stealing = false
                end
            end
        }

        exports.ox_target:addLocalEntity(npcs.selected.ped, option)

        CreateThread(function()
            while stealing do
                local coords = GetEntityCoords(ped)
                local npcCoords = GetEntityCoords(npcs.selected.ped)
                local dist = #(coords - npcCoords)

                if dist > 100 then
                    exports.ox_target:removeLocalEntity(npcs.selected.ped)
                    stealing = false
                    npcs.selected.ped = nil
                    TriggerServerEvent('qb-drugs:server:clearOffer')
                end
                Wait(250)
            end
        end)

        return
    end

    if lib.progressBar({ duration = 2000, label = 'Handing over products', useWhileDead = false, canCancel = false, disable = { move = false, combat = false, car = false, }, anim = { dict = 'mp_doorbell', clip = 'ring_bell_a', playbackRate = 5.0}, prop = {model = `bzzz_prop_gift_orange`, bone = 57005, pos = vec3(0.15, -0.03, -0.14), rot = vec3(-77.0, -120.0, 40.0)},}) then
        -- alertPolice()
        TriggerServerEvent('qb-drugs:server:sellDrugs')
    end

    SetPedKeepTask(npcs.selected.ped, false)
    SetEntityAsNoLongerNeeded(npcs.selected.ped)
    ClearPedTasksImmediately(npcs.selected.ped)
    npcs.used[#npcs.used + 1] = npcs.selected.ped
    exports.ox_target:removeLocalEntity(npcs.selected.ped)
    npcs.selected.ped = nil
end

local function declineOffer()
    QBCore.Functions.Notify(Lang:t("error.offer_declined"), 'error')
    SetPedKeepTask(npcs.selected.ped, false)
    SetEntityAsNoLongerNeeded(npcs.selected.pedpc)
    ClearPedTasksImmediately(npcs.selected.ped)
    npcs.used[#npcs.used + 1] = npcs.selected.ped
    exports.ox_target:removeLocalEntity(npcs.selected.ped)
    npcs.selected.ped = nil
end

local function generateNPCOffer()
    local offer = lib.callback.await('qb-drugs:callback:getCurrentOffer', false)

    lib.registerContext({
        id = 'offer_menu',
        title = 'Local Offer',
        options = {
            {
                title = 'Type: '..offer.item:gsub("^%l", string.upper),
                description = 'Amount: '..offer.amount..' \n Price: '..offer.price,
            },
            {
                title = 'Accept Offer',
                description = 'This button is disabled',
                icon = 'circle-check',
                onSelect = function()
                    acceptOffer()
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

    TriggerServerEvent('qb-drugs:server:createOffer')

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
                            generateNPCOffer()
                        end
                    }
                }

                TaskLookAtEntity(npcs.selected.ped, player, 5500.0, 2048, 3)
                TaskTurnPedToFaceEntity(npcs.selected.ped, player, 5500)
                TaskStartScenarioInPlace(npcs.selected.ped, "WORLD_HUMAN_STAND_IMPATIENT_UPRIGHT", 0, false)
                exports.ox_target:addLocalEntity(npcs.selected.ped, option)
                walking = false
            end
            Wait(250)
        end
    end)
end

local function startSelling()
    local ped = PlayerPedId()
    local startingCoords = GetEntityCoords(ped)
    cornerSelling = true
    LocalPlayer.state.invBusy = true

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
            QBCore.Functions.Notify(Lang:t("error.too_far_away"), 'error')
            cancelSelling()
        end

        Wait(Config.NewTargetWait * 1000)
    end
end

-- Events
RegisterNetEvent('qb-drugs:client:startCornerSelling', function()
    if cornerSelling then
        QBCore.Functions.Notify(Lang:t("info.stopped_selling_drugs"), 'error')
        cancelSelling()
        return
    end

    if IsPedInAnyVehicle(PlayerPedId(), false) then
        QBCore.Functions.Notify(Lang:t("error.in_vehicle"), 'error')
        return
    end

    if currentCops >= Config.MinimumDrugSalePolice then
        TriggerServerEvent('qb-drugs:server:setAvailableDrugs')
        startSelling()
    else
        QBCore.Functions.Notify(Lang:t("error.not_enough_police", {polices = Config.MinimumDrugSalePolice}), "error")
    end
end)

RegisterNetEvent('qb-drugs:client:stopCornerSelling', function()
    if not cornerSelling then return end
    LocalPlayer.state.invBusy = false
    npcs.selected.ped = nil
    cornerSelling = false
end)

RegisterNetEvent('police:SetCopCount', function(amount)
    currentCops = amount
end)