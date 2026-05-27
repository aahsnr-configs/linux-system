# ~/.config/home-manager/ripgrep/default.nix
{ ... }: {
  programs.ripgrep = {
    enable = true;
    arguments = [
      "--max-columns=300"
      "--smart-case"
      "--one-file-system"
      "--hidden"
      "--follow"
      "--glob=!.git/"
      "--glob=!node_modules/"
      "--glob=!__pycache__/"
      "--glob=!target/"
      "--glob=!result"
      "--glob=!result-*"
      "--type-add=nix:*.nix"
      "--type-add=systemd:*.service,*.target,*.mount"
    ];
  };
}
