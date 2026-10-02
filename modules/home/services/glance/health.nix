# A custom-api widget that lists only what is broken: containers that are not
# running or report "unhealthy", and host services that do not answer 2xx/3xx.
# With nothing broken it calls `hide`, so the widget disappears instead of
# showing an all-green list.
#
# Nothing on dafoltop is stopped on purpose (no one-shot containers), so any
# state other than "running" is worth flagging.
{
  lib,
  # Docker-compatible API, through socket-proxy.
  socketUrl,
  # container name -> label shown
  labels,
  # [ { title; url; } ] probed with a plain GET
  sites,
}:
let
  labelTemplate = ''
    {{ define "container-label" }}${
      lib.concatStrings (
        lib.mapAttrsToList (name: label: ''{{ if eq . "${name}" }}${label}{{ else }}'') labels
      )
    }{{ . }}${lib.concatStrings (lib.mapAttrsToList (_: _: "{{ end }}") labels)}{{ end }}
  '';

  siteCheck = site: ''
    {{ $r := newRequest "${site.url}" | getResponse }}
    {{/* Dynacat's getResponse wants JSON: a 2xx HTML page (every web UI here)
         comes back as status 0 with the error text "invalid response JSON".
         That error only happens on 2xx, so it means the service is up. */}}
    {{ $up := or (eq $r.Response.Status "invalid response JSON") (and (ge $r.Response.StatusCode 200) (lt $r.Response.StatusCode 400)) }}
    {{ if not $up }}
      {{ $bad = add $bad 1 }}
      <li class="flex items-center gap-10">
        <div class="grow text-truncate color-highlight">${site.title}</div>
        <div class="shrink-0 size-h6 color-negative">{{ if eq $r.Response.StatusCode 0 }}injoignable{{ else }}{{ $r.Response.Status }}{{ end }}</div>
      </li>
    {{ end }}
  '';
in
{
  type = "custom-api";
  title = "Services en panne";
  title-icon = "mdi:alert";
  cache = "1m";
  update-interval = "1m";
  template = ''
    ${labelTemplate}
    {{ $bad := 0 }}
    {{ $containers := newRequest "${socketUrl}/containers/json" | withParameter "all" "true" | getResponse }}
    <ul class="list list-gap-8">
      {{ if ne $containers.Response.StatusCode 200 }}
        {{ $bad = add $bad 1 }}
        <li class="color-negative">socket-proxy injoignable : {{ $containers.Response.Status }}</li>
      {{ else }}
        {{ range $containers.JSON.Array "" }}
          {{ $name := .String "Names.0" | trimPrefix "/" }}
          {{ $state := .String "State" }}
          {{ $unhealthy := ne (findMatch "unhealthy" (.String "Status")) "" }}
          {{ if or (ne $state "running") $unhealthy }}
            {{ $bad = add $bad 1 }}
            <li class="flex items-center gap-10">
              <div class="grow text-truncate color-highlight">{{ template "container-label" $name }}</div>
              <div class="shrink-0 size-h6 color-negative">
                {{ if $unhealthy }}défaillant{{ else }}{{ $state | replaceAll "exited" "arrêté" | replaceAll "created" "jamais démarré" | replaceAll "paused" "en pause" | replaceAll "restarting" "redémarre" | replaceAll "dead" "mort" }}{{ end }}
              </div>
            </li>
          {{ end }}
        {{ end }}
      {{ end }}
      ${lib.concatMapStrings siteCheck sites}
    </ul>
    {{ if eq $bad 0 }}{{ hide }}{{ end }}
  '';
}
