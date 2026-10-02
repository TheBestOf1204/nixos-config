{ pkgs, ... }:
{
  programs.niri = {
    enable = true;
    useNautilus = false; # GTK file picker instead of Nautilus
  };

  programs.dank-material-shell = {
    enable = true;
    systemd = {
      enable = true; # off by default in the flake module
      target = "niri.service"; # only start in niri, not Plasma
    };
  };

  # plasma6 and niri both mkDefault this -> eval conflict without it
  services.displayManager.defaultSession = "plasma";

  # niri enables gnome-keyring, would also start gnome ssh agent
  # open ssh agent already used (via configuration.nix programs.ssh.startAgent)
  # so not needed and turned off
  services.gnome.gcr-ssh-agent.enable = false;

  services.displayManager.dms-greeter = {
    enable = true;
    compositor.name = "niri"; # the greeter runs inside niri
    configHome = "/home/linus"; # takes your DMS wallpaper and theme for the login screen
  };

  qt.platformTheme = "kde";

  # X11 apps in niri
  environment.systemPackages = [
    pkgs.xwayland-satellite
    pkgs.ghostty
  ];
}
