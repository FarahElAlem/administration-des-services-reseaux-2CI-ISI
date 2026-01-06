#!/bin/bash
# Module 05: Configuration Virtual Hosts - AVEC TEMPLATES

module_vhosts_create() {
    print_step "5" "8" "Configuration des Virtual Hosts"
    save_log_section "vhosts-create"
    timer_start
    
    # Charger la bibliothèque de templating
    source "$SCRIPT_DIR/lib/templating.sh"
    
    # Définir valeurs par défaut si vides
    VHOST_PORTAL_ROOT="${VHOST_PORTAL_ROOT:-/var/www/portal-rh.ing-infraFarah.lan/html}"
    VHOST_PROD_ROOT="${VHOST_PROD_ROOT:-/var/www/prod-web.innov-techFarah.com/html}"
    
    # Détecter version PHP
    PHP_VERSION=$(php -v | head -n1 | cut -d' ' -f2 | cut -d'.' -f1,2)
    
    # ═══════════════════════════════════════════════════════════
    # Virtual Host 1: Portal RH (PHP)
    # ═══════════════════════════════════════════════════════════
    
    print_substep "Création VHost: $VHOST_PORTAL_DOMAIN"
    
    # Créer structure
    mkdir -p "$VHOST_PORTAL_ROOT"
    chown -R www-data:www-data "$VHOST_PORTAL_ROOT"
    chmod -R 755 "$VHOST_PORTAL_ROOT"
    
    # Générer index.html depuis template
    generate_from_template \
        "$SCRIPT_DIR/templates/html/portal-rh.html.template" \
        "${VHOST_PORTAL_ROOT}/index.html" \
        "STUDENT_FIRSTNAME" "$STUDENT_FIRSTNAME" \
        "STUDENT_LASTNAME" "$STUDENT_LASTNAME" \
        "STUDENT_FORMATION" "$STUDENT_FORMATION" \
        "SERVER_HOSTNAME" "$SERVER_HOSTNAME" \
        "SERVER_IP" "$SERVER_IP"
    
    # Générer info.php depuis template
    generate_from_template \
        "$SCRIPT_DIR/templates/html/info.php.template" \
        "${VHOST_PORTAL_ROOT}/info.php" \
        "STUDENT_FIRSTNAME" "$STUDENT_FIRSTNAME" \
        "STUDENT_LASTNAME" "$STUDENT_LASTNAME" \
        "STUDENT_FORMATION" "$STUDENT_FORMATION"
    
    # Générer config Nginx depuis template
    generate_from_template \
        "$SCRIPT_DIR/templates/nginx/vhost-php.conf.template" \
        "/etc/nginx/sites-available/portal-rh.conf" \
        "DOMAIN" "$VHOST_PORTAL_DOMAIN" \
        "ROOT" "$VHOST_PORTAL_ROOT" \
        "NAME" "portal-rh" \
        "PHP_VERSION" "$PHP_VERSION"
    
    ln -sf /etc/nginx/sites-available/portal-rh.conf /etc/nginx/sites-enabled/
    chown www-data:www-data "${VHOST_PORTAL_ROOT}/info.php" "${VHOST_PORTAL_ROOT}/index.html"
    chmod 644 "${VHOST_PORTAL_ROOT}/info.php" "${VHOST_PORTAL_ROOT}/index.html"
    
    print_substep "✓ Portal RH configuré"
    
    # ═══════════════════════════════════════════════════════════
    # Virtual Host 2: Site Public (Static)
    # ═══════════════════════════════════════════════════════════
    
    print_substep "Création VHost: $VHOST_PROD_DOMAIN"
    
    mkdir -p "$VHOST_PROD_ROOT"
    chown -R www-data:www-data "$VHOST_PROD_ROOT"
    chmod -R 755 "$VHOST_PROD_ROOT"
    
    # Générer index.html depuis template
    generate_from_template \
        "$SCRIPT_DIR/templates/html/site-public.html.template" \
        "${VHOST_PROD_ROOT}/index.html" \
        "SITE_TITLE" "Innov-Tech Farah" \
        "STUDENT_FIRSTNAME" "$STUDENT_FIRSTNAME" \
        "STUDENT_LASTNAME" "$STUDENT_LASTNAME" \
        "STUDENT_FORMATION" "$STUDENT_FORMATION"
    
    # Générer config Nginx depuis template
    generate_from_template \
        "$SCRIPT_DIR/templates/nginx/vhost-static.conf.template" \
        "/etc/nginx/sites-available/prod-web.conf" \
        "DOMAIN" "$VHOST_PROD_DOMAIN" \
        "ROOT" "$VHOST_PROD_ROOT" \
        "NAME" "prod-web"
    
    ln -sf /etc/nginx/sites-available/prod-web.conf /etc/nginx/sites-enabled/
    chown www-data:www-data "${VHOST_PROD_ROOT}/index.html"
    chmod 644 "${VHOST_PROD_ROOT}/index.html"
    
    print_substep "✓ Site Public configuré"
    
    # ═══════════════════════════════════════════════════════════
    # Test configuration
    # ═══════════════════════════════════════════════════════════
    
    print_substep "Test configuration Nginx..."
    if nginx -t >/dev/null 2>&1; then
        print_substep "✓ Configuration valide"
    else
        print_error "Configuration invalide"
        nginx -t
        return 1
    fi
    
    print_substep "Rechargement Nginx..."
    systemctl reload nginx
    
    local duration=$(timer_end)
    print_substep_last "Durée: $duration"
    print_success "Virtual Hosts créés"
    
    end_log_section "vhosts-create"
    return 0
}
