{ config, pkgs, ... }:
with pkgs.lib;
let
  cfg = config.settopbox.lans;
  avahiInterfaces = attrNames (filterAttrs (_: value: value.services.advertise) cfg);
in
{
  services.avahi = {
    enable = true;
    domainName = config.home.domain;
    interfaces = avahiInterfaces;
    ipv4 = true;
    ipv6 = true;
    reflector = true;
  };

  /*services.miniupnpd.enable = true;*/
}
