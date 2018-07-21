{ config, lib, pkgs, ... }:
with lib;

let
  dhcpServiceConfig = {
      options = {
          enable = mkOption {
              type = types.bool;
              example = true;
              default = true;
              description = "Whether to provide DHCP service";
          };

          range = mkOption {
              type = types.nullOr types.str;
              example = "10.0.0.1 10.0.0.253";
              default = null;
              description = "Range of IP to distribute via DHCP";
          };

          router = mkOption {
              type = types.bool;
              example = false;
              default = true;
              description = "Whether to provide router via DHCP";
          };

          extraConfig = mkOption {
              type = types.str;
              example = ''
                  domain-search "test";
              '';
              default = "";
              description = "Extra configuration to add to this subnet section";
          };
      };
  };

  lanServiceConfig = {
      options = {
          dns = mkOption {
              type = types.bool;
              default = true;
              example = true;
              description = "Provide DNS to this lan";
          };

          advertise = mkOption {
              type = types.bool;
              example = true;
              default = false;
              description = "Advertise services to this lan";
          };

          dhcp = mkOption {
              type = types.submodule dhcpServiceConfig;
              example = {};
              default = {};
              description = "DHCP configuration for this lan";
          };
      };
  };

  firewallConfig = {
      options = {
          chains = mkOption {
              type = types.listOf types.str;
              default = [ "input_trusted" ];
              example = [ "input_trusted" ];
              description = "Chains to use for this LAN";
          };

          rules = mkOption {
              type = types.str;
              example = ''
                  tcp dport ssh accept
              '';
              default = "";
              description = "Rules for this LAN";
          };


      };
  };

  hostConfig = {
      options = {
          macAddress = mkOption {
              example = "00:00:00:00:00:00";
              type = types.nullOr types.str;
              default = null;
              description = "Mac address of the host. Used in dhcp address reservation";
          };

          ipAddress = mkOption {
              example = "192.168.1.1";
              type = types.nullOr types.str;
              default = null;
              description = "Address assigned to this host";
          };

          createDNS = mkOption {
              type = types.bool;
              example = false;
              default = true;
              description = "Whether to register dns record for this host";
          };

          globalConnectivity = mkOption {
              type = types.bool;
              example = false;
              default = true;
              description = "Whether to provide gateway to this host";
          };
          services = mkOption {
              type = types.attrs;
              example = {
                  "myservice" = 8080;
              };
              default = {};
              description = "Services hosted on this machine";
          };
      };
  };

  lanConfig = {
      options = {
          vlan = mkOption {
              example = 10;
              type = types.nullOr types.int;
              default = null;
              description = "Vlan number";
          };

          lanId = mkOption {
              type = types.int;
              example = 10;
              description = "Id of the LAN";
          };

          network = mkOption {
              type = types.nullOr types.str;
              example = "10.0.1.0";
              default = null;
              description = "Network segment to assign to this lan";
          };

          gateway = mkOption {
              type = types.nullOr types.str;
              example = "10.0.1.254";
              default = null;
              description = "Gateway address";
          };

          prefixLength = mkOption {
              type = types.int;
              example = 24;
              default = 24;
              description = "Prefixlength of lan";
          };

          netmask = mkOption {
              type = types.str;
              example = "255.255.255.0";
              default = "255.255.255.0";
              description = "Netmask of LAN (TODO: use prefixLength)";
          };

          services = mkOption {
              type = types.submodule lanServiceConfig;
              default = {};
              description = "Services configuration for this lan";
          };

          firewall = mkOption {
              type = types.submodule firewallConfig;
              default = {};
              description = "Firewall configuration for this LAN";
          };
      };
  };
in
{
  options = {
      settopbox.lans = mkOption {
          type = types.attrsOf (types.submodule lanConfig);
          default = {};
          description = ''
              Lan to provide for settopbox
          '';
      };

      settopbox.hosts = mkOption {
          type = types.attrsOf (types.submodule hostConfig);
          default = [];
          description = ''
              Host to configure on settopbox
          '';
      };

      settopbox.prefix = mkOption {
          type = types.str;
          default = "10.0";
          description = "Prefix to prepend to lanId for addresses";
      };

      settopbox.firewall.rules.input = mkOption {
          type = types.str;
          default = "";
          description = "Additionnal input rule to apply";
      };

      settopbox.firewall.rules.trusted = mkOption {
          type = types.str;
          default = "";
          description = "Additionnal rules to apply to trusted (LAN) interfaces";
      };

      settopbox.dns.extraConfig = mkOption {
          type = types.str;
          default = "";
          description = "Additionnal configuration to apply to unbound";
      };
    };

  imports =
    [
      (builtins.fetchGit https://github.com/netixx/nixos-home + "/default.nix")
      <nixpkgs/nixos/modules/services/networking/freeradius.nix>
      ./dhcp-server.nix
      ./dns.nix
      ./firewall.nix
      ./network.nix
      ./ntp.nix
      ./openvpn.nix
      ./radius.nix
      ./service-advertisment.nix
    ];

}
