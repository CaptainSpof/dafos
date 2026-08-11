{
  config,
  lib,
  namespace,
  ...
}:

let
  cfg = config.${namespace}.services.avahi;

  inherit (lib) mkEnableOption mkIf;
in
{
  options.${namespace}.services.avahi = {
    enable = mkEnableOption "Whether or not to enable and setup Avahi.";
  };

  config = mkIf cfg.enable {
    services.avahi = {
      enable = true;

      extraServiceFiles = {
        smb = # xml
          ''
            <?xml version="1.0" standalone='no'?><!--*-nxml-*-->
            <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
            <service-group>
              <name replace-wildcards="yes">%h</name>
              <service>
                <type>_smb._tcp</type>
                <port>445</port>
              </service>
            </service-group>
          '';
      };

      # resolve .local domains
      nssmdns4 = true;
      # nssmdns6 = true;

      # mDNS over IPv4 only: rotating IPv6 privacy addresses get cached by
      # other devices on the LAN, and their stale AAAA answers make avahi
      # think its own hostname is taken — endless "Host name conflict,
      # retrying with <host>-N" renames that also withdraw every published
      # service (e.g. Sunshine's _nvstream) faster than clients can see it.
      ipv6 = false;

      # pass avahi port(s) to the firewall
      openFirewall = true;

      publish = {
        enable = true;
        addresses = true;
        domain = true;
        hinfo = true;
        userServices = true;
        workstation = true;
      };
    };
  };
}
