{ config, pkgs, ... }:

{
  services.timesyncd = {
    enable = false;
  };

  # using chrony rtcfile https://chrony.tuxfamily.org/faq.html#_i_want_to_use_code_chronyd_code_s_rtc_support_must_i_disable_code_hwclock_code
  systemd.services.save-hwclock.enable = false;
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

          #rtcsync
          hwclockfile /etc/adjtime
          rtcfile /var/lib/chrony/rtc
          rtcautotrim 30
        '';
      };
  #   };
  # };

}
