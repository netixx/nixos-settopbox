{ config, pkgs, ... }:
with pkgs.lib;
with (import (builtins.fetchGit https://github.com/netixx/nixos-pkgs + "/iptools.nix")) {inherit config pkgs;};
let
  cfg = config.settopbox;
in
{
  imports = [
    # include fixes when ipv6 is disabled
    (builtins.fetchGit https://github.com/netixx/nixos-pkgs + "/network-ipv6-fixes.nix")
  ];
  # makes sure renaming interfaces works
  # networking.usePredictableInterfaceNames=false;

  # use systemd-networkd for network management
  networking.useNetworkd = true;
  # fix for catch all
  # systemd.network.networks."99-main" = {
  #   enable = pkgs.lib.mkForce false;
  # };

  # disable dhcp client on all interfaces
  networking.useDHCP = false;

  systemd.network.networks."40-WAN".gateway = ["10.0.0.254"];

  networking.enableIPv6 = false;

  networking.vlans = {
    ADMIN = {
      id=1000;
      interface="pLAN";
    };
  };

  networking.interfaces = [
    {
      name = "WAN";
      ipv4.addresses = [
        {
          address = "10.0.0.253";
          prefixLength = 24;
        }
      ];
    }
    {
      name = "ADMIN";
      ipv4.addresses = [
        {
          address = "10.0.254.254";
          prefixLength = 24;
        }
      ];
    }
  ] ++ mapAttrsToList (k: v: { name = k; ipv4.addresses = [ { address = (makeGateway v); prefixLength = v.prefixLength; } ]; } ) cfg.lans;

  networking.vswitches = {
    vs-int = {
      interfaces= [
        {
          name="pLAN";
        }
      ] ++ mapAttrsToList (k: v: { name = k; vlan = (makeVlan v); type="internal"; }) cfg.lans;
      # controllers = [];
      # extraOvsctlCmds=''
      # '';
    };
    vs-ext = {
      interfaces=[
        {
          name="WAN";
          type="internal";
        }
        {
          name="pWAN";
        }
        # {
        #   name="pDMZ";
        # }
      ];
    };
  };

  # enable IPv4 forwarding (router)
  boot = {
    kernel.sysctl = {
      "net.ipv4.conf.all.forwarding" = pkgs.lib.mkOverride 99 true;
      "net.ipv4.conf.default.forwarding" = pkgs.lib.mkOverride 99 true;
      "net.ipv4.ip_forward" = "1";
    };

  };
}
