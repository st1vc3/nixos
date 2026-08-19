{ config, pkgs, ... }:

{
  # Push-to-talk voice dictation, the Linux counterpart to Wispr Flow. The
  # daemon captures from PipeWire, transcribes through Groq's hosted Whisper,
  # and injects the text into the focused window over Hyprland IPC.
  #
  # Behaviour lives in config/hyprwhspr-rs/config.jsonc, keys in
  # config/hypr/hyprland.lua. This file only wires the service.
  services.hyprwhspr-rs.enable = true;

  # The upstream module defines the daemon's unit but installs nothing on PATH.
  # The Hyprland bindings invoke the same binary as a client (`record start`),
  # which talks to the daemon over its control socket, so it has to be reachable
  # by name. Taken from the module's own `package` option so the client and the
  # daemon can never drift apart.
  environment.systemPackages = [ config.services.hyprwhspr-rs.package ];

  systemd.user.services.hyprwhspr-rs = {
    # Every remote backend pipes the captured PCM through ffmpeg to encode FLAC
    # before upload. The nixpkgs package wraps only whisper-cpp onto PATH, so
    # with provider = "groq" the daemon otherwise fails each transcription with
    # "Failed to spawn ffmpeg for FLAC encoding". Headless is enough - this is
    # an audio-only pipe.
    path = [ pkgs.ffmpeg-headless ];

    # The key has to arrive as an environment variable; the daemon reads
    # GROQ_API_KEY and nothing else. The module's own `environmentFile` option
    # maps to systemd's LoadCredential, which only exposes the file under
    # $CREDENTIALS_DIRECTORY and never exports its contents, so it cannot
    # satisfy that read - set the real EnvironmentFile instead.
    #
    # The file is deliberately outside this repo: it is a live credential, and
    # everything here is world-readable on GitHub. See the README for the
    # one-time setup.
    serviceConfig.EnvironmentFile = "-%h/.config/hyprwhspr-rs/env";

    # With provider = "groq" the daemon resolves its backend during startup and
    # exits if GROQ_API_KEY is unset - it does not defer the failure to the
    # first transcription. Without a guard that turns into a restart loop until
    # systemd's start limit trips. Gating on the credential instead leaves the
    # unit cleanly inactive with "Condition check resulted in ... being skipped",
    # which says what is missing. Drop this line if the provider ever moves to a
    # local backend, which needs no key.
    unitConfig.ConditionPathExists = "%h/.config/hyprwhspr-rs/env";
  };

  # Note on the `input` group: upstream suggests adding the account to it so the
  # daemon's own evdev listener can grab a global hotkey. That is deliberately
  # skipped. Hyprland owns the shortcut here and drives the daemon through its
  # control socket, which needs no elevated access, whereas `input` would hand
  # every process running as this user read access to all keyboard events. The
  # unused listener logs one "No keyboard devices found" warning at startup and
  # is otherwise inert.
}
