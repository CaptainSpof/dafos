{
  flake.modules.nixos.locale =
    { config, lib, ... }:
    {
      options.dafos.system.locale.enable = lib.mkEnableOption "locale settings";

      config = lib.mkIf config.dafos.system.locale.enable {
        i18n.defaultLocale = "en_US.UTF-8";

        i18n.extraLocaleSettings = {
          LC_MONETARY = "fr_FR.UTF-8";
          LC_MEASUREMENT = "fr_FR.UTF-8";
          LC_TIME = "fr_FR.UTF-8";
          LANG = "en_US.UTF-8";
        };
      };
    };
}
