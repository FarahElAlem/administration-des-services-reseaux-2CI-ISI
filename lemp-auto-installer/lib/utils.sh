#!/bin/bash
# Fonctions utilitaires

command_exists() { command -v "$1" >/dev/null 2>&1; }

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Ce script doit être exécuté en tant que root"
        exit 1
    fi
}

check_debian_version() {
    [ ! -f /etc/os-release ] && return 1
    source /etc/os-release
    [ "$ID" != "debian" ] && return 1
    print_success "Debian $VERSION_ID détecté"
    return 0
}

check_internet() {
    for host in "8.8.8.8" "1.1.1.1"; do
        ping -c 1 -W 2 "$host" >/dev/null 2>&1 && return 0
    done
    return 1
}

check_disk_space() {
    local required_mb=${1:-2000}
    local available_mb=$(df / | awk 'NR==2 {print int($4/1024)}')
    [ "$available_mb" -lt "$required_mb" ] && return 1
    return 0
}

check_memory() {
    local available_mb=$(free -m | awk 'NR==2 {print $7}')
    [ "$available_mb" -lt 512 ] && print_warning "Mémoire faible"
    return 0
}

create_backup() {
    local file="$1"
    local backup_dir="${2:-/root/lemp-backups}"
    [ ! -f "$file" ] && return 0
    mkdir -p "$backup_dir"
    cp "$file" "$backup_dir/$(basename $file).$(date +%Y%m%d_%H%M%S).bak"
}

timer_start() { TIMER_START=$(date +%s); }

timer_end() {
    local duration=$(($(date +%s) - TIMER_START))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    [ $minutes -gt 0 ] && echo "${minutes}m ${seconds}s" || echo "${seconds}s"
}

detect_network_interfaces() {
    print_info "Interfaces réseau détectées:"
    ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$' | while read iface; do
        local ip=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
        [ -n "$ip" ] && echo "  • $iface: $ip"
    done
}
