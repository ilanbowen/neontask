#!/bin/bash
set -xeuo pipefail

log() { echo "[$(date -Is)] $*"; }

# ----- retry helpers -----
apt_update() {
  for i in $(seq 1 30); do
    if apt-get update -y; then return 0; fi
    log "apt-get update failed, retrying ($i/30)..."
    sleep 10
  done
  return 1
}

apt_install() {
  # install packages passed as args, but avoid bash arrays in templatefile context
  for i in $(seq 1 20); do
    if apt-get install -y --no-install-recommends "$@"; then return 0; fi
    log "apt-get install failed, retrying ($i/20)..."
    sleep 10
  done
  return 1
}

# -----------------------------
# Base OS prep
# -----------------------------
export DEBIAN_FRONTEND=noninteractive

apt_update
apt_install ca-certificates curl gnupg lsb-release apt-transport-https unzip git jq

# -----------------------------
# Install Docker (official repo)
# -----------------------------
if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings

  # Docker GPG key
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  # Repo line uses $(dpkg --print-architecture) and $(. /etc/os-release; echo $VERSION_CODENAME)
  ARCH="$(dpkg --print-architecture)"
  CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"

  echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $CODENAME stable" \
    > /etc/apt/sources.list.d/docker.list

  apt_update
  apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu || true

# -----------------------------
# Install AWS CLI v2
# -----------------------------
if ! command -v aws >/dev/null 2>&1; then
  cd /tmp
  curl -sSLo awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
  unzip -q awscliv2.zip
  /tmp/aws/install
fi

# -----------------------------
# Install kubectl (latest stable)
# -----------------------------
if ! command -v kubectl >/dev/null 2>&1; then
  KUBECTL_VERSION="$(curl -L -s https://dl.k8s.io/release/stable.txt)"
  curl -sSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl"
  chmod +x /usr/local/bin/kubectl
fi

# -----------------------------
# Install Helm
# -----------------------------
if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# -----------------------------
# GitHub Actions runner setup
# -----------------------------
RUNNER_ROOT="/opt/github-runner"
mkdir -p "$RUNNER_ROOT"
chown ubuntu:ubuntu "$RUNNER_ROOT"

su - ubuntu << 'EOF'
set -xeuo pipefail

RUNNER_ROOT="/opt/github-runner"
cd "$RUNNER_ROOT"

# Values substituted by terraform templatefile:
GITHUB_URL="${GITHUB_URL}"
RUNNER_TOKEN="${RUNNER_TOKEN}"
RUNNER_LABEL="${RUNNER_LABEL}"
RUNNER_VERSION="${RUNNER_VERSION}"

# Download runner
curl -fsSL -o actions-runner-linux-x64.tar.gz \
  "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"

tar xzf actions-runner-linux-x64.tar.gz

chmod +x config.sh run.sh

./config.sh \
  --url "$GITHUB_URL" \
  --token "$RUNNER_TOKEN" \
  --labels "$RUNNER_LABEL" \
  --unattended \
  --replace
EOF

# Install & start service (root)
cd /opt/github-runner
chmod +x svc.sh || true
./svc.sh install
./svc.sh start

log "GitHub Actions runner user_data completed."
