import QtQuick
import qs.Common
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "pixelClock"

    SelectionSetting {
        settingKey: "timeFormat"
        label: "Time Format"
        options: [
            { label: "24-hour", value: "24" },
            { label: "12-hour", value: "12" }
        ]
        defaultValue: "24"
    }

    SelectionSetting {
        settingKey: "align"
        label: "Alignment"
        description: "Where the digits sit in the widget. Put the widget against a screen edge and align to that side to hug it."
        options: [
            { label: "Left", value: "left" },
            { label: "Center", value: "center" },
            { label: "Right", value: "right" }
        ]
        defaultValue: "center"
    }

    SliderSetting {
        settingKey: "margin"
        label: "Margin"
        description: "Space around the digits, as a share of the widget's shorter side."
        defaultValue: 13
        minimum: 0
        maximum: 30
        unit: "%"
    }

    SliderSetting {
        settingKey: "weight"
        label: "Weight"
        defaultValue: 900
        minimum: 400
        maximum: 1000
    }

    SliderSetting {
        settingKey: "roundness"
        label: "Roundness"
        description: "Google Sans Flex's ROND axis: sharp corners at 0, Pixel-soft at 100."
        defaultValue: 100
        minimum: 0
        maximum: 100
        unit: "%"
    }

    SliderSetting {
        settingKey: "backgroundOpacity"
        label: "Background Opacity"
        defaultValue: 45
        minimum: 0
        maximum: 100
        unit: "%"
    }
}
