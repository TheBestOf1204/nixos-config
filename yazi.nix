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

      plugin = {
        prepend_fetchers = [
          {
            url = "*";
            run = "git";
            group = "git";
          }
          {
            url = "*/";
            run = "git";
            group = "git";
          }
        ];
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
      {
        on = "l";
        run = "plugin smart-enter";
        desc = "Enter dir or open file";
      }
    ];

    plugins = {
      # 1. just a path → only linked, no setup() call
      smart-enter = "${inputs.yazi-plugins}/smart-enter.yazi";

      # 2. setup = true → HM writes  require("git"):setup()  into init.lua
      git = {
        package = "${inputs.yazi-plugins}/git.yazi";
        setup = true;
      };

      # 3. setup with arguments → Nix attrset becomes a Lua table
      full-border = {
        package = "${inputs.yazi-plugins}/full-border.yazi";
        setup = true;
        settings = {
          type = lib.generators.mkLuaInline "ui.Border.ROUNDED";
        };
      };
    };

    flavors.catppuccin-mocha = "${inputs.yazi-flavors}/catppuccin-mocha.yazi";

    theme = {
      flavor = {
        dark = "catppuccin-mocha";
        light = "catppuccin-mocha";
      };

      app.overall.bg = "#1e1e2e";

      # your own overrides win over the flavor
      git = {
        unstaged_sign = "M";
        deleted_sign = "D";
      };
    };
  };

  home.packages = with pkgs; [
    ffmpeg
    poppler-utils
    _7zz
    jq
  ];
}
