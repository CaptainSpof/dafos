{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkIf types getExe;
  inherit (lib.${namespace}) mkBoolOpt enabled;

  cfg = config.${namespace}.services.tailscale;
in
{
  options.${namespace}.services.tailscale = {
    enable = mkBoolOpt false "Whether or not to configure tailscale.";
    autoconnect = {
      enable = mkBoolOpt false "Whether or not to enable automatic connection to tailscale.";
      key = types.mkOp types.str "" "The authentication key to use.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.autoconnect.enable -> cfg.autoconnect.key != "";
        message = "dafos.services.tailscale.autoconnect.key must be set";
      }
    ];

    environment.systemPackages = with pkgs; [ tailscale ];

    services.tailscale = enabled;

    networking = {
      firewall = {
        trustedInterfaces = [ config.services.tailscale.interfaceName ];

        allowedUDPPorts = [ config.services.tailscale.port ];

        # Strict reverse path filtering breaks Tailscale exit node use and some subnet routing setups.
        checkReversePath = "loose";
      };

      networkmanager.unmanaged = [ "tailscale0" ];
    };

    systemd.services.tailscale-autoconnect = mkIf cfg.autoconnect.enable {
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

      # Set this service as a oneshot job
      serviceConfig.Type = "oneshot";

      # Have the job run this shell script
      script = with pkgs; ''
        # Wait for tailscaled to settle
        sleep 2

        # Check if we are already authenticated to tailscale
        status="$(${getExe tailscale} status -json | ${getExe jq} -r .BackendState)"
        if [ $status = "Running" ]; then # if so, then do nothing
          exit 0
        fi

        # Otherwise authenticate with tailscale
        ${getExe tailscale} up -authkey "${cfg.autoconnect.key}"
      '';

    };
  };
}
