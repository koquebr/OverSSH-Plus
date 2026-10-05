#!/bin/bash
clear

echo -e "\033[1;36m=====================================================\033[0m"
echo -e "\033[1;32m         OVER SSH PLUS - CONFIGURAR ROOT             \033[0m"
echo -e "\033[1;36m=====================================================\033[0m\n"

# Habilita autenticacao por senha e login de root em todos os arquivos de configuracao do SSH
sed -i 's/.*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null
sed -i 's/.*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null

grep -q "PasswordAuthentication yes" /etc/ssh/sshd_config || echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
grep -q "PermitRootLogin yes" /etc/ssh/sshd_config || echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
grep -q "KbdInteractiveAuthentication yes" /etc/ssh/sshd_config || echo "KbdInteractiveAuthentication yes" >> /etc/ssh/sshd_config 2>/dev/null

systemctl restart ssh >/dev/null 2>&1 || service ssh restart >/dev/null 2>&1

echo -e "\033[1;33mDigite a NOVA SENHA para o usuário ROOT:\033[0m"
passwd root

echo -e "\n\033[1;32m[✓] Senha do ROOT e login por senha configurados com sucesso!\033[0m\n"
sleep 2s
rm -f senharoot.sh >/dev/null 2>&1
