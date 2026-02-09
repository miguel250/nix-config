{
  config,
  pkgs,
  codex,
  lib,
  ...
}:
let
  tomlFormat = pkgs.formats.toml { };
  homeDir = config.home.homeDirectory;

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

  codexCli =
    (codex.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
      inherit rustPlatform;
    }).overrideAttrs
      (oa:
      let
        installShellCompletions = oa.installShellCompletions or true;
      in
      {
        nativeBuildInputs =
          (oa.nativeBuildInputs or [ ])
          ++ (with pkgs; [
            cmake
            gitMinimal
            installShellFiles
            llvmPackages.clang
            pkg-config
          ]);
        buildInputs =
          (oa.buildInputs or [ ])
          ++ (with pkgs; [
            openssl
            pkgs.llvmPackages.libclang.lib
          ]);
        env = (oa.env or { }) // {
          PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
          LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
          RUST_MIN_STACK=16777216;
          CC = "clang";
          CXX = "clang++";
          NIX_CFLAGS_COMPILE = toString (
            pkgs.lib.optionals pkgs.stdenv.cc.isGNU [
              "-Wno-error=stringop-overflow"
            ]
            ++ pkgs.lib.optionals pkgs.stdenv.cc.isClang [
              "-Wno-error=character-conversion"
            ]
          );
        };
        postInstall =
          (oa.postInstall or "")
          + lib.optionalString installShellCompletions ''
            installShellCompletion --cmd codex --zsh <($out/bin/codex completion zsh)
          '';
      });

  writableRoots = [
    "${homeDir}/.codex/skills"
    "${homeDir}/.cache"
    "${homeDir}/.cache/pip"
    "${homeDir}/.cache/uv"
    "${homeDir}/.cargo"
    "${homeDir}/.rustup"
    "${homeDir}/.yarn"
    "${homeDir}/.npm"
    "${homeDir}/.local/share/pnpm"
  ];

  codexConfigAttrs = {
    model_reasoning_effort = "xhigh";
    model_reasoning_summary = "auto";
    file_opener = "none";
    show_raw_agent_reasoning = true;

    sandbox_mode = "workspace-write";
    approval_policy = "on-request";
    web_search = "live";

    sandbox_workspace_write = {
      network_access = true;
      writable_roots = writableRoots;
    };

    shell_environment_policy = {
      "inherit" = "all";
      ignore_default_excludes = true;
    };
  };

  codexConfigFile = tomlFormat.generate "codex-config.toml" codexConfigAttrs;
  codexDir = "${config.home.homeDirectory}/.codex";
  codexConfigPath = "${codexDir}/config.toml";
in
{
  home.packages = lib.mkAfter [ codexCli ];
  home.file.".codex/AGENTS.md".source = ./AGENTS.md;
  home.file.".codex/skills/frontend-design".source = ./skills/frontend-design;
  home.file.".codex/skills/notebook".source = ./skills/notebook;
  home.activation.codexConfigWritable = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p ${codexDir}
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -f ${codexConfigPath}
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 0644 ${codexConfigFile} ${codexConfigPath}
  '';
}
