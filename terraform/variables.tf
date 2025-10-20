# AWS Configuration
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
  default     = "sre-showcase"
}

variable "environment" {
  description = "Environment name (demo, dev, staging, prod)"
  type        = string
  default     = "demo"
}

# Networking
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# EKS Configuration
variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
}

variable "enable_spot_instances" {
  description = "Use spot instances for cost savings"
  type        = bool
  default     = true
}

variable "node_instance_types" {
  description = "EC2 instance types for EKS nodes"
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 3
}

# Application Configuration
variable "github_repo" {
  description = "GitHub repository for container images"
  type        = string
}

variable "app_image_tag" {
  description = "Docker image tag for the application"
  type        = string
  default     = "latest"
}

# Monitoring Configuration
variable "slack_webhook_url" {
  description = "Slack webhook URL for alerts"
  type        = string
  sensitive   = true
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana (auto-generated if not provided)"
  type        = string
  default     = ""
  sensitive   = true
}

# Tags
variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

# Locals for environment-specific configurations
locals {
  # Workspace-based environment configuration
  environment = terraform.workspace == "default" ? var.environment : terraform.workspace

  # Environment-specific node configurations
  node_config = {
    demo = {
      desired_size   = 2
      min_size       = 1
      max_size       = 3
      instance_types = ["t3.small"]
      use_spot       = true
    }
    dev = {
      desired_size   = 2
      min_size       = 1
      max_size       = 4
      instance_types = ["t3.small"]
      use_spot       = true
    }
    staging = {
      desired_size   = 2
      min_size       = 2
      max_size       = 5
      instance_types = ["t3.medium"]
      use_spot       = true
    }
    prod = {
      desired_size   = 3
      min_size       = 3
      max_size       = 10
      instance_types = ["t3.medium"]
      use_spot       = false
    }
  }

  # Select configuration based on environment
  selected_node_config = local.node_config[local.environment]

  # Common tags
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = local.environment
      ManagedBy   = "Terraform"
      Repository  = var.github_repo
    },
    var.tags
  )

  # Cluster name
  cluster_name = "${var.project_name}-${local.environment}"

  # Generate Grafana password if not provided
  grafana_password = var.grafana_admin_password != "" ? var.grafana_admin_password : random_password.grafana_password.result
}
