# Pins elements of a stateful XML config that the application otherwise owns.
#
# Only the listed elements are forced; the rest of the file stays the
# dashboard's. Updates only elements whose value differs, so an
# already-correct file is left byte-for-byte alone. A list is one `<string>`
# per item, and its children are rewritten as a whole when they differ.
# xmlstarlet refuses malformed input, and that is deliberate: a broken file
# makes Jellyfin reset the whole thing, so better to fail the start loudly than
# to patch around it. A missing file (first start) is skipped; Jellyfin writes
# its defaults and the next start pins.
{ lib, pkgs }:
{
  name,
  file,
  # The document element, e.g. `EncodingOptions` or `PluginConfiguration`.
  root,
  values,
}:
pkgs.writeShellApplication {
  inherit name;
  runtimeInputs = [ pkgs.xmlstarlet ];
  text = ''
    f=${lib.escapeShellArg file}
    [ -e "$f" ] || exit 0
  ''
  + lib.concatStrings (
    lib.mapAttrsToList (
      name: value:
      if lib.isList value then
        ''
          xpath=/${root}/${name}
          if [ "$(xmlstarlet sel -t -v "count($xpath)" "$f")" = 0 ]; then
            xmlstarlet ed -L -s /${root} -t elem -n ${name} "$f"
          fi
          if [ "$(xmlstarlet sel -t -m "$xpath/string" -v . -n "$f" || true)" != ${lib.escapeShellArg (lib.concatStringsSep "\n" value)} ]; then
            xmlstarlet ed -L -d "$xpath/*" ${
              lib.concatMapStringsSep " " (v: ''-s "$xpath" -t elem -n string -v ${lib.escapeShellArg v}'') value
            } "$f"
          fi
        ''
      else
        ''
          xpath=/${root}/${name}
          if [ "$(xmlstarlet sel -t -v "count($xpath)" "$f")" = 0 ]; then
            xmlstarlet ed -L -s /${root} -t elem -n ${name} -v ${lib.escapeShellArg value} "$f"
          elif [ "$(xmlstarlet sel -t -v "$xpath" "$f")" != ${lib.escapeShellArg value} ]; then
            xmlstarlet ed -L -u "$xpath" -v ${lib.escapeShellArg value} "$f"
          fi
        ''
    ) values
  );
}
