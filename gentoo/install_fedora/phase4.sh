#!/bin/bash
set -e

echo "Phase 4: Create directories and prepare DNF config"

mkdir -p /mnt/dev /mnt/proc /mnt/sys /mnt/run /mnt/tmp

mkdir -p /mnt/etc/dnf
cat >/mnt/etc/dnf/dnf.conf <<'EOF'
[main]
gpgcheck=True
installonly_limit=3
clean_requirements_on_remove=True
best=False
install_weak_deps=False
skip_if_unavailable=True
fastestmirror=True
max_parallel_downloads=10
EOF

mkdir -p /mnt/etc/yum.repos.d
for repo in /etc/yum.repos.d/fedora*.repo /etc/yum.repos.d/fedora-updates*.repo; do
  [[ -f "$repo" ]] && cp "$repo" /mnt/etc/yum.repos.d/
done

mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys
mount --bind /run /mnt/run
mount --bind /tmp /mnt/tmp

echo "Phase 4 completed successfully."
