{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };

    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };

    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };

    ghostty = {
      url = "github:ghostty-org/ghostty";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dotfiles = {
      url = "github:miguel250/dotfiles";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vimrc = {
      url = "github:miguel250/vimrc";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    codex = {
      url = "git+https://github.com/openai/codex?ref=refs/tags/rust-v0.98.0&submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  description = "Flake to manage Miguel's hosts";

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      nix-homebrew,
      homebrew-core,
      homebrew-cask,
      homebrew-bundle,
      ghostty,
      dotfiles,
      vimrc,
      rust-overlay,
      codex,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      forEachSystem = lib.genAttrs systems;

      utils = import ./lib/utils.nix {
        inherit
          nixpkgs
          home-manager
          nix-darwin
          ghostty
          rust-overlay
          dotfiles
          vimrc
          codex
          ;
      };
      workstation = utils.mkHost "workstation";
      mperezPersonal = utils.mkHost "mperez-personal";
      hosts = [
        workstation
        mperezPersonal
      ];
      hostnames = builtins.map (host: host.hostname) hosts;
      darwinHostnames = builtins.map (host: host.hostname) (
        builtins.filter (host: lib.hasSuffix "darwin" host.system) hosts
      );
    in
    {
      formatter = forEachSystem (system: (utils.mkPkgs system).nixfmt);

      devShells = forEachSystem (
        system:
        let
          pkgs = utils.mkPkgs system;
          homeManagerPkg = home-manager.packages.${system}.home-manager;
          devshell = import ./devshell.nix { inherit pkgs homeManagerPkg; };
        in
        {
          inherit (devshell) default;
        }
      );

      checks = forEachSystem (
        system:
        let
          pkgs = utils.mkPkgs system;
          src = self;
        in
        {
          statix = pkgs.runCommand "statix-check" { inherit src; } ''
            cd "$src"
            ${pkgs.statix}/bin/statix check
            touch "$out"
          '';
          deadnix = pkgs.runCommand "deadnix-check" { inherit src; } ''
            cd "$src"
            ${pkgs.deadnix}/bin/deadnix .
            touch "$out"
          '';
          nixfmt = pkgs.runCommand "nixfmt-check" { inherit src; } ''
            cd "$src"
            ${pkgs.nixfmt}/bin/nixfmt --check .
            touch "$out"
          '';
        }
      );

      homeConfigurations = utils.mkHomeConfigurations { hosts = hostnames; };

      darwinConfigurations = utils.mkDarwinConfigurations {
        hosts = darwinHostnames;
        inherit inputs;
      };

      packages = utils.mkPackages {
        inherit self systems;
        inherit hosts;
      };

      apps = forEachSystem (system: {
        switch =
          let
            isDarwin = lib.hasSuffix "darwin" system;
            switchPackage =
              if isDarwin then self.packages.${system}.darwin-switch else self.packages.${system}.home-switch;
            switchBin = if isDarwin then "darwin-switch" else "home-switch";
          in
          {
            type = "app";
            program = "${switchPackage}/bin/${switchBin}";
            meta.description = "switch host configuration";
          };

      });
    };
}
