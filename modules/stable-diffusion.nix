{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.myStableDiffusion;
in
{
  imports = [ inputs.stable-diffusion-webui.nixosModules.default ];

  options.myStableDiffusion = {
    enable = lib.mkEnableOption ''
      the Stable Diffusion Forge web UI as a system service. Forge is the
      maintained continuation of AUTOMATIC1111's WebUI; upstream A1111 itself
      has had no release since 2024'';

    port = lib.mkOption {
      type = lib.types.port;
      default = 7860;
      description = "Port the web UI listens on, bound to localhost only.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/sd-webui-forge";
      description = ''
        Where checkpoints, LoRAs and generated images live. Changing this away
        from the default drops the btrfs subvolume handling below, which exists
        to keep model weights out of the hourly snapshots.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.sd-webui-forge = {
      enable = true;

      # Take the package from the flake's own output rather than letting the
      # option default to `pkgs.stable-diffusion-webui.forge.cuda`. That default
      # resolves against this system's nixpkgs, which has `cudaSupport` unset,
      # so the whole torch stack would be assembled without CUDA and fall back
      # to the CPU at runtime. The flake's package set is built from its own
      # nixpkgs with `cudaSupport = true`.
      package = inputs.stable-diffusion-webui.packages.${pkgs.stdenv.hostPlatform.system}.forge.cuda;

      inherit (cfg) dataDir port;

      # Gradio binds 127.0.0.1 unless told otherwise. There is no authentication
      # in front of this UI and it can read and write anywhere under dataDir, so
      # exposing it to the LAN would need a deliberate decision and a firewall
      # rule, not a default.
      listen = false;
    };

    # cache.nixos.org builds nixpkgs with `cudaSupport = false`, so nothing in
    # the CUDA half of this closure is in it. Without a second substituter the
    # heavy pieces get compiled here - NCCL alone is a ~40 minute nvcc run
    # across ten GPU architectures, and it is rebuilt every time the upstream
    # flake moves its nixpkgs pin. nix-community carries those exact paths
    # (verified against the store hashes this closure asks for; the
    # cuda-maintainers cache the wiki suggests did *not* have them).
    #
    # This is a trust decision, which is why it is scoped to this module rather
    # than dropped into configuration.nix: nix only accepts paths from here that
    # carry a matching signature, but a cache is still an entity whose builds
    # you are choosing to run. nix-community is the one this flake's own README
    # points at.
    nix.settings = {
      substituters = [ "https://nix-community.cachix.org" ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };

    # /var/lib sits on the `/` subvolume, which snapper snapshots hourly and
    # retains for a day plus seven dailies (modules/snapshots.nix). A checkpoint
    # is 2-7GB and a model library grows without bound, so leaving the data
    # directory inside `/` would pin every deleted or replaced checkpoint on disk
    # for a week. btrfs snapshots stop at nested subvolume boundaries, so making
    # this directory its own subvolume excludes it from those snapshots entirely.
    #
    # tmpfiles' `v` creates a subvolume on btrfs and a plain directory anywhere
    # else. It will not convert a directory that already exists, so this only
    # takes effect before the service first populates it - which is why it runs
    # from sysinit.target, well ahead of the service at multi-user.target.
    systemd.tmpfiles.rules = lib.mkIf (cfg.dataDir == "/var/lib/sd-webui-forge") [
      "v ${cfg.dataDir} 0700 sd-webui-forge sd-webui-forge -"
    ];
  };
}
