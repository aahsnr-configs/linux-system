# ~/.config/home-manager/dev/default.nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nixd
    alejandra
    deadnix 
    statix
    nix-prefetch
    nix-prefetch-github
 ];

}
