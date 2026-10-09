# A Dynacat custom-api widget with one ESPN standings table: a football
# league, or one NBA conference.
#
# Standings live under ESPN's `apis/v2`, not the `apis/site/v2` the
# scoreboards use. Each `children` entry is a table: the season for a
# league, a conference for the NBA. NBA entries come unordered, hence the
# sort on `playoffSeed`; football ones are already in rank order.
#
# A coloured stripe marks each row's zone, drawn by `.standings-*` in the
# module's userCss (classes, not inline styles: html/template turns a
# templated colour into "ZgotmplZ"). Football takes the zone from ESPN's
# `note.description`; the NBA from the seed (1-6 playoffs, 7-10 play-in).
{
  title,
  # ESPN's path: "soccer/fra.1", "basketball/nba".
  league,
  # Which table of `children`: 0 is the East for the NBA.
  table ? 0,
  # Rows shown before "show more"; 0 shows them all.
  collapseAfter ? 0,
  # HTML put before the table; the "open in FotMob" button.
  button ? "",
}:
let
  football = builtins.substring 0 7 league == "soccer/";
  stat = name: ''(.Int "stats.#(name==\"${name}\").value")'';
  statText = name: ''(.String "stats.#(name==\"${name}\").displayValue")'';
  entries = ''.JSON.Array "children.${toString table}.standings.entries"'';

  cell = width: content: ''<div class="shrink-0 text-right" style="width:${width}">${content}</div>'';

  columns =
    if football then
      {
        header = cell "2.5rem" "J" + cell "3.5rem" "Diff" + cell "3rem" "Pts";
        row =
          cell "2.5rem" "{{ ${stat "gamesPlayed"} }}"
          + cell "3.5rem" "{{ ${statText "pointDifferential"} }}"
          + cell "3rem" ''<span class="color-highlight">{{ ${stat "points"} }}</span>'';
      }
    else
      {
        header = cell "2.5rem" "V" + cell "2.5rem" "D" + cell "4rem" "%" + cell "3rem" "Écart";
        row =
          cell "2.5rem" "{{ ${stat "wins"} }}"
          + cell "2.5rem" "{{ ${stat "losses"} }}"
          + cell "4rem" ''<span class="color-highlight">{{ ${statText "winPercent"} }}</span>''
          + cell "3rem" "{{ ${statText "gamesBehind"} }}";
      };

  zone =
    if football then
      ''
        {{ $note := .String "note.description" }}
        {{ $zone := "" }}
        {{ if ne (findMatch "(?i)relegation|eliminated" $note) "" }}{{ $zone = "down" }}
        {{ else if ne (findMatch "(?i)^champions league$|round of 16" $note) "" }}{{ $zone = "top" }}
        {{ else if ne $note "" }}{{ $zone = "mid" }}
        {{ end }}
      ''
    else
      ''
        {{ $zone := "" }}
        {{ if le $rank 6 }}{{ $zone = "top" }}{{ else if le $rank 10 }}{{ $zone = "mid" }}{{ end }}
      '';

  listClass =
    if collapseAfter > 0 then
      ''collapsible-container" data-collapse-after="${toString collapseAfter}''
    else
      "";

  rank = if football then stat "rank" else stat "playoffSeed";
  sorted =
    if football then
      entries
    else
      ''sortByInt "stats.#(name==\"playoffSeed\").value" "asc" (${entries})'';
in
{
  type = "custom-api";
  inherit title;
  url = "https://site.api.espn.com/apis/v2/sports/${league}/standings";
  # Standings move once a match ends.
  cache = "1h";
  update-interval = "1h";
  template = ''
    ${button}
    {{ if ne .Response.StatusCode 200 }}
      <p class="color-negative">ESPN indisponible : {{ .Response.Status }}</p>
    {{ else }}
      <div class="flex items-center gap-10 size-h6 uppercase standings-row">
        <div class="shrink-0" style="width:2rem">#</div>
        <div class="grow">Équipe</div>
        ${columns.header}
      </div>
      <ul class="list list-gap-4 ${listClass}">
        {{ range ${sorted} }}
          {{ $rank := ${rank} }}
          ${zone}
          <li class="flex items-center gap-10 standings-row{{ if ne $zone "" }} standings-{{ $zone }}{{ end }}" title="{{ .String "note.description" }}">
            <div class="shrink-0" style="width:2rem">{{ $rank }}</div>
            <img class="shrink-0" src="{{ .String "team.logos.0.href" }}" alt="" style="width:1.6rem;height:1.6rem" loading="lazy">
            <div class="grow text-truncate color-highlight">{{ .String "team.shortDisplayName" }}</div>
            ${columns.row}
          </li>
        {{ end }}
      </ul>
    {{ end }}
  '';
}
