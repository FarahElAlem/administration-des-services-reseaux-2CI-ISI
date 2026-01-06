#!/bin/bash
# ═══════════════════════════════════════════════════════════
# LEMP Auto-Installer v2.0 - Script Principal
# ═══════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.yaml"

# Charger les bibliothèques
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logger.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/validators.sh"
source "$SCRIPT_DIR/lib/templating.sh"

# ═══════════════════════════════════════════════════════════
# MENU PRINCIPAL
# ═══════════════════════════════════════════════════════════

show_main_menu() {
    print_banner
    
    echo -e "${COLOR_BRIGHT_CYAN}   Créé par: Farah ELALEM${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_CYAN}   Formation: ISGA Marrakech${COLOR_RESET}"
    echo ""
    
    print_header "MENU PRINCIPAL"
    
    echo ""
    echo "  1. 🚀 Installation LEMP Stack"
    echo "     └─ Nginx + MariaDB + PHP-FPM + phpMyAdmin"
    echo ""
    echo "  2. 🌐 Configuration Réseau (Netplan)"
    echo "     └─ Migration /etc/network/interfaces → netplan"
    echo ""
    echo "  3. ❓ Aide & Documentation"
    echo "     └─ Guide d'utilisation"
    echo ""
    echo "  4. 🚪 Quitter"
    echo ""
    
    while true; do
        read -p "Votre choix [1-4]: " menu_choice
        echo ""
        
        case $menu_choice in
            1)
                INSTALL_MODE="lemp"
                break
                ;;
            2)
                INSTALL_MODE="network"
                break
                ;;
            3)
                show_help
                exit 0
                ;;
            4)
                print_info "Au revoir !"
                exit 0
                ;;
            *)
                print_error "Choix invalide, réessayez"
                ;;
        esac
    done
}

show_help() {
    print_header "AIDE - LEMP AUTO-INSTALLER"
    
    echo ""
    echo "📖 DOCUMENTATION"
    echo ""
    echo "  • README.md - Guide complet"
    echo "  • docs/INSTALLATION.md - Installation détaillée"
    echo ""
    echo "🛠️  OUTILS DISPONIBLES"
    echo ""
    echo "  • ./tools/test.sh - Tester le serveur"
    echo "  • ./tools/monitor.sh - Monitoring temps réel"
    echo "  • ./tools/backup.sh - Créer un backup"
    echo "  • ./tools/migrate-to-netplan.sh - Config réseau"
    echo ""
}

# ═══════════════════════════════════════════════════════════
# CHARGEMENT CONFIGURATION
# ═══════════════════════════════════════════════════════════

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "Fichier config introuvable"
        exit 1
    fi
    
    # IMPORTANT: Tous les export doivent être présents
    export STUDENT_FIRSTNAME=$(grep "firstname:" "$CONFIG_FILE" | cut -d'"' -f2)
    export STUDENT_LASTNAME=$(grep "lastname:" "$CONFIG_FILE" | cut -d'"' -f2)
    export STUDENT_FORMATION=$(grep "formation:" "$CONFIG_FILE" | cut -d'"' -f2)
    export STUDENT_EMAIL=$(grep "email:" "$CONFIG_FILE" | cut -d'"' -f2)
    
    export SERVER_HOSTNAME=$(grep "hostname:" "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')
    export SERVER_IP=$(grep -A4 "^server:" "$CONFIG_FILE" | grep "ip:" | awk '{print $2}' | tr -d '"')
    export SERVER_INTERFACE=$(grep -A4 "^server:" "$CONFIG_FILE" | grep "interface:" | awk '{print $2}' | tr -d '"')
    export SERVER_TIMEZONE=$(grep -A4 "^server:" "$CONFIG_FILE" | grep "timezone:" | awk '{print $2}' | tr -d '"')
    
    export VHOST_PORTAL_ENABLED=$(grep -A4 "portal_rh:" "$CONFIG_FILE" | grep "enabled:" | awk '{print $2}')
    export VHOST_PORTAL_DOMAIN=$(grep -A4 "portal_rh:" "$CONFIG_FILE" | grep "domain:" | awk '{print $2}' | tr -d '"')
    export VHOST_PORTAL_TYPE=$(grep -A4 "portal_rh:" "$CONFIG_FILE" | grep "type:" | awk '{print $2}' | tr -d '"')
    export VHOST_PORTAL_ROOT=$(grep -A4 "portal_rh:" "$CONFIG_FILE" | grep "root:" | awk '{print $2}' | tr -d '"')
    
    export VHOST_PROD_ENABLED=$(grep -A4 "prod_web:" "$CONFIG_FILE" | grep "enabled:" | awk '{print $2}')
    export VHOST_PROD_DOMAIN=$(grep -A4 "prod_web:" "$CONFIG_FILE" | grep "domain:" | awk '{print $2}' | tr -d '"')
    export VHOST_PROD_TYPE=$(grep -A4 "prod_web:" "$CONFIG_FILE" | grep "type:" | awk '{print $2}' | tr -d '"')
    export VHOST_PROD_ROOT=$(grep -A4 "prod_web:" "$CONFIG_FILE" | grep "root:" | awk '{print $2}' | tr -d '"')
    
    export MARIADB_ROOT_PASSWORD=$(grep "mariadb_root_password:" "$CONFIG_FILE" | cut -d'"' -f2)
    export PHPMYADMIN_PASSWORD=$(grep "phpmyadmin_password:" "$CONFIG_FILE" | cut -d'"' -f2)
    
    export GENERATE_HOSTS_FILE=$(grep "generate_hosts_file:" "$CONFIG_FILE" | awk '{print $2}')
    export RUN_TESTS=$(grep "run_tests:" "$CONFIG_FILE" | awk '{print $2}')
    export VERBOSE=$(grep "verbose:" "$CONFIG_FILE" | awk '{print $2}')
    
    export OUTPUT_DIR="$SCRIPT_DIR/output"
    mkdir -p "$OUTPUT_DIR"
    
    # DEBUG: Afficher les variables (optionnel)
    if [ "$VERBOSE" = "true" ]; then
        echo "DEBUG: Variables chargées:"
        echo "  STUDENT_FIRSTNAME = $STUDENT_FIRSTNAME"
        echo "  SERVER_IP = $SERVER_IP"
        echo "  MARIADB_ROOT_PASSWORD = $MARIADB_ROOT_PASSWORD"
        echo "  PHPMYADMIN_PASSWORD = $PHPMYADMIN_PASSWORD"
    fi
}

# ═══════════════════════════════════════════════════════════
# FONCTIONS
# ═══════════════════════════════════════════════════════════

show_welcome() {
    print_banner
    
    echo -e "${COLOR_BRIGHT_CYAN}   Créé par: ${STUDENT_FIRSTNAME} ${STUDENT_LASTNAME}${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_CYAN}   Formation: ${STUDENT_FORMATION}${COLOR_RESET}"
    echo ""
    
    print_header "INSTALLATION AUTOMATIQUE LEMP STACK"
    
    echo ""
    print_info "Installation:"
    echo "  • Nginx"
    echo "  • MariaDB"
    echo "  • PHP-FPM"
    echo "  • phpMyAdmin"
    echo "  • 2 Virtual Hosts"
    echo ""
}

run_prerequisites_checks() {
    print_header "VÉRIFICATION DES PRÉREQUIS"
    echo ""
    
    check_root
    print_success "Root OK"
    
    check_debian_version || exit 1
    
    if check_internet; then
        print_success "Internet OK"
    else
        print_error "Pas d'Internet"
        exit 1
    fi
    
    echo ""
    print_success "Prérequis OK"
    echo ""
}

confirm_installation() {
    echo ""
    print_warning "Installation dans 10s..."
    print_info "Ctrl+C pour annuler"
    echo ""
    
    countdown 10
    
    echo ""
    print_success "Démarrage !"
    echo ""
}

run_installation() {
    source "$SCRIPT_DIR/modules/01-system.sh"
    source "$SCRIPT_DIR/modules/02-nginx.sh"
    source "$SCRIPT_DIR/modules/03-mariadb.sh"
    source "$SCRIPT_DIR/modules/04-php.sh"
    source "$SCRIPT_DIR/modules/05-vhosts.sh"
    source "$SCRIPT_DIR/modules/06-phpmyadmin.sh"
    source "$SCRIPT_DIR/modules/07-security.sh"
    source "$SCRIPT_DIR/modules/08-finalize.sh"
    
    module_system_prepare || exit 1
    echo ""
    
    module_nginx_install || exit 1
    echo ""
    
    module_mariadb_install || exit 1
    echo ""
    
    module_php_install || exit 1
    echo ""
    
    module_vhosts_create || exit 1
    echo ""
    
    module_phpmyadmin_install || exit 1
    echo ""
    
    module_security_apply || exit 1
    echo ""
    
    module_finalize || exit 1
    echo ""
}

show_summary() {
    clear
    print_banner
    
    print_header "✨ INSTALLATION TERMINÉE ! ✨"
    
    local total_duration=$(timer_end)
    
    echo ""
    print_info "⏱️  Durée: $total_duration"
    echo ""
    
    print_header "🌐 VOS SITES"
    
    echo ""
    print_info "📱 Portal RH"
    echo "   ├─ http://${VHOST_PORTAL_DOMAIN}/"
    echo "   ├─ http://${VHOST_PORTAL_DOMAIN}/info.php"
    echo "   └─ http://${VHOST_PORTAL_DOMAIN}/pma/"
    echo "       └─ root / ${MARIADB_ROOT_PASSWORD}"
    echo ""
    
    print_info "🌍 Site Public"
    echo "   └─ http://${VHOST_PROD_DOMAIN}/"
    echo ""
    
    print_header "🔧 OUTILS"
    
    echo ""
    print_info "• Test: ./tools/test.sh"
    print_info "• Monitor: ./tools/monitor.sh"
    print_info "• Backup: ./tools/backup.sh"
    print_info "• Réseau: ./tools/migrate-to-netplan.sh"
    echo ""
    
    print_header "You are ready to go, ${STUDENT_FIRSTNAME} ! 🚀"
    echo ""
}

# ═══════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════

main() {
    # Menu
    show_main_menu
    
    # Init
    timer_start
    init_logger
    load_config
    
    # Mode Network
    if [ "$INSTALL_MODE" = "network" ]; then
        source "$SCRIPT_DIR/modules/00-network.sh"
        module_network_configure
        exit 0
    fi
    
    # Mode LEMP
    show_welcome
    run_prerequisites_checks
    confirm_installation
    run_installation
    show_summary
}

main "$@"
