{ config, pkgs, lib, ... }:
with pkgs.lib;
let
  cfg = config.settopbox;
  domain = config.home.domain;
  dnsAddress = config.home.dns;
  dnsExtraConfig = cfg.dns.extraConfig;
  dnsRecords = mapAttrsToList (name: hostConfig:
  let
    hostFQDN = "${name}.${domain}";
    serviceRecords = mapAttrsToList (name: port:
      let
        serviceFQDN = "${name}.${domain}";
      in
      ''
        # local-data-ptr: "${hostConfig.ipAddress} ${serviceFQDN}"
        local-data: "${serviceFQDN} A ${hostConfig.ipAddress}"
        # local-data: "_http._tcp.${serviceFQDN} 3600 SRV 0 100 ${toString port} ${serviceFQDN}"
        local-data: '_http._tcp.${serviceFQDN} TXT "http_URL=http://${serviceFQDN}:${toString port}"'
      '') hostConfig.services;
  in
    ''
      local-data-ptr: "${hostConfig.ipAddress} ${hostFQDN}"
      local-data: "${hostFQDN} A ${hostConfig.ipAddress}"

      ${concatStringsSep "\n" serviceRecords}
    '') (filterAttrs (n: v: v.createDNS && v.ipAddress != null) cfg.hosts);
in
{
  containers.dns = {
    autoStart = true;
    config = {config, pkgs, lib, ...}: {
      services.unbound = {
        enable = true;
        allowedAccess = ["10.0.0.0/8"];
        interfaces = ["0.0.0.0"];
        extraConfig = ''
          # auto detect reply source address from query dest address
          interface-automatic: yes
          # ip-freebind: yes

          # Outgoing interfaces to be used
          #outgoing-interface: 10.0.0.253

          # defaults
          port: 53
          verbosity: 2
          val-log-level: 2

          # do-ip4: yes
          # do-ip6: no
          # prefer-ipv6: yes
          do-udp: yes
          do-tcp: yes

          # caching
          infra-host-ttl: 900
          infra-cache-numhosts: 10000

          # fetch entries before they expire
          prefetch: yes
          prefetch-key: yes

          edns-buffer-size: 4096
          cache-max-ttl: 86400
          cache-min-ttl: 0

          # docs: https://www.unbound.net/documentation/howto_optimise.html
          # performance optimisation
          # = to number of cores
          num-threads: 4
          so-reuseport: yes
          outgoing-num-tcp: 10
          incoming-num-tcp: 10

          # power of 2 clothest to num-threads
          msg-cache-slabs: 4
          rrset-cache-slabs: 4
          infra-cache-slabs: 4
          key-cache-slabs: 4
          rrset-cache-size: 20m
          msg-cache-size: 10m

          outgoing-range: 4096
          # roughly half of outgoing-range
          num-queries-per-thread: 2048
          # miliseconds should be roughly rtt to root servers
          jostle-timeout: 200

          # 4m or 8m if busy
          #so-rcvbuf: 4m
          #so-sndbuf: 4m

          #use-syslog: yes

          # security/privacy
          hide-identity: yes
          hide-version: yes
          harden-glue: yes
          qname-minimisation: yes
          qname-minimisation-strict: no

          # ip-ratelimit: 1000
          # ip-ratelimit-size: 4m
          # ip-ratelimit-slabs: 4
          # ip-ratelimit-factor: 10

          # DNSSEC validation
          module-config: "validator iterator"
          harden-dnssec-stripped: yes
          hide-trustanchor: yes
          # harden-below-nxdomain: no
          # harden-algo-downgrade: no


          # defensive action when threshold is reached 0=off
          unwanted-reply-threshold: 0

          # draft dns-0x20, experimental
          use-caps-for-id: no

          # DNS Rebinding
          # For DNS Rebinding prevention
          private-address: 10.0.0.0/8
          private-address: 172.16.0.0/12
          private-address: 169.254.0.0/16
          private-address: 192.168.0.0/16
          private-address: fd00::/8
          private-address: fe80::/10
          # Set private domains in case authoritative name server returns a Private IP address

          # Statistics output on unbound-control port
          # Unbound Statistics
          # disabled
          statistics-interval: 0
          extended-statistics: no
          statistics-cumulative: no

          ###
          # Remote Control Config
          ###
          # include: /etc/firewall/unbound/remotecontrol.conf
          #remote-control:
          #	control-enable: yes
          #	control-interface: 127.0.0.1
          #	control-port: 953
          #	server-key-file: "/var/unbound/unbound_server.key"
          #	server-cert-file: "/var/unbound/unbound_server.pem"
          #	control-key-file: "/var/unbound/unbound_control.key"
          #	control-cert-file: "/var/unbound/unbound_control.pem"

          # domain-insecure:

          private-domain: ${domain}
          # Static host entries
          # include: /etc/firewall/unbound/host_entries.conf
          local-zone: "${domain}" transparent
          local-data-ptr: "127.0.0.1 localhost"
          local-data: "localhost A 127.0.0.1"
          local-data: "localhost.${domain} A 127.0.0.1"

          # DNS-SD setup
          local-data: "dns.${domain} IN NS ${domain}"
          local-data: "dns.${domain} A ${dnsAddress}"
          local-data: "b._dns-sd._udp.${domain} IN PTR ${dnsAddress}"
          local-data: "lb._dns-sd._udp.${domain} IN PTR ${dnsAddress}"
          local-data: "db._dns-sd._udp.${domain} IN PTR ${dnsAddress}"

          ${concatStringsSep "\n\n" dnsRecords}

          ${dnsExtraConfig}

          # dhcp lease entries
          # include: /etc/firewall/unbound/dhcpleases_entries.conf

          # Domain overrides
          # include: /etc/firewall/unbound/domainoverrides.conf
        '';
      };

    };
  };

  # fallback DNS (if unbound fails)
  # services.resolved = {
  #   enable = true;
  #   llmnr = "false";
  # };

  networking.nameservers = [
    "127.0.0.1"
    # "127.0.0.53"
  ];

  # systemd.services.unbound.wants = ["network-online.target"];
  # systemd.services.unbound.after = ["network-online.target"];
}
