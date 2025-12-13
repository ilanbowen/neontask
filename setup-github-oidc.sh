#!/bin/bash

set -e

################################################################################
# GitHub Actions OIDC Setup Script for AWS
################################################################################
# This script sets up OIDC authentication for GitHub Actions to AWS
# - Creates OIDC Identity Provider in AWS
# - Creates IAM Role for GitHub Actions
# - Attaches permissions to the role
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ ${NC}$1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

echo ""
echo "================================================================================"
echo "          GitHub Actions OIDC Setup for AWS"
echo "================================================================================"
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed."
    exit 1
fi

# Check AWS credentials
print_info "Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured."
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_success "Authenticated to AWS Account: $ACCOUNT_ID"
echo ""

# Get GitHub repository information
echo "GitHub Repository Information:"
echo "------------------------------"
read -p "GitHub Organization/Username: " GITHUB_ORG
read -p "Repository Name: " REPO_NAME

# Validate inputs
if [[ -z "$GITHUB_ORG" || -z "$REPO_NAME" ]]; then
    print_error "GitHub organization and repository name are required."
    exit 1
fi

# IAM Role name
DEFAULT_ROLE_NAME="GitHubActionsRole"
read -p "IAM Role Name [$DEFAULT_ROLE_NAME]: " ROLE_NAME
ROLE_NAME=${ROLE_NAME:-$DEFAULT_ROLE_NAME}

echo ""
echo "================================================================================"
echo "Configuration Summary:"
echo "================================================================================"
echo "  AWS Account ID:     $ACCOUNT_ID"
echo "  GitHub Org/User:    $GITHUB_ORG"
echo "  Repository:         $REPO_NAME"
echo "  IAM Role Name:      $ROLE_NAME"
echo "  Full Repo Path:     ${GITHUB_ORG}/${REPO_NAME}"
echo "================================================================================"
echo ""

read -p "Proceed with setup? (yes/no): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]es$ ]]; then
    print_warning "Setup cancelled."
    exit 0
fi

echo ""

################################################################################
# Step 1: Create OIDC Provider
################################################################################

print_info "Step 1/3: Creating OIDC Identity Provider..."

OIDC_PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN" &>/dev/null; then
    print_warning "OIDC provider already exists: $OIDC_PROVIDER_ARN"
else
    aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 > /dev/null
    
    print_success "Created OIDC provider: $OIDC_PROVIDER_ARN"
fi

################################################################################
# Step 2: Create IAM Role with Trust Policy
################################################################################

print_info "Step 2/3: Creating IAM Role..."

# Create trust policy
TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_PROVIDER_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${REPO_NAME}:*"
        }
      }
    }
  ]
}
EOF
)

# Save trust policy to file
echo "$TRUST_POLICY" > /tmp/github-trust-policy.json

# Check if role exists
if aws iam get-role --role-name "$ROLE_NAME" &>/dev/null; then
    print_warning "IAM role already exists: $ROLE_NAME"
    print_info "Updating trust policy..."
    aws iam update-assume-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-document file:///tmp/github-trust-policy.json
    print_success "Updated trust policy for role: $ROLE_NAME"
else
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document file:///tmp/github-trust-policy.json \
        --description "Role for GitHub Actions to deploy infrastructure" > /dev/null
    print_success "Created IAM role: $ROLE_NAME"
fi

# Clean up temp file
rm /tmp/github-trust-policy.json

################################################################################
# Step 3: Attach Permissions
################################################################################

print_info "Step 3/3: Attaching permissions to role..."

echo ""
echo "Select permission level:"
echo "  1) AdministratorAccess (full access - for testing)"
echo "  2) Custom Terraform policy (recommended for production)"
echo ""
read -p "Choice [1]: " PERMISSION_CHOICE
PERMISSION_CHOICE=${PERMISSION_CHOICE:-1}

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

if [ "$PERMISSION_CHOICE" == "1" ]; then
    # Attach AdministratorAccess
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
    
    print_success "Attached AdministratorAccess policy"
    print_warning "Note: AdministratorAccess provides full AWS access. Consider using custom policy for production."
else
    print_info "Creating custom Terraform policy..."
    
    # Create custom policy
    POLICY_NAME="TerraformDeployPolicy"
    POLICY_DOCUMENT=$(cat <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformState",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::terraform-state-*",
        "arn:aws:s3:::terraform-state-*/*"
      ]
    },
    {
      "Sid": "TerraformLocking",
      "Effect": "Allow",
      "Action": [
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/terraform-state-lock"
    },
    {
      "Sid": "EC2Full",
      "Effect": "Allow",
      "Action": "ec2:*",
      "Resource": "*"
    },
    {
      "Sid": "EKSFull",
      "Effect": "Allow",
      "Action": "eks:*",
      "Resource": "*"
    },
    {
      "Sid": "IAMPermissions",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:GetRole",
        "iam:PassRole",
        "iam:TagRole",
        "iam:CreateServiceLinkedRole",
        "iam:ListAttachedRolePolicies"
      ],
      "Resource": "*"
    },
    {
      "Sid": "KMSPermissions",
      "Effect": "Allow",
      "Action": [
        "kms:CreateKey",
        "kms:CreateAlias",
        "kms:DeleteAlias",
        "kms:DescribeKey",
        "kms:EnableKeyRotation",
        "kms:GetKeyPolicy",
        "kms:ScheduleKeyDeletion",
        "kms:TagResource"
              ],
      "Resource": "*"
    }
  ]
}
EOF
)
    
    echo "$POLICY_DOCUMENT" > /tmp/terraform-policy.json
    
    # Create or update policy
    POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"
    
    if aws iam get-policy --policy-arn "$POLICY_ARN" &>/dev/null; then
        print_warning "Policy already exists: $POLICY_NAME"
    else
        aws iam create-policy \
            --policy-name "$POLICY_NAME" \
            --policy-document file:///tmp/terraform-policy.json \
            --description "Permissions for Terraform to deploy infrastructure" > /dev/null
        print_success "Created policy: $POLICY_NAME"
    fi
    
    # Attach policy to role
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "$POLICY_ARN"

    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
    
    print_success "Attached custom Terraform policy"
    
    rm /tmp/terraform-policy.json
fi

echo ""
echo "================================================================================"
echo "✓ Setup Complete!"
echo "================================================================================"
echo ""

################################################################################
# Print Configuration
################################################################################

echo "GitHub Actions Configuration:"
echo "-----------------------------"
echo ""
echo "Add this to your GitHub Actions workflow (.github/workflows/terraform.yml):"
echo ""
cat <<EOF
permissions:
  id-token: write
  contents: read

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${ROLE_ARN}
          aws-region: us-east-1
          
      - name: Verify AWS identity
        run: aws sts get-caller-identity
EOF

echo ""
echo "================================================================================"
echo ""
echo "Next Steps:"
echo "----------"
echo ""
echo "1. Copy the GitHub Actions workflow file:"
echo "   cp /mnt/user-data/outputs/.github/workflows/terraform-oidc.yml .github/workflows/"
echo ""
echo "2. Update the workflow file with your role ARN:"
echo "   Replace: YOUR_ACCOUNT_ID"
echo "   With:    $ACCOUNT_ID"
echo ""
echo "3. Commit and push to GitHub:"
echo "   git add .github/workflows/terraform-oidc.yml"
echo "   git commit -m 'Add GitHub Actions workflow'"
echo "   git push origin main"
echo ""
echo "4. The workflow will run automatically on push to main branch"
echo ""
echo "================================================================================"
echo ""

print_success "OIDC authentication is now configured!"
print_info "Role ARN: ${ROLE_ARN}"
print_info "Repository: ${GITHUB_ORG}/${REPO_NAME}"
echo ""