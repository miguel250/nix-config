{ config, pkgs, ... }:
let
  tomlFormat = pkgs.formats.toml {};
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

    features = {
      web_search_request = true;
    };

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
in
{
  home.file.".codex/config.toml".source = codexConfigFile;
  home.file.".codex/AGENTS.md".source = ./AGENTS.md;
  home.file.".codex/skills/frontend-design".source = ./skills/frontend-design;
}
