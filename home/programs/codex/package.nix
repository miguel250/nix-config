{
  pkgs,
  lib,
}:
let
  codexVersion = "0.117.0";
  codexReleaseAssets = {
    x86_64-linux = {
      url = "https://github.com/openai/codex/releases/download/rust-v${codexVersion}/codex-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-n3icJBOFQx8f6czScRMhHxz9hGVfFVpcBiAQtixvWi8=";
      binaryName = "codex-x86_64-unknown-linux-musl";
    };
    aarch64-darwin = {
      url = "https://github.com/openai/codex/releases/download/rust-v${codexVersion}/codex-aarch64-apple-darwin.tar.gz";
      hash = "sha256-HoL2K02PjvnA3vyw5o3DXaFofSyPteaMovRB85WZh/0=";
      binaryName = "codex-aarch64-apple-darwin";
    };
  };
  codexAsset =
    codexReleaseAssets.${pkgs.stdenv.hostPlatform.system} or (
      throw "Unsupported Codex binary system: ${pkgs.stdenv.hostPlatform.system}"
    );
in
pkgs.stdenv.mkDerivation {
  pname = "codex";
  version = codexVersion;
  src = pkgs.fetchurl {
    inherit (codexAsset) url hash;
  };

  nativeBuildInputs = [ pkgs.installShellFiles ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    tar -xzf "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 "${codexAsset.binaryName}" "$out/bin/codex"
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
