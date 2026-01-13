--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                    CONVOI CONTRE CONVOI - VÉHICULES (CLIENT)              ║
    ║                    VERSION SIMPLIFIÉE - RÉCEPTION NETWORK IDs             ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
]]

CVC = CVC or {}
CVC.Vehicles = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- VARIABLES LOCALES
-- ═══════════════════════════════════════════════════════════════════════════

local trackedVehicles = {} -- Liste des netIds des véhicules trackés

-- ═══════════════════════════════════════════════════════════════════════════
-- RÉCEPTION DES VÉHICULES SPAWNÉS (DEPUIS LE SERVEUR)
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('cvc:client:vehiclesSpawned', function(vehicleNetIds)
    -- Recevoir la liste des Network IDs des véhicules spawnés
    trackedVehicles = vehicleNetIds or {}
    
    CVC.Utils.Debug('Réception de %d véhicules du serveur', #trackedVehicles)
    CVC.Utils.Notify(Config.Notifications.vehiclesSpawned)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- SUPPRESSION DES VÉHICULES (TRIGGER SERVEUR)
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('cvc:client:vehiclesDeleted', function()
    trackedVehicles = {}
    CVC.Utils.Debug('Liste des véhicules locaux nettoyée')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- RÉCUPÉRATION DES VÉHICULES LOCAUX (À PARTIR DES NETWORK IDs)
-- ═══════════════════════════════════════════════════════════════════════════

function CVC.Vehicles.GetLocalVehicles()
    local localVehicles = {}
    
    for _, netId in ipairs(trackedVehicles) do
        local vehicle = NetworkGetEntityFromNetworkId(netId)
        
        if vehicle and DoesEntityExist(vehicle) then
            table.insert(localVehicles, vehicle)
        end
    end
    
    return localVehicles
end

-- ═══════════════════════════════════════════════════════════════════════════
-- STATISTIQUES CLIENT (DEBUG)
-- ═══════════════════════════════════════════════════════════════════════════

function CVC.Vehicles.GetLocalStats()
    local vehicles = CVC.Vehicles.GetLocalVehicles()
    
    return {
        tracked = #trackedVehicles,
        existing = #vehicles
    }
end

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDE DEBUG
-- ═══════════════════════════════════════════════════════════════════════════

if Config.Debug then
    RegisterCommand('cvc_localvehicles', function()
        local stats = CVC.Vehicles.GetLocalStats()
        
        local vehicles = CVC.Vehicles.GetLocalVehicles()
        for i, vehicle in ipairs(vehicles) do
            local model = GetEntityModel(vehicle)
            local modelName = GetDisplayNameFromVehicleModel(model)
        end
    end, false)
end