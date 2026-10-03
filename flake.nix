{
  description = "A simple NixOS flake";

  inputs = {
    # NixOS official package source, using the nixos-unstable branch here
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager"; # master tracks unstable
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    superfile = {
      url = "github:yorukot/superfile/v1.6.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    yazi.url = "github:sxyazi/yazi";

  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    {
      # Please replace my-nixos with your hostname
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          # Import the previous configuration.nix we used,
          # so the old configuration file still takes effect
          ./configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true; # reuse system pkgs (+ allowUnfree, overlays)
              useUserPackages = true; # install to /etc/profiles instead of ~/.nix-profile
              extraSpecialArgs = { inherit inputs; };
              backupFileExtension = "hm-bak"; # see gotchas
              users.linus = import ./home.nix;
            };
          }
          inputs.dms.nixosModules.dank-material-shell
        ];
      };
    };
}
