variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS"
  type        = list(string)
}

variable "node_desired_size" {
  description = "Desired number of nodes"
  type        = number
}

variable "node_min_size" {
  description = "Minimum number of nodes"
  type        = number
}

variable "node_max_size" {
  description = "Maximum number of nodes"
  type        = number
}

variable "node_instance_types" {
  description = "EC2 instance types for nodes"
  type        = list(string)
}

variable "enable_spot_instances" {
  description = "Use spot instances"
  type        = bool
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "VPC CIDR block for security group rules"
  type        = string
}
