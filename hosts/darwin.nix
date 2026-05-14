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

  system.defaults = {
    NSGlobalDomain = {
      InitialKeyRepeat = 10;
      KeyRepeat = 2;
      AppleShowAllFiles = true;
      "com.apple.trackpad.scaling" = 3.0;
    };

    dock = {
      autohide = true;
      mru-spaces = false;
      tilesize = 48;
      largesize = 72;
      orientation = "bottom";
      magnification = true;
      wvous-bl-corner = 13; # hotcorner lock screen
    };

    CustomUserPreferences = {
      "com.apple.menuextra.clock" = {
        # Show 24-hour clock in menu bar.
        Show24Hour = true;
      };
    };
  };

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
      autoUpdate = false;
      upgrade = true;
    };
    global.autoUpdate = false;
    casks = [
      {
        name = "ghostty@tip";
        greedy = true;
      }
      "discord"
      "spotify"
      "1password@beta"
    ];
  };
}
