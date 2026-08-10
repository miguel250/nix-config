{
  lib,
  pkgs,
  ...
}:
let
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
      pkgs.androidStudioPackages.beta
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
