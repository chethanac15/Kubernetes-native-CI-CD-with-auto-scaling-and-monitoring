# Contributing to Kubernetes-Native CI/CD Platform

Thank you for your interest in contributing to our Kubernetes-Native CI/CD Platform! This document provides guidelines and information for contributors.

## 🚀 Getting Started

### Prerequisites
- Docker Desktop
- Java 17
- Maven
- Git
- Kubernetes cluster (Minikube, Kind, or cloud-based)

### Local Development Setup
```bash
# Clone the repository
git clone https://github.com/yourusername/kubernetes-native-cicd-platform.git
cd kubernetes-native-cicd-platform

# Start local services
docker-compose up -d

# Build the application
mvn clean package -DskipTests

# Run the application
docker build -t enhanced-cicd-app:latest .
docker run -d --name enhanced-cicd-app -p 8081:8080 enhanced-cicd-app:latest
```

## 📋 How to Contribute

### 1. Fork the Repository
- Fork the repository to your GitHub account
- Clone your fork locally

### 2. Create a Feature Branch
```bash
git checkout -b feature/your-feature-name
```

### 3. Make Your Changes
- Follow the existing code style and conventions
- Add tests for new functionality
- Update documentation as needed
- Ensure all tests pass

### 4. Commit Your Changes
```bash
git add .
git commit -m "feat: add your feature description"
```

### 5. Push and Create a Pull Request
```bash
git push origin feature/your-feature-name
```

## 🎯 Development Guidelines

### Code Style
- Follow Java coding conventions
- Use meaningful variable and method names
- Add comments for complex logic
- Keep methods small and focused

### Testing
- Write unit tests for new functionality
- Ensure test coverage is maintained
- Run integration tests before submitting

### Documentation
- Update README.md if adding new features
- Add inline comments for complex code
- Update API documentation if applicable

## 🐛 Reporting Issues

When reporting issues, please include:
- Clear description of the problem
- Steps to reproduce the issue
- Expected vs actual behavior
- Environment details (OS, Java version, etc.)
- Screenshots if applicable

## 🔧 Development Environment

### Required Tools
- **IDE**: IntelliJ IDEA, Eclipse, or VS Code
- **Build Tool**: Maven 3.6+
- **Java**: OpenJDK 17
- **Docker**: Docker Desktop
- **Kubernetes**: Minikube or Kind

### Configuration
- Copy `application-dev.yml` to `application-local.yml` for local development
- Configure your IDE to use Java 17
- Set up Docker Desktop for containerization

## 📝 Commit Message Guidelines

Use conventional commit format:
```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

## 🚀 Deployment

### Local Deployment
```bash
./scripts/setup-simple-local.sh
```

### Cloud Deployment
```bash
# GCP
./scripts/deploy-gcp.sh

# Azure
./scripts/deploy-azure.sh

# DigitalOcean
./scripts/deploy-do.sh
```

## 🤝 Code Review Process

1. **Pull Request Creation**: Create a detailed PR description
2. **Automated Checks**: Ensure CI/CD pipeline passes
3. **Code Review**: Address reviewer feedback
4. **Merge**: Once approved, merge to main branch

## 📚 Resources

- [Spring Boot Documentation](https://spring.io/projects/spring-boot)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

## 🏆 Recognition

Contributors will be recognized in:
- Project README.md
- Release notes
- Contributor hall of fame

## 📞 Support

For questions or support:
- Open an issue on GitHub
- Check existing documentation
- Review previous issues and discussions

Thank you for contributing to our Kubernetes-Native CI/CD Platform! 🚀
