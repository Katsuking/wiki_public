#!/usr/bin/env bash
set -euo pipefail

# --- Configuration (Only update this section) ---
USB_MOUNT_POINT="/mnt/usb"
BACKUP_SUBDIR="garage_backups"
RETENTION_COUNT=7

# Dynamically generated paths
BACKUP_ROOT="${USB_MOUNT_POINT}/${BACKUP_SUBDIR}"
DATE="$(date +%Y%m%d_%H%M%S)"
DEST_DIR="${BACKUP_ROOT}/${DATE}"
ARCHIVE_NAME="garage_backup_${DATE}.tar.gz"

GARAGE_CONF="/etc/garage.toml"
GARAGE_META="/var/lib/garage/meta"
WIREGUARD_CONF="/etc/wireguard"
SERVICE_NAME="garage"

# --- Pre-flight Checks ---
if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root (use sudo)." >&2
  exit 1
fi

if ! mountpoint -q "${USB_MOUNT_POINT}"; then
  echo "Error: USB drive is not mounted at ${USB_MOUNT_POINT}." >&2
  exit 1
fi

mkdir -p "${DEST_DIR}"

echo "=== Starting Backup: ${DATE} ==="

systemctl stop "${SERVICE_NAME}"
[[ -f "${GARAGE_CONF}" ]] && cp -p "${GARAGE_CONF}" "${DEST_DIR}/"
[[ -d "${WIREGUARD_CONF}" ]] && cp -a "${WIREGUARD_CONF}" "${DEST_DIR}/"
[[ -d "${GARAGE_META}" ]] && cp -a "${GARAGE_META}" "${DEST_DIR}/meta"
systemctl start "${SERVICE_NAME}"

tar -czf "${BACKUP_ROOT}/${ARCHIVE_NAME}" -C "${BACKUP_ROOT}" "${DATE}"
rm -rf "${DEST_DIR}"
chmod 600 "${BACKUP_ROOT}/${ARCHIVE_NAME}"

# Prune older archives
find "${BACKUP_ROOT}" -maxdepth 1 -name "garage_backup_*.tar.gz" -type f \
  | sort -r \
  | tail -n +$((RETENTION_COUNT + 1)) \
  | xargs -r rm -f

sync
echo "=== Backup completed: ${BACKUP_ROOT}/${ARCHIVE_NAME} ==="
