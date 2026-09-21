{
  inputs,
  pkgs,
  ...
}:

let
  forge = inputs.stable-diffusion-webui.packages.${pkgs.stdenv.hostPlatform.system}.forge.cuda;
  url = "http://127.0.0.1:7860";

  launchForge = pkgs.writeShellApplication {
    name = "launch-stable-diffusion";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.libnotify
      pkgs.util-linux
      pkgs.xdg-utils
    ];
    text = ''
      url=${pkgs.lib.escapeShellArg url}
      lock_file="''${XDG_RUNTIME_DIR:?}/stable-diffusion-webui.lock"

      wait_for_forge() {
        for _ in $(seq 1 300); do
          if curl --fail --silent --output /dev/null "$url"; then
            exec xdg-open "$url"
          fi
          sleep 1
        done

        notify-send --urgency=critical "Stable Diffusion did not become ready" \
          "The startup timed out after five minutes."
        exit 1
      }

      # Only one launcher owns Forge. A second launch waits for the first one
      # and opens the same URL instead of starting a process that cannot bind
      # the already occupied port.
      exec 9>"$lock_file"
      if ! flock --nonblock 9; then
        wait_for_forge
      fi

      ${forge}/bin/stable-diffusion-webui --port 7860 &
      forge_pid=$!
      trap 'kill "$forge_pid" 2>/dev/null || true' EXIT INT TERM

      # Forge can take a while to import its Python and CUDA stack on a cold
      # start. Keep the launcher process alive until the HTTP endpoint is ready
      # so the browser never lands on a connection error page.
      for _ in $(seq 1 300); do
        if curl --fail --silent --output /dev/null "$url"; then
          xdg-open "$url"
          wait "$forge_pid"
          exit $?
        fi

        if ! kill -0 "$forge_pid" 2>/dev/null; then
          wait "$forge_pid" || true
          notify-send --urgency=critical "Stable Diffusion failed to start" \
            "Open the application logs for details."
          exit 1
        fi

        sleep 1
      done

      notify-send --urgency=critical "Stable Diffusion did not become ready" \
        "The startup timed out after five minutes."
      exit 1
    '';
  };
in
{
  xdg.desktopEntries.stable-diffusion = {
    name = "Stable Diffusion";
    genericName = "AI Image Generator";
    comment = "Launch Forge and open it in the default browser";
    exec = "${launchForge}/bin/launch-stable-diffusion";
    icon = "applications-graphics";
    terminal = false;
    type = "Application";
    categories = [ "Graphics" ];
    startupNotify = false;
  };
}
