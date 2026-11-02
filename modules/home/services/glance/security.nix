# The « Sécurité » page: custom-api widgets over the status.json the
# security-status aspect writes (flake-modules/services/security-status.nix).
# The file sits in a directory bind-mounted under Dynacat's assets, so each
# widget reads it from Dynacat's own port. A defence that is down, a stale
# file and IPs banned by Authelia carry `dafos-alert` (see
# monitoring-alert.js); CrowdSec bans are routine and do not.
#
# Dynacat renders every widget once before it opens its port, so the file is
# fetched from the template (`getResponse`) rather than as the main request:
# a refused connection then reads « en attente » for that first minute instead
# of the widget-wide error box. getResponse turns every failure, a 404 too,
# into status 0, so only the refused connection is matched (on its text).
{
  # status.json, as seen from inside the dashboard container.
  url,
  # The file is rewritten every 5 minutes.
  maxAge ? "15m",
}:
let
  # A custom-api widget whose body sees status.json as its dot.
  widget =
    {
      title,
      icon,
      body,
    }:
    {
      type = "custom-api";
      inherit title;
      title-icon = icon;
      cache = "1m";
      update-interval = "1m";
      template = ''
        {{ $r := newRequest "${url}" | getResponse }}
        {{ if eq $r.Response.StatusCode 200 }}
          {{ with $r.JSON }}${body}{{ end }}
        {{ else if ne (findMatch "connection refused" $r.Response.Status) "" }}
          <p class="size-h6">En attente du relevé…</p>
        {{ else }}
          <p class="color-negative dafos-alert">État de la sécurité injoignable : {{ $r.Response.Status }}</p>
        {{ end }}
      '';
    };

  # One « label · state » line of the Défenses widget.
  row = label: ok: okText: badText: ''
    <li class="flex items-center gap-10">
      <div class="grow color-highlight">${label}</div>
      {{ if ${ok} }}
        <div class="shrink-0 color-positive">${okText}</div>
      {{ else }}
        <div class="shrink-0 color-negative dafos-alert">${badText}</div>
      {{ end }}
    </li>
  '';

  counter = label: value: cls: ''
    <li class="flex items-center gap-10">
      <div class="grow">${label}</div>
      <div class="shrink-0 size-h4 ${cls}">${value}</div>
    </li>
  '';
in
{
  defences = widget {
    title = "Défenses";
    icon = "mdi:shield-check";
    body = ''
      {{ $generated := .String "generated" }}
      <ul class="list list-gap-8">
        ${row "CrowdSec" ''.Bool "crowdsec.running"'' "actif" "arrêté"}
        ${row "API locale" ''.Bool "crowdsec.lapi"'' "répond" "injoignable"}
        ${row "Liste communautaire" ''.Bool "crowdsec.capi"'' ''{{ .Int "crowdsec.blocklist" }} IP''
          "injoignable"
        }
        ${row "Authelia" ''.Bool "authelia.running"'' "actif" "arrêté"}
        ${counter "Échecs de connexion (24 h)" ''{{ .Int "authelia.failures" }}''
          ''{{ if gt (.Int "authelia.failures") 0 }}color-highlight{{ else }}color-positive{{ end }}''
        }
        ${counter "IP bannies par Authelia" ''{{ .Int "authelia.bans" }}''
          ''{{ if gt (.Int "authelia.bans") 0 }}color-negative dafos-alert{{ else }}color-positive{{ end }}''
        }
      </ul>
      {{ if (parseTime "rfc3339" $generated).Before (offsetNow "-${maxAge}") }}
        <p class="margin-top-10 size-h6 color-negative dafos-alert">Relevé périmé : <span {{ parseRelativeTime "rfc3339" $generated }}></span></p>
      {{ end }}
    '';
  };

  bans = widget {
    title = "Bans CrowdSec en cours";
    icon = "mdi:cancel";
    body = ''
      {{ $bans := .Array "crowdsec.bans" }}
      {{ if eq (len $bans) 0 }}
        <p class="color-positive">Aucun ban en cours.</p>
      {{ else }}
        <p class="size-h6 margin-bottom-10">{{ len $bans }} IP bannies sur toutes les routes publiques</p>
        <ul class="list list-gap-10 collapsible-container" data-collapse-after="8">
          {{ range $bans }}
            <li>
              <div class="flex items-center gap-10">
                <div class="grow color-highlight text-truncate">{{ .String "ip" }}</div>
                <div class="shrink-0 size-h6" title="temps restant">{{ .String "remaining" }}</div>
              </div>
              <div class="flex gap-10 size-h6">
                <span class="shrink-0">{{ .String "cn" }}</span>
                <span class="text-truncate">{{ .String "scenario" }}</span>
                <span class="grow text-truncate text-right">{{ .String "as" }}</span>
              </div>
            </li>
          {{ end }}
        </ul>
      {{ end }}
    '';
  };

  attacks = widget {
    title = "Attaques (24 h)";
    icon = "mdi:target";
    body = ''
      <div class="flex justify-between text-center margin-bottom-15">
        <div>
          <div class="color-highlight size-h3">{{ .Int "crowdsec.alerts.count" }}</div>
          <div class="size-h6">alertes</div>
        </div>
        <div>
          <div class="color-highlight size-h3">{{ .Int "crowdsec.alerts.ips" }}</div>
          <div class="size-h6">IP</div>
        </div>
      </div>
      {{ $scenarios := .Array "crowdsec.alerts.scenarios" }}
      {{ if gt (len $scenarios) 0 }}
        <ul class="list list-gap-8">
          {{ range $scenarios }}
            <li class="flex items-center gap-10">
              <div class="grow text-truncate">{{ .String "name" }}</div>
              <div class="shrink-0 color-highlight">{{ .Int "count" }}</div>
            </li>
          {{ end }}
        </ul>
        <p class="margin-top-15 size-h6">
          {{ range $i, $c := .Array "crowdsec.alerts.countries" }}{{ if $i }} · {{ end }}{{ $c.String "name" }} {{ $c.Int "count" }}{{ end }}
        </p>
      {{ else }}
        <p class="color-positive">Aucune alerte depuis 24 h.</p>
      {{ end }}
    '';
  };
}
