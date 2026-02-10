# ~/.config/home-manager/catppuccin/default.nix
{ ... }:
{
  catppuccin = {
    atuin = {
      enable = true;
      flavor = "macchiato";
      accent = "flamingo";
    };

    bat = {
      enable = true;
      flavor = "macchiato";
    };

    delta = {
      enable = true;
      flavor = "macchiato";
    };

    fish = {
      enable = true;
      flavor = "macchiato";
    };

    fzf = {
      enable = true;
      accent = "flamingo";
      flavor = "macchiato";
    };

    lazygit = {
      enable = true;
      accent = "flamingo";
      flavor = "macchiato";
    };

    tmux = {
      enable = true;
      extraConfig = ''
        set -g @catppuccin_status_modules_right "application session user host date_time"
      '';
      flavor = "macchiato";
    };

    yazi = {
      enable = true;
      accent = "flamingo";
      flavor = "macchiato";
    };
  };
}
