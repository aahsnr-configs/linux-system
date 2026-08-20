{
  description = "Home Manager configuration of ahsan";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    systems.url = "github:nix-systems/default-linux";
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs-wayland = {
      url = "github:nix-community/nixpkgs-wayland";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin.url = "github:catppuccin/nix";

    nfsm-flake = {
      url = "github:gvolpe/nfsm";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri-switch = {
      url = "github:Kiki-Bouba-Team/niri-switch";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri-scratchpad-flake = {
      url = "github:gvolpe/niri-scratchpad";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      rust-overlay,
      catppuccin,
      nix-vscode-extensions,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
    in
    {
      homeConfigurations."ahsan" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs { inherit system; };
        overlays = [
          rust-overlay.overlays.default
          nix-vscode-extensions.overlays.default
        ];
        extraSpecialArgs = {
          inherit inputs;
          inherit rust-overlay;
          inherit catppuccin;
        };

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        modules = [
          ./home.nix
          catppuccin.homeModules.catppuccin
        ];
      };
    };
}
