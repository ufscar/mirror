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
  };
  outputs = inputs@{ self, nixpkgs, ... }: let
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

    packages = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      deploy-worker = pkgs.writeShellApplication {
        name = "mirror-deploy-worker";
        runtimeInputs = [ pkgs.coreutils pkgs.util-linux pkgs.systemd pkgs.nix pkgs.curl ];
        text = builtins.readFile ./scripts/deploy-worker.sh;
      };
    });

    apps = forAllSystems (system: rec {
      deploy = {
        type = "app";
        program = let
          pkgs = nixpkgs.legacyPackages.${system};
        in pkgs.lib.getExe (pkgs.writeShellApplication {
          name = "deploy";
          runtimeInputs = [ pkgs.nix pkgs.openssh pkgs.wstunnel pkgs.coreutils ];
          text = ''
            set -- ${self.nixosConfigurations.mirror.config.system.build.toplevel} ${self.packages.x86_64-linux.deploy-worker} "$@"
          '' + builtins.readFile ./scripts/deploy.sh;
        });
      };
      default = deploy;
    });
  };
}
