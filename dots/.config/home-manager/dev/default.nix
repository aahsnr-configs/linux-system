# ~/.config/home-manager/dev/default.nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    deadnix
    nil
    alejandra
    nixfmt
    nixpkgs-fmt
    statix
  ];

  # programs.direnv = {
  #   enable = true;
  #   nix-direnv.enable = true;
  #   config.global.hide_env_diff = true;
  # };
}
