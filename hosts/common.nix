let
  mkRust =
    {
      pkgs,
    }:
    let
      rustBin = pkgs.rust-bin.stable.latest;
      rustToolchain = rustBin.default.override {
        extensions = [
          "rust-src"
          "clippy"
          "rustfmt"
        ];
      };
      rustPlatform = pkgs.makeRustPlatform {
        cargo = rustToolchain;
        rustc = rustToolchain;
      };
    in
    {
      inherit
        rustBin
        rustToolchain
        rustPlatform
        ;
    };
in
{
  rust = mkRust;

  packages =
    {
      pkgs,
    }:
    let
      rust = mkRust { inherit pkgs; };
    in
    with pkgs;
    [
      ast-grep
      coreutils
      curl
      direnv
      fd
      fzf
      git
      gnused
      grc
      jq
      nerd-fonts.jetbrains-mono
      prek
      python3
      ripgrep
      rust.rustToolchain
      starship
      tmux
      tree
      wget
      zsh
    ];
}
