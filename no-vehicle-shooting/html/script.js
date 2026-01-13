// ============================================================
// VARIABLES GLOBALES
// ============================================================

let isOpen = false;
let currentSeat = null;
let availableSeats = [];

// ============================================================
// GESTION DE L'AFFICHAGE
// ============================================================

/**
 * Affiche ou masque le sélecteur de sièges
 */
function toggleDisplay(show) {
    const selector = document.getElementById('seatSelector');
    
    if (show) {
        selector.classList.remove('hidden');
        isOpen = true;
    } else {
        selector.classList.add('hidden');
        isOpen = false;
        hideMessage();
    }
}

/**
 * Met à jour l'interface avec les données des sièges
 */
function updateSeats(data) {
    currentSeat = data.currentSeat;
    availableSeats = data.seats || [];
    
    // Réinitialiser tous les sièges
    const allSeats = document.querySelectorAll('.seat, .seat-middle');
    allSeats.forEach(seat => {
        const seatIndex = parseInt(seat.getAttribute('data-seat'));
        const seatInfo = availableSeats.find(s => s.index === seatIndex);
        
        // Réinitialiser les classes
        seat.classList.remove('occupied', 'current', 'unavailable');
        seat.querySelector('.seat-status').textContent = '';
        
        if (!seatInfo) {
            // Siège n'existe pas dans ce véhicule
            seat.classList.add('unavailable');
            seat.querySelector('.seat-status').textContent = 'Indisponible';
        } else if (seatInfo.occupied && seatIndex !== currentSeat) {
            // Siège occupé par un autre joueur
            seat.classList.add('occupied');
            seat.querySelector('.seat-status').textContent = 'Occupé';
        } else if (seatIndex === currentSeat) {
            // Siège actuel du joueur
            seat.classList.add('current');
            seat.querySelector('.seat-status').textContent = 'Position actuelle';
        } else {
            // Siège disponible
            seat.querySelector('.seat-status').textContent = 'Disponible';
        }
    });
    
    // Afficher/masquer les sièges supplémentaires
    const extraRow = document.getElementById('extra-seats');
    const hasExtraSeats = availableSeats.some(s => s.index >= 4);
    
    if (hasExtraSeats) {
        extraRow.classList.add('visible');
    } else {
        extraRow.classList.remove('visible');
    }
}

/**
 * Affiche un message d'information
 */
function showMessage(message, type = 'info') {
    const messageEl = document.getElementById('infoMessage');
    messageEl.textContent = message;
    messageEl.className = 'info-message show';
    
    if (type === 'error') {
        messageEl.classList.add('error');
    } else if (type === 'success') {
        messageEl.classList.add('success');
    }
    
    // Auto-masquer après 3 secondes
    setTimeout(() => {
        hideMessage();
    }, 3000);
}

/**
 * Masque le message d'information
 */
function hideMessage() {
    const messageEl = document.getElementById('infoMessage');
    messageEl.classList.remove('show');
}

// ============================================================
// GESTION DES ÉVÉNEMENTS
// ============================================================

/**
 * Gère le clic sur un siège
 */
function handleSeatClick(seatIndex) {
    // Vérifier si c'est le siège actuel
    if (seatIndex === currentSeat) {
        showMessage('Vous êtes déjà à cette place !', 'error');
        return;
    }
    
    // Vérifier si le siège existe et est disponible
    const seatInfo = availableSeats.find(s => s.index === seatIndex);
    
    if (!seatInfo) {
        showMessage('Ce siège n\'existe pas dans ce véhicule !', 'error');
        return;
    }
    
    if (seatInfo.occupied) {
        showMessage('Ce siège est déjà occupé !', 'error');
        return;
    }
    
    // Envoyer la demande de changement de siège
    fetch(`https://${GetParentResourceName()}/changeSeat`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            seat: seatIndex
        })
    });
    
    // Fermer l'interface
    toggleDisplay(false);
}

/**
 * Ferme l'interface
 */
function closeUI() {
    if (isOpen) {
        fetch(`https://${GetParentResourceName()}/closeUI`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        });
        
        toggleDisplay(false);
    }
}

// ============================================================
// ÉCOUTEURS D'ÉVÉNEMENTS
// ============================================================

// Ajouter les écouteurs de clic sur tous les sièges
document.addEventListener('DOMContentLoaded', () => {
    const seats = document.querySelectorAll('.seat, .seat-middle');
    
    seats.forEach(seat => {
        seat.addEventListener('click', () => {
            const seatIndex = parseInt(seat.getAttribute('data-seat'));
            handleSeatClick(seatIndex);
        });
    });
});

// Gestion de la touche ESC
document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && isOpen) {
        closeUI();
    }
});

// Écouter les messages du client Lua
window.addEventListener('message', (event) => {
    const data = event.data;
    
    switch(data.action) {
        case 'openUI':
            toggleDisplay(true);
            if (data.seats) {
                updateSeats(data.seats);
            }
            break;
            
        case 'closeUI':
            toggleDisplay(false);
            break;
            
        case 'updateSeats':
            if (data.seats) {
                updateSeats(data.seats);
            }
            break;
            
        case 'showMessage':
            showMessage(data.message, data.type || 'info');
            break;
    }
});

// ============================================================
// FONCTIONS UTILITAIRES
// ============================================================

/**
 * Récupère le nom de la ressource parente
 */
function GetParentResourceName() {
    let resourceName = 'no-vehicle-shooting';
    
    // Essayer de récupérer depuis l'URL
    if (window.location.href.includes('://')) {
        const parts = window.location.href.split('/');
        for (let i = 0; i < parts.length; i++) {
            if (parts[i] === 'nui:' && parts[i + 1]) {
                resourceName = parts[i + 1];
                break;
            }
        }
    }
    
    return resourceName;
}