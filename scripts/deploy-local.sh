#!/bin/bash

# Enhanced CI/CD Project - Local Development Setup
# This script sets up the complete environment locally using Docker Compose and Minikube

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="enhanced-cicd"
CLUSTER_NAME="enhanced-cicd-local"

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
    
    if ! command_exists docker; then
        print_error "Docker is not installed. Please install Docker Desktop first."
        exit 1
    fi
    
    if ! command_exists kubectl; then
        print_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    if ! command_exists minikube; then
        print_error "Minikube is not installed. Please install it first."
        exit 1
    fi
    
    if ! command_exists helm; then
        print_error "Helm is not installed. Please install it first."
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

# Start Minikube
start_minikube() {
    print_status "Starting Minikube cluster..."
    
    # Check if minikube is already running
    if minikube status | grep -q "Running"; then
        print_warning "Minikube is already running"
    else
        # Start minikube with more resources
        minikube start \
            --cpus 4 \
            --memory 8192 \
            --disk-size 20g \
            --driver docker \
            --kubernetes-version v1.28.0 \
            --addons ingress \
            --addons metrics-server \
            --addons dashboard
        
        # Enable ingress addon
        minikube addons enable ingress
        minikube addons enable metrics-server
    fi
    
    # Configure kubectl to use minikube
    minikube kubectl -- get nodes
    
    print_success "Minikube cluster started"
}

# Setup local infrastructure
setup_local_infrastructure() {
    print_status "Setting up local infrastructure..."
    
    # Create namespace
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Start PostgreSQL using Docker Compose
    print_status "Starting PostgreSQL database..."
    docker-compose -f docker-compose.local.yml up -d postgres
    
    # Start Redis using Docker Compose
    print_status "Starting Redis cache..."
    docker-compose -f docker-compose.local.yml up -d redis
    
    # Wait for services to be ready
    print_status "Waiting for services to be ready..."
    sleep 30
    
    print_success "Local infrastructure setup completed"
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
        --set prometheus.prometheusSpec.probeSelectorNilUsesHelmValues=false \
        --set grafana.enabled=true \
        --set grafana.service.type=NodePort \
        --set grafana.service.nodePort=30000
    
    print_success "Monitoring stack deployed"
}

# Setup CI/CD tools
setup_cicd_tools() {
    print_status "Setting up CI/CD tools..."
    
    # Install Jenkins
    helm repo add jenkins https://charts.jenkins.io
    helm repo update
    
    helm install jenkins jenkins/jenkins \
        --namespace $NAMESPACE \
        --set controller.serviceType=NodePort \
        --set controller.serviceNodePort=30001 \
        --set controller.installPlugins=true \
        --set controller.installLatestPlugins=true \
        --set controller.installLatestSpecifiedPlugins=true \
        --set controller.installPlugins={kubernetes:1.31.3,workflow-aggregator:2.6,git:4.11.0,configuration-as-code:1.55,blueocean:1.25.3,sonar:2.14,trivy:1.0.0}
    
    # Install SonarQube
    helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
    helm repo update
    
    helm install sonarqube sonarqube/sonarqube \
        --namespace $NAMESPACE \
        --set service.type=NodePort \
        --set service.nodePort=30002
    
    print_success "CI/CD tools deployed"
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
    
    # Patch ArgoCD service to NodePort
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"port": 80, "targetPort": 8080, "nodePort": 30003}]}}'
    
    print_success "ArgoCD deployed"
}

# Build and deploy application
build_and_deploy_app() {
    print_status "Building and deploying application..."
    
    # Build Docker image
    docker build -t enhanced-cicd-app:local .
    
    # Load image into minikube
    minikube image load enhanced-cicd-app:local
    
    # Create ConfigMap for local environment
    kubectl create configmap app-config \
        --from-literal=db.host="host.minikube.internal" \
        --from-literal=db.port="5432" \
        --from-literal=db.name="enhanced_cicd_db" \
        --from-literal=redis.host="host.minikube.internal" \
        --from-literal=redis.port="6379" \
        -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Create Secrets
    kubectl create secret generic app-secrets \
        --from-literal=db.user="postgres" \
        --from-literal=db.password="password" \
        --from-literal=redis.password="" \
        --from-literal=jwt.secret="local-development-secret-key" \
        -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply Kubernetes manifests with local image
    cat k8s/base/deployment.yaml | sed 's|your-registry/enhanced-cicd-app:latest|enhanced-cicd-app:local|g' | kubectl apply -f - -n $NAMESPACE
    
    # Apply other manifests
    kubectl apply -f k8s/base/service.yaml -n $NAMESPACE
    kubectl apply -f k8s/base/hpa.yaml -n $NAMESPACE
    
    # Wait for application to be ready
    kubectl wait --namespace $NAMESPACE \
        --for=condition=ready pod \
        --selector=app=enhanced-cicd-app \
        --timeout=300s
    
    print_success "Application deployed"
}

# Setup port forwarding
setup_port_forwarding() {
    print_status "Setting up port forwarding..."
    
    # Start port forwarding in background
    kubectl port-forward -n $NAMESPACE svc/enhanced-cicd-app-service 8080:80 &
    kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &
    kubectl port-forward -n argocd svc/argocd-server 8081:80 &
    
    print_success "Port forwarding setup completed"
}

# Display access information
display_access_info() {
    print_status "Local deployment completed successfully!"
    echo
    echo "=== Access Information ==="
    echo
    
    # Get minikube IP
    MINIKUBE_IP=$(minikube ip)
    
    echo "Application: http://localhost:8080"
    echo "Grafana: http://localhost:3000 (admin/prom-operator)"
    echo "ArgoCD: http://localhost:8081 (admin/$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d))"
    echo "Jenkins: http://$MINIKUBE_IP:30001"
    echo "SonarQube: http://$MINIKUBE_IP:30002"
    echo
    echo "=== Database Information ==="
    echo "PostgreSQL: localhost:5432"
    echo "Username: postgres"
    echo "Password: password"
    echo "Database: enhanced_cicd_db"
    echo
    echo "=== Redis Information ==="
    echo "Redis: localhost:6379"
    echo
    echo "=== Useful Commands ==="
    echo "View logs: kubectl logs -f deployment/enhanced-cicd-app -n $NAMESPACE"
    echo "Access minikube: minikube dashboard"
    echo "Stop port forwarding: pkill -f 'kubectl port-forward'"
    echo "Stop minikube: minikube stop"
    echo "Delete cluster: minikube delete"
}

# Cleanup function
cleanup() {
    print_status "Cleaning up..."
    
    # Stop port forwarding
    pkill -f 'kubectl port-forward' || true
    
    # Stop Docker Compose services
    docker-compose -f docker-compose.local.yml down || true
    
    print_success "Cleanup completed"
}

# Main execution
main() {
    echo "🚀 Enhanced CI/CD Project - Local Development Setup"
    echo "=================================================="
    echo
    
    # Set up cleanup on script exit
    trap cleanup EXIT
    
    check_prerequisites
    start_minikube
    setup_local_infrastructure
    setup_monitoring
    setup_cicd_tools
    setup_argocd
    build_and_deploy_app
    setup_port_forwarding
    display_access_info
    
    print_status "Setup completed! Press Ctrl+C to stop all services."
    
    # Keep script running
    while true; do
        sleep 1
    done
}

# Run main function
main "$@"
