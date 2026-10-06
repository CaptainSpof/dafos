# claude-desktop 2.19675.1 ships a native module (claude-native-binding.node)
# that links libpipewire-0.3.so.0 directly. The upstream derivation
# (aaddrick/claude-desktop-debian) only lists pipewire under
# runtimeDependencies, which autoPatchelf adds to the main executable's
# runpath but does not use to satisfy other ELFs' DT_NEEDED, so the build
# fails. Adding it to buildInputs fixes that; claude-desktop-fhs picks it up
# through final.claude-desktop. Drop this once upstream adds it.
_:

final: prev: {
  claude-desktop = prev.claude-desktop.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [ (final.lib.getLib final.pipewire) ];
  });
}
