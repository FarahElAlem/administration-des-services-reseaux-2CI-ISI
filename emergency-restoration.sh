echo "╔════════════════════════════════════════════════════════╗"
echo "║  🚑 RESTAURATION D'URGENCE EN COURS 🚑                ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "⏰ DÉBUT RESTAURATION : $(date +%H:%M:%S)"
DEBUT=$(date +%s)
echo ""

# Archive à restaurer
ARCHIVE="backup-serv-core-elalem01-2025-12-21_12-31-20"

echo "=== 1/4 - Restauration de /etc/hostname ==="
sudo /backup/scripts/borgbackup_manager.sh extract \
    "$ARCHIVE" \
    etc/hostname \
    /tmp/restore
sudo cp /tmp/restore/etc/hostname /etc/hostname
echo "✓ /etc/hostname restauré"
cat /etc/hostname

echo ""
echo "=== 2/4 - Restauration de /etc/hosts ==="
sudo /backup/scripts/borgbackup_manager.sh extract \
    "$ARCHIVE" \
    etc/hosts \
    /tmp/restore
sudo cp /tmp/restore/etc/hosts /etc/hosts
echo "✓ /etc/hosts restauré (5 premières lignes)"
head -5 /etc/hosts

echo ""
echo "=== 3/4 - Restauration de /etc/fstab ==="
sudo /backup/scripts/borgbackup_manager.sh extract \
    "$ARCHIVE" \
    etc/fstab \
    /tmp/restore
sudo cp /tmp/restore/etc/fstab /etc/fstab
echo "✓ /etc/fstab restauré"
head -5 /etc/fstab

echo ""
echo "=== 4/4 - Restauration de /home/elalem/.bashrc ==="
sudo /backup/scripts/borgbackup_manager.sh extract \
    "$ARCHIVE" \
    home/elalem/.bashrc \
    /tmp/restore 2>/dev/null
sudo cp /tmp/restore/home/elalem/.bashrc /home/elalem/.bashrc 2>/dev/null
sudo chown elalem:elalem /home/elalem/.bashrc 2>/dev/null
echo "✓ /home/elalem/.bashrc restauré"

echo ""
FIN=$(date +%s)
DUREE=$((FIN - DEBUT))
echo "╔════════════════════════════════════════════════════════╗"
echo "║  ✅ RESTAURATION TERMINÉE AVEC SUCCÈS ! ✅            ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "⏰ FIN RESTAURATION : $(date +%H:%M:%S)"
echo "⏱️  DURÉE TOTALE : ${DUREE} secondes"
echo ""

if [ $DUREE -lt 1800 ]; then
    echo "🏆 OBJECTIF ATTEINT ! Restauration en moins de 30 minutes !"
else
    echo "⚠️ Restauration terminée mais a dépassé 30 minutes"
fi

echo ""
echo "=== VÉRIFICATION FINALE ==="
echo "✓ Hostname :"
hostname
echo "✓ Sudo fonctionne maintenant :"
sudo echo "Sudo OK !"
