let
  mkRust =
    {
      pkgs,
      codex,
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
      codexCli = codex.packages.${pkgs.stdenv.hostPlatform.system}.codex-rs.override {
        inherit rustPlatform;
      };
    in
    {
      inherit
        rustBin
        rustToolchain
        rustPlatform
        codexCli
        ;
    };
in
{
  rust = mkRust;

  packages =
    {
      pkgs,
      codex,
    }:
    let
      rust = mkRust { inherit pkgs codex; };
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
      rust.codexCli
      rust.rustToolchain
      starship
      tmux
      tree
      wget
      zsh
    ];
}
