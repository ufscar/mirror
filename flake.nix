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
  outputs = inputs@{ self, nixpkgs, deploy-rs, ... }: {
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
        hostname = "mirror.ufscar.br";
        sshUser = "deploy";
        profiles.system = {
          user = "root";
          path = activate "nixos" self.outputs.nixosConfigurations.mirror;
        };
      };
    };
  };
}
