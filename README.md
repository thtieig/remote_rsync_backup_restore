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

### Usage

```bash
./remote_backup.sh user@remote_host:/ /path/to/local/backup
```

You can optionally specify a `--link-dest` for incremental hard-link based backups.

---

## ♻️ `restore_backup.sh`

This script restores a backup from a local directory to a target VPS over SSH, **while carefully excluding system-specific paths** that should not be overwritten.

### Features

- Excludes paths like `/boot`, `/etc/fstab`, `/etc/ssh/ssh_host_*`, etc.
- Supports `--dry-run` mode for previewing changes
- Verbose output with `-v`
- Built-in sanity check for typical backup structure (`etc`, `usr`, `bin`, `var`)
- Prompts before proceeding with destructive sync
- Automatically reboots the target VPS on successful restore

### Usage

```bash
./restore_backup.sh [--dry-run] /full/path/to/backup-source VPS_IP
```

Example:

```bash
./restore_backup.sh --dry-run /mnt/backup 192.168.1.100
```

> 🛑 Be cautious: this script will delete files on the VPS that aren't in the backup, except those explicitly excluded.

---

## ⚠️ Requirements

- `rsync` must be installed on both local and remote machines
- SSH access with root privileges or password-less `sudo`

---

## 📁 License

This project is distributed under the MIT License.