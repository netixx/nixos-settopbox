{ config, pkgs, ... }:

{
  services.timesyncd = {
    enable = false;
  };

  # containers.ntp = {
  #   autoStart = true;
  #   config = {config, pkgs, lib, ...}: {
      services.chrony = {
        enable = true;
        servers = [
          "ntp.midway.ovh"
          "ntp.unice.fr"
          "0.fr.pool.ntp.org"
          "1.fr.pool.ntp.org"
          "0.nixos.pool.ntp.org"
          "1.nixos.pool.ntp.org"
        ];
        extraConfig = ''
          allow 127.0.0.0/8
          allow 10.0.0.0/8
          local stratum 13 orphan
        '';
      };
  #   };
  # };

}
