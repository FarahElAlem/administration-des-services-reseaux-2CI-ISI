#!/bin/bash
# Outil de monitoring temps réel

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"

while true; do
    clear
    print_banner
    print_header "MONITORING SERVEUR LEMP"
    
    echo ""
    echo -e "${COLOR_BRIGHT_CYAN}=== SERVICES ===${COLOR_RESET}"
    echo ""
    
    systemctl is-active --quiet nginx && echo -e "  ${COLOR_BRIGHT_GREEN}● Nginx${COLOR_RESET}" || echo -e "  ${COLOR_BRIGHT_RED}● Nginx (inactif)${COLOR_RESET}"
    
    PHP_VER=$(php -v 2>/dev/null | head -n1 | cut -d' ' -f2 | cut -d'.' -f1,2)
    systemctl is-active --quiet "php${PHP_VER}-fpm" && echo -e "  ${COLOR_BRIGHT_GREEN}● PHP-FPM ${PHP_VER}${COLOR_RESET}" || echo -e "  ${COLOR_BRIGHT_RED}● PHP-FPM (inactif)${COLOR_RESET}"
    
    systemctl is-active --quiet mariadb && echo -e "  ${COLOR_BRIGHT_GREEN}● MariaDB${COLOR_RESET}" || echo -e "  ${COLOR_BRIGHT_RED}● MariaDB (inactif)${COLOR_RESET}"
    
    echo ""
    echo -e "${COLOR_BRIGHT_CYAN}=== RESSOURCES ===${COLOR_RESET}"
    echo ""
    
    cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    echo -e "  CPU: ${cpu}%"
    
    mem_total=$(free -m | awk 'NR==2 {print $2}')
    mem_used=$(free -m | awk 'NR==2 {print $3}')
    mem_percent=$((mem_used * 100 / mem_total))
    echo -e "  RAM: ${mem_used}MB / ${mem_total}MB (${mem_percent}%)"
    
    disk=$(df -h / | awk 'NR==2 {print $5}')
    echo -e "  Disque: ${disk}"
    
    echo ""
    echo -e "${COLOR_BRIGHT_CYAN}=== CONNEXIONS ===${COLOR_RESET}"
    echo ""
    
    http_conn=$(netstat -an 2>/dev/null | grep ":80 " | grep ESTABLISHED | wc -l)
    echo -e "  HTTP: ${http_conn}"
    
    mysql_conn=$(netstat -an 2>/dev/null | grep ":3306 " | grep ESTABLISHED | wc -l)
    echo -e "  MySQL: ${mysql_conn}"
    
    echo ""
    echo -e "${COLOR_DIM}Actualisation: 5s (Ctrl+C pour quitter)${COLOR_RESET}"
    
    sleep 5
done
