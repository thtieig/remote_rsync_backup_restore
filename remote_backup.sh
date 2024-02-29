#!/bin/bash

# =============================================================================
# - title        : Backup script to create a copy of runnig linux boxes 
# - description  : Bash script that rsync's the content of a server(s) to a
#                  local folder. Using RSYNC you can restore the entire server
#                  to a new machine in one single run.
# - License      : GPLv3
# - author       : Chris Tian
# - date         : 2024-02-29
# - version      : 2.0
# - usage        : bash remote_backup.sh
# - OS Supported : Ubuntu, Debian, SUSE, Gentoo, RHEL, CentOS, Scientific, Arch
# - Credits      : Extracted from https://github.com/cloudnull/InstanceSync
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

###############################################################################

# NO NEED TO TOUCH BELOW HERE #

# Setting to use RSYNC version 3
RSYNC="$(which rsync)"


function GENEXCLUDELIST() {

# Append log folder to the EXCLUDE_LIST if flag is set to true
if ${VAR_LOG_TREE_ONLY} ; then
  EXCLUDE_LIST="${EXCLUDE_LIST} ${VAR_LOG_PATH}"  
fi

EXCLUDE_FILE='/tmp/remote_backup_excludeme.file'

echo "${EXCLUDE_LIST}" | tr " " "\n" | sed '/^\s*$/d' > "${EXCLUDE_FILE}"

sleep 2
}


function RUNRSYNCCOMMAND() {
  set +e
  MAX_RETRIES=${MAX_RETRIES:-5}
  RETRY_COUNT=0

  # Make sure destination path exists - if not, create
  [ -d ${BACKUP_LOC_PATH} ] || mkdir -p ${BACKUP_LOC_PATH}

  echo "Performing the rsync copy from ${REMOTE_SERVER} to ${BACKUP_LOC_PATH}"
  
  # Set the initial return value to failure
  false

  while [ $? -ne 0 -a ${RETRY_COUNT} -lt ${MAX_RETRIES} ];do
    RETRY_COUNT=$((${RETRY_COUNT}+1))
    
    echo "Running: ${RSYNC} -${RSYNC_FLAGS} --exclude-from=\"${EXCLUDE_FILE}\" \
                                        root@${REMOTE_SERVER}:/ ${BACKUP_LOC_PATH}/"
    ${RSYNC} -${RSYNC_FLAGS} --exclude-from="${EXCLUDE_FILE}" \
					root@${REMOTE_SERVER}:/ ${BACKUP_LOC_PATH}/
    
    if ${VAR_LOG_TREE_ONLY} ; then
      ${RSYNC} -${RSYNC_FLAGS}  -f"+ */" -f"- *" root@${REMOTE_SERVER}:${VAR_LOG_PATH}/ ${BACKUP_LOC_PATH}${VAR_LOG_PATH}/
    fi

    sleep 2
    echo "Copy completed."
  done

  if [ ${RETRY_COUNT} -ge ${MAX_RETRIES} ];then
    echo "ERROR: Hit maximum number of retries, giving up."
    echo "$0 script wasn't unable to complete. Please manually check" | mail -s "$0 ERROR" root
    exit 1
  fi

  unset MAX_RETRIES
  set -e
}

# -----------------------------------------------------------------------------------------------------------------
# If PRE_EXEC_SCRIPT is set, execute the script
[ ! -z "$PRE_EXEC_SCRIPT" ] && bash "$PRE_EXEC_SCRIPT"

# Exclude list generated - same for all servers
GENEXCLUDELIST

for server in $(echo "${REMOTE_SERVERS_LIST}") ; do
  REMOTE_SERVER=$server
  BACKUP_LOC_PATH="${BKP_MAIN_PATH}/${REMOTE_SERVER}/${BKP_REL_PATH}"
  echo "\n####################################################################################################"
  echo  ">>>> Running backup of $REMOTE_SERVER <<<<"
  echo "DEBUG: REMOTE_SERVER=$REMOTE_SERVER and BACKUP_LOC_PATH=$BACKUP_LOC_PATH"
  RUNRSYNCCOMMAND
done

# Clean up
rm -f "${EXCLUDE_FILE}"

# If POST_EXEC_SCRIPT is set, execute the script
[ ! -z "$POST_EXEC_SCRIPT" ] && bash "$POST_EXEC_SCRIPT"

