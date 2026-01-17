# Mini-Lab DevOps : Guide Complet d'Installation

Le projet consiste à déployer deux machines virtuelles sur Proxmox, puis à les transformer progressivement en un mini cluster Kubernetes, en utilisant chaque outil pour son rôle spécifique.

*Noté que le projet utilise des @IP_aléatoire x.x.x.100 pour la VM1 et x.x.x.101 pour la VM2*

## Objectif pédagogique

L’objectif de ce projet est de démontrer concrètement la différence de rôle entre :

* Vagrant → création et gestion des machines virtuelles
* Terraform → provisioning et gestion de l’infrastructure comme code
* Ansible → configuration et automatisation logicielle
* Kubernetes (K8s) → orchestration de conteneurs

Le projet doit permettre à un collègue de comprendre :

- qui fait quoi ?
- à quel moment ?
- pourquoi on ne remplace pas un outil par un autre ?

## Structure du Projet

```
devops-minilab/
├── README.md
├── vagrant/
│   ├── Vagrantfile
│   └── scripts/
│       └── bootstrap.sh
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── terraform.tfvars
│   └── outputs.tf
├── ansible/
│   ├── inventory/
│   │   └── hosts.ini
│   ├── playbooks/
│   │   ├── prepare-system.yml
│   │   ├── install-docker.yml
│   │   └── install-kubernetes.yml
│   └── roles/
│       ├── common/
│       ├── docker/
│       └── kubernetes/
├── kubernetes/
│   ├── init-master.sh
│   ├── join-worker.sh
│   └── deployments/
│       └── nginx-demo.yaml
└── scripts/
    ├── setup-all.sh
    └── cleanup-all.sh
```

## Prérequis sur ta Machine Hôte

```bash
# Installation des outils nécessaires
# Sur Ubuntu/Debian
# Ajouter le dépôt HashiCorp
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Ajouter le dépôt
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update
sudo apt install -y vagrant terraform ansible sshpass

# Installer kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Installer le provider Vagrant pour Proxmox
vagrant plugin install vagrant-proxmox
```

## Configuration Initiale

### 1. Créer la structure du projet en clonant le dêpot si le github

```bash
git clone https://wbatchayon/DEVOPS-MINILAB.git
cd DEVOPS-MINILAB
```