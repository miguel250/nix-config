{
  config,
  ...
}:
let
  shellAliases = import ./shell.nix;
in
{
  manual.manpages.enable = false;

  imports = [
    ./programs/ghosty.nix
    ./programs/codex
    ./programs/git.nix
  ];

  programs = {
    home-manager.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
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
