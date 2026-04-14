{
  description = "Dominix OS personal settings";

  inputs = {
    # TODO: To upgrade the system change the versions of nixpkgs, home-manager and nixvim.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    nixvim.url = "github:nix-community/nixvim/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable"; # for packages that need frequently updates.
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
    dominix.inputs.nixvim.follows = "nixvim";
    dominix.url = "github:dominikoetiker/domiNixOS";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      dominix,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs-unstable = import inputs.nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
      personal = import ./settings.nix;
      userConfig = personal.userConfig;
      machineConfig = personal.machineConfig;
      hardwareConfig = personal.hardwareConfig;
    in
    {
      nixosConfigurations = {
        "${machineConfig.hostName}" = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              inputs
              personal
              hardwareConfig
              machineConfig
              userConfig
              pkgs-unstable
              ;
          };
          modules = [
            # Hardware.
            ./hardware-configuration.nix
            ./crypt-uuid.nix

            # TODO: Uncomment modules, you don't want or need.
            dominix.nixosModules.base
            dominix.nixosModules.gnome
            dominix.nixosModules.displaylink
            dominix.nixosModules.fonts
            dominix.nixosModules.security_1password
            dominix.nixosModules.git
            dominix.nixosModules.user
            dominix.nixosModules.nixvim
            dominix.nixosModules.tmux
            dominix.nixosModules.docker
            dominix.nixosModules.virtualization
            dominix.nixosModules.fingerprint
            dominix.nixosModules.onedrive
            dominix.nixosModules.ghostty
            dominix.nixosModules.thunderbird
            dominix.nixosModules.gemini-cli

            # TODO: Chose either zsh or bash as your default shell. Uncomment the one you want and comment the other one out.
            dominix.nixosModules.starship
            dominix.nixosModules.zsh
            #dominix.nixosModules.bash

            # Machine specific packages.
            (
              { pkgs, ... }:
              {
                environment.systemPackages = with pkgs; [
                  # <-- TODO: Add any additional packages you want to be available on your system here.
                ];
              }
            )

            # Home Manager.
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = {
                inherit
                  inputs
                  personal
                  userConfig
                  machineConfig
                  hardwareConfig
                  ;
              };
            }
          ];
        };
      };
    };
}
