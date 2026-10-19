{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation {
  name = "leaf-kde";

  src = fetchFromGitHub {
    owner = "qewer33";
    repo = "leaf-kde";
    rev = "8308d1583dcebca666938d9ea9668d73e48d265c";
    sha256 = "sha256-5KY9JmIfwqWd/i2EW4su4v/f7PO/dFyu097Pxn6liWA=";
  };

  # TODO: install with repo's ruby script
  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/desktoptheme
    cp -R color-schemes desktoptheme konsole look-and-feel $out/share

    runHook postInstall
  '';

  meta = {
    description = "A forest green dark & light theme for the KDE Plasma desktop";
    homepage = "https://github.com/qewer33/leaf-kde";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.linux;
  };
}
