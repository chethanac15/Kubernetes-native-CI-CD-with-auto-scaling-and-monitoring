# Google Cloud Platform Terraform Configuration
# Enhanced CI/CD Project Infrastructure

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 4.0"
    }
  }
  
  backend "gcs" {
    bucket = "enhanced-cicd-terraform-state"
    prefix = "gcp"
  }
}

# Provider configuration
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Variables
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "cluster_name" {
  description = "GKE Cluster Name"
  type        = string
  default     = "enhanced-cicd-cluster"
}

variable "node_count" {
  description = "Number of nodes in the cluster"
  type        = number
  default     = 3
}

variable "machine_type" {
  description = "Machine type for nodes"
  type        = string
  default     = "e2-standard-4"
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "dns.googleapis.com",
    "certificatemanager.googleapis.com"
  ])
  
  project = var.project_id
  service = each.value
  
  disable_dependent_services = true
  disable_on_destroy         = false
}

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "enhanced-cicd-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  
  depends_on = [google_project_service.required_apis]
}

# Subnet for GKE
resource "google_compute_subnetwork" "subnet" {
  name          = "enhanced-cicd-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
  
  # Enable flow logs for network monitoring
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling       = 0.5
    metadata            = "INCLUDE_ALL_METADATA"
  }
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region
  
  # Remove default node pool
  remove_default_node_pool = true
  initial_node_count       = 1
  
  # Network configuration
  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name
  
  # IP allocation policy for VPC-native cluster
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "/16"
    services_ipv4_cidr_block = "/22"
  }
  
  # Security features
  enable_shielded_nodes = true
  enable_secure_boot   = true
  
  # Workload Identity
  workload_pool_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  
  # Monitoring and logging
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
    
    managed_prometheus {
      enabled = true
    }
  }
  
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }
  
  # Release channel
  release_channel {
    channel = "REGULAR"
  }
  
  # Maintenance policy
  maintenance_policy {
    recurring_window {
      start_time = "2024-01-01T02:00:00Z"
      end_time   = "2024-01-01T06:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SU"
    }
  }
  
  # Node auto-upgrade
  node_config {
    machine_type = "e2-standard-2"
    disk_size_gb = 100
    
    # OAuth scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only"
    ]
    
    # Metadata
    metadata = {
      disable-legacy-endpoints = "true"
    }
    
    # Labels
    labels = {
      environment = "production"
      app         = "enhanced-cicd"
    }
    
    # Tags
    tags = ["gke-node", "enhanced-cicd"]
  }
  
  depends_on = [google_project_service.required_apis]
}

# Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count
  
  # Autoscaling
  autoscaling {
    min_node_count = 2
    max_node_count = 10
  }
  
  # Management
  management {
    auto_repair  = true
    auto_upgrade = true
  }
  
  # Upgrade settings
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
  
  node_config {
    machine_type = var.machine_type
    disk_size_gb = 100
    disk_type    = "pd-ssd"
    
    # OAuth scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only"
    ]
    
    # Metadata
    metadata = {
      disable-legacy-endpoints = "true"
    }
    
    # Labels
    labels = {
      environment = "production"
      app         = "enhanced-cicd"
      node-type   = "application"
    }
    
    # Tags
    tags = ["gke-node", "enhanced-cicd"]
    
    # Taints for dedicated nodes
    taint {
      key    = "node-type"
      value  = "application"
      effect = "NO_SCHEDULE"
    }
  }
}

# Cloud SQL Instance (PostgreSQL)
resource "google_sql_database_instance" "postgres" {
  name             = "enhanced-cicd-postgres"
  database_version = "POSTGRES_15"
  region           = var.region
  
  settings {
    tier = "db-f1-micro"
    
    backup_configuration {
      enabled    = true
      start_time = "02:00"
      
      point_in_time_recovery {
        enabled = true
      }
    }
    
    ip_configuration {
      ipv4_enabled    = true
      private_network = google_compute_network.vpc.id
    }
    
    maintenance_window {
      day          = 7
      hour         = 2
      update_track = "stable"
    }
  }
  
  deletion_protection = false
}

# PostgreSQL Database
resource "google_sql_database" "database" {
  name     = "enhanced_cicd_db"
  instance = google_sql_database_instance.postgres.name
}

# PostgreSQL User
resource "google_sql_user" "users" {
  name     = "appuser"
  instance = google_sql_database_instance.postgres.name
  password = random_password.db_password.result
}

# Random password for database
resource "random_password" "db_password" {
  length  = 16
  special = true
}

# Redis Memorystore
resource "google_redis_instance" "cache" {
  name           = "enhanced-cicd-redis"
  tier           = "BASIC"
  memory_size_gb = 1
  region         = var.region
  
  authorized_network = google_compute_network.vpc.id
  
  redis_configs = {
    maxmemory-policy = "allkeys-lru"
  }
}

# Cloud Storage Bucket for application logs
resource "google_storage_bucket" "logs_bucket" {
  name          = "${var.project_id}-enhanced-cicd-logs"
  location      = var.region
  force_destroy = true
  
  versioning {
    enabled = true
  }
  
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}

# IAM Service Account for GKE
resource "google_service_account" "gke_sa" {
  account_id   = "enhanced-cicd-gke-sa"
  display_name = "Enhanced CI/CD GKE Service Account"
}

# IAM roles for GKE service account
resource "google_project_iam_member" "gke_sa_roles" {
  for_each = toset([
    "roles/container.developer",
    "roles/storage.objectViewer",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter"
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

# Outputs
output "cluster_name" {
  value = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  value = google_container_cluster.primary.endpoint
}

output "cluster_ca_certificate" {
  value = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

output "postgres_connection_name" {
  value = google_sql_database_instance.postgres.connection_name
}

output "redis_host" {
  value = google_redis_instance.cache.host
}

output "logs_bucket" {
  value = google_storage_bucket.logs_bucket.name
}
