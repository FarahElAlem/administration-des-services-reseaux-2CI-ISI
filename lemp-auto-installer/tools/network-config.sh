#!/bin/bash
# Outil de configuration réseau standalone

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/logger.sh"
source "$SCRIPT_DIR/lib/utils.sh"

check_root

init_logger
timer_start

source "$SCRIPT_DIR/modules/00-network.sh"
module_network_configure

echo ""
print_success "Configuration terminée en $(timer_end)"
