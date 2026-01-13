-- ============================================================
-- VARIABLES GLOBALES
-- ============================================================

local playerPed = PlayerPedId()
local isInVehicle = false
local currentVehicle = nil
local currentSeat = nil
local lastNotification = 0
local shootingDisabled = false

-- ============================================================
-- FONCTIONS UTILITAIRES
-- ============================================================

--- Affiche un message de debug dans la console F8
---@param message string Le message à afficher
local function DebugPrint(message)
    if Config.Debug then
        print('^3[NoVehicleShooting]^7 ' .. message)
    end
end

--- Affiche une notification à l'écran
---@param message string Le message à afficher
local function ShowNotification(message)
    if not Config.ShowNotifications then return end
    
    local currentTime = GetGameTimer()
    if currentTime - lastNotification < Config.NotificationCooldown then
        return
    end
    
    lastNotification = currentTime
    
    SetNotificationTextEntry('STRING')
    AddTextComponentString(message)
    DrawNotification(false, true)
    
    DebugPrint('Notification affichée : ' .. message)
end

--- Trouve le siège actuel du joueur dans un véhicule
---@param vehicle number Entity ID du véhicule
---@param ped number Entity ID du ped
---@return number Index du siège (-1 = conducteur, 0+ = passagers, -2 = non trouvé)
local function FindPedSeat(vehicle, ped)
    -- Vérifier tous les sièges possibles
    for seatIndex = -1, 15 do
        local pedInSeat = GetPedInVehicleSeat(vehicle, seatIndex)
        if pedInSeat == ped then
            return seatIndex
        end
    end
    return -2 -- Siège non trouvé
end

--- Vérifie si le joueur peut tirer depuis son siège actuel
---@return boolean Peut tirer ou non
local function CanPlayerShoot()
    if not Config.Enabled then return true end
    if not isInVehicle then return true end
    if not currentVehicle then return true end
    
    -- Vérifier si le véhicule est dans la liste blanche
    if Config.IsVehicleAllowed(currentVehicle) then
        DebugPrint('Véhicule autorisé à tirer')
        return true
    end
    
    -- Vérifier si le siège est autorisé
    if Config.IsSeatAllowed(currentSeat) then
        DebugPrint('Siège ' .. currentSeat .. ' autorisé à tirer')
        return true
    end
    
    DebugPrint('Tir bloqué - Siège: ' .. currentSeat)
    return false
end

--- Désactive les contrôles de tir
local function DisableShootingControls()
    -- Désactiver le tir avec arme
    DisableControlAction(0, 24, true)  -- INPUT_ATTACK (Clic gauche)
    DisableControlAction(0, 25, true)  -- INPUT_AIM (Clic droit)
    DisableControlAction(0, 47, true)  -- INPUT_DETONATE (G - grenade)
    DisableControlAction(0, 58, true)  -- INPUT_ATTACK2 (Tir alternatif)
    DisableControlAction(0, 91, true)  -- INPUT_VEH_PASSENGER_AIM (Viser depuis véhicule)
    DisableControlAction(0, 92, true)  -- INPUT_VEH_PASSENGER_ATTACK (Tirer depuis véhicule)
    DisableControlAction(0, 114, true) -- INPUT_VEH_FLY_ATTACK (Tir hélico)
    DisableControlAction(0, 331, true) -- INPUT_VEH_FLY_ATTACK2 (Tir alternatif hélico)
    
    -- Empêcher le joueur de viser
    DisablePlayerFiring(PlayerId(), true)
end

--- Met à jour l'état du véhicule du joueur
local function UpdateVehicleState()
    playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    
    if vehicle ~= 0 then
        isInVehicle = true
        currentVehicle = vehicle
        
        -- Trouver le siège du joueur
        currentSeat = FindPedSeat(vehicle, playerPed)
        
        if currentSeat == -2 then
            DebugPrint('AVERTISSEMENT: Siège du joueur non trouvé')
            currentSeat = -1 -- Fallback sur conducteur
        end
        
        DebugPrint('Joueur dans véhicule - Siège: ' .. currentSeat)
        
        -- Vérifier immédiatement si le tir doit être bloqué
        if not CanPlayerShoot() then
            shootingDisabled = true
            TriggerServerEvent('noVehicleShooting:playerEnteredVehicle', GetPlayerServerId(PlayerId()), currentSeat)
        else
            shootingDisabled = false
        end
    else
        -- Sortie du véhicule - débloquer IMMÉDIATEMENT
        if isInVehicle then
            DebugPrint('Joueur sorti du véhicule - Déblocage immédiat')
        end
        
        isInVehicle = false
        currentVehicle = nil
        currentSeat = nil
        shootingDisabled = false
    end
end

-- ============================================================
-- SYSTÈME BASÉ SUR LES ÉVÉNEMENTS (RECOMMANDÉ)
-- ============================================================

if Config.UseNativeEvents then
    --- Détecte quand le joueur entre dans un véhicule
    AddEventHandler('gameEventTriggered', function(event, data)
        if event == 'CEventNetworkPlayerEnteredVehicle' then
            local player = data[1]
            if player == PlayerId() then
                Wait(100) -- Petit délai pour s'assurer que les données sont à jour
                UpdateVehicleState()
            end
        elseif event == 'CEventNetworkPlayerLeftVehicle' then
            local player = data[1]
            if player == PlayerId() then
                UpdateVehicleState()
            end
        end
    end)
    
    -- Vérification initiale au spawn
    CreateThread(function()
        Wait(1000)
        UpdateVehicleState()
    end)
end

-- ============================================================
-- THREAD PRINCIPAL DE DÉSACTIVATION DES CONTRÔLES
-- ============================================================

CreateThread(function()
    while true do
        local sleep = 1000
        
        if isInVehicle and shootingDisabled then
            sleep = 0
            DisableShootingControls()
            
            -- Détecter tentative de tir pour notification
            if IsDisabledControlJustPressed(0, 24) or IsDisabledControlJustPressed(0, 92) then
                ShowNotification(Config.NotificationMessage)
                TriggerServerEvent('noVehicleShooting:shootingAttempt', GetPlayerServerId(PlayerId()), currentSeat)
            end
        end
        
        Wait(sleep)
    end
end)

-- ============================================================
-- THREAD DE VÉRIFICATION PÉRIODIQUE (FALLBACK)
-- ============================================================

if not Config.UseNativeEvents then
    CreateThread(function()
        while true do
            Wait(Config.CheckInterval)
            UpdateVehicleState()
            
            if isInVehicle then
                shootingDisabled = not CanPlayerShoot()
            end
        end
    end)
else
    -- Thread de vérification de sécurité (toutes les 5 secondes)
    CreateThread(function()
        while true do
            Wait(5000)
            local tempInVehicle = IsPedInAnyVehicle(PlayerPedId(), false)
            if tempInVehicle ~= isInVehicle then
                DebugPrint('Désynchronisation détectée, mise à jour forcée')
                UpdateVehicleState()
            end
        end
    end)
end

-- ============================================================
-- THREAD DE VÉRIFICATION RAPIDE POUR SORTIE DE VÉHICULE
-- ============================================================

CreateThread(function()
    while true do
        Wait(50) -- Vérification très rapide (50ms)
        
        -- Si on était dans un véhicule et qu'on n'y est plus
        if isInVehicle then
            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
            if vehicle == 0 then
                -- Sortie détectée - déblocage immédiat
                DebugPrint('Sortie de véhicule détectée (thread rapide)')
                isInVehicle = false
                currentVehicle = nil
                currentSeat = nil
                shootingDisabled = false
            end
        else
            -- Pas dans un véhicule, ralentir la vérification
            Wait(450) -- Total = 500ms quand pas en véhicule
        end
    end
end)

-- ============================================================
-- ÉVÉNEMENTS RÉSEAU
-- ============================================================

--- Permet de forcer l'activation/désactivation du système à distance
RegisterNetEvent('noVehicleShooting:toggle', function(state)
    Config.Enabled = state
    DebugPrint('Système ' .. (state and 'activé' or 'désactivé') .. ' par le serveur')
    UpdateVehicleState()
end)

--- Mise à jour de la configuration en temps réel
RegisterNetEvent('noVehicleShooting:updateConfig', function(newConfig)
    for key, value in pairs(newConfig) do
        if Config[key] ~= nil then
            Config[key] = value
            DebugPrint('Config mise à jour : ' .. key)
        end
    end
    UpdateVehicleState()
end)

-- ============================================================
-- COMMANDES DE DEBUG
-- ============================================================

if Config.Debug then
    RegisterCommand('vehicleinfo', function()
        print('^2=== INFO VÉHICULE ===^7')
        print('Dans véhicule: ' .. tostring(isInVehicle))
        print('Véhicule ID: ' .. tostring(currentVehicle))
        print('Siège: ' .. tostring(currentSeat))
        print('Tir désactivé: ' .. tostring(shootingDisabled))
        print('Peut tirer: ' .. tostring(CanPlayerShoot()))
    end)
    
    RegisterCommand('toggleshoot', function()
        Config.Enabled = not Config.Enabled
        print('^2Système anti-tir: ' .. (Config.Enabled and 'ACTIVÉ' or 'DÉSACTIVÉ') .. '^7')
        UpdateVehicleState()
    end)
end

-- ============================================================
-- INITIALISATION
-- ============================================================

DebugPrint('Script anti-tir en véhicule chargé')