# A custom-api widget listing the next RER departures at one stop, from
# PRIM's real-time "prochains passages" (SIRI Lite stop-monitoring).
#
# SIRI's DirectionRef is "Retour" for every RER A train at Nanterre-Ville, so
# the direction is picked by destination instead: `excludeDestinations` drops
# the termini on the other side. The quay would also tell them apart, but it
# moves during works.
{
  title,
  stopArea,
  excludeDestinations,
  limit ? 6,
  # HTML put before the list; the "open in Citymapper" button.
  button ? "",
}:
let
  call = "MonitoredVehicleJourney.MonitoredCall";
  exclude = builtins.concatStringsSep "|" excludeDestinations;
in
{
  type = "custom-api";
  inherit title;
  url = "https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring";
  parameters.MonitoringRef = "STIF:StopArea:SP:${toString stopArea}:";
  headers.apikey = "\${PRIM_API_KEY}";
  cache = "1m";
  update-interval = "1m";
  template = ''
    ${button}
    {{ if ne .Response.StatusCode 200 }}
      <p class="color-negative">PRIM indisponible : {{ .Response.Status }}</p>
    {{ else }}
    {{ $visits := .JSON.Array "Siri.ServiceDelivery.StopMonitoringDelivery.0.MonitoredStopVisit" }}
    {{ $n := 0 }}
    <ul class="list list-gap-10">
      {{ range sortByTime "${call}.ExpectedDepartureTime" "rfc3339" "asc" $visits }}
        {{ $dest := .String "MonitoredVehicleJourney.DestinationName.0.value" }}
        {{ $expected := .String "${call}.ExpectedDepartureTime" | parseTime "rfc3339" }}
        {{ $aimed := .String "${call}.AimedDepartureTime" | parseTime "rfc3339" }}
        {{ $in := toInt ($expected.Sub now).Minutes }}
        {{ if and (lt $n ${toString limit}) (ge $in 0) (eq (findMatch "^(${exclude})$" $dest) "") }}
          {{ $n = add $n 1 }}
          {{ $late := toInt ($expected.Sub $aimed).Minutes }}
          {{ $cancelled := eq (.String "${call}.DepartureStatus") "cancelled" }}
          <li class="flex items-center gap-10">
            <div class="shrink-0 color-highlight" style="min-width:3.2rem">{{ $expected.Local.Format "15:04" }}</div>
            <div class="grow min-width-0">
              <div class="text-truncate color-highlight">{{ $dest }}</div>
              <div class="size-h6 text-truncate">
                {{ .String "MonitoredVehicleJourney.JourneyNote.0.value" }} · quai {{ .String "${call}.DeparturePlatformName.value" }}
                {{ if gt $late 0 }}<span class="color-negative"> · +{{ $late }} min</span>{{ end }}
              </div>
            </div>
            <div class="shrink-0 text-right {{ if $cancelled }}color-negative{{ else }}color-highlight size-h3{{ end }}">
              {{ if $cancelled }}Supprimé{{ else if eq $in 0 }}à quai{{ else }}{{ $in }} min{{ end }}
            </div>
          </li>
        {{ end }}
      {{ end }}
    </ul>
    {{ if eq $n 0 }}<p>Aucun départ annoncé.</p>{{ end }}
    {{ end }}
  '';
}
