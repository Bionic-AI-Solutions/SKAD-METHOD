FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Install docker-compose standalone (compose v2 comes via feature)
RUN apt-get update && apt-get install -y --no-install-recommends \
    docker-compose \
    && rm -rf /var/lib/apt/lists/*

# Ensure kube config directory exists
RUN mkdir -p /home/vscode/.kube && chown vscode:vscode /home/vscode/.kube
