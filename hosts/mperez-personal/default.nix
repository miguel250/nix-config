let
  system = "aarch64-darwin";
  username = "miguel";
  hostname = "mperez-personal";
  homeDirectory = "/Users/${username}";

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

  darwinModule =
    { lib, ... }:
    {
      homebrew = {
        brews = lib.mkAfter [ "tailscale" ];
        casks = lib.mkAfter [ "slack" ];
      };
    };

  homeModule =
    {
      pkgs,
      ...
    }:
    {
      imports = [
        ../../home/default.nix
      ];

      home = {
        inherit username homeDirectory;
        stateVersion = "26.05";
        packages = packages { inherit pkgs; };
      };
    };
}
