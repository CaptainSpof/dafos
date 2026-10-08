# A custom-api widget with each host's CPU temperature and load, from the
# Glance agents (flake-modules/services/glance-agent.nix). The server-stats
# widget shows the same reading in small; this one colours it, because dafpi
# (passive cooling only) reached 97 °C under load.
{
  lib,
  # [ { name; url; } ]: each host's agent, reached through Traefik.
  hosts,
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
    in
    ''
      {{ $r${toString i} := ${r} }}
      <li class="flex items-center gap-10">
        <div class="grow color-highlight">${h.name}</div>
        {{ if ne $r${toString i}.Response.StatusCode 200 }}
          <div class="shrink-0 color-negative">injoignable</div>
        {{ else }}
          {{ $t${toString i} := $r${toString i}.JSON.Int "cpu.temperature_c" }}
          <div class="shrink-0 size-h6">charge {{ $r${toString i}.JSON.Int "cpu.load1_percent" }} %</div>
          <div class="shrink-0 size-h3 {{ if ge $t${toString i} 85 }}temp-hot{{ else if ge $t${toString i} 70 }}temp-warm{{ else }}temp-ok{{ end }}">{{ $t${toString i} }} °C</div>
        {{ end }}
      </li>
    '';
in
{
  type = "custom-api";
  title = "Températures";
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
