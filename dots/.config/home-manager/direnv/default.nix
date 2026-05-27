# ~/.config/home-manager/dev/default.nix
{ ... }:
{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config.global.hide_env_diff = true;
  };
}
