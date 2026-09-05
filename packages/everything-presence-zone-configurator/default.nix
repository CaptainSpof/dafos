{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  nodejs,
}:

# The "Zone Configurator" from Everything Smart Home: a browser UI that draws
# rooms, detection zones and live mmWave targets for Everything Presence
# Lite/One/Pro sensors, talking to Home Assistant over its REST/WebSocket API.
#
# Upstream ships it as a Home Assistant add-on (Supervisor) or a Docker image;
# neither is usable on a NixOS host running home-assistant natively, so this
# builds the npm workspace (express/TypeScript backend + React frontend) the
# same way the `standalone` stage of upstream's Dockerfile does:
#   npm ci --include=dev && npm run build --workspaces && npm prune --omit=dev
#
# The backend locates its device profiles and its version string relative to
# the *working directory* (backend/src/index.ts, backend/src/routes/meta.ts), so
# the wrapper chdirs into the installed app root. `backend/config` is symlinked
# as a belt-and-braces second candidate path.
buildNpmPackage rec {
  pname = "everything-presence-zone-configurator";
  version = "2.2.4";

  src = fetchFromGitHub {
    owner = "EverythingSmartHome";
    repo = "everything-presence-addons";
    rev = "refs/tags/v${version}";
    hash = "sha256-V5Bl8h+YtxcPyQApNzWTqPt44LsWpmyYPpu/a17u59o=";
  };

  sourceRoot = "${src.name}/everything-presence-mmwave-configurator";

  npmDepsHash = "sha256-deIP71crJU4hfZd85qkWEXyWy89wibdXuobh1iNzmGY=";

  nativeBuildInputs = [ makeWrapper ];

  # The default install hook runs `npm pack`, which is meaningless for a private
  # workspace root with no `files`; prune and copy by hand instead.
  dontNpmPrune = true;

  installPhase = ''
    runHook preInstall

    npm prune --omit=dev --workspaces --no-audit --no-fund

    app=$out/lib/${pname}
    mkdir -p $app/backend $app/frontend

    # -a keeps the workspace symlinks inside node_modules relative and intact.
    cp -a package.json package-lock.json config.yaml config node_modules $app/
    cp -a backend/package.json backend/dist $app/backend/
    if [ -d backend/node_modules ]; then
      cp -a backend/node_modules $app/backend/
    fi
    cp -a frontend/dist $app/frontend/
    ln -s ../config $app/backend/config

    makeWrapper ${lib.getExe nodejs} $out/bin/${pname} \
      --add-flags $app/backend/dist/index.js \
      --chdir $app \
      --set-default NODE_ENV production \
      --set-default FRONTEND_DIST $app/frontend/dist

    runHook postInstall
  '';

  passthru.appDir = "lib/${pname}";

  meta = {
    description = "Visual zone configurator for Everything Presence mmWave sensors in Home Assistant";
    homepage = "https://github.com/EverythingSmartHome/everything-presence-addons";
    # Upstream ships no LICENSE file and GitHub reports no license for the repo.
    mainProgram = pname;
    platforms = lib.platforms.linux;
  };
}
