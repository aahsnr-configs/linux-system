# ~/.config/home-manager/fish/default.nix
{ pkgs, ... }:

{
  # Install all required packages and shell plugins
  home.packages = with pkgs; [
    fishPlugins.autopair
  ];

  # Configure Fish shell and its ecosystem
  programs.fish = {
    enable = true;
    shellAliases = {
      # General
      vi = "nvim";
      gg = "lazygit";
      cat = "bat --paging=never";
      grep = "rg";
      du = "dust";
      rmi = "sudo rm -rf";

      # NixOS / Home Manager
      "hm-switch" = "home-manager switch";
      nixs = "nix-shell -p";

      # Systemd
      sctl = "systemctl";
      sctle = "sudo systemctl enable";
      sctls = "sudo systemctl start";
    };

    functions = {
      "pac-clean" = "command sudo pacman -Qdtq | command sudo pacman -Rns -";
      "tldr-fzf" = "tldr --list | fzf --preview 'tldr {1}' --preview-window right:70%";
      yy = ''
        set tmp (mktemp -t "yazi-cwd.XXXXXX")
        yazi $argv --cwd-file="$tmp"
        if set cwd (cat -- "$tmp"); and test -n "$cwd"; and test "$cwd" != "$PWD"
          cd -- "$cwd"
        end
        rm -f -- "$tmp"
      '';
      rgfzf = ''
        rg --color=always --line-number $argv | fzf --ansi \
            --preview 'bat --style=numbers --color=always --line-range :500 {1}' \
            --preview-window 'right:60%:wrap'
      '';
    };

    plugins = [
      {
        name = "autopair";
        src = pkgs.fishPlugins.autopair.src;
      }
    ];

    interactiveShellInit = ''
      set fish_greeting
      # Set VI keybindings
      set -g fish_key_bindings fish_vi_key_bindings

      # Bind 'jk' to escape insert mode
      bind -M insert jk 'set fish_bind_mode default; commandline -f repaint'

      # Configure fzf previews for files (bat) and directories (eza)
      set -x FZF_PREVIEW_COMMAND '
        if test -f {};
          bat --color=always --style=numbers --line-range :500 {};
        else;
          eza --tree --level=2 {};
        end'
    '';
  };
}
