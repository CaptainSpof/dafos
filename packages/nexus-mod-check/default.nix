{
  lib,
  writeShellApplication,
  python3,
  ...
}:

# Reports which downloaded Nexus Mods archives have a newer file online.
# Stdlib-only Python; see the docstring in nexus-mod-check.py for usage.
writeShellApplication {
  name = "nexus-mod-check";
  checkPhase = "";
  text = ''
    exec ${lib.getExe python3} -I ${./nexus-mod-check.py} "$@"
  '';
}
