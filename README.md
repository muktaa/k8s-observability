# Kubernetes Observability Demo

This repository contains scripts to set up a complete Kubernetes observability stack on AWS EKS, including Prometheus for metrics collection, Grafana for visualization, and a demo application that generates logs and metrics.

## Short Description

This demo showcases a complete observability setup for Kubernetes, including:
- Metrics collection with Prometheus
- Log aggregation with Loki
- Visualization with Grafana
- A demo application that generates sample metrics and logs
- All components deployed on AWS EKS

## Prerequisites

Before running the setup script, ensure you have:
- AWS CLI installed and configured with appropriate credentials
- AWS account with permissions to create EKS clusters
- Sufficient AWS resources available (VPC, subnets, etc.)
- Basic understanding of Kubernetes concepts

## Components Installed

The `k8s-setup-aws.sh` script installs and configures the following components:

### 1. AWS EKS Cluster
- Creates a Kubernetes cluster using EKS
- Configures with 2 t3.medium nodes
- Sets up necessary IAM roles and policies
- Configures auto-scaling (2-3 nodes)

### 2. Monitoring Stack
- **Prometheus**: Metrics collection and storage
  - Collects metrics from Kubernetes components
  - Stores time-series data
  - [Learn more about Prometheus](https://prometheus.io/docs/introduction/overview/)

- **Grafana**: Visualization and dashboarding
  - Web-based UI for metrics visualization
  - Pre-configured dashboards
  - [Learn more about Grafana](https://grafana.com/docs/)

- **Loki**: Log aggregation
  - Collects and stores application logs
  - Integrates with Grafana for log visualization
  - [Learn more about Loki](https://grafana.com/docs/loki/latest/)

### 3. Demo Application
- A sample application that generates:
  - Sample metrics (warp drive status, shields, etc.)
  - Sample logs (info, debug, warning, error)
  - Web interface to view logs in real-time

## Script Components Explained

### Prerequisites Check
```bash
command -v aws >/dev/null 2>&1 || { echo "AWS CLI required, installing..."; pip install awscli; }
command -v eksctl >/dev/null 2>&1 || { echo "eksctl required, installing..."; ... }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl required, installing..."; ... }
command -v helm >/dev/null 2>&1 || { echo "helm required, installing..."; ... }
```
Checks and installs required tools if not present.

### Cluster Configuration
```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: obs-demo-cluster
  region: us-east-1
  version: "1.27"
```
Defines the EKS cluster configuration including:
- Cluster name and region
- Kubernetes version
- Node group configuration
- IAM policies

### Monitoring Setup
```bash
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=observability \
  --set prometheus.serviceMonitor.enabled=true
```
Installs the monitoring stack using Helm charts.

## Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html)
- [Prometheus Operator Documentation](https://github.com/prometheus-operator/prometheus-operator)
- [Grafana Documentation](https://grafana.com/docs/)
- [Helm Documentation](https://helm.sh/docs/)

## Cleanup

Use the `cleanup.sh` script to remove all created resources:
```bash
./cleanup.sh
```

## Note

The cluster creation process typically takes 10-15 minutes to complete. Please wait for the cluster to be fully created before proceeding with monitoring stack installation.

# Tips

### Check the created cluster
kubectl get nodes
kubectl get namespaces
kubectl get pods -n demo-app

### Check current state of monitoring
kubectl get pods -n monitoring
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80

### Enable metric collection
kubectl describe deployment space-explorer -n demo-app

cat service-monitor.yaml
kubectl apply -f service-monitor.yaml

kubectl get servicemonitor -n monitoring

### Port forward to prometheus
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090

