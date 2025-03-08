#!/bin/bash
set -e

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or use sudo."
    exit 1
fi

# Fetch the public IP from AWS EC2 instance metadata
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
DOMAIN="$PUBLIC_IP"
echo "Using public IP as domain: $DOMAIN"

# Check if Docker is installed
if command -v docker >/dev/null 2>&1; then
    echo "Docker is already installed."
else
    echo "Docker not found. Installing Docker..."
    apt-get update
    # Simple installation; for production consider using Docker’s official repo
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker
fi

# Check if code-server is installed
if command -v code-server >/dev/null 2>&1; then
    echo "code-server is already installed."
else
    echo "code-server not found. Installing code-server..."
    # The official installer script from code-server
    curl -fsSL https://code-server.dev/install.sh | sh
fi

# Define paths for the certificate and key
CRT_PATH="/etc/ssl/certs/code-server.crt"
KEY_PATH="/etc/ssl/private/code-server.key"

# Generate a self-signed HTTPS certificate if it doesn't exist
if [ -f "$CRT_PATH" ] && [ -f "$KEY_PATH" ]; then
    echo "HTTPS certificate already exists."
else
    echo "Generating self-signed HTTPS certificate..."
    # Adjust the -subj value if needed; here we set the Common Name (CN) to your domain.
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout "$KEY_PATH" \
      -out "$CRT_PATH" \
      -subj "/CN=${DOMAIN}"
fi

# Configure code-server to use HTTPS
# The config file is expected at /etc/code-server/config.yaml.
CONFIG_FILE="/etc/code-server/config.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Creating code-server configuration file..."
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" <<EOF
bind-addr: 0.0.0.0:8080
cert: $CRT_PATH
cert-key: $KEY_PATH
auth: password
password: changeme
EOF
    echo "A default password 'changeme' is set in $CONFIG_FILE. Please change it after installation."
else
    echo "code-server config file already exists at $CONFIG_FILE."
    echo "Ensure it contains the correct certificate paths (cert: $CRT_PATH and cert-key: $KEY_PATH)."
fi

# Restart and enable code-server service (if installed as a systemd service)
if systemctl list-units --type=service | grep -q "code-server"; then
    systemctl restart code-server
    systemctl enable code-server
    echo "code-server has been restarted and enabled on boot."
else
    echo "code-server systemd service not found. Please check your installation."
fi

echo "Installation complete. You can now access code-server at:"
echo "https://${DOMAIN}:8080"
