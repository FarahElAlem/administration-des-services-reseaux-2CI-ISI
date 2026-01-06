#!/bin/bash
# Module 01: Préparation du système

module_system_prepare() {
    print_step "1" "8" "Préparation du système"
    save_log_section "system-prepare"
    timer_start
    
    print_substep "Sauvegarde de la configuration..."
    create_backup "/etc/hosts"
    create_backup "/etc/hostname"
    
    print_substep "Mise à jour des dépôts APT..."
    apt-get update -qq >/dev/null 2>&1
    
    print_substep "Mise à jour du système..."
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq >/dev/null 2>&1 &
    spinner $!
    
    print_substep "Installation des outils de base..."
    local packages="curl wget gnupg2 ca-certificates apt-transport-https tree htop net-tools"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $packages >/dev/null 2>&1
    
    print_substep "Configuration du hostname..."
    if [ -n "$SERVER_HOSTNAME" ]; then
        hostnamectl set-hostname "$SERVER_HOSTNAME" 2>/dev/null
        log_info "Hostname: $SERVER_HOSTNAME"
    fi
    
    print_substep "Configuration de /etc/hosts..."
    cat > /etc/hosts << HOSTS_EOF
127.0.0.1       localhost
127.0.1.1       $SERVER_HOSTNAME

# Configuration LEMP
$SERVER_IP      $SERVER_HOSTNAME
$SERVER_IP      $VHOST_PORTAL_DOMAIN
$SERVER_IP      $VHOST_PROD_DOMAIN

::1             localhost ip6-localhost ip6-loopback
HOSTS_EOF
    
    if [ -n "$SERVER_TIMEZONE" ]; then
        print_substep "Configuration du timezone..."
        timedatectl set-timezone "$SERVER_TIMEZONE" 2>/dev/null
    fi
    
    local duration=$(timer_end)
    print_substep_last "Durée: $duration"
    print_success "Système préparé"
    
    end_log_section "system-prepare"
    return 0
}
