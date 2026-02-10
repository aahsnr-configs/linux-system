# ~/.config/home-manager/fzf/default.nix
{ ... }:
{
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    defaultCommand = "fd --type f --hidden --follow --exclude .git --exclude node_modules";
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
      "--preview-window=right:60%:wrap"
      "--bind='ctrl-d:preview-page-down,ctrl-u:preview-page-up'"
      "--bind='ctrl-y:execute-silent(echo {} | wl-copy)'" # Wayland clipboard
      "--bind='ctrl-e:execute($EDITOR {})'" # Open in editor
      "--ansi"
    ];
    fileWidgetOptions = [ "--preview 'bat --style=numbers --color=always {}'" ];
  };
}
