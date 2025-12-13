# ECR Repositories for Application CI/CD

# ECR Repository for Docker images
resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.project_name}-app"
    Environment = var.environment
    Purpose     = "Docker images for application"
  }
}

# ECR Repository for Helm charts (OCI format)
resource "aws_ecr_repository" "helm" {
  name                 = "${var.project_name}-helm"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false  # Helm charts don't need security scanning
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.project_name}-helm"
    Environment = var.environment
    Purpose     = "Helm charts (OCI format)"
  }
}

# Lifecycle policy for Docker images - keep only recent images
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "main", "sha"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Lifecycle policy for Helm charts - keep more versions
resource "aws_ecr_lifecycle_policy" "helm" {
  repository = aws_ecr_repository.helm.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 20 chart versions"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
