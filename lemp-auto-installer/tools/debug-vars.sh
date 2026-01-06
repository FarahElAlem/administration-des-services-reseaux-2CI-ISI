#!/bin/bash
# Diagnostic des variables

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.yaml"

source "$SCRIPT_DIR/lib/colors.sh"

print_header "DIAGNOSTIC DES VARIABLES"

# Fonction load_config (copie de install.sh)
load_config() {
    export STUDENT_FIRSTNAME=$(grep "firstname:" "$CONFIG_FILE" | cut -d'"' -f2)
    export STUDENT_LASTNAME=$(grep "lastname:" "$CONFIG_FILE" | cut -d'"' -f2)
    export STUDENT_EMAIL=$(grep "email:" "$CONFIG_FILE" | cut -d'"' -f2)
    export SERVER_HOSTNAME=$(grep "hostname:" "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')
    export SERVER_IP=$(grep -A4 "^server:" "$CONFIG_FILE" | grep "ip:" | awk '{print $2}' | tr -d '"')
    export MARIADB_ROOT_PASSWORD=$(grep "mariadb_root_password:" "$CONFIG_FILE" | cut -d'"' -f2)
    export PHPMYADMIN_PASSWORD=$(grep "phpmyadmin_password:" "$CONFIG_FILE" | cut -d'"' -f2)
    export VHOST_PORTAL_DOMAIN=$(grep -A4 "portal_rh:" "$CONFIG_FILE" | grep "domain:" | awk '{print $2}' | tr -d '"')
}

load_config

echo ""
echo "Variables chargées depuis config.yaml:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Vérifier chaque variable
check_var() {
    local name=$1
    local value=$2
    
    if [ -n "$value" ]; then
        echo "✅ $name = $value"
    else
        echo "❌ $name = (vide)"
    fi
}

check_var "STUDENT_FIRSTNAME" "$STUDENT_FIRSTNAME"
check_var "STUDENT_LASTNAME" "$STUDENT_LASTNAME"
check_var "STUDENT_EMAIL" "$STUDENT_EMAIL"
check_var "SERVER_HOSTNAME" "$SERVER_HOSTNAME"
check_var "SERVER_IP" "$SERVER_IP"
check_var "MARIADB_ROOT_PASSWORD" "$MARIADB_ROOT_PASSWORD"
check_var "PHPMYADMIN_PASSWORD" "$PHPMYADMIN_PASSWORD"
check_var "VHOST_PORTAL_DOMAIN" "$VHOST_PORTAL_DOMAIN"

echo ""
