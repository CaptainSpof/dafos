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
        # The config schema this file is written for; bump it with the image,
        # after reading its changes. Frigate still logs "Config file is
        # read-only, unable to migrate" on every start: it checks that the
        # file is writable before comparing versions. Harmless.
        version = "0.18-0";

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
        # GPU (renderD129 is the NVIDIA one, on nouveau).
        detectors.ov = {
          type = "openvino";
          device = "GPU";
        };
        # YOLOv9-s rather than the SSDLite model shipped in the image, which
        # missed the cat in the night-time infrared picture. The model is not
        # in the image: export it with yolov9.Containerfile, then copy it to
        # ~/stacks/frigate/config/model_cache/ (the /config mount).
        model = {
          model_type = "yolo-generic";
          width = 320;
          height = 320;
          input_tensor = "nchw";
          input_dtype = "float";
          path = "/config/model_cache/yolov9-s-320.onnx";
          labelmap_path = "/labelmap/coco-80.txt";
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
            # Off by default since 0.18
            enabled = true;
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
        # Measured at ~420 MB per recorded hour (HD stream).
        record = {
          enabled = true;
          continuous.days = 0;
          motion.days = 1;
          alerts.retain.days = 7;
          detections.retain.days = 7;
        };
        snapshots = {
          enabled = true;
          retain.default = 7;
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
