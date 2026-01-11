{
  inputs,
  hostname,
  username,
  homeDirectory,
  pkgs,
  ...
}:
{
  imports = [
    inputs.nix-homebrew.darwinModules.nix-homebrew
  ];

  nix = {
    enable = false;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      warn-dirty = false;
    };
    channel.enable = false;
  };

  nixpkgs = {
    config.allowUnfree = true;
    overlays = [
      inputs.rust-overlay.overlays.default
    ];
  };

  networking = {
    hostName = hostname;
    computerName = hostname;
  };

  users.users.${username} = {
    home = homeDirectory;
    shell = pkgs.zsh;
  };

  system.primaryUser = username;
  system.stateVersion = 6;

  nix-homebrew = {
    enable = true;
    enableRosetta = false;
    autoMigrate = true;
    mutableTaps = true;
    user = username;
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "homebrew/homebrew-bundle" = inputs.homebrew-bundle;
    };
  };

  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap";
      autoUpdate = true;
      upgrade = true;
    };
    casks = [
      "ghostty"
      "discord"
      "spotify"
    ];
  };
}
