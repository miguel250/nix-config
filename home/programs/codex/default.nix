{
  config,
  pkgs,
  lib,
  ...
}:
let
  tomlFormat = pkgs.formats.toml { };
  homeDir = config.home.homeDirectory;

  codexCli = import ./package.nix { inherit pkgs lib; };

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
    "${homeDir}/workspace"
  ];

  codexConfigAttrs = {
    model = "gpt-5.6-sol";
    model_reasoning_effort = "xhigh";
    model_reasoning_summary = "auto";
    personality = "none";
    file_opener = "none";
    show_raw_agent_reasoning = true;

    tui = {
      status_line = [
        "model-with-reasoning"
        "current-dir"
        "context-remaining"
        "used-tokens"
        "fast-mode"
      ];
      status_line_use_colors = true;
    };

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

    features = {
      multi_agent = true;
      memories = true;
      fast_mode = true;
      js_repl = false;
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
    run ${pkgs.python3}/bin/python ${./sync-config.py} \
      ${codexConfigFile} \
      ${lib.escapeShellArg codexConfigPath}
  '';
  home.activation.codexStandalone = lib.hm.dag.entryAfter [ "codexConfigWritable" ] ''
    run ${codexCli.codexStandaloneSync}/bin/sync-codex-standalone ${lib.escapeShellArg codexDir}
  '';
}
