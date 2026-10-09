# A Dynacat custom-api widget for one ESPN league: live games, the five
# latest results and the five next fixtures.
#
# ESPN's scoreboard returns only the next matchday by default and answers 400
# to a `dates=YYYYMMDD-YYYYMMDD` range, but accepts a whole month
# (`dates=YYYYMM`). The template fetches every month within three weeks of
# today, one batch per month, so an international break still leaves results
# and fixtures to show. Batches are disjoint and in month order: sorting each
# one and walking them forwards or backwards orders the whole set.
{
  title,
  # ESPN's path: "soccer/fra.1", "basketball/nba".
  league,
  # HTML put before the matches; the "open in FotMob" button.
  button ? "",
}:
let
  layout = "2006-01-02T15:04Z07:00";
  limit = "5";
  # A football clock reads "67'"; a basketball one needs its quarter
  # ("5:32 - 3rd"), which `shortDetail` carries.
  clock =
    if builtins.substring 0 7 league == "soccer/" then
      "status.displayClock"
    else
      "status.type.shortDetail";
in
{
  type = "custom-api";
  inherit title;
  cache = "1m";
  update-interval = "1m";
  template = ''
    ${button}
    {{ define "match" }}
      {{ $state := .String "status.type.state" }}
      {{ $home := "competitions.0.competitors.#(homeAway==\"home\")" }}
      {{ $away := "competitions.0.competitors.#(homeAway==\"away\")" }}
      {{ $local := (.String "date" | parseTime "${layout}").Local }}
      <li class="flex items-center gap-10">
        <div class="text-right grow text-truncate color-highlight" style="flex-basis:0">{{ .String (concat $home ".team.shortDisplayName") }}</div>
        <img src="{{ .String (concat $home ".team.logo") }}" alt="" style="width:1.6rem;height:1.6rem" loading="lazy">
        <div class="shrink-0 text-center" style="min-width:5.5rem">
          {{ if eq $state "pre" }}
            <div class="color-highlight">{{ $local.Format "15:04" }}</div>
            <div class="size-h6">{{ $local.Format "02/01" }}</div>
          {{ else }}
            <div class="color-highlight size-h3">{{ .String (concat $home ".score") }} – {{ .String (concat $away ".score") }}</div>
            <div class="size-h6 {{ if eq $state "in" }}color-positive{{ end }}">
              {{ if eq $state "in" }}{{ .String "${clock}" }}{{ else }}{{ $local.Format "02/01" }}{{ end }}
            </div>
          {{ end }}
        </div>
        <img src="{{ .String (concat $away ".team.logo") }}" alt="" style="width:1.6rem;height:1.6rem" loading="lazy">
        <div class="grow text-truncate color-highlight" style="flex-basis:0">{{ .String (concat $away ".team.shortDisplayName") }}</div>
      </li>
    {{ end }}

    {{ $months := uniq (list (offsetNow "-504h" | formatTime "200601") (now | formatTime "200601") (offsetNow "504h" | formatTime "200601")) }}
    {{ $batches := list }}
    {{ $failed := "" }}
    {{ range $months }}
      {{ $r := newRequest "https://site.api.espn.com/apis/site/v2/sports/${league}/scoreboard"
        | withParameter "limit" "500"
        | withParameter "dates" .
        | getResponse }}
      {{ if eq $r.Response.StatusCode 200 }}
        {{ $batches = append $batches ($r.JSON.Array "events") }}
      {{ else }}
        {{ $failed = $r.Response.Status }}
      {{ end }}
    {{ end }}
    {{ $reversed := $batches }}
    {{ if eq (len $batches) 2 }}{{ $reversed = list (index $batches 1) (index $batches 0) }}{{ end }}
    {{ if eq (len $batches) 3 }}{{ $reversed = list (index $batches 2) (index $batches 1) (index $batches 0) }}{{ end }}

    {{ if ne $failed "" }}
      <p class="color-negative">ESPN indisponible : {{ $failed }}</p>
    {{ end }}

    {{ $live := 0 }}{{ $past := 0 }}{{ $next := 0 }}
    {{ range $batches }}{{ range . }}
      {{ $s := .String "status.type.state" }}
      {{ if eq $s "in" }}{{ $live = add $live 1 }}{{ else if eq $s "post" }}{{ $past = add $past 1 }}{{ else if eq $s "pre" }}{{ $next = add $next 1 }}{{ end }}
    {{ end }}{{ end }}

    {{ if gt $live 0 }}
      <div class="size-h5 uppercase margin-bottom-5 color-positive">En direct</div>
      <ul class="list list-gap-8 margin-bottom-10">
        {{ range $batches }}{{ range . }}
          {{ if eq (.String "status.type.state") "in" }}{{ template "match" . }}{{ end }}
        {{ end }}{{ end }}
      </ul>
    {{ end }}

    {{ if gt $past 0 }}
      <div class="size-h5 uppercase margin-bottom-5">Résultats</div>
      <ul class="list list-gap-8 margin-bottom-10">
        {{ $n := 0 }}
        {{ range $reversed }}{{ range sortByTime "date" "${layout}" "desc" . }}
          {{ if and (eq (.String "status.type.state") "post") (lt $n ${limit}) }}
            {{ template "match" . }}{{ $n = add $n 1 }}
          {{ end }}
        {{ end }}{{ end }}
      </ul>
    {{ end }}

    {{ if gt $next 0 }}
      <div class="size-h5 uppercase margin-bottom-5">À venir</div>
      <ul class="list list-gap-8">
        {{ $n := 0 }}
        {{ range $batches }}{{ range sortByTime "date" "${layout}" "asc" . }}
          {{ if and (eq (.String "status.type.state") "pre") (lt $n ${limit}) }}
            {{ template "match" . }}{{ $n = add $n 1 }}
          {{ end }}
        {{ end }}{{ end }}
      </ul>
    {{ end }}

    {{ if and (eq (add $live (add $past $next)) 0) (eq $failed "") }}
      <p>Aucun match dans les trois semaines.</p>
    {{ end }}
  '';
}
