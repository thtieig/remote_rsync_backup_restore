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
# - version      : 3.2.2
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

# Get the directory where this script is located
SCRIPT_DIR=$(dirname "$0")

# Load config variables from config.sh
source "$SCRIPT_DIR/remote_backup_config.sh"

# Required fallback, in case EXCLUDE_LIST_FILE is not present
EXCLUDE_LIST='/dev/*** /proc/*** /sys/*** /tmp/*** /run/*** /mnt/*** /media/*** /lost+found/*** 
/root/.cache/*** 
/home/*/.cache/*** 
/core* 
/swap* /var/swap*'

# Name of the exclusion file
EXCLUDE_LIST_FILE="$SCRIPT_DIR/backup-exclude.list"

# Number of times that the script retries the backup before giving up
MAX_RETRIES=3

generate_exclude_list() {
  # Set temporary file
  EXCLUDE_FILE='/tmp/remote_backup_excludeme.file'

  # Check if EXCLUDE_LIST_FILE exists
  if [ -f "${EXCLUDE_LIST_FILE}" ]; then
    # Use EXCLUDE_LIST_FILE as the exclude file
    grep -vE "^#|^$" "${EXCLUDE_LIST_FILE}" > "${EXCLUDE_FILE}"
  else
    # Generate exclude file from EXCLUDE_LIST variable
    echo "${EXCLUDE_LIST}" | tr " " "\n" | sed '/^\s*$/d' | sort > "${EXCLUDE_FILE}"
  fi

  # Append log folder to the EXCLUDE_LIST if flag is set to true
  if [ "$VAR_LOG_TREE_ONLY" = "true" ]; then
    echo "${VAR_LOG_PATH}" >> "${EXCLUDE_FILE}"
  fi
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
    if [ -n "$SEND_ERROR_MAIL_TO" ]; then
      echo "$0 script wasn't able to complete. Please manually check" | mail -s "$0 ERROR" "$SEND_ERROR_MAIL_TO"
    fi
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
  echo -e "\n****************************************************************************"
  echo ">>>> Running backup of $REMOTE_SERVER <<<<"
  echo -e "\nFYI ;-) \n\tREMOTE_SERVER=$REMOTE_SERVER \n\tBACKUP_LOC_PATH=$BACKUP_LOC_PATH \n\tRSYNC_FLAGS=$RSYNC_FLAGS\n\n"
  echo -e "Starting in 5 seconds...\n"
  sleep 5
  run_rsync_command "$REMOTE_SERVER" "$BACKUP_LOC_PATH"
done

# Clean up
rm -f "${EXCLUDE_FILE}"

# Execute post script
execute_post_script