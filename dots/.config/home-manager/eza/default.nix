# ~/.config/home-manager/eza/default.nix
{ ... }:
{
  programs.eza = {
    enable = true;
    enableFishIntegration = true; # Manages aliases
    git = true;
    icons = "auto";
    extraOptions = [
      "--group-directories-first"
      "--header"
    ];
    # The full, detailed Catppuccin theme is restored
    theme = {
      ui = {
        size = {
          number = "#fab387";
          unit = "#f38ba8";
        };
        user = "#f9e2af";
        group = "#a6e3a1";
        date = {
          day = "#89b4fa";
          time = "#cba6f7";
        };
        inode = "#cdd6f4";
        blocks = "#fab387";
        header = "#b4befe";
        links = "#f5e0dc";
        tree = "#cba6f7";
      };
      punctuation = "#9399b2";
      permission = {
        read = "#a6e3a1";
        write = "#f9e2af";
        exec = "#f38ba8";
        exec_sticky = "#cba6f7";
        no_access = "#6c7086";
        octal = "#fab387";
        attribute = "#89dceb";
      };
      filetype = {
        directory = "#89b4fa";
        symlink = "#89dceb";
        pipe = "#f5c2e7";
        socket = "#f5c2e7";
        block_device = "#f38ba8";
        char_device = "#f38ba8";
        setuid = "#fab387";
        setgid = "#fab387";
        sticky = "#89b4fa";
        other_writable = "#89b4fa";
        sticky_other_writable = "#cba6f7";
      };
      filekinds = {
        image = "#94e2d5";
        video = "#74c7ec";
        music = "#cba6f7";
        lossless = "#cba6f7";
        crypto = "#f38ba8";
        document = "#f5c2e7";
        compressed = "#fab387";
        temp = "#6c7086";
        compiled = "#fab387";
        source = "#89b4fa";
        executable = "#a6e3a1";
      };
      git = {
        clean = "#a6e3a1";
        new = "#89b4fa";
        modified = "#f9e2af";
        deleted = "#f38ba8";
        renamed = "#cba6f7";
        typechange = "#fab387";
        ignored = "#6c7086";
        conflicted = "#eba0ac";
      };
      extension = {
        "7z" = "#fab387";
        zip = "#fab387";
        tar = "#fab387";
        gz = "#fab387";
        avif = "#94e2d5";
        png = "#94e2d5";
        jpg = "#94e2d5";
        gif = "#94e2d5";
        mp4 = "#74c7ec";
        mkv = "#74c7ec";
        webm = "#74c7ec";
        mp3 = "#cba6f7";
        flac = "#cba6f7";
        ogg = "#cba6f7";
        pdf = "#f5c2e7";
        docx = "#f5c2e7";
        md = "#f5c2e7";
        json = "#f9e2af";
        toml = "#f9e2af";
        yml = "#f9e2af";
        nix = "#89b4fa";
        sh = "#a6e3a1";
        bash = "#a6e3a1";
        zsh = "#a6e3a1";
        py = "#f9e2af";
        js = "#f9e2af";
        ts = "#89b4fa";
        go = "#89dceb";
        rs = "#fab387";
      };
    };
  };
}
