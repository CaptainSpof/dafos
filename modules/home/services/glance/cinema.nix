# A custom-api widget with the films now showing in French cinemas, as a
# strip of posters. Source: TMDB `movie/now_playing` (region FR, French
# titles). TMDB wants a token: the « Jeton d'accès en lecture à l'API » (v4)
# of a free account, sent as a bearer header and kept in sops (`tmdb/token`).
{
  title,
  limit ? 10,
}:
{
  type = "custom-api";
  inherit title;
  url = "https://api.themoviedb.org/3/movie/now_playing";
  parameters = {
    region = "FR";
    language = "fr-FR";
    page = "1";
  };
  headers.Authorization = "Bearer \${TMDB_TOKEN}";
  # The list moves weekly (Wednesday releases).
  cache = "6h";
  update-interval = "6h";
  template = ''
    <ul class="cinema-strip">
      {{ range $i, $f := .JSON.Array "results" }}
        {{ if lt $i ${toString limit} }}
          <li class="cinema-film">
            <a class="cinema-link" href="https://www.themoviedb.org/movie/{{ $f.Int "id" }}?language=fr-FR" target="_blank" rel="noreferrer" title="{{ $f.String "title" }}">
              {{ if $f.String "poster_path" }}
                <img class="cinema-poster" src="https://image.tmdb.org/t/p/w342{{ $f.String "poster_path" }}" alt="" loading="lazy">
              {{ else }}
                <div class="cinema-poster"></div>
              {{ end }}
              <div class="cinema-title color-highlight text-truncate">{{ $f.String "title" }}</div>
              <div class="size-h6">
                {{ if $f.String "release_date" }}{{ ($f.String "release_date" | parseTime "dateonly").Format "02/01/2006" }}{{ end }}
              </div>
            </a>
          </li>
        {{ end }}
      {{ end }}
    </ul>
  '';
}
