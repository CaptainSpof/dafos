# OpenDeck plugin for dafbox's Stream Deck: keys whose image follows a Home
# Assistant entity and that switch page or call a service (the HA plugin can
# do neither on a navigation key). Linked into ~/.config/opendeck/plugins by
# programs.opendeck.plugins (homes/x86_64-linux/daf@dafbox).
#
# The plugin directory (= plugin UUID) is "opendeck_alternative_elgato_implementation":
# OpenDeck 2.14 only lets that UUID and the starter pack send switchProfile.
# That UUID only means something when Settings → "disable Elgato" is on, which
# would hand the Deck itself to this plugin: keep that setting off.
{
  runCommand,
  python3,
  librsvg,
}:

let
  python = python3.withPackages (p: [ p.websockets ]);
in
# pluginId: what nix-opendeck's Home Manager module links into the plugin dir.
runCommand "opendeck-dafos-plugin"
  { passthru.pluginId = "opendeck_alternative_elgato_implementation"; }
  ''
    d=$out/opendeck_alternative_elgato_implementation
    mkdir -p $d/bin
    cp ${./plugin/manifest.json} $d/manifest.json
    cp ${./plugin/plugin.py} $d/plugin.py
    # Plain grey tile; only shows in OpenDeck's action list.
    echo '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 144 144"><rect width="144" height="144" rx="14" fill="#1c1611"/><text x="72" y="84" font-size="40" text-anchor="middle" fill="#fbefd9">HA</text></svg>' > icon.svg
    ${librsvg}/bin/rsvg-convert -w 144 -h 144 icon.svg -o $d/icon@2x.png
    cp $d/icon@2x.png $d/icon.png
    cat > $d/bin/dafos-plugin <<EOF
    #!/bin/sh
    exec ${python.interpreter} $d/plugin.py "\$@"
    EOF
    chmod +x $d/bin/dafos-plugin
  ''
