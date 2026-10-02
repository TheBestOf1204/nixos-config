{ pkgs, inputs, ... }:
{
  environment.systemPackages = [
    inputs.superfile.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
