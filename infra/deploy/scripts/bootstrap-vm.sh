#!/usr/bin/env bash
# Optional: run once on a fresh Debian/Ubuntu VM to install Docker Engine + Compose plugin.
set -euo pipefail
if [[ "${EUID:-}" -ne 0 ]]; then
  echo "Run as root (e.g. sudo bash bootstrap-vm.sh)"
  exit 1
fi
apt-get update -y
apt-get install -y ca-certificates curl git
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${VERSION_CODENAME:-jammy}") stable" \
  >/etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
echo "Docker installed. Add your deploy user: usermod -aG docker <user>"
