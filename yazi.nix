{
  pkgs,
  lib,
  inputs,
  ...
}:
{
  programs.yazi = {
    enable = true;
    package = inputs.yazi.packages.${pkgs.stdenv.hostPlatform.system}.default;

    settings = {
      mgr = {
        ratio = [
          1
          3
          4
        ]; # parent / current / preview width
        sort_by = "natural"; # 1, 2, 10 instead of 1, 10, 2
        sort_dir_first = true;
        show_hidden = false; # toggle live with `.`
        linemode = "size"; # info on the right of each row
        scrolloff = 5;
      };
      preview = {
        wrap = "no";
        tab_size = 2;
      };
    };

    keymap.mgr.prepend_keymap = [
      {
        on = [
          "g"
          "n"
        ];
        run = "cd ~/etc/nixos";
        desc = "Go to NixOS config";
      }
    ];
  };
}
