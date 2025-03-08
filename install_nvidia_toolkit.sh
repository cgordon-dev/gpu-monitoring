#!/bin/bash
set -e

# This script installs NVIDIA drivers (if needed) and the NVIDIA Container Toolkit.
# It assumes you are running on an Ubuntu EC2 instance with a supported NVIDIA GPU.
# Run this script as root (or using sudo).

# Ensure the script is run as root.
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or use sudo."
    exit 1
fi

echo "Checking for NVIDIA GPU drivers..."

if ! command -v nvidia-smi &> /dev/null; then
    echo "nvidia-smi not found. It appears NVIDIA drivers are not installed."
    echo "Attempting to install NVIDIA drivers via Ubuntu repository..."
    
    # Update package index and install drivers.
    apt-get update
    # Using ubuntu-drivers autoinstall will detect and install the recommended drivers.
    ubuntu-drivers autoinstall

    echo "NVIDIA drivers installed. A reboot might be required."
    echo "Please reboot your instance and re-run this script if nvidia-smi is still not found."
    sleep 5
fi

# Verify that nvidia-smi is now available.
if ! command -v nvidia-smi &> /dev/null; then
    echo "nvidia-smi still not available. Exiting."
    exit 1
fi

echo "GPU detected. Proceeding with NVIDIA Container Toolkit installation."

# Determine the Ubuntu distribution version for the NVIDIA Docker repository.
distribution=$(. /etc/os-release; echo "$ID$VERSION_ID")
echo "Detected distribution: $distribution"

# Add NVIDIA GPG key.
echo "Adding NVIDIA GPG key..."
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -

# Add the NVIDIA Docker repository.
echo "Adding NVIDIA Docker repository..."
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list

# Update package lists.
apt-get update

# Install the NVIDIA Container Toolkit.
echo "Installing NVIDIA Container Toolkit..."
apt-get install -y nvidia-docker2

# Restart the Docker daemon to apply changes.
echo "Restarting Docker daemon..."
systemctl restart docker

# Verify installation by running a test container.
echo "Verifying the NVIDIA Container Toolkit installation..."
docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi

echo "NVIDIA Container Toolkit installation completed successfully."