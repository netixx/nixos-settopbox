{ config, pkgs, ... }:
let
  commonConfig = srv: ''
    # server mode
    mode server
    tls-server

    # system settings
    verb 2
    persist-tun
    persist-key
    persist-remote-ip

    script-security 3
    keepalive 10 60
    ping-timer-rem

    # ciphers
    cipher AES-256-CBC
    auth SHA256

    # double authentication
    script-security 3
    username-as-common-name
    auth-user-pass-verify "/etc/firewall/openvpn/ovpn_auth_verify" via-file
    #auth-user-pass-verify "/usr/local/sbin/ovpn_auth_verify user bG9jYWwgcmFkaXVz true server-udp 1196" via-env
    #tls-verify "/usr/local/sbin/ovpn_auth_verify tls 'netixx.dtdns.net' 1"

    # networking
    passtos
    comp-lzo adaptive
    topology subnet
    float
    push "dhcp-option DOMAIN ${config.home.domain}"
    push "dhcp-option DNS ${config.home.dns}"
    push "redirect-gateway def1"

    # auth crendentials
    ca /etc/firewall/openvpn/${srv}.ca
    cert /etc/firewall/openvpn/${srv}.cert
    key /etc/firewall/openvpn/${srv}.key
    crl-verify /etc/firewall/openvpn/${srv}.crl-verify
    tls-auth /etc/firewall/openvpn/${srv}.tls-auth 0
    dh /etc/firewall/openvpn/dh-parameters.1024
  '';
in
{
  services.openvpn.servers.tcp-1195 = {
    autoStart = true;
    config = ''
      ${commonConfig "server-tcp"}
      dev tun0
      lport 1195
      proto tcp-server
      server 10.2.1.0 255.255.255.0
    '';
  };

  services.openvpn.servers.udp-1196 = {
    autoStart = true;
    config = ''
      ${commonConfig "server-udp"}
      dev tun1
      lport 1196
      proto udp4
      server 10.2.2.0 255.255.255.0
    '';
  };

  # fix for network depency
  systemd.services.openvpn-tcp-1195.requires = ["network-online.target"];
  systemd.services.openvpn-tcp-1195.after = ["network-online.target"];
  systemd.services.openvpn-udp-1196.requires = ["network-online.target"];
  systemd.services.openvpn-udp-1196.after = ["network-online.target"];

}
