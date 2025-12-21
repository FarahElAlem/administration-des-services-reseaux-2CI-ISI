#!/usr/bin/env bash
#===============================================================================
# TP 2 : Script BorgBackup Autonome avec Alertes Email
# Author: Farah El Alem
# Description: Script 100% autonome avec notifications email
# Version: 7.0 - Avec alertes email automatiques
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
EMAIL_CONFIG="/backup/.email_config"

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

#----- Fonctions Email ---------------------------------------------------------
install_email_tools() {
    log "INFO" "Installation des outils email..."
    
    case "$OS" in
        debian|ubuntu)
            apt-get update -qq
            apt-get install -y msmtp msmtp-mta mailutils
            ;;
        rhel|centos|fedora)
            yum install -y msmtp mailx
            ;;
        *)
            log "WARNING" "Distribution non supportée pour l'installation automatique d'email"
            return 1
            ;;
    esac
    
    log "INFO" "Outils email installés avec succès"
}

setup_email() {
    log "INFO" "===== Configuration des alertes email ====="
    
    # Vérifier si déjà configuré
    if [ -f "$EMAIL_CONFIG" ]; then
        log "INFO" "Configuration email déjà présente"
        return 0
    fi
    
    # Installer les outils si nécessaire
    if ! command -v msmtp &> /dev/null; then
        log "INFO" "Installation de msmtp..."
        install_email_tools || {
            log "ERROR" "Impossible d'installer msmtp"
            return 1
        }
    fi
    
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║  CONFIGURATION DES ALERTES EMAIL                      ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    
    # Demander les informations
    read -p "Votre email (destinataire des alertes) : " ADMIN_EMAIL
    
    echo ""
    echo "Choisissez votre fournisseur email :"
    echo "1) Gmail"
    echo "2) Outlook/Hotmail"
    echo "3) Yahoo"
    echo "4) Autre (SMTP personnalisé)"
    read -p "Choix [1-4] : " EMAIL_PROVIDER
    
    case $EMAIL_PROVIDER in
        1)
            SMTP_HOST="smtp.gmail.com"
            SMTP_PORT="587"
            echo ""
            echo "⚠️  Pour Gmail, vous devez créer un mot de passe d'application :"
            echo "   1. Allez sur https://myaccount.google.com/security"
            echo "   2. Activez la validation en 2 étapes"
            echo "   3. Créez un mot de passe d'application"
            echo ""
            ;;
        2)
            SMTP_HOST="smtp-mail.outlook.com"
            SMTP_PORT="587"
            ;;
        3)
            SMTP_HOST="smtp.mail.yahoo.com"
            SMTP_PORT="587"
            ;;
        4)
            read -p "Serveur SMTP : " SMTP_HOST
            read -p "Port SMTP : " SMTP_PORT
            ;;
        *)
            log "ERROR" "Choix invalide"
            return 1
            ;;
    esac
    
    read -p "Email d'envoi : " SMTP_USER
    read -sp "Mot de passe : " SMTP_PASS
    echo ""
    
    # Créer la configuration msmtp
    cat > /tmp/msmtprc << EOF
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account        backup
host           $SMTP_HOST
port           $SMTP_PORT
from           $SMTP_USER
user           $SMTP_USER
password       $SMTP_PASS

account default : backup
EOF
    
    # Installer la configuration
    sudo mv /tmp/msmtprc /etc/msmtprc
    sudo chmod 600 /etc/msmtprc
    sudo touch /var/log/msmtp.log
    sudo chmod 666 /var/log/msmtp.log
    
    # Sauvegarder l'email de l'admin
    echo "ADMIN_EMAIL=$ADMIN_EMAIL" > "$EMAIL_CONFIG"
    chmod 600 "$EMAIL_CONFIG"
    
    # Test d'envoi
    log "INFO" "Test d'envoi d'email..."
    if send_test_email; then
        log "INFO" "✅ Configuration email réussie !"
        log "INFO" "Vous recevrez désormais des alertes à : $ADMIN_EMAIL"
    else
        log "ERROR" "❌ Échec de l'envoi de test"
        log "INFO" "Vérifiez vos paramètres et réessayez"
        return 1
    fi
}

send_test_email() {
    if [ ! -f "$EMAIL_CONFIG" ]; then
        return 1
    fi
    
    source "$EMAIL_CONFIG"
    
    cat <<EOF | mail -s "✅ BorgBackup - Configuration Email Réussie" "$ADMIN_EMAIL"
Félicitations !

La configuration des alertes email pour BorgBackup est terminée.

Vous recevrez désormais des notifications automatiques pour :
- ✅ Backups réussis
- ❌ Backups échoués  
- ⚠️ Avertissements

Serveur : $(hostname)
Date : $(date)

---
BorgBackup Manager v7.0
EOF
    
    return $?
}

send_alert() {
    local status=$1
    local subject=$2
    local message=$3
    
    # Vérifier si email configuré
    if [ ! -f "$EMAIL_CONFIG" ]; then
        return 0
    fi
    
    source "$EMAIL_CONFIG"
    
    local icon
    case $status in
        success) icon="✅" ;;
        error)   icon="❌" ;;
        warning) icon="⚠️" ;;
        *) icon="ℹ️" ;;
    esac
    
    # Envoyer l'email
    cat <<EOF | mail -s "$icon BorgBackup - $subject" "$ADMIN_EMAIL"
$message

---
Serveur : $(hostname)
Date : $(date)
Logs : $LOG_FILE

---
BorgBackup Manager v7.0
EOF
}

#----- Fonctions Originales ----------------------------------------------------
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
    
    if ! ssh -i "$SSH_KEY" -p "$REMOTE_PORT" -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" "exit" 2>/dev/null; then
        log "ERROR" "Impossible de se connecter au serveur distant"
        exit 1
    fi
    
    if ssh -i "$SSH_KEY" -p "$REMOTE_PORT" "${REMOTE_USER}@${REMOTE_HOST}" "command -v borg" &> /dev/null; then
        local remote_version=$(ssh -i "$SSH_KEY" -p "$REMOTE_PORT" "${REMOTE_USER}@${REMOTE_HOST}" "borg --version" 2>&1)
        log "INFO" "BorgBackup déjà installé sur le serveur distant: $remote_version"
        return 0
    fi
    
    log "INFO" "Installation de BorgBackup sur le serveur distant..."
    
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
        exit 1
    fi
    
    if ssh -i "$SSH_KEY" -p "$REMOTE_PORT" -o ConnectTimeout=5 "${REMOTE_USER}@${REMOTE_HOST}" "echo 'SSH OK'" &> /dev/null; then
        log "INFO" "Connexion SSH validée"
    else
        log "ERROR" "Connexion SSH échouée"
        exit 1
    fi
}

init_repo() {
    log "INFO" "Initialisation du dépôt Borg..."
    
    log "INFO" "Création du répertoire de backup distant..."
    ssh -i "$SSH_KEY" -p "$REMOTE_PORT" "${REMOTE_USER}@${REMOTE_HOST}" "
        sudo mkdir -p /backup/borg-repo
        sudo chown -R ${REMOTE_USER}:${REMOTE_USER} /backup
        sudo chmod 755 /backup
    " || {
        log "ERROR" "Impossible de créer le répertoire distant"
        exit 1
    }
    
    if borg list "$BORG_REPO" &> /dev/null; then
        log "INFO" "Dépôt Borg déjà initialisé"
        return 0
    fi
    
    log "INFO" "Création du dépôt chiffré (repokey-blake2)..."
    if borg init --encryption=repokey-blake2 "$BORG_REPO" 2>&1 | tee -a "$LOG_FILE"; then
        log "INFO" "Dépôt initialisé avec succès"
        send_alert "success" "Dépôt Borg Initialisé" "Le dépôt Borg a été créé avec succès sur $REMOTE_HOST"
    else
        log "ERROR" "Échec de l'initialisation du dépôt"
        send_alert "error" "Échec Initialisation" "Impossible de créer le dépôt Borg sur $REMOTE_HOST"
        exit 1
    fi
}

create_backup() {
    local archive_name="backup-$(hostname)-$(date +%Y-%m-%d_%H-%M-%S)"
    local start_time=$(date +%s)
    
    log "INFO" "===== Création du backup ====="
    log "INFO" "Archive: $archive_name"
    
    local exclude_opts=""
    for pattern in "${EXCLUSIONS[@]}"; do
        exclude_opts+="--exclude '$pattern' "
    done
    
    log "INFO" "Sauvegarde en cours..."
    
    if eval "borg create \
        --stats \
        --progress \
        --compression lz4 \
        $exclude_opts \
        '$BORG_REPO::$archive_name' \
        ${BACKUP_SOURCES[*]}" 2>&1 | tee -a "$LOG_FILE"; then
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log "INFO" "Backup créé avec succès: $archive_name"
        
        # Récupérer les stats
        local stats=$(borg info "$BORG_REPO::$archive_name" 2>&1 | grep -E "Number of files|Original size|Compressed size|Deduplicated size")
        
        send_alert "success" "Backup Réussi" "Archive créée avec succès !

Archive : $archive_name
Durée : ${duration}s

Statistiques :
$stats"
        
        return 0
    else
        log "ERROR" "Échec de la création du backup"
        send_alert "error" "Échec Backup" "Le backup a échoué !

Archive : $archive_name
Consultez les logs : $LOG_FILE"
        return 1
    fi
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
        return 1
    fi
    
    log "INFO" "===== Contenu de l'archive: $archive ====="
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
    
    mkdir -p "$dest"
    cd "$dest"
    
    if borg extract "$BORG_REPO::$archive" "$file_path" 2>&1 | tee -a "$LOG_FILE"; then
        log "INFO" "Restauration terminée"
        log "INFO" "Fichier restauré dans: $dest/$file_path"
        send_alert "success" "Restauration Réussie" "Fichier restauré avec succès !

Archive : $archive
Fichier : $file_path
Destination : $dest"
    else
        log "ERROR" "Échec de la restauration"
        send_alert "error" "Échec Restauration" "Impossible de restaurer le fichier !

Archive : $archive
Fichier : $file_path"
        return 1
    fi
}

restore_interactive() {
    log "INFO" "===== Mode Restauration Interactive ====="
    
    echo "Archives disponibles:"
    borg list "$BORG_REPO"
    echo ""
    
    read -p "Nom de l'archive à restaurer: " archive
    
    if [ -z "$archive" ]; then
        log "ERROR" "Nom d'archive requis"
        return 1
    fi
    
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
    
    if borg prune \
        --list \
        --stats \
        --keep-daily=$KEEP_DAILY \
        --keep-weekly=$KEEP_WEEKLY \
        --keep-monthly=$KEEP_MONTHLY \
        "$BORG_REPO" 2>&1 | tee -a "$LOG_FILE"; then
        
        log "INFO" "Nettoyage terminé"
        send_alert "success" "Rotation Effectuée" "Nettoyage des anciennes archives réussi !

Politique de rétention :
- Quotidien : $KEEP_DAILY
- Hebdomadaire : $KEEP_WEEKLY
- Mensuel : $KEEP_MONTHLY"
    else
        log "ERROR" "Échec du nettoyage"
        send_alert "error" "Échec Rotation" "Le nettoyage des archives a échoué !"
        return 1
    fi
}

show_help() {
    cat << EOF
Usage: $(basename $0) [COMMAND] [OPTIONS]

COMMANDES:
    init                  Initialiser le dépôt Borg distant
    setup-email           Configurer les alertes email
    backup                Créer un nouveau backup
    list                  Lister toutes les archives
    show <archive> [n]    Afficher le contenu d'une archive
    info <archive>        Afficher les infos détaillées
    restore               Mode restauration interactive
    extract               Extraire un fichier spécifique
    prune                 Nettoyer les anciennes archives
    
OPTIONS:
    -h, --help            Afficher cette aide
    
EXEMPLES:
    $(basename $0) setup-email                       # Configurer les emails
    $(basename $0) init                              # Initialiser le dépôt
    $(basename $0) backup                            # Créer un backup
    $(basename $0) list                              # Lister les archives
    
CONFIGURATION:
    Serveur distant : ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PORT}
    Dépôt Borg      : $BORG_REPO
    Sources         : ${BACKUP_SOURCES[*]}
    
EOF
}

#----- Main --------------------------------------------------------------------
main() {
    local command=${1:-backup}
    
    mkdir -p "$LOG_DIR"
    
    case "$command" in
        -h|--help)
            show_help
            exit 0
            ;;
        setup-email)
            check_root
            detect_os
            setup_email
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
