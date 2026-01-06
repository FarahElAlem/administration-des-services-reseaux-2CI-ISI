#!/bin/bash
# ==============================================================================
# Nom du script : migrate_to_netplan.sh
# Description   : Automatise la migration de /etc/network/interfaces vers Netplan
#                 sur Debian (10, 11, 12, 13) - VERSION COMPLETE
# Auteur        : Farah El Alem
# Date          : 2025
# ==============================================================================

# Couleurs pour la lisibilite
VERT='\033[0;32m'
JAUNE='\033[1;33m'
ROUGE='\033[0;31m'
BLEU='\033[0;34m'
NC='\033[0m' # No Color

# 1. Verification root
if [ "$EUID" -ne 0 ]; then
  echo -e "${ROUGE}Erreur : Ce script doit etre lance avec sudo ou en root.${NC}"
  exit 1
fi

clear
echo -e "${VERT}==================================================${NC}"
echo -e "${VERT}   MIGRATION AUTOMATISEE VERS NETPLAN (DEBIAN)    ${NC}"
echo -e "${VERT}                                                  ${NC}"
echo -e "${VERT}==================================================${NC}"
echo ""

# 2. Verification et installation de Netplan
echo -e "${JAUNE}[1/8] Verification de l'installation de Netplan...${NC}"

# Ignorer les erreurs de depots pour l'instant
apt update -qq 2>/dev/null || echo -e "${JAUNE}Avertissement: Probleme avec apt update (ignore)${NC}"

if ! command -v netplan &> /dev/null; then
    echo "Installation de netplan.io en cours..."
    apt install -y netplan.io 2>/dev/null || {
        echo -e "${ROUGE}Impossible d'installer netplan. Verifiez vos depots.${NC}"
        exit 1
    }
else
    echo -e "${VERT}Netplan est deja installe.${NC}"
fi

# 3. Configuration interactive
echo ""
echo -e "${JAUNE}[2/8] Configuration des interfaces${NC}"
echo "Appuyez sur Entree pour accepter la valeur par defaut entre crochets [ ]."
echo ""

# Interface Principale (souvent DHCP pour management)
read -p "Nom de l'interface principale (DHCP) [ens33] : " INT_MAIN
INT_MAIN=${INT_MAIN:-ens33}

# Interface 2 (Statique)
read -p "Nom de la 2eme interface [ens37] : " INT_2
INT_2=${INT_2:-ens37}

# Boucle de validation pour IP_2
while true; do
    read -p "IP pour $INT_2 avec masque CIDR (ex: 192.168.1.100/24) : " IP_2
    IP_2=${IP_2:-192.168.1.100/24}
    
    # Validation basique du format IP/CIDR
    if [[ $IP_2 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        echo -e "${VERT}Format valide : $IP_2${NC}"
        break
    else
        echo -e "${ROUGE}Format invalide! Utilisez le format IP/masque (ex: 192.168.1.100/24)${NC}"
    fi
done

# Interface 3 (Statique)
read -p "Nom de la 3eme interface [ens38] : " INT_3
INT_3=${INT_3:-ens38}

# Boucle de validation pour IP_3
while true; do
    read -p "IP pour $INT_3 avec masque CIDR (ex: 172.16.2.100/24) : " IP_3
    IP_3=${IP_3:-172.16.2.100/24}
    
    # Validation basique du format IP/CIDR
    if [[ $IP_3 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        echo -e "${VERT}Format valide : $IP_3${NC}"
        break
    else
        echo -e "${ROUGE}Format invalide! Utilisez le format IP/masque (ex: 172.16.2.100/24)${NC}"
    fi
done

# 4. Recapitulatif avant application
echo ""
echo -e "${JAUNE}[3/8] Recapitulatif de la configuration${NC}"
echo "=========================================="
echo "Interface 1 : $INT_MAIN (DHCP)"
echo "Interface 2 : $INT_2 - IP: $IP_2"
echo "Interface 3 : $INT_3 - IP: $IP_3"
echo "=========================================="
echo ""
read -p "Confirmer cette configuration ? (o/N) : " CONFIRM

if [[ ! $CONFIRM =~ ^[oOyY]$ ]]; then
    echo -e "${ROUGE}Operation annulee par l'utilisateur.${NC}"
    exit 0
fi

# 5. Sauvegarde de l'ancienne configuration
echo ""
echo -e "${JAUNE}[4/8] Sauvegarde et desactivation de ifupdown${NC}"
if [ -f /etc/network/interfaces ]; then
    BACKUP_NAME="/etc/network/interfaces.backup_$(date +%F_%H-%M-%S)"
    cp /etc/network/interfaces "$BACKUP_NAME"
    mv /etc/network/interfaces /etc/network/interfaces.old
    echo -e "${VERT}Backup cree : $BACKUP_NAME${NC}"
else
    echo "Fichier interfaces non trouve, passage a la suite."
fi

# Desactivation des anciens services
systemctl disable networking &> /dev/null
systemctl stop networking &> /dev/null

# 6. Nettoyage des anciennes configurations systemd-networkd
echo ""
echo -e "${JAUNE}[5/8] Nettoyage des anciennes configurations systemd-networkd${NC}"

# Sauvegarder et supprimer les anciens fichiers .network
if [ -d /etc/systemd/network ]; then
    NETWORKD_FILES=$(ls /etc/systemd/network/*.network 2>/dev/null)
    if [ -n "$NETWORKD_FILES" ]; then
        echo "Anciennes configurations trouvees, sauvegarde en cours..."
        mkdir -p /root/networkd_backup_$(date +%F_%H-%M-%S)
        cp -r /etc/systemd/network/*.network /root/networkd_backup_$(date +%F_%H-%M-%S)/ 2>/dev/null
        rm -f /etc/systemd/network/*.network
        echo -e "${VERT}Anciennes configurations nettoyees.${NC}"
    else
        echo "Aucune ancienne configuration trouvee."
    fi
fi

# 7. Generation du fichier YAML
echo ""
echo -e "${JAUNE}[6/8] Generation de la configuration Netplan${NC}"
CONFIG_FILE="/etc/netplan/01-netcfg.yaml"

# Sauvegarde de l'ancien fichier netplan s'il existe
if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "${CONFIG_FILE}.backup_$(date +%F_%H-%M-%S)"
fi

# Supprimer tous les anciens fichiers netplan
rm -f /etc/netplan/*.yaml 2>/dev/null

# Creer le nouveau fichier avec les bonnes permissions
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

# Appliquer les bonnes permissions immediatement
chmod 600 "$CONFIG_FILE"

echo -e "${VERT}Fichier $CONFIG_FILE genere avec permissions correctes (600).${NC}"
echo ""
echo "Contenu du fichier :"
echo "-------------------"
cat "$CONFIG_FILE"
echo "-------------------"
echo ""

# Validation de la syntaxe YAML
echo -e "${JAUNE}Validation de la syntaxe du fichier YAML...${NC}"
if netplan generate 2>&1 | grep -qi error; then
    echo -e "${ROUGE}ERREUR : Le fichier YAML contient des erreurs!${NC}"
    echo "Restauration de l'ancienne configuration..."
    if [ -f /etc/network/interfaces.old ]; then
        mv /etc/network/interfaces.old /etc/network/interfaces
        systemctl enable networking
        systemctl restart networking
    fi
    exit 1
else
    echo -e "${VERT}Syntaxe YAML valide.${NC}"
fi

# 8. Nettoyage des anciennes IPs sur les interfaces
echo ""
echo -e "${JAUNE}[7/8] Nettoyage des anciennes adresses IP${NC}"

# Flush les IPs sur les interfaces statiques
echo "Nettoyage de l'interface $INT_2..."
ip addr flush dev $INT_2 2>/dev/null || echo "Interface $INT_2 non trouvee (ignoré)"

echo "Nettoyage de l'interface $INT_3..."
ip addr flush dev $INT_3 2>/dev/null || echo "Interface $INT_3 non trouvee (ignoré)"

sleep 2

# 9. Application avec test de securite
echo ""
echo -e "${JAUNE}[8/8] Application de la configuration Netplan${NC}"

# Activation du backend systemd-networkd
systemctl enable systemd-networkd &> /dev/null
systemctl restart systemd-networkd

# Petit delai pour laisser le service demarrer
sleep 2

# Generer la config
netplan generate

echo ""
echo -e "${BLEU}Application de la configuration avec test de securite...${NC}"
echo -e "${JAUNE}Si la connexion fonctionne, appuyez sur ENTREE dans les 120 secondes.${NC}"
echo -e "${JAUNE}Sinon, la configuration sera annulee automatiquement.${NC}"
echo ""

# Utiliser netplan try pour la securite
if netplan try 2>&1; then
    echo ""
    echo -e "${VERT}========================================${NC}"
    echo -e "${VERT}   SUCCES : Migration terminee !${NC}"
    echo -e "${VERT}========================================${NC}"
    echo ""
    echo "Configuration reseau actuelle :"
    echo "-------------------------------"
    ip -brief addr show | grep -v lo
    echo ""
    
    # Verification finale des IPs
    echo -e "${BLEU}Verification finale des interfaces :${NC}"
    echo "------------------------------------"
    IP_INT2=$(ip -4 addr show $INT_2 | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' || echo "NON CONFIGUREE")
    IP_INT3=$(ip -4 addr show $INT_3 | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' || echo "NON CONFIGUREE")
    
    echo "$INT_2 : $IP_INT2 (attendu: $IP_2)"
    echo "$INT_3 : $IP_INT3 (attendu: $IP_3)"
    
    if [[ "$IP_INT2" == "$IP_2" ]] && [[ "$IP_INT3" == "$IP_3" ]]; then
        echo -e "${VERT}✓ Toutes les IPs sont correctes!${NC}"
    else
        echo -e "${JAUNE}⚠ Les IPs ne correspondent pas. Redemarrage necessaire...${NC}"
        echo ""
        read -p "Voulez-vous redemarrer maintenant ? (o/N) : " REBOOT
        if [[ $REBOOT =~ ^[oOyY]$ ]]; then
            echo "Redemarrage dans 3 secondes..."
            sleep 3
            reboot
        else
            echo -e "${JAUNE}Veuillez redemarrer manuellement: sudo reboot${NC}"
        fi
    fi
    
    echo ""
    echo -e "${VERT}Configuration Netplan appliquee avec succes!${NC}"
    echo "Fichier de configuration : $CONFIG_FILE"
    [ -n "$BACKUP_NAME" ] && echo "Sauvegarde disponible : $BACKUP_NAME"
    
else
    echo ""
    echo -e "${ROUGE}ECHEC : Une erreur est survenue lors de l'application.${NC}"
    echo "Restauration de l'ancienne configuration..."
    
    if [ -f /etc/network/interfaces.old ]; then
        mv /etc/network/interfaces.old /etc/network/interfaces
        systemctl enable networking
        systemctl restart networking
        echo -e "${JAUNE}Ancienne configuration restauree.${NC}"
    fi
    exit 1
fi

# Nettoyage optionnel
echo ""
read -p "Voulez-vous supprimer les fichiers de sauvegarde ? (o/N) : " CLEANUP
if [[ $CLEANUP =~ ^[oOyY]$ ]]; then
    rm -f /etc/network/interfaces.old
    rm -rf /root/networkd_backup_* 2>/dev/null
    echo -e "${VERT}Fichiers de sauvegarde supprimes.${NC}"
fi

echo ""
echo -e "${VERT}========================================${NC}"
echo -e "${VERT}  Script termine avec succes !${NC}"
echo -e "${VERT}========================================${NC}"
echo ""
echo -e "${BLEU}Prochaines etapes :${NC}"
echo "1. Verifiez la connectivite reseau"
echo "2. Si necessaire, redemarrez : sudo reboot"
echo ""

