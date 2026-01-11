{
  config,
  lib,
  pkgs,
  ...
}:
let
  shellAliases = import ./shell.nix;
in
{
  manual.manpages.enable = false;

  imports = [
    ./programs/ghosty.nix
  ];

  programs = {
    home-manager.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    git.enable = true;
    starship.enable = true;
    zsh = {
      enable = true;
      enableCompletion = true;
      dotDir = config.home.homeDirectory;
      inherit shellAliases;
    };
  };

}
