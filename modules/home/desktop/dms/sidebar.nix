# Tabbed side panel with the Home Assistant dashboard
# (github:CaptainSpof/dms-sidebar). The widget and its own options come from
# that flake input; this is the fleet's tab set, so every host that turns
# `dafos.desktop.dms.sidebar` on gets the same panel.
#
# `url` defaults to HA's LAN address, which only answers at home. The dafoltop
# hostname resolves to its Tailscale address, which works anywhere, but only
# with a token whose HA user is not restricted to local access: such a user
# gets a 401 from a Tailscale (CGNAT) address.
{ namespace }:
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf optional;
  inherit (lib.${namespace}) mkBoolOpt mkOpt;

  cfg = config.${namespace}.desktop.dms.sidebar;
in
{
  options.${namespace}.desktop.dms.sidebar = {
    enable = mkBoolOpt false "Whether or not to enable the DMS sidebar (Home Assistant dashboard).";
    url =
      mkOpt lib.types.str "http://192.168.0.10:8123"
        "Home Assistant base URL. The LAN default only answers at home; see the header of this file before pointing it at Tailscale.";
    rer = mkBoolOpt false "Whether or not to add the RER departures tab. Needs a user key that opens the PRIM token in secrets/dafoltop/glance.yaml (the laptops' keys do not).";
  };

  config = mkIf cfg.enable {
    programs.dms-sidebar = {
      enable = true;
      inherit (cfg) url;
      # The HA "Maison" dashboard rendered natively (its bubble-card pop-ups are
      # the room pages), plus the generated per-area list.
      tabs = [
        {
          id = "maison";
          text = "Maison";
          icon = "home";
          type = "lovelace";
          dashboard = "dashboard-maison";
          # Section 0 is the greeting, date and weather row: noise in a sidebar.
          skipSections = [ 0 ];
          hideUnsupported = true;
        }
        {
          id = "pieces";
          text = "Pièces";
          icon = "grid_view";
          type = "home";
          sections = [ { byArea = true; } ];
        }
      ]
      ++ optional cfg.rer {
        id = "rer";
        text = "RER";
        icon = "train";
        type = "rer";
        title = "RER A → Paris";
        # Same stop and direction as the dashboard's widget
        # (modules/home/services/glance/default.nix).
        stopArea = 43171;
        excludeDestinations = [
          "Saint-Germain-en-Laye"
          "Le Vésinet-Le Pecq"
          "Le Vésinet-Centre"
          "Chatou-Croissy"
          "Rueil-Malmaison"
        ];
        keyFile = config.sops.secrets."prim/api-key".path;
        # Under the departures: both ends of the trip (Open-Meteo, no key).
        weather = [
          {
            name = "Nanterre";
            latitude = 48.8924;
            longitude = 2.2069;
          }
          {
            name = "Paris";
            latitude = 48.8566;
            longitude = 2.3522;
          }
        ];
      };
    };

    # The dashboard's PRIM token, for the RER tab. The 1000 requests a day are
    # shared with the dashboard.
    sops.secrets = mkIf cfg.rer {
      "prim/api-key".sopsFile = lib.snowfall.fs.get-file "secrets/dafoltop/glance.yaml";
    };
  };
}
