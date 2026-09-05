{
  lib,
  pkgs,
  ...
}:
let
  # nixpkgs beta 2026.1.3.6 points at an upstream-corrupted archive.
  # Pin the next RC until nixpkgs advances its beta package.
  androidStudioBeta =
    pkgs.callPackage
      (import "${pkgs.path}/pkgs/applications/editors/android-studio/linux.nix" {
        channel = "beta";
        pname = "android-studio-beta";
        version = "2026.1.4.5";
        sources.x86_64-linux = {
          sha256Hash = "sha256-of6o6bn3hpc5OyHJbm005GFeW2K1q3STQU4vzPRhB0w=";
          url = "https://edgedl.me.gvt1.com/android/studio/ide-zips/2026.1.4.5/android-studio-quail4-rc1-linux.tar.gz";
        };
        meta = pkgs.androidStudioPackages.beta.meta;
      })
      {
        fontsConf = pkgs.makeFontsConf { fontDirectories = [ ]; };
        tiling_wm = false;
      };
  androidComposition = pkgs.androidenv.composeAndroidPackages {
    platformVersions = [ "36" ];
    buildToolsVersions = [
      "35.0.0"
      "36.0.0"
    ];
    cmakeVersions = [
      "3.22.1"
      "4.1.2"
    ];

    includeEmulator = true;
    includeSystemImages = true;
    systemImageTypes = [ "google_apis" ];
    abiVersions = [ "x86_64" ];

    includeNDK = true;
    ndkVersions = [ "27.1.12297006" ];
  };
  androidSdk = androidComposition.androidsdk;
  androidSdkRoot = "${androidSdk}/libexec/android-sdk";
in
{
  nixpkgs.config = {
    android_sdk.accept_license = true;
    allowUnfree = true;
  };

  home = {
    packages = [
      androidStudioBeta
      pkgs.jdk17
      androidSdk
    ];

    sessionVariables = {
      ANDROID_HOME = androidSdkRoot;
      ANDROID_SDK_ROOT = androidSdkRoot;
      JAVA_HOME = "${pkgs.jdk17.home}";
    };
  };

  # The dotfiles Zsh configuration loads after Home Manager's session variables
  # and assigns macOS-specific Android and Java values on Linux.
  programs.zsh.initContent = lib.mkOrder 2000 ''
    export ANDROID_HOME="${androidSdkRoot}"
    export ANDROID_SDK_ROOT="${androidSdkRoot}"
    export JAVA_HOME="${pkgs.jdk17.home}"
  '';
}
