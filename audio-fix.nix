{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.alsa-utils ];

  systemd.services.fix-audio = {
    description = "Fix some stupid ES8336 speaker routing problems, idk why, if you don't have these issues without this, don't use it!! yee";
    wantedBy = [ "sound.target" ];
    after = [ "sound.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = [
        "${pkgs.alsa-utils}/bin/amixer -c sofessx8336 set 'Left Headphone Mixer Left DAC' on"
        "${pkgs.alsa-utils}/bin/amixer -c sofessx8336 set 'Right Headphone Mixer Right DAC' on"
      ];
    };
  };
}
