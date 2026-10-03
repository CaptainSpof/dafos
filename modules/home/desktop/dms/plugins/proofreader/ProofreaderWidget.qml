import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "./components"

// A scratch text area checked by LanguageTool, with offline translation.
//
// The UI is a full-height slideout per screen, framed like the built-in
// Notepad (ProofreaderPanel.qml). State lives here, on the component, so a
// check in flight survives the slideout closing and the bar pill can show the
// issue count. The text is persisted through pluginState, which every
// instance (one per bar/screen) shares in memory; a slideout reloads it when
// it opens.
//
// Per-host defaults (server URL, translation wrapper, available pairs) come
// from ~/.config/DankMaterialShell/proofreader.json, written by
// modules/home/desktop/dms/proofreader.nix. The plugin settings override them.
PluginComponent {
    id: root

    // ── configuration ────────────────────────────────────────────────────
    property var nixDefaults: ({})

    readonly property string ltUrl: {
        const fromSettings = (pluginData.languageToolUrl || "").trim();
        const url = fromSettings || nixDefaults.languageToolUrl || "http://127.0.0.1:8081";
        return url.replace(/\/+$/, "");
    }
    readonly property string translateBin: nixDefaults.translateBin || ""
    readonly property var translationPairs: nixDefaults.translationPairs || ({})
    readonly property bool autoCheck: pluginData.autoCheck ?? true
    readonly property bool picky: pluginData.picky ?? false
    readonly property string motherTongue: pluginData.motherTongue ?? "fr"
    readonly property string englishVariant: pluginData.englishVariant || "en-US"

    // ── state ────────────────────────────────────────────────────────────
    property string text: ""
    property string language: "auto"
    property string targetLanguage: ""
    property var ignoredWords: []

    // Matches only describe `checkedText`; once the text moves on, their
    // offsets are stale and the underlines hide until the next check lands.
    property var matches: []
    property string checkedText: ""
    property string detectedCode: ""
    property string detectedName: ""
    property bool busy: false
    property string errorText: ""
    property int activeIndex: -1
    property int requestSeq: 0

    property string translation: ""
    property bool translating: false
    property string translationError: ""
    property bool showTranslation: false

    property var languages: []

    readonly property bool upToDate: text === checkedText
    readonly property int issueCount: upToDate ? matches.length : 0

    // Fallback when /v2/languages is unreachable.
    readonly property var fallbackLanguages: [
        {
            name: "French",
            longCode: "fr"
        },
        {
            name: "English (US)",
            longCode: "en-US"
        },
        {
            name: "English (GB)",
            longCode: "en-GB"
        },
        {
            name: "German (Germany)",
            longCode: "de-DE"
        },
        {
            name: "Spanish",
            longCode: "es"
        }
    ]

    readonly property var langNames: ({
            "fr": "Français",
            "en": "English",
            "de": "Deutsch",
            "es": "Español",
            "it": "Italiano",
            "pt": "Português",
            "nl": "Nederlands",
            "pl": "Polski",
            "cs": "Čeština",
            "et": "Eesti",
            "bg": "Български",
            "uk": "Українська",
            "is": "Íslenska",
            "nb": "Norsk bokmål",
            "nn": "Norsk nynorsk",
            "tr": "Türkçe",
            "ca": "Català",
            "el": "Ελληνικά",
            "sl": "Slovenščina",
            "sq": "Shqip",
            "mk": "Македонски",
            "mt": "Malti"
        })

    function langName(code) {
        return langNames[code] || code;
    }

    // "fr-FR" -> "fr"
    function baseCode(code) {
        return (code || "").split("-")[0];
    }

    readonly property string sourceLanguage: baseCode(language !== "auto" ? language : detectedCode)
    readonly property var translationTargets: translationPairs[sourceLanguage] || []
    readonly property string effectiveTarget: {
        const targets = translationTargets;
        if (targets.indexOf(targetLanguage) >= 0)
            return targetLanguage;
        if (targets.indexOf("en") >= 0)
            return "en";
        return targets.length > 0 ? targets[0] : "";
    }

    // ── persistence ──────────────────────────────────────────────────────
    function loadState() {
        if (!pluginService)
            return;
        text = pluginService.loadPluginState("proofreader", "text", "");
        // Bare en/de (no spell checker) were selectable before; move them to a variant.
        const saved = pluginService.loadPluginState("proofreader", "language", "auto");
        language = saved === "en" ? englishVariant : saved === "de" ? "de-DE" : saved;
        targetLanguage = pluginService.loadPluginState("proofreader", "targetLanguage", "");
        ignoredWords = pluginService.loadPluginState("proofreader", "ignoredWords", []);
    }

    function saveState(key, value) {
        if (pluginService)
            pluginService.savePluginState("proofreader", key, value);
    }

    onPluginServiceChanged: loadState()

    onTextChanged: {
        saveState("text", text);
        translation = "";
        translationError = "";
        if (autoCheck)
            checkTimer.restart();
    }
    onLanguageChanged: {
        saveState("language", language);
        checkTimer.restart();
    }
    onLtUrlChanged: {
        languages = [];
        fetchLanguages();
    }

    FileView {
        path: Paths.strip(Paths.config) + "/proofreader.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.nixDefaults = JSON.parse(text());
            } catch (e) {
                console.warn("proofreader: unreadable proofreader.json:", e);
            }
        }
        onLoadFailed: root.nixDefaults = {}
    }

    Timer {
        id: checkTimer
        interval: 800
        onTriggered: root.runCheck()
    }

    // ── LanguageTool ─────────────────────────────────────────────────────
    function fetchLanguages() {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", ltUrl + "/v2/languages");
        xhr.timeout = 10000;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status !== 200)
                return;
            try {
                // Bare "en" and "de" run without a spell checker (LanguageTool
                // 6.6), so a typo like "hte" passes; only their variants
                // (en-US, de-DE, ...) catch it. Every other bare code checked
                // spelling when surveyed, so the list stays explicit.
                const noSpelling = ["en", "de"];
                const list = JSON.parse(xhr.responseText).filter(l => noSpelling.indexOf(l.longCode) < 0);
                list.sort((a, b) => a.name.localeCompare(b.name));
                root.languages = list;
            } catch (e) {
                console.warn("proofreader: bad /v2/languages response:", e);
            }
        };
        xhr.send();
    }

    readonly property var languageList: languages.length > 0 ? languages : fallbackLanguages

    function filterIgnored(list, source) {
        if (ignoredWords.length === 0)
            return list;
        return list.filter(m => {
            if (m.rule?.issueType !== "misspelling")
                return true;
            return ignoredWords.indexOf(source.substr(m.offset, m.length)) < 0;
        });
    }

    function runCheck() {
        checkTimer.stop();
        const snapshot = text;
        if (snapshot.trim().length === 0) {
            requestSeq++;
            busy = false;
            errorText = "";
            matches = [];
            checkedText = snapshot;
            return;
        }

        const seq = ++requestSeq;
        busy = true;

        const params = ["text=" + encodeURIComponent(snapshot), "language=" + encodeURIComponent(language)];
        if (language === "auto")
            params.push("preferredVariants=" + encodeURIComponent(englishVariant + ",de-DE,pt-PT"));
        if (motherTongue)
            params.push("motherTongue=" + encodeURIComponent(motherTongue));
        if (picky)
            params.push("level=picky");

        const xhr = new XMLHttpRequest();
        xhr.open("POST", ltUrl + "/v2/check");
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
        xhr.setRequestHeader("Accept", "application/json");
        xhr.timeout = 20000;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            // A newer request superseded this one.
            if (seq !== root.requestSeq)
                return;
            root.busy = false;

            if (xhr.status === 0) {
                root.errorText = "LanguageTool injoignable : " + root.ltUrl;
                return;
            }
            if (xhr.status !== 200) {
                root.errorText = "LanguageTool : HTTP " + xhr.status + " " + (xhr.responseText || "").slice(0, 160);
                return;
            }

            let data;
            try {
                data = JSON.parse(xhr.responseText);
            } catch (e) {
                root.errorText = "Réponse LanguageTool illisible";
                return;
            }

            root.errorText = "";
            const lang = data.language || {};
            root.detectedCode = lang.detectedLanguage?.code || lang.code || "";
            root.detectedName = lang.detectedLanguage?.name || lang.name || "";
            root.matches = root.filterIgnored(data.matches || [], snapshot);
            root.activeIndex = -1;
            root.checkedText = snapshot;
        };
        xhr.send(params.join("&"));
    }

    function ignoreMatch(i) {
        const list = matches.slice();
        list.splice(i, 1);
        matches = list;
        activeIndex = -1;
    }

    function addToDictionary(i) {
        const word = checkedText.substr(matches[i].offset, matches[i].length);
        if (ignoredWords.indexOf(word) < 0) {
            ignoredWords = ignoredWords.concat([word]);
            saveState("ignoredWords", ignoredWords);
        }
        matches = filterIgnored(matches, checkedText);
        activeIndex = -1;
    }

    // ── translation ──────────────────────────────────────────────────────
    function runTranslate() {
        const src = sourceLanguage;
        const dst = effectiveTarget;
        if (!translateBin || !src || !dst || text.trim().length === 0)
            return;
        translating = true;
        translationError = "";
        const snapshot = text;
        Proc.runCommand("proofreader.translate", [translateBin, src, dst, snapshot], (stdout, exitCode) => {
            root.translating = false;
            if (snapshot !== root.text)
                return;
            if (exitCode === 0) {
                root.translation = stdout.replace(/\n+$/, "");
            } else if (exitCode === 2) {
                root.translationError = "Aucun modèle pour " + src + " → " + dst;
            } else {
                root.translationError = "Échec de la traduction (code " + exitCode + ")";
            }
        }, 0, 60000);
    }

    function copy(value) {
        if (!value)
            return;
        Quickshell.execDetached(["dms", "cl", "copy", value]);
        ToastService.showInfo("Copié dans le presse-papiers");
    }

    function issueColor(match) {
        switch (match?.rule?.issueType) {
        case "misspelling":
            return Theme.error;
        case "style":
        case "locale-violation":
        case "register":
            return Theme.info;
        case "typographical":
        case "whitespace":
            return Theme.secondary;
        default:
            return Theme.warning;
        }
    }

    // ── slideouts and IPC ────────────────────────────────────────────────
    // One component runs per bar per screen. The first to load owns the IPC
    // target and the per-screen slideouts; every pill routes its click to it
    // through a global var, so there is exactly one slideout per screen.
    readonly property string instanceToken: Math.random().toString(36).slice(2)
    readonly property bool ipcOwner: (PluginService.globalVars["proofreader"] || {}).ipcOwner === instanceToken

    Component.onCompleted: {
        if (!PluginService.getGlobalVar("proofreader", "ipcOwner", ""))
            PluginService.setGlobalVar("proofreader", "ipcOwner", instanceToken);
    }
    Component.onDestruction: {
        if (ipcOwner)
            PluginService.setGlobalVar("proofreader", "ipcOwner", "");
    }

    pillClickAction: (x, y, width, section, screen) => {
        PluginService.setGlobalVar("proofreader", "toggleRequest", {
            screen: screen?.name || "",
            at: Date.now()
        });
    }

    Connections {
        target: PluginService
        enabled: root.ipcOwner
        function onGlobalVarChanged(pluginId, varName) {
            if (pluginId === "proofreader" && varName === "toggleRequest")
                root.toggleOn(PluginService.getGlobalVar("proofreader", "toggleRequest", {}).screen);
        }
    }

    function toggleOn(screenName) {
        const list = slideouts.instances || [];
        if (list.length === 0)
            return;
        const target = list.find(s => s.modelData?.name === screenName) || list[0];
        list.forEach(s => {
            if (s !== target && s.isVisible)
                s.hide();
        });
        target.toggle();
    }

    // Same frame as the built-in Notepad: full-height slideout, its side,
    // edge gap and transparency, 480px expandable to 960px.
    Variants {
        id: slideouts
        model: root.ipcOwner ? Quickshell.screens : []

        delegate: DankSlideout {
            id: slideout
            layerNamespace: "dms:plugins:proofreader"
            title: "Correcteur"
            slideoutWidth: 480
            expandable: true
            expandedWidthValue: 960
            edgeGap: SettingsData.notepadEffectiveEdgeGap
            slideEdge: SettingsData.notepadSlideoutSide
            customTransparency: Theme.notepadTransparency

            content: Component {
                ProofreaderPanel {
                    ctl: root
                    slideout: slideout
                }
            }
        }
    }

    // `dms ipc call proofreader toggle` opens it on the focused screen.
    IpcHandler {
        target: "proofreader"
        enabled: root.ipcOwner

        function toggle(): string {
            root.toggleOn(BarWidgetService.getFocusedScreenName());
            return "ok";
        }

        function check(): string {
            root.runCheck();
            return "ok";
        }
    }

    // ── bar pill ─────────────────────────────────────────────────────────
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                name: "spellcheck"
                size: root.iconSize
                color: root.errorText ? Theme.error : Theme.widgetIconColor
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.issueCount > 0
                text: root.issueCount
                font.pixelSize: root.textSize
                color: Theme.widgetTextColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                name: "spellcheck"
                size: root.iconSize
                color: root.errorText ? Theme.error : Theme.widgetIconColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                visible: root.issueCount > 0
                text: root.issueCount
                font.pixelSize: root.textSize
                color: Theme.widgetTextColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
