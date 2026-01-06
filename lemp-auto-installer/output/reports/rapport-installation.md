# 📊 RAPPORT D'INSTALLATION LEMP STACK

**Date :** 2026-01-05 21:28:20
**Étudiante :** Farah EL ALEM
**Formation :** ISGA Marrakech
**Serveur :** srv-web01 (192.168.1.50)

---

## ✅ Stack Installée

| Composant | Version | État |
|-----------|---------|------|
| Nginx | 1.26.3 | ✅ |
| PHP-FPM | 8.4 | ✅ |
| MariaDB | 15.2 | ✅ |
| phpMyAdmin | Installé | ✅ |

---

## 🌐 Virtual Hosts

### 1. Portal RH (PHP)
- **URL :** http://portal-rh.ing-infraFarah.lan/
- **PHP Info :** http://portal-rh.ing-infraFarah.lan/info.php
- **phpMyAdmin :** http://portal-rh.ing-infraFarah.lan/pma/

### 2. Site Public (Statique)
- **URL :** http://prod-web.innov-techFarah.com/

---

## 🔐 Connexions

**MariaDB / phpMyAdmin :**
- Utilisateur : root
- Mot de passe : MariaDB2026!

---

## 📁 Fichiers Importants

- Config Portal RH : /etc/nginx/sites-available/portal-rh.conf
- Config Prod Web : /etc/nginx/sites-available/prod-web.conf
- Logs Nginx : /var/log/nginx/
- Fichier hosts Windows : /home/elalem/lemp-auto-installer/output/configs/hosts-windows.txt

---

**Rapport généré automatiquement par LEMP Auto-Installer v2.0**
