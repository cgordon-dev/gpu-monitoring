#!/bin/bash
# setup.sh - Install required system packages for the monitoring and DCGAN project

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Try running with sudo."
  exit 1
fi

echo "Updating package lists and upgrading existing packages..."
apt update && apt upgrade -y

##############################
# Install Docker & Docker Compose
##############################

echo "Installing Docker dependencies..."
apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg-agent

echo "Adding Docker's official GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "Setting up the Docker repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "Installing Docker Engine..."
apt update
apt install -y docker-ce docker-ce-cli containerd.io

echo "Installing Docker Compose..."
# Install docker-compose plugin if not available
if ! command -v docker-compose &> /dev/null; then
    apt install -y docker-compose
fi

# Optionally, add the current user to the docker group to run docker without sudo.
if id -nG "${SUDO_USER:-$USER}" | grep -qw "docker"; then
    echo "User is already in the docker group."
else
    echo "Adding user ${SUDO_USER:-$USER} to the docker group..."
    usermod -aG docker ${SUDO_USER:-$USER}
    echo "Please log out and log back in for group changes to take effect."
fi

##############################
# Install Python3 and Virtual Environment Tools
##############################

echo "Installing Python3, pip, and venv..."
apt install -y python3 python3-pip python3-venv

##############################
# (Optional) Install NVIDIA Docker Support
##############################
# Uncomment the following block if you plan to use GPU features (e.g. dcgm-exporter)
#: '
#echo "Setting up NVIDIA Docker support..."
#curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
#distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
#curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list
#apt update
#apt install -y nvidia-docker2
#systemctl restart docker
#'

echo "System setup completed successfully."