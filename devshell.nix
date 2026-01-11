{
  pkgs,
  homeManagerPkg,
}:
{
  default = pkgs.mkShell {
    packages = with pkgs; [
      deadnix
      nixfmt
      statix
      homeManagerPkg
    ];
  };
}
