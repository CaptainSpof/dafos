# A custom-api widget with each host's CPU temperature and load, from the
# Glance agents (flake-modules/services/glance-agent.nix), plus a line per
# nearly full disk. The server-stats widget shows the same readings in
# small; this one colours them, because dafpi (passive cooling only) reached
# 97 °C under load, and server-stats only flags the combined usage of a
# host's disks.
#
# Every alert carries the `dafos-alert` class: monitoring-alert.js looks for
# it to colour the Monitoring tab.
{
  lib,
  # [ { name; url; } ]: each host's agent, reached through Traefik.
  hosts,
  tempWarm ? 70,
  tempHot ? 85,
  diskFull ? 90,
}:
let
  headers.Authorization = "Bearer \${GLANCE_AGENT_TOKEN}";
  first = builtins.head hosts;
  rest = builtins.tail hosts;

  # The first host is the main request, the others subrequests.
  hostBlock =
    i: h:
    let
      r = if i == 0 then "." else "(.Subrequest \"${h.name}\")";
      v = "$r${toString i}";
      t = "$t${toString i}";
    in
    ''
      {{ ${v} := ${r} }}
      <li class="flex items-center gap-10">
        <div class="grow color-highlight">${h.name}</div>
        {{ if ne ${v}.Response.StatusCode 200 }}
          <div class="shrink-0 color-negative dafos-alert">injoignable</div>
        {{ else }}
          {{ ${t} := ${v}.JSON.Int "cpu.temperature_c" }}
          <div class="shrink-0 size-h6">charge {{ ${v}.JSON.Int "cpu.load1_percent" }} %</div>
          <div class="shrink-0 size-h3 {{ if ge ${t} ${toString tempHot} }}temp-hot dafos-alert{{ else if ge ${t} ${toString tempWarm} }}temp-warm{{ else }}temp-ok{{ end }}">{{ ${t} }} °C</div>
        {{ end }}
      </li>
      {{ if eq ${v}.Response.StatusCode 200 }}
        {{ range ${v}.JSON.Array "mountpoints" }}
          {{ if ge (.Int "used_percent") ${toString diskFull} }}
            <li class="flex items-center gap-10 size-h6 color-negative dafos-alert">
              <div class="grow">disque {{ .String "name" }} presque plein</div>
              <div class="shrink-0">{{ .Int "used_percent" }} %</div>
            </li>
          {{ end }}
        {{ end }}
      {{ end }}
    '';
in
{
  type = "custom-api";
  title = "État des hôtes";
  cache = "1m";
  update-interval = "1m";
  url = "${first.url}/api/sysinfo/all";
  inherit headers;
  subrequests = lib.listToAttrs (
    map (
      h:
      lib.nameValuePair h.name {
        url = "${h.url}/api/sysinfo/all";
        inherit headers;
      }
    ) rest
  );
  template = ''
    <ul class="list list-gap-10">
      ${lib.concatStrings (lib.imap0 hostBlock hosts)}
    </ul>
  '';
}
