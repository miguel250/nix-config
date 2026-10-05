{
  pkgs,
  lib,
}:
let
  codexVersion = "0.160.1";
  codexReleaseAssets = {
    x86_64-linux = {
      url = "https://github.com/openai/codex/releases/download/rust-v${codexVersion}/codex-package-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-NAgBVlkGpwKPa6qpq2hTrdrvIh8AFqFBenwf/dlsIfA=";
    };
    aarch64-darwin = {
      url = "https://github.com/openai/codex/releases/download/rust-v${codexVersion}/codex-package-aarch64-apple-darwin.tar.gz";
      hash = "sha256-9zUn7gnG24aay7N7cJhmsznqdO+R0t4lXpx07JYMYxQ=";
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
      .entrypoint == "bin/codex" and .resourcesDir == "codex-resources" and
      .pathDir == "codex-path"
    ' "$out/codex-package.json"
    for executable in bin/codex bin/codex-code-mode-host codex-path/rg codex-resources/zsh/bin/zsh ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux "codex-resources/bwrap"}; do
      test -x "$out/$executable"
    done
    test "$("$out/bin/codex" --version)" = "codex-cli $version"
    runHook postInstallCheck
  '';

  passthru.codexStandaloneSync =
    let
      codexStandalone = pkgs.linkFarm "codex-standalone-${finalAttrs.version}" [
        {
          name = "current";
          path = finalAttrs.finalPackage;
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
          if [[ ! -f "$standalone_source/current/bin/$executable" || ! -x "$standalone_source/current/bin/$executable" ]]; then
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
