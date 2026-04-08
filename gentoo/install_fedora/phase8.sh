#!/bin/bash
set -e

echo "Phase 8: Set passwords and create user"

chroot /mnt dnf install -y neovim wl-clipboard cracklib-dicts

# Set root password
chroot /mnt bash -c '
    if ! grep -q "^root:" /etc/shadow; then
        echo "root:*:19800:0:99999:7:::" >> /etc/shadow
    fi
    echo "Set root password:"
    read -s p1; echo
    read -s p2; echo
    if [ "$p1" != "$p2" ]; then
        echo "Password mismatch" >&2
        exit 1
    fi
    hash=$(openssl passwd -6 "$p1")
    sed -i "s|^root:[^:]*|root:$hash|" /etc/shadow
    echo "Root password set successfully"
'

# Create sudo user
read -p "Enter username for sudo user: " username
chroot /mnt useradd -m -G wheel,audio,video "$username"
chroot /mnt bash -c '
    touch /etc/shadow
    chmod 600 /etc/shadow
    username="$1"
    if ! grep -q "^$username:" /etc/shadow; then
        echo "$username:*:19800:0:99999:7:::" >> /etc/shadow
    fi
    echo "Set password for $username:"
    read -s p1; echo
    read -s p2; echo
    if [ "$p1" != "$p2" ]; then
        echo "Password mismatch" >&2
        exit 1
    fi
    hash=$(openssl passwd -6 "$p1")
    sed -i "s|^$username:[^:]*|$username:$hash|" /etc/shadow
    echo "Password for $username set successfully"
' -- "$username"

# Configure sudoers
chroot /mnt bash -c "EDITOR=nvim visudo"
echo "Please ensure %wheel ALL=(ALL) ALL is uncommented or added in nano, then save and exit."

echo "Phase 8 completed successfully."
