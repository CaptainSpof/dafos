{
  lib,
  fetchFromGitHub,
  buildHomeAssistantComponent,
  pkgs,
}:

let
  pythonWithBluetooth = pkgs.python.overrideAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.bluez.dev ];
    configureFlags = (old.configureFlags or [ ]) ++ [ "--enable-bluez" ];
    extraMakeFlags = (old.extraMakeFlags or [ ]) ++ [
      "CFLAGS=-I${pkgs.bluez.dev}/include"
      "LDFLAGS=-L${pkgs.bluez.dev}/lib"
    ];
  });

  # Add required Python packages
  pythonEnv = pythonWithBluetooth.withPackages (
    ps: with ps; [
      btsocket
      # Add other Python dependencies here if needed
    ]
  );
in

buildHomeAssistantComponent {
  owner = "d03n3rfr1tz3";
  domain = "hass-divoom";
  version = "1.1.3";

  src = fetchFromGitHub {
    owner = "d03n3rfr1tz3";
    repo = "hass-divoom";
    rev = "7a49f32c833aaa852f02d22bc7faf0277a5f5639";
    hash = "sha256-AFdICIbwLIB9tvEeaRYt8dzll54fWToZVuhYHwJPUws=";
  };

  propagatedBuildInputs = [ pythonEnv ];

  # Skip phases with nothing to do
  dontConfigure = true;
  dontBuild = true;
  doCheck = false;

  meta = with lib; {
    description = "Divoom Home Assistant integration";
    homepage = "https://github.com/d03n3rfr1tz3/hass-divoom";
    license = licenses.mit;
    maintainers = with lib.maintainers; [ "d03n3rfr1tz3" ];
    changelog = "https://github.com/d03n3rfr1tz3/hass-divoom/releases";
  };
}
