#!/bin/bash

# =============================================================================
# - title        : Backup script to create a copy of runnig linux boxes 
# - description  : Bash script that rsync's the content of a server(s) to a
#                  local folder. Using RSYNC you can restore the entire server
#                  to a new machine in one single run.
#                  It can run PRE and POST scripts, if some actions are 
#                  required before or after the rsync.
# - License      : GPLv3
# - author       : Chris Tian
# - date         : 2025-05-05
# - version      : 3.0
# - usage        : bash remote_backup.sh
# - OS Supported : Ubuntu, Debian, SUSE, Gentoo, RHEL, CentOS, Scientific, Arch
# - Credits      : Ispired by https://github.com/cloudnull/InstanceSync
# =============================================================================

# ============
# REQUIREMENTS
# ============
# 
# - Scripts needs to run on the server that will store the backup
# - Current and Remote servers need 'rsync' installed
# - Remote server needs to allow ssh key auth for user 'root'
#   > test it using 'ssh root@${REMOTE_SERVER}' and make sure it works without
#   > asking for the password.

###############################################################################

# >>>> SET VARIABLES BELOW <<<< #

REMOTE_SERVERS_LIST='remote1.example.com remote2.example.com'

# Where to store the backup?
# BKP_MAIN_PATH/<server_name>/BKP_REL_PATH
BKP_MAIN_PATH='/space/backups/hosts'
BKP_REL_PATH='rsync_host_bkp'


# General Exclude List; The exclude list is space separated
EXCLUDE_LIST='/dev/* /proc/* /sys/* /run/* /tmp/* /lock
/media/* /lost+found /space/* /mnt/* 
/var/run/* /var/tmp/* /var/cache/apt/archives/*
/root/.cache/* /home/*/.cache/*
/core* /swap* /var/swap* /swapfile 
/usr/lib/Acronis /var/lib/Acronis /etc/Acronis /root/agent* /root/Acronis /root/snap'

# Enable/disable only folders tree sync of /var/log
# Default: true (bool)
VAR_LOG_TREE_ONLY=true

# Default /var/log path: modify only in case your servers use a different one
VAR_LOG_PATH="/var/log"

# Execute custom script before or after the sync
# Script runs on and from the backup server, not on the remote
# Add full path of the script in here (or leave empty)
PRE_EXEC_SCRIPT=''
POST_EXEC_SCRIPT=''

# Choose the rsync flags you prefer
# Default: aHEAXSzx --delete -v
RSYNC_FLAGS='aHEAXSzx --delete -v'
#RSYNC_FLAGS='aHEAXSzx --delete --delete-excluded -v'
#RSYNC_FLAGS='aHEAXSzx'
#RSYNC_FLAGS='av --delete'
#RSYNC_FLAGS='aHEAXSzx --progress'

# Maximum number of retries before giving up
MAX_RETRIES=5

###############################################################################

# NO NEED TO TOUCH BELOW HERE #

generate_exclude_list() {
  # Append log folder to the EXCLUDE_LIST if flag is set to true
  if $VAR_LOG_TREE_ONLY; then
    EXCLUDE_LIST="${EXCLUDE_LIST} ${VAR_LOG_PATH}"
  fi

  EXCLUDE_FILE='/tmp/remote_backup_excludeme.file'

  echo "${EXCLUDE_LIST}" | tr " " "\n" | sed '/^\s*$/d' > "${EXCLUDE_FILE}"
}

run_rsync_command() {
  local REMOTE_SERVER=$1
  local BACKUP_LOC_PATH=$2

  # Make sure destination path exists - if not, create
  mkdir -p "${BACKUP_LOC_PATH}" || {
    echo "Error creating directory: ${BACKUP_LOC_PATH}"
    exit 1
  }

  echo "Performing the rsync copy from ${REMOTE_SERVER} to ${BACKUP_LOC_PATH}"
  
  local retry_count=0
  while [ $retry_count -lt $MAX_RETRIES ]; do
    rsync -${RSYNC_FLAGS} --exclude-from="${EXCLUDE_FILE}" root@${REMOTE_SERVER}:/ "${BACKUP_LOC_PATH}/"
    
    if $VAR_LOG_TREE_ONLY; then
      rsync -${RSYNC_FLAGS} -f"+ */" -f"- *" root@${REMOTE_SERVER}:${VAR_LOG_PATH}/ "${BACKUP_LOC_PATH}${VAR_LOG_PATH}/"
    fi

    if [ $? -eq 0 ]; then
      break
    fi

    retry_count=$((retry_count + 1))
    sleep 2
  done

  if [ $retry_count -ge $MAX_RETRIES ]; then
    echo "ERROR: Hit maximum number of retries, giving up."
    echo "$0 script wasn't unable to complete. Please manually check" | mail -s "$0 ERROR" root
    exit 1
  fi
}

execute_pre_script() {
  if [ -n "$PRE_EXEC_SCRIPT" ]; then
    bash "$PRE_EXEC_SCRIPT"
  fi
}

execute_post_script() {
  if [ -n "$POST_EXEC_SCRIPT" ]; then
    bash "$POST_EXEC_SCRIPT"
  fi
}

# Generate exclude list
generate_exclude_list

# Execute pre script
execute_pre_script

for server in $REMOTE_SERVERS_LIST; do
  REMOTE_SERVER=$server
  BACKUP_LOC_PATH="${BKP_MAIN_PATH}/${REMOTE_SERVER}/${BKP_REL_PATH}"
  echo "\n####################################################################################################"
  echo ">>>> Running backup of $REMOTE_SERVER <<<<"
  echo "DEBUG: REMOTE_SERVER=$REMOTE_SERVER and BACKUP_LOC_PATH=$BACKUP_LOC_PATH"
  run_rsync_command "$REMOTE_SERVER" "$BACKUP_LOC_PATH"
done

# Clean up
rm -f "${EXCLUDE_FILE}"

# Execute post script
execute_post_script