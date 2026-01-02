#!/bin/bash
# ==============================================================================
# Nom du script : migrate_to_netplan.sh
# Description   : Automatise la migration de /etc/network/interfaces vers Netplan
#                 sur Debian (10, 11, 12, 13).
# Auteur        : Farah El Alem
# Date          : 2025
# ==============================================================================

# Couleurs pour la lisibilité
VERT='\033[0;32m'
JAUNE='\033[1;33m'
ROUGE='\033[0;31m'
NC='\033[0m' # No Color

# 1. Vérification root
if [ "$EUID" -ne 0 ]; then
  echo -e "${ROUGE}Erreur : Ce script doit être lancé avec sudo ou en root.${NC}"
  exit 1
fi

clear
echo -e "${VERT}==================================================${NC}"
echo -e "${VERT}   MIGRATION AUTOMATISÉE VERS NETPLAN (DEBIAN)    ${NC}"
echo -e "${VERT}==================================================${NC}"
echo ""

# 2. Vérification et installation de Netplan
echo -e "${JAUNE}[1/5] Vérification de l'installation de Netplan...${NC}"
apt update -qq
if ! command -v netplan &> /dev/null; then
    echo "Installation de netplan.io en cours..."
    apt install -y netplan.io
else
    echo "Netplan est déjà installé."
fi

# 3. Configuration interactive
echo ""
echo -e "${JAUNE}[2/5] Configuration des interfaces${NC}"
echo "Appuyez sur Entrée pour accepter la valeur par défaut entre crochets [ ]."

# Interface Principale (souvent DHCP pour management)
read -p "Nom de l'interface principale (DHCP) [ens33] : " INT_MAIN
INT_MAIN=${INT_MAIN:-ens33}

# Interface 2 (Statique)
read -p "Nom de la 2ème interface [ens37] : " INT_2
INT_2=${INT_2:-ens37}
read -p "IP pour $INT_2 (ex: 192.168.10.50/24) : " IP_2
IP_2=${IP_2:-192.168.10.50/24}

# Interface 3 (Statique)
read -p "Nom de la 3ème interface [ens38] : " INT_3
INT_3=${INT_3:-ens38}
read -p "IP pour $INT_3 (ex: 172.16.20.50/24) : " IP_3
IP_3=${IP_3:-172.16.20.50/24}

# 4. Sauvegarde de l'ancienne configuration
echo ""
echo -e "${JAUNE}[3/5] Sauvegarde et désactivation de ifupdown${NC}"
if [ -f /etc/network/interfaces ]; then
    BACKUP_NAME="/etc/network/interfaces.backup_$(date +%F_%T)"
    cp /etc/network/interfaces "$BACKUP_NAME"
    mv /etc/network/interfaces /etc/network/interfaces.old
    echo "Backup créé : $BACKUP_NAME"
else
    echo "Fichier interfaces non trouvé, passage à la suite."
fi

# Désactivation des anciens services
systemctl disable networking &> /dev/null
systemctl stop networking &> /dev/null

# 5. Génération du fichier YAML
echo ""
echo -e "${JAUNE}[4/5] Génération de la configuration Netplan${NC}"
CONFIG_FILE="/etc/netplan/01-netcfg.yaml"

cat > "$CONFIG_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INT_MAIN:
      dhcp4: true
    $INT_2:
      dhcp4: false
      addresses:
        - $IP_2
    $INT_3:
      dhcp4: false
      addresses:
        - $IP_3
EOF
echo "Fichier $CONFIG_FILE généré."

# 6. Application
echo ""
echo -e "${JAUNE}[5/5] Application de la configuration...${NC}"

# Activation du backend systemd-networkd
systemctl enable systemd-networkd &> /dev/null
systemctl start systemd-networkd &> /dev/null

netplan generate
netplan apply

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${VERT}SUCCÈS : Migration terminée !${NC}"
    echo "Vos IPs actuelles :"
    ip a | grep inet | grep global
else
    echo -e "${ROUGE}ÉCHEC : Une erreur est survenue.${NC}"
    echo "Restauration de l'ancienne configuration..."
    mv /etc/network/interfaces.old /etc/network/interfaces
    systemctl restart networking
fi
