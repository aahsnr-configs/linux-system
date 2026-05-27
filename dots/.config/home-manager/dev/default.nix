# ~/.config/home-manager/dev/default.nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nixd
    alejandra
    shellcheck
    shfmt
    bash-language-server
    nix-prefetch
    nix-prefetch-github
 ];

  # programs.direnv = {
  #   enable = true;
  #   nix-direnv.enable = true;
  #   config.global.hide_env_diff = true;
  # };
}
