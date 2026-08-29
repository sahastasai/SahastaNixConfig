{ pkgs, inputs, ... }:

{
  environment.systemPackages = with pkgs; [
    adwaita-icon-theme
    alacritty
    bun
    cargo
    clippy
    inputs.codex-desktop.packages.${pkgs.stdenv.hostPlatform.system}.default
    eza
    fish
    gh
    git
    gptfdisk
    gnomeExtensions.caffeine
    pandoc
    parted
    rsync
    rustc
    rustfmt
    signal-desktop
    vicinae
    vim
    wget
    wl-clipboard
    zed-editor
    zoxide
    zstd
  ];
}
