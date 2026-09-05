{
  pkgs,
  lib,
}:
let
  codexVersion = "0.153.4";
  codexReleaseAssets = {
    x86_64-linux = {
      url = "https://github.com/openai/codex/releases/download/rust-v${codexVersion}/codex-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-9HlCTsoJJITcQNh64oxE9MxAI0pgBF1hMeSTgA2BSjA=";
      binaryName = "codex-x86_64-unknown-linux-musl";
      codeModeHostUrl = "https://github.com/openai/codex/releases/download/rust-v${codexVersion}/codex-code-mode-host-x86_64-unknown-linux-musl.tar.gz";
      codeModeHostHash = "sha256-+VgwqGlZCVdmS7/Ge8ywh3OAa2k2cLrxWQgXb4m0zTE=";
      codeModeHostBinaryName = "codex-code-mode-host-x86_64-unknown-linux-musl";
    };
    aarch64-darwin = {
      url = "https://github.com/openai/codex/releases/download/rust-v${codexVersion}/codex-aarch64-apple-darwin.tar.gz";
      hash = "sha256-jPkR6mdlI7+yEh7FYYSNKrpWSJCtU2202KM1PyuYULE=";
      binaryName = "codex-aarch64-apple-darwin";
      codeModeHostUrl = "https://github.com/openai/codex/releases/download/rust-v${codexVersion}/codex-code-mode-host-aarch64-apple-darwin.tar.gz";
      codeModeHostHash = "sha256-Ramw/fU7mLhaa7keF13ZDpYTKKehT7UKQJAiBRmd8d8=";
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
pkgs.stdenv.mkDerivation (finalAttrs: {
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

  passthru.codexStandaloneSync =
    let
      codexStandalone = pkgs.linkFarm "codex-standalone-${finalAttrs.version}" [
        {
          name = "current";
          path = "${finalAttrs.finalPackage}/bin";
        }
      ];
    in
    pkgs.writeShellApplication {
      name = "sync-codex-standalone";
      runtimeInputs = [ pkgs.coreutils ];
      text = ''
        standalone_source=${lib.escapeShellArg (toString codexStandalone)}
        standalone_target="''${1:?Expected Codex home directory}/packages/standalone"

        for executable in codex codex-code-mode-host; do
          if [[ ! -f "$standalone_source/current/$executable" || ! -x "$standalone_source/current/$executable" ]]; then
            echo "Missing packaged Codex executable: $executable" >&2
            exit 1
          fi
        done

        if [[ -L "$standalone_target" && "$(readlink -- "$standalone_target")" == "$standalone_source" ]]; then
          exit 0
        fi

        if [[ -e "$standalone_target" && ! -L "$standalone_target" && ! -d "$standalone_target" ]]; then
          echo "Refusing to replace unexpected standalone path: $standalone_target" >&2
          exit 1
        fi

        standalone_parent=$(dirname -- "$standalone_target")
        mkdir -p -- "$standalone_parent"
        standalone_stage=$(mktemp -d -- "$standalone_parent/.standalone.XXXXXX")

        cleanup() {
          local status=$?
          trap - EXIT

          rm -f -- "$standalone_stage/next"
          rmdir -- "$standalone_stage"
          exit "$status"
        }
        trap cleanup EXIT
        trap 'exit 130' INT
        trap 'exit 143' TERM

        ln -s -- "$standalone_source" "$standalone_stage/next"
        if [[ -d "$standalone_target" && ! -L "$standalone_target" ]]; then
          rm -rf -- "$standalone_target"
        fi
        mv -Tf -- "$standalone_stage/next" "$standalone_target"
      '';
    };

  meta = {
    description = "OpenAI Codex CLI - prebuilt binary";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = builtins.attrNames codexReleaseAssets;
  };
})
