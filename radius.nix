{ config, pkgs, ... }:

{
  /*environment.systemPackages = with pkgs; [
    freeradius
  ];

  systemd.*/
  config.services.freeradius = {
    enable=true;
    configDir="/etc/firewall/freeradius";
  };

  config.systemd.services.freeradius.serviceConfig.LogsDirectory= "radius";

}
