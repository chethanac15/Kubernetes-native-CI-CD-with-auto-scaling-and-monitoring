package com.enhancedcicd;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * Enhanced CI/CD Application
 * 
 * This is the main Spring Boot application that demonstrates a complete
 * CI/CD pipeline with multi-cloud support, monitoring, security, and
 * advanced DevOps features.
 * 
 * Features included:
 * - Multi-cloud deployment support (GCP, Azure, DigitalOcean, Local)
 * - Comprehensive monitoring with Prometheus and Micrometer
 * - Security scanning and JWT authentication
 * - Database integration with PostgreSQL
 * - Caching with Redis
 * - API documentation with OpenAPI
 * - Health checks and metrics
 * - Async processing capabilities
 * - Scheduled tasks
 */
@SpringBootApplication
@EnableJpaAuditing
@EnableCaching
@EnableAsync
@EnableScheduling
public class EnhancedCicdApplication {

    public static void main(String[] args) {
        SpringApplication.run(EnhancedCicdApplication.class, args);
    }
}
