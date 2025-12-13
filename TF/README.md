# Terraform Infrastructure Configuration

This directory contains the Infrastructure as Code (IaC) configuration for deploying the complete AWS infrastructure.

## 📁 Files Overview

### Option 1: Modular Structure (Recommended for Production)

The Terraform configuration is split into logical files:

- **`main.tf`** - Provider configuration and authentication setup
- **`variables.tf`** - Input variables and their default values
- **`vpc.tf`** - VPC, subnets, NAT gateways, and networking
- **`eks.tf`** - EKS cluster, node groups, and KMS encryption
- **`rds.tf`** - Optional RDS PostgreSQL database
- **`outputs.tf`** - Output values from the infrastructure
- **`terraform.tfvars.example`** - Example variables file

### Option 2: Single File (Alternative)

If you prefer a single file configuration:

- **`terraform-consolidated.tf`** - All configurations in one file

## 🚀 Quick Start

### 1. Prerequisites

```bash
# Install Terraform
brew install terraform  # macOS
# or download from https://www.terraform.io/downloads

# Configure AWS credentials
aws configure
```

### 2. Initialize Terraform

```bash
cd terraform

# Download provider plugins
terraform init
```

### 3. Configure Variables

```bash
# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

Minimum required variables:
```hcl
aws_region   = "us-east-1"
environment  = "dev"
cluster_name = "my-eks-cluster"
```

### 4. Plan Infrastructure

```bash
# Preview changes
terraform plan
```

### 5. Deploy Infrastructure

```bash
# Apply changes (takes ~15-20 minutes)
terraform apply

# Or auto-approve (skip confirmation)
terraform apply -auto-approve
```

### 6. Configure kubectl

```bash
# Get the command from terraform output
terraform output configure_kubectl

# Or run directly
aws eks update-kubeconfig --region us-east-1 --name hello-world-eks
```

## 📋 What Gets Created

### Networking
- **VPC** (10.0.0.0/16)
  - 3 Public subnets (10.0.101.0/24, 10.0.102.0/24, 10.0.103.0/24)
  - 3 Private subnets (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24)
  - Internet Gateway
  - NAT Gateway(s) - 1 for dev, 2 for prod
  - Route tables
  - VPC Flow Logs

### Compute
- **EKS Cluster** (Kubernetes 1.28)
  - Control plane
  - Managed node groups (2-5 t3.medium instances)
  - KMS encryption for secrets
  - Cluster addons (CoreDNS, VPC CNI, EBS CSI)

### Security
- Security groups for EKS and optional RDS
- KMS keys for encryption
- IAM roles and policies
- Private subnets for workloads

### Optional Database
- RDS PostgreSQL instance (if `enable_rds = true`)
  - Multi-AZ capable
  - Automated backups
  - Encryption at rest

## 💰 Cost Estimation

### Development Environment (~$175/month)
```
EKS Control Plane:  $73/month
2x t3.medium nodes: $60/month
NAT Gateway:        $32/month
Data Transfer:      $10/month
```

### Production Environment (~$230-320/month)
```
EKS Control Plane:      $73/month
2-5x t3.medium nodes:   $60-150/month
2x NAT Gateways:        $64/month
RDS (optional):         $15/month
Data Transfer:          $20/month
```

## ⚙️ Configuration Options

### Key Variables

```hcl
# Basic Configuration
aws_region   = "us-east-1"        # AWS region
environment  = "dev"              # dev, staging, or prod
project_name = "hello-world"      # Project name prefix
cluster_name = "hello-world-eks"  # EKS cluster name

# Network Configuration
vpc_cidr             = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# EKS Configuration
kubernetes_version      = "1.28"
node_instance_types     = ["t3.medium"]
node_group_min_size     = 2
node_group_max_size     = 5
node_group_desired_size = 2

# Optional RDS
enable_rds           = false      # Set to true to create RDS
rds_instance_class   = "db.t3.micro"
rds_allocated_storage = 20
```

## 📤 Outputs

After deployment, Terraform provides these outputs:

```bash
# View all outputs
terraform output

# View specific output
terraform output cluster_name
terraform output cluster_endpoint

# Get kubectl configuration command
terraform output configure_kubectl
```

## 🔧 Common Operations

### View Current State

```bash
# List all resources
terraform state list

# Show specific resource
terraform state show module.eks.aws_eks_cluster.this[0]
```

### Update Infrastructure

```bash
# Modify variables in terraform.tfvars
# Then apply changes
terraform plan
terraform apply
```

### Scale Node Group

```bash
# Edit terraform.tfvars
node_group_desired_size = 3

# Apply changes
terraform apply
```

### Add RDS Database

```bash
# Edit terraform.tfvars
enable_rds = true

# Apply changes
terraform apply
```

## 🗑️ Cleanup

### Destroy All Resources

```bash
# Remove all infrastructure
terraform destroy

# Or with auto-approval
terraform destroy -auto-approve
```

**Warning**: This will delete:
- EKS cluster and all workloads
- VPC and all networking
- Any data in RDS (if enabled)
- All associated resources

## 🔒 Security Best Practices

### 1. State Management

For production, use remote state:

```hcl
# Uncomment in main.tf
backend "s3" {
  bucket         = "your-terraform-state-bucket"
  key            = "hello-world-app/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-state-lock"
}
```

### 2. Secrets Management

Don't commit sensitive values:

```bash
# Use environment variables
export TF_VAR_rds_password="secure-password"

# Or AWS Secrets Manager
# (modify rds.tf to use aws_secretsmanager_secret)
```

### 3. IAM Permissions

Required AWS permissions:
- VPC and Subnet management
- EKS cluster creation
- EC2 instances
- IAM roles and policies
- KMS key management
- RDS (if enabled)

## 🐛 Troubleshooting

### Error: "insufficient capacity"

```bash
# Try different instance types
node_instance_types = ["t3.medium", "t3a.medium"]
```

### Error: "subnet does not have enough IPs"

```bash
# Use larger CIDR blocks
private_subnet_cidrs = ["10.0.0.0/22", "10.0.4.0/22", "10.0.8.0/22"]
```

### Error: "cluster already exists"

```bash
# Import existing cluster
terraform import module.eks.aws_eks_cluster.this[0] cluster-name
```

### Stuck on "Still creating..." for EKS

This is normal! EKS cluster creation takes 15-20 minutes.

## 📚 Module Documentation

This configuration uses official Terraform AWS modules:

- [terraform-aws-modules/vpc/aws](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws)
- [terraform-aws-modules/eks/aws](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws)

## 🔗 Integration with Application

After Terraform completes:

1. **Configure kubectl**:
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name hello-world-eks
   ```

2. **Deploy application with Helm**:
   ```bash
   cd ../helm
   helm install hello-world-app ./hello-world-app
   ```

3. **Verify deployment**:
   ```bash
   kubectl get nodes
   kubectl get pods
   ```

## 📊 State File Structure

The Terraform state will contain:
- ~50+ resources in dev environment
- ~70+ resources in production environment
- Sensitive data (handle with care!)

## 🚀 Advanced Usage

### Multiple Environments

Create workspace per environment:

```bash
# Create workspaces
terraform workspace new dev
terraform workspace new prod

# Select workspace
terraform workspace select dev

# Apply environment-specific config
terraform apply -var-file="dev.tfvars"
```

### Custom VPC CIDR

```hcl
vpc_cidr = "172.16.0.0/16"
private_subnet_cidrs = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
public_subnet_cidrs  = ["172.16.101.0/24", "172.16.102.0/24", "172.16.103.0/24"]
```

### Spot Instances (Cost Savings)

Modify `eks.tf` to add spot instances:

```hcl
capacity_type = "SPOT"
instance_types = ["t3.medium", "t3a.medium", "t2.medium"]
```

## 📞 Support

For issues:
1. Check AWS service quotas
2. Verify IAM permissions
3. Review CloudWatch logs
4. Check Terraform state

## 🔄 Updates

To update Terraform or providers:

```bash
# Update provider versions
terraform init -upgrade

# Update modules
terraform get -update
```

---

**Note**: Always run `terraform plan` before `apply` to review changes!
