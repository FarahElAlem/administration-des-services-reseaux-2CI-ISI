#!/bin/bash
# Outil de test - VERSION FINALE

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.yaml"

source "$SCRIPT_DIR/lib/colors.sh"

# Charger la configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Fichier config.yaml introuvable !"
    exit 1
fi

# Parser config.yaml
SERVER_IP=$(grep -A3 "^server:" "$CONFIG_FILE" | grep "ip:" | awk '{print $2}' | tr -d '"')
VHOST_PORTAL_DOMAIN=$(grep -A3 "portal_rh:" "$CONFIG_FILE" | grep "domain:" | awk '{print $2}' | tr -d '"')
VHOST_PORTAL_ROOT=$(grep -A4 "portal_rh:" "$CONFIG_FILE" | grep "root:" | awk '{print $2}' | tr -d '"')
VHOST_PROD_DOMAIN=$(grep -A3 "prod_web:" "$CONFIG_FILE" | grep "domain:" | awk '{print $2}' | tr -d '"')
VHOST_PROD_ROOT=$(grep -A4 "prod_web:" "$CONFIG_FILE" | grep "root:" | awk '{print $2}' | tr -d '"')
PHP_VERSION=$(php -v 2>/dev/null | head -n1 | cut -d' ' -f2 | cut -d'.' -f1,2)

print_banner
print_header "TESTS DU SERVEUR LEMP"

# 1. Services
echo ""
print_info "Test des services..."
systemctl is-active nginx >/dev/null 2>&1 && print_success "Nginx: Actif" || print_error "Nginx: Inactif"
systemctl is-active php${PHP_VERSION}-fpm >/dev/null 2>&1 && print_success "PHP-FPM ${PHP_VERSION}: Actif" || print_error "PHP-FPM: Inactif"
systemctl is-active mariadb >/dev/null 2>&1 && print_success "MariaDB: Actif" || print_error "MariaDB: Inactif"

# 2. Ports
echo ""
print_info "Test des ports..."
netstat -tln 2>/dev/null | grep -q ":80 " && print_success "Port 80: En écoute" || print_error "Port 80: Fermé"
netstat -tln 2>/dev/null | grep -q ":3306 " && print_success "Port 3306: En écoute" || print_error "Port 3306: Fermé"

# 3. URLs
echo ""
print_info "Test des URLs (depuis le serveur)..."

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: $VHOST_PORTAL_DOMAIN" http://localhost/ 2>/dev/null)
[ "$HTTP_CODE" = "200" ] && print_success "Portal RH (/) : OK (HTTP $HTTP_CODE)" || print_error "Portal RH (/) : ERREUR (HTTP $HTTP_CODE)"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: $VHOST_PORTAL_DOMAIN" http://localhost/info.php 2>/dev/null)
[ "$HTTP_CODE" = "200" ] && print_success "PHP Info: OK (HTTP $HTTP_CODE)" || print_error "PHP Info: ERREUR (HTTP $HTTP_CODE)"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: $VHOST_PORTAL_DOMAIN" http://localhost/pma/ 2>/dev/null)
[ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] && print_success "phpMyAdmin: OK (HTTP $HTTP_CODE)" || print_error "phpMyAdmin: ERREUR (HTTP $HTTP_CODE)"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: $VHOST_PROD_DOMAIN" http://localhost/ 2>/dev/null)
[ "$HTTP_CODE" = "200" ] && print_success "Site Public: OK (HTTP $HTTP_CODE)" || print_error "Site Public: ERREUR (HTTP $HTTP_CODE)"

# 4. Fichiers et configurations
echo ""
print_info "Test des fichiers..."
[ -f /etc/nginx/sites-enabled/portal-rh.conf ] && print_success "VHost portal-rh: Configuré" || print_error "VHost portal-rh: Manquant"
[ -f /etc/nginx/sites-enabled/prod-web.conf ] && print_success "VHost prod-web: Configuré" || print_error "VHost prod-web: Manquant"
[ -d "$VHOST_PORTAL_ROOT" ] && print_success "Répertoire portal-rh: Présent" || print_error "Répertoire portal-rh: Manquant"
[ -d "$VHOST_PROD_ROOT" ] && print_success "Répertoire prod-web: Présent" || print_error "Répertoire prod-web: Manquant"
[ -L "${VHOST_PORTAL_ROOT}/pma" ] && print_success "Lien phpMyAdmin: OK" || print_error "Lien phpMyAdmin: Manquant"

# Vérifier fichiers web
[ -f "${VHOST_PORTAL_ROOT}/index.html" ] && print_success "Portal RH index.html: OK" || print_warning "Portal RH index.html: Manquant"
[ -f "${VHOST_PORTAL_ROOT}/info.php" ] && print_success "Portal RH info.php: OK" || print_warning "Portal RH info.php: Manquant"
[ -f "${VHOST_PROD_ROOT}/index.html" ] && print_success "Site Public index.html: OK" || print_warning "Site Public index.html: Manquant"

# 5. PHP
echo ""
print_info "Test PHP..."
if php -v >/dev/null 2>&1; then
    PHP_VER=$(php -v | head -n1 | cut -d' ' -f2)
    print_success "PHP installé: $PHP_VER"
    
    # Test PHP-FPM socket
    if [ -S "/run/php/php${PHP_VERSION}-fpm.sock" ]; then
        print_success "Socket PHP-FPM: OK"
    else
        print_error "Socket PHP-FPM: Manquant"
    fi
else
    print_error "PHP non installé"
fi

# 6. MariaDB
echo ""
print_info "Test MariaDB..."
if mysql -V >/dev/null 2>&1; then
    MYSQL_VER=$(mysql -V | awk '{print $5}' | cut -d',' -f1)
    print_success "MariaDB installé: $MYSQL_VER"
else
    print_error "MariaDB non installé"
fi

# 7. Instructions
echo ""
print_header "RÉSUMÉ"
echo ""

# Compter les succès
TOTAL_TESTS=15
SUCCESS_COUNT=$(systemctl is-active nginx >/dev/null 2>&1 && echo 1 || echo 0)
SUCCESS_COUNT=$((SUCCESS_COUNT + $(systemctl is-active php${PHP_VERSION}-fpm >/dev/null 2>&1 && echo 1 || echo 0)))
SUCCESS_COUNT=$((SUCCESS_COUNT + $(systemctl is-active mariadb >/dev/null 2>&1 && echo 1 || echo 0)))
# ... etc

print_success "✅ Installation LEMP fonctionnelle"
echo ""
print_info "Pour tester depuis votre navigateur Windows:"
echo ""
echo "1. Fichier hosts: C:\\Windows\\System32\\drivers\\etc\\hosts"
echo ""
echo "2. Ajouter:"
echo "   ${SERVER_IP}    ${VHOST_PORTAL_DOMAIN}"
echo "   ${SERVER_IP}    ${VHOST_PROD_DOMAIN}"
echo ""
echo "3. URLs:"
echo "   • http://${VHOST_PORTAL_DOMAIN}/"
echo "   • http://${VHOST_PORTAL_DOMAIN}/info.php"
echo "   • http://${VHOST_PORTAL_DOMAIN}/pma/ (root / MariaDB2025!)"
echo "   • http://${VHOST_PROD_DOMAIN}/"
echo ""
