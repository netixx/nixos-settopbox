{ config, pkgs, ... }:
with pkgs.lib;
with (import (builtins.fetchGit https://github.com/netixx/nixos-pkgs + "/iptools.nix")) {inherit config pkgs;};
let
  cfg = config.settopbox;
  firewallInterfaces = attrNames cfg.lans;
  inputChain = interfaceName: "input_${interfaceName}";
  firewallInterfaceMatch = map (interfaceName:
  let
    lanConfig = cfg.lans.${interfaceName};
  in
    with cfg.lans.${interfaceName};"iifname ${interfaceName} jump ${inputChain interfaceName}") firewallInterfaces;
  firewallInterfaceChains = map (interfaceName:
  let
    lanConfig = cfg.lans.${interfaceName};
  in
    with cfg.lans.${interfaceName};''
    # chain for ${interfaceName}
    chain ${inputChain interfaceName} {
      ${lanConfig.firewall.rules}
      ${concatStringsSep "\n" (map (v: "jump ${v}") lanConfig.firewall.chains)}
    }

  '') firewallInterfaces;

  interfaceNetworks = mapAttrs (key: value: (makeCidr value)) cfg.lans;

  interfaceNetBlocks = mapAttrsToList (interfaceName: value:
  ''
    # net block for ${interfaceName}
    set net_${interfaceName} {
      type ipv4_addr; flags constant, interval;

      elements = {
        ${value}
      }
    }
  '') interfaceNetworks;


in
{
  networking.firewall.enable = false;
  networking.nftables = {
    enable = true;
    ruleset = ''
      table inet filter {
        set net_admin {
          type ipv4_addr; flags constant, interval;

          elements = {
            10.0.254.0/24
          }
        }

        ${concatStringsSep "\n" interfaceNetBlocks}

        set net_lan {
          type ipv4_addr; flags constant, interval;

          elements = {
            ${concatStringsSep ",\n" (attrValues interfaceNetworks)}
          }
        }

        set net_srv {
          type ipv4_addr; flags constant, interval;

          elements = {
            ${concatStringsSep ",\n" (attrValues (filterAttrs (key: _: (hasPrefix "SRV_" key)) interfaceNetworks))}
          }
        }

        set net_usr {
          type ipv4_addr; flags constant, interval;

          elements = {
            ${concatStringsSep ",\n" (attrValues (filterAttrs (key: _: (hasPrefix "USR_" key)) interfaceNetworks))}
          }
        }

        set net_obj {
          type ipv4_addr; flags constant, interval;

          elements = {
            ${concatStringsSep ",\n" (attrValues (filterAttrs (key: _: (hasPrefix "OBJ_" key)) interfaceNetworks))}
          }
        }

        # Block all incomming connections traffic except SSH and "ping".
        chain input {
          type filter hook input priority 0;policy drop;

          # accept any localhost traffic
          iifname lo accept

          # accept traffic originated from us
          ct state {established, related} accept
          # ct state invalid drop

          iifname WAN  jump input_WAN
          iifname ADMIN jump input_ADMIN

          # protect admin
          ip daddr @net_admin drop
          # ip saddr != @net_admin daddr @net_admin drop

          ${concatStringsSep "\n" firewallInterfaceMatch}

          iifname "tun1" jump input_USR_WIR
          iifname "tun0" jump input_USR_WIR

          # ICMP
          # routers may also want: mld-listener-query, nd-router-solicit
          #ip6 nexthdr icmpv6 icmpv6 type { destination-unreachable, packet-too-big, time-exceeded, parameter-problem, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } accept
          #ip protocol icmp icmp type { destination-unreachable, router-advertisement, time-exceeded, parameter-problem } accept

          ${cfg.firewall.rules.input}
          # count and drop any other traffic
          counter drop
        }

        # Allow all outgoing connections.
        chain output {
          type filter hook output priority 0;
          accept
        }

        chain forward {
          type filter hook forward priority 0;

          # prevent direct DNS resolv (use provided DNS)
          udp dport 53 counter reject
          tcp dport 53 counter reject

          # TODO : ntp,

          accept
        }

        chain input_basic {
          tcp dport ntp accept
          udp dport ntp accept
          udp dport {bootpc, bootps} accept
          udp dport domain accept
          tcp dport domain accept

          # web browsing
          tcp dport {80, 443} accept
          # quik
          udp dport 443 accept

          continue
        }

        chain input_trusted {
          #policy drop;
          jump input_basic

          # ping at reasonable rate
          ip6 nexthdr icmpv6 icmpv6 type echo-request limit rate 10/second accept
          ip protocol icmp icmp type echo-request limit rate 10/second accept

          ${cfg.firewall.rules.trusted}
        }

        chain input_WAN {
          tcp dport 1195 accept
          udp dport 1196 accept
          counter drop
        }

        chain input_ADMIN {
          ip6 nexthdr icmpv6 icmpv6 type echo-request accept
          ip protocol icmp icmp type echo-request accept
          ip saddr @net_admin udp dport {radius, radius-acct} accept
          ip saddr @net_admin tcp dport 22 accept
          ip saddr @net_admin tcp dport 19999 accept
          jump input_basic;
        }

        ${concatStringsSep "\n" firewallInterfaceChains}
      }

      # nat
      table ip nat {
        chain prerouting {
          type nat hook prerouting priority 0;
        }
        chain postrouting {
          type nat hook postrouting priority 0;
          oifname "WAN" masquerade
        }
      }
    '';
  };

}
