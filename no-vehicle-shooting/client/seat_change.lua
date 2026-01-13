-- ============================================================
-- SYSTÈME DE CHANGEMENT DE SIÈGE
-- ============================================================

local isUIOpen = false
local isChangingSeat = false
local lastVehicle = nil

-- ============================================================
-- FONCTIONS UTILITAIRES DE BASE
-- ============================================================

--- Affiche un message de debug dans la console F8
---@param message string Le message à afficher
local function DebugPrint(message)
    if Config.Debug then
        print('^3[SeatChange]^7 ' .. message)
    end
end

-- ============================================================
-- CONFIGURATION
-- ============================================================

local SeatConfig = {
    -- Touche pour ouvrir le menu (H par défaut)
    OpenKey = 74,  -- H
    
    -- Animation lors du changement de siège
    EnableAnimation = true,
    AnimationDuration = 800, -- ms
    
    -- Cooldown entre changements de siège
    CooldownTime = 1000, -- ms
    
    -- Bloquer changement si véhicule en mouvement
    BlockIfMoving = false,
    MaxSpeed = 5.0, -- km/h maximum si BlockIfMoving = true
}

-- ============================================================
-- FONCTIONS UTILITAIRES
-- ============================================================

--- Récupère tous les sièges disponibles dans un véhicule
---@param vehicle number Entity ID du véhicule
---@return table Liste des sièges avec leur statut
local function GetVehicleSeats(vehicle)
    if not DoesEntityExist(vehicle) then
        return {}
    end
    
    local seats = {}
    local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
    
    -- Vérifier le siège conducteur (-1)
    table.insert(seats, {
        index = -1,
        occupied = GetPedInVehicleSeat(vehicle, -1) ~= 0,
        name = "Conducteur"
    })
    
    -- Vérifier les sièges passagers (0 à maxSeats-1)
    for i = 0, maxSeats - 1 do
        local ped = GetPedInVehicleSeat(vehicle, i)
        table.insert(seats, {
            index = i,
            occupied = ped ~= 0,
            name = i == 0 and "Passager" or "Siège " .. (i + 1)
        })
    end
    
    return seats
end

--- Trouve le siège actuel du joueur
---@param vehicle number Entity ID du véhicule
---@return number|nil Index du siège
local function GetPlayerCurrentSeat(vehicle)
    local playerPed = PlayerPedId()
    
    for i = -1, 15 do
        if GetPedInVehicleSeat(vehicle, i) == playerPed then
            return i
        end
    end
    
    return nil
end

--- Vérifie si le joueur peut changer de siège
---@return boolean, string Peut changer, raison si non
local function CanChangeSeat()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    
    -- Pas dans un véhicule
    if vehicle == 0 then
        return false, "Vous n'êtes pas dans un véhicule"
    end
    
    -- En train de changer de siège
    if isChangingSeat then
        return false, "Changement de siège en cours"
    end
    
    -- Véhicule en mouvement (si configuré)
    if SeatConfig.BlockIfMoving then
        local speed = GetEntitySpeed(vehicle) * 3.6 -- Conversion en km/h
        if speed > SeatConfig.MaxSpeed then
            return false, "Le véhicule roule trop vite"
        end
    end
    
    -- Joueur en train de faire une action
    if IsPedRagdoll(playerPed) or IsPedBeingStunned(playerPed) or IsPedDeadOrDying(playerPed) then
        return false, "Vous ne pouvez pas changer de place maintenant"
    end
    
    return true, ""
end

--- Envoie les données des sièges à la NUI
---@param vehicle number Entity ID du véhicule
local function SendSeatsToUI(vehicle)
    local seats = GetVehicleSeats(vehicle)
    local currentSeat = GetPlayerCurrentSeat(vehicle)
    
    SendNUIMessage({
        action = 'updateSeats',
        seats = {
            seats = seats,
            currentSeat = currentSeat
        }
    })
end

-- ============================================================
-- GESTION DE L'INTERFACE
-- ============================================================

--- Ouvre l'interface de sélection de siège
local function OpenSeatSelector()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    
    if vehicle == 0 then
        return
    end
    
    local canChange, reason = CanChangeSeat()
    if not canChange then
        if Config.ShowNotifications then
            SetNotificationTextEntry('STRING')
            AddTextComponentString('~r~' .. reason)
            DrawNotification(false, true)
        end
        return
    end
    
    isUIOpen = true
    lastVehicle = vehicle
    
    -- Activer le curseur et le focus NUI
    SetNuiFocus(true, true)
    
    -- Envoyer les données à la NUI
    local seats = GetVehicleSeats(vehicle)
    local currentSeat = GetPlayerCurrentSeat(vehicle)
    
    SendNUIMessage({
        action = 'openUI',
        seats = {
            seats = seats,
            currentSeat = currentSeat
        }
    })
    
    DebugPrint('Interface de changement de siège ouverte')
end

--- Ferme l'interface de sélection de siège
local function CloseSeatSelector()
    if not isUIOpen then return end
    
    isUIOpen = false
    SetNuiFocus(false, false)
    
    SendNUIMessage({
        action = 'closeUI'
    })
    
    DebugPrint('Interface de changement de siège fermée')
end

-- ============================================================
-- LOGIQUE DE CHANGEMENT DE SIÈGE
-- ============================================================

--- Change le joueur de siège
---@param targetSeat number Index du siège cible
local function ChangeSeat(targetSeat)
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    
    if vehicle == 0 then
        DebugPrint('Erreur: Joueur plus dans un véhicule')
        return
    end
    
    local currentSeat = GetPlayerCurrentSeat(vehicle)
    
    if currentSeat == targetSeat then
        DebugPrint('Erreur: Déjà à cette place')
        return
    end
    
    -- Vérifier que le siège cible est libre
    local targetPed = GetPedInVehicleSeat(vehicle, targetSeat)
    if targetPed ~= 0 then
        DebugPrint('Erreur: Siège occupé')
        
        SendNUIMessage({
            action = 'showMessage',
            message = 'Ce siège est déjà occupé !',
            type = 'error'
        })
        return
    end
    
    isChangingSeat = true
    
    -- Animation de changement de siège
    if SeatConfig.EnableAnimation then
        -- Déclencher l'animation
        TaskShuffleToNextVehicleSeat(playerPed, vehicle)
        
        -- Attendre que l'animation démarre
        Wait(100)
        
        -- Forcer le changement de siège après un délai
        local startTime = GetGameTimer()
        while GetGameTimer() - startTime < SeatConfig.AnimationDuration do
            -- Vérifier si le joueur a atteint le siège
            local newSeat = GetPlayerCurrentSeat(vehicle)
            if newSeat == targetSeat then
                break
            end
            Wait(50)
        end
        
        -- Si TaskShuffle n'a pas fonctionné, forcer le changement
        if GetPlayerCurrentSeat(vehicle) ~= targetSeat then
            SetPedIntoVehicle(playerPed, vehicle, targetSeat)
        end
    else
        -- Changement instantané
        SetPedIntoVehicle(playerPed, vehicle, targetSeat)
    end
    
    Wait(100)
    
    isChangingSeat = false
    
    -- Vérifier que le changement a réussi
    local finalSeat = GetPlayerCurrentSeat(vehicle)
    if finalSeat == targetSeat then
        DebugPrint('Changement de siège réussi: ' .. currentSeat .. ' -> ' .. targetSeat)
        
        SendNUIMessage({
            action = 'showMessage',
            message = 'Place changée avec succès !',
            type = 'success'
        })
        
        -- Notifier le serveur pour logging
        TriggerServerEvent('seatChange:changed', GetPlayerServerId(PlayerId()), currentSeat, targetSeat)
    else
        DebugPrint('Échec du changement de siège')
        
        SendNUIMessage({
            action = 'showMessage',
            message = 'Impossible de changer de place',
            type = 'error'
        })
    end
    
    -- Mettre à jour l'interface
    SendSeatsToUI(vehicle)
end

-- ============================================================
-- CALLBACKS NUI
-- ============================================================

RegisterNUICallback('changeSeat', function(data, cb)
    local targetSeat = data.seat
    
    DebugPrint('Demande de changement vers siège: ' .. targetSeat)
    
    ChangeSeat(targetSeat)
    CloseSeatSelector()
    
    cb('ok')
end)

RegisterNUICallback('closeUI', function(data, cb)
    CloseSeatSelector()
    cb('ok')
end)

-- ============================================================
-- THREADS
-- ============================================================

--- Thread pour détecter la touche H
CreateThread(function()
    while true do
        Wait(0)
        
        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        
        if vehicle ~= 0 then
            -- Vérifier si H est pressé
            if IsControlJustPressed(0, SeatConfig.OpenKey) then
                if not isUIOpen then
                    OpenSeatSelector()
                else
                    CloseSeatSelector()
                end
            end
        else
            -- Si plus dans un véhicule, fermer l'UI
            if isUIOpen then
                CloseSeatSelector()
            end
            
            Wait(500)
        end
    end
end)

--- Thread pour mettre à jour l'interface en temps réel
CreateThread(function()
    while true do
        Wait(1000)
        
        if isUIOpen and lastVehicle and DoesEntityExist(lastVehicle) then
            -- Vérifier que le joueur est toujours dans le véhicule
            local playerPed = PlayerPedId()
            local currentVehicle = GetVehiclePedIsIn(playerPed, false)
            
            if currentVehicle == lastVehicle then
                SendSeatsToUI(lastVehicle)
            else
                -- Plus dans le véhicule, fermer l'interface
                CloseSeatSelector()
            end
        end
    end
end)

-- ============================================================
-- ÉVÉNEMENTS
-- ============================================================

--- Événement pour fermer l'interface depuis le serveur
RegisterNetEvent('seatChange:closeUI', function()
    if isUIOpen then
        CloseSeatSelector()
    end
end)

--- Événement pour ouvrir l'interface depuis un autre script
RegisterNetEvent('seatChange:openUI', function()
    if not isUIOpen then
        OpenSeatSelector()
    end
end)

-- ============================================================
-- EXPORTS
-- ============================================================

--- Export pour ouvrir l'interface depuis un autre script
exports('OpenSeatSelector', OpenSeatSelector)

--- Export pour fermer l'interface
exports('CloseSeatSelector', CloseSeatSelector)

--- Export pour changer de siège programmatiquement
exports('ChangeSeat', ChangeSeat)

--- Export pour obtenir les sièges disponibles
exports('GetVehicleSeats', GetVehicleSeats)

-- ============================================================
-- COMMANDES DE DEBUG
-- ============================================================

if Config.Debug then
    RegisterCommand('seats', function()
        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        if vehicle ~= 0 then
            OpenSeatSelector()
        else
            print('Vous devez être dans un véhicule')
        end
    end)
    
    RegisterCommand('seatinfo', function()
        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        if vehicle ~= 0 then
            local seats = GetVehicleSeats(vehicle)
            local current = GetPlayerCurrentSeat(vehicle)
            
            print('^2=== INFO SIÈGES ===^7')
            print('Siège actuel: ' .. tostring(current))
            print('Sièges disponibles:')
            for _, seat in ipairs(seats) do
                print(string.format('  Siège %d (%s): %s', 
                    seat.index, 
                    seat.name, 
                    seat.occupied and 'OCCUPÉ' or 'LIBRE'
                ))
            end
        end
    end)
end

-- ============================================================
-- INITIALISATION
-- ============================================================

DebugPrint('Module de changement de siège chargé')