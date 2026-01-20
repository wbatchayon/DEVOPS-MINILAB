## Règles d'Alerte

**Créons quelques règles d'alerte basiques pour tester :**

```bash
cd ~/devops-minilab/ansible


cat > playbooks/configure-prometheus-alerts.yml << 'EOF'
---
- name: Configuration des alertes Prometheus
  hosts: monitoring
  become: yes
  tasks:
    - name: Créer le fichier de règles d'alerte
      copy:
        dest: /etc/prometheus/alert_rules.yml
        owner: prometheus
        group: prometheus
        content: |
          groups:
            - name: node_alerts
              interval: 30s
              rules:
                # Alerte si un node est down
                - alert: InstanceDown
                  expr: up == 0
                  for: 1m
                  labels:
                    severity: critical
                  annotations:
                    summary: "Instance {% raw %}{{ $labels.instance }}{% endraw %} down"
                    description: "{% raw %}{{ $labels.instance }}{% endraw %} of job {% raw %}{{ $labels.job }}{% endraw %} has been down for more than 1 minute."

                # Alerte si CPU > 80%
                - alert: HighCPUUsage
                  expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
                  for: 2m
                  labels:
                    severity: warning
                  annotations:
                    summary: "High CPU usage on {% raw %}{{ $labels.instance }}{% endraw %}"
                    description: "CPU usage is above 80% (current value: {% raw %}{{ $value }}{% endraw %}%)"

                # Alerte si mémoire > 85%
                - alert: HighMemoryUsage
                  expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
                  for: 2m
                  labels:
                    severity: warning
                  annotations:
                    summary: "High memory usage on {% raw %}{{ $labels.instance }}{% endraw %}"
                    description: "Memory usage is above 85% (current value: {% raw %}{{ $value }}{% endraw %}%)"

                # Alerte si disque > 80%
                - alert: HighDiskUsage
                  expr: (node_filesystem_size_bytes{fstype!="tmpfs"} - node_filesystem_free_bytes{fstype!="tmpfs"}) / node_filesystem_size_bytes{fstype!="tmpfs"} * 100 > 80
                  for: 2m
                  labels:
                    severity: warning
                  annotations:
                    summary: "High disk usage on {% raw %}{{ $labels.instance }}{% endraw %}"
                    description: "Disk usage is above 80% on {% raw %}{{ $labels.mountpoint }}{% endraw %} (current value: {% raw %}{{ $value }}{% endraw %}%)"

    - name: Mettre à jour la configuration Prometheus pour inclure les règles
      lineinfile:
        path: /etc/prometheus/prometheus.yml
        regexp: '^rule_files:'
        line: 'rule_files:'
        state: present

    - name: Ajouter le fichier de règles
      lineinfile:
        path: /etc/prometheus/prometheus.yml
        insertafter: '^rule_files:'
        line: '  - "alert_rules.yml"'
        state: present

    - name: Redémarrer Prometheus
      systemd:
        name: prometheus
        state: restarted

    - name: Attendre que Prometheus redémarre
      wait_for:
        port: 9090
        delay: 5

    - name: Afficher les instructions
      debug:
        msg:
          - "Règles d'alerte configurées !"
          - "Vérifier les règles : http://x.x.x.102:9090/rules"
          - "Vérifier les alertes actives : http://x.x.x.102:9090/alerts"
EOF
```

**Appliquer**

```bash
ansible-playbook -i inventory/hosts.ini playbooks/configure-prometheus-alerts.yml
```

### Tester les Alertes

#### Option 1 : Simuler une alerte CPU (Quick Test)

```bash
# Se connecter au worker
ssh ubuntu@x.x.x.101

# Stresser le CPU pour déclencher l'alerte
# Installer stress si besoin
sudo apt install -y stress

# Créer du stress CPU pendant 5 minutes
stress --cpu 4 --timeout 300s &

# Sortir
exit
```

**Attends 2-3 minutes, puis vérifie :**

- Prometheus Alerts : http://x.x.x.102:9090/alerts
- Alertmanager : http://x.x.x.102:9093

#### Option 2 : Arrêter Node Exporter (Instance Down)

```bash
# Arrêter node_exporter sur le worker
ssh ubuntu@x.x.x.101 "sudo systemctl stop node_exporter"

# Attendre 2 minutes
sleep 120

# Vérifier dans Alertmanager
# http://x.x.x.102:9093

# Redémarrer
ssh ubuntu@x.x.x.101 "sudo systemctl start node_exporter"
```

### Optionnel

#### Configurer les Notifications 

Pour recevoir des notifications (Slack, Email, etc.), modifie Alertmanager :

```bash
ssh ubuntu@x.x.x.102

sudo nano /etc/alertmanager/alertmanager.yml
```

Exemple avec un webhook simple :

```bash
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'instance']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default-receiver'

receivers:
  - name: 'default-receiver'
    webhook_configs:
      - url: 'http://example.com/webhook'  # Remplace par ton webhook
        send_resolved: true

# Pour Slack (exemple)
#   - name: 'slack-notifications'
#     slack_configs:
#       - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
#         channel: '#alerts'
#         text: 'Alert: {{ .CommonAnnotations.summary }}'
```

Redémarre Alertmanager :

```bash
sudo systemctl restart alertmanager

exit
```

Vérifications Rapides:

```bash
# Voir les règles configurées
http://x.x.x.102:9090/rules

# Voir les alertes actives
http://x.x.x.102:9090/alerts

# Statut Alertmanager
http://x.x.x.102:9093/status
```