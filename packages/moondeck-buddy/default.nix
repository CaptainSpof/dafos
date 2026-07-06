{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  procps,
  qt6Packages,
  ...
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "moondeck-buddy";
  version = "1.9.2";

  src = fetchFromGitHub {
    owner = "FrogTheFrog";
    repo = "moondeck-buddy";
    tag = "v${finalAttrs.version}";
    # resources/ssl submodule carries the TLS keys shared with the MoonDeck plugin.
    fetchSubmodules = true;
    hash = "sha256-GhZlmdI+oa5BjEzr9bkR2sY/nVpd1nuJlT2hYYv6zGU=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    qt6Packages.wrapQtAppsHook
  ];

  buildInputs = [
    procps # libproc2, used to track the Steam process
  ]
  ++ (with qt6Packages; [
    qtbase
    qthttpserver
    qtwebsockets
  ]);

  meta = with lib; {
    description = "Host-side companion for the MoonDeck Steam Deck plugin — monitors Steam and handles game launch/PC power requests";
    homepage = "https://github.com/FrogTheFrog/moondeck-buddy";
    changelog = "https://github.com/FrogTheFrog/moondeck-buddy/releases/tag/v${finalAttrs.version}";
    license = licenses.lgpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "MoonDeckBuddy";
  };
})
