{
  nixpkgs,
  home-manager,
  nix-darwin,
  ghostty,
  rust-overlay,
  dotfiles,
  vimrc,
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
          configurationName = "${host.username}@${host.hostname}";
        in
        {
          name = configurationName;
          value =
            assert lib.assertMsg (
              host.hostname == hostName
            ) "hosts/${hostName} must export hostname = \"${hostName}\"";
            home-manager.lib.homeManagerConfiguration {
              pkgs = mkPkgs host.system;
              extraSpecialArgs = {
                inherit dotfiles vimrc;
                gitUserName = host.git.userName;
                gitUserEmail = host.git.userEmail;
              };
              modules = [
                host.homeModule
                ../home/dotfiles.nix
              ];
            };
        }
      ) hostnames;
      configurationNames = builtins.map (c: c.name) configurations;
    in
    assert lib.assertMsg
      (builtins.length configurationNames == builtins.length (lib.unique configurationNames))
      "mkHomeConfigurations: duplicate configuration names (${lib.concatStringsSep ", " configurationNames})";
    builtins.listToAttrs configurations;

  mkPackages =
    {
      self,
      systems,
      hosts,
    }:
    let
      forEachSystem = lib.genAttrs systems;
      hostsBySystem = lib.groupBy (host: host.system) hosts;
      hostnames = builtins.map (host: host.hostname) hosts;
    in
    assert lib.assertMsg (
      builtins.length hostnames == builtins.length (lib.unique hostnames)
    ) "mkPackages: expected unique host.hostname values, got (${lib.concatStringsSep ", " hostnames})";
    forEachSystem (
      system:
      let
        systemHosts = hostsBySystem.${system} or [ ];
        pkgs = mkPkgs system;
        hostPackages = builtins.listToAttrs (
          builtins.map (host: {
            name = host.hostname;
            value = pkgs.buildEnv {
              name = "${host.hostname}-packages";
              paths = host.packages { inherit pkgs; };
            };
          }) systemHosts
        );
        knownHosts = lib.concatStringsSep ", " (builtins.map (host: host.hostname) systemHosts);
        switchPackage = pkgs.writeShellApplication {
          name = "switch";
          runtimeInputs = [
            (if pkgs.stdenv.isDarwin then
              nix-darwin.packages.${system}.darwin-rebuild
            else
              home-manager.packages.${system}.home-manager)
          ];
          text =
            let
              hostResolver =
                if pkgs.stdenv.isDarwin then
                  ''
                    host_name=""
                    if command -v scutil >/dev/null 2>&1; then
                      host_name="$(scutil --get LocalHostName 2>/dev/null || true)"
                    fi
                    if [ -z "$host_name" ]; then
                      host_name="$(hostname)"
                    fi
                  ''
                else
                  ''
                    host_name="$(hostname -s 2>/dev/null || hostname)"
                  '';
              hostCases = lib.concatMapStringsSep "\n" (
                host:
                if pkgs.stdenv.isDarwin then
                  ''
                    ${host.hostname})
                      exec sudo -H darwin-rebuild switch --flake ${self.outPath}#${host.hostname} "$@"
                      ;;
                  ''
                else
                  ''
                    ${host.hostname})
                      exec home-manager switch --flake ${self.outPath}#${host.username}@${host.hostname} "$@"
                      ;;
                  ''
              ) systemHosts;
            in
            ''
              set -euo pipefail
              ${hostResolver}

              case "$host_name" in
              ${hostCases}
                *)
                  echo "switch: unknown host \"$host_name\"." >&2
                  echo "Known hosts: ${knownHosts}" >&2
                  exit 1
                  ;;
              esac
            '';
        };
        defaults =
          if builtins.length systemHosts == 1 then
            let
              host = builtins.head systemHosts;
            in
            {
              default = self.packages.${system}.${host.hostname};
            }
          else
            { };
      in
      hostPackages // { switch = switchPackage; } // defaults
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
        in
        {
          name = host.hostname;
          value =
            assert lib.assertMsg (
              host.hostname == hostName
            ) "hosts/${hostName} must export hostname = \"${hostName}\"";
            nix-darwin.lib.darwinSystem {
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
                      inherit dotfiles vimrc;
                      gitUserName = host.git.userName;
                      gitUserEmail = host.git.userEmail;
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
