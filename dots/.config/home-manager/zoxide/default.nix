# ~/.config/home-manager/zoxide/default.nix
{ ... }:
{
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };
}
