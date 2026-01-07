#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Système de logs
# ═══════════════════════════════════════════════════════════

# Variables globales pour les logs
LOG_FILE=""
LOG_SECTION=""

# ═══════════════════════════════════════════════════════════
# Initialiser le système de logs
# ═══════════════════════════════════════════════════════════

init_log() {
    local log_dir="${OUTPUT_DIR:-./output}/logs"
    mkdir -p "$log_dir"
    
    LOG_FILE="${log_dir}/installation-$(date +%Y%m%d-%H%M%S).log"
    
    # Créer le fichier de log
    {
        echo "═══════════════════════════════════════════════════════════"
        echo "LEMP Auto-Installer - Log d'installation"
        echo "═══════════════════════════════════════════════════════════"
        echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "User: $(whoami)"
        echo "Hostname: $(hostname)"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
    } > "$LOG_FILE"
    
    log_info "Initialisation des logs: $LOG_FILE"
}

# ═══════════════════════════════════════════════════════════
# Fonctions de logging
# ═══════════════════════════════════════════════════════════

log_info() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $message" >> "$LOG_FILE"
}

log_success() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $message" >> "$LOG_FILE"
}

log_warning() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $message" >> "$LOG_FILE"
}

log_error() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $message" >> "$LOG_FILE"
}

log_command() {
    local command="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CMD] $command" >> "$LOG_FILE"
}

# ═══════════════════════════════════════════════════════════
# Sections de logs
# ═══════════════════════════════════════════════════════════

save_log_section() {
    LOG_SECTION="$1"
    {
        echo ""
        echo "───────────────────────────────────────────────────────────"
        echo "Section: $LOG_SECTION"
        echo "───────────────────────────────────────────────────────────"
    } >> "$LOG_FILE"
}

end_log_section() {
    local section="$1"
    {
        echo "───────────────────────────────────────────────────────────"
        echo "Fin de section: $section"
        echo ""
    } >> "$LOG_FILE"
}

# ═══════════════════════════════════════════════════════════
# Sauvegarder une commande et sa sortie
# ═══════════════════════════════════════════════════════════

log_exec() {
    local command="$*"
    log_command "$command"
    
    {
        echo "Sortie:"
        eval "$command" 2>&1 | tee -a "$LOG_FILE"
        echo "Code retour: ${PIPESTATUS[0]}"
    } >> "$LOG_FILE" 2>&1
}

# ═══════════════════════════════════════════════════════════
# Finaliser les logs
# ═══════════════════════════════════════════════════════════

finalize_log() {
    {
        echo ""
        echo "═══════════════════════════════════════════════════════════"
        echo "Fin de l'installation"
        echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "═══════════════════════════════════════════════════════════"
    } >> "$LOG_FILE"
    
    log_info "Log finalisé: $LOG_FILE"
}
