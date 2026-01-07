#!/bin/bash
# Couleurs et formatage

export COLOR_RESET='\033[0m'
export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[0;33m'
export COLOR_BLUE='\033[0;34m'
export COLOR_CYAN='\033[0;36m'
export COLOR_BRIGHT_RED='\033[1;31m'
export COLOR_BRIGHT_GREEN='\033[1;32m'
export COLOR_BRIGHT_YELLOW='\033[1;33m'
export COLOR_BRIGHT_BLUE='\033[1;34m'
export COLOR_BRIGHT_MAGENTA='\033[1;35m'
export COLOR_BRIGHT_CYAN='\033[1;36m'
export STYLE_BOLD='\033[1m'
export STYLE_DIM='\033[2m'

print_success() { echo -e "${COLOR_BRIGHT_GREEN}✅ $1${COLOR_RESET}"; }
print_error() { echo -e "${COLOR_BRIGHT_RED}❌ $1${COLOR_RESET}" >&2; }
print_warning() { echo -e "${COLOR_BRIGHT_YELLOW}⚠️  $1${COLOR_RESET}"; }
print_info() { echo -e "${COLOR_BRIGHT_BLUE}ℹ️  $1${COLOR_RESET}"; }
print_step() { echo -e "${COLOR_BRIGHT_MAGENTA}[$1/$2] 🚀 $3${COLOR_RESET}"; }
print_substep() { echo -e "  ${COLOR_CYAN}├─ ✓ $1${COLOR_RESET}"; }
print_substep_last() { echo -e "  ${COLOR_CYAN}└─ ✓ $1${COLOR_RESET}"; }

print_header() {
    echo -e "\n${COLOR_BRIGHT_CYAN}${STYLE_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_CYAN}${STYLE_BOLD}$1${COLOR_RESET}"
    echo -e "${COLOR_BRIGHT_CYAN}${STYLE_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}\n"
}

progress_bar() {
    local current=$1
    local total=$2
    local width=40
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    printf "\r  ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %3d%%" $percentage
    [ "$current" -eq "$total" ] && echo ""
}

print_banner() {
    clear
    echo -e "${COLOR_BRIGHT_CYAN}"
    cat << 'BANNER'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     ██╗     ███████╗███╗   ███╗██████╗                        ║
║     ██║     ██╔════╝████╗ ████║██╔══██╗                       ║
║     ██║     █████╗  ██╔████╔██║██████╔╝                       ║
║     ██║     ██╔══╝  ██║╚██╔╝██║██╔═══╝                        ║
║     ███████╗███████╗██║ ╚═╝ ██║██║                            ║
║     ╚══════╝╚══════╝╚═╝     ╚═╝╚═╝                            ║
║                                                               ║
║   Installation Automatique v2.0                               ║
║   Linux • Nginx • MariaDB • PHP-FPM                           ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
BANNER
    echo -e "${COLOR_RESET}"
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while ps a | awk '{print $1}' | grep -q $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

countdown() {
    local seconds=$1
    local message=${2:-"Démarrage dans"}
    for ((i=seconds; i>0; i--)); do
        printf "\r${message} ${i}s... "
        sleep 1
    done
    printf "\r%-50s\r" " "
}
