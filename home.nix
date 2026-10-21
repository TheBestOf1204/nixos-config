{
  config,
  pkgs,
  inputs,
  ...
}:

let
  myRPackages = with pkgs.rPackages; [
    ggplot2
    dplyr
    data_table
    tidyverse
  ];
in

{
  imports = [
    ./yazi.nix
    ./superfile.nix
    ./scripts/dn.nix
  ];

  home.stateVersion = "26.11";

  home.packages = with pkgs; [
    ripgrep
    fd
    (rstudioWrapper.override { packages = myRPackages; })
    (rWrapper.override { packages = myRPackages; })
    imv
    jq
  ];

  programs.bat.enable = true;
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.starship.enable = true;
  xdg.configFile."starship.toml".source = ./starship.toml;

  programs.bash.enable = true;

  xdg.configFile."tridactyl/tridactylrc".text = ''
    bind J tabnext
    bind K tabprev
  '';
}
