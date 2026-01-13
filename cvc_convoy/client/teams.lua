--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                    CONVOI CONTRE CONVOI - GESTION ÉQUIPES (CLIENT)        ║
    ║                    MODIFIÉ : Changement d'équipe dynamique                ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
]]

CVC = CVC or {}
CVC.Teams = {}

local teamZonesActive = false
local lastZoneCheck = nil
local isChangingTeam = false -- Nouveau: flag pour éviter le spam

-- ═══════════════════════════════════════════════════════════════════════════
-- GESTION DES ZONES D'ÉQUIPE
-- ═══════════════════════════════════════════════════════════════════════════

function CVC.Teams.StartZoneCheck()
    if teamZonesActive then return end
    teamZonesActive = true
    
    CVC.Utils.Debug('Démarrage de la vérification des zones d\'équipe')
    
    CreateThread(function()
        while teamZonesActive and CVC.State.inGameMode do
            local sleep = 0
            local playerCoords = GetEntityCoords(PlayerPedId())
            local currentZone = nil
            
            -- Dessiner les marqueurs des zones
            for teamName, zone in pairs(Config.TeamZones) do
                CVC.Utils.DrawMarker(zone.coords, zone.radius, zone.color)
                
                -- Afficher le label au-dessus de la zone
                local labelText = zone.label
                
                -- NOUVEAU : Afficher un message différent selon la situation
                if CVC.State.currentTeam then
                    if CVC.State.currentTeam == teamName then
                        labelText = zone.label .. " (Votre équipe)"
                    else
                        labelText = zone.label .. " - Appuyez sur ~INPUT_CONTEXT~ pour changer"
                    end
                else
                    labelText = zone.label .. " - Entrez pour rejoindre"
                end
                
                CVC.Utils.DrawText3D(
                    vector3(zone.coords.x, zone.coords.y, zone.coords.z + 0.5),
                    labelText
                )
                
                -- Vérifier si le joueur est dans la zone
                if CVC.Utils.IsInZone(playerCoords, zone.coords, zone.radius) then
                    currentZone = teamName
                end
            end
            
            -- NOUVEAU : Logique de changement d'équipe
            if currentZone then
                -- Si le joueur n'a pas d'équipe, rejoindre automatiquement
                if not CVC.State.currentTeam and currentZone ~= lastZoneCheck then
                    lastZoneCheck = currentZone
                    CVC.Utils.Debug('Joueur entré dans la zone: %s', currentZone)
                    TriggerServerEvent('cvc:server:joinTeam', currentZone)
                    
                -- Si le joueur a déjà une équipe différente, demander confirmation
                elseif CVC.State.currentTeam and CVC.State.currentTeam ~= currentZone then
                    if not isChangingTeam then
                        -- Afficher une instruction pour changer d'équipe
                        CVC.Utils.DrawText3D(
                            vector3(Config.TeamZones[currentZone].coords.x, Config.TeamZones[currentZone].coords.y, Config.TeamZones[currentZone].coords.z + 1.5),
                            "~y~Appuyez sur ~INPUT_CONTEXT~ pour changer d'équipe~s~"
                        )
                        
                        -- Vérifier l'appui sur E
                        if IsControlJustReleased(0, 38) then -- Touche E
                            isChangingTeam = true
                            CVC.Utils.Debug('Demande de changement d\'équipe: %s -> %s', CVC.State.currentTeam, currentZone)
                            TriggerServerEvent('cvc:server:changeTeam', currentZone)
                            
                            -- Reset du flag après 2 secondes pour éviter le spam
                            SetTimeout(2000, function()
                                isChangingTeam = false
                            end)
                        end
                    end
                end
                
                lastZoneCheck = currentZone
            else
                lastZoneCheck = nil
            end
            
            Wait(sleep)
        end
        
        CVC.Utils.Debug('Arrêt de la vérification des zones d\'équipe')
    end)
end

function CVC.Teams.StopZoneCheck()
    teamZonesActive = false
    lastZoneCheck = nil
    isChangingTeam = false
end

-- ═══════════════════════════════════════════════════════════════════════════
-- APPLICATION DE LA TENUE D'ÉQUIPE
-- ═══════════════════════════════════════════════════════════════════════════

function CVC.Teams.ApplyTeamOutfit(team)
    if not team or not Config.Outfits[team] then
        CVC.Utils.Debug('Équipe invalide pour la tenue: %s', tostring(team))
        return
    end
    
    local gender = CVC.Utils.GetPlayerGender()
    local outfit = Config.Outfits[team][gender]
    
    if not outfit then
        CVC.Utils.Debug('Pas de tenue trouvée pour: %s/%s', team, gender)
        return
    end
    
    CVC.Utils.Debug('Application de la tenue: %s/%s', team, gender)
    CVC.Utils.ApplyOutfit(outfit)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENTS
-- ═══════════════════════════════════════════════════════════════════════════

-- Confirmation de l'équipe rejointe
RegisterNetEvent('cvc:client:teamJoined', function(team)
    CVC.State.currentTeam = team
    CVC.Teams.ApplyTeamOutfit(team)
    
    local notification = team == 'red' and Config.Notifications.joinedRed or Config.Notifications.joinedBlue
    CVC.Utils.Notify(notification)
    
    CVC.Utils.Debug('Équipe rejointe: %s', team)
end)

-- NOUVEAU : Confirmation du changement d'équipe
RegisterNetEvent('cvc:client:teamChanged', function(oldTeam, newTeam)
    CVC.State.currentTeam = newTeam
    CVC.Teams.ApplyTeamOutfit(newTeam)
    
    local oldTeamLabel = oldTeam == 'red' and '~r~Rouge~s~' or '~b~Bleue~s~'
    local newTeamLabel = newTeam == 'red' and '~r~Rouge~s~' or '~b~Bleue~s~'
    
    CVC.Utils.Notify(string.format(
        "Vous avez changé de l'équipe %s vers l'équipe %s",
        oldTeamLabel,
        newTeamLabel
    ))
    
    CVC.Utils.Debug('Équipe changée: %s -> %s', oldTeam, newTeam)
end)

-- Mise à jour du compteur d'équipe (pour l'admin)
RegisterNetEvent('cvc:client:teamCount', function(redCount, blueCount)
    local message = string.format(
        "~r~Équipe Rouge: %d~s~ | ~b~Équipe Bleue: %d~s~",
        redCount, blueCount
    )
    CVC.Utils.Notify(message)
end)
