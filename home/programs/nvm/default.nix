{
  config,
  pkgs,
  lib,
  ...
}:
let
  nvm = import ./package.nix { inherit pkgs lib; };
in
{
  home.packages = lib.mkAfter [ nvm ];
  home.sessionVariables.NVM_DIR = "${config.home.homeDirectory}/.nvm";

  programs.zsh.initContent = lib.mkAfter ''
    source ${nvm}/share/nvm/nvm.sh
    source ${nvm}/share/nvm/bash_completion
  '';
}
