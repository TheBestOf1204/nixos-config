{
  config,
  pkgs,
  inputs,
  ...
}:
{
  programs.superfile = {
    enable = true;
    package = inputs.superfile.packages.${pkgs.stdenv.hostPlatform.system}.default;
  };

  xdg.configFile."matugen/dms/configs/superfile.toml".text = ''
    [templates.superfile]
    input_path = '${./matugen/superfile.toml}'
    output_path = '${config.xdg.configHome}/superfile/theme/dms.toml'
  '';
}
