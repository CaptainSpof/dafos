{ lib, namespace, ... }:

let
  inherit (lib.${namespace}) enabled disabled mkForce;
in
{
  # `install-iso` adds wireless support that
  # is incompatible with networkmanager.
  networking.wireless.enable = mkForce false;

  dafos = {
    nix = enabled;

    tools = {
      git = enabled;
      misc = enabled;
      lang = {
        node = enabled;
        nix = enabled;
      };
    };

    services = {
      openssh = enabled;
    };

    security = {
      doas = disabled;
    };

    system = {
      boot = enabled;
      fonts = enabled;
      locale = enabled;
      networking = enabled;
      time = enabled;
      xkb = enabled;
    };
  };
}
