# LanguageTool

Spelling and grammar server behind the DMS proofreader plugin
(`modules/home/desktop/dms/plugins/proofreader`). The plugin only needs an HTTP
URL, set per home in `dafos.desktop.dms.proofreader.languageToolUrl`.

dafbox runs its own instance on `127.0.0.1:8081`, which is the plugin's default.

## Serving daftop from dafoltop

Nothing here is enabled yet. Do it only if daftop needs it — the JVM costs up to
1 GB on a box with ~8 GB to spare (see
[../../../../systems/x86_64-linux/dafoltop/AGENTS.md](../../../../systems/x86_64-linux/dafoltop/AGENTS.md)).

1. On dafoltop, in `systems/x86_64-linux/dafoltop/default.nix`:

   ```nix
   services.languagetool = {
     enable = true;
     openFirewallForPodman = true;
   };
   ```

2. In `modules/home/services/traefik/default.nix`, add a router and a service
   next to `zigbee2mqtt-nix`:

   ```nix
   routers.languagetool-nix = {
     rule = "Host(`languagetool.${cfg.base-url}`)";
     service = "languagetool-service";
     entryPoints = [ "websecure" ];
     # No auth of its own: LAN and tailnet only.
     middlewares = [ "private@file" ];
     tls.certResolver = "letsencrypt";
   };
   services.languagetool-service.loadBalancer.servers = [
     { url = "http://host.containers.internal:8081"; }
   ];
   ```

3. In `homes/x86_64-linux/daf@daftop/default.nix`:

   ```nix
   desktop.dms.proofreader = {
     enable = true;
     languageToolUrl = "https://languagetool.daftdaf.dev";
   };
   ```

Check it from daftop over the tailnet:

```bash
curl -s -d 'language=auto&text=Je suis aller' https://languagetool.daftdaf.dev/v2/check | jq '.matches[0].replacements[0]'
```
