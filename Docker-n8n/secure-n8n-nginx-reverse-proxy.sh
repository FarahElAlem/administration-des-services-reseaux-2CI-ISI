#!/bin/bash

#==============================================================================
# Script de Securisation n8n avec Nginx Reverse Proxy
# Auteur: Farah Elalem
# Date: 27 Decembre 2025
#==============================================================================

readonly LOG_FILE="/var/log/n8n-security-setup.log"
readonly NGINX_CONFIG="/etc/nginx/sites-available/n8n"
readonly HTPASSWD_FILE="/etc/nginx/.htpasswd"
readonly BACKUP_DIR="$HOME/n8n-backup-$(date +%Y%m%d-%H%M%S)"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | sudo tee -a "$LOG_FILE" > /dev/null
}

print_header() {
    echo "================================================================"
    echo ""
    echo "      Securisation n8n avec Nginx Reverse Proxy"
    echo ""
    echo "================================================================"
}

print_section() {
    echo ""
    echo ">> $1"
}

print_success() {
    echo "[OK] $1"
}

print_error() {
    echo "[ERREUR] $1"
}

validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

validate_port() {
    local port=$1
    if [[ $port =~ ^[0-9]+$ ]] && [ $port -ge 1 ] && [ $port -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

backup_config() {
    print_section "Sauvegarde de la configuration actuelle"
    
    mkdir -p "$BACKUP_DIR"
    
    if [ -f "$HOME/n8n-docker/docker-compose.yml" ]; then
        cp "$HOME/n8n-docker/docker-compose.yml" "$BACKUP_DIR/"
        print_success "docker-compose.yml sauvegarde"
    fi
    
    log "Backup cree dans $BACKUP_DIR"
}

collect_information() {
    print_section "Configuration"
    
    while true; do
        read -p "Adresse IP du serveur [192.168.200.150]: " server_ip
        server_ip=${server_ip:-192.168.200.150}
        
        if validate_ip "$server_ip"; then
            print_success "IP valide: $server_ip"
            break
        else
            print_error "Format IP invalide"
        fi
    done
    
    while true; do
        read -p "Nom d utilisateur [admin]: " username
        username=${username:-admin}
        
        if [ ${#username} -ge 3 ]; then
            print_success "Utilisateur: $username"
            break
        else
            print_error "Le nom doit contenir au moins 3 caracteres"
        fi
    done
    
    while true; do
        read -s -p "Mot de passe (min 8 caracteres): " password
        echo ""
        
        if [ ${#password} -lt 8 ]; then
            print_error "Le mot de passe doit contenir au moins 8 caracteres"
            continue
        fi
        
        read -s -p "Confirmez le mot de passe: " password_confirm
        echo ""
        
        if [ "$password" = "$password_confirm" ]; then
            print_success "Mot de passe confirme"
            break
        else
            print_error "Les mots de passe ne correspondent pas"
        fi
    done
    
    while true; do
        read -p "Port Nginx [80]: " nginx_port
        nginx_port=${nginx_port:-80}
        
        if validate_port "$nginx_port"; then
            print_success "Port: $nginx_port"
            break
        else
            print_error "Port invalide"
        fi
    done
}

show_summary() {
    echo ""
    echo "================================================================"
    echo "                    RECAPITULATIF"
    echo "================================================================"
    echo ""
    echo "  Adresse IP       : $server_ip"
    echo "  Port Nginx       : $nginx_port"
    echo "  Utilisateur      : $username"
    echo "  Mot de passe     : ********"
    echo ""
    echo "  URL publique     : http://$server_ip:$nginx_port"
    echo "  URL interne      : http://localhost:5678 (ferme au public)"
    echo ""
    
    read -p "Confirmer l installation ? [o/N]: " confirm
    
    if [[ ! "$confirm" =~ ^[oOyY]$ ]]; then
        echo "Installation annulee"
        log "Installation annulee"
        exit 0
    fi
}

install_nginx() {
    print_section "Installation de Nginx"
    
    sudo apt update > /dev/null 2>&1
    sudo apt install -y nginx apache2-utils > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        print_success "Nginx installe"
        log "Nginx installe"
    else
        print_error "Echec installation Nginx"
        exit 1
    fi
}

configure_nginx() {
    print_section "Configuration Nginx"
    
    sudo tee "$NGINX_CONFIG" > /dev/null <<EOF
server {
    listen $nginx_port;
    server_name $server_ip;

    access_log /var/log/nginx/n8n-access.log;
    error_log /var/log/nginx/n8n-error.log;

    auth_basic "Acces Restreint - Innov-Alert";
    auth_basic_user_file $HTPASSWD_FILE;

    location / {
        proxy_pass http://localhost:5678;
        proxy_http_version 1.1;
        
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
    
    print_success "Configuration Nginx creee"
    log "Configuration Nginx creee"
}

create_credentials() {
    print_section "Creation identifiants"
    
    sudo htpasswd -cb "$HTPASSWD_FILE" "$username" "$password"
    sudo chmod 644 "$HTPASSWD_FILE"
    sudo chown www-data:www-data "$HTPASSWD_FILE"
    
    print_success "Identifiants crees"
    log "Utilisateur $username cree"
}

activate_site() {
    print_section "Activation site Nginx"
    
    sudo ln -sf "$NGINX_CONFIG" /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
    
    print_success "Site active"
    log "Site Nginx active"
}

test_nginx_config() {
    print_section "Test configuration Nginx"
    
    if sudo nginx -t 2>&1 | grep -q "successful"; then
        print_success "Configuration valide"
        log "Test Nginx: OK"
        return 0
    else
        print_error "Configuration invalide"
        sudo nginx -t
        exit 1
    fi
}

restart_nginx() {
    print_section "Redemarrage Nginx"
    
    sudo systemctl restart nginx
    
    if [ $? -eq 0 ]; then
        print_success "Nginx redemarre"
        log "Nginx redemarre"
    else
        print_error "Echec redemarrage Nginx"
        exit 1
    fi
}

configure_docker() {
    print_section "Reconfiguration Docker"
    
    cd /home/elalem/n8n-docker || exit 1
    
    cat > docker-compose.yml <<EOF
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n_app
    restart: always
    
    ports:
      - "127.0.0.1:5678:5678"
    
    environment:
      - N8N_HOST=$server_ip
      - TZ=Africa/Casablanca
      - N8N_SECURE_COOKIE=false
      - WEBHOOK_URL=http://$server_ip
      - N8N_LOG_LEVEL=info
    
    volumes:
      - ./n8n_data:/home/node/.n8n
EOF
    
    print_success "docker-compose.yml mis a jour"
    log "Docker Compose reconfigure"
}

restart_n8n() {
    print_section "Redemarrage n8n"
    
    cd /home/elalem/n8n-docker || exit 1
    
    sudo docker compose down
    print_success "Conteneur arrete"
    
    sudo docker compose up -d
    
    if [ $? -eq 0 ]; then
        print_success "Conteneur redemarre"
        log "n8n redemarre en mode securise"
    else
        print_error "Echec redemarrage n8n"
        exit 1
    fi
}

show_final_info() {
    echo ""
    echo "================================================================"
    echo "              INSTALLATION TERMINEE AVEC SUCCES"
    echo "================================================================"
    echo ""
    echo "INFORMATIONS D'ACCES"
    echo "  URL          : http://$server_ip:$nginx_port"
    echo "  Utilisateur  : $username"
    echo "  Mot de passe : [Celui que vous avez defini]"
    echo ""
    echo "SECURITE"
    echo "  - Reverse Proxy Nginx actif"
    echo "  - Authentification HTTP Basic"
    echo "  - n8n accessible uniquement via Nginx"
    echo "  - Port 5678 ferme au public"
    echo ""
    echo "FICHIERS"
    echo "  Nginx       : $NGINX_CONFIG"
    echo "  Credentials : $HTPASSWD_FILE"
    echo "  Docker      : $HOME/n8n-docker/docker-compose.yml"
    echo "  Sauvegarde  : $BACKUP_DIR"
    echo "  Log         : $LOG_FILE"
    echo ""
    
    log "Installation terminee avec succes"
}

main() {
    sudo touch "$LOG_FILE"
    log "=== Debut installation ==="
    
    print_header
    collect_information
    show_summary
    backup_config
    
    install_nginx
    configure_nginx
    create_credentials
    activate_site
    test_nginx_config
    restart_nginx
    
    configure_docker
    restart_n8n
    
    show_final_info
    
    log "=== Installation terminee ==="
}

main "$@"
