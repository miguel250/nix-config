{
  dotfiles,
  gitUserName,
  gitUserEmail,
  ...
}:
let
  dotfilesPath = dotfiles.outPath or dotfiles;
in
{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = gitUserName;
        email = gitUserEmail;
      };
    };
    includes = [
      { path = "${dotfilesPath}/git/config"; }
    ];
  };
}
