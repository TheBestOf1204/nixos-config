{ config, pkgs, ... }:
{
  home.stateVersion = "26.11";

  home.packages = with pkgs; [
    ripgrep
    fd
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
}
