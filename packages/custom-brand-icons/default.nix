{
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation rec {
  pname = "custom-brand-icons";
  version = "2024.11.1";

  src = fetchFromGitHub {
    owner = "elax46";
    repo = "custom-brand-icons";
    rev = "refs/tags/${version}";
    hash = "sha256-VZpKSnp901IKLuCK92cjBfyuKp6X9wnb3wOToDLiWQs=";
  };

  dontBuild = true;

  installPhase = ''

    mkdir $out
    cp -v dist/custom-brand-icons.js $out/

  '';

  passthru.entrypoint = "custom-brand-icons.js";

  meta = {
    description = "Custom brand icons for Home Assistant";
    homepage = "https://github.com/";
  };
}
