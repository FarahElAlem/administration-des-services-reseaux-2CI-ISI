#!/bin/bash
# Outil de sauvegarde

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"

BACKUP_DIR="/root/lemp-backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

print_banner
print_header "BACKUP DU SERVEUR LEMP"

print_info "Répertoire: $BACKUP_DIR"
echo ""

print_info "Sauvegarde des configurations..."
mkdir -p "$BACKUP_DIR/configs"
cp -r /etc/nginx/sites-available "$BACKUP_DIR/configs/" 2>/dev/null
cp -r /etc/nginx/sites-enabled "$BACKUP_DIR/configs/" 2>/dev/null
cp /etc/hosts "$BACKUP_DIR/configs/" 2>/dev/null
print_success "Configurations sauvegardées"

print_info "Sauvegarde des sites web..."
mkdir -p "$BACKUP_DIR/www"
cp -r /var/www/* "$BACKUP_DIR/www/" 2>/dev/null
print_success "Sites web sauvegardés"

print_info "Sauvegarde des bases de données..."
mkdir -p "$BACKUP_DIR/databases"

MARIADB_PASS=$(grep "mariadb_root_password:" "$SCRIPT_DIR/config.yaml" | cut -d'"' -f2)
if [ -n "$MARIADB_PASS" ]; then
    mysqldump -u root -p"$MARIADB_PASS" --all-databases > "$BACKUP_DIR/databases/all-databases.sql" 2>/dev/null
    [ $? -eq 0 ] && print_success "Bases de données sauvegardées" || print_error "Échec backup BDD"
else
    print_warning "Mot de passe non trouvé"
fi

print_info "Compression..."
cd "$(dirname "$BACKUP_DIR")"
tar -czf "backup-$(basename $BACKUP_DIR).tar.gz" "$(basename $BACKUP_DIR)" 2>/dev/null
rm -rf "$BACKUP_DIR"

ARCHIVE="$(dirname $BACKUP_DIR)/backup-$(basename $BACKUP_DIR).tar.gz"
SIZE=$(du -h "$ARCHIVE" | cut -f1)

echo ""
print_header "BACKUP TERMINÉ"
echo ""
print_success "Fichier: $ARCHIVE"
print_success "Taille: $SIZE"
echo ""
