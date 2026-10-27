{
  lib,
  config,
  namespace,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf types;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.frigate;

  secret = key: config.sops.secrets."frigate/${key}".path;

  # The Tapo camera account (not the TP-Link cloud one), shared with HA's
  # Tapo integration. Every failed login counts towards a ~30 min lockout of
  # all clients, HA included, so the password must be right before the first
  # start.
  camera = {
    host = "192.168.0.44";
    user = "dafdaf";
  };
  rtsp = stream: "rtsp://${camera.user}:{FRIGATE_RTSP_PASSWORD}@${camera.host}:554/${stream}";
in
{
  options.${namespace}.services.frigate = {
    enable = mkEnableOption "Whether or not to configure Frigate.";
    subDomain = mkOpt types.str "frigate" "The subdomain Frigate is served on.";
    mediaPath =
      mkOpt types.str "/mnt/data/frigate"
        "Where the recordings, clips and snapshots go. Create it by hand.";
  };

  config = mkIf cfg.enable {
    sops.secrets = lib.genAttrs [ "frigate/mqtt-password" "frigate/rtsp-password" ] (_: {
      sopsFile = lib.snowfall.fs.get-file "secrets/dafoltop/frigate.yaml";
    });

    nps.stacks.frigate = {
      enable = true;
      inherit (cfg) mediaPath;

      # Frigate substitutes {FRIGATE_*} variables in its config.
      extraEnv = {
        FRIGATE_RTSP_PASSWORD.fromFile = secret "rtsp-password";
        FRIGATE_MQTT_PASSWORD.fromFile = secret "mqtt-password";
      };

      settings = {
        # The password-protected listener of the host's mosquitto (see the
        # home-assistant NixOS module): its loopback one is out of reach.
        mqtt = {
          enabled = true;
          host = "host.containers.internal";
          port = 1884;
          user = "frigate";
          password = "{FRIGATE_MQTT_PASSWORD}";
        };

        # Object detection on the i7-8550U's UHD 620; renderD128 is the Intel
        # GPU (renderD129 is the NVIDIA one, on nouveau). The model ships in
        # the image.
        detectors.ov = {
          type = "openvino";
          device = "GPU";
        };
        model = {
          width = 300;
          height = 300;
          input_tensor = "nhwc";
          input_pixel_format = "bgr";
          path = "/openvino-model/ssdlite_mobilenet_v2.xml";
          labelmap_path = "/openvino-model/coco_91cl_bkgr.txt";
        };

        ffmpeg.hwaccel_args = "preset-vaapi";

        # Frigate's own go2rtc opens the camera once per stream and restreams
        # it to the detector, the recorder and the UI. HA keeps its own
        # connection through the host's go2rtc.
        go2rtc.streams = {
          dafindoorcam = [ (rtsp "stream1") ];
          dafindoorcam_sub = [ (rtsp "stream2") ];
        };

        cameras.dafindoorcam = {
          ffmpeg.inputs = [
            {
              path = "rtsp://127.0.0.1:8554/dafindoorcam";
              input_args = "preset-rtsp-restream";
              roles = [ "record" ];
            }
            {
              path = "rtsp://127.0.0.1:8554/dafindoorcam_sub";
              input_args = "preset-rtsp-restream";
              roles = [ "detect" ];
            }
          ];
          detect = {
            width = 640;
            height = 360;
            fps = 5;
          };
          live.streams."Principal" = "dafindoorcam";
        };

        objects.track = [
          "person"
          "cat"
        ];

        # In privacy mode the camera sends a still "Privacy Mode is on"
        # frame: no motion, so nothing is kept but continuous footage.
        record = {
          enabled = true;
          continuous.days = 0;
          motion.days = 3;
          alerts.retain.days = 14;
          detections.retain.days = 14;
        };
        snapshots = {
          enabled = true;
          retain.default = 14;
        };
      };

      containers.frigate = {
        traefik = {
          inherit (cfg) subDomain;
          middleware.authelia.enable = true;
        };
        # Port 5000 has no authentication of its own: Authelia guards the
        # Traefik route, and Home Assistant's Frigate integration (native, on
        # this host) uses the loopback port.
        ports = [ "127.0.0.1:5000:5000" ];
        # Only the Intel GPU: given all of /dev/dri, preset-vaapi picked
        # renderD129 (nouveau), which cannot decode H.264 High, and detect
        # crash-looped.
        devices = lib.mkForce [ "/dev/dri/renderD128:/dev/dri/renderD128" ];
        environment.TZ = "Europe/Paris";
      };
    };
  };
}
