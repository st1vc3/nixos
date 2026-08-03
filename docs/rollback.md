# Rollback and recovery

NixOS generations are the primary rollback mechanism. They restore the built
system, including system packages, services, kernels, boot entries, and the
Home Manager generation activated by this configuration. They do not revert the
Git checkout or arbitrary mutable files.

Snapper complements generations by retaining mutable files from the root Btrfs
subvolume. It does not snapshot the separate `/home`, `/nix`, or `/var/log`
subvolumes and is not a backup against disk failure.

## Safe rebuild workflow

Activate a candidate configuration without making it the boot default:

```bash
rebuild_test
```

Test the desktop, networking, user services, and any changed hardware behavior.
If the candidate is broken, reboot to return to the last permanent generation.
Once it is satisfactory, make it permanent:

```bash
rebuild
```

Both helpers use `~/nixos#nixos` and refresh Zsh's command cache after a
successful activation.

## Roll back a running system

List the generations retained by the system profile:

```bash
generations
```

Switch to the generation immediately preceding the current system profile:

```bash
rollback_system
```

The underlying command is `sudo nixos-rebuild switch --rollback`. It activates
the previous generation and makes it the boot default.

To select a specific generation instead, replace `GENERATION` with a number from
the generation list:

```bash
sudo nix-env --profile /nix/var/nix/profiles/system --switch-generation GENERATION
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

This changes system state, but it does not change the files in `~/nixos`.
Revert or fix the Git checkout separately before the next rebuild, otherwise the
next `rebuild` can reintroduce the broken configuration.

## Recover when the newest generation does not boot

At the systemd-boot menu, select an older NixOS generation. Ten boot generations
are retained by `boot.loader.systemd-boot.configurationLimit`.

After the older generation boots, inspect the generation list and use the
specific-generation commands above to make the chosen generation permanent.
Then repair or revert the repository before rebuilding.

## Recover an individual mutable root file

List the available root snapshots:

```bash
snapper -c root list
```

Files from snapshot `NUMBER` appear below `/.snapshots/NUMBER/snapshot`. Inspect
and copy only the required file rather than replacing the complete root:

```bash
sudo diff -u /etc/example.conf /.snapshots/NUMBER/snapshot/etc/example.conf
sudo cp --preserve=all /.snapshots/NUMBER/snapshot/etc/example.conf /etc/example.conf
```

Do not use this method for `/home`, `/nix`, or `/var/log`; those paths are
separate subvolumes and are absent from root snapshots. Important user data
needs an independent backup stored on another device or host.
