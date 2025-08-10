# Manual Setup Guide for Enhanced CI/CD Project

This guide will help you set up the Enhanced CI/CD project manually on your local machine.

## Prerequisites

Before starting, ensure you have the following installed:

- **Docker Desktop** (with Docker Compose)
- **Java 17** (for building the application)
- **Maven** (for building the application)
- **Git** (for version control)

## Step 1: Verify Docker Installation

First, let's make sure Docker is working properly:

```bash
docker --version
docker-compose --version
```

If Docker is not responding, try restarting Docker Desktop.

## Step 2: Start Basic Services

Create a simple `docker-compose.yml` file for basic services:

```yaml
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

  redis:
    image: redis:7-alpine
    container_name: enhanced-cicd-redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

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

volumes:
  postgres_data:
  redis_data:
  jenkins_data:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_logs:
```

Save this as `docker-compose.yml` and run:

```bash
docker-compose up -d
```

## Step 3: Build the Application

Build the Spring Boot application:

```bash
# Build with Maven
mvn clean package -DskipTests

# Build Docker image
docker build -t enhanced-cicd-app:latest .
```

## Step 4: Run the Application

Run the application container:

```bash
docker run -d \
  --name enhanced-cicd-app \
  --network devops1_default \
  -p 8081:8080 \
  -e SPRING_PROFILES_ACTIVE=dev \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/enhanced_cicd \
  -e SPRING_DATASOURCE_USERNAME=postgres \
  -e SPRING_DATASOURCE_PASSWORD=postgres123 \
  -e SPRING_REDIS_HOST=redis \
  -e SPRING_REDIS_PORT=6379 \
  enhanced-cicd-app:latest
```

## Step 5: Access the Services

Once everything is running, you can access:

- **Application**: http://localhost:8081
- **Jenkins**: http://localhost:8082
- **SonarQube**: http://localhost:9000
- **PostgreSQL**: localhost:5432
- **Redis**: localhost:6379

## Step 6: Configure Jenkins

1. Access Jenkins at http://localhost:8082
2. Get the initial admin password:
   ```bash
   docker exec enhanced-cicd-jenkins cat /var/jenkins_home/secrets/initialAdminPassword
   ```
3. Complete the initial setup
4. Install recommended plugins
5. Install additional plugins:
   - Docker Pipeline
   - SonarQube Scanner
   - Pipeline: Stage View
   - Email Extension Plugin

## Step 7: Configure SonarQube

1. Access SonarQube at http://localhost:9000
2. Login with default credentials: admin/admin
3. Create a new project
4. Generate a token for Jenkins integration

## Step 8: Set Up CI/CD Pipeline

1. In Jenkins, create a new Pipeline job
2. Use the `Jenkinsfile` from the project root
3. Configure the pipeline to use your Git repository
4. Set up SonarQube credentials in Jenkins

## Troubleshooting

### Docker Issues
If Docker is not responding:
1. Restart Docker Desktop
2. Check if Docker service is running
3. Ensure you have sufficient disk space

### Port Conflicts
If ports are already in use:
- Change port mappings in docker-compose.yml
- Check what's using the ports: `netstat -ano | findstr :PORT`

### Application Issues
If the application doesn't start:
1. Check container logs: `docker logs enhanced-cicd-app`
2. Verify database connectivity
3. Check environment variables

## Useful Commands

```bash
# View running containers
docker ps

# View logs
docker logs <container-name>

# Stop all services
docker-compose down

# Restart services
docker-compose restart

# Remove all containers and volumes
docker-compose down -v
docker system prune -a
```

## Next Steps

After successful setup:

1. **Test the Application**: Visit http://localhost:8081
2. **Set up Git Repository**: Push your code to a Git repository
3. **Configure Jenkins Pipeline**: Set up the CI/CD pipeline
4. **Add Monitoring**: Consider adding Prometheus and Grafana
5. **Security Scanning**: Configure Trivy and OWASP ZAP
6. **Load Balancing**: Set up NGINX if needed

## Support

If you encounter issues:
1. Check the logs of each service
2. Verify all prerequisites are installed
3. Ensure Docker Desktop is running properly
4. Check network connectivity between containers
