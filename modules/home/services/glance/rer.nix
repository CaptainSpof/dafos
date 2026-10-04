# A custom-api widget listing the next RER departures at one stop, from
# PRIM's real-time "prochains passages" (SIRI Lite stop-monitoring).
#
# SIRI's DirectionRef is "Retour" for every RER A train at Nanterre-Ville, so
# the direction is picked by destination instead: `excludeDestinations` drops
# the termini on the other side. The quay would also tell them apart, but it
# moves during works.
#
# PRIM allows 1000 requests a day per token, and Dynacat's per-widget polling
# (`update-interval`) bypasses the cache: every visible tab refetches on its
# own. So the data is refetched rarely (`refreshEvery`), and the countdown,
# stripe and "pars dans" hint are recomputed in the browser every 15 s by
# rer-ticker.js from each row's `data-rer-departure`. The server render
# carries the same state, so the widget still reads right without the
# script. A ⟳ button forces a refetch.
{
  title,
  stopArea,
  excludeDestinations,
  limit ? 6,
  # Departures rendered past `limit`, hidden until earlier ones leave. The
  # data can be `refreshEvery` old, and a few trains leave in that time.
  spare ? 4,
  refreshEvery ? "15m",
  # HTML put in the header; the "open in Citymapper" button.
  button ? "",
  # Minutes from home to the platform. Each row gets a state class, drawn
  # as a coloured stripe by `.rer-*` in the module's userCss: `ok` when
  # there is time to spare (leave in `margin` minutes or more), `hurry`
  # when leaving right now still makes it, `missed` when even the fastest
  # walk is too slow. Classes, not inline styles: html/template replaces a
  # templated CSS value with "ZgotmplZ".
  walk ? {
    min = 7;
    max = 8;
  },
  margin ? 3,
}:
let
  call = "MonitoredVehicleJourney.MonitoredCall";
  exclude = builtins.concatStringsSep "|" excludeDestinations;
  refreshIcon = "https://cdn.jsdelivr.net/npm/@mdi/svg@latest/svg/refresh.svg";
in
{
  type = "custom-api";
  inherit title;
  url = "https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring";
  parameters.MonitoringRef = "STIF:StopArea:SP:${toString stopArea}:";
  headers.apikey = "\${PRIM_API_KEY}";
  cache = refreshEvery;
  update-interval = refreshEvery;
  template = ''
    <div class="widget-link-button-group">
      <button type="button" class="inline-link-button rer-refresh" title="Rafraîchir les horaires"
        onclick="const b = this; b.classList.add('is-loading'); dynacatRefreshWidget(b.closest('.widget').dataset.widgetId).finally(() => { b.classList.remove('is-loading'); window.dafosRerTick && window.dafosRerTick(); })">
        <img class="flat-icon" src="${refreshIcon}" alt="Rafraîchir">
      </button>
      ${button}
    </div>
    {{ if eq .Response.StatusCode 429 }}
      <p class="color-negative">Quota PRIM du jour atteint (1000 requêtes). Les horaires reviennent demain.</p>
    {{ else if ne .Response.StatusCode 200 }}
      <p class="color-negative">PRIM indisponible : {{ .Response.Status }}</p>
    {{ else }}
    {{ $visits := .JSON.Array "Siri.ServiceDelivery.StopMonitoringDelivery.0.MonitoredStopVisit" }}
    {{ $n := 0 }}
    <ul class="list list-gap-10 rer-list" data-walk-min="${toString walk.min}" data-walk-max="${toString walk.max}" data-margin="${toString margin}" data-limit="${toString limit}">
      {{ range sortByTime "${call}.ExpectedDepartureTime" "rfc3339" "asc" $visits }}
        {{ $dest := .String "MonitoredVehicleJourney.DestinationName.0.value" }}
        {{ $expected := .String "${call}.ExpectedDepartureTime" | parseTime "rfc3339" }}
        {{ $aimed := .String "${call}.AimedDepartureTime" | parseTime "rfc3339" }}
        {{ $in := toInt ($expected.Sub now).Minutes }}
        {{ if and (lt $n ${toString (limit + spare)}) (ge $in 0) (eq (findMatch "^(${exclude})$" $dest) "") }}
          {{ $late := toInt ($expected.Sub $aimed).Minutes }}
          {{ $cancelled := eq (.String "${call}.DepartureStatus") "cancelled" }}
          {{ $leave := sub $in ${toString walk.max} }}
          {{ $state := "ok" }}
          {{ if $cancelled }}{{ $state = "cancelled" }}
          {{ else if lt $in ${toString walk.min} }}{{ $state = "missed" }}
          {{ else if lt $leave ${toString margin} }}{{ $state = "hurry" }}
          {{ end }}
          <li class="flex items-center gap-10 rer-row rer-{{ $state }}{{ if ge $n ${toString limit} }} rer-extra{{ end }}" data-rer-departure="{{ $expected.Unix }}" data-rer-cancelled="{{ $cancelled }}">
            <div class="shrink-0 color-highlight" style="min-width:3.2rem">{{ $expected.Local.Format "15:04" }}</div>
            <div class="grow min-width-0">
              <div class="text-truncate color-highlight">{{ $dest }}</div>
              <div class="size-h6 text-truncate">
                {{ .String "MonitoredVehicleJourney.JourneyNote.0.value" }} · quai {{ .String "${call}.DeparturePlatformName.value" }}
                {{ if gt $late 0 }}<span class="color-negative"> · +{{ $late }} min</span>{{ end }}
              </div>
            </div>
            <div class="shrink-0 text-right">
              <div class="{{ if $cancelled }}color-negative{{ else }}color-highlight size-h3 rer-min{{ end }}">
                {{ if $cancelled }}Supprimé{{ else if eq $in 0 }}à quai{{ else }}{{ $in }} min{{ end }}
              </div>
              {{ if not $cancelled }}
                <div class="size-h6 rer-status">
                  {{ if lt $in ${toString walk.min} }}trop tard{{ else if lt $leave ${toString margin} }}pars maintenant{{ else }}pars dans {{ $leave }} min{{ end }}
                </div>
              {{ end }}
            </div>
          </li>
          {{ $n = add $n 1 }}
        {{ end }}
      {{ end }}
    </ul>
    <p class="rer-empty"{{ if gt $n 0 }} hidden{{ end }}>Aucun départ annoncé.</p>
    <div class="size-h6 margin-top-10 rer-age" data-fetched="{{ now.Unix }}">maj {{ now.Local.Format "15:04" }}</div>
    {{ end }}
  '';
}
