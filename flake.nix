{
  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:mic92/sops-nix";
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
        hostname = "mirror.ufscar.br";
        sshUser = "deploy";
        activationTimeout = 600;
        profiles.system = {
          user = "root";
          path = activate "nixos" self.outputs.nixosConfigurations.mirror;
        };
      };
    };

    apps = forAllSystems (system: rec {
      deploy = {
        type = "app";
        program = let
          pkgs = nixpkgs.legacyPackages.${system};
        in pkgs.lib.getExe (pkgs.writeShellScriptBin "deploy" ''
          export PATH="${pkgs.wstunnel}/bin:$PATH"
          exec ${pkgs.deploy-rs}/bin/deploy "$@"
        '');
      };
      default = deploy;
    });
  };
}
