#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Installation et configuration BIND9 (serveur DNS)
# VERSION 100% DYNAMIQUE - Aucune donnée en dur
# ═══════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.yaml"

source "$SCRIPT_DIR/lib/colors.sh"

print_banner
print_header "🌐 INSTALLATION BIND9 (Serveur DNS)"

# Vérifier root
if [ "$EUID" -ne 0 ]; then
    print_error "Ce script nécessite les droits root"
    exit 1
fi

# ═══════════════════════════════════════════════════════════
# CHARGEMENT DES VARIABLES DEPUIS CONFIG.YAML
# ═══════════════════════════════════════════════════════════

print_header "📋 CHARGEMENT DE LA CONFIGURATION"
echo ""

# Charger variables serveur
SERVER_IP=$(grep -A4 "^server:" "$CONFIG_FILE" | grep "ip:" | awk '{print $2}' | tr -d '"')
SERVER_HOSTNAME=$(grep "hostname:" "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')
SERVER_INTERFACE=$(grep -A4 "^server:" "$CONFIG_FILE" | grep "interface:" | awk '{print $2}' | tr -d '"')

# Afficher ce qui a été chargé
print_info "Variables depuis config.yaml:"
echo "  IP serveur: ${SERVER_IP:-non défini}"
echo "  Hostname: ${SERVER_HOSTNAME:-non défini}"
echo "  Interface: ${SERVER_INTERFACE:-non défini}"
echo ""

# Demander ce qui manque
if [ -z "$SERVER_IP" ]; then
    read -p "IP du serveur (ex: 192.168.1.50): " SERVER_IP
fi

if [ -z "$SERVER_HOSTNAME" ]; then
    read -p "Hostname du serveur (ex: srv-web01): " SERVER_HOSTNAME
fi

if [ -z "$SERVER_INTERFACE" ]; then
    # Lister les interfaces disponibles
    echo "Interfaces réseau disponibles:"
    ip -o link show | awk -F': ' '{print "  - "$2}' | grep -v "lo"
    read -p "Interface à utiliser: " SERVER_INTERFACE
fi

# Calculer le réseau depuis l'IP
IFS='.' read -r -a ip_parts <<< "$SERVER_IP"
NETWORK_PREFIX="${ip_parts[0]}.${ip_parts[1]}.${ip_parts[2]}"
NETWORK_CIDR="${NETWORK_PREFIX}.0/24"

echo ""
print_info "Configuration finale:"
echo "  IP: $SERVER_IP"
echo "  Hostname: $SERVER_HOSTNAME"
echo "  Interface: $SERVER_INTERFACE"
echo "  Réseau: $NETWORK_CIDR"
echo ""

# ═══════════════════════════════════════════════════════════
# RÉCUPÉRATION DES DOMAINES DEPUIS CONFIG.YAML
# ═══════════════════════════════════════════════════════════

print_info "Scan des Virtual Hosts dans config.yaml..."
echo ""

# Fonction pour extraire les domaines
extract_domains() {
    # Trouver toutes les sections vhosts
    grep -A4 "enabled: true" "$CONFIG_FILE" | grep "domain:" | awk '{print $2}' | tr -d '"'
}

# Récupérer tous les domaines
DOMAINS=($(extract_domains))

if [ ${#DOMAINS[@]} -eq 0 ]; then
    print_warning "Aucun domaine trouvé dans config.yaml"
    echo ""
    print_info "Voulez-vous ajouter des domaines manuellement ? [o/N]"
    read -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[OoYy]$ ]]; then
        DOMAINS=()
        while true; do
            read -p "Domaine à ajouter (entrée vide pour terminer): " domain
            [ -z "$domain" ] && break
            DOMAINS+=("$domain")
        done
    fi
fi

if [ ${#DOMAINS[@]} -eq 0 ]; then
    print_error "Aucun domaine configuré. Impossible de continuer."
    exit 1
fi

print_success "Domaines détectés: ${#DOMAINS[@]}"
for domain in "${DOMAINS[@]}"; do
    echo "  • $domain"
done

# Grouper les domaines par zone (domaine racine)
declare -A ZONES

for domain in "${DOMAINS[@]}"; do
    # Extraire le domaine racine (les 2 derniers segments)
    # Ex: portal-rh.ing-infraFarah.lan → ing-infraFarah.lan
    #     blog.innov-techFarah.com → innov-techFarah.com
    
    # Compter les segments
    segments=$(echo "$domain" | tr '.' '\n' | wc -l)
    
    if [ $segments -ge 2 ]; then
        # Prendre les 2 derniers segments
        root_domain=$(echo "$domain" | awk -F'.' '{print $(NF-1)"."$NF}')
        
        # Extraire le sous-domaine (tout avant le domaine racine)
        subdomain=$(echo "$domain" | sed "s/\.$root_domain$//")
        
        # Si pas de sous-domaine, c'est @ (root)
        [ -z "$subdomain" ] && subdomain="@"
        
        # Ajouter à la zone
        if [ -z "${ZONES[$root_domain]}" ]; then
            ZONES[$root_domain]="$subdomain"
        else
            ZONES[$root_domain]="${ZONES[$root_domain]}|$subdomain"
        fi
    fi
done

echo ""
print_info "Zones DNS à créer: ${#ZONES[@]}"
for zone in "${!ZONES[@]}"; do
    echo "  • $zone"
    # Afficher les sous-domaines
    IFS='|' read -ra subs <<< "${ZONES[$zone]}"
    for sub in "${subs[@]}"; do
        echo "    - $sub"
    done
done

echo ""
read -p "Confirmer l'installation ? [o/N] " -n 1 -r
echo ""
echo ""

if [[ ! $REPLY =~ ^[OoYy]$ ]]; then
    print_info "Installation annulée"
    exit 0
fi

# ═══════════════════════════════════════════════════════════
# ÉTAPE 1 : INSTALLATION
# ═══════════════════════════════════════════════════════════

print_header "📦 INSTALLATION DES PAQUETS"
echo ""

print_substep "Installation BIND9..."
apt update >/dev/null 2>&1
apt install -y bind9 bind9utils bind9-doc dnsutils >/dev/null 2>&1

if [ $? -eq 0 ]; then
    print_substep "✓ BIND9 installé"
else
    print_error "Échec installation"
    exit 1
fi

# ═══════════════════════════════════════════════════════════
# ÉTAPE 2 : BACKUP
# ═══════════════════════════════════════════════════════════

print_substep "Sauvegarde des configurations existantes..."
BACKUP_DIR="/root/bind9-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r /etc/bind "$BACKUP_DIR/" 2>/dev/null || true
print_substep "✓ Backup: $BACKUP_DIR"

# ═══════════════════════════════════════════════════════════
# ÉTAPE 3 : CONFIGURATION PRINCIPALE
# ═══════════════════════════════════════════════════════════

print_header "⚙️ CONFIGURATION BIND9"
echo ""

print_substep "Configuration /etc/bind/named.conf.options..."

cat > /etc/bind/named.conf.options << NAMEDOPTIONS
options {
    directory "/var/cache/bind";
    
    // Écouter sur toutes les interfaces
    listen-on { any; };
    listen-on-v6 { any; };
    
    // Autoriser les requêtes du réseau local
    allow-query { localhost; ${NETWORK_CIDR}; };
    
    // Forwarders (Google DNS)
    forwarders {
        8.8.8.8;
        8.8.4.4;
    };
    
    // Sécurité
    recursion yes;
    allow-recursion { localhost; ${NETWORK_CIDR}; };
    
    // DNSSEC
    dnssec-validation auto;
    
    // Logs
    querylog yes;
};
NAMEDOPTIONS

print_substep "✓ Options configurées (réseau: ${NETWORK_CIDR})"

# ═══════════════════════════════════════════════════════════
# ÉTAPE 4 : DÉCLARATION DES ZONES
# ═══════════════════════════════════════════════════════════

print_substep "Déclaration des zones..."

cat > /etc/bind/named.conf.local << 'NAMEDHEADER'
// ═══════════════════════════════════════════════════════════
// Zones locales - Générées automatiquement par LEMP Installer
// ═══════════════════════════════════════════════════════════

NAMEDHEADER

# Ajouter chaque zone
for zone in "${!ZONES[@]}"; do
    cat >> /etc/bind/named.conf.local << ZONEDECL

// Zone: $zone
zone "$zone" {
    type master;
    file "/etc/bind/zones/db.$zone";
};
ZONEDECL
done

# Zone reverse
REVERSE_ZONE="${ip_parts[2]}.${ip_parts[1]}.${ip_parts[0]}.in-addr.arpa"

cat >> /etc/bind/named.conf.local << REVERSEZONE

// Zone reverse (${NETWORK_CIDR})
zone "$REVERSE_ZONE" {
    type master;
    file "/etc/bind/zones/db.${NETWORK_PREFIX}";
};
REVERSEZONE

print_substep "✓ ${#ZONES[@]} zone(s) déclarée(s) + 1 reverse"

# ═══════════════════════════════════════════════════════════
# ÉTAPE 5 : FICHIERS DE ZONES
# ═══════════════════════════════════════════════════════════

print_substep "Création des fichiers de zones..."

mkdir -p /etc/bind/zones

SERIAL=$(date +%Y%m%d)01

# Créer chaque fichier de zone
for zone in "${!ZONES[@]}"; do
    print_substep "  • Création zone $zone..."
    
    cat > /etc/bind/zones/db.$zone << ZONEFILE
;
; Zone file for $zone
; Generated: $(date)
; Server: $SERVER_HOSTNAME ($SERVER_IP)
;
\$TTL    604800
@       IN      SOA     ${SERVER_HOSTNAME}.$zone. admin.$zone. (
                              ${SERIAL}         ; Serial
                              604800         ; Refresh
                               86400         ; Retry
                             2419200         ; Expire
                              604800 )       ; Negative Cache TTL
;
; Name servers
@       IN      NS      ${SERVER_HOSTNAME}.$zone.

; Server A record
${SERVER_HOSTNAME}      IN      A       ${SERVER_IP}

; Virtual Hosts A records
ZONEFILE

    # Ajouter les sous-domaines
    IFS='|' read -ra subs <<< "${ZONES[$zone]}"
    for sub in "${subs[@]}"; do
        if [ "$sub" = "@" ]; then
            echo "@       IN      A       ${SERVER_IP}" >> /etc/bind/zones/db.$zone
        else
            echo "${sub}               IN      A       ${SERVER_IP}" >> /etc/bind/zones/db.$zone
        fi
    done
    
    # Ajouter www si pas déjà présent
    if ! echo "${ZONES[$zone]}" | grep -q "www"; then
        echo "www                    IN      A       ${SERVER_IP}" >> /etc/bind/zones/db.$zone
    fi
done

# Zone reverse
print_substep "  • Création zone reverse..."

cat > /etc/bind/zones/db.${NETWORK_PREFIX} << REVERSEFILE
;
; Reverse DNS Zone for ${NETWORK_CIDR}
; Generated: $(date)
;
\$TTL    604800
@       IN      SOA     ${SERVER_HOSTNAME}.$(echo "${!ZONES[@]}" | awk '{print $1}'). admin.$(echo "${!ZONES[@]}" | awk '{print $1}'). (
                              ${SERIAL}         ; Serial
                              604800         ; Refresh
                               86400         ; Retry
                             2419200         ; Expire
                              604800 )       ; Negative Cache TTL
;
; Name servers
@       IN      NS      ${SERVER_HOSTNAME}.$(echo "${!ZONES[@]}" | awk '{print $1}').

; PTR record for server
${ip_parts[3]}      IN      PTR     ${SERVER_HOSTNAME}.$(echo "${!ZONES[@]}" | awk '{print $1}').

; PTR records for domains
REVERSEFILE

# Ajouter les PTR pour chaque domaine
for domain in "${DOMAINS[@]}"; do
    echo "${ip_parts[3]}      IN      PTR     ${domain}." >> /etc/bind/zones/db.${NETWORK_PREFIX}
done

# Permissions
chown -R bind:bind /etc/bind/zones
chmod 644 /etc/bind/zones/*

print_substep "✓ Fichiers de zones créés"

# ═══════════════════════════════════════════════════════════
# ÉTAPE 6 : VALIDATION
# ═══════════════════════════════════════════════════════════

print_header "🔍 VALIDATION"
echo ""

print_substep "Vérification de la configuration principale..."
if named-checkconf; then
    print_substep "✓ Configuration principale valide"
else
    print_error "Erreur dans la configuration"
    exit 1
fi

print_substep "Vérification des zones..."
for zone in "${!ZONES[@]}"; do
    if named-checkzone "$zone" /etc/bind/zones/db.$zone >/dev/null 2>&1; then
        print_substep "✓ Zone $zone valide"
    else
        print_error "✗ Zone $zone invalide"
        named-checkzone "$zone" /etc/bind/zones/db.$zone
    fi
done

# ═══════════════════════════════════════════════════════════
# ÉTAPE 7 : DÉMARRAGE
# ═══════════════════════════════════════════════════════════

echo ""
print_substep "Redémarrage de BIND9..."
systemctl restart bind9

if systemctl is-active bind9 >/dev/null 2>&1; then
    print_substep "✓ BIND9 actif"
    systemctl enable bind9 >/dev/null 2>&1
else
    print_error "✗ BIND9 n'a pas démarré"
    journalctl -xeu bind9 --no-pager | tail -20
    exit 1
fi

# ═══════════════════════════════════════════════════════════
# ÉTAPE 8 : TESTS
# ═══════════════════════════════════════════════════════════

print_header "🧪 TESTS DE RÉSOLUTION DNS"
echo ""

for domain in "${DOMAINS[@]}"; do
    print_substep "Test: $domain"
    if dig @localhost "$domain" +short | grep -q "${SERVER_IP}"; then
        print_substep "✓ Résolution OK"
    else
        print_warning "⚠ Échec résolution"
        dig @localhost "$domain"
    fi
done

# ═══════════════════════════════════════════════════════════
# RÉSUMÉ FINAL
# ═══════════════════════════════════════════════════════════

echo ""
print_header "✅ INSTALLATION TERMINÉE"
echo ""

print_success "BIND9 configuré et opérationnel"
echo ""

print_info "📋 Configuration:"
echo "  Serveur DNS : $SERVER_IP"
echo "  Hostname : $SERVER_HOSTNAME"
echo "  Réseau : $NETWORK_CIDR"
echo ""

print_info "📋 Domaines configurés:"
for domain in "${DOMAINS[@]}"; do
    echo "  • $domain → $SERVER_IP"
done
echo ""

print_info "🔧 Configuration des clients:"
echo ""
echo "Sur TOUS vos appareils, configurer:"
echo "  DNS préféré : $SERVER_IP"
echo "  DNS auxiliaire : 8.8.8.8"
echo ""

print_info "📝 Commandes utiles:"
echo "  • Statut : sudo systemctl status bind9"
echo "  • Logs : sudo journalctl -fu bind9"
echo "  • Tester : dig @$SERVER_IP $( echo "${DOMAINS[0]}" )"
echo "  • Recharger : sudo rndc reload"
echo ""

print_info "➕ Pour ajouter un domaine:"
echo "  1. Ajouter à config.yaml"
echo "  2. Relancer ce script"
echo "  OU utiliser: sudo ./tools/add-to-bind9.sh"
echo ""

print_info "💾 Backup des configs:"
echo "  $BACKUP_DIR"
echo ""

# Sauvegarder la config dans un fichier
cat > /etc/bind/lemp-installer-config.txt << CONFIGSAVE
# Configuration BIND9 - LEMP Auto-Installer
# Générée le: $(date)

SERVER_IP=$SERVER_IP
SERVER_HOSTNAME=$SERVER_HOSTNAME
SERVER_INTERFACE=$SERVER_INTERFACE
NETWORK_CIDR=$NETWORK_CIDR

DOMAINS=(${DOMAINS[@]})
CONFIGSAVE

print_info "💾 Configuration sauvegardée:"
echo "  /etc/bind/lemp-installer-config.txt"
echo ""
