# Btrfs snapshots

Snapper creates read-only snapshots of the root subvolume in `/.snapshots`.
Because `/home`, `/nix`, and `/var/log` are separate Btrfs subvolumes, they are
not included in root snapshots. Snapshots are local recovery points, not
backups: disk failure removes both the live filesystem and its snapshots.

The configured retention is 24 hourly, 7 daily, 4 weekly, 6 monthly, and no
yearly timeline snapshots. Snapper also retains up to 10 ordinary numbered
snapshots and 10 snapshots marked important.

## Existing installation migration

Disko creates `@snapshots` automatically during a fresh installation. On a
machine installed before this subvolume was declared, create it once before
activating the configuration that mounts `/.snapshots`:

```bash
snapshot_fs_uuid=$(findmnt -no UUID /)
sudo mkdir -p /mnt/btrfs-root
sudo mount -o subvolid=5 "/dev/disk/by-uuid/$snapshot_fs_uuid" /mnt/btrfs-root
sudo btrfs subvolume create /mnt/btrfs-root/@snapshots
sudo umount /mnt/btrfs-root
sudo nixos-rebuild switch --flake ~/nixos#nixos
```

Before creating it, verify that `/mnt/btrfs-root/@snapshots` does not already
exist. If it does, unmount `/mnt/btrfs-root` and proceed directly to the rebuild.

## Routine commands

```bash
# List snapshots
snapper -c root list

# Create a named manual snapshot
snapper -c root create --description "before maintenance"

# Mark a snapshot as important so it uses the separate important limit
snapper -c root modify --userdata important=yes SNAPSHOT_NUMBER
```

See [`rollback.md`](rollback.md) for NixOS generation rollback, boot recovery,
and individual-file recovery from these snapshots.
