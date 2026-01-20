## Démarches d'Exécution

### Étape 1 : Configuration Initiale

```bash
# Éditer les fichiers avec tes credentials
nano terraform/terraform.tfvars
nano ansible/inventory/hosts.ini
```

### Étape 2 : Provisioning avec Terraform

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

**Attendre que Cloud-Init se Termine**

```bash
# Tester la connexion SSH
ssh -o StrictHostKeyChecking=no ubuntu@x.x.x.100 "echo 'Master OK'"
ssh -o StrictHostKeyChecking=no ubuntu@x.x.x.101 "echo 'Worker OK'"
```

***Note***: En cas de problème de clés SSH des VMs précédentes sont encore dans ton fichier `known_hosts`

```bash
# Supprimer les anciennes clés SSH
ssh-keygen -f ~/.ssh/known_hosts -R x.x.x.100
ssh-keygen -f ~/.ssh/known_hosts -R x.x.x.101

# Maintenant réessayer
ssh -o StrictHostKeyChecking=no ubuntu@x.x.x.100 "echo 'Master OK'"
ssh -o StrictHostKeyChecking=no ubuntu@x.x.x.101 "echo 'Worker OK'"
```
### Étape 3 : Configuration avec Ansible

```bash
cd ../ansible

# Teste Ansible
ansible -i inventory/hosts.ini k8s_cluster -m ping

# Préparation système
ansible-playbook -i inventory/hosts.ini playbooks/prepare-system.yml

# Installation Docker
ansible-playbook -i inventory/hosts.ini playbooks/install-docker.yml

# Installation Kubernetes
ansible-playbook -i inventory/hosts.ini playbooks/install-kubernetes.yml
```

### Étape 4 : Changer les hostnames des VMs

```bash
# Sur le MASTER 
ssh ubuntu@x.x.x.100

sudo hostnamectl set-hostname k8s-master
echo "127.0.0.1 k8s-master" | sudo tee -a /etc/hosts
echo "x.x.x.100 k8s-master" | sudo tee -a /etc/hosts

# Redémarrer pour appliquer
sudo reboot

# Sur le WORKER
ssh ubuntu@x.x.x.101

sudo hostnamectl set-hostname k8s-worker
echo "127.0.0.1 k8s-worker" | sudo tee -a /etc/hosts
echo "x.x.x.101 k8s-worker" | sudo tee -a /etc/hosts

# Redémarrer
sudo reboot
```

### Étape 5 : Initialisation du Cluster

```bash
# Copier le script vers le master
scp kubernetes/init-master.sh ubuntu@x.x.x.100:/tmp/

# Sur le master (x.x.x.100)
ssh ubuntu@x.x.x.100

# Copier le script vers le master
bash /tmp/init-master.sh

# Récupérer la commande join
cat /tmp/join-command.sh
```

Tu verras quelque chose comme :

```bash
sudo kubeadm join x.x.x.100:6443 --token abc123.xyz789 \
    --discovery-token-ca-cert-hash sha256:1234567890abcdef...
```

### Étape 6 : Joindre le Worker

```bash
# Sur le worker (x.x.x.101)
ssh ubuntu@x.x.x.101

# Coller la commande du join-command.sh
```

Vérifier que le Cluster est Opérationnel

```bash
# Retourner sur le master
ssh ubuntu@x.x.x.100

# Vérifier les nodes
kubectl get nodes

# Tu devrais voir :
# NAME         STATUS   ROLES           AGE   VERSION
# k8s-master   Ready    control-plane   5m    v1.28.x
# k8s-worker   Ready    <none>          2m    v1.28.x

# Attendre que les nodes soient "Ready"
watch kubectl get nodes
# Ctrl+C pour sortir
```

### Étape 7 : Déploiement Application

```bash
# Copier le fichier sur le master
scp kubernetes/deployments/nginx-demo.yaml ubuntu@x.x.x.100:/tmp/

# Se connecter au master
ssh ubuntu@x.x.x.100

# Déployer
kubectl apply -f /tmp/nginx-demo.yaml

# Vérifier les pods
kubectl get pods

# Vérifier les services
kubectl get services

# Attendre que les pods soient "Running"
watch kubectl get pods
# Ctrl+C pour sortir
```

### Étape 8 : Test de l'Application

```bash
# Accéder à nginx
curl http://x.x.x.100:30080
```

## Vérifications Finales

```bash
# Vérifier le cluster
kubectl get nodes

# Vérifier les pods
kubectl get pods -A

# Vérifier les services
kubectl get svc
```