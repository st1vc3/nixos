# NixOS install with disko

Target: physical machine, AMD CPU + NVIDIA GPU, UEFI, btrfs (unencrypted), Hyprland.

## 0. Before you boot

Edit `disko.nix` and set the real `device` (you can also do this live on the
ISO). Everything else in the repo is ready to go.

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
lsblk -o NAME,SIZE,TYPE,MODEL
```

Note the disk (e.g. `/dev/nvme0n1`). This disk will be **completely erased**.

## 4. Get the config

```bash
nix-shell -p git
git clone https://github.com/st1vc3/nixos /mnt-config
cd /mnt-config
```

Edit `disko.nix` so `device = "..."` matches step 3:

```bash
nano disko.nix
```

## 5. Partition + format + mount (disko)

```bash
# --mode destroy,format,mount wipes, creates, and mounts everything at /mnt
nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- \
  --mode destroy,format,mount \
  ./disko.nix
```

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

## 7. Install

```bash
nixos-install --flake .#nixos
# It will prompt for the root password at the end.
```

## 8. Reboot

```bash
reboot        # remove the USB stick
```

Log in as `stivce` with the initial password `changeme` (set in
`configuration.nix`). **Immediately change it:**

```bash
passwd
```

Hyprland: at the SDDM login screen pick the **Hyprland** session. Default
terminal keybind is `Super + Q` (opens kitty).

## 9. Persist your config

Copy the (now hardware-specific) repo to your home dir and keep it in git:

```bash
sudo cp -r /mnt-config ~/nixos     # if still mounted, else re-clone
# from then on, rebuild with:
sudo nixos-rebuild switch --flake ~/nixos#nixos
```

Commit the real `hardware-configuration.nix` back to the repo so future
rebuilds are reproducible.

---

## Alternative: nixos-anywhere (from your Mac, over SSH)

Once the config is solid you can install unattended from your Mac to a booted
target (any Linux you can SSH into as root, or the NixOS ISO):

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#nixos \
  root@<target-ip>
```

It runs disko + install remotely. Good for repeat installs; the manual flow
above is better the first time so you see each step.
