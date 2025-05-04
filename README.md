# Remote Rsync Backup and Restore Scripts

This repository provides two simple yet powerful Bash scripts for handling remote Linux server backups and restorations using `rsync` over SSH.

---

## 🔄 `remote_backup.sh`

This script is designed to back up a remote Linux server to a local directory using `rsync`.  

### Features

- Preserves file attributes (`-aHAXSzx`)
- Supports incremental backups using `--link-dest`
- Excludes runtime and volatile system directories (e.g. `/proc`, `/sys`, `/run`, etc.)
- Compresses during transfer (`-z`)
- Customisable exclude list
- Allows Pre and Post scripts to run before or after the rsync (if needed)
- Can use a custom external `backup-exclude.list` file as rsync exclusion paths, if present

#### Notes about RSYNC Exclusions

There are difference between `*`, `**`, and `***` in rsync. Here the explanation:

- `*` — matches anything except a slash (`/`) in a single directory level.
- `**` — matches any number of directory levels, including `/`.
- `***` — a special rsync pattern: like `**`, but also follows symlinked directories.


### Usage

Edit the script and set/review (at least) the following variables:
```bash
REMOTE_SERVERS_LIST='remote1.example.com remote2.example.com'
BKP_MAIN_PATH='/mnt/backup/hosts'
BKP_REL_PATH='rsync_host_bkp'
```
There are other variables that can be set (e.g. `VAR_LOG_TREE_ONLY` or `RSYNC_FLAGS`), but it's all documented within the script.  

*OPTIONAL*: update/delete the file `backup-exclude.list`. This file override the `EXCLUDE_LIST` variable within the script, if present.  

Once all set, you can run the script, without any flag or options:

```bash
./remote_backup.sh
```

You can schedule the script to run using `cron`. You can use `remote_backup_cron` as sample config into `/etc/cron.d/` folder.  

---

## ♻️ `restore_backup.sh`

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