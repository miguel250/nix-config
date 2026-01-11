{ pkgs, lib, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
{
  programs.ghostty = {
    enable = true;
    package = if isLinux then pkgs.ghostty else null;
    settings = {
      font-size = 12;
      font-family = "JetBrainsMono Nerd Font Mono";
      theme = "Catppuccin Frappe";
      shell-integration = "zsh";
      background-opacity = 0.8;
      background-blur = 10;
      clipboard-read = "allow";
      clipboard-write = "allow";
      copy-on-select = true;
      clipboard-paste-protection = false;
      keybind = lib.optionals isLinux [
        "ctrl+v=paste_from_clipboard"
      ];
    };
  };
}
