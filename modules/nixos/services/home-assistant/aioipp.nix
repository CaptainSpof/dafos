# HA 2026.10's ipp integration requires aioipp (github.com/brianegge/aioipp,
# the maintained fork of pyipp, still imported as `pyipp`), which nixpkgs does
# not package yet: component-packages.nix lists "missing inputs: aioipp", and
# the integration failed with "No module named 'pyipp'". Drop this once
# nixpkgs ships it. Built from the pure-Python wheel.
{
  lib,
  buildPythonPackage,
  fetchPypi,
  aiohttp,
  awesomeversion,
  deepmerge,
  yarl,
}:

buildPythonPackage rec {
  pname = "aioipp";
  version = "0.19.3";
  format = "wheel";

  src = fetchPypi {
    inherit pname version format;
    dist = "py3";
    python = "py3";
    hash = "sha256-xJtPkXIZFeFNY9KWqzt7LGw1Kdhf4LgCK1juU5aT59E=";
  };

  dependencies = [
    aiohttp
    awesomeversion
    deepmerge
    yarl
  ];

  pythonImportsCheck = [ "pyipp" ];

  meta = {
    description = "Asynchronous Python client for Internet Printing Protocol (IPP)";
    homepage = "https://github.com/brianegge/aioipp";
    license = lib.licenses.mit;
  };
}
