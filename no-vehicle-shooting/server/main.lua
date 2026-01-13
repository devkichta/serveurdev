-- ============================================================
-- VARIABLES SERVEUR
-- ============================================================

local shootingAttempts = {}

-- ============================================================
-- FONCTIONS UTILITAIRES
-- ============================================================

--- Envoie un log vers Discord
---@param title string Titre du log
---@param description string Description du log
---@param color number Couleur (décimal)
local function SendDiscordLog(title, description, color)
    if not Config.EnableServerLogging or Config.DiscordWebhook == "" then
        return
    end
    
    local embed = {
        {
            ["title"] = title,
            ["description"] = description,
            ["color"] = color,
            ["footer"] = {
                ["text"] = os.date("%d/%m/%Y à %H:%M:%S")
            }
        }
    }
    
    PerformHttpRequest(Config.DiscordWebhook, function(err, text, headers) end, 'POST', json.encode({
        username = "Anti-Tir Véhicule",
        embeds = embed
    }), {['Content-Type'] = 'application/json'})
end

--- Récupère le nom d'un joueur
---@param src number ID du joueur
---@return string Nom du joueur
local function GetPlayerNameSafe(src)
    local name = GetPlayerName(src)
    return name or "Inconnu"
end

--- Récupère les identifiants d'un joueur
---@param source number ID du joueur
---@return table Identifiants
local function GetPlayerIdentifiersSafe(source)
    local identifiers = {}
    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local id = GetPlayerIdentifier(source, i)
        if id then
            local idType = string.match(id, "^([^:]+):")
            identifiers[idType] = id
        end
    end
    return identifiers
end

-- ============================================================
-- ÉVÉNEMENTS RÉSEAU
-- ============================================================

--- Événement déclenché quand un joueur entre dans un véhicule
RegisterNetEvent('noVehicleShooting:playerEnteredVehicle', function(playerId, seatIndex)
    local source = source
    local playerName = GetPlayerNameSafe(source)
    
    if Config.Debug then
        print(string.format('^3[NoVehicleShooting]^7 %s est entré dans un véhicule (Siège: %d)', playerName, seatIndex))
    end
    
    if Config.EnableServerLogging then
        SendDiscordLog(
            "🚗 Joueur en véhicule",
            string.format("**Joueur:** %s\n**Siège:** %d", playerName, seatIndex),
            3447003 -- Bleu
        )
    end
end)

--- Événement déclenché quand un joueur tente de tirer
RegisterNetEvent('noVehicleShooting:shootingAttempt', function(playerId, seatIndex)
    local source = source
    local playerName = GetPlayerNameSafe(source)
    local identifiers = GetPlayerIdentifiersSafe(source)
    
    -- Compteur de tentatives
    if not shootingAttempts[source] then
        shootingAttempts[source] = {
            count = 0,
            lastAttempt = 0
        }
    end
    
    local currentTime = os.time()
    shootingAttempts[source].count = shootingAttempts[source].count + 1
    shootingAttempts[source].lastAttempt = currentTime
    
    -- Log console
    print(string.format(
        '^1[ANTI-CHEAT]^7 %s a tenté de tirer depuis un véhicule (Siège: %d) - Tentatives: %d',
        playerName,
        seatIndex,
        shootingAttempts[source].count
    ))
    
    -- Log Discord
    if Config.EnableServerLogging then
        local color = 16776960 -- Jaune
        
        -- Rouge si tentatives multiples (possible cheat)
        if shootingAttempts[source].count > 5 then
            color = 16711680 -- Rouge
        end
        
        SendDiscordLog(
            "⚠️ Tentative de tir en véhicule",
            string.format(
                "**Joueur:** %s\n**Siège:** %d\n**Tentatives:** %d\n**Steam:** %s\n**License:** %s",
                playerName,
                seatIndex,
                shootingAttempts[source].count,
                identifiers.steam or "N/A",
                identifiers.license or "N/A"
            ),
            color
        )
    end
    
    -- Action anti-cheat (optionnel)
    if shootingAttempts[source].count > 10 then
        print(string.format('^1[ANTI-CHEAT]^7 %s a dépassé 10 tentatives de tir - Action recommandée', playerName))
        
        -- Optionnel : kick/ban automatique
        -- DropPlayer(source, "Tentatives répétées de contournement du système anti-tir")
    end
end)

-- ============================================================
-- COMMANDES ADMIN
-- ============================================================

--- Commande pour activer/désactiver le système pour tous
RegisterCommand('togglevehicleshooting', function(source, args, rawCommand)
    -- Vérifier permissions (à adapter selon votre framework)
    if source ~= 0 then -- Si ce n'est pas la console
        -- Exemple : vérifier si le joueur est admin
        -- if not IsPlayerAdmin(source) then
        --     return
        -- end
    end
    
    Config.Enabled = not Config.Enabled
    
    local message = string.format('Système anti-tir en véhicule %s', Config.Enabled and 'ACTIVÉ' or 'DÉSACTIVÉ')
    print('^2' .. message .. '^7')
    
    -- Notifier tous les clients
    TriggerClientEvent('noVehicleShooting:toggle', -1, Config.Enabled)
    
    if source ~= 0 then
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            multiline = true,
            args = {"[ADMIN]", message}
        })
    end
end, false)

--- Commande pour voir les statistiques
RegisterCommand('shootingstats', function(source, args, rawCommand)
    if source ~= 0 then
        -- Vérifier permissions
    end
    
    print('^2=== STATISTIQUES ANTI-TIR ===^7')
    print(string.format('Joueurs avec tentatives: %d', #shootingAttempts))
    
    for playerId, data in pairs(shootingAttempts) do
        local name = GetPlayerNameSafe(playerId)
        print(string.format('  - %s: %d tentatives', name, data.count))
    end
end, false)

--- Commande pour reset les compteurs
RegisterCommand('resetshootingstats', function(source, args, rawCommand)
    if source ~= 0 then
        -- Vérifier permissions
    end
    
    shootingAttempts = {}
    print('^2Statistiques réinitialisées^7')
    
    if source ~= 0 then
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            args = {"[ADMIN]", "Statistiques réinitialisées"}
        })
    end
end, false)

-- ============================================================
-- NETTOYAGE
-- ============================================================

--- Nettoie les données des joueurs déconnectés toutes les heures
CreateThread(function()
    while true do
        Wait(3600000) -- 1 heure
        
        local activePlayers = GetPlayers()
        local activeIds = {}
        
        for _, player in ipairs(activePlayers) do
            activeIds[tonumber(player)] = true
        end
        
        for playerId, _ in pairs(shootingAttempts) do
            if not activeIds[playerId] then
                shootingAttempts[playerId] = nil
            end
        end
        
        if Config.Debug then
            print('^3[NoVehicleShooting]^7 Nettoyage des données effectué')
        end
    end
end)

-- ============================================================
-- EXPORTS POUR AUTRES SCRIPTS
-- ============================================================

--- Export pour vérifier le nombre de tentatives d'un joueur
---@param playerId number ID du joueur
---@return number Nombre de tentatives
exports('GetShootingAttempts', function(playerId)
    return shootingAttempts[playerId] and shootingAttempts[playerId].count or 0
end)

--- Export pour reset les tentatives d'un joueur
---@param playerId number ID du joueur
exports('ResetPlayerAttempts', function(playerId)
    shootingAttempts[playerId] = nil
end)

-- ============================================================
-- INITIALISATION
-- ============================================================

print('^2[NoVehicleShooting]^7 Script serveur chargé')
if Config.EnableServerLogging then
    print('^2[NoVehicleShooting]^7 Logging Discord activé')
end