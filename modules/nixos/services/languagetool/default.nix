{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:

let
  inherit (lib.${namespace}) mkOpt mkBoolOpt;
  inherit (lib)
    mkEnableOption
    mkIf
    mkMerge
    types
    ;

  cfg = config.${namespace}.services.languagetool;

  # Upstream's n-gram archives (https://languagetool.org/download/ngram-data/).
  # Each zip unpacks to a `<lang>/` directory.
  ngramArchives = {
    de = "ngrams-de-20150819.zip";
    en = "ngrams-en-20150817.zip";
    es = "ngrams-es-20150915.zip";
    fr = "ngrams-fr-20150913.zip";
    nl = "ngrams-nl-20181229.zip";
  };

  fetchNgrams = pkgs.writeShellApplication {
    name = "languagetool-fetch-ngrams";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      unzip
      systemd
    ];
    text = ''
      dir=${lib.escapeShellArg cfg.ngrams.directory}
      fetched=0
      ${lib.concatMapStrings (lang: ''
        if [ ! -d "$dir/${lang}" ]; then
          tmp="$dir/.tmp-${lang}"
          rm -rf "$tmp"
          mkdir -p "$tmp"
          echo "Downloading ${ngramArchives.${lang}}"
          curl -fL --retry 3 -o "$tmp/ngrams.zip" \
            "https://languagetool.org/download/ngram-data/${ngramArchives.${lang}}"
          unzip -q "$tmp/ngrams.zip" -d "$tmp"
          chmod -R a+rX "$tmp/${lang}"
          mv "$tmp/${lang}" "$dir/${lang}"
          rm -rf "$tmp"
          fetched=1
        fi
      '') cfg.ngrams.languages}
      # The server opens the indexes at startup; pick up new ones.
      if [ "$fetched" = 1 ]; then
        systemctl try-restart languagetool.service
      fi
    '';
  };

  # Upstream's server imports its vendored bottle, which needs the `cgi` and
  # `imp` modules Python 3.12+ dropped; the bottle nixpkgs already propagates
  # works.
  grammalecte = pkgs.python3Packages.grammalecte.overridePythonAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace grammalecte-server.py \
        --replace-fail "from grammalecte.bottle import" "from bottle import"
    '';
  });
in
{
  options.${namespace}.services.languagetool = {
    enable = mkEnableOption "the LanguageTool spelling and grammar server (backs the DMS proofreader plugin)";
    port = mkOpt types.port 8081 "Port the LanguageTool HTTP API listens on";
    heapSize =
      mkOpt types.str "1g"
        "JVM max heap (-Xmx). 512m hit OutOfMemoryError once a handful of languages had been checked: each one loads its rules and dictionary on first use.";
    openFirewallForPodman = mkBoolOpt false "Listen on every interface and open `port` on `podman+` only, so traefik can proxy it to other hosts. Off means localhost only. See README.md.";
    ngrams = {
      languages =
        mkOpt (types.listOf (types.enum (lib.attrNames ngramArchives))) [ ]
          "Languages to download n-gram data for (confusion rules such as a/à, their/there). Removing one does not delete its data. See README.md.";
      directory =
        mkOpt types.str "/var/lib/languagetool-ngrams"
          "Where the unpacked n-gram data lives (fr ~4 GB, en ~14 GB).";
    };
    grammalecte = {
      enable = mkBoolOpt false "Run a local Grammalecte server and merge its French rules (e.g. the infinitive after « avoir l'air de ») into LanguageTool's results.";
      port = mkOpt types.port 8082 "Port the Grammalecte server listens on (localhost only).";
    };
  };

  config = mkIf cfg.enable {
    services.languagetool = {
      enable = true;
      inherit (cfg) port;
      # Upstream has no bind-address option: `public` is all interfaces or
      # nothing. The NixOS firewall keeps it off the LAN; only podman+ (where
      # traefik lives) is opened below.
      public = cfg.openFirewallForPodman;
      jvmOptions = [ "-Xmx${cfg.heapSize}" ];
      settings = mkMerge [
        (mkIf (cfg.ngrams.languages != [ ]) { languageModel = cfg.ngrams.directory; })
        # LanguageTool's FR_GRAMMALECTE rule posts each French sentence here
        # and already drops Grammalecte's typography-only rules.
        (mkIf cfg.grammalecte.enable {
          grammalecteServer = "http://127.0.0.1:${toString cfg.grammalecte.port}/gc_text/fr";
        })
      ];
    };

    networking.firewall.interfaces."podman+".allowedTCPPorts = mkIf cfg.openFirewallForPodman [
      cfg.port
    ];

    systemd = mkMerge [
      (mkIf (cfg.ngrams.languages != [ ]) {
        tmpfiles.rules = [ "d ${cfg.ngrams.directory} 0755 root root -" ];

        # Upstream sets ProtectHome=yes; tmpfs mode still lets a bind mount
        # through, so the data can live on /home where the space is.
        services.languagetool.serviceConfig = {
          ProtectHome = lib.mkForce "tmpfs";
          BindReadOnlyPaths = [ cfg.ngrams.directory ];
        };

        # Not ordered before the server: the first download takes a while, and
        # the server runs fine without the data until it is restarted.
        services.languagetool-ngrams = {
          description = "Download LanguageTool n-gram data";
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = lib.getExe fetchNgrams;
          };
        };
      })

      (mkIf cfg.grammalecte.enable {
        services.grammalecte = {
          description = "Grammalecte French grammar server";
          wantedBy = [ "multi-user.target" ];
          before = [ "languagetool.service" ];
          serviceConfig = {
            # It defaults to one worker process per CPU; LanguageTool sends
            # one sentence at a time.
            ExecStart = "${grammalecte}/bin/grammalecte-server.py --host 127.0.0.1 --port ${toString cfg.grammalecte.port} --multiprocessor 2";
            DynamicUser = true;
            ProtectHome = true;
            Restart = "on-failure";
          };
        };
      })
    ];
  };
}
