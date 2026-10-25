# A custom-api widget summing up the restic repositories, from the JSON the
# backup-status aspect serves (flake-modules/services/backup/backup-status.nix):
# per host, the age of the newest snapshot, what it added, the snapshot count
# and the repository size. A snapshot older than `maxAge`, a failed run, a
# repository restic cannot read or stale database dumps carry `dafos-alert`
# (see monitoring-alert.js).
{
  # The status.json URL, as seen from the glance container.
  url,
  # The backups run nightly; same threshold as the server-side staleness alert.
  maxAge ? "26h",
}:
{
  type = "custom-api";
  title = "Sauvegardes";
  cache = "5m";
  update-interval = "5m";
  inherit url;
  template = ''
    {{ if ne .Response.StatusCode 200 }}
      <p class="color-negative dafos-alert">État des sauvegardes injoignable : {{ .Response.Status }}</p>
    {{ else }}
      {{ $old := offsetNow "-${maxAge}" }}
      <ul class="list list-gap-10">
        {{ range .JSON.Array "repos" }}
          {{ $t := .String "latest.time" }}
          <li>
            <div class="flex items-center gap-10">
              <div class="grow color-highlight">{{ .String "name" }}</div>
              {{ if ne (.String "error") "" }}
                <div class="shrink-0 size-h6 color-negative text-truncate dafos-alert">{{ .String "error" }}</div>
              {{ else if eq $t "" }}
                <div class="shrink-0 color-negative dafos-alert">aucun instantané</div>
              {{ else }}
                <div class="shrink-0 size-h4 {{ if (parseTime "rfc3339" $t).Before $old }}color-negative dafos-alert{{ else }}color-positive{{ end }}" title="{{ $t }}" {{ parseRelativeTime "rfc3339" $t }}></div>
              {{ end }}
            </div>
            {{ if eq (.String "error") "" }}
              <div class="flex gap-10 size-h6">
                <span>{{ .Int "snapshots" }} instantanés</span>
                <span>{{ formatBytes (.Int "size") }}</span>
                {{ if ne $t "" }}<span>+{{ formatBytes (.Int "latest.summary.data_added") }}</span>{{ end }}
              </div>
            {{ end }}
            {{ $result := .String "unit.result" }}
            {{ if and (ne $result "") (ne $result "success") }}
              <div class="size-h6 color-negative dafos-alert">{{ .String "unit.name" }} : {{ $result }}</div>
            {{ end }}
            {{ $d := .String "dumps.time" }}
            {{ if and (.Exists "dumps") (or (eq $d "") ((parseTime "rfc3339" $d).Before $old)) }}
              <div class="size-h6 color-negative dafos-alert">dumps des bases manquants ou périmés</div>
            {{ end }}
          </li>
        {{ end }}
      </ul>
    {{ end }}
  '';
}
