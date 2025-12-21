# Hello World on EKS (Flask + PostgreSQL) — CI/CD Demo

This repository demonstrates a simple end-to-end deployment of a web application to **AWS EKS** using **GitHub Actions**, **Amazon ECR**, and a **Helm chart**.

The application is a small **Flask** service that:
- shows a simple UI page at `/`
- allows users to submit a message
- stores messages in a **PostgreSQL database**
- retrieves and displays stored messages from the database

---

## What's in this repo

- `app/`  
  Flask application source code + Dockerfile.
- `hello-world-helm/`  
  Helm chart that deploys the app to Kubernetes (Deployment, Service, Secret, etc.).
- `terraform/`  
  Infrastructure as Code to provision AWS resources (VPC, EKS, RDS, EC2 GitHub runner).
- `.github/workflows/app-deploy.yml`  
  CI/CD pipeline: build image → package chart → validate → deploy.

---

## Prerequisites

- An AWS account with IAM credentials configured for CLI access (admin permissions recommended)
- A GitHub account
- `terraform` CLI installed on your local machine
- A GitHub Personal Access Token with appropriate permissions

---

## Setup Instructions

### GitHub Setup

1. **Fork this repository** to your own GitHub account

2. **Configure Repository Secrets**
   - Navigate to: Settings → Secrets and variables → Actions → Repository secrets
   - Create a new secret: `AWS_ACCOUNT_ID` with your AWS account ID as the value

3. **Prepare GitHub Runner Token**
   - Navigate to: Settings → Actions → Runners → New self-hosted runner
   - Choose 'Linux'
   - Under the 'Configure' section, **copy the token value** (you'll need this in step 7)
   
   > ⚠️ **Important**: This token expires in less than 1 hour. If more than 30 minutes pass before step 8, you'll need to generate a new token.

4. **Create GitHub Personal Access Token** (if you don't already have one)
   - This will be used to clone the repository

### Local Setup & Infrastructure Deployment

5. **Clone your forked repository**
```bash
   git clone https://<your-PAT>@github.com/<your-username>/neontask.git
   cd neontask/terraform
```

6. **Configure Terraform Variables**
   
   Edit `variables.tf` and update:
   - `external-source-ip` — Set to your current machine's external IP address
   - `github_org` — Set to your GitHub username or organization name

7. **Export the GitHub Runner Token**
```bash
   export TF_VAR_github_runner_token=<token-value-from-step-3>
```

8. **Deploy Infrastructure**
```bash
   terraform init
   terraform apply
```
   
   This creates:
   - VPC with public and private subnets
   - RDS PostgreSQL database (`hello-world-db`)
   - EKS cluster with managed node group
   - EC2 instance (GitHub Actions self-hosted runner) in private subnet
   
   After completion:
   - The EC2 runner should appear in your GitHub Actions Runners list with status "Idle"
   - Note the RDS endpoint from the Terraform output

### Application Configuration

9. **Create Database Connection String**
   
   Using the RDS endpoint from Terraform output, construct a string:
```
   postgresql+psycopg2://<rds_username>:<rds_password>@<rds-endpoint>:5432/<rds_database_name>?sslmode=require
```
   
10. **Configure Application Secret**
    - Navigate to: Settings → Secrets and variables → Actions → Repository secrets
    - Create a new secret: `DATABASE_URL` with the connection string from step 9

### Deploy the Application

11. **Trigger CI/CD Pipeline**
    - Navigate to: Actions → Application CI/CD → Run workflow → Run workflow

12. **Access the Application**
    - Click on Actions to view the running pipeline
    - Once the 'Deploy to EKS' job completes, click on it
    - Expand 'Get application URL'
    - Click the displayed URL to open the application in your browser

---

## Architecture

- **VPC**: Custom VPC with public and private subnets across multiple AZs
- **EKS**: Managed Kubernetes cluster running the application
- **RDS**: PostgreSQL database for persistent storage
- **ECR**: Container registry for Docker images
- **GitHub Actions**: CI/CD automation with self-hosted runner
- **Helm**: Kubernetes package management

---

## Cleanup

To destroy all AWS resources, follow these steps **in order**:

### Before running Terraform destroy

If you have run the CI/CD workflow, you must manually remove the following resources first:

1. **Uninstall the Helm release**
```bash
   helm uninstall hello-world-helm
```
   This removes the Kubernetes load balancer, associated security groups, and OIDC provider.

2. **Delete ECR repository images**
   
   Manually delete all images from the two ECR repositories created by Terraform.
   
   You can do this via AWS Console or CLI:
```bash
   # List images
   aws ecr list-images --repository-name hello-world-app
   
   # Delete all images
   aws ecr batch-delete-image \
     --repository-name hello-world-app \
     --image-ids "$(aws ecr list-images --repository-name hello-world-app --query 'imageIds[*]' --output json)"
```

### Destroy infrastructure

Once the above steps are complete:
```bash
cd terraform
terraform destroy
```

> ⚠️ **Important**: Skipping the manual cleanup steps will cause `terraform destroy` to fail.

---

> ⚠️ **Note**: Also remove the GitHub self-hosted runner from your repository settings (Settings → Actions → Runners) after infrastructure destruction.


---

