# DMS plugins, pinned to Nix so installs are reproducible. Each entry's `src` is
# symlinked into ~/.config/DankMaterialShell/plugins/<name> by the upstream
# dank-material-shell module.
#
# Only sources are declared here — plugin enable-state and per-plugin settings
# stay in DMS's runtime-owned plugin_settings.json (we don't set `settings`, so
# managePluginSettings stays off). Toggle/configure plugins in the DMS UI as
# usual; built-in toggles (dankClight, worldClock) have no source and are
# untouched.
#
# To update a plugin: bump its rev and refresh the hash with
#   nix-prefetch-url --unpack https://github.com/<owner>/<repo>/archive/<rev>.tar.gz
#   | tail -1 | xargs nix hash to-sri --type sha256
{ pkgs }:
let
  inherit (pkgs) fetchFromGitHub;

  # Monorepos: one fetch, several plugins live in subdirectories.
  avengemedia = fetchFromGitHub {
    owner = "AvengeMedia";
    repo = "dms-plugins";
    rev = "f4583449f12920e0a2f16808b00a860c27f0173d";
    hash = "sha256-QkQPqP7Wmo5DLRyKNSY5NuOau4LSaSfz3DYdHDLxluA=";
  };
  lucyfire = fetchFromGitHub {
    owner = "lucyfire";
    repo = "dms-plugins";
    rev = "c99ba77c848721fbb8b8c3307638ea10d5dccdd9";
    hash = "sha256-FLC/0rktMTYaVJ/gvuTw6UryyzgR/OEiNIZk+5O1XuI=";
  };
in
{
  # AvengeMedia/dms-plugins (subdirectories)
  dankActions.src = "${avengemedia}/DankActions";
  dankBatteryAlerts.src = "${avengemedia}/DankBatteryAlerts";
  dankDesktopWeather.src = "${avengemedia}/DankDesktopWeather";
  dankKDEConnect.src = "${avengemedia}/DankKDEConnect";
  dankPomodoroTimer.src = "${avengemedia}/DankPomodoroTimer";

  # lucyfire/dms-plugins (subdirectories)
  displaySettings.src = "${lucyfire}/displaySettings";
  wallpaperDiscovery.src = "${lucyfire}/wallpaperDiscovery";

  # Individual repos
  dankAudioVisualizer.src = fetchFromGitHub {
    owner = "odtgit";
    repo = "DankAudioVisualizer";
    rev = "25424e8d570e000f4ab086c9e5e1122180861a65";
    hash = "sha256-bdWWaIZJW2wuaDaNor4QlYOzFEWGPc69xVsABuUloLg=";
  };
  displayMirror.src = fetchFromGitHub {
    owner = "jfchenier";
    repo = "dms-display-mirror";
    rev = "92cd44c4fb67834bf71fdd78f83c29df5e0750b2";
    hash = "sha256-JX3pDZ1F5Uu/rOdA4KMhcwH8a6gxsTZjwgcZxNV/Ngc=";
  };
  emojiLauncher.src = fetchFromGitHub {
    owner = "devnullvoid";
    repo = "dms-emoji-launcher";
    rev = "1c0a7d337a52b48f9499060076703a35e8dd4f4f";
    hash = "sha256-NQ14YenDiNK2VqXQ3z7jAkatbSRtYJHhOhvv7AJlUD8=";
  };
  homeAssistantMonitor.src = fetchFromGitHub {
    owner = "xxyangyoulin";
    repo = "dms-plugin-hass";
    rev = "0d3cd45f6a094582db5f9209b3dc1f72c1cfb067";
    hash = "sha256-YScGw1b4OHX3s7f+JUCoCuK+BcWGDLgpYxgSI+N3EPI=";
  };
  nixMonitor.src = fetchFromGitHub {
    owner = "antonjah";
    repo = "nix-monitor";
    rev = "ef3db9d5a525ddf41355e8c456b40d56480a6626";
    hash = "sha256-lTbQ13lQ3ZPNkdnFmxAMGf1Gjx//80lDDlcJR8msREI=";
  };
  powerUsagePlugin.src = fetchFromGitHub {
    owner = "Daniel-42-z";
    repo = "dms-power-usage";
    rev = "cac8befec7f9b4e73bfde9f7552d10cb7c5b1828";
    hash = "sha256-8jUptgfuMHlvMPTntLq3ibLzzL6EOc2O47Yww4Rp3w4=";
  };
  tailscale.src = fetchFromGitHub {
    owner = "cglavin50";
    repo = "dms-tailscale";
    rev = "f035c3a0923e5872f912fc9bd4cc0c7f161fbe2a";
    hash = "sha256-cXuljANI8aO5cb7xwIs/ttucJD/y9s9PXuUw7LS+BGI=";
  };
  wallpaperShufflerPlugin.src = fetchFromGitHub {
    owner = "Daniel-42-z";
    repo = "dms-wallpaper-shuffler";
    rev = "cc459906990e562d3a332bd5c6869e8f5af1ee52";
    hash = "sha256-71kZLdVZmWMG+sgpbPHH8RFGmvLWve9NNTpZNJXrRd4=";
  };
  webSearch.src = fetchFromGitHub {
    owner = "devnullvoid";
    repo = "dms-web-search";
    rev = "52f9ec482dc86d9c5ff0110a5d57401112191a38";
    hash = "sha256-c6mVBTlkJdfvMuMvPjXGeOEWBtb0mdmIcPNzgmMxGwE=";
  };
}
