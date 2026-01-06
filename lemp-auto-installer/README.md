# 🚀 LEMP Auto-Installer v2.0

Installation automatique ultra-professionnelle d'un serveur web LEMP (Linux, Nginx, MariaDB, PHP-FPM) sous Debian 13.

## 📋 Prérequis

- **OS:** Debian 13 (Trixie)
- **Accès:** Root
- **RAM:** 2 GB minimum
- **Disque:** 10 GB minimum
- **Réseau:** Connexion Internet active

## 🎯 Fonctionnalités

✅ Installation complète automatisée  
✅ 2 Virtual Hosts (PHP dynamique + HTML statique)  
✅ phpMyAdmin configuré  
✅ Sécurisation MariaDB  
✅ Logs détaillés  
✅ Génération fichier hosts Windows  
✅ Scripts de maintenance  

## 🚀 Installation Rapide
```bash
# 1. Aller dans le dossier
cd lemp-auto-installer

# 2. (Optionnel) Personnaliser la configuration
nano config.yaml

# 3. Lancer l'installation
sudo ./install.sh
```

## ⚙️ Configuration

Éditez `config.yaml` pour personnaliser:

- Informations personnelles (nom, formation)
- Adresse IP du serveur
- Noms de domaine des Virtual Hosts
- Mots de passe (MariaDB, phpMyAdmin)
- Composants à installer

## 🛠️ Outils de Maintenance
```bash
# Tester le serveur
./tools/test.sh

# Monitoring en temps réel
./tools/monitor.sh

# Créer une sauvegarde
./tools/backup.sh

# Désinstaller complètement
./tools/uninstall.sh
```

## 📁 Structure du Projet
```
lemp-auto-installer/
├── install.sh              # Script principal
├── config.yaml             # Configuration
├── README.md               # Documentation
├── lib/                    # Bibliothèques
│   ├── colors.sh
│   ├── logger.sh
│   ├── utils.sh
│   └── validators.sh
├── modules/                # Modules d'installation
│   ├── 01-system.sh
│   ├── 02-nginx.sh
│   ├── 03-mariadb.sh
│   ├── 04-php.sh
│   ├── 05-vhosts.sh
│   ├── 06-phpmyadmin.sh
│   ├── 07-security.sh
│   └── 08-finalize.sh
├── tools/                  # Outils
│   ├── test.sh
│   ├── backup.sh
│   ├── monitor.sh
│   └── uninstall.sh
└── output/                 # Fichiers générés
```

## 🌐 URLs de Test

Après installation (configurez votre fichier hosts d'abord):

- **Portal RH:** http://portal-rh.ing-infraFarah.lan/
- **PHP Info:** http://portal-rh.ing-infraFarah.lan/info.php
- **phpMyAdmin:** http://portal-rh.ing-infraFarah.lan/pma/
- **Site Public:** http://prod-web.innov-techFarah.com/

## 🔧 Configuration Client Windows

1. **Ouvrir Bloc-notes en Administrateur**
2. **Ouvrir:** `C:\Windows\System32\drivers\etc\hosts`
3. **Ajouter:**
```
   192.168.1.50    portal-rh.ing-infraFarah.lan
   192.168.1.50    prod-web.innov-techFarah.com
```
4. **Sauvegarder**
5. **Configurer DNS:** Paramètres réseau → DNS préféré: `8.8.8.8`

## 👤 Auteur

**Farah ELALEM**  
Formation: Big Data & AI Engineering - ISGA Marrakech  
Date: Janvier 2026

## 📄 Licence

Projet éducatif - Libre d'utilisation pour la formation
