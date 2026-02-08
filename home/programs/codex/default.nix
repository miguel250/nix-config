{
  config,
  pkgs,
  lib,
  ...
}:
let
  tomlFormat = pkgs.formats.toml { };
  homeDir = config.home.homeDirectory;

  writableRoots = [
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
  home.file.".codex/AGENTS.md".source = ./AGENTS.md;
  home.file.".codex/skills/frontend-design".source = ./skills/frontend-design;
  home.activation.codexConfigWritable = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p ${codexDir}
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -f ${codexConfigPath}
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 0644 ${codexConfigFile} ${codexConfigPath}
  '';
}
