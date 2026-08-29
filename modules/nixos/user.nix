{ pkgs, identity, ... }:

{
  programs.fish.enable = true;

  users.users.${identity.username} = {
    isNormalUser = true;
    description = identity.fullName;
    home = identity.homeDirectory;
    createHome = true;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.fish;
  };
}
