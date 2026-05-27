{ pkgs, ... }:
let
  tex = pkgs.texlive.combine {
    inherit (pkgs.texlive)
      scheme-medium dvisvgm dvipng latexmk wrapfig amsmath ulem hyperref
      capt-of;
  };
in {
  # home-manager
  home.packages = with pkgs; [ tex texlab tectonic ];
}
