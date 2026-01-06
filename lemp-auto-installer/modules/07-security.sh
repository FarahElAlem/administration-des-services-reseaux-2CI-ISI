#!/bin/bash
# Module 07: Sécurisation

module_security_apply() {
    print_step "7" "8" "Sécurisation du serveur"
    save_log_section "security"
    timer_start
    
    print_substep "Configuration des permissions..."
    
    # Portal RH
    if [ -d "$VHOST_PORTAL_ROOT" ]; then
        chown -R www-data:www-data "$VHOST_PORTAL_ROOT"
        find "$VHOST_PORTAL_ROOT" -type d -exec chmod 755 {} \;
        find "$VHOST_PORTAL_ROOT" -type f -exec chmod 644 {} \;
    fi
    
    # Prod Web
    if [ -d "$VHOST_PROD_ROOT" ]; then
        chown -R www-data:www-data "$VHOST_PROD_ROOT"
        find "$VHOST_PROD_ROOT" -type d -exec chmod 755 {} \;
        find "$VHOST_PROD_ROOT" -type f -exec chmod 644 {} \;
    fi
    
    print_substep "Sécurisation PHP..."
    local php_ini="/etc/php/${PHP_VERSION}/fpm/php.ini"
    if [ -f "$php_ini" ]; then
        sed -i 's/^expose_php = .*/expose_php = Off/' "$php_ini"
        systemctl restart "php${PHP_VERSION}-fpm" >/dev/null 2>&1
    fi
    
    local duration=$(timer_end)
    print_substep_last "Durée: $duration"
    print_success "Sécurité configurée"
    
    end_log_section "security"
    return 0
}
