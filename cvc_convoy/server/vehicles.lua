--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                    CONVOI CONTRE CONVOI - VÉHICULES (SERVER)              ║
    ║                    VERSION FINALE - LOGS CONDITIONNELS                    ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
]]

CVC = CVC or {}
CVC.Vehicles = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- STOCKAGE DES VÉHICULES SPAWNÉS
-- ═══════════════════════════════════════════════════════════════════════════

local spawnedVehicles = {
    red = {},
    blue = {}
}

-- ═══════════════════════════════════════════════════════════════════════════
-- SPAWN D'UN VÉHICULE CÔTÉ SERVEUR
-- ═══════════════════════════════════════════════════════════════════════════

local function SpawnVehicleServer(vehicleConfig, team)
    if not vehicleConfig or not vehicleConfig.model or not vehicleConfig.coords then
        if Config.Debug then
            print('[CVC-VEHICLES] ❌ Configuration invalide')
        end
        return nil
    end
    
    local model = type(vehicleConfig.model) == 'string' and GetHashKey(vehicleConfig.model) or vehicleConfig.model
    local coords = vehicleConfig.coords
    local color = vehicleConfig.color or {primary = 0, secondary = 0}
    
    -- Création du véhicule
    local vehicle = CreateVehicle(
        model,
        coords.x,
        coords.y,
        coords.z,
        coords.w,
        true,  -- network
        true   -- script owner
    )
    
    -- Attendre que le véhicule existe
    local timeout = 0
    while not DoesEntityExist(vehicle) and timeout < 50 do
        Wait(10)
        timeout = timeout + 1
    end
    
    if not DoesEntityExist(vehicle) then
        if Config.Debug then
            print('[CVC-VEHICLES] ❌ Échec création: ' .. vehicleConfig.model)
        end
        return nil
    end
    
    -- Configuration
    SetVehicleColours(vehicle, color.primary, color.secondary)
    
    -- Network ID
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    
    if Config.Debug then
        print(string.format('[CVC-VEHICLES] ✅ %s spawné (NetID: %d)', vehicleConfig.model, netId))
    end
    
    return vehicle, netId
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SPAWN PAR ÉQUIPE
-- ═══════════════════════════════════════════════════════════════════════════

local function SpawnTeamVehicles(team)
    if not Config or not Config.Vehicles or not Config.Vehicles[team] then
        if Config.Debug then
            print('[CVC-VEHICLES] ❌ Config.Vehicles.' .. team .. ' introuvable')
        end
        return 0
    end
    
    local vehicleList = Config.Vehicles[team]
    local spawnedCount = 0
    
    if Config.Debug then
        print('[CVC-VEHICLES] Spawn équipe ' .. team .. ': ' .. #vehicleList .. ' véhicules')
    end
    
    for index, vehicleConfig in ipairs(vehicleList) do
        local vehicle, netId = SpawnVehicleServer(vehicleConfig, team)
        
        if vehicle and netId then
            table.insert(spawnedVehicles[team], {
                entity = vehicle,
                netId = netId,
                model = vehicleConfig.model,
                coords = vehicleConfig.coords,
                index = index
            })
            
            spawnedCount = spawnedCount + 1
            Wait(150)
        end
    end
    
    return spawnedCount
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SPAWN TOUS LES VÉHICULES
-- ═══════════════════════════════════════════════════════════════════════════

function CVC.Vehicles.SpawnAll()
    if not Config or not Config.Vehicles then
        print('[CVC-VEHICLES] ❌ Config.Vehicles manquant!')
        return 0
    end
    
    -- Supprimer les anciens
    CVC.Vehicles.DeleteAll()
    Wait(500)
    
    -- Spawn rouge
    local redCount = SpawnTeamVehicles('red')
    Wait(500)
    
    -- Spawn bleu
    local blueCount = SpawnTeamVehicles('blue')
    
    local total = redCount + blueCount
    
    -- Log final (toujours affiché)
    print(string.format('[CVC] %d véhicules spawnés (Rouge: %d, Bleu: %d)', total, redCount, blueCount))
    
    return total
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SUPPRESSION
-- ═══════════════════════════════════════════════════════════════════════════

function CVC.Vehicles.DeleteAll()
    local deleted = 0
    
    for team, vehicles in pairs(spawnedVehicles) do
        for _, veh in ipairs(vehicles) do
            if DoesEntityExist(veh.entity) then
                DeleteEntity(veh.entity)
                deleted = deleted + 1
            end
        end
        spawnedVehicles[team] = {}
    end
    
    if deleted > 0 and Config.Debug then
        print('[CVC-VEHICLES] ' .. deleted .. ' véhicules supprimés')
    end
    
    return deleted
end

function CVC.Vehicles.DeleteTeam(team)
    if not spawnedVehicles[team] then return 0 end
    
    local deleted = 0
    
    for _, veh in ipairs(spawnedVehicles[team]) do
        if DoesEntityExist(veh.entity) then
            DeleteEntity(veh.entity)
            deleted = deleted + 1
        end
    end
    
    spawnedVehicles[team] = {}
    
    if deleted > 0 and Config.Debug then
        print('[CVC-VEHICLES] Équipe ' .. team .. ': ' .. deleted .. ' véhicules supprimés')
    end
    
    return deleted
end

-- ═══════════════════════════════════════════════════════════════════════════
-- RÉPARATION
-- ═══════════════════════════════════════════════════════════════════════════

function CVC.Vehicles.RepairInRadius(coords, radius)
    local repaired = 0
    
    for team, vehicles in pairs(spawnedVehicles) do
        for _, veh in ipairs(vehicles) do
            if DoesEntityExist(veh.entity) then
                local vehCoords = GetEntityCoords(veh.entity)
                if #(coords - vehCoords) <= radius then
                    SetVehicleFixed(veh.entity)
                    repaired = repaired + 1
                end
            end
        end
    end
    
    if Config.Debug then
        print('[CVC-VEHICLES] ' .. repaired .. ' véhicules réparés')
    end
    
    return repaired
end

-- ═══════════════════════════════════════════════════════════════════════════
-- STATISTIQUES
-- ═══════════════════════════════════════════════════════════════════════════

function CVC.Vehicles.GetStats()
    local stats = {
        total = 0,
        byTeam = { red = 0, blue = 0 },
        byModel = {}
    }
    
    for team, vehicles in pairs(spawnedVehicles) do
        for _, veh in ipairs(vehicles) do
            if DoesEntityExist(veh.entity) then
                stats.total = stats.total + 1
                stats.byTeam[team] = stats.byTeam[team] + 1
                stats.byModel[veh.model] = (stats.byModel[veh.model] or 0) + 1
            end
        end
    end
    
    return stats
end

function CVC.Vehicles.GetAll()
    local all = {}
    for team, vehicles in pairs(spawnedVehicles) do
        for _, veh in ipairs(vehicles) do
            if DoesEntityExist(veh.entity) then
                table.insert(all, veh)
            end
        end
    end
    return all
end

function CVC.Vehicles.GetByTeam(team)
    local teamVeh = {}
    if spawnedVehicles[team] then
        for _, veh in ipairs(spawnedVehicles[team]) do
            if DoesEntityExist(veh.entity) then
                table.insert(teamVeh, veh)
            end
        end
    end
    return teamVeh
end

-- ═══════════════════════════════════════════════════════════════════════════
-- NETTOYAGE PÉRIODIQUE
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(60000)
        for team, vehicles in pairs(spawnedVehicles) do
            for i = #vehicles, 1, -1 do
                if not DoesEntityExist(vehicles[i].entity) then
                    table.remove(vehicles, i)
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- NETTOYAGE À L'ARRÊT
-- ═══════════════════════════════════════════════════════════════════════════

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        CVC.Vehicles.DeleteAll()
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDE DEBUG
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('cvc_vehiclestats', function()
    local stats = CVC.Vehicles.GetStats()
    print('╔═══════════════════════════════════════╗')
    print('║     CVC - STATISTIQUES VÉHICULES      ║')
    print('╚═══════════════════════════════════════╝')
    print('Total: ' .. stats.total)
    print('Rouge: ' .. stats.byTeam.red)
    print('Bleu: ' .. stats.byTeam.blue)
    print('Détail par modèle:')
    for model, count in pairs(stats.byModel) do
        print('  • ' .. model .. ': ' .. count)
    end
    print('╚═══════════════════════════════════════╝')
end, false)

-- ═══════════════════════════════════════════════════════════════════════════
-- CHARGEMENT
-- ═══════════════════════════════════════════════════════════════════════════

print('[CVC] Module véhicules chargé')