-- ============================================================
-- LOGGING DES CHANGEMENTS DE SIÈGE
-- ============================================================

local seatChangeStats = {}

-- ============================================================
-- ÉVÉNEMENTS
-- ============================================================

--- Événement déclenché quand un joueur change de siège
RegisterNetEvent('seatChange:changed', function(playerId, fromSeat, toSeat)
    local source = source
    local playerName = GetPlayerName(source) or "Inconnu"
    
    -- Initialiser les stats du joueur
    if not seatChangeStats[source] then
        seatChangeStats[source] = {
            count = 0,
            lastChange = 0
        }
    end
    
    seatChangeStats[source].count = seatChangeStats[source].count + 1
    seatChangeStats[source].lastChange = os.time()
    
    -- Log console
    if Config.Debug then
        print(string.format(
            '^3[SeatChange]^7 %s a changé de siège : %d -> %d (Total: %d)',
            playerName,
            fromSeat,
            toSeat,
            seatChangeStats[source].count
        ))
    end
    
    -- Log Discord (optionnel)
    if Config.EnableServerLogging and Config.DiscordWebhook ~= "" then
        local identifiers = GetPlayerIdentifiers(source)
        
        SendDiscordLog(
            "🔄 Changement de siège",
            string.format(
                "**Joueur:** %s\n**De:** Siège %d\n**Vers:** Siège %d\n**Total changements:** %d\n**Steam:** %s",
                playerName,
                fromSeat,
                toSeat,
                seatChangeStats[source].count,
                identifiers.steam or "N/A"
            ),
            3066993 -- Couleur verte
        )
    end
end)

-- ============================================================
-- COMMANDES ADMIN
-- ============================================================

--- Commande pour voir les statistiques de changements de siège
RegisterCommand('seatstats', function(source, args, rawCommand)
    if source ~= 0 then
        -- Vérifier permissions admin
    end
    
    print('^2=== STATISTIQUES CHANGEMENTS DE SIÈGE ===^7')
    
    local totalChanges = 0
    for playerId, data in pairs(seatChangeStats) do
        local name = GetPlayerName(playerId) or "Déconnecté"
        print(string.format('  - %s: %d changements', name, data.count))
        totalChanges = totalChanges + data.count
    end
    
    print(string.format('Total: %d changements', totalChanges))
end, false)

--- Commande pour forcer la fermeture de l'UI d'un joueur
RegisterCommand('closeseatui', function(source, args, rawCommand)
    if source ~= 0 then
        -- Vérifier permissions admin
    end
    
    local targetId = tonumber(args[1])
    if not targetId then
        print('^1Usage: /closeseatui [playerID]^7')
        return
    end
    
    TriggerClientEvent('seatChange:closeUI', targetId)
    print('^2Interface de changement de siège fermée pour le joueur ' .. targetId .. '^7')
end, false)

-- ============================================================
-- NETTOYAGE
-- ============================================================

--- Nettoie les stats des joueurs déconnectés
CreateThread(function()
    while true do
        Wait(1800000) -- 30 minutes
        
        local activePlayers = GetPlayers()
        local activeIds = {}
        
        for _, player in ipairs(activePlayers) do
            activeIds[tonumber(player)] = true
        end
        
        for playerId, _ in pairs(seatChangeStats) do
            if not activeIds[playerId] then
                seatChangeStats[playerId] = nil
            end
        end
        
        if Config.Debug then
            print('^3[SeatChange]^7 Nettoyage des statistiques effectué')
        end
    end
end)

-- ============================================================
-- EXPORTS
-- ============================================================

--- Export pour obtenir les stats d'un joueur
---@param playerId number ID du joueur
---@return table Stats du joueur
exports('GetPlayerSeatStats', function(playerId)
    return seatChangeStats[playerId] or {count = 0, lastChange = 0}
end)

--- Export pour réinitialiser les stats d'un joueur
---@param playerId number ID du joueur
exports('ResetPlayerSeatStats', function(playerId)
    seatChangeStats[playerId] = nil
end)

-- ============================================================
-- INITIALISATION
-- ============================================================

print('^2[SeatChange]^7 Module de changement de siège (serveur) chargé')