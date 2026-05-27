{ pkgs, ... }:
{
  fonts = {
    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [ "JetBrainsMono Nerd Font" ];
      };
    };

  };

  home.packages = with pkgs; [
    corefonts
    (google-fonts.override { fonts = [ "Inter" ]; })
    jetbrains-mono
    material-symbols
    nerd-fonts.jetbrains-mono
    noto-fonts-color-emoji
    powerline-fonts
    ubuntu_font_family
    ubuntu-sans
  ];

}
