# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

# EKS Outputs
output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "EKS cluster version"
  value       = module.eks.cluster_version
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

# Application Outputs
output "app_namespace" {
  description = "Application namespace"
  value       = "sre-app"
}

output "app_deployment_command" {
  description = "Command to deploy the application"
  value       = "kubectl apply -k ../k8s/app/"
}

# # Monitoring Outputs
# output "grafana_url" {
#   description = "Grafana dashboard URL"
#   value       = module.monitoring.grafana_url
# }
#
# output "grafana_admin_user" {
#   description = "Grafana admin username"
#   value       = "admin"
# }
#
# output "grafana_admin_password" {
#   description = "Grafana admin password"
#   value       = local.grafana_password
#   sensitive   = true
# }
#
# output "prometheus_url" {
#   description = "Prometheus URL"
#   value       = module.monitoring.prometheus_url
# }

# AWS Region
output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

# Environment
output "environment" {
  description = "Environment name"
  value       = local.environment
}

# Kubeconfig Command
output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# Cost Estimation
output "estimated_monthly_cost" {
  description = "Estimated monthly cost (USD)"
  value       = <<-EOT
    EKS Control Plane: $73/month
    EC2 Nodes (${local.selected_node_config.desired_size}x ${local.selected_node_config.instance_types[0]}): ~$${local.selected_node_config.use_spot ? 30 * local.selected_node_config.desired_size : 60 * local.selected_node_config.desired_size}/month
    Load Balancers: ~$20/month
    NAT Gateway: ~$32/month
    Data Transfer: ~$10/month
    Total: ~$${135 + (local.selected_node_config.use_spot ? 30 : 60) * local.selected_node_config.desired_size}/month
    
    Per 30-min demo: ~$0.10-0.15
  EOT
}

# Quick Start Commands
output "quick_start" {
  description = "Quick start commands"
  value       = <<-EOT
    # Update kubeconfig
    aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}
    
    # Verify cluster
    kubectl get nodes
    kubectl get pods -A
    
    # Deploy Application
    kubectl apply -k ../k8s/app/
    
    # Get Application URL
    kubectl get svc sre-app -n sre-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
    
    # Run load test
    k6 run load-tests/spike-test.js
  EOT
  sensitive   = true
}
