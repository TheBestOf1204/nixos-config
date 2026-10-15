# Home Manager module that installs `dn`, a menu for the dotnet CLI.
# Import it from home.nix:   imports = [ ./scripts/dn.nix ];
{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "dn";
      # dotnet itself is deliberately NOT listed: dn uses whatever SDK is on your
      # PATH, so it always matches the SDK your projects and Rider use.
      runtimeInputs = with pkgs; [
        gum
        jq
        dotnet-ef # for the "EF Core: …" actions; drop it if you don't use EF Core
        coreutils
        findutils
        gnugrep
        gnused
        gawk
      ];
      text = builtins.readFile ./dn.sh;
    })
  ];
}
