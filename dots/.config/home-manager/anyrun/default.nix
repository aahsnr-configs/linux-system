{ inputs, pkgs, ... }:
{
  programs.anyrun = {
    enable = true;
    config = {
      x.fraction = 0.5;
      y.fraction = 6.0e-2;
      width.fraction = 0.4;
      hideIcons = false;
      ignoreExclusiveZones = false;
      layer = "overlay";
      hidePluginInfo = true;
      closeOnClick = true;
      showResultsImmediately = false;
      maxEntries = 15;
      plugins = with inputs.anyrun.packages.${pkgs.system}; [
        applications
        rink
        shell
        stdin
        translate
        symbols
      ];
    };

    extraConfigFiles = {
      "applications.ron".text = ''
        Config(
          desktop_actions: true,
          max_entries: 10,
          terminal: Some("alacritty"),
        )
      '';
    };

    extraCss = ''
      /* Global */
      * {
        all: unset;
        font-family: "JetBrainsMono Nerd Font";
        font-size: 21pt;
        font-weight: 500;
        transition: 300ms;
      }

      /* Modules */
      #window,
      #match,
      #entry,
      #plugin,
      #main {
        background: transparent;
      }

      /* Entry */
      #entry {
        background: #1e2030;
        border-radius: 12px;
        margin: 0.3rem;
        padding: 0.3rem;
      }

      /* Match  */
      #match.activatable {
        background: #1e2030;
        padding: 0.2rem 0.5rem;
      }

      #match.activatable:first-child {
        border-radius: 12px 12px 0 0;
      }

      #match.activatable:last-child {
        border-radius: 0 0 12px 12px;
      }

      #match.activatable:only-child {
        border-radius: 12px;
      }

      /* Hover and selected states */
      #match:selected,
      #match:hover,
      #plugin:hover {
        background: #494d64;
      }

      /* Main container */
      box#main {
        background: #181926;
        border-radius: 12px;
        padding: 0.3rem;
      }

      /* Plugin within list */
      list > #plugin {
        border-radius: 12px;
        margin: 0.5rem;
      }
    '';
  };
}
