# Debian Netplan Migrator

Un script Bash interactif pour migrer facilement la configuration réseau de Debian (gestion via `/etc/network/interfaces`) vers **Netplan**.

Ce script est particulièrement utile pour configurer rapidement des serveurs ou des VMs (VMware, VirtualBox) avec plusieurs cartes réseaux.

## Fonctionnalités

- 📦 Installe Netplan automatiquement si nécessaire.
- 📝 Mode interactif pour définir les noms d'interfaces et les IPs.
- 🛡️ Sauvegarde automatiquement votre ancien fichier `interfaces`.
- ⚙️ Configure 1 interface en DHCP et 2 interfaces en IP Statique (modifiable).
- 🔄 Applique les changements immédiatement.

## Prérequis

- Un système Debian (10, 11, 12, 13) ou basé sur Debian.
- Accès root ou sudo.

## Utilisation

1. **Téléchargez le script** :
   ```bash
   https://github.com/FarahElAlem/Administration-des-Services-R-seaux-2CI-ISI/blob/0e119c34221fb893050cb232d5c4ad59e5048f0a/migrate-to-netplan/migrate_to_netplan.sh

