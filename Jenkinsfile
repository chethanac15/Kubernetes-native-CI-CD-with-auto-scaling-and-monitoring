pipeline {
    agent any
    
    environment {
        // Application Configuration
        APP_NAME = 'enhanced-cicd-app'
        APP_VERSION = '1.0.0'
        DOCKER_IMAGE = 'your-registry/enhanced-cicd-app'
        DOCKER_TAG = "${BUILD_NUMBER}"
        
        // Cloud Provider Configuration
        CLOUD_PROVIDER = 'gcp' // Options: gcp, azure, digitalocean, local
        
        // Registry Configuration
        DOCKER_REGISTRY = 'your-registry.com'
        DOCKER_CREDENTIALS = 'docker-registry-credentials'
        
        // SonarQube Configuration
        SONAR_HOST_URL = 'http://sonarqube:9000'
        SONAR_TOKEN = 'your-sonar-token'
        
        // Kubernetes Configuration
        K8S_NAMESPACE = 'enhanced-cicd'
        K8S_CONTEXT = 'your-k8s-context'
        
        // Security Configuration
        TRIVY_SEVERITY = 'CRITICAL,HIGH'
        TRIVY_EXIT_CODE = '1'
        
        // Monitoring Configuration
        PROMETHEUS_URL = 'http://prometheus:9090'
        GRAFANA_URL = 'http://grafana:3000'
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        ansiColor('xterm')
        timeout(time: 30, unit: 'MINUTES')
    }
    
    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "🚀 Starting Enhanced CI/CD Pipeline"
                    echo "📋 Build Number: ${BUILD_NUMBER}"
                    echo "🌐 Cloud Provider: ${CLOUD_PROVIDER}"
                    
                    // Checkout code
                    checkout scm
                    
                    // Set build description
                    currentBuild.description = "Build #${BUILD_NUMBER} - ${CLOUD_PROVIDER.toUpperCase()}"
                }
            }
        }
        
        stage('Dependency Analysis') {
            steps {
                script {
                    echo "📦 Analyzing dependencies..."
                    
                    // Run OWASP dependency check
                    sh '''
                        wget -qO- https://github.com/jeremylong/DependencyCheck/releases/download/v8.4.0-release/dependency-check-8.4.0-release.zip | unzip -
                        ./dependency-check/bin/dependency-check.sh --scan . --format "HTML" --format "JSON" --out . --failOnCVSS 7
                    '''
                    
                    // Archive dependency check reports
                    archiveArtifacts artifacts: 'dependency-check-report.*', allowEmptyArchive: true
                }
            }
            post {
                always {
                    script {
                        // Publish dependency check results
                        dependencyCheck additionalArguments: '', pattern: 'dependency-check-report.xml'
                    }
                }
            }
        }
        
        stage('Unit Tests') {
            steps {
                script {
                    echo "🧪 Running unit tests..."
                    
                    // Run tests with coverage
                    sh 'mvn clean test jacoco:report'
                    
                    // Archive test results
                    archiveArtifacts artifacts: 'target/surefire-reports/*.xml', allowEmptyArchive: true
                    archiveArtifacts artifacts: 'target/site/jacoco/*', allowEmptyArchive: true
                }
            }
            post {
                always {
                    script {
                        // Publish test results
                        junit 'target/surefire-reports/*.xml'
                        
                        // Publish coverage report
                        publishCoverage adapters: [jacocoAdapter('target/site/jacoco/jacoco.xml')], 
                                       sourceFileResolver: sourceFiles('STORE_LAST_BUILD')
                    }
                }
            }
        }
        
        stage('Code Quality Analysis') {
            steps {
                script {
                    echo "🔍 Running SonarQube analysis..."
                    
                    // Run SonarQube scanner
                    withSonarQubeEnv('SonarQube') {
                        sh '''
                            mvn sonar:sonar \
                                -Dsonar.projectKey=${APP_NAME} \
                                -Dsonar.projectName="${APP_NAME}" \
                                -Dsonar.projectVersion="${APP_VERSION}" \
                                -Dsonar.sources=src/main/java \
                                -Dsonar.tests=src/test/java \
                                -Dsonar.java.binaries=target/classes \
                                -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml \
                                -Dsonar.host.url=${SONAR_HOST_URL} \
                                -Dsonar.login=${SONAR_TOKEN}
                        '''
                    }
                }
            }
        }
        
        stage('Security Scanning') {
            parallel {
                stage('Container Security Scan') {
                    steps {
                        script {
                            echo "🔒 Scanning container for vulnerabilities..."
                            
                            // Build Docker image for scanning
                            sh 'docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .'
                            
                            // Run Trivy security scan
                            sh '''
                                trivy image --severity ${TRIVY_SEVERITY} \
                                           --exit-code ${TRIVY_EXIT_CODE} \
                                           --format json \
                                           --output trivy-report.json \
                                           ${DOCKER_IMAGE}:${DOCKER_TAG}
                            '''
                            
                            // Archive security report
                            archiveArtifacts artifacts: 'trivy-report.json', allowEmptyArchive: true
                        }
                    }
                }
                
                stage('SAST Scan') {
                    steps {
                        script {
                            echo "🔍 Running SAST analysis..."
                            
                            // Run OWASP ZAP scan
                            sh '''
                                docker run -v $(pwd):/zap/wrk/:rw -t owasp/zap2docker-stable zap-baseline.py \
                                    -t http://localhost:8080 \
                                    -J zap-report.json \
                                    -m 5
                            '''
                            
                            // Archive SAST report
                            archiveArtifacts artifacts: 'zap-report.json', allowEmptyArchive: true
                        }
                    }
                }
            }
        }
        
        stage('Build Application') {
            steps {
                script {
                    echo "🏗️ Building application..."
                    
                    // Build with Maven
                    sh 'mvn clean package -DskipTests'
                    
                    // Archive JAR file
                    archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    echo "🐳 Building Docker image..."
                    
                    // Build Docker image
                    sh 'docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .'
                    sh 'docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest'
                    
                    // Archive Docker image info
                    sh 'docker images ${DOCKER_IMAGE}:${DOCKER_TAG} > docker-image-info.txt'
                    archiveArtifacts artifacts: 'docker-image-info.txt'
                }
            }
        }
        
        stage('Push to Registry') {
            steps {
                script {
                    echo "📤 Pushing to container registry..."
                    
                    // Login to registry
                    withCredentials([usernamePassword(credentialsId: DOCKER_CREDENTIALS, 
                                                   usernameVariable: 'DOCKER_USER', 
                                                   passwordVariable: 'DOCKER_PASS')]) {
                        sh 'echo $DOCKER_PASS | docker login ${DOCKER_REGISTRY} -u $DOCKER_USER --password-stdin'
                    }
                    
                    // Push images
                    sh 'docker push ${DOCKER_IMAGE}:${DOCKER_TAG}'
                    sh 'docker push ${DOCKER_IMAGE}:latest'
                }
            }
        }
        
        stage('Deploy to Staging') {
            when {
                branch 'develop'
            }
            steps {
                script {
                    echo "🚀 Deploying to staging environment..."
                    
                    // Deploy to staging using ArgoCD
                    sh '''
                        kubectl config use-context ${K8S_CONTEXT}
                        kubectl apply -f k8s/overlays/staging/
                        
                        # Wait for deployment to be ready
                        kubectl rollout status deployment/${APP_NAME} -n ${K8S_NAMESPACE} --timeout=300s
                    '''
                    
                    // Run integration tests
                    sh '''
                        # Wait for application to be ready
                        sleep 30
                        
                        # Run integration tests
                        mvn verify -Dspring.profiles.active=staging
                    '''
                }
            }
            post {
                always {
                    script {
                        // Collect staging metrics
                        sh '''
                            kubectl get pods -n ${K8S_NAMESPACE} -o wide
                            kubectl top pods -n ${K8S_NAMESPACE}
                        '''
                    }
                }
            }
        }
        
        stage('Performance Testing') {
            when {
                branch 'develop'
            }
            steps {
                script {
                    echo "⚡ Running performance tests..."
                    
                    // Run JMeter performance tests
                    sh '''
                        jmeter -n -t performance-tests/load-test.jmx \
                               -l performance-results.jtl \
                               -e -o performance-report/
                    '''
                    
                    // Archive performance results
                    archiveArtifacts artifacts: 'performance-results.jtl,performance-report/**/*', allowEmptyArchive: true
                }
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "🚀 Deploying to production environment..."
                    
                    // Deploy to production using ArgoCD
                    sh '''
                        kubectl config use-context ${K8S_CONTEXT}
                        kubectl apply -f k8s/overlays/prod/
                        
                        # Wait for deployment to be ready
                        kubectl rollout status deployment/${APP_NAME} -n ${K8S_NAMESPACE} --timeout=600s
                    '''
                    
                    // Verify deployment
                    sh '''
                        # Health check
                        kubectl get pods -n ${K8S_NAMESPACE} -o wide
                        
                        # Check application health
                        curl -f http://${APP_NAME}.${K8S_NAMESPACE}.svc.cluster.local:8080/api/actuator/health
                    '''
                }
            }
        }
        
        stage('Post-Deployment Verification') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "✅ Running post-deployment verification..."
                    
                    // Run smoke tests
                    sh '''
                        # Smoke tests
                        curl -f http://${APP_NAME}.${K8S_NAMESPACE}.svc.cluster.local:8080/api/actuator/health
                        curl -f http://${APP_NAME}.${K8S_NAMESPACE}.svc.cluster.local:8080/api/actuator/info
                    '''
                    
                    // Check monitoring
                    sh '''
                        # Verify Prometheus metrics
                        curl -f ${PROMETHEUS_URL}/api/v1/query?query=up{job="${APP_NAME}"}
                        
                        # Verify Grafana dashboards
                        curl -f ${GRAFANA_URL}/api/health
                    '''
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "🧹 Cleaning up workspace..."
                
                // Clean Docker images
                sh 'docker rmi ${DOCKER_IMAGE}:${DOCKER_TAG} || true'
                sh 'docker rmi ${DOCKER_IMAGE}:latest || true'
                
                // Clean workspace
                cleanWs()
            }
        }
        
        success {
            script {
                echo "✅ Pipeline completed successfully!"
                
                // Send success notification
                emailext (
                    subject: "✅ Pipeline Success: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: """
                        <h2>Pipeline Success</h2>
                        <p><strong>Job:</strong> ${env.JOB_NAME}</p>
                        <p><strong>Build:</strong> #${env.BUILD_NUMBER}</p>
                        <p><strong>Branch:</strong> ${env.GIT_BRANCH}</p>
                        <p><strong>Cloud Provider:</strong> ${CLOUD_PROVIDER}</p>
                        <p><strong>Duration:</strong> ${currentBuild.durationString}</p>
                        <p><a href="${env.BUILD_URL}">View Build Details</a></p>
                    """,
                    recipientProviders: [[$class: 'DevelopersRecipientProvider']]
                )
            }
        }
        
        failure {
            script {
                echo "❌ Pipeline failed!"
                
                // Send failure notification
                emailext (
                    subject: "❌ Pipeline Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: """
                        <h2>Pipeline Failure</h2>
                        <p><strong>Job:</strong> ${env.JOB_NAME}</p>
                        <p><strong>Build:</strong> #${env.BUILD_NUMBER}</p>
                        <p><strong>Branch:</strong> ${env.GIT_BRANCH}</p>
                        <p><strong>Cloud Provider:</strong> ${CLOUD_PROVIDER}</p>
                        <p><strong>Duration:</strong> ${currentBuild.durationString}</p>
                        <p><a href="${env.BUILD_URL}">View Build Details</a></p>
                    """,
                    recipientProviders: [[$class: 'DevelopersRecipientProvider']]
                )
            }
        }
        
        cleanup {
            script {
                echo "🧹 Final cleanup..."
                
                // Cleanup any remaining resources
                sh '''
                    # Cleanup Docker images
                    docker system prune -f || true
                    
                    # Cleanup Kubernetes resources (if needed)
                    kubectl delete job --field-selector=status.successful=1 --all-namespaces || true
                '''
            }
        }
    }
}
