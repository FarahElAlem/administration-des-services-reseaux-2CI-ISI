#!/bin/bash
# Validateurs

check_service_active() { systemctl is-active --quiet "$1"; }

check_port_listening() {
    local port=$1
    netstat -tlnp 2>/dev/null | grep -q ":$port " || ss -tlnp 2>/dev/null | grep -q ":$port "
}

check_package_installed() { dpkg -l | grep -q "^ii.*$1 "; }
