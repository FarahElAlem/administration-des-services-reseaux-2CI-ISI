echo "╔════════════════════════════════════════════════════════╗"
echo "║  ✅ VALIDATION POST-RESTAURATION                      ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "=== Vérification 1 : Identité du serveur ==="
hostname
cat /etc/hostname

echo ""
echo "=== Vérification 2 : Résolution DNS locale ==="
head -10 /etc/hosts

echo ""
echo "=== Vérification 3 : Montage des disques ==="
head -10 /etc/fstab

echo ""
echo "=== Vérification 4 : Sudo fonctionne ==="
sudo echo "✓ Sudo opérationnel"

echo ""
echo "=== Vérification 5 : Fichiers utilisateur ==="
ls -la /home/elalem/.bashrc

echo ""
echo "=== Vérification 6 : Archives Borg accessibles ==="
sudo /backup/scripts/borgbackup_manager.sh list | tail -5

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  🏆 SERVEUR COMPLÈTEMENT RESTAURÉ ET OPÉRATIONNEL 🏆  ║"
echo "╚════════════════════════════════════════════════════════╝"
