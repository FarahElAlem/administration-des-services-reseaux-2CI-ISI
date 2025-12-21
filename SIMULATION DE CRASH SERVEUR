echo "╔════════════════════════════════════════════════════════╗"
echo "║  🔥 SIMULATION DE CATASTROPHE - CRASH SERVEUR 🔥      ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "⏰ DÉBUT DU CRASH : $(date +%H:%M:%S)"
echo ""

# Backup de sécurité (au cas où)
sudo mkdir -p /tmp/emergency_backup
sudo cp -r /etc/hostname /etc/hosts /etc/fstab /tmp/emergency_backup/ 2>/dev/null

echo "=== FICHIERS CRITIQUES AVANT LE CRASH ==="
echo "✓ /etc/hostname :"
cat /etc/hostname
echo "✓ /etc/hosts (5 premières lignes) :"
head -5 /etc/hosts
echo "✓ /etc/fstab (premières lignes) :"
head -5 /etc/fstab

echo ""
echo "🔥🔥🔥 CRASH EN COURS 🔥🔥🔥"
echo ""

# SUPPRIMER LES FICHIERS CRITIQUES
sudo rm -f /etc/hostname
sudo rm -f /etc/hosts
sudo rm -f /etc/fstab

# Supprimer aussi des fichiers dans /home
sudo rm -rf /home/elalem/.bashrc 2>/dev/null
sudo rm -rf /home/elalem/.profile 2>/dev/null

echo "=== VÉRIFICATION APRÈS LE CRASH ==="
echo "❌ /etc/hostname :"
cat /etc/hostname 2>&1
echo ""
echo "❌ /etc/hosts :"
cat /etc/hosts 2>&1
echo ""
echo "❌ /etc/fstab :"
cat /etc/fstab 2>&1

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  💀 CATASTROPHE ! LE SERVEUR EST EN PANNE ! 💀        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "⏰ FIN DU CRASH : $(date +%H:%M:%S)"
echo ""
