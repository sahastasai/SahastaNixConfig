{
  identity,
  lib,
  pkgs,
  ...
}:

{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # `sudo nixos-rebuild` evaluates the user-owned default flake as root. Trust
  # only this exact checkout so libgit2 accepts it without weakening Git's
  # ownership checks globally.
  programs.git = {
    enable = true;
    config.safe.directory = "${identity.homeDirectory}/.config/nixos";
  };

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    loader = lib.mkMerge [
      (lib.mkIf (identity.bootMode == "uefi") {
        systemd-boot.enable = true;
        efi = {
          canTouchEfiVariables = true;
          efiSysMountPoint = identity.efiSysMountPoint;
        };
      })
      (lib.mkIf (identity.bootMode == "bios") {
        grub = {
          enable = true;
          device = identity.grubDevice;
        };
      })
    ];
  };

  networking = {
    hostName = identity.hostName;
    networkmanager.enable = true;
  };

  time.timeZone = identity.timeZone;
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = identity.systemStateVersion;
}
