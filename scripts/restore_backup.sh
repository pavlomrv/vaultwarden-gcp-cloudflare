#!/usr/bin/env bash

set -Eeuo pipefail

failure_handler() {
    local exit_code=$1
    local line_no=$2
    local failed_command=$3

    echo -e "\n💥 \033[0;31m[CRITICAL ERROR]\033[0m Restore script failed!" >&2
    echo "--------------------------------------------------" >&2
    echo "Failed on Line: $line_no" >&2
    echo "Failed Command: $failed_command" >&2
    echo "Exit Status:    $exit_code" >&2
    echo "--------------------------------------------------" >&2
    echo "⚠️  Restore halted." >&2
    echo "Please check your backup file (/var/vaultwarden/pre-restore-<timestamp>.tgz) and target directories." >&2
    echo "" >&2

    exit "$exit_code"
}
trap 'failure_handler $? $LINENO "$BASH_COMMAND"' ERR

show_usage() {
  local script_name
  script_name=$(basename "$0")

  cat << EOF
----------------------------------------------------------------------

Vaultwarden Data Restore Script

Restores Vaultwarden data from an encrypted backup stored in
Cloudflare R2. The script performs the following steps:

  1. Downloads the specified backup ZIP from R2.
  2. Stops Vaultwarden, Cloudflared, and backup containers.
  3. Creates a local safety snapshot (.tgz) of the current data.
  4. Extracts and restores the backup (you will be prompted for
     the zip password).
  5. Restarts all containers.

USAGE:
  CONFIRM=restore R2_BUCKET=<bucket> bash ./${script_name} [-h|--help] <backup-file.zip>

ARGUMENTS:
  <backup-file.zip>     The exact filename of the .zip backup in R2.
  -h, --help            Show this help message and exit.

REQUIRED ENVIRONMENT VARIABLES:
  R2_BUCKET             Cloudflare R2 bucket name where backups are stored.
  CONFIRM=restore       Safety flag — the script refuses to run without it.

PREREQUISITES:
  - Docker must be running.
  - A valid rclone config must exist at /var/vaultwarden-backup/rclone.conf
    with a remote named 'CloudflareR2'.

EXAMPLE:
  CONFIRM=restore R2_BUCKET=my-vw-backups \\
    bash ./${script_name} backup-20260601-000000.zip

IMPORTANT WARNING:
  This is a DESTRUCTIVE operation — it replaces the contents of
  /var/vaultwarden/data. A pre-restore snapshot is saved automatically
  at /var/vaultwarden/pre-restore-<timestamp>.tgz.
----------------------------------------------------------------------
EOF
}

if [[ $# -eq 0 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  show_usage
  exit 1
fi

BACKUP_FILE="$1"
CONFIRM="${CONFIRM:-}"
VAULTWARDEN_BACKUP_CONTAINER_HASH="" # Injected dynamically via sed during the VM startup process

# Check if VAULTWARDEN_BACKUP_CONTAINER_HASH was successfully injected
if [[ -z "${VAULTWARDEN_BACKUP_CONTAINER_HASH:-}" ]]; then
    echo "⚠️  WARNING: Container hash was not injected by the startup script."
    read -rp "Enter the container hash (sha256:...): " VAULTWARDEN_BACKUP_CONTAINER_HASH
fi

if [[ "$CONFIRM" != "restore" ]]; then
  echo "Error: Refusing to restore without CONFIRM=restore"
  show_usage
  exit 1
elif [[ -z "${R2_BUCKET:-}" ]]; then
  echo "Error: R2_BUCKET variable is not set. Nothing to restore."
  show_usage
  exit 1
fi

mkdir -p /var/vaultwarden/restore

echo "Downloading backup from R2..."
docker run --rm \
  --entrypoint rclone \
  -v /var/vaultwarden-backup/rclone.conf:/config/rclone/rclone.conf:ro \
  -v /var/vaultwarden/restore:/restore \
  ttionya/vaultwarden-backup@"${VAULTWARDEN_BACKUP_CONTAINER_HASH}" \
  copy \
  "CloudflareR2:/$R2_BUCKET/$BACKUP_FILE" \
  /restore

echo "Stopping containers..."
docker stop vaultwarden_backup cloudflared vaultwarden 2>/dev/null || true

echo "Taking local pre-restore snapshot..."
timestamp=$(date +%Y%m%d-%H%M%S)
tar -C /var/vaultwarden \
  -czf "/var/vaultwarden/pre-restore-$timestamp.tgz" \
  data
echo "Pre-restore snapshot saved at: '/var/vaultwarden/pre-restore-$timestamp.tgz'"

echo "Restoring backup..."
docker run --rm -it \
  -v /var/vaultwarden/data:/data \
  -v /var/vaultwarden/restore:/bitwarden/restore \
  -e DATA_DIR="/data" \
  ttionya/vaultwarden-backup@"${VAULTWARDEN_BACKUP_CONTAINER_HASH}" \
  restore \
  --force-restore \
  --zip-file "$BACKUP_FILE"

echo "Starting containers..."
docker start vaultwarden
docker start cloudflared
docker start vaultwarden_backup

echo "Restore complete. Check: docker logs vaultwarden"
