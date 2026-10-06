{
  flake.modules.nixos.time =
    { config, lib, ... }:
    {
      options.dafos.system.time.enable = lib.mkEnableOption "timezone information";

      config = lib.mkIf config.dafos.system.time.enable { time.timeZone = "Europe/Paris"; };
    };
}
