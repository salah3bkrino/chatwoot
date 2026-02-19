#!/bin/bash

# Chatwoot KVM4 Setup Script for Hostinger VPS (Ubuntu 22.04/24.04)
# Run as root

set -e

# Update and Upgrade (essential for security)
apt-get update && apt-get upgrade -y

# Install essential tools
apt-get install -y curl wget git unzip htop ufw ntp

# Install Docker
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    usermod -aG docker $USER
    systemctl enable docker
    systemctl start docker
else
    echo "Docker is already installed."
fi

# Install Docker Compose (v2 is included with recent Docker installs as 'docker compose')
# If you need standalone docker-compose v1 (deprecated but sometimes needed):
# curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
# chmod +x /usr/local/bin/docker-compose

# Create Chatwoot Directory Structure
mkdir -p /opt/chatwoot
cd /opt/chatwoot
mkdir -p storage postgres_data redis_data

# Firewall Configuration (UFW)
echo "Configuring Firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp  # SSH
ufw allow 80/tcp  # HTTP
ufw allow 443/tcp # HTTPS
ufw --force enable

# Nginx reverse proxy setup (optional, if you want Nginx outside container handling SSL)
# For this setup, we will use Nginx inside Docker or Traefik, but let's prepare for Certbot if needed on host.
# apt-get install -y nginx certbot python3-certbot-nginx

echo "Setup Complete! Please log out and log back in."
