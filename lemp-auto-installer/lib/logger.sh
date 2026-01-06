#!/bin/bash
# Système de logging avancé

LOG_FILE="${LOG_FILE:-/var/log/lemp-install.log}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"
VERBOSE="${VERBOSE:-true}"

declare -A LOG_LEVELS=([DEBUG]=0 [INFO]=1 [WARNING]=2 [ERROR]=3 [CRITICAL]=4)

init_logger() {
    local log_dir=$(dirname "$LOG_FILE")
    mkdir -p "$log_dir" 2>/dev/null || LOG_FILE="/tmp/lemp-install.log"
    : > "$LOG_FILE" || { LOG_FILE="/tmp/lemp-install.log"; : > "$LOG_FILE"; }
    
    log_info "═══════════════════════════════════════════════════════════"
    log_info "LEMP Auto-Installer - Session démarrée"
    log_info "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "Utilisateur: $(whoami)"
    log_info "═══════════════════════════════════════════════════════════"
}

_log() {
    local level=$1; shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [ ${LOG_LEVELS[$level]} -ge ${LOG_LEVELS[$LOG_LEVEL]} ]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
}

log_info() { _log "INFO" "$@"; }
log_error() { _log "ERROR" "$@"; }
log_warning() { _log "WARNING" "$@"; }

log_command() {
    local description="$1"; shift
    log_info "Exécution: $description"
    if $@ >> "$LOG_FILE" 2>&1; then
        log_info "✓ $description: Succès"
        return 0
    else
        log_error "✗ $description: Échec"
        return 1
    fi
}

save_log_section() { log_info "═══ Début: $1 ═══"; }
end_log_section() { log_info "═══ Fin: $1 ═══"; }
