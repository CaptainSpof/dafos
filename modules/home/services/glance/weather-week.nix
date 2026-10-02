# A custom-api widget with the week's forecast, one row per day. Dynacat's
# own weather widget only shows today, hour by hour. Same source as that
# widget (Open-Meteo, no key), with WMO weather codes mapped to French
# labels and monochrome MDI icons.
{
  title,
  latitude,
  longitude,
  days ? 7,
}:
let
  mdi = name: "https://cdn.jsdelivr.net/npm/@mdi/svg@latest/svg/weather-${name}.svg";
in
{
  type = "custom-api";
  inherit title;
  url = "https://api.open-meteo.com/v1/forecast";
  parameters = {
    latitude = toString latitude;
    longitude = toString longitude;
    daily = "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max";
    timezone = "Europe/Paris";
    forecast_days = toString days;
  };
  cache = "1h";
  update-interval = "1h";
  template = ''
    {{ $root := . }}
    <ul class="list list-gap-10">
      {{ range $i, $d := .JSON.Array "daily.time" }}
        {{ $code := $root.JSON.Int (printf "daily.weather_code.%d" $i) }}
        {{ $icon := "${mdi "sunny"}" }}{{ $label := "Ensoleillé" }}
        {{ if ge $code 95 }}{{ $icon = "${mdi "lightning-rainy"}" }}{{ $label = "Orage" }}
        {{ else if ge $code 85 }}{{ $icon = "${mdi "snowy-heavy"}" }}{{ $label = "Averses de neige" }}
        {{ else if ge $code 80 }}{{ $icon = "${mdi "pouring"}" }}{{ $label = "Averses" }}
        {{ else if ge $code 71 }}{{ $icon = "${mdi "snowy"}" }}{{ $label = "Neige" }}
        {{ else if ge $code 61 }}{{ $icon = "${mdi "rainy"}" }}{{ $label = "Pluie" }}
        {{ else if ge $code 51 }}{{ $icon = "${mdi "rainy"}" }}{{ $label = "Bruine" }}
        {{ else if ge $code 45 }}{{ $icon = "${mdi "fog"}" }}{{ $label = "Brouillard" }}
        {{ else if eq $code 3 }}{{ $icon = "${mdi "cloudy"}" }}{{ $label = "Couvert" }}
        {{ else if ge $code 1 }}{{ $icon = "${mdi "partly-cloudy"}" }}{{ $label = "Éclaircies" }}
        {{ end }}
        {{ $date := $root.JSON.String (printf "daily.time.%d" $i) | parseTime "dateonly" }}
        {{ $rain := $root.JSON.Int (printf "daily.precipitation_probability_max.%d" $i) }}
        <li class="flex items-center gap-10">
          <div class="shrink-0" style="min-width:4.2rem">
            <div class="color-highlight">{{ if eq $i 0 }}Auj.{{ else }}{{ $date.Format "Mon" | replaceAll "Mon" "Lun." | replaceAll "Tue" "Mar." | replaceAll "Wed" "Mer." | replaceAll "Thu" "Jeu." | replaceAll "Fri" "Ven." | replaceAll "Sat" "Sam." | replaceAll "Sun" "Dim." }}{{ end }}</div>
            <div class="size-h6">{{ $date.Format "02/01" }}</div>
          </div>
          <img class="flat-icon shrink-0" src="{{ $icon }}" alt="" title="{{ $label }}" style="width:2.2rem;height:2.2rem" loading="lazy">
          <div class="grow min-width-0">
            <div class="text-truncate">{{ $label }}</div>
            {{ if ge $rain 20 }}<div class="size-h6 color-primary">{{ $rain }} % de pluie</div>{{ end }}
          </div>
          <div class="shrink-0 text-right">
            <span class="color-highlight">{{ $root.JSON.Float (printf "daily.temperature_2m_max.%d" $i) | toInt }}°</span>
            <span class="size-h6"> / {{ $root.JSON.Float (printf "daily.temperature_2m_min.%d" $i) | toInt }}°</span>
          </div>
        </li>
      {{ end }}
    </ul>
  '';
}
