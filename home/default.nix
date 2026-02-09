{
  config,
  lib,
  pkgs,
  dotfiles,
  ...
}:
let
  shellAliases = import ./shell.nix;
  dotfilesPath = dotfiles.outPath or dotfiles;
in
{
  manual.manpages.enable = false;

  imports = [
    ./programs/ghosty.nix
    ./programs/codex
  ];

  programs = {
    home-manager.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    git = {
      enable = true;
      includes = [
        { path = "${dotfilesPath}/git/config"; }
      ];
    };
    starship.enable = true;
    zsh = {
      enable = true;
      enableCompletion = true;
      dotDir = config.home.homeDirectory;
      inherit shellAliases;
    };
  };
}
