#!/bin/bash
#====================================================
# OVER SSH PLUS - TCP TWEAKER & GOOGLE BBR
#====================================================
clear

C_RESET="\033[0m"
C_CYAN="\033[1;36m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"
C_WHITE="\033[1;37m"

echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
echo -e "${C_GREEN}     TCP TWEAKER & OTIMIZADOR DE REDE GOOGLE BBR    ${C_RESET}"
echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n"

# Verifica se BBR já está ativo
bbr_active=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -i bbr)
tweaker_active=$(grep -c "^#SSHPLUS_TCP_BBR" /etc/sysctl.conf 2>/dev/null || echo 0)

if [[ "$tweaker_active" -ge 1 ]] || [[ -n "$bbr_active" ]]; then
    echo -e "${C_GREEN}[✓] Otimização TCP e Google BBR já estão ATIVADOS no servidor!${C_RESET}\n"
    echo -e "${C_WHITE}Congestion Control Atual: ${C_YELLOW}$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)${C_RESET}"
    echo -e "${C_WHITE}Fila de Pacotes Atual:    ${C_YELLOW}$(sysctl -n net.core.default_qdisc 2>/dev/null)${C_RESET}\n"
    
    echo -ne "${C_YELLOW}Deseja restaurar as configurações padrão de rede? [s/N]: ${C_WHITE}"
    read -e -i "n" resposta0
    if [[ "$resposta0" =~ ^[sS]$ ]]; then
        # Remove bloco
        sed -i '/#SSHPLUS_TCP_BBR/,/#END_SSHPLUS_TCP_BBR/d' /etc/sysctl.conf 2>/dev/null
        sed -i '/#PH56/,+8d' /etc/sysctl.conf 2>/dev/null
        sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf 2>/dev/null
        sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf 2>/dev/null
        
        sysctl -w net.ipv4.tcp_congestion_control=cubic >/dev/null 2>&1
        sysctl -p /etc/sysctl.conf >/dev/null 2>&1
        echo -e "\n${C_GREEN}[✓] Configurações de rede restauradas com sucesso!${C_RESET}\n"
        sleep 2s
        exit 0
    else
        exit 0
    fi
fi

echo -e "${C_WHITE}O algoritmo de congestionamento ${C_GREEN}Google BBR${C_WHITE} (Bottleneck Bandwidth and RTT)${C_RESET}"
echo -e "${C_WHITE}melhora substancialmente o fluxo de dados em conexões 4G/5G, reduzindo o ping${C_RESET}"
echo -e "${C_WHITE}e aumentando a velocidade de streaming (YouTube/Netflix/IPTV) e downloads.${C_RESET}\n"

echo -ne "${C_GREEN}Deseja ativar as otimizações TCP BBR agora? [S/n]: ${C_WHITE}"
read -e -i "s" resposta
if [[ "$resposta" =~ ^[sS]$ ]]; then
    echo -e "\n${C_CYAN}[+] Aplicando configurações avançadas de kernel...${C_RESET}"

    # Carrega módulo BBR caso não esteja no kernel
    modprobe tcp_bbr >/dev/null 2>&1
    echo "tcp_bbr" >> /etc/modules-load.d/bbr.conf 2>/dev/null || echo "tcp_bbr" >> /etc/modules 2>/dev/null

    # Remove regras antigas para evitar duplicidade
    sed -i '/#SSHPLUS_TCP_BBR/,/#END_SSHPLUS_TCP_BBR/d' /etc/sysctl.conf 2>/dev/null
    sed -i '/#PH56/,+8d' /etc/sysctl.conf 2>/dev/null
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf 2>/dev/null
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf 2>/dev/null

    # Adiciona parâmetros otimizados
    cat << 'EOF' >> /etc/sysctl.conf

#SSHPLUS_TCP_BBR
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432
net.core.rmem_default = 1048576
net.core.wmem_default = 1048576
net.core.optmem_max = 2048576
net.core.netdev_max_backlog = 50000
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 65536 33554432
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.ip_local_port_range = 1024 65535
#END_SSHPLUS_TCP_BBR
EOF

    sysctl -p /etc/sysctl.conf >/dev/null 2>&1

    echo -e "${C_GREEN}[✓] Google BBR e Otimizações de Rede ATIVADOS com sucesso!${C_RESET}"
    echo -e "${C_WHITE}Congestion Control: ${C_YELLOW}$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)${C_RESET}"
    echo -e "${C_WHITE}Queue Discipline:    ${C_YELLOW}$(sysctl -n net.core.default_qdisc 2>/dev/null)${C_RESET}\n"
    sleep 2s
else
    echo -e "\n${C_RED}[!] Operação cancelada pelo usuário.${C_RESET}\n"
fi
