#!/bin/bash

# Define the target file and fixed settings
NETPLAN_FILE="/etc/netplan/50-cloud-init.yaml"
GATEWAY="192.168.0.1"
DNS_SERVER="192.168.0.1"
INTERFACE="ens18"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit
fi

echo "--- Network Setup Script ---"

# 1. Input: Ask for the new IP Address
read -p "Enter the desired IP address (e.g., 192.168.0.65): " NEW_IP

# 2. Backup: Check if file exists, backup, and echo content
if [ -f "$NETPLAN_FILE" ]; then
    echo "Found existing config. Backing up to $NETPLAN_FILE.bak"
    cp $NETPLAN_FILE "$NETPLAN_FILE.bak"
    
    echo "--- OLD CONFIG CONTENT ---"
    cat "$NETPLAN_FILE"
    echo "--------------------------"
else
    echo "Netplan file not found! Creating new one..."
fi

# 3. Write: Create the new configuration file
# Note: We are appending /24 automatically to the IP. 
# If you use different subnets, remove the '/24' below.

cat <<EOF > $NETPLAN_FILE
network:
  version: 2
  ethernets:
    $INTERFACE:
      addresses:
        - $NEW_IP/24
      nameservers:
        addresses:
          - $DNS_SERVER
      routes:
        - to: default
          via: $GATEWAY
EOF

echo "New configuration written to $NETPLAN_FILE."

# 4. Machine ID Fix (For Proxmox Clones)
echo "Resetting Machine ID for unique identification..."
rm -f /etc/machine-id
dbus-uuidgen --ensure=/etc/machine-id
rm -f /var/lib/dbus/machine-id
dbus-uuidgen --ensure

# 5. Apply
echo "Applying Netplan configuration..."
netplan apply

echo "Done! You can verify connectivity by pinging 1.1.1.1"
