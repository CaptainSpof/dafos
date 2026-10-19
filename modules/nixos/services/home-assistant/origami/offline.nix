# Which of the Maison dashboard's entities are unavailable, to spot a dropped
# device or a dead integration (Netatmo, a Zigbee ceiling) at a glance.
#
# Only the entities the dashboard uses are watched, taken from ./rooms.nix:
# HA as a whole always has a few hundred unavailable entities (unused cloud
# switches, retired devices, plug options), so a global count means nothing.
#
# sensor.maison_offline: how many are unavailable; attributes `entities`,
# `labels` ("Escaliers · Plafonnier") and `rooms` (room ids, for the cards).
{ lib }:

let
  inherit (lib) concatMap concatMapStringsSep optional;

  inherit (import ./rooms.nix) rooms;

  roomEntities =
    r:
    optional (r.light != null) {
      entity = r.light;
      label = "Lumières";
    }
    ++ map (l: {
      inherit (l) entity;
      label = l.name;
    }) r.lights
    ++ optional (r.climate != null) {
      entity = r.climate;
      label = "Thermostat";
    }
    ++ optional (r.temperature != null) {
      entity = r.temperature;
      label = "Température";
    }
    ++ optional (r.humidity != null) {
      entity = r.humidity;
      label = "Humidité";
    }
    ++ optional (r.opening != null) {
      entity = r.opening;
      label = "Porte";
    }
    ++ optional (r.presence != null) {
      entity = r.presence;
      label = "Présence";
    }
    ++ optional (r.device != null) {
      inherit (r.device) entity;
      label = "Appareil";
    }
    ++ optional (r.media != null) {
      entity = r.media;
      label = "Média";
    }
    ++ map (e: {
      entity = e;
      label = "Appareil";
    }) r.extras;

  # First mention wins: an entity shared by two rooms belongs to the first.
  dedupe =
    list:
    let
      go =
        seen: xs:
        if xs == [ ] then
          [ ]
        else
          let
            x = builtins.head xs;
          in
          if builtins.elem x.entity seen then
            go seen (builtins.tail xs)
          else
            [ x ] ++ go (seen ++ [ x.entity ]) (builtins.tail xs);
    in
    go [ ] list;

  watched = dedupe (
    concatMap (
      r:
      map (e: {
        inherit (e) entity;
        room = r.id;
        label = "${r.name} · ${e.label}";
      }) (roomEntities r)
    ) rooms
  );

  quote = builtins.replaceStrings [ "'" ] [ "\\'" ];
  jinjaList =
    f: "[" + concatMapStringsSep ", " (w: "('${w.entity}', '${quote (f w)}')") watched + "]";
in
{
  inherit watched;

  sensors = [
    {
      name = "Maison · Hors ligne";
      unique_id = "dafos.sensor.maison_offline";
      default_entity_id = "sensor.maison_offline";
      icon = "mdi:lan-disconnect";
      state = ''
        {{ ${jinjaList (w: w.room)} | selectattr(0, 'is_state', 'unavailable') | list | count }}
      '';
      attributes = {
        entities = "{{ ${jinjaList (w: w.room)} | selectattr(0, 'is_state', 'unavailable') | map(attribute=0) | list }}";
        labels = "{{ ${jinjaList (w: w.label)} | selectattr(0, 'is_state', 'unavailable') | map(attribute=1) | list }}";
        rooms = "{{ ${jinjaList (w: w.room)} | selectattr(0, 'is_state', 'unavailable') | map(attribute=1) | unique | list }}";
      };
    }
  ];
}
