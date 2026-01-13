--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                    CONVOI CONTRE CONVOI - COMMANDES ADMIN                 ║
    ║                    VERSION FINALE - LOGS CONDITIONNELS                    ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
]]

CVC = CVC or {}

-- ═══════════════════════════════════════════════════════════════════════════
-- /cvchealall [radius] - Soigner tous les joueurs dans un rayon
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('cvchealall', function(source, args, rawCommand)
    if not CVC.Utils.HasPermission(source, 'cvchealall') then
        TriggerClientEvent('cvc:client:notify', source, Config.Notifications.noPermission)
        return
    end
    
    local radius = tonumber(args[1]) or Config.DefaultRadius.healall
    local playersHealed = 0
    local playersInRadius = CVC.Utils.GetPlayersInRadius(source, radius)
    
    for _, playerId in ipairs(playersInRadius) do
        if CVC.Players.IsInMode(playerId) then
            TriggerClientEvent('cvc:client:heal', playerId)
            playersHealed = playersHealed + 1
        end
    end
    
    TriggerClientEvent('cvc:client:notify', source, 
        string.format('%d %s', playersHealed, Config.Notifications.healedPlayers))
    
    if Config.Debug then
        CVC.Utils.Debug('cvchealall: %d joueurs soignés', playersHealed)
    end
end, false)

-- ═══════════════════════════════════════════════════════════════════════════
-- /cvcequipe - Afficher le nombre de joueurs par équipe
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('cvcequipe', function(source, args, rawCommand)
    if not CVC.Utils.HasPermission(source, 'cvcequipe') then
        TriggerClientEvent('cvc:client:notify', source, Config.Notifications.noPermission)
        return
    end
    
    local redCount, blueCount = CVC.Teams.GetCount()
    TriggerClientEvent('cvc:client:teamCount', source, redCount, blueCount)
    
    if Config.Debug then
        CVC.Utils.Debug('cvcequipe: Rouge=%d, Bleu=%d', redCount, blueCount)
    end
end, false)

-- ═══════════════════════════════════════════════════════════════════════════
-- /givecallall [radius] - Donner une arme à tous les joueurs dans un rayon
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('givecallall', function(source, args, rawCommand)
    if not CVC.Utils.HasPermission(source, 'givecallall') then
        TriggerClientEvent('cvc:client:notify', source, Config.Notifications.noPermission)
        return
    end
    
    local radius = tonumber(args[1]) or Config.DefaultRadius.givecallall
    local playersGiven = 0
    local playersInRadius = CVC.Utils.GetPlayersInRadius(source, radius)
    
    for _, playerId in ipairs(playersInRadius) do
        if CVC.Players.IsInMode(playerId) then
            local success = CVC.Utils.GiveWeapon(
                playerId,
                Config.GiveAllWeapon.weapon,
                Config.GiveAllWeapon.ammo,
                Config.GiveAllWeapon.ammoType
            )
            
            if success then
                TriggerClientEvent('cvc:client:weaponReceived', playerId)
                playersGiven = playersGiven + 1
            end
        end
    end
    
    TriggerClientEvent('cvc:client:notify', source, 
        string.format('%d %s', playersGiven, Config.Notifications.givenWeapons))
    
    if Config.Debug then
        CVC.Utils.Debug('givecallall: %d joueurs', playersGiven)
    end
end, false)

-- ═══════════════════════════════════════════════════════════════════════════
-- /cvctpall - Téléporter tous les joueurs EN ÉQUIPE vers l'admin
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('cvctpall', function(source, args, rawCommand)
    if not CVC.Utils.HasPermission(source, 'cvctpall') then
        TriggerClientEvent('cvc:client:notify', source, Config.Notifications.noPermission)
        return
    end
    
    local adminCoords = CVC.Utils.GetPlayerCoords(source)
    if not adminCoords then
        TriggerClientEvent('cvc:client:notify', source, 'Erreur: Impossible de récupérer votre position')
        return
    end
    
    local ped = GetPlayerPed(source)
    local heading = GetEntityHeading(ped)
    local teleportCoords = vector4(adminCoords.x, adminCoords.y, adminCoords.z, heading)
    
    local playersTeleported = 0
    local allPlayers = CVC.Players.GetAllInMode()
    
    for _, playerId in ipairs(allPlayers) do
        local team = CVC.Teams.GetPlayerTeam(playerId)
        if team and playerId ~= source then
            TriggerClientEvent('cvc:client:teleport', playerId, teleportCoords)
            playersTeleported = playersTeleported + 1
        end
    end
    
    TriggerClientEvent('cvc:client:notify', source, 
        string.format('%d joueurs téléportés vers vous', playersTeleported))
    
    if Config.Debug then
        CVC.Utils.Debug('cvctpall: %d joueurs téléportés', playersTeleported)
    end
end, false)

-- ═══════════════════════════════════════════════════════════════════════════
-- /cvctpequipe [rouge/bleu] - Téléporter une équipe spécifique vers l'admin
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('cvctpequipe', function(source, args, rawCommand)
    if not CVC.Utils.HasPermission(source, 'cvctpequipe') then
        TriggerClientEvent('cvc:client:notify', source, Config.Notifications.noPermission)
        return
    end
    
    local teamArg = args[1] and args[1]:lower() or nil
    
    local team = nil
    if teamArg == 'rouge' or teamArg == 'red' then
        team = 'red'
    elseif teamArg == 'bleu' or teamArg == 'blue' then
        team = 'blue'
    end
    
    if not team then
        TriggerClientEvent('cvc:client:notify', source, Config.Notifications.invalidTeam)
        return
    end
    
    local adminCoords = CVC.Utils.GetPlayerCoords(source)
    if not adminCoords then
        TriggerClientEvent('cvc:client:notify', source, 'Erreur: Impossible de récupérer votre position')
        return
    end
    
    local ped = GetPlayerPed(source)
    local heading = GetEntityHeading(ped)
    local teleportCoords = vector4(adminCoords.x, adminCoords.y, adminCoords.z, heading)
    
    local playersTeleported = 0
    local teamPlayers = CVC.Teams.GetTeamPlayers(team)
    
    for _, playerId in ipairs(teamPlayers) do
        if playerId ~= source then
            TriggerClientEvent('cvc:client:teleport', playerId, teleportCoords)
            playersTeleported = playersTeleported + 1
        end
    end
    
    local teamLabel = team == 'red' and 'Rouge' or 'Bleue'
    TriggerClientEvent('cvc:client:notify', source, 
        string.format('Équipe %s: %d joueurs téléportés vers vous', teamLabel, playersTeleported))
    
    if Config.Debug then
        CVC.Utils.Debug('cvctpequipe %s: %d joueurs', team, playersTeleported)
    end
end, false)

-- ═══════════════════════════════════════════════════════════════════════════
-- /cvcrepairall [radius] - Réparer tous les véhicules dans un rayon
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('cvcrepairall', function(source, args, rawCommand)
    if not CVC.Utils.HasPermission(source, 'cvcrepairall') then
        CVC.Utils.NotifyPlayer(source, Config.Notifications.noPermission)
        return
    end
    
    local radius = tonumber(args[1]) or Config.DefaultRadius.repairall
    local coords = CVC.Utils.GetPlayerCoords(source)
    
    if not coords then
        CVC.Utils.NotifyPlayer(source, 'Erreur: Impossible de récupérer votre position')
        return
    end
    
    local count = CVC.Vehicles.RepairInRadius(coords, radius)
    CVC.Utils.NotifyPlayer(source, string.format('%d %s', count, Config.Notifications.repairedVehicles))
end, false)

-- ═══════════════════════════════════════════════════════════════════════════
-- /cvcspawnvehicule - Spawn les véhicules du convoi
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('cvcspawnvehicule', function(source, args, rawCommand)
    if not CVC.Utils.HasPermission(source, 'cvcspawnvehicule') then
        CVC.Utils.NotifyPlayer(source, Config.Notifications.noPermission)
        return
    end
    
    -- Capturer source avant le thread
    local playerId = source
    
    -- Spawn dans un thread séparé
    CreateThread(function()
        local count = CVC.Vehicles.SpawnAll()
        
        -- Notifier le joueur
        if playerId and playerId > 0 then
            CVC.Utils.NotifyPlayer(playerId, string.format('%d véhicules spawnés', count))
        end
    end)
end, false)

-- ═══════════════════════════════════════════════════════════════════════════
-- /cvcdeletevehicles - Supprimer tous les véhicules
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('cvcdeletevehicles', function(source, args, rawCommand)
    if not CVC.Utils.HasPermission(source, 'cvcspawnvehicule') then
        CVC.Utils.NotifyPlayer(source, Config.Notifications.noPermission)
        return
    end
    
    local count = CVC.Vehicles.DeleteAll()
    CVC.Utils.NotifyPlayer(source, string.format('%d véhicules supprimés', count))
end, false)

-- ═══════════════════════════════════════════════════════════════════════════
-- /cvckickall - Expulser tous les joueurs du mode
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('cvckickall', function(source, args, rawCommand)
    if not CVC.Utils.HasPermission(source, 'cvckickall') then
        TriggerClientEvent('cvc:client:notify', source, Config.Notifications.noPermission)
        return
    end
    
    CVC.Vehicles.DeleteAll()
    local kickedCount = CVC.Players.KickAll()
    
    TriggerClientEvent('cvc:client:notify', source, 
        string.format('%s (%d joueurs)', Config.Notifications.kickedAll, kickedCount))
    
    if Config.Debug then
        CVC.Utils.Debug('cvckickall: %d joueurs expulsés', kickedCount)
    end
end, false)

-- ═══════════════════════════════════════════════════════════════════════════
-- /cvckick [id] - Expulser un joueur spécifique
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('cvckick', function(source, args, rawCommand)
    if not CVC.Utils.HasPermission(source, 'cvckick') then
        TriggerClientEvent('cvc:client:notify', source, Config.Notifications.noPermission)
        return
    end
    
    local targetId = tonumber(args[1])
    
    if not targetId then
        TriggerClientEvent('cvc:client:notify', source, 'Usage: /cvckick [id]')
        return
    end
    
    if not CVC.Players.IsInMode(targetId) then
        TriggerClientEvent('cvc:client:notify', source, Config.Notifications.playerNotFound)
        return
    end
    
    local success = CVC.Players.Kick(targetId)
    
    if success then
        TriggerClientEvent('cvc:client:notify', source, 
            string.format('Joueur %d expulsé du mode', targetId))
    else
        TriggerClientEvent('cvc:client:notify', source, Config.Notifications.playerNotFound)
    end
end, false)

-- ═══════════════════════════════════════════════════════════════════════════
-- /cvcannonce [texte] - Afficher une annonce
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('cvcannonce', function(source, args, rawCommand)
    if not CVC.Utils.HasPermission(source, 'cvcannonce') then
        TriggerClientEvent('cvc:client:notify', source, Config.Notifications.noPermission)
        return
    end
    
    local text = table.concat(args, ' ')
    
    if text == '' then
        TriggerClientEvent('cvc:client:notify', source, 'Usage: /cvcannonce [texte]')
        return
    end
    
    local allPlayers = CVC.Players.GetAllInMode()
    
    for _, playerId in ipairs(allPlayers) do
        TriggerClientEvent('cvc:client:showAnnouncement', playerId, text)
    end
    
    TriggerClientEvent('cvc:client:notify', source, 
        string.format('Annonce envoyée à %d joueurs', #allPlayers))
end, false)

-- ═══════════════════════════════════════════════════════════════════════════
-- SUGGESTIONS DE COMMANDES
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    Wait(1000)
    
    TriggerClientEvent('chat:addSuggestion', -1, '/cvchealall', 'Soigner tous les joueurs dans un rayon', {
        { name = 'radius', help = 'Rayon en mètres (défaut: 50)' }
    })
    
    TriggerClientEvent('chat:addSuggestion', -1, '/cvcequipe', 'Afficher le nombre de joueurs par équipe', {})
    
    TriggerClientEvent('chat:addSuggestion', -1, '/givecallall', 'Donner des armes aux joueurs dans un rayon', {
        { name = 'radius', help = 'Rayon en mètres (défaut: 50)' }
    })
    
    TriggerClientEvent('chat:addSuggestion', -1, '/cvctpall', 'Téléporter tous les joueurs en équipe vers vous', {})
    
    TriggerClientEvent('chat:addSuggestion', -1, '/cvctpequipe', 'Téléporter une équipe spécifique vers vous', {
        { name = 'équipe', help = 'rouge ou bleu' }
    })
    
    TriggerClientEvent('chat:addSuggestion', -1, '/cvcrepairall', 'Réparer les véhicules dans un rayon', {
        { name = 'radius', help = 'Rayon en mètres (défaut: 50)' }
    })
    
    TriggerClientEvent('chat:addSuggestion', -1, '/cvcspawnvehicule', 'Spawn les véhicules du convoi', {})
    
    TriggerClientEvent('chat:addSuggestion', -1, '/cvcdeletevehicles', 'Supprimer tous les véhicules', {})
    
    TriggerClientEvent('chat:addSuggestion', -1, '/cvckickall', 'Expulser tous les joueurs du mode', {})
    
    TriggerClientEvent('chat:addSuggestion', -1, '/cvckick', 'Expulser un joueur du mode', {
        { name = 'id', help = 'ID du joueur' }
    })
    
    TriggerClientEvent('chat:addSuggestion', -1, '/cvcannonce', 'Envoyer une annonce à tous les joueurs', {
        { name = 'texte', help = 'Message à afficher' }
    })
end)