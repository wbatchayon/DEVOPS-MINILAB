#!/bin/bash
set -e

echo "Bootstrap VM - Configuration de base"

# Mise à jour du système
apt-get update
apt-get upgrade -y

# Installation des paquets de base
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    net-tools \
    vim \
    git

# Configuration SSH
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd

# Désactivation du swap (requis pour Kubernetes)
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Configuration des modules kernel pour Kubernetes
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Configuration sysctl
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

echo "Bootstrap terminé"