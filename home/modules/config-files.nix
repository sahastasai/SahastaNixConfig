{
  config,
  identity,
  lib,
  pkgs,
  ...
}:

let
  homeDir = identity.homeDirectory;
  managedConfigFiles = [
    "QtProject.conf"
    "btop/btop.conf"
    "codex-desktop/electron-flags.conf"
    "dolphinrc"
    "fish/completions/bun.fish"
    "fish/conf.d/fish_frozen_key_bindings.fish"
    "gh/config.yml"
    "hypr/hyprland.conf"
    "micro/colorschemes/catppuccin-frappe.micro"
    "micro/colorschemes/catppuccin-latte.micro"
    "micro/colorschemes/catppuccin-macchiato.micro"
    "micro/colorschemes/catppuccin-mocha.micro"
    "micro/settings.json"
    "mimeapps.list"
    "obs-studio/basic/profiles/Untitled/basic.ini"
    "obs-studio/basic/scenes/Untitled.json"
    "obs-studio/global.ini"
    "opencode/opencode.jsonc"
    "pavucontrol.ini"
    "qalculate/qalc.cfg"
    "saimail/config.toml"
    "topgrade.toml"
    "user-dirs.dirs"
    "user-dirs.locale"
    "vicinae/settings.json"
    "zed/settings.json"
    "zellij/config.kdl"
  ];
in
{
  xdg.enable = true;

  home.activation.ensureMutableConfigDirectories = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${homeDir}/.local/share/saimail
    if [[ -x ${homeDir}/.local/bin/saimail ]]; then
      run ${pkgs.coreutils}/bin/install -Dm755 \
        ${homeDir}/.local/bin/saimail \
        ${homeDir}/.local/libexec/saimail-nixos
      run ${pkgs.patchelf}/bin/patchelf \
        --set-interpreter ${pkgs.stdenv.cc.bintools.dynamicLinker} \
        --set-rpath ${
          lib.makeLibraryPath [
            pkgs.openssl
            pkgs.stdenv.cc.cc.lib
          ]
        } \
        ${homeDir}/.local/libexec/saimail-nixos
    fi
  '';

  xdg.configFile = lib.genAttrs managedConfigFiles (name: {
    text = builtins.replaceStrings [ "@HOME@" ] [ identity.homeDirectory ] (
      builtins.readFile (../dotfiles + "/${name}")
    );
    force = true;
  });

  programs.fish = {
    enable = true;
    interactiveShellInit = builtins.replaceStrings [ "@HOME@" ] [ identity.homeDirectory ] (
      builtins.readFile ../dotfiles/fish/config.fish
    );
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
    options = [ "--cmd cd" ];
  };

  systemd.user.services = {
    hydroterrace-microgreen-queue-poller = {
      Unit = {
        Description = "Hydro Terrace microgreen queue poller";
        After = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        WorkingDirectory = "${homeDir}/Development/hydroterrace-microgreen-evaluation/microgreenlist-app";
        EnvironmentFile = "-%h/.config/hydroterrace/microgreen-queue.env";
        ExecStart = "${pkgs.bun}/bin/bun ${homeDir}/Development/hydroterrace-microgreen-evaluation/microgreenlist-app/scripts/process-queue.mjs";
      };
    };

    saimail-codex-scan = {
      Unit = {
        Description = "Scan Codex mailboxes through SaiMail quarantine";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
        ConditionPathExists = "${homeDir}/.local/share/saimail/secrets/mailapp_session";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${homeDir}/.local/libexec/saimail-nixos codex scan --limit 50";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        ReadWritePaths = [ "${homeDir}/.local/share/saimail" ];
      };
    };

    thatha-market-sd-open = {
      Unit.Description = "Thatha Stocks market-open SD refresh, report rebuild, deploy, and email";
      Service = {
        Type = "simple";
        WorkingDirectory = "${homeDir}/Finance/Thatha/May_Portfolio";
        Environment = "PATH=${homeDir}/.local/bin:${
          lib.makeBinPath [
            pkgs.bun
            pkgs.coreutils
            pkgs.curl
            pkgs.git
            pkgs.nodejs
            pkgs.python3
          ]
        }";
        ExecStart = "${pkgs.python3}/bin/python3 ${homeDir}/Finance/Thatha/May_Portfolio/scripts/market_sd_action.py --phase open";
        Nice = 5;
        IOSchedulingClass = "best-effort";
        IOSchedulingPriority = 6;
      };
    };

    thatha-market-sd-close = {
      Unit.Description = "Thatha Stocks market-close SD refresh, report rebuild, deploy, and email";
      Service = {
        Type = "simple";
        WorkingDirectory = "${homeDir}/Finance/Thatha/May_Portfolio";
        Environment = "PATH=${homeDir}/.local/bin:${
          lib.makeBinPath [
            pkgs.bun
            pkgs.coreutils
            pkgs.curl
            pkgs.git
            pkgs.nodejs
            pkgs.python3
          ]
        }";
        ExecStart = "${pkgs.python3}/bin/python3 ${homeDir}/Finance/Thatha/May_Portfolio/scripts/market_sd_action.py --phase close";
        Nice = 5;
        IOSchedulingClass = "best-effort";
        IOSchedulingPriority = 6;
      };
    };
  };

  systemd.user.timers = {
    hydroterrace-microgreen-queue-poller = {
      Unit.Description = "Run Hydro Terrace microgreen queue poller every 5 minutes";
      Timer = {
        OnBootSec = "1min";
        OnUnitActiveSec = "5min";
        AccuracySec = "30s";
        Persistent = true;
        Unit = "hydroterrace-microgreen-queue-poller.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    saimail-codex-scan = {
      Unit.Description = "Poll Codex mailboxes through SaiMail quarantine";
      Timer = {
        OnBootSec = "30s";
        OnUnitActiveSec = "60s";
        AccuracySec = "5s";
        Persistent = true;
        Unit = "saimail-codex-scan.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    thatha-market-sd-open = {
      Unit.Description = "Run Thatha Stocks SD refresh 30 minutes before U.S. market open";
      Timer = {
        OnCalendar = "Mon..Fri *-*-* 06:00:00";
        Persistent = true;
        AccuracySec = "1min";
        Unit = "thatha-market-sd-open.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    thatha-market-sd-close = {
      Unit.Description = "Run Thatha Stocks SD refresh 30 minutes after U.S. market close";
      Timer = {
        OnCalendar = "Mon..Fri *-*-* 13:30:00";
        Persistent = true;
        AccuracySec = "1min";
        Unit = "thatha-market-sd-close.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
