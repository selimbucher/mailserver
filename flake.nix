{
  description = "Selim's mail server NixOS module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    simple-nixos-mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, simple-nixos-mailserver }: {
    nixosModules.default = {
      imports = [
        simple-nixos-mailserver.nixosModule
        ./module.nix
      ];
    };
  };
}
