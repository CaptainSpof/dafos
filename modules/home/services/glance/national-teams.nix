# A Dynacat custom-api widget following national teams across every
# competition: live match, three latest results, three next fixtures.
#
# ESPN's per-team schedule under the `all` league spans competitions. It
# needs two calls: `fixture=true` for what is coming, `season=<year>` for
# results (without it the results stop in 2025). The fixture list repeats
# some matches, hence `unique "id"`.
{ title, teams }:
let
  layout = "2006-01-02T15:04Z07:00";
  limit = "3";
  base = "https://site.api.espn.com/apis/site/v2/sports/soccer/all/teams";

  teamBlock =
    {
      name,
      flag,
      id,
      # HTML shown beside the team name; the "open in FotMob" button.
      link ? "",
    }:
    ''
      {{ with $team := "${name}" }}
        {{ $fixtures := newRequest "${base}/${id}/schedule" | withParameter "fixture" "true" | getResponse }}
        {{ $results := newRequest "${base}/${id}/schedule" | withParameter "season" (now | formatTime "2006") | getResponse }}
        <div class="flex items-center gap-10 size-h3 color-highlight margin-top-15 margin-bottom-5">${flag} ${name} ${link}</div>
        {{ if or (ne $fixtures.Response.StatusCode 200) (ne $results.Response.StatusCode 200) }}
          <p class="color-negative">ESPN indisponible : {{ $fixtures.Response.Status }} / {{ $results.Response.Status }}</p>
        {{ else }}
          {{ $live := "," }}
          <ul class="list list-gap-8">
            {{ range list ($fixtures.JSON.Array "events") ($results.JSON.Array "events") }}{{ range . }}
              {{ $id := .String "id" }}
              {{ if and (eq (.String "competitions.0.status.type.state") "in") (eq (findMatch (concat "," $id ",") $live) "") }}
                {{ template "national-match" . }}{{ $live = concat $live $id "," }}
              {{ end }}
            {{ end }}{{ end }}
          </ul>

          <div class="size-h5 uppercase margin-top-10 margin-bottom-5">Résultats</div>
          <ul class="list list-gap-8">
            {{ $n := 0 }}
            {{ range sortByTime "date" "${layout}" "desc" (unique "id" ($results.JSON.Array "events")) }}
              {{ $id := .String "id" }}
              {{ if and (eq (.String "competitions.0.status.type.state") "post") (lt $n ${limit}) }}
                {{ template "national-match" . }}{{ $n = add $n 1 }}
              {{ end }}
            {{ end }}
            {{ if eq $n 0 }}<li>Aucun résultat cette saison.</li>{{ end }}
          </ul>

          <div class="size-h5 uppercase margin-top-10 margin-bottom-5">À venir</div>
          <ul class="list list-gap-8">
            {{ $n := 0 }}
            {{ range sortByTime "date" "${layout}" "asc" (unique "id" ($fixtures.JSON.Array "events")) }}
              {{ $id := .String "id" }}
              {{ if and (eq (.String "competitions.0.status.type.state") "pre") (lt $n ${limit}) }}
                {{ template "national-match" . }}{{ $n = add $n 1 }}
              {{ end }}
            {{ end }}
            {{ if eq $n 0 }}<li>Aucun match programmé.</li>{{ end }}
          </ul>
        {{ end }}
      {{ end }}
    '';
in
{
  type = "custom-api";
  inherit title;
  cache = "1m";
  update-interval = "1m";
  template = ''
    {{ define "national-match" }}
      {{ $state := .String "competitions.0.status.type.state" }}
      {{ $home := "competitions.0.competitors.#(homeAway==\"home\")" }}
      {{ $away := "competitions.0.competitors.#(homeAway==\"away\")" }}
      {{ $local := (.String "date" | parseTime "${layout}").Local }}
      {{ $competition := .String "league.name"
        | replaceAll "FIFA World Cup Qualifying - UEFA" "Qualif. Coupe du monde"
        | replaceAll "UEFA European Championship Qualifying" "Qualif. Euro"
        | replaceAll "UEFA European Championship" "Euro"
        | replaceAll "FIFA World Cup" "Coupe du monde"
        | replaceAll "UEFA Nations League" "Ligue des nations"
        | replaceAll "International Friendly" "Match amical" }}
      <li class="flex items-center gap-10">
        <div class="text-right grow text-truncate color-highlight" style="flex-basis:0">{{ .String (concat $home ".team.shortDisplayName") }}</div>
        <img src="{{ .String (concat $home ".team.logos.0.href") }}" alt="" style="width:1.6rem;height:1.6rem" loading="lazy">
        <div class="shrink-0 text-center" style="min-width:7rem">
          {{ if eq $state "pre" }}
            <div class="color-highlight">{{ $local.Format "02/01 15:04" }}</div>
          {{ else }}
            <div class="color-highlight size-h3">{{ .String (concat $home ".score.displayValue") }} – {{ .String (concat $away ".score.displayValue") }}</div>
          {{ end }}
          <div class="size-h6 text-truncate {{ if eq $state "in" }}color-positive{{ end }}">
            {{ if eq $state "in" }}{{ .String "competitions.0.status.displayClock" }}{{ else if eq $state "post" }}{{ $local.Format "02/01" }} · {{ $competition }}{{ else }}{{ $competition }}{{ end }}
          </div>
        </div>
        <img src="{{ .String (concat $away ".team.logos.0.href") }}" alt="" style="width:1.6rem;height:1.6rem" loading="lazy">
        <div class="grow text-truncate color-highlight" style="flex-basis:0">{{ .String (concat $away ".team.shortDisplayName") }}</div>
      </li>
    {{ end }}

    ${builtins.concatStringsSep "\n" (map teamBlock teams)}
  '';
}
