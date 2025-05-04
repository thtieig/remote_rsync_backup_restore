#!/usr/bin/env bash
#
# restore_backup.sh — mirror backup to VPS, excluding paths that must stay VPS-native
#
# Usage: ./restore_backup.sh [--dry-run] /full/path/to/backup-source VPS_IP
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

# Default: dry_run is off
dry_run=false

# Check for --dry-run flag
if [[ "$1" == "--dry-run" ]]; then
  dry_run=true
  shift
fi

# Expect exactly two arguments now: source and destination IP
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 [--dry-run] /path/to/backup-source VPS_IP"
  exit 1
fi

BACKUP_SRC="$1/"
VPS_IP="$2"
DEST="root@${VPS_IP}:/"

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


RSYNC_FLAGS=(
  -aHAXSzx
  -v
  --delete

  # never touch the VPS's own boot, modules, initramfs
  --exclude='/boot/***'
  --exclude='/lib/modules/***'
  --exclude='/usr/lib/modules/***'
  --exclude='/etc/initramfs-tools/***'

  # keep the VPS fstab & grub
  --exclude='/etc/fstab'
  --exclude='/etc/default/grub'

  # machine-specific IDs & SSH host keys
  --exclude='/etc/machine-id'
  --exclude='/etc/ssh/ssh_host_*'

  # ignore all runtime and virtual filesystems
  --exclude='/dev/***'
  --exclude='/proc/***'
  --exclude='/sys/***'
  --exclude='/run/***'
  --exclude='/tmp/***'
  --exclude='/mnt/***'
  --exclude='/media/***'
  --exclude='/lost+found/***'
)


# Dry-run or actual execution
if $dry_run; then
  echo "Performing dry-run rsync to ${VPS_IP}..."
  rsync "${RSYNC_FLAGS[@]}" --dry-run -e ssh "$BACKUP_SRC" "$DEST"
  echo "Dry-run complete. Remove --dry-run to execute for real."
else
  echo "About to start the rsync. Please review the following command before pressing any key to proceed"
  echo ""
  echo "rsync \"${RSYNC_FLAGS[@]}\" -e ssh \"$BACKUP_SRC\" \"$DEST\""
  echo ""
  read -p "DO YOU WANT TO PROCEED? [y/N]: " answer
  if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi
  echo "Starting rsync to ${VPS_IP}..."
  rsync "${RSYNC_FLAGS[@]}" -e ssh "$BACKUP_SRC" "$DEST" \
    && echo "Rsync completed, rebooting ${VPS_IP}..." \
    && ssh root@"${VPS_IP}" 'reboot'
fi
