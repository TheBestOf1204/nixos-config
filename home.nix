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

  programs.bash.enable = true;
}
