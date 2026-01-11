{
  nixpkgs,
  home-manager,
  nix-darwin,
  ghostty,
  rust-overlay,
  dotfiles,
  vimrc,
  codex,
}:
let
  inherit (nixpkgs) lib;

  mkPkgs =
    system:
    import nixpkgs {
      inherit system;
      overlays = [
        ghostty.overlays.default
        rust-overlay.overlays.default
      ];
      config.allowUnfree = true;
    };

  mkHost = hostname: import ../hosts/${hostname};

  mkHomeConfigurations =
    {
      hostname ? null,
      hosts ? null,
    }:
    let
      hostnames =
        if hosts != null then
          hosts
        else if hostname != null then
          [ hostname ]
        else
          throw "mkHomeConfigurations: expected `hostname` or `hosts`";

      configurations = builtins.map (
        hostName:
        let
          host = mkHost hostName;
          _ = lib.assertMsg (
            host.hostname == hostName
          ) "hosts/${hostName} must export hostname = \"${hostName}\"";
          configurationName = "${host.username}@${host.hostname}";
        in
        {
          name = configurationName;
          value = home-manager.lib.homeManagerConfiguration {
            pkgs = mkPkgs host.system;
            extraSpecialArgs = {
              inherit dotfiles vimrc codex;
            };
            modules = [
              host.homeModule
              ../home/dotfiles.nix
            ];
          };
        }
      ) hostnames;
      configurationNames = builtins.map (c: c.name) configurations;
      _ =
        lib.assertMsg
          (builtins.length configurationNames == builtins.length (lib.unique configurationNames))
          "mkHomeConfigurations: duplicate configuration names (${lib.concatStringsSep ", " configurationNames})";
    in
    builtins.listToAttrs configurations;

  mkPackages =
    {
      self,
      systems,
      hosts,
    }:
    let
      forEachSystem = lib.genAttrs systems;
      hostsBySystem = builtins.listToAttrs (
        builtins.map (host: {
          name = host.system;
          value = host;
        }) hosts
      );
      hostSystems = builtins.map (host: host.system) hosts;
      _ = lib.assertMsg (
        builtins.length hostSystems == builtins.length (lib.unique hostSystems)
      ) "mkPackages: expected unique host.system values, got (${lib.concatStringsSep ", " hostSystems})";
    in
    forEachSystem (
      system:
      let
        host = hostsBySystem.${system};
        pkgs = mkPkgs system;
        hostPackages = host.packages { inherit pkgs codex; };
        basePackages = {
          ${host.hostname} = pkgs.buildEnv {
            name = "${host.hostname}-packages";
            paths = hostPackages;
          };

          default = self.packages.${system}.${host.hostname};

          home-switch = pkgs.writeShellApplication {
            name = "home-switch";
            runtimeInputs = [
              home-manager.packages.${system}.home-manager
            ];
            text = ''
              exec home-manager switch --flake ${self.outPath}#${host.username}@${host.hostname} "$@"
            '';
          };
        };
        darwinPackages = lib.optionalAttrs pkgs.stdenv.isDarwin {
          darwin-switch = pkgs.writeShellApplication {
            name = "darwin-switch";
            runtimeInputs = [
              nix-darwin.packages.${system}.darwin-rebuild
            ];
            text = ''
              exec darwin-rebuild switch --flake ${self.outPath}#${host.hostname} "$@"
            '';
          };
        };
      in
      basePackages // darwinPackages
    );

  mkDarwinConfigurations =
    {
      hosts,
      inputs,
    }:
    let
      configurations = builtins.map (
        hostName:
        let
          host = mkHost hostName;
          _ = lib.assertMsg (
            host.hostname == hostName
          ) "hosts/${hostName} must export hostname = \"${hostName}\"";
        in
        {
          name = host.hostname;
          value = nix-darwin.lib.darwinSystem {
            inherit (host) system;
            specialArgs = {
              inherit inputs;
              inherit (host) hostname username homeDirectory;
            };
            modules = [
              ../hosts/darwin.nix
            ]
            ++ lib.optional (host ? darwinModule) host.darwinModule
            ++ [
              home-manager.darwinModules.home-manager
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  extraSpecialArgs = {
                    inherit dotfiles vimrc codex;
                  };
                  users.${host.username}.imports = [
                    host.homeModule
                    ../home/dotfiles.nix
                  ];
                };
              }
            ];
          };
        }
      ) hosts;
    in
    builtins.listToAttrs configurations;
in
{
  inherit
    mkPkgs
    mkHost
    mkHomeConfigurations
    mkPackages
    mkDarwinConfigurations
    ;
}
