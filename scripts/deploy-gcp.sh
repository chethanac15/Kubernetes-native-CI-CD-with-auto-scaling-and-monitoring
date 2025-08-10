#!/bin/bash

# Enhanced CI/CD Project - Google Cloud Platform Deployment Script
# This script sets up the complete infrastructure on GCP

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="your-gcp-project-id"
REGION="us-central1"
ZONE="us-central1-a"
CLUSTER_NAME="enhanced-cicd-cluster"
NAMESPACE="enhanced-cicd"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command_exists gcloud; then
        print_error "gcloud CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! command_exists kubectl; then
        print_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    if ! command_exists terraform; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    if ! command_exists docker; then
        print_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

# Initialize GCP
init_gcp() {
    print_status "Initializing Google Cloud Platform..."
    
    # Set project
    gcloud config set project $PROJECT_ID
    
    # Enable required APIs
    print_status "Enabling required APIs..."
    gcloud services enable \
        compute.googleapis.com \
        container.googleapis.com \
        monitoring.googleapis.com \
        logging.googleapis.com \
        cloudresourcemanager.googleapis.com \
        iam.googleapis.com \
        dns.googleapis.com \
        certificatemanager.googleapis.com \
        sqladmin.googleapis.com \
        redis.googleapis.com \
        storage.googleapis.com
    
    print_success "GCP APIs enabled"
}

# Setup Terraform
setup_terraform() {
    print_status "Setting up Terraform infrastructure..."
    
    cd terraform/gcp
    
    # Initialize Terraform
    terraform init
    
    # Create terraform.tfvars
    cat > terraform.tfvars << EOF
project_id   = "$PROJECT_ID"
region       = "$REGION"
zone         = "$ZONE"
cluster_name = "$CLUSTER_NAME"
node_count   = 3
machine_type = "e2-standard-4"
EOF
    
    # Plan and apply
    terraform plan -out=tfplan
    terraform apply tfplan
    
    # Get cluster credentials
    gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION
    
    cd ../..
    
    print_success "Terraform infrastructure deployed"
}

# Setup Kubernetes cluster
setup_kubernetes() {
    print_status "Setting up Kubernetes cluster..."
    
    # Create namespace
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Setup NGINX Ingress Controller
    print_status "Installing NGINX Ingress Controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
    
    # Wait for ingress controller to be ready
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s
    
    # Setup Cert-Manager for SSL certificates
    print_status "Installing Cert-Manager..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
    
    # Wait for cert-manager to be ready
    kubectl wait --namespace cert-manager \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=webhook \
        --timeout=300s
    
    # Create ClusterIssuer for Let's Encrypt
    cat > cluster-issuer.yaml << EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
    
    kubectl apply -f cluster-issuer.yaml
    rm cluster-issuer.yaml
    
    print_success "Kubernetes cluster setup completed"
}

# Setup monitoring stack
setup_monitoring() {
    print_status "Setting up monitoring stack..."
    
    # Create monitoring namespace
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Prometheus Operator
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
        --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
        --set prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues=false \
        --set prometheus.prometheusSpec.probeSelectorNilUsesHelmValues=false
    
    # Install Grafana dashboards
    kubectl apply -f k8s/monitoring/grafana-dashboards.yaml
    
    print_success "Monitoring stack deployed"
}

# Setup logging stack
setup_logging() {
    print_status "Setting up logging stack..."
    
    # Create logging namespace
    kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Elasticsearch
    helm repo add elastic https://helm.elastic.co
    helm repo update
    
    helm install elasticsearch elastic/elasticsearch \
        --namespace logging \
        --set replicas=1 \
        --set minimumMasterNodes=1
    
    # Install Kibana
    helm install kibana elastic/kibana \
        --namespace logging \
        --set service.type=ClusterIP
    
    # Install Filebeat
    helm install filebeat elastic/filebeat \
        --namespace logging
    
    print_success "Logging stack deployed"
}

# Setup ArgoCD
setup_argocd() {
    print_status "Setting up ArgoCD..."
    
    # Create ArgoCD namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    kubectl wait --namespace argocd \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/name=argocd-server \
        --timeout=300s
    
    # Patch ArgoCD service to LoadBalancer
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
    
    # Get ArgoCD admin password
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    print_success "ArgoCD admin password: $ARGOCD_PASSWORD"
    
    print_success "ArgoCD deployed"
}

# Setup application
setup_application() {
    print_status "Setting up application..."
    
    # Create ConfigMap
    kubectl create configmap app-config \
        --from-literal=db.host="enhanced-cicd-postgres" \
        --from-literal=db.port="5432" \
        --from-literal=db.name="enhanced_cicd_db" \
        --from-literal=redis.host="enhanced-cicd-redis" \
        --from-literal=redis.port="6379" \
        -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Create Secrets
    kubectl create secret generic app-secrets \
        --from-literal=db.user="appuser" \
        --from-literal=db.password="$(openssl rand -base64 32)" \
        --from-literal=redis.password="$(openssl rand -base64 32)" \
        --from-literal=jwt.secret="$(openssl rand -base64 64)" \
        -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply Kubernetes manifests
    kubectl apply -f k8s/base/ -n $NAMESPACE
    
    # Wait for application to be ready
    kubectl wait --namespace $NAMESPACE \
        --for=condition=ready pod \
        --selector=app=enhanced-cicd-app \
        --timeout=300s
    
    print_success "Application deployed"
}

# Setup CI/CD tools
setup_cicd_tools() {
    print_status "Setting up CI/CD tools..."
    
    # Install Jenkins
    helm repo add jenkins https://charts.jenkins.io
    helm repo update
    
    helm install jenkins jenkins/jenkins \
        --namespace $NAMESPACE \
        --set controller.serviceType=LoadBalancer \
        --set controller.installPlugins=true \
        --set controller.installLatestPlugins=true \
        --set controller.installLatestSpecifiedPlugins=true \
        --set controller.installPlugins={kubernetes:1.31.3,workflow-aggregator:2.6,git:4.11.0,configuration-as-code:1.55,blueocean:1.25.3,sonar:2.14,trivy:1.0.0}
    
    # Install SonarQube
    helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
    helm repo update
    
    helm install sonarqube sonarqube/sonarqube \
        --namespace $NAMESPACE \
        --set service.type=LoadBalancer
    
    print_success "CI/CD tools deployed"
}

# Display access information
display_access_info() {
    print_status "Deployment completed successfully!"
    echo
    echo "=== Access Information ==="
    echo
    
    # Get service URLs
    ARGOCD_URL=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    JENKINS_URL=$(kubectl get svc jenkins -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    SONARQUBE_URL=$(kubectl get svc sonarqube-sonarqube -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    GRAFANA_URL=$(kubectl get svc prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    KIBANA_URL=$(kubectl get svc kibana-kibana -n logging -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    echo "ArgoCD: http://$ARGOCD_URL"
    echo "Jenkins: http://$JENKINS_URL"
    echo "SonarQube: http://$SONARQUBE_URL"
    echo "Grafana: http://$GRAFANA_URL"
    echo "Kibana: http://$KIBANA_URL"
    echo
    echo "=== Credentials ==="
    echo "ArgoCD Admin Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
    echo "Jenkins Admin Password: $(kubectl exec --namespace $NAMESPACE -c jenkins -it svc/jenkins -- /bin/cat /run/secrets/additional/chart-admin-password)"
    echo
    echo "=== Next Steps ==="
    echo "1. Configure your domain in the ingress configuration"
    echo "2. Set up SSL certificates with Let's Encrypt"
    echo "3. Configure Jenkins pipelines"
    echo "4. Set up ArgoCD applications"
    echo "5. Configure monitoring dashboards"
}

# Main execution
main() {
    echo "🚀 Enhanced CI/CD Project - GCP Deployment"
    echo "=========================================="
    echo
    
    check_prerequisites
    init_gcp
    setup_terraform
    setup_kubernetes
    setup_monitoring
    setup_logging
    setup_argocd
    setup_cicd_tools
    setup_application
    display_access_info
}

# Run main function
main "$@"
