# 📁 Templates LEMP Auto-Installer

Ce dossier contient tous les templates utilisés par le script d'installation.

## Structure
```
templates/
├── nginx/              # Configurations Nginx
│   ├── vhost-php.conf.template
│   └── vhost-static.conf.template
├── html/               # Pages web
│   ├── portal-rh.html.template
│   ├── site-public.html.template
│   └── info.php.template
├── phpmyadmin/         # Config phpMyAdmin
│   └── config.inc.php.template
├── php/                # Config PHP
│   └── pool.conf.template
├── mysql/              # Config MariaDB
│   └── my.cnf.template
└── hosts-windows.txt.template
```

## Variables disponibles

Les templates utilisent la syntaxe `{{VARIABLE}}` qui est remplacée lors de l'installation.

### Variables globales
- `{{STUDENT_FIRSTNAME}}` - Prénom de l'étudiant
- `{{STUDENT_LASTNAME}}` - Nom de l'étudiant
- `{{STUDENT_FORMATION}}` - Formation
- `{{SERVER_HOSTNAME}}` - Nom du serveur
- `{{SERVER_IP}}` - Adresse IP du serveur
- `{{INSTALL_DATE}}` - Date d'installation

### Variables Virtual Hosts
- `{{VHOST_PORTAL_DOMAIN}}` - Domaine Portal RH
- `{{VHOST_PROD_DOMAIN}}` - Domaine Site Public
- `{{DOMAIN}}` - Domaine générique
- `{{ROOT}}` - Racine web
- `{{NAME}}` - Nom du VHost

### Variables techniques
- `{{PHP_VERSION}}` - Version PHP (ex: 8.4)
- `{{BLOWFISH_SECRET}}` - Secret phpMyAdmin
- `{{POOL_NAME}}` - Nom du pool PHP-FPM

## Personnalisation

Pour personnaliser les templates:

1. Modifiez le fichier `.template` souhaité
2. Utilisez `{{VARIABLE}}` pour les valeurs dynamiques
3. Relancez l'installation

## Exemple

Avant (template):
```html
<h1>Bienvenue {{STUDENT_FIRSTNAME}} !</h1>
```

Après (fichier généré):
```html
<h1>Bienvenue Farah !</h1>
```
