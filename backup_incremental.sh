#!/bin/bash
#===============================================================================
# TP 1 : Script de Sauvegarde Incrémentielle avec Hard-Links
# Author: Farah
# Description: Script autonome avec vérification et installation des dépendances
# Version: 2.0 - Production Ready
#===============================================================================

set -e  # Arrêter en cas d'erreur

# === CONFIGURATION ===
SOURCE="/data-test"                    # Répertoire à sauvegarder
BACKUP_DIR="/backup/snapshots"         # Où stocker les snapshots
LOG_DIR="/backup/logs"                 # Logs
DATE=$(date +%Y-%m-%d_%H-%M-%S)
SNAPSHOT_NAME="backup-$DATE"
LATEST_LINK="$BACKUP_DIR/latest"
LOG_FILE="$LOG_DIR/backup_$(date +%Y%m%d).log"

# Nombre de snapshots à conserver
KEEP_SNAPSHOTS=7

# === FONCTION DE LOG ===
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message"
    echo "$message" >> "$LOG_FILE"
}

# === VÉRIFICATION DES PRIVILÈGES ===
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo "ERREUR: Ce script doit être exécuté en tant que root (sudo)"
        exit 1
    fi
}

# === DÉTECTION DU SYSTÈME ===
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    elif [ -f /etc/debian_version ]; then
        OS="debian"
    else
        OS="unknown"
    fi
    log "Système détecté: $OS $VERSION"
}

# === INSTALLATION DES DÉPENDANCES ===
install_dependencies() {
    log "Vérification des dépendances..."
    
    # Vérifier si rsync est installé
    if ! command -v rsync &> /dev/null; then
        log "rsync n'est pas installé. Installation en cours..."
        
        case "$OS" in
            debian|ubuntu)
                apt-get update -qq
                apt-get install -y rsync
                ;;
            rhel|centos|fedora)
                yum install -y rsync
                ;;
            arch)
                pacman -S --noconfirm rsync
                ;;
            *)
                log "ERREUR: Distribution non supportée pour l'auto-installation"
                log "Installez rsync manuellement: apt install rsync"
                exit 1
                ;;
        esac
        
        log "rsync installé avec succès"
    else
        log "rsync est déjà installé ($(rsync --version | head -1))"
    fi
}

# === CRÉATION DES RÉPERTOIRES ===
create_directories() {
    log "Création/vérification des répertoires..."
    
    # Créer les répertoires s'ils n'existent pas
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$SOURCE"
    
    # Vérifier les permissions
    if [ ! -w "$BACKUP_DIR" ]; then
        log "ERREUR: Pas de permission d'écriture sur $BACKUP_DIR"
        exit 1
    fi
    
    log "Répertoires OK"
}

# === VÉRIFICATION DE L'ESPACE DISQUE ===
check_disk_space() {
    local available=$(df -BG "$BACKUP_DIR" | tail -1 | awk '{print $4}' | sed 's/G//')
    log "Espace disque disponible: ${available}G"
    
    if [ "$available" -lt 1 ]; then
        log "ATTENTION: Espace disque faible (< 1G)"
    fi
}

# === CRÉATION DE DONNÉES DE TEST ===
create_test_data() {
    if [ ! -f "$SOURCE/fichier1.txt" ]; then
        log "Création de données de test dans $SOURCE..."
        echo "Fichier 1 - Version initiale - $(date)" > "$SOURCE/fichier1.txt"
        echo "Fichier 2 - Version initiale - $(date)" > "$SOURCE/fichier2.txt"
        echo "Fichier 3 - Version initiale - $(date)" > "$SOURCE/fichier3.txt"
        log "Données de test créées"
    fi
}

# === BACKUP INCRÉMENTIEL ===
perform_backup() {
    log "===== Début du backup incrémentiel ====="
    log "Source: $SOURCE"
    log "Destination: $BACKUP_DIR/$SNAPSHOT_NAME"
    
    # Vérifier que la source existe et n'est pas vide
    if [ ! -d "$SOURCE" ] || [ -z "$(ls -A $SOURCE)" ]; then
        log "ATTENTION: Le répertoire source est vide ou n'existe pas"
        create_test_data
    fi
    
    # Options rsync
    RSYNC_OPTS="-av --delete --stats"
    
    # Si un snapshot précédent existe, utiliser --link-dest
    if [ -L "$LATEST_LINK" ] && [ -d "$LATEST_LINK" ]; then
        local previous=$(readlink -f "$LATEST_LINK")
        log "Snapshot précédent trouvé: $(basename $previous)"
        log "Utilisation des hard-links pour économiser l'espace"
        RSYNC_OPTS="$RSYNC_OPTS --link-dest=$LATEST_LINK"
    else
        log "Premier backup, création complète"
    fi
    
    # Exécuter rsync
    log "Lancement de rsync..."
    if rsync $RSYNC_OPTS "$SOURCE/" "$BACKUP_DIR/$SNAPSHOT_NAME/" >> "$LOG_FILE" 2>&1; then
        log "Rsync réussi"
        
        # Mettre à jour le lien 'latest'
        rm -f "$LATEST_LINK"
        ln -s "$SNAPSHOT_NAME" "$LATEST_LINK"
        log "Lien 'latest' mis à jour"
        
        # Statistiques
        display_stats
        
        # Rotation des anciens snapshots
        rotate_snapshots
        
        log "===== Backup terminé avec succès ====="
        return 0
    else
        log "ERREUR: Rsync a échoué"
        return 1
    fi
}

# === AFFICHAGE DES STATISTIQUES ===
display_stats() {
    log "--- Statistiques ---"
    
    # Taille du snapshot
    local snapshot_size=$(du -sh "$BACKUP_DIR/$SNAPSHOT_NAME" 2>/dev/null | cut -f1)
    log "Taille du snapshot: $snapshot_size"
    
    # Taille totale
    local total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    log "Taille totale des backups: $total_size"
    
    # Nombre de snapshots
    local count=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup-*" | wc -l)
    log "Nombre de snapshots: $count"
    
    # Vérifier les hard-links (pour démonstration)
    if [ -L "$LATEST_LINK" ]; then
        local previous_snapshot=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup-*" | sort | tail -2 | head -1)
        if [ -n "$previous_snapshot" ] && [ -d "$previous_snapshot" ]; then
            local test_file=$(find "$SOURCE" -type f | head -1)
            if [ -n "$test_file" ]; then
                local filename=$(basename "$test_file")
                local inode_new=$(ls -i "$BACKUP_DIR/$SNAPSHOT_NAME/$filename" 2>/dev/null | awk '{print $1}')
                local inode_old=$(ls -i "$previous_snapshot/$filename" 2>/dev/null | awk '{print $1}')
                
                if [ "$inode_new" = "$inode_old" ] && [ -n "$inode_new" ]; then
                    log "Hard-links détectés (économie d'espace) ✓"
                fi
            fi
        fi
    fi
}

# === ROTATION DES SNAPSHOTS ===
rotate_snapshots() {
    log "Rotation des snapshots (garder les $KEEP_SNAPSHOTS derniers)..."
    
    local snapshots=($(find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup-*" | sort))
    local count=${#snapshots[@]}
    
    if [ "$count" -gt "$KEEP_SNAPSHOTS" ]; then
        local to_delete=$((count - KEEP_SNAPSHOTS))
        log "Suppression de $to_delete ancien(s) snapshot(s)..."
        
        for ((i=0; i<$to_delete; i++)); do
            local snapshot="${snapshots[$i]}"
            log "Suppression: $(basename $snapshot)"
            rm -rf "$snapshot"
        done
    else
        log "Aucune rotation nécessaire ($count/$KEEP_SNAPSHOTS snapshots)"
    fi
}

# === AFFICHAGE DE L'AIDE ===
show_help() {
    cat << EOF
Usage: $(basename $0) [OPTIONS]

Script de sauvegarde incrémentielle avec hard-links (TP1)

OPTIONS:
    -h, --help          Afficher cette aide
    -s, --source DIR    Spécifier le répertoire source (défaut: $SOURCE)
    -d, --dest DIR      Spécifier le répertoire de destination (défaut: $BACKUP_DIR)
    -k, --keep N        Nombre de snapshots à conserver (défaut: $KEEP_SNAPSHOTS)
    --dry-run           Simuler sans effectuer le backup
    --stats             Afficher uniquement les statistiques
    
EXEMPLES:
    $(basename $0)                          # Backup avec les paramètres par défaut
    $(basename $0) -s /etc -d /backup/etc   # Backup personnalisé
    $(basename $0) --stats                  # Voir les statistiques
    
EOF
}

# === AFFICHAGE DES STATISTIQUES UNIQUEMENT ===
show_stats_only() {
    echo "=== Statistiques des Backups ==="
    echo ""
    echo "Répertoire: $BACKUP_DIR"
    echo ""
    
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "Aucun backup trouvé"
        exit 0
    fi
    
    echo "Liste des snapshots:"
    ls -lh "$BACKUP_DIR" | grep "^d" || echo "Aucun snapshot"
    echo ""
    
    echo "Espace disque:"
    du -sh "$BACKUP_DIR"/backup-* 2>/dev/null || echo "Aucun snapshot"
    echo ""
    
    echo "Total:"
    du -sh "$BACKUP_DIR"
    echo ""
    
    if [ -L "$LATEST_LINK" ]; then
        echo "Dernier snapshot: $(readlink $LATEST_LINK)"
    fi
}

# === GESTION DES ARGUMENTS ===
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -s|--source)
                SOURCE="$2"
                shift 2
                ;;
            -d|--dest)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -k|--keep)
                KEEP_SNAPSHOTS="$2"
                shift 2
                ;;
            --dry-run)
                log "Mode DRY-RUN activé (simulation)"
                RSYNC_OPTS="$RSYNC_OPTS --dry-run"
                shift
                ;;
            --stats)
                show_stats_only
                exit 0
                ;;
            *)
                echo "Option inconnue: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# === MAIN ===
main() {
    # Vérifier les privilèges
    check_root
    
    # Détecter le système
    detect_os
    
    # Installer les dépendances
    install_dependencies
    
    # Créer les répertoires
    create_directories
    
    # Vérifier l'espace disque
    check_disk_space
    
    # Effectuer le backup
    if perform_backup; then
        exit 0
    else
        exit 1
    fi
}

# === POINT D'ENTRÉE ===
parse_arguments "$@"
main
