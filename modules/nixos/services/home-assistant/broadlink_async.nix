# HA 2026.10's broadlink integration requires broadlink-async
# (github.com/DAB-LABS/broadlink-async, an asyncio fork of python-broadlink),
# which nixpkgs does not package yet: the integration failed with "No module
# named 'broadlink_async'", leaving the IR remote that drives the stove and the
# TV speakers unavailable (2026-10-21). Drop this once nixpkgs ships it. Built
# from the pure-Python wheel.
{
  lib,
  buildPythonPackage,
  fetchPypi,
  cryptography,
}:

buildPythonPackage rec {
  pname = "broadlink_async";
  version = "1.1.0";
  format = "wheel";

  src = fetchPypi {
    inherit pname version format;
    dist = "py3";
    python = "py3";
    hash = "sha256-4Th8VnnBmPIOfbLiCftO2cn1g3fh/1xA/3EV2g13fv8=";
  };

  dependencies = [ cryptography ];

  pythonImportsCheck = [ "broadlink_async" ];

  meta = {
    description = "Asyncio Python API for Broadlink IR/RF controllers and smart devices";
    homepage = "https://github.com/DAB-LABS/broadlink-async";
    license = lib.licenses.mit;
  };
}
