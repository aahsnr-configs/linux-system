# ~/.config/home-manager/dev/default.nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nixd
    deadnix
    statix
    alejandra
    nix-prefetch
    nix-prefetch-github
    nil
 ];

}
