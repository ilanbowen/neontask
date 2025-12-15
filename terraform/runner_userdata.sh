#!/bin/bash
set -xe

# -----------------------------
# System basics (Ubuntu)
# -----------------------------
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
apt-get install -y \
  curl \
  unzip \
  git \
  jq \
  ca-certificates \
  apt-transport-https \
  lsb-release \
  gnupg \
  docker.io

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu || true

# -----------------------------
# Install AWS CLI v2
# -----------------------------
if ! command -v aws &> /dev/null; then
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  ./aws/install
fi

# -----------------------------
# Install kubectl (latest stable)
# -----------------------------
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/$${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# -----------------------------
# Install Helm (latest)
# -----------------------------
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# -----------------------------
# GitHub Actions runner setup
# -----------------------------
RUNNER_ROOT="/opt/github-runner"
mkdir -p "$RUNNER_ROOT"
chown ubuntu:ubuntu "$RUNNER_ROOT"

# Run the rest as ubuntu user
su - ubuntu << 'EOF'
set -xe

RUNNER_ROOT="/opt/github-runner"
cd "$RUNNER_ROOT"

# Download GitHub Actions runner
curl -L -o actions-runner-linux-x64.tar.gz \
  "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"

tar xzf actions-runner-linux-x64.tar.gz

chmod +x config.sh run.sh

# Configure runner (no sudo!)
./config.sh \
  --url "${GITHUB_URL}" \
  --token "${RUNNER_TOKEN}" \
  --labels "${RUNNER_LABEL}" \
  --unattended \
  --replace

EOF

# Back as root: install & start service
cd /opt/github-runner
chmod +x svc.sh || true
./svc.sh install
./svc.sh start

echo "GitHub Actions runner user_data completed."
