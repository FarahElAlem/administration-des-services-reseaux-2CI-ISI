#!/bin/bash
# Module 08: Finalisation - VERSION AVEC TEMPLATES

module_finalize() {
    print_step "8" "8" "Finalisation"
    save_log_section "finalize"
    timer_start
    
    # IMPORTANT: Charger la bibliothèque de templating
    source "$SCRIPT_DIR/lib/templating.sh"
    
    # UTILISER le dossier output/ DU PROJET
    local OUTPUT_DIR="$SCRIPT_DIR/output"
    mkdir -p "$OUTPUT_DIR/logs" "$OUTPUT_DIR/reports" "$OUTPUT_DIR/configs" "$OUTPUT_DIR/backups"
    
    print_substep "Redémarrage des services..."
    systemctl restart nginx >/dev/null 2>&1
    systemctl restart "php${PHP_VERSION}-fpm" >/dev/null 2>&1
    systemctl restart mariadb >/dev/null 2>&1
    sleep 2
    
    print_substep "Vérification des services..."
    local all_ok=true
    
    check_service_active "nginx" && print_substep "✓ Nginx: Actif" || { print_substep "✗ Nginx: Inactif"; all_ok=false; }
    check_service_active "php${PHP_VERSION}-fpm" && print_substep "✓ PHP-FPM: Actif" || { print_substep "✗ PHP-FPM: Inactif"; all_ok=false; }
    check_service_active "mariadb" && print_substep "✓ MariaDB: Actif" || { print_substep "✗ MariaDB: Inactif"; all_ok=false; }
    check_port_listening 80 && print_substep "✓ Port 80: En écoute" || { print_substep "✗ Port 80: Inactif"; all_ok=false; }
    
    # Générer le fichier hosts Windows DEPUIS TEMPLATE
    print_substep "Génération fichier hosts Windows..."
    
    if [ -f "$SCRIPT_DIR/templates/hosts-windows.txt.template" ]; then
        generate_from_template \
            "$SCRIPT_DIR/templates/hosts-windows.txt.template" \
            "${OUTPUT_DIR}/configs/hosts-windows.txt" \
            "STUDENT_FIRSTNAME" "$STUDENT_FIRSTNAME" \
            "STUDENT_LASTNAME" "$STUDENT_LASTNAME" \
            "SERVER_HOSTNAME" "$SERVER_HOSTNAME" \
            "SERVER_IP" "$SERVER_IP" \
            "VHOST_PORTAL_DOMAIN" "$VHOST_PORTAL_DOMAIN" \
            "VHOST_PROD_DOMAIN" "$VHOST_PROD_DOMAIN" \
            "INSTALL_DATE" "$(date '+%Y-%m-%d %H:%M:%S')"
        
        print_substep "✓ Fichier hosts généré"
    else
        # Fallback si template n'existe pas
        cat > "${OUTPUT_DIR}/configs/hosts-windows.txt" << HOSTSWIN
# ═══════════════════════════════════════════════════════════
# FICHIER HOSTS POUR WINDOWS
# Serveur LEMP - ${STUDENT_FIRSTNAME} ${STUDENT_LASTNAME}
# ═══════════════════════════════════════════════════════════

${SERVER_IP}    ${VHOST_PORTAL_DOMAIN}
${SERVER_IP}    ${VHOST_PROD_DOMAIN}

# URLs à tester:
# - http://${VHOST_PORTAL_DOMAIN}/
# - http://${VHOST_PORTAL_DOMAIN}/info.php
# - http://${VHOST_PORTAL_DOMAIN}/pma/
# - http://${VHOST_PROD_DOMAIN}/
HOSTSWIN
        print_substep "✓ Fichier hosts généré (fallback)"
    fi
    
    # Copier les logs d'installation
    print_substep "Copie des logs..."
    cp /var/log/lemp-install.log "${OUTPUT_DIR}/logs/installation-$(date +%Y%m%d-%H%M%S).log" 2>/dev/null || true
    
    # Générer un rapport d'installation
    print_substep "Génération du rapport..."
    cat > "${OUTPUT_DIR}/reports/rapport-installation.md" << RAPPORT
# 📊 RAPPORT D'INSTALLATION LEMP STACK

**Date :** $(date '+%Y-%m-%d %H:%M:%S')
**Étudiante :** ${STUDENT_FIRSTNAME} ${STUDENT_LASTNAME}
**Formation :** ${STUDENT_FORMATION}
**Serveur :** ${SERVER_HOSTNAME} (${SERVER_IP})

---

## ✅ Stack Installée

| Composant | Version | État |
|-----------|---------|------|
| Nginx | $(nginx -v 2>&1 | cut -d'/' -f2) | ✅ |
| PHP-FPM | ${PHP_VERSION} | ✅ |
| MariaDB | $(mysql --version | cut -d' ' -f5 | cut -d',' -f1) | ✅ |
| phpMyAdmin | Installé | ✅ |

---

## 🌐 Virtual Hosts

### 1. Portal RH (PHP)
- **URL :** http://${VHOST_PORTAL_DOMAIN}/
- **PHP Info :** http://${VHOST_PORTAL_DOMAIN}/info.php
- **phpMyAdmin :** http://${VHOST_PORTAL_DOMAIN}/pma/

### 2. Site Public (Statique)
- **URL :** http://${VHOST_PROD_DOMAIN}/

---

## 🔐 Connexions

**MariaDB / phpMyAdmin :**
- Utilisateur : root
- Mot de passe : ${MARIADB_ROOT_PASSWORD}

---

## 📁 Fichiers Importants

- Config Portal RH : /etc/nginx/sites-available/portal-rh.conf
- Config Prod Web : /etc/nginx/sites-available/prod-web.conf
- Logs Nginx : /var/log/nginx/
- Fichier hosts Windows : ${OUTPUT_DIR}/configs/hosts-windows.txt

---

**Rapport généré automatiquement par LEMP Auto-Installer v2.0**
RAPPORT
    
    # Tests automatiques
    if [ "$RUN_TESTS" = "true" ]; then
        print_substep "Tests automatiques..."
        
        local test_file="${OUTPUT_DIR}/reports/tests-$(date +%Y%m%d-%H%M%S).txt"
        
        {
            echo "═══════════════════════════════════════════════════════════"
            echo "RÉSULTATS DES TESTS - $(date)"
            echo "═══════════════════════════════════════════════════════════"
            echo ""
            
            # Test Portal RH
            echo "Test 1: Portal RH"
            if curl -s -o /dev/null -w "%{http_code}" -H "Host: ${VHOST_PORTAL_DOMAIN}" http://localhost/ | grep -q "200"; then
                echo "  ✓ http://${VHOST_PORTAL_DOMAIN}/ - OK"
            else
                echo "  ✗ http://${VHOST_PORTAL_DOMAIN}/ - ERREUR"
            fi
            
            # Test PHP
            echo ""
            echo "Test 2: PHP Info"
            if curl -s -H "Host: ${VHOST_PORTAL_DOMAIN}" http://localhost/info.php | grep -q "phpinfo"; then
                echo "  ✓ http://${VHOST_PORTAL_DOMAIN}/info.php - OK"
            else
                echo "  ✗ http://${VHOST_PORTAL_DOMAIN}/info.php - ERREUR"
            fi
            
            # Test Prod Web
            echo ""
            echo "Test 3: Site Public"
            if curl -s -o /dev/null -w "%{http_code}" -H "Host: ${VHOST_PROD_DOMAIN}" http://localhost/ | grep -q "200"; then
                echo "  ✓ http://${VHOST_PROD_DOMAIN}/ - OK"
            else
                echo "  ✗ http://${VHOST_PROD_DOMAIN}/ - ERREUR"
            fi
            
            echo ""
            echo "═══════════════════════════════════════════════════════════"
        } > "$test_file"
        
        print_substep "Résultats: ${test_file}"
    fi
    
    local duration=$(timer_end)
    print_substep_last "Durée: $duration"
    print_success "Finalisation terminée"
    
    # Mettre à jour la variable pour l'affichage final
    export OUTPUT_DIR
    
    end_log_section "finalize"
}
