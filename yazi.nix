{
  config,
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

      starship = {
        package = inputs.starship-yazi;
        setup = true;
      };
    };

    flavors.catppuccin-mocha = "${inputs.yazi-flavors}/catppuccin-mocha.yazi";

    theme = {
      flavor = {
        dark = "dms";
        light = "dms";
      };

      # your own overrides win over the flavor
      git = {
        unstaged_sign = "M";
        deleted_sign = "D";
      };
    };
  };

  # tell matugen (via DMS) about the template
  # tell DMS about the template (same mechanism as your superfile one)
  xdg.configFile."matugen/dms/configs/yazi.toml".text = ''
    [templates.yazi]
    input_path = '${./matugen/yazi-flavor.toml}'
    output_path = '${config.xdg.configHome}/yazi/flavors/dms.yazi/flavor.toml'
  '';

  # syntax highlighting theme for code previews (a flavor ships one);
  # side effect: makes flavors/dms.yazi a real, writable directory
  xdg.configFile."yazi/flavors/dms.yazi/tmtheme.xml".source =
    "${inputs.yazi-flavors}/catppuccin-mocha.yazi/tmtheme.xml";

  home.packages = with pkgs; [
    ffmpeg
    poppler-utils
    _7zz
    jq
  ];
}
