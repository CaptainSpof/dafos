{
  writeShellApplication,
  grim,
  slurp,
  wl-clipboard,
  libnotify,
  coreutils,
  gnused,
  tesseract,
}:
# Region select -> OCR (French + English) -> text to the clipboard. The capture
# is upscaled x3: it fixes accents on small UI text. Cancelling the selection is
# silent and leaves the clipboard alone, as does an empty result.
writeShellApplication {
  name = "screenshot-ocr";
  runtimeInputs = [
    grim
    slurp
    wl-clipboard
    libnotify
    coreutils
    gnused
    (tesseract.override {
      enableLanguages = [
        "fra"
        "eng"
      ];
    })
  ];
  text = ''
    # niri may spawn us with no UTF-8 locale; the preview must count characters.
    export LC_ALL=C.UTF-8
    region=$(slurp) || exit 0
    text=$(grim -s 3 -g "$region" - | tesseract stdin stdout -l fra+eng 2>/dev/null | tr -d '\f' | sed -e 's/[[:space:]]*$//' || true)
    if [ -z "$text" ]; then
      notify-send -a screenshot-ocr "OCR" "Aucun texte reconnu"
      exit 0
    fi
    printf '%s' "$text" | wl-copy
    notify-send -a screenshot-ocr "Texte copié" "''${text:0:200}"
  '';
}
