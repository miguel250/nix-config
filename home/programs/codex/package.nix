{
  pkgs,
  lib,
}:
let
  codexVersion = "0.145.0";
  codexReleaseAssets = {
    x86_64-linux = {
      url = "https://github.com/openai/codex/releases/download/rust-v${codexVersion}/codex-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-v68Tybo08q12TkqRbEnPcXeuujKc8PcZ4iJ1ZvyNZio=";
      binaryName = "codex-x86_64-unknown-linux-musl";
      codeModeHostUrl = "https://github.com/openai/codex/releases/download/rust-v${codexVersion}/codex-code-mode-host-x86_64-unknown-linux-musl.tar.gz";
      codeModeHostHash = "sha256-rCMXeVbDDMH58YDCe9gPW7W3Z4DbVfuU3MImRNSQhS4=";
      codeModeHostBinaryName = "codex-code-mode-host-x86_64-unknown-linux-musl";
    };
    aarch64-darwin = {
      url = "https://github.com/openai/codex/releases/download/rust-v${codexVersion}/codex-aarch64-apple-darwin.tar.gz";
      hash = "sha256-Byowpl8FZmc1iJ7w9gtW2xhq293p1cXMGmS+C1mFMP4=";
      binaryName = "codex-aarch64-apple-darwin";
      codeModeHostUrl = "https://github.com/openai/codex/releases/download/rust-v${codexVersion}/codex-code-mode-host-aarch64-apple-darwin.tar.gz";
      codeModeHostHash = "sha256-dfkwaDSqiRO1wfkf9y8fa5RB5aks1dZLjmBc9UZoRgw=";
      codeModeHostBinaryName = "codex-code-mode-host-aarch64-apple-darwin";
    };
  };
  codexAsset =
    codexReleaseAssets.${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported Codex binary system: ${pkgs.stdenv.hostPlatform.system}");
  codexSource = pkgs.fetchurl {
    inherit (codexAsset) url hash;
  };
  codeModeHostSource = pkgs.fetchurl {
    url = codexAsset.codeModeHostUrl;
    hash = codexAsset.codeModeHostHash;
  };
in
pkgs.stdenv.mkDerivation {
  pname = "codex";
  version = codexVersion;
  srcs = [
    codexSource
    codeModeHostSource
  ];

  nativeBuildInputs = [ pkgs.installShellFiles ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    for source in $srcs; do
      tar -xzf "$source"
    done
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 "${codexAsset.binaryName}" "$out/bin/codex"
    install -Dm755 "${codexAsset.codeModeHostBinaryName}" "$out/bin/codex-code-mode-host"
    runHook postInstall
  '';

  postInstall = ''
    installShellCompletion --cmd codex --zsh <("$out/bin/codex" completion zsh)
  '';

  meta = {
    description = "OpenAI Codex CLI - prebuilt binary";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = builtins.attrNames codexReleaseAssets;
  };
}
