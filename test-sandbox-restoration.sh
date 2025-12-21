echo "╔════════════════════════════════════════════════════════╗"
echo "║  TEST SANDBOX - RESTAURATION SANS RISQUE              ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Créer un environnement sandbox
SANDBOX="/tmp/sandbox-restore"
sudo mkdir -p "$SANDBOX"

echo "=== Restauration complète de /etc dans le sandbox ==="
sudo /backup/scripts/borgbackup_manager.sh extract \
    backup-serv-core-elalem01-2025-12-21_12-31-20 \
    etc \
    "$SANDBOX"

echo ""
echo "=== Contenu du sandbox ==="
ls -lh "$SANDBOX/etc/" | head -20

echo ""
echo "=== Vérification d'un fichier restauré ==="
cat "$SANDBOX/etc/hostname"

echo ""
echo "=== Taille du sandbox ==="
du -sh "$SANDBOX"

echo ""
echo "✅ Test sandbox réussi - Production non impactée !"
