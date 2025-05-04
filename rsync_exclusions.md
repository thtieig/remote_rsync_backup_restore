# Further Clarifications on Rsync Exclusions

### Introduction

Rsync is a powerful tool for synchronising files and directories, and its exclusion mechanism is a key part of its functionality. Understanding how rsync handles exclusions is vital for effective use of the tool. This page provides further clarification and examples on the exclusion patterns used by rsync, along with visual representations of folder structures to illustrate the behaviour.

### Example Folder Structure

Let's consider the following folder structure as our example:

```
source/
├── file1.txt
├── file2.log
├── directory1
│   ├── file3.txt
│   ├── file4.log
│   └── subdirectory1
│       ├── file5.txt
│       └── file6.log
├── directory2
│   ├── file7.txt
│   └── link_to_directory1 (symlink to directory1)
└── directory3
    ├── file8.txt
    └── file9.log
```

### Exclusion Patterns

Rsync uses the following patterns to match files and directories for exclusion:

* `*` - Matches anything except a slash `/` in a single directory level.
* `**` - Matches any number of directory levels, including `/`.
* `***` - A special rsync pattern that behaves like `**` but also follows symbolic links to directories.

### Example 1: Excluding Files in the Current Directory

Suppose you want to exclude all `.txt` files in the current directory (`source/`) but not in any subdirectories. You can use the `*` pattern:

```bash
rsync -av --exclude='*.txt' source/ destination/
```

This will exclude `file1.txt` but not `directory1/file3.txt`, `directory1/subdirectory1/file5.txt`, `directory2/file7.txt`, or `directory3/file8.txt`.

```
destination/
├── file2.log
├── directory1
│   ├── file3.txt
│   ├── file4.log
│   └── subdirectory1
│       ├── file5.txt
│       └── file6.log
├── directory2
│   ├── file7.txt
│   └── link_to_directory1 (symlink to directory1)
└── directory3
    ├── file8.txt
    └── file9.log
```

### Example 2: Recursive Exclusion

To exclude **all** `.txt` files regardless of their location within the directory tree, you can use the `**` pattern:

```bash
rsync -av --exclude='**/*.txt' source/ destination/
```

This will exclude `file1.txt`, `directory1/file3.txt`, `directory1/subdirectory1/file5.txt`, `directory2/file7.txt`, and `directory3/file8.txt`.

```
destination/
├── file2.log
├── directory1
│   ├── file4.log
│   └── subdirectory1
│       └── file6.log
├── directory2
│   └── link_to_directory1 (symlink to directory1)
└── directory3
    └── file9.log
```

### Example 3: Excluding Files in Symlinked Directories

Consider a scenario where you want to exclude **all** `.txt` files **even within symlinked directories**. You can use the `***` pattern:

```bash
rsync -av --exclude='***/*.txt' source/ destination/
```

This will exclude `file1.txt`, `directory1/file3.txt`, `directory1/subdirectory1/file5.txt`, `directory2/file7.txt`, `directory3/file8.txt`, and also files within the symlinked directory (`link_to_directory1`).

```
destination/
├── file2.log
├── directory1
│   ├── file4.log
│   └── subdirectory1
│       └── file6.log
├── directory2
│   └── link_to_directory1 (symlink to directory1, but empty)
└── directory3
    └── file9.log
```

Note that even though `link_to_directory1` is a symlink, the `***` pattern follows it and excludes files within the linked directory.


### Some common mistakes

Even myself, creating the first version of these scripts, I felt into the *rsync trap*, thinking in a *bash way*.

Below some of the mistakes I made, and I had some help to have it fixed:

```
/dev/*              🔸 matches files in /dev but NOT subdirectories like /dev/pts/
                    ➤ You probably want: /dev/***
					
/media/*            🔸 same as /dev/* — doesn't match subfolders
                    ➤ Use: /media/***
					
/home/*/.cache/*    🔸 Will match `/home/user/.cache/file`  
                    ❌ Will NOT match `/home/user/.cache/somedir/file.txt`  
                    ➤ Use: `/home/*/.cache/***`

/swap*              ✅ matches /swap, /swapfile, /swapXYZ
/swapfile           🔸 redundant if /swap* is kept

/root/snap          ✅ excludes exactly /root/snap (dir or file)
                    ➤ To exclude contents: /root/snap/***

/core*              ✅ matches /core, /core1, /corefile but NOT /core/dir/file

/lock               ✅ if there's a /lock file or directory in the root
```

Let's also use another example, where I want to exclude the folder 'Acronis' in full:

```
/etc/Acronis/	    May still create empty dir

/etc/Acronis/*	    Excludes direct contents only

/etc/Acronis/**	    Excludes all contents recursively: ⮜ Use THIS

/etc/Acronis/***	✅ Excludes dir and all contents, including symlinks

/etc/Acronis***	    ❌ Invalid, matches e.g. /etc/Acronis_backup, not a directory

```
In this example, again, I need to use the `***` to be sure to exclude in full the `/etc/Acronis` folder from the sync.


### Conclusion

Understanding how rsync handles exclusions is crucial for using the tool effectively. By leveraging the `*`, `**`, and `***` patterns and visualising the folder structure, you can create complex exclusion rules to suit your needs. Remember to test your rsync commands with the `-n` or `--dry-run` option to see what would be transferred or excluded without actually performing the transfer.

### Additional Tips

- Always test your rsync commands with the `--dry-run` option before executing them to avoid unintended data transfer or deletion.
- Use the `--exclude` option multiple times to specify different exclusion patterns.
- Be cautious with the order of `--include` and `--exclude` options, as it can affect the outcome of your rsync operation.

By following these guidelines and examples, you can better utilise rsync's exclusion mechanisms to manage your file synchronisations efficiently.