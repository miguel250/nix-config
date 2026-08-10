let
  system = "x86_64-linux";
  username = "mperez";
  hostname = "workstation";
  homeDirectory = "/home/${username}";
  git = {
    userName = "Miguel Perez";
    userEmail = "miguel@miguelpz.com";
  };

  common = import ../common.nix;
  inherit (common) packages;
in
{
  inherit
    system
    username
    hostname
    homeDirectory
    git
    packages
    ;

  homeModule =
    {
      pkgs,
      ...
    }:
    {
      imports = [
        ../../home/default.nix
        ./android.nix
      ];

      nixpkgs.config.nvidia.acceptLicense = true;

      targets.genericLinux = {
        enable = true;

        # This must match the proprietary NVIDIA driver loaded by the host OS.
        gpu.nvidia = {
          enable = true;
          version = "610.57.04";
          sha256 = "sha256-suk1xmuDuwDAyFe8jg7g/VLekoa0DJzB7sKafOfrEW0=";
        };
      };

      home = {
        inherit username homeDirectory;
        stateVersion = "26.05";
        packages = packages { inherit pkgs; };
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
