#!/bin/bash
# Régénérer les pages web sans réinstaller tout le stack

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.yaml"

source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/templating.sh"

# Charger config
export STUDENT_FIRSTNAME=$(grep "firstname:" "$CONFIG_FILE" | cut -d'"' -f2)
export STUDENT_LASTNAME=$(grep "lastname:" "$CONFIG_FILE" | cut -d'"' -f2)
export STUDENT_FORMATION=$(grep "formation:" "$CONFIG_FILE" | cut -d'"' -f2)
export SERVER_HOSTNAME=$(grep "hostname:" "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')
export SERVER_IP=$(grep -A1 "^server:" "$CONFIG_FILE" | grep "ip:" | awk '{print $2}' | tr -d '"')
export VHOST_PORTAL_DOMAIN=$(grep -A3 "portal_rh:" "$CONFIG_FILE" | grep "domain:" | awk '{print $2}' | tr -d '"')
export VHOST_PORTAL_ROOT=$(grep -A4 "portal_rh:" "$CONFIG_FILE" | grep "root:" | awk '{print $2}' | tr -d '"')
export VHOST_PROD_DOMAIN=$(grep -A3 "prod_web:" "$CONFIG_FILE" | grep "domain:" | awk '{print $2}' | tr -d '"')
export VHOST_PROD_ROOT=$(grep -A4 "prod_web:" "$CONFIG_FILE" | grep "root:" | awk '{print $2}' | tr -d '"')

print_banner
print_header "RÉGÉNÉRATION DES PAGES WEB"

echo ""
echo "1. Portal RH (index.html)"
echo "2. Portal RH (info.php)"
echo "3. Site Public (index.html)"
echo "4. Toutes les pages"
echo "5. Quitter"
echo ""

read -p "Votre choix [1-5]: " choice
echo ""

case $choice in
    1)
        print_info "Régénération Portal RH index.html..."
        generate_from_template \
            "$SCRIPT_DIR/templates/html/portal-rh.html.template" \
            "${VHOST_PORTAL_ROOT}/index.html" \
            "STUDENT_FIRSTNAME" "$STUDENT_FIRSTNAME" \
            "STUDENT_LASTNAME" "$STUDENT_LASTNAME" \
            "STUDENT_FORMATION" "$STUDENT_FORMATION" \
            "SERVER_HOSTNAME" "$SERVER_HOSTNAME" \
            "SERVER_IP" "$SERVER_IP"
        
        sudo chown www-data:www-data "${VHOST_PORTAL_ROOT}/index.html"
        sudo chmod 644 "${VHOST_PORTAL_ROOT}/index.html"
        print_success "✓ Portal RH index.html régénéré"
        ;;
        
    2)
        print_info "Régénération Portal RH info.php..."
        generate_from_template \
            "$SCRIPT_DIR/templates/html/info.php.template" \
            "${VHOST_PORTAL_ROOT}/info.php" \
            "STUDENT_FIRSTNAME" "$STUDENT_FIRSTNAME" \
            "STUDENT_LASTNAME" "$STUDENT_LASTNAME" \
            "STUDENT_FORMATION" "$STUDENT_FORMATION"
        
        sudo chown www-data:www-data "${VHOST_PORTAL_ROOT}/info.php"
        sudo chmod 644 "${VHOST_PORTAL_ROOT}/info.php"
        print_success "✓ Portal RH info.php régénéré"
        ;;
        
    3)
        print_info "Régénération Site Public index.html..."
        generate_from_template \
            "$SCRIPT_DIR/templates/html/site-public.html.template" \
            "${VHOST_PROD_ROOT}/index.html" \
            "SITE_TITLE" "Innov-Tech Farah" \
            "STUDENT_FIRSTNAME" "$STUDENT_FIRSTNAME" \
            "STUDENT_LASTNAME" "$STUDENT_LASTNAME" \
            "STUDENT_FORMATION" "$STUDENT_FORMATION"
        
        sudo chown www-data:www-data "${VHOST_PROD_ROOT}/index.html"
        sudo chmod 644 "${VHOST_PROD_ROOT}/index.html"
        print_success "✓ Site Public index.html régénéré"
        ;;
        
    4)
        print_info "Régénération de toutes les pages..."
        
        # Portal RH index
        generate_from_template \
            "$SCRIPT_DIR/templates/html/portal-rh.html.template" \
            "${VHOST_PORTAL_ROOT}/index.html" \
            "STUDENT_FIRSTNAME" "$STUDENT_FIRSTNAME" \
            "STUDENT_LASTNAME" "$STUDENT_LASTNAME" \
            "STUDENT_FORMATION" "$STUDENT_FORMATION" \
            "SERVER_HOSTNAME" "$SERVER_HOSTNAME" \
            "SERVER_IP" "$SERVER_IP"
        
        # Portal RH info.php
        generate_from_template \
            "$SCRIPT_DIR/templates/html/info.php.template" \
            "${VHOST_PORTAL_ROOT}/info.php" \
            "STUDENT_FIRSTNAME" "$STUDENT_FIRSTNAME" \
            "STUDENT_LASTNAME" "$STUDENT_LASTNAME" \
            "STUDENT_FORMATION" "$STUDENT_FORMATION"
        
        # Site Public index
        generate_from_template \
            "$SCRIPT_DIR/templates/html/site-public.html.template" \
            "${VHOST_PROD_ROOT}/index.html" \
            "SITE_TITLE" "Innov-Tech Farah" \
            "STUDENT_FIRSTNAME" "$STUDENT_FIRSTNAME" \
            "STUDENT_LASTNAME" "$STUDENT_LASTNAME" \
            "STUDENT_FORMATION" "$STUDENT_FORMATION"
        
        # Permissions
        sudo chown www-data:www-data "${VHOST_PORTAL_ROOT}"/{index.html,info.php}
        sudo chmod 644 "${VHOST_PORTAL_ROOT}"/{index.html,info.php}
        sudo chown www-data:www-data "${VHOST_PROD_ROOT}/index.html"
        sudo chmod 644 "${VHOST_PROD_ROOT}/index.html"
        
        print_success "✓ Toutes les pages régénérées"
        ;;
        
    5)
        print_info "Annulé"
        exit 0
        ;;
        
    *)
        print_error "Choix invalide"
        exit 1
        ;;
esac

echo ""
print_info "🌐 Testez dans le navigateur (F5 pour rafraîchir)"
echo ""
