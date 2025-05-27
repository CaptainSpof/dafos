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
    rev = "cea63298cfe1a0d3163ca7a58fc51d6bb3a15331";
    sha256 = "sha256-/0fxxr3ACczJ6/vC7tYLe+Je7z6X4Q4ukYln5sOigu8";
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
