#!/usr/bin/env bash
#
# restore_backup.sh — mirror backup to VPS, excluding paths that must stay VPS-native
#
# Usage: ./restore_backup.sh [--dry-run] /full/path/to/backup-source DESTINATION_SERVER_IP
#
# Flags:
#   --dry-run    perform a trial run with no changes made to destination
#   -v           verbose output for rsync
#
# Rsync options used:
#   -a    archive mode: recurse and preserve symlinks, permissions, timestamps, group, owner
#   -H    preserve hard links
#   -A    preserve ACLs
#   -X    preserve extended attributes
#   -S    handle sparse files efficiently
#   -z    compress file data during the transfer
#   -x    stay on one filesystem only
#   --delete    delete extraneous files from destination dirs
#   --exclude   do not copy or delete the specified patterns

# Custom rsync exclude file. If exists, it will be used. If not, it will use 
# the info found in EXCLUDE_LIST variable
EXCLUDE_LIST_FILE="restore-exclude.list"

# General Exclude List; The exclude list is space separated (multiple lines allowed)
# List ignored if EXCLUDE_LIST_FILE is present (even if empty!)
EXCLUDE_LIST='/boot/*** /lib/modules/*** /usr/lib/modules/*** /etc/initramfs-tools/*** 
/etc/fstab /etc/default/grub 
/etc/machine-id /etc/ssh/ssh_host_* 
/dev/*** /proc/*** /sys/*** /run/*** /tmp/*** /mnt/*** /media/*** /lost+found/***'

RSYNC_FLAGS=(
  -aHAXSzx
  -v
  --delete
)

BACKUP_SRC="$1/"
DESTINATION_SERVER_IP="$2"
DEST="root@${DESTINATION_SERVER_IP}:/"

# Expect exactly two arguments now: source and destination IP
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 [--dry-run] /path/to/backup-source DESTINATION_SERVER_IP"
  exit 1
fi

# Default: dry_run is off
dry_run=false

# Check for --dry-run flag
if [[ "$1" == "--dry-run" ]]; then
  dry_run=true
  shift
fi

# Basic sanity check: ensure source has common dirs (etc var usr bin)
missing=()
for dir in etc var usr bin; do
  if [[ ! -d "${BACKUP_SRC%/}/${dir}" ]]; then
    missing+=("${dir}")
  fi
done
if (( ${#missing[@]} )); then
  echo "Warning: backup source seems to be missing directories: ${missing[*]}"
  read -p "Proceed anyway? [y/N]: " answer
  if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi
fi

# Generate exclude list for rsync
# Set temporary file
EXCLUDE_FILE='/tmp/remote_restore_excludeme.file'

# Check if EXCLUDE_LIST_FILE exists
if [ -f "${EXCLUDE_LIST_FILE}" ]; then
  # Use EXCLUDE_LIST_FILE as the exclude file
  grep -vE "^#|^$" "${EXCLUDE_LIST_FILE}" > "${EXCLUDE_FILE}"
else
  # Generate exclude file from EXCLUDE_LIST variable
  echo "${EXCLUDE_LIST}" | tr " " "\n" | sed '/^\s*$/d' | sort > "${EXCLUDE_FILE}"
fi

# Dry-run or actual execution
if $dry_run; then
  echo "Performing dry-run rsync to ${DESTINATION_SERVER_IP}..."
  rsync "${RSYNC_FLAGS[@]}" --exclude-from="${EXCLUDE_FILE}" --dry-run -e ssh "$BACKUP_SRC" "$DEST"
  echo "Dry-run complete. Remove --dry-run to execute for real."
else
  echo "About to start the rsync. Please review the following command before pressing any key to proceed"
  echo ""
  echo "rsync \"${RSYNC_FLAGS[@]}\" --exclude-from="${EXCLUDE_FILE}" -e ssh \"$BACKUP_SRC\" \"$DEST\""
  echo ""
  read -p "DO YOU WANT TO PROCEED? [y/N]: " answer
  if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi
  echo "Starting rsync to ${DESTINATION_SERVER_IP}..."
  rsync "${RSYNC_FLAGS[@]}" --exclude-from="${EXCLUDE_FILE}" -e ssh "$BACKUP_SRC" "$DEST" \
    && echo "Rsync completed, rebooting ${DESTINATION_SERVER_IP}..." \
    && ssh root@"${DESTINATION_SERVER_IP}" 'reboot'
fi

# Clean up
rm -f "${EXCLUDE_FILE}"