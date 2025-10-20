# Configure providers
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Generate random password for Grafana
resource "random_password" "grafana_password" {
  length  = 16
  special = true
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  environment        = local.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  tags = local.common_tags
}

# EKS Module
module "eks" {
  source = "./modules/eks"

  project_name    = var.project_name
  environment     = local.environment
  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  node_desired_size     = local.selected_node_config.desired_size
  node_min_size         = local.selected_node_config.min_size
  node_max_size         = local.selected_node_config.max_size
  node_instance_types   = local.selected_node_config.instance_types
  enable_spot_instances = local.selected_node_config.use_spot

  tags = local.common_tags

  depends_on = [module.vpc]
}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name,
      "--region",
      var.aws_region
    ]
  }
}

# Configure Helm provider
#provider "helm" {
#  kubernetes {
#    host                   = module.eks.cluster_endpoint
#    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
#
#    exec {
#      api_version = "client.authentication.k8s.io/v1beta1"
#      command     = "aws"
#      args = [
#        "eks",
#        "get-token",
#        "--cluster-name",
#        module.eks.cluster_name,
#        "--region",
#        var.aws_region
#      ]
#    }
#  }
#}

# Monitoring Module
#module "monitoring" {
#  source = "./modules/monitoring"
#
#  project_name      = var.project_name
#  environment       = local.environment
#  cluster_name      = local.cluster_name
#  slack_webhook_url = var.slack_webhook_url
#  grafana_password  = local.grafana_password
#
#  tags = local.common_tags
#
#  depends_on = [module.eks]
#}

# Ingress Module
#module "ingress" {
#  source = "./modules/ingress"
#
#  project_name       = var.project_name
#  environment        = local.environment
#  cluster_name       = local.cluster_name
#  vpc_id             = module.vpc.vpc_id
#  
#  tags = local.common_tags
#
#  depends_on = [module.eks]
#}
