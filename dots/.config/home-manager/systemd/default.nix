{ pkgs, ... }:

let
  tmux-start-script = pkgs.writeShellScriptBin "tmux-start" ''
    #!${pkgs.runtimeShell}
    tmux has-session -t main || tmux new-session -s main -d
  '';

in
{
  systemd.user.services = {

    # This service creates a persistent tmux session named "main".
    tmux = {
      Unit = {
        Description = "Tmux User Session";
        Documentation = [ "man:tmux(1)" ];
      };

      Service = {
        # 'forking' is appropriate because `tmux new-session -d` starts a
        # background server process and then immediately exits.
        Type = "forking";
        ExecStart = "${tmux-start-script}/bin/tmux-start";
        ExecStop = "tmux kill-session -t main";
        Restart = "on-failure";
        RestartSec = "1s";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };

  };
}
