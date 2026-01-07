#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Désinstallation complète du stack LEMP
# VERSION DYNAMIQUE - Lit config.yaml
# ═══════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.yaml"

source "$SCRIPT_DIR/lib/colors.sh"

# Vérifier root
if [ "$EUID" -ne 0 ]; then
    print_error "Ce script nécessite les droits root"
    exit 1
fi

print_banner
print_header "🗑️  DÉSINSTALLATION DU STACK LEMP"

# ═══════════════════════════════════════════════════════════
# CHARGEMENT DE LA CONFIGURATION
# ═══════════════════════════════════════════════════════════

print_header "📋 ANALYSE DE LA CONFIGURATION"
echo ""

# Fonction pour extraire tous les domaines
extract_all_domains() {
    grep -A4 "enabled: true" "$CONFIG_FILE" 2>/dev/null | grep "domain:" | awk '{print $2}' | tr -d '"'
}

# Fonction pour extraire tous les roots
extract_all_roots() {
    grep -A4 "enabled: true" "$CONFIG_FILE" 2>/dev/null | grep "root:" | awk '{print $2}' | tr -d '"'
}

# Charger les domaines et roots
DOMAINS=($(extract_all_domains))
ROOTS=($(extract_all_roots))

if [ ${#DOMAINS[@]} -eq 0 ]; then
    print_warning "Aucun domaine trouvé dans config.yaml"
    print_info "Recherche des virtual hosts installés..."
    
    # Fallback : chercher dans /etc/nginx/sites-available/
    DOMAINS=($(ls /etc/nginx/sites-available/ 2>/dev/null | grep -v "default" | sed 's/\.conf$//'))
    
    if [ ${#DOMAINS[@]} -eq 0 ]; then
        print_warning "Aucun virtual host trouvé"
    fi
fi

if [ ${#ROOTS[@]} -eq 0 ]; then
    print_warning "Aucun root trouvé dans config.yaml"
    print_info "Recherche des répertoires web..."
    
    # Fallback : chercher dans /var/www/
    ROOTS=($(find /var/www/ -maxdepth 1 -type d ! -name "www" ! -name "html" 2>/dev/null))
fi

# Afficher ce qui sera supprimé
print_info "Configuration détectée:"
echo ""

if [ ${#DOMAINS[@]} -gt 0 ]; then
    echo "Domaines à supprimer:"
    for domain in "${DOMAINS[@]}"; do
        echo "  • $domain"
    done
    echo ""
fi

if [ ${#ROOTS[@]} -gt 0 ]; then
    echo "Répertoires web à supprimer:"
    for root in "${ROOTS[@]}"; do
        echo "  • $root"
    done
    echo ""
fi

# ═══════════════════════════════════════════════════════════
# CONFIRMATION
# ═══════════════════════════════════════════════════════════

print_warning "⚠️  ATTENTION : Cette action est IRRÉVERSIBLE"
echo ""
echo "Sera supprimé:"
echo "  • Nginx"
echo "  • MariaDB (+ toutes les bases de données)"
echo "  • PHP-FPM"
echo "  • phpMyAdmin"
echo "  • Tous les virtual hosts configurés"
echo "  • Tous les fichiers web"
echo ""

read -p "Voulez-vous créer un backup avant ? [O/n] " -n 1 -r
echo ""

CREATE_BACKUP=true
if [[ $REPLY =~ ^[Nn]$ ]]; then
    CREATE_BACKUP=false
fi

echo ""
read -p "Confirmer la désinstallation complète ? [o/N] " -n 1 -r
echo ""
echo ""

if [[ ! $REPLY =~ ^[OoYy]$ ]]; then
    print_info "Désinstallation annulée"
    exit 0
fi

# ═══════════════════════════════════════════════════════════
# BACKUP (optionnel)
# ═══════════════════════════════════════════════════════════

if [ "$CREATE_BACKUP" = true ]; then
    print_header "💾 CRÉATION DU BACKUP"
    echo ""
    
    BACKUP_DIR="/root/lemp-backup-before-uninstall-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    print_substep "Sauvegarde de la configuration Nginx..."
    cp -r /etc/nginx "$BACKUP_DIR/nginx" 2>/dev/null || true
    
    print_substep "Sauvegarde de la configuration PHP..."
    cp -r /etc/php "$BACKUP_DIR/php" 2>/dev/null || true
    
    print_substep "Sauvegarde de la configuration MariaDB..."
    cp -r /etc/mysql "$BACKUP_DIR/mysql" 2>/dev/null || true
    
    print_substep "Export des bases de données..."
    if systemctl is-active mariadb >/dev/null 2>&1; then
        # Lire le mot de passe depuis config.yaml
        MARIADB_ROOT_PASSWORD=$(grep "mariadb_root_password:" "$CONFIG_FILE" | cut -d'"' -f2)
        
        if [ -n "$MARIADB_ROOT_PASSWORD" ]; then
            mysqldump -u root -p"${MARIADB_ROOT_PASSWORD}" --all-databases > "$BACKUP_DIR/all-databases.sql" 2>/dev/null || true
            print_substep "✓ Bases de données exportées"
        else
            print_warning "Mot de passe MariaDB introuvable, skip export BDD"
        fi
    fi
    
    print_substep "Sauvegarde des fichiers web..."
    for root in "${ROOTS[@]}"; do
        if [ -d "$root" ]; then
            dirname=$(basename "$root")
            cp -r "$root" "$BACKUP_DIR/www-$dirname" 2>/dev/null || true
        fi
    done
    
    # Créer une archive
    print_substep "Compression du backup..."
    tar -czf "${BACKUP_DIR}.tar.gz" -C "$(dirname $BACKUP_DIR)" "$(basename $BACKUP_DIR)" >/dev/null 2>&1
    rm -rf "$BACKUP_DIR"
    
    print_success "Backup créé: ${BACKUP_DIR}.tar.gz"
    echo ""
fi

# ═══════════════════════════════════════════════════════════
# ARRÊT DES SERVICES
# ═══════════════════════════════════════════════════════════

print_header "⏹️  ARRÊT DES SERVICES"
echo ""

services=("nginx" "php8.4-fpm" "php8.3-fpm" "php8.2-fpm" "mariadb" "mysql")

for service in "${services[@]}"; do
    if systemctl is-active "$service" >/dev/null 2>&1; then
        print_substep "Arrêt de $service..."
        systemctl stop "$service" >/dev/null 2>&1
        systemctl disable "$service" >/dev/null 2>&1
    fi
done

print_substep "✓ Services arrêtés"
echo ""

# ═══════════════════════════════════════════════════════════
# SUPPRESSION DES VIRTUAL HOSTS
# ═══════════════════════════════════════════════════════════

print_header "🌐 SUPPRESSION DES VIRTUAL HOSTS"
echo ""

for domain in "${DOMAINS[@]}"; do
    # Déterminer le nom du fichier de config
    # Peut être domain.conf OU un nom dérivé
    
    # Chercher dans sites-available
    conf_files=$(find /etc/nginx/sites-available/ -type f -name "*${domain}*" 2>/dev/null)
    
    if [ -z "$conf_files" ]; then
        # Essayer avec juste le premier segment
        first_part=$(echo "$domain" | cut -d'.' -f1)
        conf_files=$(find /etc/nginx/sites-available/ -type f -name "*${first_part}*" 2>/dev/null)
    fi
    
    if [ -n "$conf_files" ]; then
        while IFS= read -r conf_file; do
            print_substep "Suppression de $(basename $conf_file)..."
            rm -f "$conf_file"
            rm -f "/etc/nginx/sites-enabled/$(basename $conf_file)"
        done <<< "$conf_files"
    else
        print_warning "Config introuvable pour $domain"
    fi
done

# Nettoyer les éventuels liens cassés
find /etc/nginx/sites-enabled/ -type l ! -exec test -e {} \; -delete 2>/dev/null

print_substep "✓ Virtual hosts supprimés"
echo ""

# ═══════════════════════════════════════════════════════════
# SUPPRESSION DES RÉPERTOIRES WEB
# ═══════════════════════════════════════════════════════════

print_header "📁 SUPPRESSION DES RÉPERTOIRES WEB"
echo ""

for root in "${ROOTS[@]}"; do
    if [ -d "$root" ]; then
        print_substep "Suppression de $root..."
        rm -rf "$root"
    fi
done

# Nettoyer /var/www (garder seulement html par défaut)
if [ -d /var/www ]; then
    find /var/www -mindepth 1 -maxdepth 1 -type d ! -name "html" -exec rm -rf {} \; 2>/dev/null
fi

print_substep "✓ Répertoires web supprimés"
echo ""

# ═══════════════════════════════════════════════════════════
# DÉSINSTALLATION DES PAQUETS
# ═══════════════════════════════════════════════════════════

print_header "📦 DÉSINSTALLATION DES PAQUETS"
echo ""

packages=(
    "nginx"
    "nginx-common"
    "nginx-core"
    "mariadb-server"
    "mariadb-client"
    "mariadb-common"
    "php8.4-fpm"
    "php8.4-mysql"
    "php8.4-cli"
    "php8.4-common"
    "php8.4-curl"
    "php8.4-gd"
    "php8.4-mbstring"
    "php8.4-xml"
    "php8.4-zip"
    "phpmyadmin"
)

print_substep "Suppression des paquets (cela peut prendre 1-2 minutes)..."

# Barre de progression simple
total=${#packages[@]}
current=0

for package in "${packages[@]}"; do
    if dpkg -l | grep -q "^ii.*$package"; then
        DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y "$package" >/dev/null 2>&1
    fi
    
    current=$((current + 1))
    percent=$((current * 100 / total))
    printf "\r  Progression: [%-50s] %d%%" $(printf '#%.0s' $(seq 1 $((percent / 2)))) $percent
done

echo ""
print_substep "✓ Paquets supprimés"

# Nettoyer les résidus
print_substep "Nettoyage des résidus..."
apt-get autoremove -y >/dev/null 2>&1
apt-get autoclean -y >/dev/null 2>&1

# Purger les configs résiduelles
dpkg -l | grep "^rc" | awk '{print $2}' | xargs dpkg --purge >/dev/null 2>&1 || true

print_substep "✓ Résidus nettoyés"
echo ""

# ═══════════════════════════════════════════════════════════
# SUPPRESSION DES CONFIGURATIONS
# ═══════════════════════════════════════════════════════════

print_header "🗂️  SUPPRESSION DES CONFIGURATIONS"
echo ""

dirs_to_remove=(
    "/etc/nginx"
    "/etc/php"
    "/etc/mysql"
    "/etc/phpmyadmin"
    "/var/lib/mysql"
    "/var/lib/nginx"
    "/var/log/nginx"
    "/var/log/mysql"
    "/var/log/php*"
    "/run/php"
)

for dir in "${dirs_to_remove[@]}"; do
    if [ -d "$dir" ] || [ -L "$dir" ]; then
        print_substep "Suppression de $dir..."
        rm -rf $dir
    fi
done

print_substep "✓ Configurations supprimées"
echo ""

# ═══════════════════════════════════════════════════════════
# NETTOYAGE FINAL
# ═══════════════════════════════════════════════════════════

print_header "🧹 NETTOYAGE FINAL"
echo ""

# Nettoyer systemd
print_substep "Rechargement de systemd..."
systemctl daemon-reload

print_substep "✓ Nettoyage terminé"
echo ""

# ═══════════════════════════════════════════════════════════
# RÉSUMÉ
# ═══════════════════════════════════════════════════════════

print_header "✅ DÉSINSTALLATION TERMINÉE"
echo ""

print_success "Le stack LEMP a été complètement supprimé"
echo ""

print_info "Résumé:"
echo "  • Virtual hosts supprimés: ${#DOMAINS[@]}"
echo "  • Répertoires web supprimés: ${#ROOTS[@]}"
echo "  • Services arrêtés: nginx, mariadb, php-fpm"
echo "  • Paquets désinstallés: ${#packages[@]}"
echo ""

if [ "$CREATE_BACKUP" = true ]; then
    print_info "💾 Backup disponible:"
    echo "  ${BACKUP_DIR}.tar.gz"
    echo ""
fi

print_info "Pour réinstaller:"
echo "  sudo ./install.sh"
echo ""
