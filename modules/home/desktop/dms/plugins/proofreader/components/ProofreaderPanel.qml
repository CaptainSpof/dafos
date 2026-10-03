import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Widgets

// Slideout body. All state and the LanguageTool/translation calls live on the
// widget (`ctl`); this file only lays them out and drives the text area.
Item {
    id: panel

    required property var ctl
    required property var slideout

    Keys.onEscapePressed: slideout.hide()

    function onShown() {
        ctl.loadState();
        if (ctl.languages.length === 0)
            ctl.fetchLanguages();
        if (!ctl.upToDate)
            ctl.runCheck();
        Qt.callLater(() => textArea.forceActiveFocus());
    }

    Component.onCompleted: onShown()

    Connections {
        target: panel.slideout
        function onRevealed() {
            panel.onShown();
        }
    }

    // Replace one match in place. remove()+insert() keeps the edit on the
    // undo stack, unlike assigning `text`.
    function applyReplacement(i, value) {
        const m = ctl.matches[i];
        if (!m || !ctl.upToDate)
            return;
        const end = m.offset + m.length;
        const delta = value.length - m.length;
        const newText = ctl.checkedText.slice(0, m.offset) + value + ctl.checkedText.slice(end);

        const rest = [];
        ctl.matches.forEach((o, j) => {
            if (j === i)
                return;
            if (o.offset >= end)
                rest.push(Object.assign({}, o, {
                    offset: o.offset + delta
                }));
            else if (o.offset + o.length <= m.offset)
                rest.push(o);
        });

        // Shift the bookkeeping first so the underlines survive the edit.
        ctl.checkedText = newText;
        ctl.matches = rest;
        ctl.activeIndex = -1;
        textArea.remove(m.offset, end);
        textArea.insert(m.offset, value);
        textArea.cursorPosition = m.offset + value.length;
        textArea.forceActiveFocus();
    }

    function selectMatch(i) {
        const m = ctl.matches[i];
        if (!m || !ctl.upToDate)
            return;
        textArea.select(m.offset, m.offset + m.length);
        textArea.forceActiveFocus();
        ctl.activeIndex = i;
    }

    function replaceAll(value) {
        textArea.selectAll();
        textArea.remove(0, textArea.length);
        if (value)
            textArea.insert(0, value);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingS

        // ── toolbar ──
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS

            DankDropdown {
                id: languageDropdown
                dropdownWidth: 200
                enableFuzzySearch: true
                options: ["Auto (détection)"].concat(panel.ctl.languageList.map(l => l.name))
                currentValue: {
                    if (panel.ctl.language === "auto")
                        return "Auto (détection)";
                    const hit = panel.ctl.languageList.find(l => l.longCode === panel.ctl.language);
                    return hit ? hit.name : panel.ctl.language;
                }
                onValueChanged: value => {
                    if (value === "Auto (détection)") {
                        panel.ctl.language = "auto";
                        return;
                    }
                    const hit = panel.ctl.languageList.find(l => l.name === value);
                    if (hit)
                        panel.ctl.language = hit.longCode;
                }
            }

            Item {
                Layout.fillWidth: true
            }

            DankActionButton {
                iconName: "spellcheck"
                tooltipText: "Vérifier (Ctrl+Entrée)"
                onClicked: panel.ctl.runCheck()
            }
            DankActionButton {
                iconName: "translate"
                visible: panel.ctl.translateBin !== ""
                iconColor: panel.ctl.showTranslation ? Theme.primary : Theme.surfaceVariantText
                tooltipText: "Traduction"
                onClicked: panel.ctl.showTranslation = !panel.ctl.showTranslation
            }
            DankActionButton {
                iconName: "content_copy"
                tooltipText: "Copier le texte"
                onClicked: panel.ctl.copy(panel.ctl.text)
            }
            DankActionButton {
                iconName: "delete_sweep"
                tooltipText: "Effacer"
                onClicked: panel.replaceAll("")
            }
        }

        StyledText {
            Layout.fillWidth: true
            elide: Text.ElideRight
            font.pixelSize: Theme.fontSizeSmall
            color: panel.ctl.errorText ? Theme.error : Theme.surfaceVariantText
            text: {
                const c = panel.ctl;
                if (c.errorText)
                    return c.errorText;
                if (c.busy)
                    return "Vérification…";
                if (c.text.trim().length === 0)
                    return "Prêt.";
                if (!c.upToDate)
                    return "Modifié — en attente de vérification";
                const detected = c.langNames[c.baseCode(c.detectedCode)] || c.detectedName;
                const lang = c.language === "auto" && detected ? "Détecté : " + detected + " · " : "";
                const n = c.matches.length;
                return lang + (n === 0 ? "Aucune faute trouvée" : n + (n > 1 ? " problèmes" : " problème"));
            }
        }

        // ── editor ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 160
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh
            border.width: textArea.activeFocus ? 2 : 1
            border.color: textArea.activeFocus ? Theme.primary : Theme.outlineVariant

            Flickable {
                anchors.fill: parent
                anchors.margins: 1
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                TextArea.flickable: TextArea {
                    id: textArea

                    property var segments: []

                    text: panel.ctl.text
                    font.family: SettingsData.fontFamily
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    selectedTextColor: Theme.background
                    selectionColor: Theme.primary
                    selectByMouse: true
                    wrapMode: TextArea.Wrap
                    textFormat: TextEdit.PlainText
                    persistentSelection: true
                    padding: Theme.spacingM
                    background: null

                    // TextArea's own placeholder does not render under the
                    // DMS style, so draw one.
                    StyledText {
                        x: textArea.leftPadding
                        y: textArea.topPadding
                        width: textArea.width - textArea.leftPadding - textArea.rightPadding
                        wrapMode: Text.WordWrap
                        visible: textArea.length === 0 && !textArea.preeditText
                        text: "Écrivez ou collez votre texte ici… (Ctrl+Entrée pour vérifier)"
                        font: textArea.font
                        color: Theme.surfaceTextSecondary
                    }

                    onTextChanged: {
                        if (panel.ctl.text !== text)
                            panel.ctl.text = text;
                        segmentTimer.restart();
                    }
                    onWidthChanged: segmentTimer.restart()
                    onContentHeightChanged: segmentTimer.restart()

                    onCursorPositionChanged: {
                        if (!panel.ctl.upToDate)
                            return;
                        const pos = cursorPosition;
                        const i = panel.ctl.matches.findIndex(m => pos >= m.offset && pos <= m.offset + m.length);
                        panel.ctl.activeIndex = i;
                        if (i >= 0)
                            matchList.positionViewAtIndex(i, ListView.Contain);
                    }

                    Keys.onPressed: event => {
                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) {
                            panel.ctl.runCheck();
                            event.accepted = true;
                        }
                    }

                    Connections {
                        target: panel.ctl
                        function onMatchesChanged() {
                            segmentTimer.restart();
                        }
                        function onCheckedTextChanged() {
                            segmentTimer.restart();
                        }
                        function onTextChanged() {
                            // Another screen's slideout, or loadState(), changed the text.
                            if (textArea.text !== panel.ctl.text)
                                textArea.text = panel.ctl.text;
                        }
                    }

                    // Layout settles after text/width changes; measure on the
                    // next tick rather than inside the change handler.
                    Timer {
                        id: segmentTimer
                        interval: 16
                        onTriggered: textArea.segments = textArea.computeSegments()
                    }

                    // One underline per visual line a match covers, found by
                    // walking positions until the line's y changes.
                    function computeSegments() {
                        if (!panel.ctl.upToDate || text !== panel.ctl.checkedText)
                            return [];
                        const out = [];
                        panel.ctl.matches.forEach((m, i) => {
                            const start = m.offset;
                            const end = Math.min(m.offset + Math.max(m.length, 1), length);
                            let seg = positionToRectangle(start);
                            let right = seg.x;
                            const push = () => {
                                if (right - seg.x >= 1)
                                    out.push({
                                        x: seg.x,
                                        y: seg.y,
                                        w: right - seg.x,
                                        h: seg.height,
                                        index: i,
                                        color: panel.ctl.issueColor(m)
                                    });
                            };
                            for (let p = start + 1; p <= end; p++) {
                                const r = positionToRectangle(p);
                                if (Math.abs(r.y - seg.y) > 0.5) {
                                    push();
                                    seg = r;
                                }
                                right = r.x;
                            }
                            push();
                        });
                        return out;
                    }

                    Repeater {
                        model: textArea.segments

                        Item {
                            required property var modelData
                            x: modelData.x
                            y: modelData.y
                            width: modelData.w
                            height: modelData.h

                            Rectangle {
                                anchors.fill: parent
                                radius: 2
                                color: parent.modelData.color
                                opacity: parent.modelData.index === panel.ctl.activeIndex ? 0.18 : 0
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 2
                                radius: 1
                                color: parent.modelData.color
                            }
                        }
                    }
                }
            }
        }

        // ── issues ──
        ListView {
            id: matchList
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, panel.height * 0.35)
            visible: panel.ctl.upToDate && panel.ctl.matches.length > 0
            clip: true
            spacing: Theme.spacingXS
            boundsBehavior: Flickable.StopAtBounds
            model: panel.ctl.upToDate ? panel.ctl.matches : []
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            delegate: Rectangle {
                id: issue
                required property var modelData
                required property int index

                readonly property string bad: panel.ctl.checkedText.substr(modelData.offset, modelData.length)
                readonly property bool isSpelling: modelData.rule?.issueType === "misspelling"

                width: matchList.width - Theme.spacingS
                height: issueColumn.implicitHeight + Theme.spacingS * 2
                radius: Theme.cornerRadius
                color: index === panel.ctl.activeIndex ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.selectMatch(issue.index)
                }

                Rectangle {
                    width: 3
                    radius: 1.5
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.spacingS
                    color: panel.ctl.issueColor(issue.modelData)
                }

                Column {
                    id: issueColumn
                    x: Theme.spacingM + 3
                    y: Theme.spacingS
                    width: parent.width - x - Theme.spacingS
                    spacing: Theme.spacingXS

                    StyledText {
                        width: parent.width
                        elide: Text.ElideRight
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        text: "« " + issue.bad + " » · " + (issue.modelData.rule?.category?.name || "")
                    }

                    StyledText {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        text: issue.modelData.message
                    }

                    Flow {
                        width: parent.width
                        spacing: Theme.spacingXS

                        Repeater {
                            model: (issue.modelData.replacements || []).slice(0, 6)

                            Rectangle {
                                required property var modelData
                                width: chipLabel.implicitWidth + Theme.spacingM * 2
                                height: chipLabel.implicitHeight + Theme.spacingXS * 2
                                radius: height / 2
                                color: chipArea.containsMouse ? Theme.primary : Theme.primaryContainer

                                StyledText {
                                    id: chipLabel
                                    anchors.centerIn: parent
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: chipArea.containsMouse ? Theme.onPrimary : Theme.onPrimaryContainer
                                    text: parent.modelData.value === "" ? "(supprimer)" : parent.modelData.value
                                }

                                MouseArea {
                                    id: chipArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: panel.applyReplacement(issue.index, parent.modelData.value)
                                }
                            }
                        }

                        Repeater {
                            model: issue.isSpelling ? ["Ignorer", "Ajouter au dictionnaire"] : ["Ignorer"]

                            Rectangle {
                                required property string modelData
                                required property int index
                                width: actionLabel.implicitWidth + Theme.spacingM * 2
                                height: actionLabel.implicitHeight + Theme.spacingXS * 2
                                radius: height / 2
                                color: actionArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                                border.width: 1
                                border.color: Theme.outlineVariant

                                StyledText {
                                    id: actionLabel
                                    anchors.centerIn: parent
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    text: parent.modelData
                                }

                                MouseArea {
                                    id: actionArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: parent.index === 0 ? panel.ctl.ignoreMatch(issue.index) : panel.ctl.addToDictionary(issue.index)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── translation ──
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS
            visible: panel.ctl.showTranslation && panel.ctl.translateBin !== ""

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingS

                StyledText {
                    color: Theme.surfaceVariantText
                    text: panel.ctl.sourceLanguage ? panel.ctl.langName(panel.ctl.sourceLanguage) + "  →" : "Langue source inconnue : lancez une vérification"
                }

                DankDropdown {
                    visible: panel.ctl.translationTargets.length > 0
                    dropdownWidth: 160
                    options: panel.ctl.translationTargets.map(c => panel.ctl.langName(c))
                    currentValue: panel.ctl.langName(panel.ctl.effectiveTarget)
                    onValueChanged: value => {
                        const code = panel.ctl.translationTargets.find(c => panel.ctl.langName(c) === value);
                        if (code) {
                            panel.ctl.targetLanguage = code;
                            panel.ctl.saveState("targetLanguage", code);
                            panel.ctl.translation = "";
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                DankButton {
                    text: "Traduire"
                    iconName: "translate"
                    busy: panel.ctl.translating
                    enabled: panel.ctl.effectiveTarget !== "" && panel.ctl.text.trim().length > 0 && !panel.ctl.translating
                    onClicked: panel.ctl.runTranslate()
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: panel.ctl.sourceLanguage !== "" && panel.ctl.translationTargets.length === 0
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                text: "Aucun modèle de traduction installé pour " + panel.ctl.langName(panel.ctl.sourceLanguage) + " (dafos.desktop.dms.proofreader.translation.models)."
            }

            StyledText {
                Layout.fillWidth: true
                visible: panel.ctl.translationError !== ""
                wrapMode: Text.WordWrap
                color: Theme.error
                text: panel.ctl.translationError
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(panel.height * 0.3, 220)
                visible: panel.ctl.translation !== ""
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh

                Flickable {
                    anchors.fill: parent
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    TextArea.flickable: TextArea {
                        readOnly: true
                        selectByMouse: true
                        text: panel.ctl.translation
                        wrapMode: TextArea.Wrap
                        textFormat: TextEdit.PlainText
                        font.family: SettingsData.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        selectedTextColor: Theme.background
                        selectionColor: Theme.primary
                        padding: Theme.spacingM
                        background: null
                    }
                }
            }

            RowLayout {
                visible: panel.ctl.translation !== ""
                spacing: Theme.spacingS

                DankButton {
                    text: "Copier"
                    iconName: "content_copy"
                    onClicked: panel.ctl.copy(panel.ctl.translation)
                }

                DankButton {
                    text: "Remplacer le texte"
                    iconName: "swap_horiz"
                    onClicked: {
                        panel.replaceAll(panel.ctl.translation);
                        if (panel.ctl.language !== "auto")
                            panel.ctl.language = "auto";
                    }
                }
            }
        }
    }
}
