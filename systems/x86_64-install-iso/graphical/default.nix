{ lib, ... }:

with lib;
with lib.dafos;
{
  # `install-iso` adds wireless support that
  # is incompatible with networkmanager.
  networking.wireless.enable = mkForce false;

  dafos = {
    nix = enabled;

    apps = {
      firefox = enabled;
      vscode = enabled;
      gparted = enabled;
    };

    cli-apps = {
      neovim = enabled;
      zellij = enabled;
    };

    desktop = {
      gnome = {
        enable = true;
      };

      addons = {
        # I like to have a convenient place to share wallpapers from
        # even if they're not currently being used.
        wallpapers = enabled;
      };
    };

    tools = {
      k8s = enabled;
      git = enabled;
      http = enabled;
      misc = enabled;
      lang = {
        nix = enabled;
        node = enabled;
      };
    };

    hardware = {
      audio = enabled;
      networking = enabled;
    };

    services = {
      openssh = enabled;
      printing = enabled;
    };

    security = {
      doas = disabled;
      keyring = enabled;
    };

    system = {
      boot = enabled;
      fonts = enabled;
      locale = enabled;
      time = enabled;
      xkb = enabled;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?
}
