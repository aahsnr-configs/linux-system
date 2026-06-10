# ~/.config/home-manager/dev/default.nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nixd
    deadnix
    statix
    alejandra
    marksman
    bash-language-server
    shellcheck
    shfmt
    stylua
    nix-prefetch
    nix-prefetch-github
    pyrefly
    lua-language-server
 ];

}
