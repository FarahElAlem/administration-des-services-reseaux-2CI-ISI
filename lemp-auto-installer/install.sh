#!/bin/bash
# ═══════════════════════════════════════════════════════════
# LEMP Auto-Installer - Script Principal
# ═══════════════════════════════════════════════════════════

set -euo pipefail

# Déterminer le répertoire du script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.yaml"

# ═══════════════════════════════════════════════════════════
# CHARGEMENT DES BIBLIOTHÈQUES
# ═══════════════════════════════════════════════════════════

if [ ! -f "$SCRIPT_DIR/lib/colors.sh" ]; then
    echo "ERREUR: Fichier lib/colors.sh introuvable"
    exit 1
fi

source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logger.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/validators.sh"
source "$SCRIPT_DIR/lib/templating.sh"

# ═══════════════════════════════════════════════════════════
# VÉRIFICATIONS PRÉALABLES
# ═══════════════════════════════════════════════════════════

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Ce script doit être exécuté en tant que root (sudo)"
        exit 1
    fi
}

check_os() {
    if [ ! -f /etc/os-release ]; then
        print_error "Impossible de détecter le système d'exploitation"
        exit 1
    fi
    
    source /etc/os-release
    
    if [[ "$ID" != "debian" ]]; then
        print_error "Ce script nécessite Debian (détecté: $ID)"
        exit 1
    fi
    
    # Accepter Debian 12 et 13
    DEBIAN_VERSION=$(echo "$VERSION_ID" | cut -d'.' -f1)
    if [[ "$DEBIAN_VERSION" -lt 12 ]]; then
        print_error "Debian $DEBIAN_VERSION non supporté (minimum: Debian 12)"
        exit 1
    fi
}

check_internet() {
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        print_error "Pas de connexion Internet"
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════
# CHARGEMENT DE LA CONFIGURATION
# ═══════════════════════════════════════════════════════════

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "Fichier config.yaml introuvable: $CONFIG_FILE"
        exit 1
    fi
    
    print_info "Chargement de la configuration depuis config.yaml..."
    
    # ─────────────────────────────────────────────────────────
    # Section user
    # ─────────────────────────────────────────────────────────
    export STUDENT_FIRSTNAME=$(grep "firstname:" "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f2)
    export STUDENT_LASTNAME=$(grep "lastname:" "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f2)
    export STUDENT_FORMATION=$(grep "formation:" "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f2)
    export STUDENT_EMAIL=$(grep "email:" "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f2)
    
    # ─────────────────────────────────────────────────────────
    # Section server
    # ─────────────────────────────────────────────────────────
    export SERVER_HOSTNAME=$(grep -A10 "^server:" "$CONFIG_FILE" 2>/dev/null | grep "hostname:" | awk '{print $2}' | tr -d '"')
    export SERVER_IP=$(grep -A10 "^server:" "$CONFIG_FILE" 2>/dev/null | grep "ip:" | awk '{print $2}' | tr -d '"')
    export SERVER_INTERFACE=$(grep -A10 "^server:" "$CONFIG_FILE" 2>/dev/null | grep "interface:" | awk '{print $2}' | tr -d '"')
    export SERVER_TIMEZONE=$(grep -A10 "^server:" "$CONFIG_FILE" 2>/dev/null | grep "timezone:" | awk '{print $2}' | tr -d '"')
    
    # ─────────────────────────────────────────────────────────
    # Section vhosts - Charger TOUS les vhosts dynamiquement
    # ─────────────────────────────────────────────────────────
    
    # Créer des tableaux pour stocker tous les vhosts
    VHOST_NAMES=()
    VHOST_ENABLED=()
    VHOST_DOMAINS=()
    VHOST_TYPES=()
    VHOST_ROOTS=()
    
    # Parser le YAML pour extraire tous les vhosts
    in_vhosts=false
    current_vhost=""
    
    while IFS= read -r line; do
        # Détecter la section vhosts
        if [[ "$line" =~ ^vhosts: ]]; then
            in_vhosts=true
            continue
        fi
        
        # Sortir de la section vhosts si on rencontre une nouvelle section
        if [[ "$in_vhosts" == true ]] && [[ "$line" =~ ^[a-z_]+: ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
            in_vhosts=false
            continue
        fi
        
        # Si on est dans vhosts
        if [[ "$in_vhosts" == true ]]; then
            # Nouveau vhost (indenté de 2 espaces)
            if [[ "$line" =~ ^[[:space:]]{2}([a-zA-Z0-9_-]+): ]]; then
                current_vhost="${BASH_REMATCH[1]}"
                VHOST_NAMES+=("$current_vhost")
            fi
            
            # Propriétés du vhost (indenté de 4 espaces)
            if [[ -n "$current_vhost" ]]; then
                if [[ "$line" =~ ^[[:space:]]{4}enabled:[[:space:]]*([a-z]+) ]]; then
                    VHOST_ENABLED+=("${BASH_REMATCH[1]}")
                elif [[ "$line" =~ ^[[:space:]]{4}domain:[[:space:]]*\"([^\"]+)\" ]]; then
                    VHOST_DOMAINS+=("${BASH_REMATCH[1]}")
                elif [[ "$line" =~ ^[[:space:]]{4}type:[[:space:]]*\"([^\"]+)\" ]]; then
                    VHOST_TYPES+=("${BASH_REMATCH[1]}")
                elif [[ "$line" =~ ^[[:space:]]{4}root:[[:space:]]*\"([^\"]+)\" ]]; then
                    VHOST_ROOTS+=("${BASH_REMATCH[1]}")
                fi
            fi
        fi
    done < "$CONFIG_FILE"
    
    # Exporter les tableaux (pas possible directement, donc on crée des variables indexées)
    export VHOST_COUNT=${#VHOST_NAMES[@]}
    
    for i in "${!VHOST_NAMES[@]}"; do
        export "VHOST_${i}_NAME=${VHOST_NAMES[$i]}"
        export "VHOST_${i}_ENABLED=${VHOST_ENABLED[$i]:-false}"
        export "VHOST_${i}_DOMAIN=${VHOST_DOMAINS[$i]:-}"
        export "VHOST_${i}_TYPE=${VHOST_TYPES[$i]:-static}"
        export "VHOST_${i}_ROOT=${VHOST_ROOTS[$i]:-}"
    done
    
    # Pour compatibilité avec les modules existants, garder les 2 premiers vhosts
    if [ ${#VHOST_NAMES[@]} -gt 0 ]; then
        export VHOST_PORTAL_ENABLED="${VHOST_ENABLED[0]:-false}"
        export VHOST_PORTAL_DOMAIN="${VHOST_DOMAINS[0]:-}"
        export VHOST_PORTAL_TYPE="${VHOST_TYPES[0]:-php}"
        export VHOST_PORTAL_ROOT="${VHOST_ROOTS[0]:-/var/www/portal-rh/html}"
    fi
    
    if [ ${#VHOST_NAMES[@]} -gt 1 ]; then
        export VHOST_PROD_ENABLED="${VHOST_ENABLED[1]:-false}"
        export VHOST_PROD_DOMAIN="${VHOST_DOMAINS[1]:-}"
        export VHOST_PROD_TYPE="${VHOST_TYPES[1]:-static}"
        export VHOST_PROD_ROOT="${VHOST_ROOTS[1]:-/var/www/prod-web/html}"
    fi
    
    # ─────────────────────────────────────────────────────────
    # Section security
    # ─────────────────────────────────────────────────────────
    export MARIADB_ROOT_PASSWORD=$(grep "mariadb_root_password:" "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f2)
    export PHPMYADMIN_PASSWORD=$(grep "phpmyadmin_password:" "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f2)
    
    # Si PHPMYADMIN_PASSWORD vide, utiliser MARIADB_ROOT_PASSWORD
    if [ -z "$PHPMYADMIN_PASSWORD" ]; then
        export PHPMYADMIN_PASSWORD="$MARIADB_ROOT_PASSWORD"
    fi
    
    # ─────────────────────────────────────────────────────────
    # Section components
    # ─────────────────────────────────────────────────────────
    export INSTALL_NGINX=$(grep -A10 "^components:" "$CONFIG_FILE" 2>/dev/null | grep "nginx:" | awk '{print $2}')
    export INSTALL_MARIADB=$(grep -A10 "^components:" "$CONFIG_FILE" 2>/dev/null | grep "mariadb:" | awk '{print $2}')
    export INSTALL_PHP=$(grep -A10 "^components:" "$CONFIG_FILE" 2>/dev/null | grep "php_fpm:" | awk '{print $2}')
    export INSTALL_PHPMYADMIN=$(grep -A10 "^components:" "$CONFIG_FILE" 2>/dev/null | grep "phpmyadmin:" | awk '{print $2}')
    export INSTALL_FAIL2BAN=$(grep -A10 "^components:" "$CONFIG_FILE" 2>/dev/null | grep "fail2ban:" | awk '{print $2}')
    export INSTALL_UFW=$(grep -A10 "^components:" "$CONFIG_FILE" 2>/dev/null | grep "ufw:" | awk '{print $2}')
    
    # Valeurs par défaut
    : ${INSTALL_NGINX:=true}
    : ${INSTALL_MARIADB:=true}
    : ${INSTALL_PHP:=true}
    : ${INSTALL_PHPMYADMIN:=true}
    : ${INSTALL_FAIL2BAN:=false}
    : ${INSTALL_UFW:=false}
    
    # ─────────────────────────────────────────────────────────
    # Section options
    # ─────────────────────────────────────────────────────────
    export CREATE_BACKUP=$(grep -A10 "^options:" "$CONFIG_FILE" 2>/dev/null | grep "create_backup:" | awk '{print $2}')
    export GENERATE_HOSTS_FILE=$(grep -A10 "^options:" "$CONFIG_FILE" 2>/dev/null | grep "generate_hosts_file:" | awk '{print $2}')
    export RUN_TESTS=$(grep -A10 "^options:" "$CONFIG_FILE" 2>/dev/null | grep "run_tests:" | awk '{print $2}')
    export VERBOSE=$(grep -A10 "^options:" "$CONFIG_FILE" 2>/dev/null | grep "verbose:" | awk '{print $2}')
    
    # Valeurs par défaut
    : ${CREATE_BACKUP:=true}
    : ${GENERATE_HOSTS_FILE:=true}
    : ${RUN_TESTS:=true}
    : ${VERBOSE:=false}
    
    # ─────────────────────────────────────────────────────────
    # Variables générées automatiquement
    # ─────────────────────────────────────────────────────────
    export OUTPUT_DIR="$SCRIPT_DIR/output"
    export INSTALL_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
    
    mkdir -p "$OUTPUT_DIR/logs"
    mkdir -p "$OUTPUT_DIR/reports"
    mkdir -p "$OUTPUT_DIR/configs"
    mkdir -p "$OUTPUT_DIR/backups"
    
    # ─────────────────────────────────────────────────────────
    # Validation des variables critiques
    # ─────────────────────────────────────────────────────────
    
    if [ -z "$SERVER_IP" ]; then
        print_error "SERVER_IP non défini dans config.yaml"
        exit 1
    fi
    
    if [ -z "$MARIADB_ROOT_PASSWORD" ]; then
        print_error "MARIADB_ROOT_PASSWORD non défini dans config.yaml"
        exit 1
    fi
    
    if [ "$VHOST_COUNT" -eq 0 ]; then
        print_warning "Aucun virtual host défini dans config.yaml"
    fi
    
    # ─────────────────────────────────────────────────────────
    # Affichage debug (si verbose)
    # ─────────────────────────────────────────────────────────
    
    if [ "$VERBOSE" = "true" ]; then
        echo ""
        print_info "Configuration chargée:"
        echo "  User: $STUDENT_FIRSTNAME $STUDENT_LASTNAME"
        echo "  Server: $SERVER_HOSTNAME ($SERVER_IP)"
        echo "  Virtual Hosts: $VHOST_COUNT"
        for i in $(seq 0 $((VHOST_COUNT - 1))); do
            vhost_name_var="VHOST_${i}_NAME"
            vhost_domain_var="VHOST_${i}_DOMAIN"
            vhost_enabled_var="VHOST_${i}_ENABLED"
            echo "    ${!vhost_name_var}: ${!vhost_domain_var} (${!vhost_enabled_var})"
        done
        echo "  MariaDB password: ${MARIADB_ROOT_PASSWORD:0:3}***"
        echo ""
    fi
    
    print_success "Configuration chargée avec succès"
}

# ═══════════════════════════════════════════════════════════
# MENU PRINCIPAL
# ═══════════════════════════════════════════════════════════

show_menu() {
    clear
    print_banner
    
    print_header "MENU PRINCIPAL"
    echo ""
    echo "  1. 🚀 Installation LEMP Stack"
    echo "  2. 🌐 Configuration Réseau"
    echo "  3. ❓ Aide"
    echo "  4. 🚪 Quitter"
    echo ""
}

show_help() {
    clear
    print_banner
    print_header "📚 AIDE"
    echo ""
    echo "Ce script installe automatiquement un stack LEMP complet:"
    echo ""
    echo "  • Linux (Debian)"
    echo "  • Nginx (serveur web)"
    echo "  • MariaDB (base de données)"
    echo "  • PHP-FPM (interpréteur PHP)"
    echo "  • phpMyAdmin (interface de gestion)"
    echo ""
    echo "Configuration:"
    echo "  Éditez le fichier config.yaml pour personnaliser l'installation"
    echo ""
    echo "Outils disponibles:"
    echo "  • ./tools/test.sh - Tester l'installation"
    echo "  • ./tools/backup.sh - Créer un backup"
    echo "  • ./tools/uninstall.sh - Désinstaller"
    echo "  • ./tools/add-vhost.sh - Ajouter un virtual host"
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
}

# ═══════════════════════════════════════════════════════════
# INSTALLATION
# ═══════════════════════════════════════════════════════════

run_installation() {
    clear
    print_banner
    
    print_header "🚀 INSTALLATION LEMP STACK"
    echo ""
    
    # Charger la configuration
    load_config
    
    echo ""
    print_info "Composants à installer:"
    [ "$INSTALL_NGINX" = "true" ] && echo "  ✓ Nginx"
    [ "$INSTALL_MARIADB" = "true" ] && echo "  ✓ MariaDB"
    [ "$INSTALL_PHP" = "true" ] && echo "  ✓ PHP-FPM"
    [ "$INSTALL_PHPMYADMIN" = "true" ] && echo "  ✓ phpMyAdmin"
    [ "$INSTALL_FAIL2BAN" = "true" ] && echo "  ✓ Fail2ban"
    [ "$INSTALL_UFW" = "true" ] && echo "  ✓ UFW"
    echo ""
    
    read -p "Continuer l'installation ? [o/N] " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[OoYy]$ ]]; then
        print_info "Installation annulée"
        return
    fi
    
    echo ""
    
    # Démarrer le timer
    INSTALL_START=$(date +%s)
    
    # Initialiser les logs
    init_log
    
    # ─────────────────────────────────────────────────────────
    # Modules d'installation
    # ─────────────────────────────────────────────────────────
    
    local modules=(
        "01-system"
        "02-nginx"
        "03-mariadb"
        "04-php"
        "05-vhosts"
        "06-phpmyadmin"
        "07-security"
        "08-finalize"
    )
    
    for module in "${modules[@]}"; do
        module_file="$SCRIPT_DIR/modules/${module}.sh"
        
        if [ ! -f "$module_file" ]; then
            print_error "Module introuvable: $module_file"
            continue
        fi
        
        source "$module_file"
        
        # Nom de la fonction: module_<nom>_install
        # Ex: module_system_install
        func_name="module_$(echo ${module#*-} | tr '-' '_')_install"
        
        if declare -f "$func_name" >/dev/null; then
            $func_name || {
                print_error "Échec du module $module"
                exit 1
            }
        else
            print_warning "Fonction $func_name introuvable dans $module"
        fi
    done
    
    # ─────────────────────────────────────────────────────────
    # Fin d'installation
    # ─────────────────────────────────────────────────────────
    
    INSTALL_END=$(date +%s)
    INSTALL_DURATION=$((INSTALL_END - INSTALL_START))
    INSTALL_DURATION_MIN=$((INSTALL_DURATION / 60))
    INSTALL_DURATION_SEC=$((INSTALL_DURATION % 60))
    
    echo ""
    print_header "✅ INSTALLATION TERMINÉE"
    echo ""
    print_success "Stack LEMP installé en ${INSTALL_DURATION_MIN}m ${INSTALL_DURATION_SEC}s"
    echo ""
    
    read -p "Appuyez sur Entrée pour continuer..."
}

# ═══════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════

main() {
    # Vérifications
    check_root
    check_os
    check_internet
    
    # Boucle du menu
    while true; do
        show_menu
        read -p "Votre choix: " choice
        
        case $choice in
            1)
                run_installation
                ;;
            2)
                if [ -f "$SCRIPT_DIR/tools/migrate-to-netplan.sh" ]; then
                    bash "$SCRIPT_DIR/tools/migrate-to-netplan.sh"
                else
                    print_error "Script de migration réseau introuvable"
                    read -p "Appuyez sur Entrée..."
                fi
                ;;
            3)
                show_help
                ;;
            4)
                print_info "Au revoir !"
                exit 0
                ;;
            *)
                print_error "Choix invalide"
                sleep 1
                ;;
        esac
    done
}

# Lancer le script
main "$@"
