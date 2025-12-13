module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = data.aws_availability_zones.available.names
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway   = true
  single_nat_gateway   = var.environment == "dev" ? true : false
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Enable VPC Flow Logs
  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true

  # Custom names for route tables
  private_route_table_tags = {
    Name = "${var.project_name}-private-rt"
  }
  public_route_table_tags = {
    Name = "${var.project_name}-public-rt"
  }
  default_route_table_tags = {
    Name = "${var.project_name}-default-rt"
  }

  # Custom names for gateways
  igw_tags = {
    Name = "${var.project_name}-igw"
  }
  nat_gateway_tags = {
    Name = "${var.project_name}-nat-gw"
  }

  # Custom name for default security group
  default_security_group_tags = {
    Name = "${var.project_name}-default-sg"
  }

  # Kubernetes specific tags
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Add custom names to subnets using aws_ec2_tag resources
resource "aws_ec2_tag" "private_subnet_names" {
  count = length(module.vpc.private_subnets)

  resource_id = module.vpc.private_subnets[count.index]
  key         = "Name"
  value       = "${var.project_name}-private-az${count.index + 1}"
}

resource "aws_ec2_tag" "public_subnet_names" {
  count = length(module.vpc.public_subnets)

  resource_id = module.vpc.public_subnets[count.index]
  key         = "Name"
  value       = "${var.project_name}-public-az${count.index + 1}"
}

data "aws_availability_zones" "available" {
  state = "available"
}

