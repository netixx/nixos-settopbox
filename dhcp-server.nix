{ config, pkgs, ... }:
with pkgs.lib;
with (import (builtins.fetchGit {url=https://github.com/netixx/nixos-pkgs; rev="master";} + "/iptools.nix")) {inherit config pkgs;};
let
  cfg = config.settopbox;
  dhcpInterfaces = attrNames (filterAttrs (_: value: value.services.dhcp.enable) cfg.lans );
  dhcpSubnetsStrings = map (interface_name:
    let
      lanConfig = cfg.lans.${interface_name};
    in
      with cfg.lans.${interface_name};''
      #${interface_name}
      subnet ${makeNetwork lanConfig} netmask ${netmask} {
        pool {
          range ${makeRange lanConfig};
        }
        ${if services.dhcp.router then "   \noption routers ${makeGateway lanConfig};\n" else ""}
        ${services.dhcp.extraConfig}
      }
    ''
    ) dhcpInterfaces;
  dhcpHosts = mapAttrsToList (name: hostConfig:
    ''
      host ${name} {
        hardware ethernet ${hostConfig.macAddress};
        option host-name "${name}";
        ${optionalString (hostConfig.ipAddress != null) "fixed-address ${hostConfig.ipAddress};"}
        ${optionalString (!hostConfig.globalConnectivity) "option routers \0;"}
        ${optionalString (!hostConfig.globalConnectivity) "option domain-name-servers \0;"}
      }
    '') (filterAttrs (_: v: v.macAddress != null) cfg.hosts);

in
{
  services.dhcpd4 = {
    enable=true;
    interfaces = dhcpInterfaces;
    extraConfig = ''
      option domain-name "${config.home.domain}";
      option domain-search "${config.home.domain}";

      option arch code 93 = unsigned integer 16; # RFC4578

      default-lease-time 7200;
      max-lease-time 86400;
      one-lease-per-client true;
      deny duplicates;
      ping-check true;
      # DDNS
      # update-conflict-detection false;
      # update-static-leases on;

      option domain-name-servers ${config.home.dns};
      option ntp-servers 10.0.111.254;

      ${concatStringsSep "\n\n" dhcpSubnetsStrings}

      # ADMIN
      subnet 10.0.254.0 netmask 255.255.255.0 {
        pool {
          range 10.0.254.64 10.0.254.96;
        }

        option routers 10.0.254.254;
        # option domain-name-servers 10.0.254.254;
      }

      ${concatStringsSep "\n\n" dhcpHosts}

    '';
  };

  systemd.services.dhcpd4.requires = [ "network-online.target" ];
  systemd.services.dhcpd4.after = [ "network-online.target" ];
  systemd.services.dhcpd4.bindsTo = [ "network-online.target" ];
}
