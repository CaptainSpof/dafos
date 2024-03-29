{ lib, pkgs, ... }:

let
  tailscale-key = builtins.getEnv "TAILSCALE_AUTH_KEY";
in
with lib;
with lib.dafos;
{
  virtualisation.digitalOcean = {
    rebuildFromUserData = false;
  };

  boot.loader.grub = enabled;

  environment.systemPackages = with pkgs; [
    neovim
  ];

  dafos = {
    nix = enabled;

    cli-apps = {
      zellij = enabled;
    };

    tools = {
      git = enabled;
    };

    security = {
      doas = disabled;
    };

    services = {
      openssh = enabled;
      tailscale = {
        enable = true;
        autoconnect = {
          enable = tailscale-key != "";
          key = tailscale-key;
        };
      };
    };

    system = {
      fonts = enabled;
      locale = enabled;
      time = enabled;
      xkb = enabled;
    };
  };

  system.stateVersion = "21.11";
}
