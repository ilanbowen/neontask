variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-north-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "hello-world"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "hello-world-eks"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.34"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "node_instance_types" {
  description = "EC2 instance types for EKS nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_min_size" {
  description = "Minimum number of nodes in the EKS node group"
  type        = number
  default     = 2
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in the EKS node group"
  type        = number
  default     = 5
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in the EKS node group"
  type        = number
  default     = 2
}

variable "enable_rds" {
  description = "Enable RDS PostgreSQL database"
  type        = bool
  default     = false
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "rds_database_name" {
  description = "RDS database name"
  type        = string
  default     = "appdb"
}

variable "rds_username" {
  description = "RDS master username"
  type        = string
  default     = "appuser"
}

variable "rds_password" {
  description = "RDS master password (use AWS Secrets Manager in production)"
  type        = string
  sensitive   = true
  default     = "changeme123"
}

variable "github_runner_token" {
  type        = string
  description = "GitHub self-hosted runner registration token"
  sensitive   = true
}

variable "ci_iam_role_arn" {
  type        = string
  description = "IAM role ARN used by GitHub Actions to deploy to EKS"
}

