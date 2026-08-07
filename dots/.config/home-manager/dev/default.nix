# ~/.config/home-manager/dev/default.nix
{ pkgs, aicommit2, ... }:

{
  home.packages = with pkgs; [
    nixd
    deadnix
    statix
    alejandra
    nix-prefetch
    nix-prefetch-github
    nil
    aicommit2.packages.${pkgs.stdenv.hostPlatform.system}.default
 ];

}
