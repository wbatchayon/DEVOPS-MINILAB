#!/bin/bash
set -e

echo "Initialisation du Master Kubernetes"

# Initialisation du cluster
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=x.x.x.100

# Configuration kubectl pour root
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Installation du CNI (Flannel)
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Generation de la commande join
echo "Commande pour joindre le worker :"
kubeadm token create --print-join-command > /tmp/join-command.sh
cat /tmp/join-command.sh

echo "Master initialisé avec succès"