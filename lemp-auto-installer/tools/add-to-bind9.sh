#!/bin/bash
# Ajouter un domaine à BIND9 - VERSION DYNAMIQUE

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.yaml"

source "$SCRIPT_DIR/lib/colors.sh"

print_header "➕ AJOUTER UN DOMAINE À BIND9"

# Vérifier BIND9
if ! systemctl is-active bind9 >/dev/null 2>&1; then
    print_error "BIND9 n'est pas actif"
    exit 1
fi

# Charger la config BIND9
if [ -f /etc/bind/lemp-installer-config.txt ]; then
    source /etc/bind/lemp-installer-config.txt
    print_info "Configuration chargée depuis /etc/bind/lemp-installer-config.txt"
    echo "  IP serveur: $SERVER_IP"
else
    # Charger depuis config.yaml
    SERVER_IP=$(grep -A4 "^server:" "$CONFIG_FILE" | grep "ip:" | awk '{print $2}' | tr -d '"')
    
    if [ -z "$SERVER_IP" ]; then
        read -p "IP du serveur DNS: " SERVER_IP
    fi
fi

echo ""
read -p "Domaine complet à ajouter (ex: api.example.com): " NEW_DOMAIN

if [ -z "$NEW_DOMAIN" ]; then
    print_error "Domaine vide"
    exit 1
fi

# Extraire le domaine racine
segments=$(echo "$NEW_DOMAIN" | tr '.' '\n' | wc -l)

if [ $segments -ge 2 ]; then
    ROOT_DOMAIN=$(echo "$NEW_DOMAIN" | awk -F'.' '{print $(NF-1)"."$NF}')
    SUBDOMAIN=$(echo "$NEW_DOMAIN" | sed "s/\.$ROOT_DOMAIN$//")
    [ -z "$SUBDOMAIN" ] && SUBDOMAIN="@"
else
    ROOT_DOMAIN="$NEW_DOMAIN"
    SUBDOMAIN="@"
fi

ZONE_FILE="/etc/bind/zones/db.${ROOT_DOMAIN}"

echo ""
print_info "Analyse:"
echo "  Domaine complet: $NEW_DOMAIN"
echo "  Zone: $ROOT_DOMAIN"
echo "  Sous-domaine: $SUBDOMAIN"
echo "  IP: $SERVER_IP"
echo "  Fichier zone: $ZONE_FILE"
echo ""

# Vérifier si la zone existe
if [ ! -f "$ZONE_FILE" ]; then
    print_warning "La zone $ROOT_DOMAIN n'existe pas"
    echo ""
    print_info "Voulez-vous créer cette zone ? [o/N]"
    read -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[OoYy]$ ]]; then
        print_info "Annulé"
        exit 0
    fi
    
    # Créer la zone
    print_substep "Création de la zone $ROOT_DOMAIN..."
    
    # Ajouter à named.conf.local
    cat >> /etc/bind/named.conf.local << NEWZONE

// Zone: $ROOT_DOMAIN (ajoutée le $(date))
zone "$ROOT_DOMAIN" {
    type master;
    file "/etc/bind/zones/db.$ROOT_DOMAIN";
};
NEWZONE

    # Créer le fichier de zone
    SERIAL=$(date +%Y%m%d)01
    SERVER_HOSTNAME=$(grep "hostname:" "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')
    [ -z "$SERVER_HOSTNAME" ] && SERVER_HOSTNAME="ns"
    
    cat > "$ZONE_FILE" << NEWZONEFILE
;
; Zone file for $ROOT_DOMAIN
; Generated: $(date)
;
\$TTL    604800
@       IN      SOA     ${SERVER_HOSTNAME}.$ROOT_DOMAIN. admin.$ROOT_DOMAIN. (
                              ${SERIAL}         ; Serial
                              604800         ; Refresh
                               86400         ; Retry
                             2419200         ; Expire
                              604800 )       ; Negative Cache TTL
;
; Name servers
@       IN      NS      ${SERVER_HOSTNAME}.$ROOT_DOMAIN.

; Server
${SERVER_HOSTNAME}      IN      A       ${SERVER_IP}

; Root domain
@       IN      A       ${SERVER_IP}
NEWZONEFILE
    
    chown bind:bind "$ZONE_FILE"
    chmod 644 "$ZONE_FILE"
    
    print_substep "✓ Zone créée"
fi

# Backup
sudo cp "$ZONE_FILE" "${ZONE_FILE}.backup-$(date +%Y%m%d%H%M%S)"

# Vérifier si l'entrée existe déjà
if grep -q "^${SUBDOMAIN}[[:space:]]" "$ZONE_FILE"; then
    print_warning "L'entrée $SUBDOMAIN existe déjà dans la zone"
    exit 0
fi

# Ajouter l'entrée
print_substep "Ajout de l'entrée DNS..."
if [ "$SUBDOMAIN" = "@" ]; then
    echo "@       IN      A       ${SERVER_IP}" | sudo tee -a "$ZONE_FILE" >/dev/null
else
    echo "${SUBDOMAIN}               IN      A       ${SERVER_IP}" | sudo tee -a "$ZONE_FILE" >/dev/null
fi

# Incrémenter le serial
print_substep "Incrémentation du serial..."
CURRENT_SERIAL=$(grep -oP '(?<=; Serial\n\s+)\d+' "$ZONE_FILE" | head -1)

if [ -z "$CURRENT_SERIAL" ]; then
    # Chercher autrement
    CURRENT_SERIAL=$(grep "Serial" "$ZONE_FILE" -A1 | tail -1 | awk '{print $1}')
fi

if [ -n "$CURRENT_SERIAL" ]; then
    NEW_SERIAL=$((CURRENT_SERIAL + 1))
    sudo sed -i "0,/${CURRENT_SERIAL}/{s/${CURRENT_SERIAL}/${NEW_SERIAL}/}" "$ZONE_FILE"
    print_substep "✓ Serial: $CURRENT_SERIAL → $NEW_SERIAL"
fi

# Valider
print_substep "Validation de la zone..."
if sudo named-checkzone "$ROOT_DOMAIN" "$ZONE_FILE" >/dev/null 2>&1; then
    print_substep "✓ Zone valide"
else
    print_error "Zone invalide, restauration du backup"
    sudo mv "${ZONE_FILE}.backup-"* "$ZONE_FILE"
    named-checkzone "$ROOT_DOMAIN" "$ZONE_FILE"
    exit 1
fi

# Recharger
print_substep "Rechargement de BIND9..."
sudo rndc reload >/dev/null 2>&1

# Tester
sleep 2
print_substep "Test de résolution..."
if dig @localhost "$NEW_DOMAIN" +short | grep -q "$SERVER_IP"; then
    print_success "✓ Domaine $NEW_DOMAIN ajouté et fonctionnel"
else
    print_warning "⚠ Résolution échouée, attendre quelques secondes"
    echo ""
    echo "Test manuel:"
    echo "  dig @$SERVER_IP $NEW_DOMAIN"
fi

echo ""
