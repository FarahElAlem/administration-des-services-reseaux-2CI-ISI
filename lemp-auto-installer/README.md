# 🚀 LEMP Auto-Installer v2.0

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell_Script-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Debian](https://img.shields.io/badge/Debian-13-red.svg)](https://www.debian.org/)
[![Status](https://img.shields.io/badge/Status-Production-brightgreen.svg)]()

> Installation automatique et professionnelle d'un stack LEMP (Linux, Nginx, MariaDB, PHP-FPM) sur Debian 13

![LEMP Stack](https://raw.githubusercontent.com/username/lemp-auto-installer/main/docs/images/banner.png)

---

## ✨ Fonctionnalités

- ✅ **Installation automatisée** complète du stack LEMP
- 🎨 **Templates personnalisables** pour pages web et configurations
- 🔧 **Configuration via YAML** - Simple et lisible
- 🌐 **Multi Virtual Hosts** - Sites PHP et statiques
- 🗄️ **phpMyAdmin** intégré avec interface web
- 📊 **Tests automatiques** après installation
- 🔐 **Sécurisation** automatique (MariaDB, Nginx)
- 📝 **Logs détaillés** et rapports d'installation
- 🔄 **Outils de gestion** (backup, désinstallation, monitoring)

---

## 📋 Table des matières

- [Prérequis](#prérequis)
- [Installation rapide](#installation-rapide)
- [Configuration](#configuration)
- [Utilisation](#utilisation)
- [Documentation](#documentation)
- [Captures d'écran](#captures-décran)
- [Contribution](#contribution)
- [Licence](#licence)

---

## 🔧 Prérequis

- **OS**: Debian 13 (Trixie)
- **Privilèges**: Root ou sudo
- **RAM**: 512 MB minimum (1 GB recommandé)
- **Disque**: 2 GB d'espace libre
- **Réseau**: Connexion Internet active

---

## ⚡ Installation rapide

### 1. Cloner le dépôt
```bash
git clone https://github.com/FarahElAlem/lemp-auto-installer.git
cd lemp-auto-installer
```

### 2. Configurer
```bash
# Éditer le fichier de configuration
nano config.yaml
```

Modifier au minimum :
- `user.firstname` et `user.lastname`
- `server.ip` (votre adresse IP)
- `security.mariadb_root_password`

### 3. Installer
```bash
# Rendre TOUS les .sh exécutables récursivement
find . -type f -name "*.sh" -exec chmod +x {} \;
sudo ./install.sh
```

⏱️ **Durée**: ~2-3 minutes

---

## 🎯 Installation - Étapes détaillées

<details>
<summary>Cliquez pour voir les étapes détaillées</summary>

### Étape 1 : Préparation
```bash
# Mettre à jour le système
sudo apt update && sudo apt upgrade -y

# Cloner le projet
git clone https://github.com/FarahElAlem/lemp-auto-installer.git
cd lemp-auto-installer

# Rendre le script exécutable
chmod +x install.sh
```

### Étape 2 : Configuration
```bash
# Copier et éditer la configuration
cp config.yaml.example config.yaml
nano config.yaml
```

### Étape 3 : Lancer l'installation
```bash
sudo ./install.sh
```

Le script va :
1. ✅ Vérifier les prérequis
2. 📦 Installer Nginx, MariaDB, PHP 8.4
3. 🌐 Créer les Virtual Hosts
4. 🗄️ Configurer phpMyAdmin
5. 🔐 Sécuriser le système
6. 🧪 Exécuter les tests

### Étape 4 : Configuration du fichier hosts Windows
```
# Éditer C:\Windows\System32\drivers\etc\hosts
192.168.1.50    portal-rh.ing-infraFarah.lan
192.168.1.50    prod-web.innov-techFarah.com
```

### Étape 5 : Accéder aux sites

- 🏠 Portal RH: http://portal-rh.ing-infraFarah.lan/
- 🐘 PHP Info: http://portal-rh.ing-infraFarah.lan/info.php
- 🗄️ phpMyAdmin: http://portal-rh.ing-infraFarah.lan/pma/
- 🌍 Site Public: http://prod-web.innov-techFarah.com/

</details>

---

## ⚙️ Configuration

### Fichier `config.yaml`
```yaml
# Informations personnelles
user:
  firstname: "Farah"
  lastname: "EL ALEM"
  formation: "ISGA Marrakech"
  email: "farah.el1996@gmail.com"

# Configuration serveur
server:
  hostname: "srv-web01"
  ip: "192.168.1.50"
  interface: "ens37"
  timezone: "Africa/Casablanca"

# Virtual Hosts
vhosts:
  portal_rh:
    enabled: true
    domain: "portal-rh.ing-infraFarah.lan"
    type: "php"
    root: "/var/www/portal-rh.ing-infraFarah.lan/html"
    
  prod_web:
    enabled: true
    domain: "prod-web.innov-techFarah.com"
    type: "static"
    root: "/var/www/prod-web.innov-techFarah.com/html"

# Sécurité
security:
  mariadb_root_password: "VotreMotDePasseIci!"
```

📖 [Guide de configuration complet](docs/CONFIGURATION.md)

---

## 🛠️ Utilisation

### Commandes principales
```bash
# Installation
sudo ./install.sh

# Tests
sudo ./tools/test.sh

# Désinstallation
sudo ./tools/uninstall.sh

# Backup
sudo ./tools/backup.sh

# Monitoring
sudo ./tools/monitor.sh

# Régénérer les pages
sudo ./tools/regenerate-pages.sh
```

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [📖 Installation](docs/INSTALLATION.md) | Guide d'installation détaillé |
| [🏗️ Architecture](docs/ARCHITECTURE.md) | Architecture technique du projet |
| [⚙️ Configuration](docs/CONFIGURATION.md) | Guide de configuration |
| [🔧 Variables](docs/VARIABLES.md) | Documentation des variables |
| [🎨 Templates](docs/TEMPLATES.md) | Guide des templates |
| [🐛 Troubleshooting](docs/TROUBLESHOOTING.md) | Résolution de problèmes |
| [📡 API](docs/API.md) | Documentation des fonctions |

---

## 📸 Captures d'écran

### Menu principal

![Menu principal](docs/images/menu.png)

### Installation en cours

![Installation](docs/images/installation.png)

### Portal RH

![Portal RH](docs/images/portal-rh.png)

### phpMyAdmin

![phpMyAdmin](docs/images/phpmyadmin.png)

---

## 🏗️ Architecture
```
lemp-auto-installer/
├── install.sh              # Script principal
├── config.yaml             # Configuration
├── lib/                    # Bibliothèques
│   ├── colors.sh          # Couleurs et affichage
│   ├── logger.sh          # Système de logs
│   ├── utils.sh           # Fonctions utilitaires
│   ├── validators.sh      # Validations
│   └── templating.sh      # Gestion des templates
├── modules/                # Modules d'installation
│   ├── 00-network.sh      # Configuration réseau
│   ├── 01-system.sh       # Préparation système
│   ├── 02-nginx.sh        # Installation Nginx
│   ├── 03-mariadb.sh      # Installation MariaDB
│   ├── 04-php.sh          # Installation PHP
│   ├── 05-vhosts.sh       # Virtual Hosts
│   ├── 06-phpmyadmin.sh   # phpMyAdmin
│   ├── 07-security.sh     # Sécurisation
│   └── 08-finalize.sh     # Finalisation
├── templates/              # Templates personnalisables
│   ├── nginx/             # Configs Nginx
│   ├── html/              # Pages web
│   └── phpmyadmin/        # Config phpMyAdmin
└── tools/                  # Outils de gestion
    ├── test.sh            # Tests
    ├── backup.sh          # Backup
    ├── uninstall.sh       # Désinstallation
    ├── monitor.sh         # Monitoring
    └── regenerate-pages.sh # Régénération pages
```

---

## 🔍 Technologies utilisées

| Technologie | Version | Utilisation |
|-------------|---------|-------------|
| **Debian** | 13 (Trixie) | Système d'exploitation |
| **Nginx** | 1.22+ | Serveur web |
| **MariaDB** | 11.8+ | Base de données |
| **PHP-FPM** | 8.4 | Interpréteur PHP |
| **phpMyAdmin** | 5.2+ | Interface de gestion BDD |
| **Bash** | 5.2+ | Scripts d'automatisation |

---

## 📊 Statistiques du projet

- 📝 **~3500 lignes de code** Bash
- 📁 **18 fichiers** de modules
- 🎨 **6 templates** personnalisables
- 🛠️ **5 outils** de gestion
- 📚 **7 documents** de documentation

---

## 🤝 Contribution

Les contributions sont les bienvenues ! 

### Comment contribuer ?

1. Fork le projet
2. Créer une branche (`git checkout -b feature/AmazingFeature`)
3. Commit vos changements (`git commit -m 'Add: Amazing Feature'`)
4. Push vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

📖 Voir [CONTRIBUTING.md](CONTRIBUTING.md) pour plus de détails.

---

## 🐛 Signaler un bug

Trouvé un bug ? [Créer une issue](https://github.com/username/lemp-auto-installer/issues/new)

---

## 📝 Changelog

Voir [CHANGELOG.md](CHANGELOG.md) pour l'historique des versions.

---

## 👤 Auteur

**Farah ELALEM**

- 🎓 Formation: ISGA Marrakech
- 📧 Email: farah.el1996@gmail.com
- 🔗 LinkedIn: [votre-profil](https://www.linkedin.com/in/farah-el-alem/)
- 💻 GitHub: [@votre-username](https://github.com/FarahElAlem)

---

## 📄 Licence

Ce projet est sous licence MIT - voir le fichier [LICENSE](LICENSE) pour plus de détails.

---

## 🙏 Remerciements

- [Nginx Documentation](https://nginx.org/en/docs/)
- [MariaDB Knowledge Base](https://mariadb.com/kb/en/)
- [PHP Documentation](https://www.php.net/docs.php)
- [Debian Wiki](https://wiki.debian.org/)

---

## ⭐ Soutenez le projet

Si ce projet vous a été utile, n'hésitez pas à lui donner une ⭐ !

---

<p align="center">
  Fait avec ❤️ par <a href="https://github.com/FarahElAlem">Farah ELALEM</a>
</p>
