Config = {}

-- ============================================================
-- CONFIGURATION GÉNÉRALE
-- ============================================================

-- Activer/désactiver le système
Config.Enabled = true

-- Mode debug (affiche des messages dans la console F8)
Config.Debug = false

-- ============================================================
-- RÈGLES DE TIR PAR SIÈGE
-- ============================================================

-- Définir quels sièges peuvent tirer (true = peut tirer, false = bloqué)
Config.SeatRules = {
    [-1] = false,  -- Conducteur (driver)
    [0] = false,   -- Passager avant droit
    [1] = false,   -- Passager arrière gauche
    [2] = false,   -- Passager arrière droit
    -- Ajoutez d'autres sièges si besoin (bus, etc.)
}

-- Alternative : Bloquer tous les sièges par défaut
Config.BlockAllSeats = true

-- Liste blanche de sièges autorisés (si BlockAllSeats = true)
-- Par exemple, pour autoriser uniquement les passagers arrière
Config.AllowedSeats = {
    -- [1] = true,  -- Passager arrière gauche
    -- [2] = true,  -- Passager arrière droit
}

-- ============================================================
-- EXCEPTIONS PAR TYPE DE VÉHICULE
-- ============================================================

-- Classes de véhicules où le tir est toujours autorisé
-- Liste des classes : https://docs.fivem.net/natives/?_0x29439776AAA00A62
Config.AllowedVehicleClasses = {
    -- [15] = true,  -- Hélicoptères
    -- [16] = true,  -- Avions
}

-- Véhicules spécifiques autorisés (par model hash ou nom)
Config.AllowedVehicleModels = {
    -- ['insurgent'] = true,
    -- ['technical'] = true,
    -- GetHashKey('insurgent')
}

-- Véhicules d'urgence exemptés (police, ambulance, etc.)
Config.AllowEmergencyVehicles = false

-- ============================================================
-- NOTIFICATIONS
-- ============================================================

-- Activer les notifications à l'écran
Config.ShowNotifications = true

-- Message affiché quand le joueur tente de tirer
Config.NotificationMessage = "~r~Vous ne pouvez pas tirer depuis ce véhicule !"

-- Durée de la notification (en ms)
Config.NotificationDuration = 3000

-- Cooldown entre notifications (évite le spam)
Config.NotificationCooldown = 2000

-- ============================================================
-- PERFORMANCES
-- ============================================================

-- Intervalle de vérification (en ms) - Plus élevé = meilleur pour les performances
-- Recommandé : 100-200ms pour un bon équilibre
Config.CheckInterval = 150

-- Utiliser les événements natifs au lieu d'un thread (plus performant)
-- Note : nécessite de surveiller les changements de véhicule
Config.UseNativeEvents = true

-- ============================================================
-- SYSTÈME DE LOGGING (SERVEUR)
-- ============================================================

-- Logger les tentatives de tir en véhicule côté serveur
Config.EnableServerLogging = false

-- Webhook Discord pour les logs (optionnel)
Config.DiscordWebhook = ""

-- ============================================================
-- SYSTÈME DE CHANGEMENT DE SIÈGE
-- ============================================================

-- Activer le système de changement de siège
Config.EnableSeatChange = true

-- Touche pour ouvrir le menu (H par défaut)
Config.SeatChangeKey = 74  -- H

-- Animation lors du changement de siège
Config.EnableSeatAnimation = true
Config.SeatAnimationDuration = 800 -- ms

-- Cooldown entre changements de siège (anti-spam)
Config.SeatChangeCooldown = 1000 -- ms

-- Bloquer changement si véhicule en mouvement
Config.BlockSeatChangeIfMoving = false
Config.MaxSpeedForSeatChange = 5.0 -- km/h maximum

-- ============================================================
-- FONCTIONS UTILITAIRES
-- ============================================================

-- Fonction pour vérifier si un véhicule est dans la liste blanche
function Config.IsVehicleAllowed(vehicle)
    local class = GetVehicleClass(vehicle)
    local model = GetEntityModel(vehicle)
    
    -- Vérifier classe
    if Config.AllowedVehicleClasses[class] then
        return true
    end
    
    -- Vérifier modèle
    if Config.AllowedVehicleModels[model] then
        return true
    end
    
    -- Vérifier véhicule d'urgence
    if Config.AllowEmergencyVehicles and GetVehicleClass(vehicle) == 18 then
        return true
    end
    
    return false
end

-- Fonction pour vérifier si un siège est autorisé
function Config.IsSeatAllowed(seatIndex)
    if Config.BlockAllSeats then
        return Config.AllowedSeats[seatIndex] == true
    else
        return Config.SeatRules[seatIndex] ~= false
    end
end