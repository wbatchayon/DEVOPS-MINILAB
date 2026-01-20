## Monitoring

### Étape 1 : Modifier Terraform pour Ajouter la VM Monitoring

```bash
cd ~/devops-minilab/terraform

# Backup de l'ancien fichier
cp main.tf main.tf.backup

# Éditer main.tf
nano main.tf
```

**Ajoute cette ressource APRÈS les VMs master et worker :**

```yml
# VM Monitoring
resource "proxmox_virtual_environment_vm" "monitoring" {
  name        = "monitoring-tf"
  node_name   = var.proxmox_node
  vm_id       = 102
  
  clone {
    vm_id = 9000
  }
  
  cpu {
    cores = 2
  }
  
  memory {
    dedicated = 4096
  }
  
  disk {
    datastore_id = var.proxmox_storage
    interface    = "scsi0"
    size         = 40  # Plus d'espace pour les métriques
  }
  
  network_device {
    bridge = var.proxmox_bridge
  }
  
  initialization {
    ip_config {
      ipv4 {
        address = "x.x.x.102/24"
        gateway = "x.x.x.1"
      }
    }
    
    user_account {
      username = "ubuntu"
      password = "ubuntu"
      keys     = []
    }
  }
}
```

**Appliquer les changements Terraform**

```bash
cd ~/devops-minilab/terraform

terraform plan
terraform apply

# Attendre 3 minutes que la VM démarre
sleep 180

# Nettoyer known_hosts
ssh-keygen -f ~/.ssh/known_hosts -R x.x.x.100
ssh-keygen -f ~/.ssh/known_hosts -R x.x.x.101
ssh-keygen -f ~/.ssh/known_hosts -R x.x.x.102

# Tester la connexion
ssh -o StrictHostKeyChecking=no ubuntu@x.x.x.102 "echo 'Monitoring VM OK'"
```

### Étape 2 : Mettre à Jour l'Inventaire Ansible

```bash
cd ~/devops-minilab/ansible

nano inventory/hosts.ini
```
**Remplace tout par :**

```ini
# complete avec l'@ip de monitoring
[monitoring]
x.x.x.102
```

**Tester la connexion**

```bash
ansible -i inventory/hosts.ini monitoring -m ping
```

### Étape 3 : Créer le Playbook d'Installation de la Stack Monitoring

```bash 
cd ~/devops-minilab/ansible

cat > playbooks/install-monitoring-stack.yml << 'EOF'
---
- name: Installation de la Stack de Monitoring
  hosts: monitoring
  become: yes
  tasks:
    - name: Mise à jour du système
      apt:
        update_cache: yes
        upgrade: dist

    - name: Installation des dépendances
      apt:
        name:
          - curl
          - wget
          - apt-transport-https
          - software-properties-common
          - adduser
          - libfontconfig1
        state: present

    - name: Créer les utilisateurs système
      user:
        name: "{{ item }}"
        system: yes
        shell: /bin/false
        create_home: no
      loop:
        - prometheus
        - alertmanager
        - node_exporter

    - name: Créer les répertoires Prometheus
      file:
        path: "{{ item }}"
        state: directory
        owner: prometheus
        group: prometheus
        mode: '0755'
      loop:
        - /etc/prometheus
        - /var/lib/prometheus
        - /etc/alertmanager
        - /var/lib/alertmanager

    # ==========================================
    # PROMETHEUS
    # ==========================================
    - name: Télécharger Prometheus
      unarchive:
        src: https://github.com/prometheus/prometheus/releases/download/v2.48.0/prometheus-2.48.0.linux-amd64.tar.gz
        dest: /tmp
        remote_src: yes

    - name: Installer les binaires Prometheus
      copy:
        src: "/tmp/prometheus-2.48.0.linux-amd64/{{ item }}"
        dest: /usr/local/bin/
        mode: '0755'
        remote_src: yes
      loop:
        - prometheus
        - promtool

    - name: Copier les fichiers de config Prometheus
      copy:
        src: "/tmp/prometheus-2.48.0.linux-amd64/{{ item }}"
        dest: /etc/prometheus/
        owner: prometheus
        group: prometheus
        remote_src: yes
      loop:
        - consoles
        - console_libraries

    - name: Configuration Prometheus
      copy:
        dest: /etc/prometheus/prometheus.yml
        owner: prometheus
        group: prometheus
        content: |
          global:
            scrape_interval: 15s
            evaluation_interval: 15s

          alerting:
            alertmanagers:
              - static_configs:
                  - targets:
                    - localhost:9093

          rule_files:
            # - "rules.yml"

          scrape_configs:
            - job_name: 'prometheus'
              static_configs:
                - targets: ['localhost:9090']

            - job_name: 'k8s-master'
              static_configs:
                - targets: ['x.x.x.100:9100']

            - job_name: 'k8s-worker'
              static_configs:
                - targets: ['x.x.x.101:9100']

            - job_name: 'monitoring-server'
              static_configs:
                - targets: ['localhost:9100']

    - name: Créer le service systemd Prometheus
      copy:
        dest: /etc/systemd/system/prometheus.service
        content: |
          [Unit]
          Description=Prometheus
          Wants=network-online.target
          After=network-online.target

          [Service]
          User=prometheus
          Group=prometheus
          Type=simple
          ExecStart=/usr/local/bin/prometheus \
            --config.file=/etc/prometheus/prometheus.yml \
            --storage.tsdb.path=/var/lib/prometheus/ \
            --web.console.templates=/etc/prometheus/consoles \
            --web.console.libraries=/etc/prometheus/console_libraries

          [Install]
          WantedBy=multi-user.target

    # ==========================================
    # GRAFANA
    # ==========================================
    - name: Ajouter la clé GPG Grafana
      apt_key:
        url: https://apt.grafana.com/gpg.key
        state: present

    - name: Ajouter le dépôt Grafana
      apt_repository:
        repo: deb https://apt.grafana.com stable main
        state: present

    - name: Installer Grafana
      apt:
        name: grafana
        state: present
        update_cache: yes

    # ==========================================
    # ALERTMANAGER
    # ==========================================
    - name: Télécharger Alertmanager
      unarchive:
        src: https://github.com/prometheus/alertmanager/releases/download/v0.26.0/alertmanager-0.26.0.linux-amd64.tar.gz
        dest: /tmp
        remote_src: yes

    - name: Installer les binaires Alertmanager
      copy:
        src: "/tmp/alertmanager-0.26.0.linux-amd64/{{ item }}"
        dest: /usr/local/bin/
        mode: '0755'
        remote_src: yes
      loop:
        - alertmanager
        - amtool

    - name: Configuration Alertmanager
      copy:
        dest: /etc/alertmanager/alertmanager.yml
        owner: alertmanager
        group: alertmanager
        content: |
          global:
            resolve_timeout: 5m

          route:
            group_by: ['alertname']
            group_wait: 10s
            group_interval: 10s
            repeat_interval: 1h
            receiver: 'web.hook'

          receivers:
            - name: 'web.hook'
              webhook_configs:
                - url: 'http://127.0.0.1:5001/'

          inhibit_rules:
            - source_match:
                severity: 'critical'
              target_match:
                severity: 'warning'
              equal: ['alertname', 'dev', 'instance']

    - name: Créer le service systemd Alertmanager
      copy:
        dest: /etc/systemd/system/alertmanager.service
        content: |
          [Unit]
          Description=Alertmanager
          Wants=network-online.target
          After=network-online.target

          [Service]
          User=alertmanager
          Group=alertmanager
          Type=simple
          ExecStart=/usr/local/bin/alertmanager \
            --config.file=/etc/alertmanager/alertmanager.yml \
            --storage.path=/var/lib/alertmanager/

          [Install]
          WantedBy=multi-user.target

    # ==========================================
    # DÉMARRAGE DES SERVICES
    # ==========================================
    - name: Recharger systemd
      systemd:
        daemon_reload: yes

    - name: Démarrer et activer les services
      systemd:
        name: "{{ item }}"
        state: started
        enabled: yes
      loop:
        - prometheus
        - grafana-server
        - alertmanager

    - name: Afficher les URLs d'accès
      debug:
        msg:
          - " Stack de monitoring installée !"
          - " Prometheus : http://x.x.x.102:9090"
          - " Grafana    : http://x.x.x.102:3000 (admin/admin)"
          - " Alertmanager : http://x.x.x.102:9093"
EOF
```

### Étape 4 : Installer Node Exporter sur TOUTES les VMs

```bash
cat > playbooks/install-node-exporter.yml << 'EOF'
---
- name: Installation de Node Exporter
  hosts: all
  become: yes
  tasks:
    - name: Créer l'utilisateur node_exporter
      user:
        name: node_exporter
        system: yes
        shell: /bin/false
        create_home: no

    - name: Télécharger Node Exporter
      unarchive:
        src: https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
        dest: /tmp
        remote_src: yes

    - name: Installer le binaire Node Exporter
      copy:
        src: /tmp/node_exporter-1.7.0.linux-amd64/node_exporter
        dest: /usr/local/bin/
        mode: '0755'
        remote_src: yes

    - name: Créer le service systemd Node Exporter
      copy:
        dest: /etc/systemd/system/node_exporter.service
        content: |
          [Unit]
          Description=Node Exporter
          Wants=network-online.target
          After=network-online.target

          [Service]
          User=node_exporter
          Group=node_exporter
          Type=simple
          ExecStart=/usr/local/bin/node_exporter

          [Install]
          WantedBy=multi-user.target

    - name: Démarrer Node Exporter
      systemd:
        name: node_exporter
        state: started
        enabled: yes
        daemon_reload: yes

    - name: Vérifier Node Exporter
      uri:
        url: "http://localhost:9100/metrics"
        status_code: 200
      register: result
      retries: 3
      delay: 5

    - name: Afficher le statut
      debug:
        msg: "Node Exporter installé sur {{ inventory_hostname }}"
EOF
```

### Étape 5 : Exécuter les Playbooks

```bash
cd ~/devops-minilab/ansible

# 1. Installer Node Exporter sur TOUTES les VMs
echo "Installation de Node Exporter..."
ansible-playbook -i inventory/hosts.ini playbooks/install-node-exporter.yml

# 2. Installer la stack de monitoring
echo "Installation de la stack de monitoring..."
ansible-playbook -i inventory/hosts.ini playbooks/install-monitoring-stack.yml
```

### Étape 6 : Accéder aux Interfaces Web

**Prometheus**

```bash
# Depuis ton navigateur
http://x.x.x.102:9090

# Vérifier les targets
# Status > Targets
# Tu devrais voir les 3 VMs avec Node Exporter
```

**Grafana**

```bash
# Accès
http://x.x.x.102:3000

# Login : admin
# Password : admin
# (Il te demandera de changer le mot de passe)

# Configurer Grafana

# 1- Ajouter Prometheus comme DataSource :

# Configuration → Data Sources → Add data source
# Sélectionner Prometheus
# URL : http://localhost:9090
# Cliquer Save & Test


# 2- Importer un Dashboard :

# Create → Import
# Dashboard ID : 1860 (Node Exporter Full)
# Cliquer Load
# Sélectionner Prometheus datasource
# Cliquer Import
```

**Alertmanager**

```bash
http://x.x.x.102:9093
```