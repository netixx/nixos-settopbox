{ config, pkgs, ... }:

{
  services.timesyncd = {
    enable = true;
  };

  # containers.ntp = {
  #   autoStart = true;
  #   config = {config, pkgs, lib, ...}: {
      services.chrony = {
        enable = true;
        servers = [ "127.127.1.0" ];
        extraConfig = ''
          allow 127.0.0.0/8
          allow 10.0.0.0/8
          local stratum 12
        '';
      };
  #   };
  # };

}
