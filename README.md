# Remote Rsync Backup and Restore Scripts

This repository provides two simple yet powerful Bash scripts for handling remote Linux server backups and restorations using `rsync` over SSH.  
There are two folders:  

- `backup`: where you can find all the backup scripts/configs
- `restore`: where you can find, of course, the scripts/configs related to the restore  

Both scripts rely on `rsync` and its own way to manage **exclusions**. If you're not familiar on how rsync does that, here a little summary:  

There are difference between `*`, `**`, and `***` in rsync. Here the explanation:

- `*` — matches anything except a slash (`/`) in a single directory level.
- `**` — matches any number of directory levels, including `/`.
- `***` — a special rsync pattern: like `**`, but also follows symlinked directories.

You can find more information about **RSYNC EXCLUSIONS** in [here](rsync_exclusions.md)

These scripts are also using some *rsync flags* to perform the backup/restore. Here some clarifications:  

```
# Rsync options used:
   -a    archive mode: recurse and preserve symlinks, permissions, timestamps, group, owner
   -H    preserve hard links
   -E    preserves extended attributes (e.g., ACLs, SELinux attributes)
   -A    preserve ACLs (Access Control Lists)
   -X    preserves extended attributes (similar to E, but can be used in conjunction with E for compatibility with different systems)
   -S    handle sparse files efficiently
   -z    compress file data during the transfer
   -x    stay on one filesystem only
   --delete    ensures that files that no longer exist on the source are deleted from the destination
```

Also, I have hard coded `-v` to increase verbosity and the `--exclude-from` to pass the exclude files.  

---

## 🔄 remote_backup.sh

This script is designed to back up a remote Linux server to a local directory using `rsync`.  

### Features

- Preserves file attributes (`-aHAXSzx`)
- Excludes runtime and volatile system directories (e.g. `/proc`, `/sys`, `/run`, etc.)
- Compresses during transfer (`-z`)
- Customisable exclude list `backup-exclude.list` (if present)
- Allows Pre and Post scripts to run before or after the rsync (if needed)
- External `remote_backup_config.sh` config file - no changes on the main `remote_backup.sh` script are needed
- Can email in case of failure after multiple attempts of performin a backup


### Usage

1. Create a copy of `remote_backup_config.sh.example` and rename to `remote_backup_config.sh` in the same path of the script `remote_backup.sh`.  
Edit `remote_backup_config.sh` setting/reviewing (at least) the following variables:

```bash
REMOTE_SERVERS_LIST='remote1.example.com remote2.example.com'
BKP_MAIN_PATH='/mnt/backup/hosts'
BKP_REL_PATH='rsync_host_bkp'
```
There are other variables that can be set (e.g. `VAR_LOG_TREE_ONLY` or `RSYNC_FLAGS`), but it's all documented within the script.  

2. OPTIONAL: update/delete the file `backup-exclude.list`. This file, if present, overrides the `EXCLUDE_LIST` variable within the main script.

Once all set, you can run the script, without any flag or options:

```bash
./remote_backup.sh
```

You can schedule the script to run using `cron`. You can use `remote_backup_cron` as sample config into `/etc/cron.d/` folder.  

---

## ♻️ restore_backup.sh

This script restores a backup from a local directory to a target destination server over SSH, **while carefully excluding system-specific paths** that should not be overwritten.

### Features

- Excludes paths like `/boot`, `/etc/fstab`, `/etc/ssh/ssh_host_*`, etc..., unless the file `restore-exclude.list` is present. In this case, it will use the content of this file as reference and ignore the variable in the script.
- Supports `--dry-run` mode for previewing changes
- Verbose output with `-v`
- Built-in sanity check for typical backup structure (`etc`, `usr`, `bin`, `var`)
- Prompts before proceeding with destructive sync
- Automatically reboots the target destination server on successful restore
- Can use a custom external `restore-exclude.list` file as rsync exclusion paths, if present

### Usage

```bash
./restore_backup.sh [--dry-run] /full/path/to/backup-source DESTINATION_SERVER_IP
```

*OPTIONAL*: update/delete the file `restore-exclude.list`. This file override the `EXCLUDE_LIST` variable within the script, if present.  

Example:

```bash
./restore_backup.sh --dry-run /mnt/backup/hosts/server1/rsync_host_bkp 192.168.1.100
```

> 🛑 Be cautious: this script will delete files on the destination server that aren't in the backup, except those explicitly excluded.

---

## ⚠️ Requirements

- `rsync` must be installed on both local and remote machines
- SSH access with root privileges or password-less `sudo` 
- able to ssh as root@DESTINATION_SERVER_IP (test the ssh login before running the scripts)

---

## 📁 License

This project is distributed under the MIT License.