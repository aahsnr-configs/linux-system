# ~/.config/home-manager/pay-respects/default.nix
{ ... }:
{
  programs.pay-respects = {
    enable = true;
    enableFishIntegration = true;
    options = [
      "--alias"
      "f"
    ];
  };
}
