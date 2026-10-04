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
