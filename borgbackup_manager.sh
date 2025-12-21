#!/usr/bin/env bash
#===============================================================================
# TP 2 : Script BorgBackup Autonome avec Dépôt Distant Chiffré
# Author: Farah EL Alem
# Description: Script 100% autonome pour backup avec BorgBackup
# Version: 1.0
#===============================================================================

set -euo pipefail

# === CONFIGURATION ===
# Serveur distant
REMOTE_USER="backup"
REMOTE_HOST="192.168.10.253"
REMOTE_PORT="2222"
SSH_KEY="/var/lib/backup/.ssh/id_backup"

# Chemins
BORG_REPO="${REMOTE_USER}@${REMOTE_HOST}:/backup/borg-repo"
LOG_DIR="/backup/logs"
LOG_FILE="$LOG_DIR/borgbackup_$(date +%Y%m%d).log"

# Sources à sauvegarder
declare -a BACKUP_SOURCES=(
    "/etc"
    "/home"
)

# Exclusions
declare -a EXCLUSIONS=(
    "*.cache"
    "*.tmp"
    "/home/*/.cache"
    "/home/*/cache"
    "lost+found"
)

# Passphrase pour le chiffrement (CHANGEZ-LA !)
export BORG_PASSPHRASE="MySecurePassword2024!"
export BORG_RSH="ssh -i $SSH_KEY -p $REMOTE_PORT"

# Rotation des archives
KEEP_DAILY=7
KEEP_WEEKLY=4
KEEP_MONTHLY=3

#----- Fonctions ---------------------------------------------------------------
log() {
    local level=$1
    shift
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
    echo "$message"
    echo "$message" >> "$LOG_FILE"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo "ERREUR: Ce script doit être exécuté en tant que root (sudo)"
        exit 1
    fi
}

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
    log "INFO" "Système détecté: $OS $VERSION"
}

install_borg_local() {
    log "INFO" "Vérification de BorgBackup en local..."
    
    if command -v borg &> /dev/null; then
        local version=$(borg --version 2>&1 | head -1)
        log "INFO" "BorgBackup déjà installé: $version"
        return 0
    fi
    
    log "INFO" "Installation de BorgBackup..."
    case "$OS" in
        debian|ubuntu)
            apt-get update -qq
            apt-get install -y borgbackup
            ;;
        rhel|centos|fedora)
            yum install -y borgbackup
            ;;
        *)
            log "ERROR" "Distribution non supportée"
            exit 1
            ;;
    esac
    
    log "INFO" "BorgBackup installé: $(borg --version)"
}

install_borg_remote() {
    log "INFO" "Vérification de BorgBackup sur le serveur distant..."
    
    # Vérifier la connexion SSH
    if ! ssh -i "$SSH_KEY" -p "$REMOTE_PORT" -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" "exit" 2>/dev/null; then
        log "ERROR" "Impossible de se connecter au serveur distant"
        log "INFO" "Vérifiez les clés SSH et la connectivité"
        exit 1
    fi
    
    # Vérifier si borg est installé sur le serveur distant
    if ssh -i "$SSH_KEY" -p "$REMOTE_PORT" "${REMOTE_USER}@${REMOTE_HOST}" "command -v borg" &> /dev/null; then
        local remote_version=$(ssh -i "$SSH_KEY" -p "$REMOTE_PORT" "${REMOTE_USER}@${REMOTE_HOST}" "borg --version" 2>&1)
        log "INFO" "BorgBackup déjà installé sur le serveur distant: $remote_version"
        return 0
    fi
    
    log "INFO" "Installation de BorgBackup sur le serveur distant..."
    
    # Détecter l'OS distant et installer
    ssh -i "$SSH_KEY" -p "$REMOTE_PORT" "${REMOTE_USER}@${REMOTE_HOST}" "
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            case \$ID in
                debian|ubuntu)
                    sudo apt-get update -qq
                    sudo apt-get install -y borgbackup
                    ;;
                rhel|centos|fedora)
                    sudo yum install -y borgbackup
                    ;;
            esac
        fi
    " || {
        log "ERROR" "Échec de l'installation sur le serveur distant"
        exit 1
    }
    
    log "INFO" "BorgBackup installé sur le serveur distant"
}

verify_ssh_keys() {
    log "INFO" "Vérification des clés SSH..."
    
    if [ ! -f "$SSH_KEY" ]; then
        log "ERROR" "Clé SSH introuvable: $SSH_KEY"
        log "INFO" "Générez les clés avec: ssh-keygen -t ed25519 -f $SSH_KEY"
        exit 1
    fi
    
    # Tester la connexion
    if ssh -i "$SSH_KEY" -p "$REMOTE_PORT" -o ConnectTimeout=5 "${REMOTE_USER}@${REMOTE_HOST}" "echo 'SSH OK'" &> /dev/null; then
        log "INFO" "Connexion SSH validée"
    else
        log "ERROR" "Connexion SSH échouée"
        exit 1
    fi
}

init_repo() {
    log "INFO" "Initialisation du dépôt Borg..."
    
    # Créer le répertoire distant avec sudo
    log "INFO" "Création du répertoire de backup distant..."
    ssh -i "$SSH_KEY" -p "$REMOTE_PORT" "${REMOTE_USER}@${REMOTE_HOST}" "
        sudo mkdir -p /backup/borg-repo
        sudo chown -R ${REMOTE_USER}:${REMOTE_USER} /backup
        sudo chmod 755 /backup
    " || {
        log "ERROR" "Impossible de créer le répertoire distant"
        exit 1
    }
    
    # Vérifier si le dépôt existe déjà
    if borg list "$BORG_REPO" &> /dev/null; then
        log "INFO" "Dépôt Borg déjà initialisé"
        return 0
    fi
    
    # Initialiser le dépôt avec chiffrement
    log "INFO" "Création du dépôt chiffré (repokey-blake2)..."
    if borg init --encryption=repokey-blake2 "$BORG_REPO" 2>&1 | tee -a "$LOG_FILE"; then
        log "INFO" "Dépôt initialisé avec succès"
        log "WARNING" "IMPORTANT: Sauvegardez la passphrase: $BORG_PASSPHRASE"
        log "WARNING" "IMPORTANT: Exportez la clé du dépôt avec: borg key export $BORG_REPO /backup/borg-key-backup.txt"
    else
        log "ERROR" "Échec de l'initialisation du dépôt"
        exit 1
    fi
}

create_backup() {
    local archive_name="backup-$(hostname)-$(date +%Y-%m-%d_%H-%M-%S)"
    
    log "INFO" "===== Création du backup ====="
    log "INFO" "Archive: $archive_name"
    
    # Construire les exclusions
    local exclude_opts=""
    for pattern in "${EXCLUSIONS[@]}"; do
        exclude_opts+="--exclude '$pattern' "
    done
    
    # Créer l'archive
    log "INFO" "Sauvegarde en cours..."
    
    eval "borg create \
        --stats \
        --progress \
        --compression lz4 \
        $exclude_opts \
        '$BORG_REPO::$archive_name' \
        ${BACKUP_SOURCES[*]}" 2>&1 | tee -a "$LOG_FILE" || {
        log "ERROR" "Échec de la création du backup"
        return 1
    }
    
    log "INFO" "Backup créé avec succès: $archive_name"
}

list_archives() {
    log "INFO" "===== Liste des archives ====="
    
    if borg list "$BORG_REPO" 2>&1 | tee -a "$LOG_FILE"; then
        log "INFO" "Liste affichée avec succès"
    else
        log "ERROR" "Impossible de lister les archives"
        return 1
    fi
}

show_archive_content() {
    local archive=$1
    local lines=${2:-30}
    
    if [ -z "$archive" ]; then
        log "ERROR" "Nom d'archive requis"
        log "INFO" "Usage: show <archive_name> [nombre_de_lignes]"
        return 1
    fi
    
    log "INFO" "===== Contenu de l'archive: $archive ====="
    log "INFO" "Affichage des $lines premiers fichiers..."
    
    borg list "$BORG_REPO::$archive" | head -n "$lines"
}

show_archive_info() {
    local archive=$1
    
    if [ -z "$archive" ]; then
        log "ERROR" "Nom d'archive requis"
        return 1
    fi
    
    log "INFO" "Informations sur l'archive: $archive"
    borg info "$BORG_REPO::$archive" 2>&1 | tee -a "$LOG_FILE"
}

extract_file() {
    local archive=$1
    local file_path=$2
    local dest=${3:-.}
    
    if [ -z "$archive" ] || [ -z "$file_path" ]; then
        log "ERROR" "Usage: extract_file <archive> <chemin_fichier> [destination]"
        return 1
    fi
    
    log "INFO" "Restauration: $file_path depuis $archive"
    log "INFO" "Destination: $dest"
    
    # Extraction directe
    mkdir -p "$dest"
    cd "$dest"
    borg extract "$BORG_REPO::$archive" "$file_path" 2>&1 | tee -a "$LOG_FILE"
    
    log "INFO" "Restauration terminée"
    log "INFO" "Fichier restauré dans: $dest/$file_path"
}

restore_interactive() {
    log "INFO" "===== Mode Restauration Interactive ====="
    
    # Lister les archives
    echo "Archives disponibles:"
    borg list "$BORG_REPO"
    echo ""
    
    read -p "Nom de l'archive à restaurer: " archive
    
    if [ -z "$archive" ]; then
        log "ERROR" "Nom d'archive requis"
        return 1
    fi
    
    # Lister le contenu de l'archive
    echo ""
    echo "Contenu de l'archive $archive:"
    borg list "$BORG_REPO::$archive" | head -20
    echo "..."
    echo ""
    
    read -p "Chemin du fichier à restaurer (ex: etc/hostname): " file_path
    
    if [ -z "$file_path" ]; then
        log "ERROR" "Chemin de fichier requis"
        return 1
    fi
    
    read -p "Destination de restauration [/tmp/restore]: " dest
    dest=${dest:-/tmp/restore}
    
    extract_file "$archive" "$file_path" "$dest"
    
    ls -lh "$dest/$file_path"
}

prune_archives() {
    log "INFO" "===== Nettoyage des anciennes archives ====="
    
    borg prune \
        --list \
        --stats \
        --keep-daily=$KEEP_DAILY \
        --keep-weekly=$KEEP_WEEKLY \
        --keep-monthly=$KEEP_MONTHLY \
        "$BORG_REPO" 2>&1 | tee -a "$LOG_FILE"
    
    log "INFO" "Nettoyage terminé"
}

show_help() {
    cat << EOF
Usage: $(basename $0) [COMMAND] [OPTIONS]

COMMANDES:
    init                  Initialiser le dépôt Borg distant
    backup                Créer un nouveau backup
    list                  Lister toutes les archives
    show <archive> [n]    Afficher le contenu d'une archive (n lignes, défaut: 30)
    info <archive>        Afficher les infos détaillées d'une archive
    restore               Mode restauration interactive
    extract               Extraire un fichier spécifique
    prune                 Nettoyer les anciennes archives
    
OPTIONS:
    -h, --help            Afficher cette aide
    
EXEMPLES:
    $(basename $0) init                              # Initialiser le dépôt
    $(basename $0) backup                            # Créer un backup
    $(basename $0) list                              # Lister les archives
    $(basename $0) show backup-2024-12-21...         # Voir le contenu (30 lignes)
    $(basename $0) show backup-2024-12-21... 50      # Voir le contenu (50 lignes)
    $(basename $0) info backup-2024-...              # Infos sur une archive
    $(basename $0) restore                           # Mode interactif
    $(basename $0) prune                             # Nettoyer les archives
    
CONFIGURATION:
    Serveur distant : ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PORT}
    Dépôt Borg      : $BORG_REPO
    Sources         : ${BACKUP_SOURCES[*]}
    
EOF
}

#----- Main --------------------------------------------------------------------
main() {
    local command=${1:-backup}
    
    # Créer les répertoires
    mkdir -p "$LOG_DIR"
    
    case "$command" in
        -h|--help)
            show_help
            exit 0
            ;;
        init)
            log "INFO" "===== Initialisation du dépôt Borg ====="
            check_root
            detect_os
            install_borg_local
            verify_ssh_keys
            install_borg_remote
            init_repo
            log "INFO" "===== Initialisation terminée ====="
            ;;
        backup)
            log "INFO" "===== Début du backup Borg ====="
            check_root
            create_backup
            log "INFO" "===== Backup terminé ====="
            ;;
        list)
            list_archives
            ;;
        show)
            show_archive_content "$2" "${3:-}"
            ;;
        info)
            show_archive_info "$2"
            ;;
        restore)
            restore_interactive
            ;;
        extract)
            extract_file "$2" "$3" "${4:-}"
            ;;
        prune)
            check_root
            prune_archives
            ;;
        *)
            log "ERROR" "Commande inconnue: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
