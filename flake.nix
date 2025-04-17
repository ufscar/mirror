{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    archvsync.url = "github:LuNeder/archvsync-nix";
    archvsync.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = inputs@{ self, nixpkgs, ... }: {
    nixosConfigurations.mirror = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        inputs.disko.nixosModules.disko
      ];
      specialArgs = {inherit inputs;};
    };
  };
}
