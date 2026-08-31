{
  config,
  pkgs,
  identity,
  ...
}:

let
  changeBrightness = pkgs.writeShellApplication {
    name = "change-brightness";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      action="''${1:-}"
      device_path=""

      for candidate in /sys/class/backlight/*; do
        if [[ -e "$candidate" ]]; then
          device_path="$candidate"
          break
        fi
      done

      if [[ -z "$device_path" ]]; then
        echo "No backlight device found" >&2
        exit 1
      fi

      current=$(<"$device_path/brightness")
      maximum=$(<"$device_path/max_brightness")
      step=$((maximum / 20))
      minimum=$((maximum / 100))
      ((step > 0)) || step=1
      ((minimum > 0)) || minimum=1

      case "$action" in
        up)
          target=$((current + step))
          ((target <= maximum)) || target=$maximum
          ;;
        down)
          target=$((current - step))
          ((target >= minimum)) || target=$minimum
          ;;
        *)
          echo "Usage: change-brightness {up|down}" >&2
          exit 2
          ;;
      esac

      device_name=$(basename "$device_path")
      busctl --system call \
        org.freedesktop.login1 \
        /org/freedesktop/login1/session/auto \
        org.freedesktop.login1.Session \
        SetBrightness \
        ssu backlight "$device_name" "$target" >/dev/null
    '';
  };
in
{
  imports = [
    ./modules/config-files.nix
    ./modules/desktop.nix
  ];

  home.username = identity.username;
  home.homeDirectory = identity.homeDirectory;
  home.stateVersion = identity.homeStateVersion;

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    age
    bash
    bat
    bun
    cmake
    coreutils
    curl
    direnv
    eza
    fd
    findutils
    gawk
    gcc
    gh
    git
    git-lfs
    gnugrep
    gnumake
    gnupg
    grimblast
    gnutar
    go
    helix
    jq
    neovim
    nodejs
    openssh
    pkg-config
    python3
    rclone
    ripgrep
    rsync
    shellcheck
    shfmt
    sqlite
    tmux
    unzip
    uv
    wget
    zip
    zellij
    zstd
    zulu21
    changeBrightness
  ];

  # Keep Bun functional in already-running desktop sessions whose inherited
  # PATH still places the legacy ~/.bun/bin directory before the Nix profile.
  home.file.".bun/bin/bun" = {
    source = "${pkgs.bun}/bin/bun";
    force = true;
  };

  # Hyprland bindings need a stable path regardless of whether Home Manager
  # installs packages through a standalone or NixOS-integrated profile.
  home.file.".local/bin/change-brightness" = {
    source = "${changeBrightness}/bin/change-brightness";
    executable = true;
    force = true;
  };

  programs.bash.enable = true;
  programs.zsh = {
    enable = true;
    dotDir = config.home.homeDirectory;
  };
  programs.git.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  home.sessionVariables.EDITOR = "vim";
  home.sessionPath = [
    "$HOME/.local/bin"
  ];
}
