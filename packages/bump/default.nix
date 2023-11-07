{ nuenv, ... }:

nuenv.mkDerivation {
  name = "bump";
  src = ./bump.nu;
}
