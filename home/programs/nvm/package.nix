{
  pkgs,
  lib,
}:
let
  nvmVersion = "0.40.7";
  nvmHash = "sha256-bClD8XKR9yWztQQ3BDHES7VK2dyPCL1yqULpPR/K+wM=";
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "nvm";
  version = nvmVersion;

  src = pkgs.fetchFromGitHub {
    owner = "nvm-sh";
    repo = "nvm";
    rev = "v${nvmVersion}";
    hash = nvmHash;
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm644 nvm.sh "$out/share/nvm/nvm.sh"
    install -Dm644 bash_completion "$out/share/nvm/bash_completion"
    install -Dm755 nvm-exec "$out/share/nvm/nvm-exec"
    runHook postInstall
  '';

  meta = {
    description = "Node Version Manager";
    homepage = "https://github.com/nvm-sh/nvm";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
