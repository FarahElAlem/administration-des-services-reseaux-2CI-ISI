#!/bin/bash
# Module 00: Configuration Réseau - Appel du script de migration

module_network_configure() {
    print_header "🌐 CONFIGURATION RÉSEAU"
    
    # Appeler directement le script de migration
    if [ -f "$SCRIPT_DIR/tools/migrate-to-netplan.sh" ]; then
        "$SCRIPT_DIR/tools/migrate-to-netplan.sh"
    else
        print_error "Script de migration introuvable"
        return 1
    fi
    
    return 0
}
