import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "proofreader"

    StringSetting {
        settingKey: "languageToolUrl"
        label: "URL LanguageTool"
        description: "Laisser vide pour utiliser la valeur fournie par Nix (dafos.desktop.dms.proofreader.languageToolUrl)."
        placeholder: "http://127.0.0.1:8081"
    }

    ToggleSetting {
        settingKey: "autoCheck"
        label: "Vérification automatique"
        description: "Vérifier le texte pendant la frappe, après une courte pause. Sinon : bouton ou Ctrl+Entrée."
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "picky"
        label: "Mode exigeant"
        description: "Active les règles de style et de typographie supplémentaires de LanguageTool (level=picky)."
        defaultValue: false
    }

    SelectionSetting {
        settingKey: "motherTongue"
        label: "Langue maternelle"
        description: "Permet à LanguageTool de signaler les faux amis quand vous écrivez dans une autre langue."
        options: [
            {
                label: "Aucune",
                value: ""
            },
            {
                label: "Français",
                value: "fr"
            },
            {
                label: "English",
                value: "en-US"
            },
            {
                label: "Deutsch",
                value: "de-DE"
            },
            {
                label: "Español",
                value: "es"
            }
        ]
        defaultValue: "fr"
    }

    SelectionSetting {
        settingKey: "englishVariant"
        label: "Variante d'anglais"
        description: "Variante retenue quand la langue est détectée automatiquement."
        options: [
            {
                label: "English (US)",
                value: "en-US"
            },
            {
                label: "English (GB)",
                value: "en-GB"
            }
        ]
        defaultValue: "en-US"
    }
}
