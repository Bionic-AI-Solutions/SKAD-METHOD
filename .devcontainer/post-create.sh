#!/usr/bin/env bash
set -e

echo "=== Post-create setup ==="

# Verify Docker connectivity to host
echo "Checking Docker..."
docker info > /dev/null 2>&1 && echo "Docker: connected to host daemon" || echo "Docker: NOT connected"

# Verify docker compose
echo "Checking Docker Compose..."
docker compose version 2>/dev/null || docker-compose --version 2>/dev/null || echo "Docker Compose: NOT found"

# Verify gh CLI
echo "Checking GitHub CLI..."
gh --version 2>/dev/null || echo "gh: NOT found"

# Verify kubectl and kubeconfig
echo "Checking kubectl..."
if kubectl version --client 2>/dev/null; then
  echo "kubectl: installed"
  if [ -f "$HOME/.kube/config" ]; then
    echo "kubeconfig: found"
    kubectl config get-contexts 2>/dev/null || echo "kubeconfig: present but no contexts configured"
  else
    echo "kubeconfig: NOT found at $HOME/.kube/config"
  fi
else
  echo "kubectl: NOT found"
fi

# Verify Node.js
echo "Checking Node.js..."
node --version 2>/dev/null || echo "Node.js: NOT found"
npm --version 2>/dev/null || echo "npm: NOT found"

# Verify Python
echo "Checking Python..."
python3 --version 2>/dev/null || echo "Python: NOT found"

# Install project dependencies
if [ -f "package.json" ]; then
  echo "Installing npm dependencies..."
  npm install
fi

echo "=== Setup complete ==="
