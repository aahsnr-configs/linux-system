{ ... }:
{
  home = {
    username = "ahsan";
    homeDirectory = "/home/ahsan";
    stateVersion = "26.11";
    extraOutputsToInstall = [
      "doc"
      "info"
      "devdoc"
    ];

    # nixpkgs' Electron/Chromium-based packages (VSCodium included) check
    # this variable in their wrapper script and switch to native Wayland
    # rendering instead of falling back to XWayland. Under Hyprland this
    # means smoother scrolling/resizing and noticeably lower input latency.
    sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };
  };

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  imports = [
    ./direnv
    ./dev
    ./pkgs
    ./vscode
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
