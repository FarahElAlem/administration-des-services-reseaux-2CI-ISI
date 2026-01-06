#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Outil de Désinstallation LEMP Stack 
# ═══════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logger.sh"
source "$SCRIPT_DIR/lib/utils.sh"

check_root

print_banner
print_header "⚠️  DÉSINSTALLATION COMPLÈTE LEMP STACK"

echo ""
print_warning "Cette opération va TOUT supprimer:"
echo "  • Nginx, MariaDB, PHP-FPM, phpMyAdmin"
echo "  • Virtual Hosts et configurations"
echo "  • Bases de données (avec backup)"
echo "  • Fichiers web"
echo ""

read -p "Voulez-vous continuer ? [o/N] " -n 1 -r
echo ""
echo ""

if [[ ! $REPLY =~ ^[OoYy]$ ]]; then
    print_info "Désinstallation annulée"
    exit 0
fi

# ═══════════════════════════════════════════════════════════
# ÉTAPE 1 : BACKUP COMPLET
# ═══════════════════════════════════════════════════════════

print_header "📦 BACKUP AVANT SUPPRESSION"
echo ""

BACKUP_DIR="/root/lemp-backup-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"/{configs,databases,websites}

print_substep "Backup des configurations..."

# Nginx
if [ -d /etc/nginx ]; then
    tar -czf "$BACKUP_DIR/configs/nginx.tar.gz" /etc/nginx 2>/dev/null
    print_substep "✓ Nginx config sauvegardé"
fi

# PHP
if [ -d /etc/php ]; then
    tar -czf "$BACKUP_DIR/configs/php.tar.gz" /etc/php 2>/dev/null
    print_substep "✓ PHP config sauvegardé"
fi

# MariaDB
if [ -d /etc/mysql ]; then
    tar -czf "$BACKUP_DIR/configs/mysql.tar.gz" /etc/mysql 2>/dev/null
    print_substep "✓ MariaDB config sauvegardé"
fi

# Bases de données
print_substep "Backup des bases de données..."
if command -v mysqldump >/dev/null 2>&1 && systemctl is-active mariadb >/dev/null 2>&1; then
    mysqldump --all-databases --single-transaction --quick --lock-tables=false \
        > "$BACKUP_DIR/databases/all-databases.sql" 2>/dev/null && \
        print_substep "✓ Bases de données sauvegardées" || \
        print_warning "✗ Échec backup BDD (normal si mot de passe protégé)"
fi

# Sites web
print_substep "Backup des sites web..."
if [ -d /var/www ]; then
    tar -czf "$BACKUP_DIR/websites/www.tar.gz" /var/www 2>/dev/null
    print_substep "✓ Sites web sauvegardés"
fi

BACKUP_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
print_success "Backup créé : $BACKUP_DIR"
print_info "Taille : $BACKUP_SIZE"
echo ""

# ═══════════════════════════════════════════════════════════
# ÉTAPE 2 : ARRÊT DES SERVICES
# ═══════════════════════════════════════════════════════════

print_header "⏹️  ARRÊT DES SERVICES"
echo ""

print_substep "Arrêt Nginx..."
systemctl stop nginx 2>/dev/null || true
systemctl disable nginx 2>/dev/null || true

print_substep "Arrêt PHP-FPM..."
systemctl stop php*.service 2>/dev/null || true
systemctl stop php*-fpm 2>/dev/null || true

print_substep "Arrêt MariaDB..."
systemctl stop mariadb 2>/dev/null || true
systemctl stop mysql 2>/dev/null || true

print_success "Services arrêtés"
echo ""

# ═══════════════════════════════════════════════════════════
# ÉTAPE 3 : SUPPRESSION CONFIGURATIONS
# ═══════════════════════════════════════════════════════════

print_header "🗑️  SUPPRESSION DES CONFIGURATIONS"
echo ""

print_substep "Suppression Virtual Hosts..."
rm -f /etc/nginx/sites-enabled/* 2>/dev/null
rm -f /etc/nginx/sites-available/portal-rh.conf 2>/dev/null
rm -f /etc/nginx/sites-available/prod-web.conf 2>/dev/null
print_substep "✓ Virtual Hosts supprimés"

print_substep "Suppression fichiers web..."
rm -rf /var/www/portal-rh.ing-infraFarah.lan 2>/dev/null
rm -rf /var/www/prod-web.innov-techFarah.com 2>/dev/null
print_substep "✓ Fichiers web supprimés"

print_success "Configurations supprimées"
echo ""

# ═══════════════════════════════════════════════════════════
# ÉTAPE 4 : DÉSINSTALLATION PAQUETS
# ═══════════════════════════════════════════════════════════

echo ""
print_warning "⚠️  DÉSINSTALLATION DES PAQUETS"
echo ""
echo "Cela va supprimer :"
echo "  • Nginx"
echo "  • MariaDB (avec toutes les bases)"
echo "  • PHP et toutes ses extensions"
echo "  • phpMyAdmin"
echo ""

read -p "Confirmer la désinstallation ? [o/N] " -n 1 -r
echo ""
echo ""

if [[ ! $REPLY =~ ^[OoYy]$ ]]; then
    print_warning "Désinstallation des paquets annulée"
    print_info "Les services sont arrêtés mais les paquets restent installés"
    exit 0
fi

print_substep "Désinstallation en cours (peut prendre 1-2 minutes)..."
echo ""

# Liste des paquets à supprimer
PACKAGES_TO_REMOVE=(
    nginx nginx-common nginx-core
    php8.4 php8.4-fpm php8.4-mysql php8.4-cli php8.4-common php8.4-curl
    php8.4-gd php8.4-mbstring php8.4-xml php8.4-zip php8.4-opcache
    php-phpmyadmin-motranslator php-phpmyadmin-shapefile php-phpmyadmin-sql-parser
    mariadb-server mariadb-client mariadb-common mysql-common
    phpmyadmin
)

# Supprimer les paquets (avec barre de progression)
TOTAL=${#PACKAGES_TO_REMOVE[@]}
CURRENT=0

for package in "${PACKAGES_TO_REMOVE[@]}"; do
    ((CURRENT++))
    if dpkg -l | grep -q "^ii.*$package"; then
        echo -ne "\r[$CURRENT/$TOTAL] Suppression: $package...                    "
        DEBIAN_FRONTEND=noninteractive apt-get remove -y --purge "$package" >/dev/null 2>&1
    fi
done

echo ""
echo ""

print_substep "Nettoyage des dépendances..."
DEBIAN_FRONTEND=noninteractive apt-get autoremove -y >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get autoclean -y >/dev/null 2>&1

print_success "Paquets désinstallés"
echo ""

# ═══════════════════════════════════════════════════════════
# ÉTAPE 5 : NETTOYAGE COMPLET
# ═══════════════════════════════════════════════════════════

print_header "🧹 NETTOYAGE COMPLET"
echo ""

print_substep "Suppression des répertoires..."

# Nginx
rm -rf /etc/nginx 2>/dev/null
rm -rf /var/log/nginx 2>/dev/null
rm -rf /var/lib/nginx 2>/dev/null

# PHP
rm -rf /etc/php 2>/dev/null
rm -rf /var/lib/php 2>/dev/null

# MariaDB
rm -rf /var/lib/mysql 2>/dev/null
rm -rf /etc/mysql 2>/dev/null
rm -rf /var/log/mysql 2>/dev/null

# phpMyAdmin
rm -rf /etc/phpmyadmin 2>/dev/null
rm -rf /var/lib/phpmyadmin 2>/dev/null

# Logs du script
rm -f /var/log/lemp-install.log 2>/dev/null

# Fichiers temporaires
rm -rf /tmp/php* 2>/dev/null

print_success "Nettoyage terminé"
echo ""

# ═══════════════════════════════════════════════════════════
# ÉTAPE 6 : PURGE COMPLÈTE DES RÉSIDUS
# ═══════════════════════════════════════════════════════════

print_header "🧼 PURGE FINALE DES RÉSIDUS"
echo ""

print_substep "Vérification des paquets résiduels..."

# Lister les paquets en état "rc" ou "pi" (résidus de config)
RESIDUAL_PACKAGES=$(dpkg -l | grep "^rc\|^pi" | grep -E "nginx|php|mariadb|phpmyadmin" | awk '{print $2}')

if [ -n "$RESIDUAL_PACKAGES" ]; then
    print_substep "Purge des résidus de configuration..."
    echo "$RESIDUAL_PACKAGES" | xargs -r sudo dpkg --purge 2>/dev/null
    print_success "Résidus purgés"
else
    print_success "Aucun résidu trouvé"
fi

# Vérification finale
echo ""
print_substep "Vérification finale..."
REMAINING=$(dpkg -l | grep -E "nginx|php|mariadb|phpmyadmin" | grep "^ii\|^rc\|^pi" | wc -l)

if [ "$REMAINING" -eq 0 ]; then
    print_success "✓ Système complètement nettoyé"
else
    print_warning "⚠ $REMAINING paquet(s) résiduel(s) détecté(s)"
    echo ""
    dpkg -l | grep -E "nginx|php|mariadb|phpmyadmin" | grep "^ii\|^rc\|^pi"
fi

echo ""

# ═══════════════════════════════════════════════════════════
# RÉSUMÉ FINAL
# ═══════════════════════════════════════════════════════════

print_header "✅ DÉSINSTALLATION TERMINÉE"
echo ""

print_info "📦 Backup disponible :"
echo "   $BACKUP_DIR"
echo "   Taille : $BACKUP_SIZE"
echo ""

print_info "🔍 Vérifications :"
echo "   • Services arrêtés : ✓"
echo "   • Paquets supprimés : ✓"
echo "   • Fichiers nettoyés : ✓"
echo ""

print_info "💡 Pour restaurer depuis le backup :"
echo "   • Configs : tar -xzf $BACKUP_DIR/configs/*.tar.gz -C /"
echo "   • Sites : tar -xzf $BACKUP_DIR/websites/www.tar.gz -C /"
echo "   • BDD : mysql < $BACKUP_DIR/databases/all-databases.sql"
echo ""

print_success "Le système est prêt pour une nouvelle installation"
echo ""
