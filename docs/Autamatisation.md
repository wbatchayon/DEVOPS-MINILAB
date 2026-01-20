# Comment Utiliser Cette Solution Complète

## Étape 1 : Rendre les scripts exécutables

```bash
chmod +x install-prerequisites.sh install-minilab.sh
```

## Étape 2 : Installer les Prérequis

```bash
./install-prerequisites.sh
```
Ce script va installer :
- Terraform
- Ansible
- Kubectl
- Vagrant
- SSHPass

## Étape 3 : Configurer les Variables

**IMPORTANT** : Édite le script `install-minilab.sh` et modifie :

```bash
PROXMOX_URL="https://TON_IP_PROXMOX:8006/api2/json"  # Change ici
PROXMOX_PASSWORD="TON_MOT_DE_PASSE"                   # Change ici
SSH_PASSWORD="votremotdepasse"                         # Change ici
etc ...
```

## Étape 4 : Lancer l'Installation Complète

```bash
./install-minilab.sh
```
Ce script va TOUT FAIRE automatiquement :
- Créer la structure du projet
- Provisionner les VMs avec Terraform
- Configurer les systèmes avec Ansible
- Installer Docker et Kubernetes
- Créer le cluster K8s
- Déployer nginx en démo


## Resume

### Ce qu'il faut savoir

Avec ce projet, tu pourras clairement comprendre :


| Outil | Action Concrète | Résultat Visible |
|-------|-----------------|------------------|
| **Terraform** | `terraform apply` | 2 VMs créées sur Proxmox |
| **Ansible** | `ansible-playbook install-docker.yml` | Docker installé sur les VMs |
| **Kubernetes** | `kubectl get nodes` | Cluster avec 2 nodes actifs |
| **Application** | `kubectl apply -f nginx-demo.yaml` | Nginx accessible sur port 30080 |

### Questions Fréquentes

* Q: Et si j'ai une erreur avec Terraform ?

    - Vérifie que l'URL Proxmox est correcte
    - Vérifie les credentials
    - Assure-toi que l'ISO Ubuntu existe dans Proxmox

* Q: Et si Ansible ne peut pas se connecter ?

    - Attends 2-3 minutes que les VMs bootent complètement
    - Vérifie que les IPs sont bien x.x.x.100-101
    - Teste avec ssh root@x.x.x.100

* Q: Comment tout détruire ?
    ```bash
    cd terraform
    terraform destroy -auto-approve
    ```

## Erreur

1. 

**Le problème :** *containerd n'est pas correctement configuré ou problème avec la version du runtime CRI.*
**Solution :** *Reconfigurer containerd*

Sur toutes les VMs (master ET worker) :

```bash
# Se connecter au master
ssh ubuntu@x.x.x.100

# Supprimer la config existante et régénérer
sudo rm /etc/containerd/config.toml
sudo containerd config default | sudo tee /etc/containerd/config.toml

# Activer SystemdCgroup
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Redémarrer containerd
sudo systemctl restart containerd

# Vérifier le statut
sudo systemctl status containerd

# Vérifier que le socket CRI fonctionne
sudo crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock version

# Sortir
exit
```

NB : Répéter les mêmes commandes pour le worker (`ssh ubuntu@x.x.x.101`)

2. 

**Problème :** *Timeout lors de l'escalade de privilèges (sudo)*
**Solution :** *Fixer le Sudo*

```bash
# connecter vous a la VM qu'il faut fixe le sudo
ssh ubuntu@x.x.x.100

# Vérifier la configuration SSH
sudo grep -i "PasswordAuthentication" /etc/ssh/sshd_config

# Vérifier sudo
sudo -l

# Vérifier le fichier sudoers
sudo cat /etc/sudoers.d/ubuntu

# Si le fichier n'existe pas ou est vide, le recréer :
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ubuntu
sudo chmod 0440 /etc/sudoers.d/ubuntu

# Changer le hostname
sudo hostnamectl set-hostname k8s-master

# Mettre à jour /etc/hosts
sudo tee -a /etc/hosts << EOF
x.x.x.100 k8s-master
x.x.x.101 k8s-worker
x.x.x.102 monitoring
EOF

# Redémarrer sshd si besoin
sudo systemctl restart ssh

# Vérifier
hostname

exit
```