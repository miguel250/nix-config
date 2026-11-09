{
  pkgs,
  lib,
}:
let
  codexVersion = "0.167.0";
  codexReleaseAssets = {
    x86_64-linux = {
      url = "https://github.com/openai/codex/releases/download/rust-v${codexVersion}/codex-package-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-O7916D3mtYrtKPLPbjOtQj7DH9RwChRXuUvlV+pafG4=";
    };
    aarch64-darwin = {
      url = "https://github.com/openai/codex/releases/download/rust-v${codexVersion}/codex-package-aarch64-apple-darwin.tar.gz";
      hash = "sha256-r0XtRdlA15mICWIsHAKW0wmO19f61pUoRCLCKL1FRRc=";
    };
  };
  codexAsset =
    codexReleaseAssets.${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported Codex binary system: ${pkgs.stdenv.hostPlatform.system}");
  codexSource = pkgs.fetchurl {
    inherit (codexAsset) url hash;
  };
in
pkgs.stdenv.mkDerivation (finalAttrs: {
  pname = "codex";
  version = codexVersion;
  src = codexSource;
  sourceRoot = "source";

  nativeBuildInputs = [
    pkgs.installShellFiles
    pkgs.jq
  ];

  dontConfigure = true;
  dontBuild = true;
  # Preserve upstream signatures and the self-contained package used by daemon installs.
  dontFixup = true;

  unpackPhase = ''
    runHook preUnpack
    mkdir "$sourceRoot"
    tar -xzf "$src" -C "$sourceRoot"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R . "$out/"
    runHook postInstall
  '';

  postInstall = ''
    installShellCompletion --cmd codex --zsh <("$out/bin/codex" completion zsh)
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    jq -e --arg version "$version" '
      .layoutVersion == 1 and .version == $version and
      .entrypoint == "bin/codex" and .execServer == "bin/codex-exec-server" and
      .resourcesDir == "codex-resources" and
      .pathDir == "codex-path"
    ' "$out/codex-package.json"
    for executable in bin/codex bin/codex-code-mode-host bin/codex-exec-server codex-path/rg ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux "codex-resources/bwrap"}; do
      test -x "$out/$executable"
    done
    test "$("$out/bin/codex" --version)" = "codex-cli $version"
    runHook postInstallCheck
  '';

  passthru.codexDaemonSync =
    let
      codexDaemon = pkgs.linkFarm "codex-daemon-${finalAttrs.version}" [
        {
          name = "current";
          path = finalAttrs.finalPackage;
        }
      ];
    in
    pkgs.writeShellApplication {
      name = "sync-codex-daemon";
      runtimeInputs = [ pkgs.coreutils ];
      text = ''
        daemon_source=${lib.escapeShellArg (toString codexDaemon)}
        daemon_target="''${1:?Expected Codex home directory}/packages/app-server-daemon"

        for executable in codex codex-code-mode-host codex-exec-server; do
          if [[ ! -f "$daemon_source/current/bin/$executable" || ! -x "$daemon_source/current/bin/$executable" ]]; then
            echo "Missing packaged Codex executable: $executable" >&2
            exit 1
          fi
        done

        if [[ -L "$daemon_target" && "$(readlink -- "$daemon_target")" == "$daemon_source" ]]; then
          exit 0
        fi

        if [[ -e "$daemon_target" && ! -L "$daemon_target" ]]; then
          echo "Refusing to replace unexpected daemon path: $daemon_target" >&2
          exit 1
        fi

        daemon_parent=$(dirname -- "$daemon_target")
        mkdir -p -- "$daemon_parent"
        daemon_stage=$(mktemp -d -- "$daemon_parent/.app-server-daemon.XXXXXX")

        cleanup() {
          local status=$?
          trap - EXIT

          rm -f -- "$daemon_stage/next"
          rmdir -- "$daemon_stage"
          exit "$status"
        }
        trap cleanup EXIT
        trap 'exit 130' INT
        trap 'exit 143' TERM

        ln -s -- "$daemon_source" "$daemon_stage/next"
        mv -Tf -- "$daemon_stage/next" "$daemon_target"
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
