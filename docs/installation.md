# NixOS installation with Disko

Target: physical machine, AMD CPU + NVIDIA GPU, UEFI, btrfs (unencrypted), Hyprland.

## 0. Before you boot

Confirm that `disko.nix` names the intended disk by its stable
`/dev/disk/by-id/...` path. Change it when installing on different hardware
(you can also do this live on the ISO). Everything else is ready to go.

## 1. Boot the NixOS minimal ISO

Download the **minimal ISO** from <https://nixos.org/download> and write it to a
USB stick (`dd if=nixos-minimal-*.iso of=/dev/diskN bs=4M` on macOS - unmount
the stick first, use the raw device `/dev/rdiskN` for speed).

Boot the target machine from it. In the machine's firmware, make sure it boots
in **UEFI** mode (not Legacy/CSM), and disable Secure Boot for now.

## 2. Get on the network + become root

```bash
sudo -i
# Wired: usually already up. Wi-Fi:
#   sudo systemctl start wpa_supplicant
#   wpa_cli   (then: add_network / set_network ... / enable_network)
ping -c1 nixos.org      # confirm connectivity
```

## 3. Identify the target disk

```bash
lsblk -o NAME,PATH,SIZE,TYPE,MODEL,SERIAL
ls -l /dev/disk/by-id/
```

Note the disk's `/dev/disk/by-id/...` symlink. Do not use a kernel-assigned name
such as `/dev/nvme0n1`, which can identify a different drive after reboot. This
disk will be **completely erased**.

## 4. Get the config

```bash
nix-shell -p git
git clone https://github.com/st1vc3/nixos /mnt-config
cd /mnt-config
```

Edit `disko.nix` so `device = "..."` matches the by-id path from step 3:

```bash
nano disko.nix
```

## 5. Partition + format + mount (disko)

First, confirm that the device evaluated from `disko.nix` is the disk you intend
to erase:

```bash
DISK=$(nix --extra-experimental-features "nix-command flakes" eval --raw \
  .#nixosConfigurations.nixos.config.disko.devices.disk.main.device)
printf 'Disko will completely erase: %s\n' "$DISK"
lsblk --output NAME,PATH,SIZE,MODEL,SERIAL,FSTYPE,MOUNTPOINTS "$DISK"
```

Only continue after checking the path, model, serial number, existing
filesystems, and mount points shown above. The following command is destructive:

```bash
# --mode destroy,format,mount wipes, creates, and mounts everything at /mnt
nix --extra-experimental-features "nix-command flakes" run .#disko -- \
  --mode destroy,format,mount \
  ./disko.nix
```

`.#disko` uses the exact Disko revision recorded in this repository's
`flake.lock`.

Verify:

```bash
mount | grep /mnt          # /, /home, /nix, /var/log, /boot should be there
```

## 6. Generate hardware config for THIS machine

```bash
nixos-generate-config --no-filesystems --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix ./hardware-configuration.nix
```

`--no-filesystems` is important: disko already declares the filesystems, so we
don't want a second, conflicting declaration.

While you're here, sanity-check `system.stateVersion` in `configuration.nix`
matches the NixOS release you're installing (the generated config shows it).

## 7. Install and set passwords

```bash
nixos-install --flake .#nixos
# It will prompt for the root password at the end.

# The declarative account starts locked, so choose its password before reboot.
nixos-enter --root /mnt -c 'passwd stivce'
```

The live environment's `/mnt-config` checkout disappears after reboot. Preserve
the exact edited checkout—including the generated hardware configuration and
the selected Disko device—in the installed system before continuing:

```bash
mkdir -p /mnt/var/lib/nixos
cp -a /mnt-config /mnt/var/lib/nixos/config-source
```

## 8. Reboot

```bash
reboot        # remove the USB stick
```

Log in as `stivce` with the password chosen in step 7. At the SDDM screen pick
the **Hyprland** session; `Super + Return` opens a terminal (Kitty).

## 9. Move the preserved config into your home directory

After logging in and changing the initial password, move the staged checkout to
its permanent location and give it to your user:

```bash
sudo mv /var/lib/nixos/config-source ~/nixos
sudo chown -R "$USER":users ~/nixos

# From then on, rebuild with:
sudo nixos-rebuild switch --flake ~/nixos#nixos
```

Commit the real `hardware-configuration.nix` and the selected stable Disko
device back to the repo so future rebuilds and reinstalls are reproducible.

---

## Alternative: nixos-anywhere (from your Mac, over SSH)

Once the config is solid you can install unattended from your Mac to a booted
target (any Linux you can SSH into as root, or the NixOS ISO):

```bash
# On the live ISO, nix-command/flakes aren't enabled by default, so pass the
# feature flag (or `export NIX_CONFIG="experimental-features = nix-command flakes"`).
nix --experimental-features "nix-command flakes" run github:nix-community/nixos-anywhere -- \
  --flake .#nixos \
  root@<target-ip>
```

It runs disko + install remotely. Good for repeat installs; the manual flow
above is better the first time so you see each step.
