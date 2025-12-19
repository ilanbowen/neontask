# Optional: RDS PostgreSQL database (if var.enable_rds is true)
# For production, prefer using PostgreSQL in Kubernetes via Helm

resource "aws_db_subnet_group" "postgres" {
  count = var.enable_rds ? 1 : 0

  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

resource "aws_security_group" "rds" {
  count = var.enable_rds ? 1 : 0

  name_prefix = "${var.project_name}-rds-"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

resource "aws_security_group_rule" "rds_from_eks_nodes" {
  count = var.enable_rds ? 1 : 0

  type                     = "ingress"
  security_group_id        = aws_security_group.rds[0].id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = module.eks.node_security_group_id
  description              = "PostgreSQL from EKS nodes"
}

resource "aws_db_instance" "postgres" {
  count = var.enable_rds ? 1 : 0

  identifier     = "${var.project_name}-db"
  engine         = "postgres"
  engine_version = "15"
  instance_class = var.rds_instance_class
  publicly_accessible = false

  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.rds_database_name
  username = var.rds_username
  password = var.rds_password
  apply_immediately      = true   # ensures password change is applied now (otherwise waits for maintenance window)


  db_subnet_group_name   = aws_db_subnet_group.postgres[0].name
  vpc_security_group_ids = [aws_security_group.rds[0].id]

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  skip_final_snapshot       = var.environment == "dev"
  deletion_protection       = var.environment == "prod"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = {
    Name = "${var.project_name}-db"
  }
}

