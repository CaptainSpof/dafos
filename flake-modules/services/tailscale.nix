{
  flake.modules.nixos.tailscale =
    {
      lib,
      pkgs,
      config,
      ...
    }:

    let
      inherit (lib) types mkIf mkOption;
      inherit (lib.modules) mkBefore;

      cfg = config.dafos.services.tailscale;
    in
    {
      options.dafos.services.tailscale = {
        enable = lib.mkEnableOption "Tailscale";
        autoconnect = {
          enable = lib.mkEnableOption "automatic connection to Tailscale";
          key = mkOption {
            type = types.str;
            default = "";
            description = "The authentication key to use";
          };
        };
      };

      config = mkIf cfg.enable {
        assertions = [
          {
            assertion = cfg.autoconnect.enable -> cfg.autoconnect.key != "";
            message = "dafos.services.tailscale.autoconnect.key must be set";
          }
        ];

        boot.kernel.sysctl = {
          # Enable IP forwarding
          # required for Wireguard & Tailscale/Headscale subnet feature
          # See <https://tailscale.com/kb/1019/subnets/?tab=linux#step-1-install-the-tailscale-client>
          "net.ipv4.ip_forward" = true;
          "net.ipv6.conf.all.forwarding" = true;
        };

        environment.systemPackages = with pkgs; [
          tailscale
        ];

        networking = {
          firewall = {
            allowedUDPPorts = [ config.services.tailscale.port ];
            trustedInterfaces = [ config.services.tailscale.interfaceName ];
            # Strict reverse path filtering breaks Tailscale exit node use and some subnet routing setups.
            checkReversePath = "loose";
          };

          networkmanager.unmanaged = [ "tailscale0" ];
        };

        services.tailscale = {
          enable = true;
          permitCertUid = "root";
          useRoutingFeatures = "both";
        };

        systemd = {
          network.wait-online.ignoredInterfaces = [ "${config.services.tailscale.interfaceName}" ];

          services = {
            tailscaled.serviceConfig.Environment = mkBefore [ "TS_NO_LOGS_NO_SUPPORT=true" ];

            tailscale-autoconnect = mkIf cfg.autoconnect.enable {
              description = "Automatic connection to Tailscale";

              # Make sure tailscale is running before trying to connect to tailscale
              after = [
                "network-pre.target"
                "tailscale.service"
              ];
              wants = [
                "network-pre.target"
                "tailscale.service"
              ];
              wantedBy = [ "multi-user.target" ];

              serviceConfig.Type = "oneshot";

              script =
                let
                  inherit (lib) getExe;
                in
                # bash
                ''
                  # Wait for tailscaled to settle
                  sleep 2

                  # Check if we are already authenticated to tailscale
                  status="$(${getExe pkgs.tailscale} status -json | ${getExe pkgs.jq} -r .BackendState)"
                  if [ $status = "Running" ]; then # if so, then do nothing
                    exit 0
                  fi

                  # Otherwise authenticate with tailscale
                  ${getExe pkgs.tailscale} up -authkey "${cfg.autoconnect.key}"
                '';
            };
          };
        };
      };
    };
}
