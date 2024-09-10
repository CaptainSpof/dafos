{
  config,
  lib,
  namespace,
  ...
}:

let
  inherit (lib) mkForce;
  inherit (lib.${namespace}) enabled disabled;
in
{
  imports = [ ./hardware.nix ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # disable sleep
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  dafos = {
    archetypes = {
      workstation = enabled;
    };

    apps = {
      qbittorrent = enabled;
    };

    display-managers = {
      autoLogin = {
        enable = true;
        user = config.${namespace}.user.name;
      };
    };

    security.gpg = mkForce disabled;

    services = {
      home-assistant = enabled;
      mealie = enabled;
      syncthing = enabled;
      printing = lib.mkForce disabled;
    };

    suites = {
      desktop = enabled;
      yahrr = enabled;
    };

    system = {
      kanata = enabled;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Can't touch this 🔨
}
