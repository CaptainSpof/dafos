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
  version = "1.10.0";

  src = fetchFromGitHub {
    owner = "FrogTheFrog";
    repo = "moondeck-buddy";
    tag = "v${finalAttrs.version}";
    # resources/ssl submodule carries the TLS keys shared with the MoonDeck plugin.
    fetchSubmodules = true;
    hash = "sha256-kuU6bE/I3oyLUq2qFvMOzrqu5DceqxDDwP34iTLpIgI=";
  };

  # src/lib/json pulls glaze through FetchContent (git clone at configure time,
  # which the sandbox forbids). Hand it the exact tag upstream pins — nixpkgs'
  # glaze is a newer major.
  glaze = fetchFromGitHub {
    owner = "stephenberry";
    repo = "glaze";
    tag = "v7.7.1";
    hash = "sha256-CfN2mv1s+yv2HvRLBZhHUHBNfsgRzTT7USNYkkahh8M=";
  };

  cmakeFlags = [
    (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_GLAZE" "${finalAttrs.glaze}")
  ];

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
