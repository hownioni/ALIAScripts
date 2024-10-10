# ALIAScripts

These scripts are mainly for me to be able to reproduce my setup in any computer I get my hands on.
Very heavily based on [easy-arch](https://github.com/classy-giraffe/easy-arch), please check it out!

## Install

### `bash <(curl -sL https://raw.githubusercontent.com/hownioni/ALIAScripts/master/install.sh)`

## Partitions layout

The **partitions layout** is the one I've always used for ext4:

1. A **FAT32** partition (1GiB), mounted at `/boot/`.
2. A **swap** partition, the size of which varies depending on if the device is a laptop or a desktop computer.
3. A **root** partition (32GiB), mounted at `/`. I think it's size is more than enough but if you disagree feel free to open an issue explaining why.
4. A **home** partition, mounted at `/home/`. It takes the rest of the available space in the disk.

| Partition Number | Size                                              | Mountpoint | Filesystem |
| ---------------- | ------------------------------------------------- | ---------- | ---------- |
| 1                | 1 GiB                                             | /boot/     | FAT32      |
| 2                | round(sqrt(RAM)) (plus your RAM if it's a laptop) | \[swap\]   | none       |
| 3                | 32GiB                                             | /          | ext4)      |
| 4                | Rest of the disk                                  | /home/     | ext4       |
