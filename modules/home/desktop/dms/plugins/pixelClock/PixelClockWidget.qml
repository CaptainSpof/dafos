pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Common
import qs.Modules.Plugins

// Pixel-style stacked clock: one glyph per digit on a 2x2 grid (hour over
// minute), neighbours overlapping so the digits interlock. The diagonal pair
// (H1, M2) sits in front in a pale tint; the other pair (H2, M1) sits behind in
// the primary colour, with a gap knocked out of it around the front digits so
// the wallpaper shows through where they cross.
//
// The font is Google Sans Flex, copied next to this file by ../../plugins.nix.
DesktopPluginComponent {
    id: root

    minWidth: 160
    minHeight: 180

    property bool is12Hour: (pluginData.timeFormat ?? "24") === "12"
    property real backgroundOpacity: (pluginData.backgroundOpacity ?? 45) / 100
    property real roundness: pluginData.roundness ?? 0
    property real weight: pluginData.weight ?? 900

    // Shape of the interlock, as fractions of the font size.
    readonly property real overlapX: 0.13
    readonly property real overlapY: 0.07
    readonly property real gap: 0.022
    // Inner margin, as a fraction of the shorter side.
    readonly property real padding: 0.13

    readonly property color backColor: Theme.primary
    readonly property color frontColor: Qt.rgba(
        Theme.primary.r * 0.2 + Theme.surfaceText.r * 0.8,
        Theme.primary.g * 0.2 + Theme.surfaceText.g * 0.8,
        Theme.primary.b * 0.2 + Theme.surfaceText.b * 0.8, 1)

    FontLoader {
        id: flex
        source: Qt.resolvedUrl("GoogleSansFlex.ttf")
    }

    readonly property font clockFont: Qt.font({
        family: flex.status === FontLoader.Ready ? flex.name : "sans-serif",
        pixelSize: 100,
        variableAxes: { "wght": root.weight, "ROND": root.roundness, "wdth": 100, "opsz": 144 }
    })

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property string digits: {
        if (!clock.date) return "0000";
        var h = clock.date.getHours();
        if (root.is12Hour) h = (h % 12) || 12;
        var m = clock.date.getMinutes();
        return (h < 10 ? "0" : "") + h + (m < 10 ? "0" : "") + m;
    }

    // Size everything off the "0" glyph measured at 100px, then scale.
    TextMetrics {
        id: ref
        font: root.clockFont
        text: "0"
    }
    readonly property real refW: ref.tightBoundingRect.width
    readonly property real refH: ref.tightBoundingRect.height
    readonly property real fontPx: {
        var availW = width * 1 - 2 * Math.min(width, height) * padding;
        var availH = height * 1 - 2 * Math.min(width, height) * padding;
        var blockW = 2 * refW - overlapX * 100;
        var blockH = 2 * refH - overlapY * 100;
        if (blockW <= 0 || blockH <= 0) return 0;
        return 100 * Math.min(availW / blockW, availH / blockH);
    }
    readonly property real capH: refH * fontPx / 100

    // Ink width of each slot's glyph at the current size.
    component SlotMetrics: TextMetrics {
        required property int slot
        font: Qt.font({ family: root.clockFont.family, pixelSize: Math.max(1, root.fontPx), variableAxes: root.clockFont.variableAxes })
        text: root.digits.charAt(slot)
    }
    SlotMetrics { id: m0; slot: 0 }
    SlotMetrics { id: m1; slot: 1 }
    SlotMetrics { id: m2; slot: 2 }
    SlotMetrics { id: m3; slot: 3 }
    function inkW(slot) {
        return [m0, m1, m2, m3][slot].tightBoundingRect.width;
    }

    Rectangle {
        anchors.fill: parent
        radius: Math.min(width, height) * 0.16
        color: Theme.surfaceContainer
        opacity: root.backgroundOpacity
    }

    // One digit, placed by its ink box rather than its line box.
    // col 0 ends its ink at the centre line (plus overlap); col 1 starts there.
    component Digit: Text {
        id: d
        required property int slot
        readonly property int col: slot % 2
        readonly property int row: slot < 2 ? 0 : 1

        text: root.digits.charAt(slot)
        font.family: root.clockFont.family
        font.pixelSize: root.fontPx
        font.variableAxes: root.clockFont.variableAxes
        renderType: Text.CurveRendering

        TextMetrics {
            id: ink
            font: d.font
            text: d.text
        }
        readonly property rect box: ink.tightBoundingRect

        // Each row is centred as a pair, so a narrow "1" doesn't skew it.
        readonly property real overlap: root.overlapX * root.fontPx
        readonly property real rowW: root.inkW(row * 2) + root.inkW(row * 2 + 1) - overlap
        x: (col === 0 ? (root.width - rowW) / 2 : (root.width + rowW) / 2 - box.width) - box.x
        // Baselines: row 0 sits a cap-height above centre, row 1 below it.
        readonly property real baseY: root.height / 2
            + (row === 0 ? -root.overlapY * root.fontPx / 2 : root.capH - root.overlapY * root.fontPx / 2)
        y: baseY - baselineOffset
    }

    // Back pair, with the gap cut out of it.
    Item {
        id: back
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskInverted: true
            maskSource: gapMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.2
        }

        Digit { slot: 1; color: root.backColor }
        Digit { slot: 2; color: root.backColor }
    }

    // Front digits dilated by `gap`: a ring of offset copies around each.
    Item {
        id: gapMask
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Repeater {
            model: 24
            Item {
                id: copy
                required property int index
                readonly property real a: index < 12 ? index * Math.PI / 6 : (index - 12) * Math.PI / 6 + Math.PI / 12
                readonly property real r: (index < 12 ? 1 : 0.6) * root.gap * root.fontPx
                anchors.fill: parent
                transform: Translate { x: copy.r * Math.cos(copy.a); y: copy.r * Math.sin(copy.a) }

                Digit { slot: 0; color: "white" }
                Digit { slot: 3; color: "white" }
            }
        }
    }

    Digit { slot: 0; color: root.frontColor }
    Digit { slot: 3; color: root.frontColor }
}
