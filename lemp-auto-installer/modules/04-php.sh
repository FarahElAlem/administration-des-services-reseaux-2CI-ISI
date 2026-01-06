#!/bin/bash
# Module 04: Installation PHP-FPM

module_php_install() {
    print_step "4" "8" "Installation de PHP-FPM"
    save_log_section "php-install"
    timer_start
    
    local php_packages="php-fpm php-mysql php-cli php-mbstring php-xml php-curl php-gd php-zip"
    
    print_substep "Installation des paquets PHP..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $php_packages >/dev/null 2>&1 &
    spinner $!
    
    if [ $? -eq 0 ]; then
        PHP_VERSION=$(php -v | head -n1 | cut -d' ' -f2 | cut -d'.' -f1,2)
        export PHP_FPM_SOCKET="/run/php/php${PHP_VERSION}-fpm.sock"
        print_substep "PHP $PHP_VERSION installé"
        print_substep "Socket: $PHP_FPM_SOCKET"
    else
        print_error "Échec de l'installation"
        return 1
    fi
    
    print_substep "Démarrage de PHP-FPM..."
    systemctl start "php${PHP_VERSION}-fpm"
    systemctl enable "php${PHP_VERSION}-fpm" >/dev/null 2>&1
    
    if check_service_active "php${PHP_VERSION}-fpm"; then
        print_substep "Service PHP-FPM actif"
    else
        print_error "Le service n'a pas pu démarrer"
        return 1
    fi
    
    print_substep "Vérification du socket..."
    sleep 2
    if [ -S "$PHP_FPM_SOCKET" ]; then
        print_substep "Socket PHP-FPM créé"
    else
        print_error "Socket introuvable"
        return 1
    fi
    
    print_substep "Configuration PHP..."
    local php_ini="/etc/php/${PHP_VERSION}/fpm/php.ini"
    if [ -f "$php_ini" ]; then
        create_backup "$php_ini"
        sed -i 's/^;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' "$php_ini"
        sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 64M/' "$php_ini"
        sed -i 's/^post_max_size = .*/post_max_size = 64M/' "$php_ini"
        sed -i 's/^max_execution_time = .*/max_execution_time = 300/' "$php_ini"
        sed -i 's/^memory_limit = .*/memory_limit = 256M/' "$php_ini"
        systemctl restart "php${PHP_VERSION}-fpm"
        print_substep "Optimisations appliquées"
    fi
    
    local duration=$(timer_end)
    print_substep_last "Durée: $duration"
    print_success "PHP-FPM installé et configuré"
    
    end_log_section "php-install"
    return 0
}
