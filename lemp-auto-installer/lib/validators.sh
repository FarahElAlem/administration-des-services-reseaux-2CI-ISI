#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Fonctions de validation
# ═══════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════
# Valider une adresse IP
# ═══════════════════════════════════════════════════════════

validate_ip() {
    local ip="$1"
    
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if [ $i -gt 255 ]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════
# Valider un nom de domaine
# ═══════════════════════════════════════════════════════════

validate_domain() {
    local domain="$1"
    
    if [[ $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 0
    else
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════
# Valider un email
# ═══════════════════════════════════════════════════════════

validate_email() {
    local email="$1"
    
    if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════
# Valider un port
# ═══════════════════════════════════════════════════════════

validate_port() {
    local port="$1"
    
    if [[ $port =~ ^[0-9]+$ ]] && [ $port -ge 1 ] && [ $port -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════
# Valider un mot de passe (force)
# ═══════════════════════════════════════════════════════════

validate_password_strength() {
    local password="$1"
    local min_length="${2:-8}"
    
    # Longueur minimale
    if [ ${#password} -lt $min_length ]; then
        return 1
    fi
    
    # Au moins une majuscule, une minuscule, un chiffre
    if [[ ! $password =~ [A-Z] ]] || [[ ! $password =~ [a-z] ]] || [[ ! $password =~ [0-9] ]]; then
        return 1
    fi
    
    return 0
}

# ═══════════════════════════════════════════════════════════
# Valider un chemin absolu
# ═══════════════════════════════════════════════════════════

validate_absolute_path() {
    local path="$1"
    
    if [[ $path =~ ^/ ]]; then
        return 0
    else
        return 1
    fi
}
