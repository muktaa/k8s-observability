# Install Prometheus and Grafana using Helm
echo "Setting up Prometheus and Grafana..."
kubectl create namespace monitoring

# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack - includes Prometheus, Grafana, and necessary exporters
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=observability \
  --set prometheus.serviceMonitor.enabled=true 

echo "Waiting for Prometheus and Grafana pods to be ready..."
kubectl wait --for=condition=Available deployment --all -n monitoring --timeout=300s

# Deploy the Log-generating Demo Application
echo "Deploying demo application that generates logs..."
kubectl create namespace demo-app

cat > log-generator-app.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: space-explorer
  namespace: demo-app
  labels:
    app: space-explorer
spec:
  replicas: 2
  selector:
    matchLabels:
      app: space-explorer
  template:
    metadata:
      labels:
        app: space-explorer
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
    spec:
      containers:
      - name: space-explorer
        image: nginx:latest
        ports:
        - containerPort: 80
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/conf.d
        - name: log-generator
          mountPath: /log-generator
      - name: log-generator
        image: busybox
        command: ["/bin/sh", "-c"]
        args:
        - >
          while true; do
            echo "[INFO] User exploring galaxy sector $(( RANDOM % 100 + 1 )). Coordinates: $(( RANDOM % 1000 ))-$(( RANDOM % 1000 ))" >> /logs/app.log;
            echo "[DEBUG] Ship systems: Warp Drive: $(( RANDOM % 100 ))% operational" >> /logs/app.log;
            if [ $(( RANDOM % 20 )) -eq 0 ]; then
              echo "[WARNING] Asteroid field detected! Shields at $(( RANDOM % 100 ))%" >> /logs/app.log;
            fi
            if [ $(( RANDOM % 50 )) -eq 0 ]; then
              echo "[ERROR] Critical system failure in sector $(( RANDOM % 5 + 1 ))! Emergency protocols engaged." >> /logs/app.log;
            fi
            sleep 0.5;
          done
        volumeMounts:
        - name: log-volume
          mountPath: /logs
      - name: log-exporter
        image: busybox
        command: ["/bin/sh", "-c"]
        args:
        - >
          tail -f /logs/app.log
        volumeMounts:
        - name: log-volume
          mountPath: /logs
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-config
      - name: log-volume
        emptyDir: {}
      - name: log-generator
        emptyDir: {}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: demo-app
data:
  default.conf: |
    server {
      listen 80;
      root /log-generator;
      
      location / {
        add_header Content-Type text/html;
        return 200 '<html><head><title>Space Explorer Mission Control</title><style>body{font-family:Arial,sans-serif;background:#000;color:#0f0;margin:0;padding:20px;} h1{color:#0f6;} .console{background:#001;border:1px solid #0f0;padding:10px;height:400px;overflow:auto;font-family:monospace;} .blink{animation:blink 1s infinite;} @keyframes blink{0%{opacity:1;}50%{opacity:0;}100%{opacity:1;}}</style></head><body><h1>Space Explorer Mission Control</h1><div class="console"><pre id="log">Initializing mission control systems...</pre></div><script>const log=document.getElementById("log");function fetchLogs(){fetch("/logs").then(r=>r.text()).then(t=>{log.innerHTML=t;}).catch(e=>{console.error(e);}).finally(()=>{setTimeout(fetchLogs,1000);});}fetchLogs();</script></body></html>';
      }
      
      location /logs {
        add_header Content-Type text/plain;
        return 200 $arg_data;
      }
      
      location /metrics {
        return 200 'space_explorer_warp_drive{status="operational"} 1\nspace_explorer_shields{strength="high"} 95\nspace_explorer_life_support{status="nominal"} 100\nspace_explorer_asteroids_detected 5\nspace_explorer_alien_encounters 2\n';
      }
    }
---
apiVersion: v1
kind: Service
metadata:
  name: space-explorer
  namespace: demo-app
spec:
  selector:
    app: space-explorer
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
EOF

kubectl apply -f log-generator-app.yaml

# Set up Loki for log collection
echo "Setting up Loki for log collection..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=false \
  --set promtail.enabled=true \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=10Gi

# Configure Prometheus ServiceMonitor for the demo app
cat > service-monitor.yaml << EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: space-explorer-monitor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: space-explorer
  namespaceSelector:
    matchNames:
      - demo-app
  endpoints:
  - port: http
    path: /metrics
    interval: 15s
EOF

kubectl apply -f service-monitor.yaml

# Create Grafana dashboards
echo "Creating custom Grafana dashboards..."

# Get Grafana admin password
GRAFANA_PASSWORD=$(kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode)
echo "Grafana admin password: $GRAFANA_PASSWORD"

# Set up port forwarding for accessing the services
echo "Setting up port forwarding for services..."
echo "Run these commands in separate terminals to access services:"
echo "kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090"
echo "kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80"

# Print app URL
echo "Waiting for LoadBalancer to get an external IP..."
while [[ -z $(kubectl get svc space-explorer -n demo-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}') ]]; do
  echo "Waiting for external IP..."
  sleep 10
done

APP_URL=$(kubectl get svc space-explorer -n demo-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Space Explorer Demo App is available at: http://$APP_URL"
echo ""
echo "==== Kubernetes Observability Demo Setup Complete ===="
echo "Demo Cluster: obs-demo-cluster"
echo "Application Namespace: demo-app"
echo "Monitoring Namespace: monitoring"
echo "Grafana URL: http://localhost:3000 (after port-forwarding)"
echo "Grafana Username: admin"
echo "Grafana Password: $GRAFANA_PASSWORD"
echo ""
echo "Demo Instructions:"
echo "1. Show Space Explorer app running and generating logs"
echo "2. Demonstrate how to forward Grafana port:"
echo "   kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80"
echo "3. Open Grafana and show empty dashboards to start with"
echo "4. Run these steps to enable log collection and metric scraping during demo:"
echo "   kubectl apply -f service-monitor.yaml"
echo "5. Refresh Grafana and show appearing metrics and logs"
echo ""
echo "Everything is set up for an engaging demo!"
