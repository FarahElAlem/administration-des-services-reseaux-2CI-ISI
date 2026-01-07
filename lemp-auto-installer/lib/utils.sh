#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Fonctions utilitaires
# ═══════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════
# Timer
# ═══════════════════════════════════════════════════════════

TIMER_START=0

timer_start() {
    TIMER_START=$(date +%s)
}

timer_end() {
    local end=$(date +%s)
    local duration=$((end - TIMER_START))
    
    if [ $duration -lt 60 ]; then
        echo "${duration}s"
    else
        local minutes=$((duration / 60))
        local seconds=$((duration % 60))
        echo "${minutes}m ${seconds}s"
    fi
}

# ═══════════════════════════════════════════════════════════
# Spinner d'attente
# ═══════════════════════════════════════════════════════════

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    
    printf "    \b\b\b\b"
}

# ═══════════════════════════════════════════════════════════
# Vérifier si un paquet est installé
# ═══════════════════════════════════════════════════════════

check_package_installed() {
    local package="$1"
    dpkg -l | grep -q "^ii.*$package"
}

# ═══════════════════════════════════════════════════════════
# Vérifier si un service est actif
# ═══════════════════════════════════════════════════════════

check_service_active() {
    local service="$1"
    systemctl is-active "$service" >/dev/null 2>&1
}

# ═══════════════════════════════════════════════════════════
# Créer un backup
# ═══════════════════════════════════════════════════════════

create_backup() {
    local source="$1"
    local backup_dir="${OUTPUT_DIR:-./output}/backups"
    
    if [ ! -e "$source" ]; then
        return 1
    fi
    
    mkdir -p "$backup_dir"
    
    local backup_file="${backup_dir}/$(basename $source).backup-$(date +%Y%m%d-%H%M%S)"
    
    if [ -d "$source" ]; then
        cp -r "$source" "$backup_file"
    else
        cp "$source" "$backup_file"
    fi
    
    echo "$backup_file"
}

# ═══════════════════════════════════════════════════════════
# Générer un mot de passe aléatoire
# ═══════════════════════════════════════════════════════════

generate_password() {
    local length="${1:-32}"
    openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c "$length"
}

# ═══════════════════════════════════════════════════════════
# Vérifier une commande existe
# ═══════════════════════════════════════════════════════════

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ═══════════════════════════════════════════════════════════
# Obtenir la version de PHP installée
# ═══════════════════════════════════════════════════════════

get_php_version() {
    if command_exists php; then
        php -v | head -n1 | cut -d' ' -f2 | cut -d'.' -f1,2
    else
        echo ""
    fi
}

# ═══════════════════════════════════════════════════════════
# Attendre qu'un service soit prêt
# ═══════════════════════════════════════════════════════════

wait_for_service() {
    local service="$1"
    local max_wait="${2:-30}"
    local count=0
    
    while [ $count -lt $max_wait ]; do
        if systemctl is-active "$service" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    
    return 1
}
