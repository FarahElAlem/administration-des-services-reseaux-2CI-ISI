#!/bin/bash
# Script pour ajouter un nouveau Virtual Host - VERSION CORRIGÉE

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.yaml"

source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/templating.sh"

print_banner
print_header "🌐 AJOUTER UN NOUVEAU VIRTUAL HOST"

echo ""

# Demander les informations
read -p "Nom du site (ex: blog): " SITE_NAME
read -p "Domaine (ex: blog.example.com): " DOMAIN
echo ""
echo "Type de site:"
echo "  1. PHP (avec PHP-FPM)"
echo "  2. Static (HTML/CSS/JS uniquement)"
read -p "Votre choix [1-2]: " TYPE_CHOICE

if [ "$TYPE_CHOICE" = "1" ]; then
    SITE_TYPE="php"
    TEMPLATE_NGINX="vhost-php.conf.template"
    TEMPLATE_HTML="blog.html.template"  # ← NOUVEAU : template spécifique pour PHP
else
    SITE_TYPE="static"
    TEMPLATE_NGINX="vhost-static.conf.template"
    TEMPLATE_HTML="site-public.html.template"
fi

ROOT_DIR="/var/www/${DOMAIN}/html"

echo ""
print_info "Récapitulatif:"
echo "  Nom: $SITE_NAME"
echo "  Domaine: $DOMAIN"
echo "  Type: $SITE_TYPE"
echo "  Racine: $ROOT_DIR"
echo ""

read -p "Confirmer la création ? [o/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[OoYy]$ ]]; then
    print_info "Annulé"
    exit 0
fi

# Charger les variables depuis config.yaml
export STUDENT_FIRSTNAME=$(grep "firstname:" "$CONFIG_FILE" | cut -d'"' -f2)
export STUDENT_LASTNAME=$(grep "lastname:" "$CONFIG_FILE" | cut -d'"' -f2)
export STUDENT_FORMATION=$(grep "formation:" "$CONFIG_FILE" | cut -d'"' -f2)
export SERVER_IP=$(grep -A4 "^server:" "$CONFIG_FILE" | grep "ip:" | awk '{print $2}' | tr -d '"')
export PHP_VERSION=$(php -v 2>/dev/null | head -n1 | cut -d' ' -f2 | cut -d'.' -f1,2)

print_header "CRÉATION DU VIRTUAL HOST"
echo ""

# 1. Créer la structure de répertoires
print_substep "Création des répertoires..."
sudo mkdir -p "$ROOT_DIR"
sudo chown -R www-data:www-data "$ROOT_DIR"
sudo chmod -R 755 "$ROOT_DIR"

# 2. Générer index.html AVEC LE BON TEMPLATE
print_substep "Création de la page d'accueil..."

if [ -f "$SCRIPT_DIR/templates/html/$TEMPLATE_HTML" ]; then
    generate_from_template \
        "$SCRIPT_DIR/templates/html/$TEMPLATE_HTML" \
        "${ROOT_DIR}/index.html" \
        "SITE_TITLE" "${SITE_NAME^}" \
        "STUDENT_FIRSTNAME" "$STUDENT_FIRSTNAME" \
        "STUDENT_LASTNAME" "$STUDENT_LASTNAME" \
        "STUDENT_FORMATION" "$STUDENT_FORMATION"
else
    # Fallback si template n'existe pas
    print_warning "Template $TEMPLATE_HTML introuvable, création page basique"
    cat > "${ROOT_DIR}/index.html" << HTMLFALLBACK
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>${SITE_NAME^}</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
        }
        .container {
            text-align: center;
            background: rgba(255,255,255,0.1);
            padding: 60px;
            border-radius: 15px;
            backdrop-filter: blur(10px);
        }
        h1 { font-size: 3em; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 ${SITE_NAME^}</h1>
        <p>Type: ${SITE_TYPE}</p>
        <p>Par: $STUDENT_FIRSTNAME $STUDENT_LASTNAME</p>
    </div>
</body>
</html>
HTMLFALLBACK
fi

sudo chown www-data:www-data "${ROOT_DIR}/index.html"
sudo chmod 644 "${ROOT_DIR}/index.html"

# 3. Si PHP, créer aussi un fichier info.php
if [ "$SITE_TYPE" = "php" ]; then
    print_substep "Création de info.php..."
    cat > "${ROOT_DIR}/info.php" << 'PHPINFO'
<?php
phpinfo();
?>
PHPINFO
    sudo chown www-data:www-data "${ROOT_DIR}/info.php"
    sudo chmod 644 "${ROOT_DIR}/info.php"
fi

# 4. Créer config Nginx
print_substep "Création de la configuration Nginx..."
generate_from_template \
    "$SCRIPT_DIR/templates/nginx/${TEMPLATE_NGINX}" \
    "/tmp/${SITE_NAME}.conf" \
    "DOMAIN" "$DOMAIN" \
    "ROOT" "$ROOT_DIR" \
    "NAME" "$SITE_NAME" \
    "PHP_VERSION" "$PHP_VERSION"

sudo mv "/tmp/${SITE_NAME}.conf" "/etc/nginx/sites-available/${SITE_NAME}.conf"

# 5. Activer le site
print_substep "Activation du site..."
sudo ln -sf "/etc/nginx/sites-available/${SITE_NAME}.conf" "/etc/nginx/sites-enabled/"

# 6. Tester la config Nginx
print_substep "Test de la configuration..."
if sudo nginx -t >/dev/null 2>&1; then
    print_substep "✓ Configuration valide"
else
    print_error "Configuration invalide"
    sudo nginx -t
    exit 1
fi

# 7. Recharger Nginx
print_substep "Rechargement de Nginx..."
sudo systemctl reload nginx

echo ""
print_success "Virtual Host créé avec succès !"
echo ""

print_header "PROCHAINES ÉTAPES"
echo ""
print_info "1. Ajouter au fichier hosts Windows:"
echo "   C:\\Windows\\System32\\drivers\\etc\\hosts"
echo ""
echo "   ${SERVER_IP}    ${DOMAIN}"
echo ""
print_info "2. Tester dans le navigateur:"
echo "   http://${DOMAIN}/"

if [ "$SITE_TYPE" = "php" ]; then
    echo "   http://${DOMAIN}/info.php"
fi

echo ""

# 8. Ajouter à config.yaml
print_info "3. (Optionnel) Ajouter à config.yaml pour le garder:"
echo ""
echo "vhosts:"
echo "  ${SITE_NAME}:"
echo "    enabled: true"
echo "    domain: \"${DOMAIN}\""
echo "    type: \"${SITE_TYPE}\""
echo "    root: \"${ROOT_DIR}\""
echo ""
