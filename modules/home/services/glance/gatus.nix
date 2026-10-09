# A custom-api widget summing up gatus (on dafpi): the probes that fail, or a
# one-line all-clear. gatus returns every endpoint's history; `pageSize=1`
# keeps only the latest result, at index 0. Failures carry `dafos-alert`
# (see monitoring-alert.js).
{
  # gatus' base URL, reached through Traefik's private gate.
  url,
}:
{
  type = "custom-api";
  title = "Sondes gatus";
  title-url = url;
  cache = "1m";
  update-interval = "1m";
  url = "${url}/api/v1/endpoints/statuses?page=1&pageSize=1";
  template = ''
    {{ if ne .Response.StatusCode 200 }}
      <p class="color-negative dafos-alert">gatus injoignable : {{ .Response.Status }}</p>
    {{ else }}
      {{ $total := 0 }}
      {{ $bad := 0 }}
      <ul class="list list-gap-8">
        {{ range .JSON.Array "" }}
          {{ $total = add $total 1 }}
          {{ if and (gt (.Int "results.#") 0) (not (.Bool "results.0.success")) }}
            {{ $bad = add $bad 1 }}
            <li class="flex items-center gap-10">
              <div class="grow text-truncate color-highlight">{{ .String "group" }} · {{ .String "name" }}</div>
              <div class="shrink-0 size-h6 color-negative text-truncate dafos-alert">{{ .String "results.0.errors.0" }}</div>
            </li>
          {{ end }}
        {{ end }}
      </ul>
      {{ if eq $bad 0 }}
        <p class="color-positive">Les {{ $total }} sondes sont vertes.</p>
      {{ end }}
    {{ end }}
  '';
}
