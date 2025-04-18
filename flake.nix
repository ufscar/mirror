{
  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    archvsync = {
      url = "github:LuNeder/archvsync-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs@{ self, nixpkgs, deploy-rs, ... }: let
    systems = ["x86_64-linux" "aarch64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    nixosConfigurations = {
      mirror = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          inputs.disko.nixosModules.disko
        ];
        specialArgs = {inherit inputs;};
      };
    };

    deploy.nodes = let
      activate = kind: config: deploy-rs.lib.${config.pkgs.system}.activate.${kind} config;
    in {
      mirror = {
        # FIXME
        # hostname = "mirror.ufscar.br";
        hostname = "200.133.233.210";
        sshUser = "deploy";
        profiles.system = {
          user = "root";
          path = activate "nixos" self.outputs.nixosConfigurations.mirror;
        };
      };
    };

    apps = forAllSystems (system: rec {
      deploy = {
        type = "app";
        program = nixpkgs.lib.getExe nixpkgs.legacyPackages.${system}.deploy-rs;
      };
      default = deploy;
    });
  };
}
