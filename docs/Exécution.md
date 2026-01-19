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