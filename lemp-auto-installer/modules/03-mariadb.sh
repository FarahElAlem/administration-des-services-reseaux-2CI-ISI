#!/bin/bash
# Module 03: Installation MariaDB - CORRECTION

module_mariadb_install() {
    print_step "3" "8" "Installation de MariaDB"
    save_log_section "mariadb-install"
    timer_start
    
    # IMPORTANT: Vérifier que la variable est définie
    if [ -z "$MARIADB_ROOT_PASSWORD" ]; then
        print_error "MARIADB_ROOT_PASSWORD non défini dans config.yaml"
        return 1
    fi
    
    if check_package_installed "mariadb-server"; then
        print_warning "MariaDB déjà installé"
    else
        print_substep "Installation MariaDB..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq mariadb-server mariadb-client >/dev/null 2>&1 &
        spinner $!
        
        if [ $? -eq 0 ]; then
            print_substep "MariaDB installé"
        else
            print_error "Échec installation"
            return 1
        fi
    fi
    
    print_substep "Démarrage MariaDB..."
    systemctl enable mariadb >/dev/null 2>&1
    systemctl start mariadb
    
    if systemctl is-active mariadb >/dev/null 2>&1; then
        print_substep "✓ MariaDB actif"
    else
        print_error "MariaDB n'a pas démarré"
        return 1
    fi
    
    # Sécurisation avec le mot de passe DEPUIS CONFIG.YAML
    print_substep "Sécurisation MariaDB..."
    
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';" 2>/dev/null || \
    mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1
    
    mysql -u root -p"${MARIADB_ROOT_PASSWORD}" <<-EOSQL >/dev/null 2>&1
        DELETE FROM mysql.user WHERE User='';
        DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
        DROP DATABASE IF EXISTS test;
        DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
        FLUSH PRIVILEGES;
EOSQL
    
    if [ $? -eq 0 ]; then
        print_substep "✓ MariaDB sécurisé"
    else
        print_warning "Sécurisation partielle"
    fi
    
    local duration=$(timer_end)
    print_substep_last "Durée: $duration"
    print_success "MariaDB installé et sécurisé"
    
    end_log_section "mariadb-install"
    return 0
}
