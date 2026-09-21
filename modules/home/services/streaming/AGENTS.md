# streaming (Jellyfin and the arrs)

## Jellyfin's image tag moves, so auto-update is off

The pin is upstream's: nps carries Jellyfin 12.1 plus a renovate regex for
linuxserver's `version-<v>ubu<n>` tag shape, which is what its old rule could
not match. Nothing to override here any more — let renovate bump it.

What _is_ set locally is `autoUpdate = "local"`, because `version-*` is a moving
tag: `12.1ubu2604-ls49` and `-ls50` are distinct builds of the same Jellyfin and
`version-12.1ubu2604` follows the newer one. On the default `registry` policy
the Sunday 00:00 pull would roll linuxserver rebuilds unattended into a
container holding a database. Same reasoning as the data-bearing containers in
the grimmory module.

### Patch `encoding.xml` before taking a new major

10.11 wrote `<EncoderPreset xsi:nil="true" />`; 12.x cannot deserialize that,
logs `Error loading configuration file: "/config/encoding.xml"`, and silently
falls back to defaults **for the whole file** — which reset
`HardwareAccelerationType` from `qsv` to `none` and blanked `QsvDevice` and
`HardwareDecodingCodecs`, so the box quietly transcoded on CPU. It was in no
release note, and it fired here on 2026-09-16. The fix was one element:

```bash
sed -i 's|<EncoderPreset xsi:nil="true" />|<EncoderPreset>auto</EncoderPreset>|' \
  ~/stacks/streaming/jellyfin/encoding.xml
```

Kept as a worked example rather than a live instruction: before any future
major, diff `encoding.xml` against a dry-run copy and check the
hardware-acceleration block specifically. Note this box has **two** render
nodes, so `QsvDevice` wants `/dev/dri/renderD128` explicitly rather than blank
auto-detection.

A major upgrade is also one-way: it migrates the database, upstream says rolling
back needs a full restore of `~/stacks/streaming/jellyfin`, and a full library
rescan is required afterwards.

## Plugin directories must be writable

Jellyfin rewrites a plugin's own `meta.json` when it first loads it
(`PluginManager.ChangePluginState` → `SaveManifest`), and that happens inside
`InitializeServices`. If the directory is read-only it throws
`UnauthorizedAccessException` and **the whole server fails to start** — not just
that plugin.

So pinned plugins are _copied_ out of the store by the
`home.activation.jellyfinPlugins` script, not bind-mounted from it. Mounting the
store read-only took Jellyfin down on 2026-09-16. A `:O` overlay mount is not a
way around it either: new files are writable, but copy-up preserves the store's
444 mode, so rewriting an existing `meta.json` still fails.

Anything that has to be readable _and_ writable by Jellyfin is in the same
position. Prove a change by starting a throwaway container against a scratch
`/config` before it goes near the real one:

```bash
podman run -d --rm --name jftest -e PUID=0 -e PGID=0 -v /tmp/jftest/config:/config <image>
```

and look for `Startup complete` plus `Loaded plugin:` in
`/tmp/jftest/config/log/`.

## Plugins are pinned, not installed

Plugins come from [jellyfin-plugins.nix](jellyfin-plugins.nix). Do not install
them through the web UI: the UI writes into host state, so the running version
becomes whatever was last clicked, a rebuild can neither see nor reproduce it,
and nothing removes the superseded copy — this box was running two builds of
Jellyfin Enhanced side by side.

Adding one is a single `fetchPlugin` entry plus a place in `managedPlugins`. Pin
the release archive rather than a plugin repository URL, and check the hash
against the publisher's own checksum. `supersedes` lists the directories the
plugin replaces, including the space-containing names the UI installer used, so
old versions go away instead of leaving a second directory with the same plugin
GUID.

Some publishers ship a bare DLL with no `meta.json` (Intro Skipper, Jellyfin
Enhanced); `fetchPlugin` takes a `meta` argument and generates it. The `guid`
there is the plugin's identity — get it wrong and Jellyfin treats it as a
different plugin and orphans its existing configuration.

Plugin _configuration_ is deliberately not managed. It lives in the sibling
`plugins/configurations/`, which the activation script never touches, so
anything tuned through the dashboard survives a version bump. The exceptions are
SSO-Auth and LDAP-Auth, whose configs are generated because they carry secrets;
those two are rendered templates under /run, so a plugin write-back to them
survives only until the container restarts. That is why
`EnableLdapProfileImageSync` stays off: it would re-fetch every avatar on every
restart.

## Two login paths, one set of groups

`jellyfin_admin` and `jellyfin_user` — created by nps for the OIDC half — gate
**both** the Authelia SSO plugin and the LDAP filters. Membership is declared in
[../lldap](../lldap). Change the groups in one place or the two paths disagree
about who is allowed in.

LDAP binds as `CN=readonly,OU=people,…` — `CN=`, not `uid=`, which is lldap's
own bind-DN form and what Authelia already uses against this directory. `uid`
remains the username attribute.
