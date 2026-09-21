# Jellyfin plugins, pinned here instead of installed through the web UI.
#
# The UI installer unpacks into `/config/data/plugins`, which is host state: the
# version actually running is whatever was last clicked, a rebuild can neither
# see it nor reproduce it, and nothing ever removes the superseded copy (this
# box was running two builds of Jellyfin Enhanced at once).
#
# These are *copied* into that directory by an activation script rather than
# bind-mounted from the store, because a plugin directory has to be writable.
# Jellyfin persists plugin state by rewriting the plugin's own `meta.json`
# (`PluginManager.ChangePluginState` -> `SaveManifest`) the first time it loads
# one, and that happens inside `InitializeServices`: on a read-only directory it
# throws `UnauthorizedAccessException` and the **whole server fails to start**,
# not just the plugin. Mounting the store read-only took Jellyfin down on
# 2026-09-16. A `:O` overlay mount does not help either -- new files are
# writable but copy-up preserves the store's 444 mode, so rewriting an existing
# `meta.json` still fails.
#
# So the store holds the pinned content and activation materialises a writable
# copy, which is exactly what the UI installer would have produced. `supersedes`
# lists the directories a plugin replaces, so old versions actually go away
# instead of accumulating a second directory with the same plugin GUID.
#
# Plugin *configuration* is deliberately not managed here: it lives in the
# sibling `plugins/configurations/`, so everything tuned through the dashboard
# survives a version bump. The exceptions are SSO-Auth and LDAP-Auth, whose
# configs are generated because they carry secrets.
{ lib, pkgs }:
let
  # Jellyfin needs a `meta.json` to name and version a plugin. Publishers that
  # build with JPRM ship one; the two below hand out a bare DLL, and Jellyfin
  # would try to write the missing manifest into the plugin directory -- which
  # is a read-only store path. So write it ourselves. `guid` is the plugin's
  # identity and must match what the publisher uses, or Jellyfin treats it as a
  # different plugin and orphans its existing configuration.
  mkMeta =
    args:
    builtins.toJSON (
      {
        category = "General";
        status = "Active";
        autoUpdate = false;
        assemblies = [ ];
      }
      // args
    );

  # `stripRoot = false`: every one of these archives is flat.
  #
  # Take the hash from the failing build, not from `nix store prefetch-file
  # --unpack` -- for the single-file archives (Intro Skipper, Jellyfin Enhanced)
  # the two disagree, and prefetch wins you one wasted build every bump.
  fetchPlugin =
    {
      pname,
      version,
      dirName,
      url,
      hash,
      meta ? null,
      supersedes ? [ ],
    }:
    let
      src = pkgs.fetchzip {
        inherit url hash;
        name = "jellyfin-plugin-${pname}-${version}";
        stripRoot = false;
      };
    in
    {
      inherit dirName supersedes;
      src =
        if meta == null then
          src
        else
          pkgs.runCommand "jellyfin-plugin-${pname}-${version}-meta" { } ''
            mkdir -p "$out"
            cp -r ${src}/. "$out/"
            cat > "$out/meta.json" <<'EOF'
            ${mkMeta (meta // { inherit version; })}
            EOF
          '';
    };
in
rec {
  # Official, from the stable catalogue at repo.jellyfin.org.
  #
  # LDAP-Auth v23 is the last build for the 10.11 line (targetAbi 10.11.9.0) and
  # is kept so the plugin can be re-pinned if this box ever has to go back to a
  # restored 10.11 database; v24 is the first for 12 (targetAbi 12.0.0.0).
  ldap-auth-23 = fetchPlugin {
    pname = "ldap-auth";
    version = "23.0.0.0";
    dirName = "LDAP-Auth_23.0.0.0";
    supersedes = [ "LDAP-Auth_*" ];
    url = "https://repo.jellyfin.org/files/plugin/ldap-authentication/ldap-authentication_23.0.0.0.zip";
    hash = "sha256-yuOAJTj+QKj6bxlJ+irDE2BjxH1ZbsgAri7fauDMOBM=";
  };

  ldap-auth = fetchPlugin {
    pname = "ldap-auth";
    version = "24.0.0.0";
    dirName = "LDAP-Auth_24.0.0.0";
    supersedes = [ "LDAP-Auth_*" ];
    url = "https://repo.jellyfin.org/files/plugin/ldap-authentication/ldap-authentication_24.0.0.0.zip";
    hash = "sha256-yiyoLahv+tzNWB4JVPoC4fxl+gj8IoYVXv0bi2FGlmM=";
  };

  open-subtitles = fetchPlugin {
    pname = "open-subtitles";
    version = "25.0.0.0";
    dirName = "OpenSubtitles_25.0.0.0";
    supersedes = [
      "OpenSubtitles_*"
      "Open Subtitles_*"
    ];
    url = "https://repo.jellyfin.org/files/plugin/open-subtitles/open-subtitles_25.0.0.0.zip";
    hash = "sha256-If7p65jk2tbRJsKBSKJFrnW8/++MaDcRK0azfc8gco0=";
  };

  tvdb = fetchPlugin {
    pname = "tvdb";
    version = "24.0.0.0";
    dirName = "TheTVDB_24.0.0.0";
    supersedes = [ "TheTVDB_*" ];
    url = "https://repo.jellyfin.org/files/plugin/thetvdb/thetvdb_24.0.0.0.zip";
    hash = "sha256-nSidMGw+gkILzPVBvgiIYraC+9QuRj70epr5jKstybY=";
  };

  # 9p4/jellyfin-plugin-sso is archived ("tired of working on this after all the
  # years") at ABI 10.11 / net9, and Jellyfin 12 moved the server to .NET 10.
  # MaxRink's fork is the consolidation point for the fork ecosystem -- it
  # absorbs Buco7854's and kiliankoe's work with credit, publishes its own
  # manifest branch, and carries an end-to-end test that drives a real browser
  # login against Jellyfin 12.
  #
  # Every element nps' `jellyfin_sso_config.nix` writes still exists in 6.x, so
  # the generated `SSO-Auth.xml`, the Authelia client and the branding.xml
  # button all carry over untouched.
  sso-auth = fetchPlugin {
    pname = "sso-auth";
    version = "6.1.0.0";
    dirName = "SSO-Auth_6.1.0.0";
    supersedes = [
      "SSO-Auth_*"
      "SSO Authentication_*"
    ];
    url = "https://github.com/MaxRink/jellyfin-plugin-sso/releases/download/v6.1.0.0/sso-auth_6.1.0.0.zip";
    hash = "sha256-ZuQeEeCjzwLT5lqjhNbMCgcHeDV7UIrPmEP2W0BwLlw=";
  };

  # The 12.0 line is now this project's default branch. 12.0.4.0 explicitly
  # preserves the completed 10.11 analysis across the upgrade, so the episodes
  # already fingerprinted here do not have to be scanned again.
  #
  # Pinned to the release zip rather than the project's plugin repository:
  # `intro-skipper.org` no longer serves a manifest, it redirects to the GitHub
  # org page.
  intro-skipper = fetchPlugin {
    pname = "intro-skipper";
    version = "12.0.4.0";
    dirName = "IntroSkipper_12.0.4.0";
    supersedes = [
      "IntroSkipper_*"
      "Intro Skipper_*"
    ];
    url = "https://github.com/intro-skipper/intro-skipper/releases/download/12.0/v12.0.4.0/intro-skipper-v12.0.4.0.zip";
    hash = "sha256-sPEZXGB3s+YI1E9+qJ3EWdKFu2gdqK7LfNjV4QjMlnA=";
    meta = {
      # Taken from the meta.json the catalogue installer wrote for 1.10.11.24,
      # which is what owns the existing IntroSkipper.xml configuration.
      guid = "c83d86bb-a1e0-4c35-a113-e2101cf4ee6b";
      name = "Intro Skipper";
      overview = "Automatically detect and skip intros in television episodes";
      description = "Analyzes the audio of television episodes and detects introduction sequences.";
      owner = "AbandonedCart, rlauuzo, jumoog (forked from ConfusedPolarBear)";
      category = "MoviesAndShows";
      targetAbi = "12.0.0.0";
    };
  };

  # Ships one zip per Jellyfin line per release; `_12.0.0` is the 12.x build.
  # Its own version numbering has been in the 12.x range since well before
  # Jellyfin 12 existed, so the two are unrelated -- do not read 12.7.0.0 as a
  # server version.
  jellyfin-enhanced = fetchPlugin {
    pname = "jellyfin-enhanced";
    version = "12.8.0.0";
    dirName = "JellyfinEnhanced_12.8.0.0";
    supersedes = [
      "JellyfinEnhanced_*"
      "Jellyfin Enhanced_*"
    ];
    url = "https://github.com/n00bcodr/Jellyfin-Enhanced/releases/download/12.8.0.0/Jellyfin.Plugin.JellyfinEnhanced_12.0.0.zip";
    hash = "sha256-qUOpYlS2WDwZiiqoK3V1YVrrVf0ayrYEamZoRgx0ew0=";
    meta = {
      guid = "f69e946a-4b3c-4e9a-8f0a-8d7c1b2c4d9b";
      name = "Jellyfin Enhanced";
      overview = "Keyboard shortcuts, quality tweaks and UI enhancements";
      description = "Adds keyboard shortcuts, subtitle styling, quality selection and other client-side enhancements to the Jellyfin web UI.";
      owner = "n00bcodr";
      category = "General";
      targetAbi = "12.0.0.0";
    };
  };

  # Everything that belongs in the plugins directory when Jellyfin is on the
  # 12.x line.
  all12 = [
    open-subtitles
    tvdb
    intro-skipper
    jellyfin-enhanced
  ];

  # Shell that materialises one plugin into a writable directory under `dir`.
  # `--no-preserve=mode` and the chmod are the entire point: the store copy is
  # mode 444, and Jellyfin has to be able to rewrite `meta.json` in place.
  #
  # `supersedes` is cleared first so an old version cannot linger beside the new
  # one -- two directories carrying the same plugin GUID is what the web UI
  # installer kept leaving behind.
  install =
    dir: p:
    lib.concatStringsSep "\n" (
      (map (g: ''run rm -rf "${dir}"/${lib.replaceStrings [ " " ] [ "\\ " ] g}'') p.supersedes)
      ++ [
        ''run mkdir -p "${dir}"''
        ''run cp -r --no-preserve=mode,ownership ${p.src}/. "${dir}/${p.dirName}"''
        ''run chmod -R u+rwX "${dir}/${p.dirName}"''
      ]
    );
}
