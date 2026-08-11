{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  wrapGAppsHook4,
  gtk4,
  glib,
  gst_all_1,
  webkitgtk_6_0,
  wayland,
  xorg,
  openxr-loader,
  libglvnd,
  ...
}:

stdenv.mkDerivation rec {
  pname = "sisr";
  version = "0.6.0";

  src = fetchurl {
    url = "https://github.com/Alia5/SISR/releases/download/v${version}/SISR-linux_x64-Release.tar.gz";
    hash = "sha256-N9e8VQ0RJqxZ4fxI1+DVOC5ykjSdMV8LSVpVLYY45/U=";
  };

  icon = fetchurl {
    url = "https://raw.githubusercontent.com/Alia5/SISR/v${version}/docs/SISR.svg";
    hash = "sha256-aKqSMrfyjg0zsWk9IjnM29oau66HbP1DmReixXlo5mE=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook4
  ];

  buildInputs = [
    gtk4
    glib
    # WebKitGTK's media backend needs GStreamer elements (appsink lives in
    # gst-plugins-base); wrapGAppsHook4 only exposes plugins listed here.
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    webkitgtk_6_0
    wayland
    xorg.libX11
    xorg.libXext
    xorg.libXtst
    xorg.libXScrnSaver
    openxr-loader
    stdenv.cc.cc.lib
  ];

  # Optional dlopen'd deps of the bundled SDL3: libsteam_api only exists inside
  # Steam-linked apps, libGLES_CM is legacy OpenGL ES 1.1 — SDL copes without both.
  autoPatchelfIgnoreMissingDeps = [
    "libsteam_api.so"
    "libGLES_CM.so.1"
  ];

  dontConfigure = true;
  dontBuild = true;

  # No desktop item here: SISR persists state (its "initial setup done" marker,
  # the Steam-shortcut path it registers itself under) next to its own
  # executable, which is read-only in the store. The consuming NixOS module
  # launches SISR through a stable wrapper in $HOME instead and owns the
  # desktop entry for that reason.
  installPhase = ''
    runHook preInstall

    install -Dm755 SISR $out/bin/SISR
    # Upstream bundles its own SDL3 build; ship it rather than nixpkgs' sdl3.
    install -Dm755 libSDL3.so.0.5.0 $out/lib/libSDL3.so.0.5.0
    ln -s libSDL3.so.0.5.0 $out/lib/libSDL3.so.0
    ln -s libSDL3.so.0.5.0 $out/lib/libSDL3.so

    install -Dm644 $icon $out/share/icons/hicolor/scalable/apps/sisr.svg

    runHook postInstall
  '';

  # autoPatchelfHook resolves libSDL3.so.0 against $out/lib.
  appendRunpaths = [ "${placeholder "out"}/lib" ];

  # SISR dlopens Steam's own gameoverlayrenderer.so at runtime to register
  # itself with Steam (so Steam Input actually routes the controller to it,
  # outside of a Steam launch). That foreign library needs libGL.so.1, which
  # on NixOS lives in libglvnd — not on any default search path for a plain
  # binary. Add libglvnd plus the runtime GPU driver dir so the dlopen and the
  # GL calls behind it resolve against the driver matching the running kernel.
  # dlopen'd deps use LD_LIBRARY_PATH, not the executable's RUNPATH, hence the
  # wrapper env rather than appendRunpaths.
  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libglvnd ]}:/run/opengl-driver/lib"
    )
  '';

  meta = with lib; {
    description = "Steam Input System Redirector — use Steam Input configurations system-wide, outside of Steam games";
    homepage = "https://github.com/Alia5/SISR";
    changelog = "https://github.com/Alia5/SISR/releases/tag/v${version}";
    license = licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "SISR";
  };
}
