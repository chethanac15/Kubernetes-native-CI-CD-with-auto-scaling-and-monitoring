# Multi-stage Dockerfile for Enhanced CI/CD Application
# Stage 1: Build the application
FROM maven:3.9.5-openjdk-17 AS builder

# Set working directory
WORKDIR /app

# Copy pom.xml and download dependencies
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source code
COPY src ./src

# Build the application
RUN mvn clean package -DskipTests

# Stage 2: Security scanning with Trivy
FROM aquasec/trivy:latest AS security-scanner
COPY --from=builder /app/target/enhanced-cicd-app-1.0.0.jar /app.jar
RUN trivy fs --security-checks vuln,config,secret /app.jar --format json --output /security-report.json || true

# Stage 3: Runtime image
FROM openjdk:17-jre-slim AS runtime

# Install necessary packages
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Create application user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Set working directory
WORKDIR /app

# Copy the built JAR from builder stage
COPY --from=builder /app/target/enhanced-cicd-app-1.0.0.jar app.jar

# Copy security report
COPY --from=security-scanner /security-report.json /security-report.json

# Create necessary directories
RUN mkdir -p /app/logs /app/config && \
    chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/api/actuator/health || exit 1

# JVM options for production
ENV JAVA_OPTS="-Xms512m -Xmx2g -XX:+UseG1GC -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

# Application startup
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]

# Labels for better container management
LABEL maintainer="devops@company.com" \
      version="1.0.0" \
      description="Enhanced CI/CD Application" \
      org.opencontainers.image.title="Enhanced CI/CD App" \
      org.opencontainers.image.description="Enhanced CI/CD project with multi-cloud support" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.vendor="Company" \
      org.opencontainers.image.source="https://github.com/company/enhanced-cicd-project"
