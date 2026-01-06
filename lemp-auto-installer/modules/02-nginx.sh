#!/bin/bash
# Module 02: Installation Nginx

module_nginx_install() {
    print_step "2" "8" "Installation de Nginx"
    save_log_section "nginx-install"
    timer_start
    
    if check_package_installed "nginx"; then
        print_warning "Nginx déjà installé"
        local version=$(nginx -v 2>&1 | cut -d'/' -f2)
        log_info "Version: $version"
    else
        print_substep "Installation de Nginx..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nginx >/dev/null 2>&1 &
        spinner $!
        
        if [ $? -eq 0 ]; then
            local version=$(nginx -v 2>&1 | cut -d'/' -f2)
            print_substep "Nginx $version installé"
        else
            print_error "Échec de l'installation de Nginx"
            return 1
        fi
    fi
    
    print_substep "Démarrage du service..."
    systemctl start nginx
    systemctl enable nginx >/dev/null 2>&1
    
    if check_service_active "nginx"; then
        print_substep "Service Nginx actif"
    else
        print_error "Le service Nginx n'a pas pu démarrer"
        return 1
    fi
    
    print_substep "Vérification du port 80..."
    sleep 2
    if check_port_listening 80; then
        print_substep "Port 80 en écoute"
    else
        print_warning "Port 80 non disponible"
    fi
    
    print_substep "Configuration initiale..."
    [ -f /etc/nginx/sites-enabled/default ] && rm -f /etc/nginx/sites-enabled/default
    
    print_substep "Test de configuration..."
    if nginx -t >/dev/null 2>&1; then
        print_substep "Configuration valide"
    else
        print_error "Configuration invalide"
        return 1
    fi
    
    local duration=$(timer_end)
    print_substep_last "Durée: $duration"
    print_success "Nginx installé et configuré"
    
    end_log_section "nginx-install"
    return 0
}
