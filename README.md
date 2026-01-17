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

### 2. Préparer l'ISO Ubuntu sur Proxmox et Créer un Template Propre (ex ubuntu)

**Sur ton interface Proxmox :**

1. Va dans `pve` → `Shell` où en CLI sur ta machine hôte avec `ssh root@TON_IP_PROXMOX`

2. Créer le script
    ```bash
    cat > create-k8s-template.sh << 'EOFSCRIPT'
    #!/bin/bash
    set -e

    VMID=9000
    TEMPLATE_NAME="ubuntu-2404-k8s"
    STORAGE="local-lvm"

    echo "Téléchargement de l'image Ubuntu Cloud..."
    wget -O /tmp/ubuntu-24.04.img https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img

    echo "Création du cloud-init personnalisé..."
    mkdir -p /var/lib/vz/snippets
    cat > /var/lib/vz/snippets/k8s-prep.yaml << 'EOF'
    #cloud-config
    users:
      - name: ubuntu
        passwd: $6$rounds=4096$saltsalt$lQzrUCM8RVqK8E5R7jlLfB5K.Jg.1O0F9p5R8L5K8L5K8L5K8L5K8L
        lock_passwd: false
        sudo: ALL=(ALL) NOPASSWD:ALL
        shell: /bin/bash
        groups: users, admin

    ssh_pwauth: true
    disable_root: false

    package_update: true
    package_upgrade: true
    packages:
      - qemu-guest-agent
      - openssh-server
      - curl
      - wget
      - vim
      - net-tools

    runcmd:
      - systemctl enable qemu-guest-agent
      - systemctl start qemu-guest-agent
      - echo "ubuntu:ubuntu" | chpasswd
      - sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
      - sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
      - sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
      - sed -i 's/PubkeyAuthentication no/PubkeyAuthentication yes/' /etc/ssh/sshd_config
      - systemctl restart sshd
      - echo "Cloud-init completed" > /tmp/cloud-init-done

    final_message: "Le système est prêt. SSH disponible avec ubuntu/ubuntu"
    EOF

    echo "Création de la VM..."
    qm create $VMID \
      --name $TEMPLATE_NAME \
      --memory 2048 \
      --cores 2 \
      --net0 virtio,bridge=vmbr0

    echo "Import du disque..."
    qm importdisk $VMID /tmp/ubuntu-24.04.img $STORAGE

    echo "Configuration du disque..."
    qm set $VMID \
      --scsihw virtio-scsi-pci \
      --scsi0 $STORAGE:vm-$VMID-disk-0

    echo "Configuration Cloud-Init..."
    qm set $VMID \
      --ide2 $STORAGE:cloudinit \
      --boot c \
      --bootdisk scsi0 \
      --serial0 socket \
      --vga serial0

    echo "Configuration utilisateur de base..."
    qm set $VMID \
      --ciuser ubuntu \
      --cipassword ubuntu \
      --ipconfig0 ip=dhcp

    echo "Activation de l'agent..."
    qm set $VMID --agent enabled=1

    echo "Ajout du script cloud-init personnalisé..."
    qm set $VMID --cicustom "user=local:snippets/k8s-prep.yaml"

    echo "Conversion en template..."
    qm template $VMID

    echo "Nettoyage..."
    rm -f /tmp/ubuntu-24.04.img

    echo ""
    echo "Template $VMID créé avec succès !"
    echo ""
    echo "Vérification de la configuration :"
    qm config $VMID | grep -E "agent|cicustom|ciuser"
    echo ""
    EOFSCRIPT
    ```

3. Éxecuter le script
    ```bash
    chmod +x create-k8s-template.sh
    ./create-k8s-template.sh
    ```