# 🛡️ Administration des Services Réseaux - Backups Automatisés

[![Debian](https://img.shields.io/badge/Debian-13%20Trixie-red?logo=debian)](https://www.debian.org/)
[![BorgBackup](https://img.shields.io/badge/BorgBackup-1.4.0-blue)](https://www.borgbackup.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

> **Travaux Pratiques - Administration Systèmes**  
> Formation : Cycle d'ingénierie des systèmes informatiques - ISGA Marrakech  
> Auteur : Farah El Alem  
> Date : Décembre 2025

## 📖 Table des Matières

- [Vue d'ensemble](#vue-densemble)
- [Architecture](#architecture)
- [Prérequis](#prérequis)
- [Installation](#installation)
- [TP1 - Snapshots Incrémentaux (rsync)](#tp1---snapshots-incrémentaux-rsync)
- [TP2 - BorgBackup Chiffré](#tp2---borgbackup-chiffré)
- [Test de Restauration](#test-de-restauration)
- [Alertes Email](#alertes-email)
- [Automatisation](#automatisation)
- [Résultats](#résultats)
- [Ressources](#ressources)

---

## 🎯 Vue d'ensemble

Ce projet implémente une **solution complète de backup automatisé** avec deux approches complémentaires :

### TP1 : Snapshots Incrémentaux avec rsync
- ✅ Sauvegardes incrémentales avec hard-links
- ✅ Économie d'espace disque (50-70%)
- ✅ Rotation automatique (7 quotidiens, 4 hebdomadaires, 3 mensuels)
- ✅ Script autonome multi-distributions

### TP2 : BorgBackup avec Chiffrement
- ✅ Dépôt distant chiffré (AES-256)
- ✅ Déduplication au niveau des blocs (95% d'économie)
- ✅ Compression lz4 (rapide)
- ✅ Installation automatique sur serveur distant
- ✅ Alertes email automatiques

### Fonctionnalités Bonus
- 🚀 Test de restauration sous pression (< 30 min)
- 📧 Notifications email automatiques (succès/échec)
- ⏰ Automatisation complète avec cron
- 🛡️ Configuration SSH sécurisée

---

## 🏗️ Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                 serv-core-elalem01                          │
│                  (Serveur Principal)                        │
│  ┌──────────────┐         ┌──────────────────┐            │
│  │ /etc         │         │  Scripts         │            │
│  │ /home        │────────▶│  - rsync         │            │
│  │ /data        │         │  - borgbackup    │            │
│  └──────────────┘         └──────────────────┘            │
└───────────────────┬─────────────────────┬──────────────────┘
                    │                     │
                    │ rsync               │ borg + SSH
                    │                     │ (chiffré)
                    ↓                     ↓
        ┌──────────────────┐  ┌──────────────────────────┐
        │  /backup/        │  │   srv-dns02-farah        │
        │  snapshots/      │  │   192.168.10.253         │
        │                  │  │  /backup/borg-repo/      │
        │  - backup-1      │  │  (Dépôt chiffré)         │
        │  - backup-2      │  │                          │
        │  - backup-3      │  └──────────────────────────┘
        └──────────────────┘
                    │
                    └─────────▶ 📧 Alertes Gmail
```

---

## 🔧 Prérequis

### Systèmes Supportés
- ✅ Debian 12/13 (Bookworm/Trixie)
- ✅ Ubuntu 22.04+
- ✅ RHEL/CentOS 8+

### Dépendances
- `rsync` (pour TP1)
- `borgbackup` (pour TP2)
- `msmtp` + `mailutils` (pour alertes email)
- `openssh-client` (pour backups distants)

### Configuration Réseau
- Serveur source : `192.168.10.254`
- Serveur distant : `192.168.10.253`
- Port SSH : `2222`

---

## 🚀 Installation

### 1. Cloner le Repository
```bash
git clone https://github.com/FarahElAlem/Administration-des-Services-R-seaux-2CI-ISI.git
cd Administration-des-Services-R-seaux-2CI-ISI
```

### 2. Rendre les Scripts Exécutables
```bash
sudo chmod +x scripts/backup_incremental.sh
sudo chmod +x scripts/borgbackup_manager.sh
```

### 3. Créer les Répertoires
```bash
sudo mkdir -p /backup/{scripts,logs,snapshots}
sudo cp scripts/* /backup/scripts/
```

---

## 📦 TP1 - Snapshots Incrémentaux (rsync)

### Principe
Utilisation de `rsync` avec `--link-dest` pour créer des snapshots incrémentaux économes en espace.

### Caractéristiques
- **Hard-links** : Fichiers identiques partagent le même inode
- **Économie** : 50-70% d'espace par rapport à des copies complètes
- **Rotation** : Conservation de 7 quotidiens, 4 hebdomadaires, 3 mensuels

### Utilisation
```bash
# Aide
sudo /backup/scripts/backup_incremental.sh --help

# Créer un snapshot
sudo /backup/scripts/backup_incremental.sh

# Avec statistiques
sudo /backup/scripts/backup_incremental.sh --stats

# Test sans exécution
sudo /backup/scripts/backup_incremental.sh --dry-run
```

### Résultats

| Métrique | Valeur |
|----------|--------|
| **Snapshots créés** | 4 |
| **Fichiers par snapshot** | ~100 |
| **Taille théorique** | 64 KB × 4 = 256 KB |
| **Taille réelle** | 140 KB |
| **Économie** | 45% |

📸 [Voir les captures d'écran TP1](docs/TP1-rsync.md)

---

## 🔐 TP2 - BorgBackup Chiffré

### Principe
Backup distant avec chiffrement AES-256, déduplication et compression.

### Caractéristiques
- **Chiffrement** : repokey-blake2 (AES-256)
- **Déduplication** : Au niveau des blocs (chunks)
- **Compression** : lz4 (rapide)
- **Automatisation** : Installation auto sur serveur distant

### Installation et Initialisation
```bash
# Initialisation complète (une seule fois)
sudo /backup/scripts/borgbackup_manager.sh init

# Configuration des alertes email
sudo /backup/scripts/borgbackup_manager.sh setup-email
```

### Utilisation
```bash
# Créer un backup
sudo /backup/scripts/borgbackup_manager.sh backup

# Lister les archives
sudo /backup/scripts/borgbackup_manager.sh list

# Afficher le contenu d'une archive
sudo /backup/scripts/borgbackup_manager.sh show backup-2025-12-21_12-31-20

# Informations détaillées
sudo /backup/scripts/borgbackup_manager.sh info backup-2025-12-21_12-31-20

# Restaurer un fichier
sudo /backup/scripts/borgbackup_manager.sh extract backup-2025-12-21_12-31-20 etc/hostname /tmp/restore

# Rotation automatique
sudo /backup/scripts/borgbackup_manager.sh prune
```

### Performances

| Archive | Fichiers | Original | Compressé | Dédupliqué | Gain |
|---------|----------|----------|-----------|------------|------|
| **#1** | 778 | 2.20 MB | 1.04 MB | 1.02 MB | 54% |
| **#2** | 778 | 2.20 MB | 1.04 MB | **665 B** | **99.97%** |
| **#3** | 787 | 2.21 MB | 1.04 MB | **737 B** | **99.97%** |

**Total stocké** : 1.24 MB pour 3 backups complets !

📸 [Voir les captures d'écran TP2](docs/TP2-borgbackup.md)

---

## 🔥 Test de Restauration

### Scénario : Crash Simulé
**Mission** : Restaurer le serveur en moins de 30 minutes après perte de fichiers critiques.

### Fichiers Supprimés
- `/etc/hostname`
- `/etc/hosts`  
- `/etc/fstab`
- Fichiers utilisateur dans `/home/`

### Résultats

| Métrique | Objectif | Résultat | Statut |
|----------|----------|----------|--------|
| **Durée restauration** | < 30 min | ** < 3 min ** | ✅ 257× plus rapide |
| **Fichiers restaurés** | 4 | 4 | ✅ 100% |
| **Serveur opérationnel** | Oui | Oui | ✅ Succès |
```bash
⏰ Début restauration : 14:21:44
⏰ Fin restauration   : 14:24:42
⏱️  Durée totale      : 178 secondes
```

📸 [Voir le test de restauration complet](docs/Restauration.md)

---

## 📧 Alertes Email

### Configuration Automatique

Le script configure automatiquement l'envoi d'emails via Gmail :
```bash
sudo /backup/scripts/borgbackup_manager.sh setup-email
```

### Types d'Alertes

| Événement | Icône | Contenu |
|-----------|-------|---------|
| **Backup réussi** | ✅ | Nom archive, durée, statistiques |
| **Backup échoué** | ❌ | Message d'erreur, chemin des logs |
| **Rotation effectuée** | ⚠️ | Archives conservées/supprimées |

### Exemple d'Email
```
✅ BorgBackup - Backup Réussi

Archive créée avec succès !

Archive : backup-serv-core-elalem01-2025-12-21_16-03-01
Durée : 0.32 secondes

Statistiques :
- 787 fichiers sauvegardés
- Taille originale : 2.21 MB
- Compressée : 1.04 MB
- Dédupliquée : 737 B (99.97% d'économie)

---
Serveur : serv-core-elalem01
Date : Sun, 2025-12-21 16:03:03
```

📸 [Voir la configuration email](docs/Alertes-Email.md)

---

## ⏰ Automatisation

### Configuration Cron
```bash
# Éditer le crontab
sudo crontab -e
```

**Tâches configurées :**
```cron
# Backup quotidien à 2h du matin avec email
0 2 * * * /backup/scripts/borgbackup_manager.sh backup >> /backup/logs/cron-backup.log 2>&1

# Rotation hebdomadaire (dimanche à 3h) avec email
0 3 * * 0 /backup/scripts/borgbackup_manager.sh prune >> /backup/logs/cron-prune.log 2>&1
```

### Vérification
```bash
# Lister les tâches cron
sudo crontab -l

# Vérifier les logs
sudo tail -f /backup/logs/cron-backup.log
```

---

## 📊 Résultats Globaux

### Comparaison TP1 vs TP2

| Critère | TP1 (rsync) | TP2 (BorgBackup) |
|---------|-------------|------------------|
| **Chiffrement** | ❌ Non | ✅ AES-256 |
| **Compression** | ❌ Non | ✅ lz4 |
| **Déduplication** | ⚠️ Hard-links (fichiers) | ✅ Blocs (chunks) |
| **Économie d'espace** | 45-70% | 95-99% |
| **Stockage distant** | ⚠️ Possible | ✅ Natif |
| **Vérification intégrité** | ❌ Manuel | ✅ Automatique |
| **Vitesse restauration** | ⚡ Très rapide | ⚡ Très rapide |

### Enseignements

1. **rsync** = Idéal pour backups locaux rapides
2. **BorgBackup** = Solution professionnelle complète
3. **Alertes email** = Monitoring proactif essentiel
4. **Tests réguliers** = "Une sauvegarde non testée n'existe pas"

---

## 📚 Ressources

### Documentation Officielle
- [BorgBackup Documentation](https://borgbackup.readthedocs.io/)
- [rsync Manual](https://download.samba.org/pub/rsync/rsync.1)
- [msmtp Guide](https://marlam.de/msmtp/)

### Scripts
- [backup_incremental.sh](scripts/backup_incremental.sh)
- [borgbackup_manager.sh](scripts/borgbackup_manager.sh)

### Guides Détaillés
- [TP1 - Guide Complet](docs/TP1-rsync.md)
- [TP2 - Guide Complet](docs/TP2-borgbackup.md)
- [Test Restauration](docs/Restauration.md)
- [Configuration Email](docs/Alertes-Email.md)

---

## 🤝 Contribution

Farah El Alem - [@FarahElAlem](https://github.com/FarahElAlem)

Formation : Cycle d'ingénierie des systèmes informatiques  
Institution : ISGA Marrakech  
Année : 2024-2025

---

## 📄 License

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

---

**Made with ❤️ by Farah El Alem**
