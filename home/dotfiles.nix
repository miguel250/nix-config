{
  config,
  dotfiles,
  vimrc,
  pkgs,
  lib,
  ...
}:
let
  dotfilesPath = dotfiles.outPath or dotfiles;
  neovimNightly = vimrc.inputs.neovim-nightly;
  neovimNightlySystem = neovimNightly.packages.${pkgs.stdenv.hostPlatform.system};
  neovimNightlyPackage =
    (neovimNightlySystem.default.override {
    }).overrideAttrs
      (_: {
        enableParallelBuilding = false;
      });
in
{
  imports = [
    dotfiles.homeManagerModules.default
    vimrc.homeManagerModules.default
  ];

  programs.neovim.package = lib.mkForce neovimNightlyPackage;

  home.file.".zshinit" = {
    force = true;
    text = ''
      eval "$(${dotfilesPath}/bin/dotfile-env)"
    '';
  };

  programs.zsh = lib.mkIf config.programs.zsh.enable {
    initContent = lib.mkAfter ''
      source ${pkgs.grc}/etc/grc.zsh
      if [ -f "$HOME/.dotfile_zshrc" ]; then
        export DOTFILES_NO_AUTO_UPDATE="false"
        source "$HOME/.dotfile_zshrc"
      fi
    '';
  };
}
