{
  lib,
  stdenvNoCC,
  pkgs,
  ...
}:

let
  # Get list of files/folders in ./wallpapers
  images = builtins.attrNames (builtins.readDir ./wallpapers);

  # Helper to create individual wallpaper derivations (kept from your original code)
  mkWallpaper =
    name: src:
    stdenvNoCC.mkDerivation {
      inherit name src;
      dontUnpack = true;
      # Copy the source directly to $out.
      # If src is a file, $out is that file. If src is a dir, $out is that dir.
      installPhase = ''
        cp -r $src $out
      '';
      passthru = {
        fileName = builtins.baseNameOf src;
      };
    };

  # Helper to get clean names (e.g. "mywallpaper")
  getCleanName = lib.snowfall.path.get-file-name-without-extension;
  names = builtins.map getCleanName images;

  # Create the set of individual wallpaper derivations
  wallpapers = lib.foldl (
    acc: image:
    let
      name = getCleanName image;
    in
    acc // { "${name}" = mkWallpaper name (./wallpapers + "/${image}"); }
  ) { } images;

  installTarget = "$out/share/wallpapers";

  # --- NEW: Create a separate derivation just for the flattened version ---
  # This uses the list of individual wallpaper packages we created above.
  flattened = pkgs.runCommand "wallpapers-flattened" { } ''
    mkdir -p $out

    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: drv: ''
        # Case 1: The wallpaper derivation is a directory (it contains the image inside)
        if [ -d "${drv}" ]; then
          find "${drv}" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.webp" \) -exec ln -s {} $out/ \;
          
        # Case 2: The wallpaper derivation IS the image file itself
        elif [ -f "${drv}" ]; then
          # USE THIS: drv.fileName preserves the extension (e.g. "image.jpg")
          ln -s "${drv}" "$out/${drv.fileName}"
        fi
      '') wallpapers
    )}
  '';
in
stdenvNoCC.mkDerivation {
  name = "dafos.wallpapers";
  src = ./wallpapers;

  installPhase = ''
    mkdir -p ${installTarget}
    # Copy files from the src directory to the output
    find . -maxdepth 1 -type f -exec cp {} ${installTarget}/ \;
  '';

  passthru = {
    inherit names flattened;
  }
  // wallpapers;
}
