#!/bin/bash
set -e

# Prompt for the new admin username
read -rp "Enter the new admin username: " ADMIN_USER

# Update system
echo "[*] Updating system..."
apt update && apt -y upgrade

# Create new user if not exists
if id "$ADMIN_USER" &>/dev/null; then
    echo "[*] User $ADMIN_USER already exists."
else
    echo "[*] Creating user: $ADMIN_USER"
    adduser --gecos "" "$ADMIN_USER"
fi

# Add user to sudo group
usermod -aG sudo "$ADMIN_USER"

# Setup SSH keys for new user
echo "[*] Copying SSH keys from root to $ADMIN_USER..."
mkdir -p /home/$ADMIN_USER/.ssh
chmod 700 /home/$ADMIN_USER/.ssh

if [ -f /root/.ssh/authorized_keys ]; then
    cp /root/.ssh/authorized_keys /home/$ADMIN_USER/.ssh/
    chmod 600 /home/$ADMIN_USER/.ssh/authorized_keys
    chown -R $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.ssh
    echo "[*] Authorized keys copied successfully."
else
    echo "⚠️  No /root/.ssh/authorized_keys found! Make sure to add your SSH key manually."
fi

# Secure SSH config
echo "[*] Hardening SSH..."
SSHD_CONFIG="/etc/ssh/sshd_config"

# Backup SSH config
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak.$(date +%F_%T)"

# Disable root login, enforce key-based login, restrict users
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
grep -q "^AllowUsers" "$SSHD_CONFIG" && \
    sed -i "s/^AllowUsers.*/AllowUsers $ADMIN_USER/" "$SSHD_CONFIG" || \
    echo "AllowUsers $ADMIN_USER" >> "$SSHD_CONFIG"

# Restart SSH service
systemctl restart ssh

# Setup UFW firewall
echo "[*] Configuring UFW firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw --force enable

echo "[*] Hardening complete!"
echo "⚠️  Important: Open a second SSH session as $ADMIN_USER and run a sudo command before logging out root to confirm everything works!"
