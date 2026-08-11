# Ryubing 1.3.3 only registers acc:u0 TrySelectUserWithoutInteraction at command
# 51. Firmware 19.0.0 moved it to command 52, so any game built against a 19.x+
# SDK throws ServiceNotImplementedException and SIGABRTs the emulator a few
# seconds into boot (seen with EA Sports FC 26 on dafbox). Upstream master still
# has not added 52; drop this once it does.
_:

_final: prev:

{
  ryubing = prev.ryubing.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./account-cmd52.patch ];
  });
}
