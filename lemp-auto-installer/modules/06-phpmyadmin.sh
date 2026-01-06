#!/bin/bash
# Module 06: Installation phpMyAdmin - CORRECTION

module_phpmyadmin_install() {
    print_step "6" "8" "Installation de phpMyAdmin"
    save_log_section "phpmyadmin-install"
    timer_start
    
    # Charger templating
    source "$SCRIPT_DIR/lib/templating.sh"
    
    # VÉRIFIER les variables
    if [ -z "$MARIADB_ROOT_PASSWORD" ]; then
        print_error "MARIADB_ROOT_PASSWORD non défini"
        return 1
    fi
    
    if [ -z "$PHPMYADMIN_PASSWORD" ]; then
        print_warning "PHPMYADMIN_PASSWORD vide, utilisation du mot de passe MariaDB"
        PHPMYADMIN_PASSWORD="$MARIADB_ROOT_PASSWORD"
    fi
    
    if check_package_installed "phpmyadmin"; then
        print_warning "phpMyAdmin déjà installé"
    else
        print_substep "Installation phpMyAdmin..."
        
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
            phpmyadmin \
            --no-install-recommends \
            >/dev/null 2>&1 &
        spinner $!
        
        [ $? -eq 0 ] && print_substep "✓ phpMyAdmin installé" || {
            print_error "Échec installation"
            return 1
        }
    fi
    
    # Config BDD avec MOT DE PASSE DEPUIS CONFIG.YAML
    print_substep "Configuration base de données..."
    mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS phpmyadmin;" 2>/dev/null || true
    
    if [ -f /usr/share/doc/phpmyadmin/examples/create_tables.sql.gz ]; then
        zcat /usr/share/doc/phpmyadmin/examples/create_tables.sql.gz | \
            mysql -u root -p"${MARIADB_ROOT_PASSWORD}" phpmyadmin 2>/dev/null || true
    fi
    
    # Lien symbolique
    print_substep "Création du lien web..."
    
    VHOST_PORTAL_ROOT="${VHOST_PORTAL_ROOT:-/var/www/portal-rh.ing-infraFarah.lan/html}"
    
    [ ! -d "$VHOST_PORTAL_ROOT" ] && {
        mkdir -p "$VHOST_PORTAL_ROOT"
        chown -R www-data:www-data "$VHOST_PORTAL_ROOT"
        chmod -R 755 "$VHOST_PORTAL_ROOT"
    }
    
    rm -f "${VHOST_PORTAL_ROOT}/pma"
    ln -sf /usr/share/phpmyadmin "${VHOST_PORTAL_ROOT}/pma"
    
    [ -L "${VHOST_PORTAL_ROOT}/pma" ] && print_substep "✓ Lien créé" || {
        print_error "Échec création lien"
        return 1
    }
    
    # Config phpMyAdmin depuis template
    print_substep "Configuration phpMyAdmin..."
    
    if [ ! -f /etc/phpmyadmin/config.inc.php ]; then
        BLOWFISH_SECRET=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
        
        if [ -f "$SCRIPT_DIR/templates/phpmyadmin/config.inc.php.template" ]; then
            generate_from_template \
                "$SCRIPT_DIR/templates/phpmyadmin/config.inc.php.template" \
                "/etc/phpmyadmin/config.inc.php" \
                "BLOWFISH_SECRET" "$BLOWFISH_SECRET" \
                "INSTALL_DATE" "$(date '+%Y-%m-%d %H:%M:%S')"
        else
            # Fallback si template absent
            cat > /etc/phpmyadmin/config.inc.php << PHPMYADMINCONF
<?php
\$cfg['blowfish_secret'] = '${BLOWFISH_SECRET}';
\$i = 0;
\$i++;
\$cfg['Servers'][\$i]['auth_type'] = 'cookie';
\$cfg['Servers'][\$i]['host'] = 'localhost';
\$cfg['Servers'][\$i]['compress'] = false;
\$cfg['Servers'][\$i]['AllowNoPassword'] = false;
\$cfg['UploadDir'] = '';
\$cfg['SaveDir'] = '';
PHPMYADMINCONF
        fi
        
        print_substep "✓ Configuration créée"
    fi
    
    local duration=$(timer_end)
    print_substep_last "Durée: $duration"
    print_success "phpMyAdmin installé et configuré"
    
    # Afficher les identifiants
    print_info "Identifiants phpMyAdmin:"
    print_info "  URL: http://${VHOST_PORTAL_DOMAIN}/pma/"
    print_info "  User: root"
    print_info "  Pass: ${MARIADB_ROOT_PASSWORD}"
    
    end_log_section "phpmyadmin-install"
    return 0
}
