#!/bin/bash
set -e

# Update the package index
echo "Updating package index..."
sudo apt-get update

# Install prerequisite packages
echo "Installing prerequisites..."
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common

# Add Docker’s official GPG key
echo "Adding Docker's GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Set up the stable Docker repository
echo "Adding Docker repository..."
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

# Update the package index again with Docker packages from the new repo
echo "Updating package index again..."
sudo apt-get update

# Install Docker Engine, CLI, and containerd
echo "Installing Docker..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Enable Docker to start on boot and start the Docker service
echo "Enabling and starting Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

# Optional: add current user to docker group to avoid using sudo with docker commands
echo "Adding user $USER to docker group..."
sudo usermod -aG docker "$USER"

echo "Docker has been installed and started."
echo "Please log out and log back in to apply the group changes, then you can run docker commands without sudo."