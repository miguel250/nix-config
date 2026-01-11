let
  system = "x86_64-linux";
  username = "mperez";
  hostname = "workstation";
  homeDirectory = "/home/${username}";

  common = import ../common.nix;
  inherit (common) packages;
in
{
  inherit
    system
    username
    hostname
    homeDirectory
    packages
    ;

  homeModule =
    {
      pkgs,
      codex,
      ...
    }:
    {
      imports = [
        ../../home/default.nix
      ];

      targets.genericLinux.enable = true;

      home = {
        inherit username homeDirectory;
        stateVersion = "26.05";
        packages = packages { inherit pkgs codex; };
      };

      fonts.fontconfig.enable = true;

      dconf = {
        settings = {
          "org/gnome/desktop/interface" = {
            clock-format = "24h";
            timezone = "America/New_York";
          };
        };
      };
    };
}
