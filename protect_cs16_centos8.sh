#!/bin/bash

echo "=== Instalando dependências ==="
dnf install -y iptables-services ipset tcpdump

systemctl stop firewalld
systemctl disable firewalld

systemctl enable iptables
systemctl start iptables

iptables -F
iptables -X
iptables -Z

# IPSET

ipset destroy autoban 2>/dev/null
ipset create autoban hash:ip timeout 600 -exist

ipset destroy whitelist 2>/dev/null
ipset create whitelist hash:ip -exist

ipset add whitelist 177.54.151.114 -exist
ipset add whitelist 177.54.151.234 -exist

# BASE

iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP

iptables -A INPUT -m set --match-set whitelist src -j ACCEPT
iptables -A INPUT -m set --match-set autoban src -j DROP

# ICMP

iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# CS UDP SMALL PACKETS

iptables -A INPUT -p udp --dport 27010:27999 -m length --length 0:12 -m hashlimit --hashlimit 80/sec --hashlimit-burst 160 --hashlimit-mode srcip --hashlimit-name len_small -j ACCEPT
iptables -A INPUT -p udp --dport 27010:27999 -m length --length 0:12 -j SET --add-set autoban src

# CS UDP LEN 23

iptables -A INPUT -p udp --dport 27010:27999 -m length --length 23 -m hashlimit --hashlimit 120/sec --hashlimit-burst 250 --hashlimit-mode srcip --hashlimit-name len23 -j ACCEPT
iptables -A INPUT -p udp --dport 27010:27999 -m length --length 23 -j SET --add-set autoban src

# GETCHALLENGE

iptables -A INPUT -p udp --dport 27010:27999 -m string --string "getchallenge" --algo bm -m hashlimit --hashlimit 80/sec --hashlimit-burst 160 --hashlimit-mode srcip --hashlimit-name challenge -j ACCEPT
iptables -A INPUT -p udp --dport 27010:27999 -m string --string "getchallenge" --algo bm -j SET --add-set autoban src

# FLOOD UDP

iptables -A INPUT -p udp --dport 27010:27999 -m hashlimit --hashlimit 250/sec --hashlimit-burst 500 --hashlimit-mode srcip --hashlimit-name udp_flood -j ACCEPT
iptables -A INPUT -p udp --dport 27010:27999 -j SET --add-set autoban src

# PORTAS TCP

for port in 22 2222 21 2121 80 443 8080 8888 3306 12679 38151; do
iptables -A INPUT -p tcp --dport $port -j ACCEPT
done

iptables -A INPUT -p tcp --dport 40110:40210 -j ACCEPT

# DNS SAÍDA

iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# CS FINAL

iptables -A INPUT -p udp --dport 27010:27999 -j ACCEPT

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

service iptables save

echo "================================="
echo "Proteção CS 1.6 ativa"
echo "Autoban: 600 segundos"
echo "================================="
