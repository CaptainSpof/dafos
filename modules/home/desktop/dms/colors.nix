# Qt/KDE colour-scheme bodies, as matugen templates.
#
# These replace DMS's built-in `qt6ct` and `kcolorscheme` templates (see
# default.nix, which disables both). Everything here is matugen template source:
# `{{colors.<role>.<mode>.<component>}}` placeholders that matugen fills in on
# each theme change. `mode` is "default" (whatever mode is being rendered),
# "light" or "dark" — the forced variants exist because plasma-manager pins a
# scheme by name and DMS renders a Light/Dark pair next to the auto one.
#
# The rule the palette below follows, and the reason it exists:
#
#   A background a widget style may fill behind arbitrary text — selection,
#   hover, focus fills — must sit on the same lightness side as the surface.
#
# A style picks the foreground for such a fill from several roles, and not all
# of them are the scheme's "highlighted text": Qt's Inactive palette group (an
# unfocused panel, e.g. Dolphin's Places sidebar once the file view takes focus)
# draws with on_surface_variant, and Darkly fills a hovered row with
# DecorationHover while leaving the text alone. So every fill has to work under
# *all* of them, not just under its paired on-colour.
#
# Which roles may be used for a fill is not obvious: under `scheme-fidelity`
# (dafos's matugenScheme) `primary`, `primary_container` and `tertiary_container`
# do not flip with the mode — they stay faithful to the wallpaper's source colour
# and are near-white tints in dark mode. `secondary_container`,
# `surface_container*` and `inverse_primary` do flip. Only the latter belong in a
# fill; the former are fine as text or as a 1px focus outline.
{ lib }:
let
  # One role, as matugen placeholders.
  hex = mode: role: "{{colors.${role}.${mode}.hex}}";
  rgb =
    mode: role:
    lib.concatMapStringsSep "," (component: "{{colors.${role}.${mode}.${component}}}") [
      "red"
      "green"
      "blue"
    ];

  # One KConfig colour group. `hover` is what Breeze/Darkly fills a hovered item
  # with and `focus` what it outlines a focused one with, so both have to keep
  # `fg` — and the scheme's other foregrounds — readable.
  colorGroup =
    mode: name:
    {
      bg,
      bgAlt,
      fg,
      fgActive,
      hover ? "inverse_primary",
      focus ? "primary",
    }:
    ''
      [${name}]
      BackgroundAlternate=${rgb mode bgAlt}
      BackgroundNormal=${rgb mode bg}
      DecorationFocus=${rgb mode focus}
      DecorationHover=${rgb mode hover}
      ForegroundActive=${rgb mode fgActive}
      ForegroundInactive=${rgb mode "on_surface_variant"}
      ForegroundLink=${rgb mode "tertiary"}
      ForegroundNegative=${rgb mode "error"}
      ForegroundNeutral=${rgb mode "secondary"}
      ForegroundNormal=${rgb mode fg}
      ForegroundPositive=${rgb mode "tertiary"}
      ForegroundVisited=${rgb mode "secondary"}
    '';

  colorGroups =
    mode:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (colorGroup mode) {
        "Colors:Button" = {
          bg = "background";
          bgAlt = "surface";
          fg = "on_surface";
          fgActive = "primary";
        };
        "Colors:Complementary" = {
          bg = "background";
          bgAlt = "surface_container";
          fg = "on_surface";
          fgActive = "primary";
        };
        "Colors:Header" = {
          bg = "surface";
          bgAlt = "background";
          fg = "on_surface";
          fgActive = "primary";
        };
        "Colors:Header][Inactive" = {
          bg = "background";
          bgAlt = "surface";
          fg = "on_surface";
          fgActive = "primary";
        };
        # The group behind every selected item: Dolphin's Places sidebar, file
        # lists, tree views, KDE dialogs. `secondary_container` is the accent
        # tone that does follow the mode, so light text (on_surface,
        # on_surface_variant) and its own on-colour are all readable on it, and
        # `inverse_primary` hover shifts it without crossing to the other side.
        "Colors:Selection" = {
          bg = "secondary_container";
          bgAlt = "surface_variant";
          fg = "on_secondary_container";
          fgActive = "on_secondary_container";
        };
        "Colors:Tooltip" = {
          bg = "surface";
          bgAlt = "background";
          fg = "on_surface";
          fgActive = "primary";
        };
        "Colors:View" = {
          bg = "background";
          bgAlt = "surface_container_low";
          fg = "on_surface";
          fgActive = "primary";
        };
        "Colors:Window" = {
          bg = "background";
          bgAlt = "surface";
          fg = "on_surface";
          fgActive = "primary";
        };
      }
    );

  colorEffects = mode: ''
    [ColorEffects:Disabled]
    Color=${rgb mode "on_surface_variant"}
    ColorAmount=0
    ColorEffect=0
    ContrastAmount=0.65
    ContrastEffect=1
    IntensityAmount=0.1
    IntensityEffect=2

    [ColorEffects:Inactive]
    ChangeSelectionColor=true
    Color=${rgb mode "outline"}
    ColorAmount=0.025
    ColorEffect=2
    ContrastAmount=0.1
    ContrastEffect=2
    Enable=false
    IntensityAmount=0
    IntensityEffect=0
  '';

  # QPalette roles in the order qt6ct/qt5ct read them out of `*_colors`:
  # WindowText, Button, Light, Midlight, Dark, Mid, Text, BrightText, ButtonText,
  # Base, Window, Shadow, Highlight, HighlightedText, Link, LinkVisited,
  # AlternateBase, NoRole, ToolTipBase, ToolTipText, PlaceholderText.
  qtPalette = mode: roles: lib.concatMapStringsSep ", " (hex mode) roles;

  qtActiveRoles = [
    "on_surface"
    "surface"
    "surface_container"
    "outline"
    "surface_variant"
    "outline_variant"
    "on_surface"
    "on_surface"
    "on_surface"
    "background"
    "background"
    "shadow"
    # Highlight / HighlightedText: same pair as [Colors:Selection] above.
    "secondary_container"
    "on_secondary_container"
    "secondary"
    "secondary"
    "surface_container_low"
    "surface"
    "surface"
    "on_surface_variant"
    "on_surface_variant"
  ];

  # An unfocused panel keeps full-strength text: Qt hands this group to Dolphin's
  # Places sidebar as soon as the file view takes focus, so dimming it here is
  # what turns a hover fill behind it into unreadable text. kdeglobals does not
  # dim either ([ColorEffects:Inactive] is disabled above) — this matches it.
  qtInactiveRoles = [
    "on_surface"
    "surface"
    "surface_container"
    "outline"
    "surface_variant"
    "outline_variant"
    "on_surface"
    "on_surface"
    "on_surface"
    "surface"
    "surface"
    "shadow"
    # A selection in an unfocused panel: dimmer than the active one, still on the
    # surface's side of the palette. This is the pair Dolphin's Places sidebar
    # actually renders with most of the time.
    "surface_container_highest"
    "on_surface"
    "secondary"
    "secondary"
    "surface_container_low"
    "surface"
    "surface"
    "on_surface_variant"
    "on_surface_variant"
  ];

  qtDisabledRoles = [
    "on_surface_variant"
    "surface_variant"
    "surface_container"
    "outline"
    "surface_variant"
    "outline_variant"
    "on_surface_variant"
    "on_surface_variant"
    "on_surface_variant"
    "surface_variant"
    "surface_variant"
    "shadow"
    "surface_variant"
    "on_surface_variant"
    "on_surface_variant"
    "on_surface_variant"
    "surface_variant"
    "surface_variant"
    "surface_variant"
    "on_surface_variant"
    "on_surface_variant"
  ];
in
{
  # qt6ct's custom palette. This is the file Qt apps under niri actually theme
  # from (qt6ct.conf points color_scheme_path at it); Darkly reads the
  # [Colors:*] groups below it for decoration colours.
  qtctColors = mode: ''
    [ColorScheme]
    active_colors=${qtPalette mode qtActiveRoles}
    disabled_colors=${qtPalette mode qtDisabledRoles}
    inactive_colors=${qtPalette mode qtInactiveRoles}

    ${colorEffects mode}
    ${colorGroups mode}
  '';

  # KDE colour scheme (kdeglobals, via plasma-apply-colorscheme). Keeps DMS's
  # scheme name so nothing downstream has to be rewired.
  kdeColorScheme = mode: ''
    [KDE]
    contrast=4

    [General]
    ColorScheme=DankMatugen
    Name=Dank Shell (matugen)

    ${colorEffects mode}
    ${colorGroups mode}
    [WM]
    activeBackground=${rgb mode "surface"}
    activeBlend=${rgb mode "on_surface"}
    activeForeground=${rgb mode "on_surface"}
    inactiveBackground=${rgb mode "background"}
    inactiveBlend=${rgb mode "on_surface_variant"}
    inactiveForeground=${rgb mode "on_surface_variant"}
  '';
}
