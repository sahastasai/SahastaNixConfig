{
  description = "Portable NixOS and Home Manager configuration for Sahanav Sai Ramesh";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    codex-desktop.url = "github:ilysenko/codex-desktop-linux";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      identity = import ./identity.nix;
    in
    {
      nixosConfigurations.sahasta = nixpkgs.lib.nixosSystem {
        system = identity.system;
        specialArgs = { inherit inputs identity; };
        modules = [
          ./hosts/main/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "hm-backup";
              extraSpecialArgs = { inherit identity; };
              users.${identity.username} = import ./home;
            };
          }
        ];
      };

      formatter.${identity.system} = nixpkgs.legacyPackages.${identity.system}.nixfmt;
    };
}
