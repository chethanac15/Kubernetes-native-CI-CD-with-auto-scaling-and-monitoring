#!/bin/bash

echo "🚀 Enhanced CI/CD Project - Simple Local Setup"
echo "================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

# Create a simple docker-compose file for basic services
create_simple_compose() {
    print_status "Creating simple Docker Compose configuration..."
    
    cat > docker-compose.simple.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: enhanced-cicd-postgres
    environment:
      POSTGRES_DB: enhanced_cicd
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres123
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 30s
      timeout: 10s
      retries: 3

  redis:
    image: redis:7-alpine
    container_name: enhanced-cicd-redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  jenkins:
    image: jenkins/jenkins:lts-jdk17
    container_name: enhanced-cicd-jenkins
    ports:
      - "8082:8080"
      - "50000:50000"
    environment:
      - JENKINS_OPTS=--httpPort=8080
    volumes:
      - jenkins_data:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/login"]
      interval: 30s
      timeout: 10s
      retries: 5

  sonarqube:
    image: sonarqube:9.4-community
    container_name: enhanced-cicd-sonarqube
    ports:
      - "9000:9000"
    environment:
      - SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/api/system/status"]
      interval: 30s
      timeout: 10s
      retries: 5

volumes:
  postgres_data:
  redis_data:
  jenkins_data:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_logs:
EOF

    print_success "Simple Docker Compose configuration created"
}

# Start basic services
start_basic_services() {
    print_status "Starting basic services..."
    
    docker-compose -f docker-compose.simple.yml up -d
    
    if [ $? -eq 0 ]; then
        print_success "Basic services started successfully"
    else
        print_error "Failed to start basic services"
        exit 1
    fi
}

# Wait for services to be ready
wait_for_services() {
    print_status "Waiting for services to be ready..."
    
    # Wait for PostgreSQL
    print_status "Waiting for PostgreSQL..."
    until docker exec enhanced-cicd-postgres pg_isready -U postgres > /dev/null 2>&1; do
        sleep 5
    done
    print_success "PostgreSQL is ready"
    
    # Wait for Redis
    print_status "Waiting for Redis..."
    until docker exec enhanced-cicd-redis redis-cli ping > /dev/null 2>&1; do
        sleep 5
    done
    print_success "Redis is ready"
    
    # Wait for Jenkins
    print_status "Waiting for Jenkins..."
    until curl -f http://localhost:8082/login > /dev/null 2>&1; do
        sleep 10
    done
    print_success "Jenkins is ready"
    
    # Wait for SonarQube
    print_status "Waiting for SonarQube..."
    until curl -f http://localhost:9000/api/system/status > /dev/null 2>&1; do
        sleep 10
    done
    print_success "SonarQube is ready"
}

# Build and run the application
build_and_run_app() {
    print_status "Building the application..."
    
    # Build the Docker image
    docker build -t enhanced-cicd-app:latest .
    
    if [ $? -eq 0 ]; then
        print_success "Application built successfully"
    else
        print_error "Failed to build application"
        exit 1
    fi
    
    # Run the application
    print_status "Starting the application..."
    
    docker run -d \
        --name enhanced-cicd-app \
        --network enhanced-cicd_default \
        -p 8081:8080 \
        -e SPRING_PROFILES_ACTIVE=dev \
        -e SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/enhanced_cicd \
        -e SPRING_DATASOURCE_USERNAME=postgres \
        -e SPRING_DATASOURCE_PASSWORD=postgres123 \
        -e SPRING_REDIS_HOST=redis \
        -e SPRING_REDIS_PORT=6379 \
        enhanced-cicd-app:latest
    
    if [ $? -eq 0 ]; then
        print_success "Application started successfully"
    else
        print_error "Failed to start application"
        exit 1
    fi
}

# Display access information
display_access_info() {
    echo ""
    echo "🎉 Enhanced CI/CD Project - Simple Local Setup Complete!"
    echo "========================================================"
    echo ""
    echo "📋 Access Information:"
    echo "======================"
    echo "🌐 Application: http://localhost:8081"
    echo "🔧 Jenkins: http://localhost:8082"
    echo "   - Initial admin password: $(docker exec enhanced-cicd-jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo 'Check Jenkins logs')"
    echo "📊 SonarQube: http://localhost:9000"
    echo "   - Default credentials: admin/admin"
    echo "🗄️  PostgreSQL: localhost:5432"
    echo "   - Database: enhanced_cicd"
    echo "   - Username: postgres"
    echo "   - Password: postgres123"
    echo "🔴 Redis: localhost:6379"
    echo ""
    echo "📝 Next Steps:"
    echo "=============="
    echo "1. Access Jenkins at http://localhost:8082"
    echo "2. Complete Jenkins initial setup"
    echo "3. Install required Jenkins plugins (Docker, Pipeline, SonarQube Scanner)"
    echo "4. Configure SonarQube at http://localhost:9000"
    echo "5. Test the application at http://localhost:8081"
    echo ""
    echo "🛠️  Useful Commands:"
    echo "===================="
    echo "View logs: docker-compose -f docker-compose.simple.yml logs -f"
    echo "Stop services: docker-compose -f docker-compose.simple.yml down"
    echo "Restart services: docker-compose -f docker-compose.simple.yml restart"
    echo "View running containers: docker ps"
    echo ""
}

# Main execution
main() {
    check_prerequisites
    create_simple_compose
    start_basic_services
    wait_for_services
    build_and_run_app
    display_access_info
}

# Run main function
main
