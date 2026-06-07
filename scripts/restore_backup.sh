#!/usr/bin/env bash

set -Eeuo pipefail

show_usage() {
  cat << EOF

Vaultwarden Restore Utility

The script will:
1. Stop running Vaultwarden and Cloudflared containers.
2. Create a local safety backup (.tgz) of the current state.
3. Download the specified backup ZIP from R2 and restore it.
   You will be prompted for the zip password.
4. Restart all containers.
---------------------------------------------------------------------
Usage:
  R2_BUCKET=<bucket> CONFIRM=restore $0 <backup-file.zip>

Required Arguments:
  <backup-file.zip>   The exact name of the .zip backup file stored in R2.

Required Environment Variables:
  R2_BUCKET           The Cloudflare R2 bucket name where backups live.
  CONFIRM=restore     A safety flag required to execute this destructive restore.
---------------------------------------------------------------------

EOF
}

if [[ $# -eq 0 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  show_usage
  exit 1
fi

BACKUP_FILE="$1"
CONFIRM="${CONFIRM:-}"
VAULTWARDEN_BACKUP_VERSION="" # This is set with a 'sed' command in the VM startup script

if [[ "$CONFIRM" != "restore" ]]; then
  echo "Error: Refusing to restore without CONFIRM=restore"
  show_usage
  exit 1
elif [[ -z "$R2_BUCKET" ]]; then
  echo "Error: R2_BUCKET variable is not set. Nothing to restore."
  show_usage
  exit 1
fi

mkdir -p /var/vaultwarden/restore

echo "Stopping containers..."
docker stop vaultwarden_backup cloudflared vaultwarden 2>/dev/null || true

echo "Downloading backup from R2..."
docker run --rm \
  --entrypoint rclone \
  -v /var/vaultwarden-backup/rclone.conf:/config/rclone.conf:ro \
  -v /var/vaultwarden/restore:/restore \
  ttionya/vaultwarden-backup:"${VAULTWARDEN_BACKUP_VERSION:-1.26.10}" \
  copy \
  "CloudflareR2:/$R2_BUCKET/$BACKUP_FILE" \
  /restore

echo "Taking local pre-restore snapshot..."
timestamp=$(date +%Y%m%d-%H%M%S)
tar -C /var/vaultwarden \
  -czf "/var/vaultwarden/pre-restore-$timestamp.tgz" \
  data
echo "Pre restore saved at: '/var/vaultwarden/pre-restore-$timestamp.tgz'"

echo "Restoring backup..."
docker run --rm -it \
  -v /var/vaultwarden/data:/data \
  -v /var/vaultwarden/restore:/bitwarden/restore \
  -e DATA_DIR="/data" \
  ttionya/vaultwarden-backup:"${VAULTWARDEN_BACKUP_VERSION:-1.26.10}" \
  restore \
  --force-restore \
  --zip-file "$BACKUP_FILE"

echo "Starting containers..."
docker start vaultwarden
docker start cloudflared
docker start vaultwarden_backup

echo "Restore complete. Check: docker logs vaultwarden"
