{ config, pkgs, ... }:

{
  programs.bash = {
    shellAliases = {
      ll = "ls -alF";
      la = "ls -A";
      l = "ls -CF";
      x = "exit";
      ".." = "cd ..";
      ff = "fastfetch";
      hf = "hyfetch";
      open = "xdg-open";

      # git shorts
      gst = "git status";
      gcl = "git clone";
      gco = "git commit";
      gcm = "git commit -m";

      wq = "wg-quick";
      # use if ollama-manager is installed
      #om = "ollama-manager";
      ermodeling = ''XDG_DATA_DIRS="/run/current-system/sw/share/gsettings-schemas/gsettings-desktop-schemas-49.1:/run/current-system/sw/share/gsettings-schemas/gtk+3-3.24.51:$XDG_DATA_DIRS" java -jar ~/School/5-6.Semester/DBI/20250818_ermodeling.jar'';

    };

    interactiveShellInit = ''
      eval "$(${pkgs.pay-respects}/bin/pay-respects bash)"
      # [ "$SHLVL" -eq 1 ] && ${pkgs.fastfetch}/bin/fastfetch
      [ "$SHLVL" -eq 1 ] && ${pkgs.hyfetch}/bin/hyfetch
    '';
    # custom terminal prompt, can be used if liked
    # promptInit = ''
    #  PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
    # '';
  };

  environment.variables = {
    HISTCONTROL = "ignoredups:ignorespace";
    HISTSIZE = "100000";
    HISTFILESIZE = "200000";
  };
}
