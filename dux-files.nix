{ inputs, ... }:
{
  imports = [ inputs.dux-files.homeModules.dux-files ];

  programs.dux-files = {
    enable = true;
    systemd.enable = true;
  };
}
