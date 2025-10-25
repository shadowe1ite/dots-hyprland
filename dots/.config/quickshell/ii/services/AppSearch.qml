// pragma NativeMethodBehavior: AcceptThisObject
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland

RippleButton {
    id: root
    property var entry
    property string query
    property bool entryShown: entry?.shown ?? true
    property string itemType: entry?.type ?? Translation.tr("App")
    property string itemName: entry?.name ?? ""
    property string itemIcon: entry?.icon ?? ""
    property var itemExecute: entry?.execute
    property string fontType: entry?.fontType ?? "main"
    property string itemClickActionName: entry?.clickActionName ?? "Open"
    property string bigText: entry?.bigText ?? ""
    property string materialSymbol: entry?.materialSymbol ?? ""
    property string cliphistRawString: entry?.cliphistRawString ?? ""
    property bool blurImage: entry?.blurImage ?? false
    property string blurImageText: entry?.blurImageText ?? "Image hidden"
    property string genericName: entry?.genericName ?? ""
    property string comment: entry?.comment ?? ""
    property var categories: entry?.categories ?? []
    property real searchScore: 0
    property string matchedField: ""

    visible: root.entryShown
    property int horizontalMargin: 10
    property int buttonHorizontalPadding: 10
    property int buttonVerticalPadding: 6
    property bool keyboardDown: false

    implicitHeight: rowLayout.implicitHeight + root.buttonVerticalPadding * 2
    implicitWidth: rowLayout.implicitWidth + root.buttonHorizontalPadding * 2
    buttonRadius: Appearance.rounding.normal
    colBackground: (root.down || root.keyboardDown) ? Appearance.colors.colSecondaryContainerActive : ((root.hovered || root.focus) ? Appearance.colors.colSecondaryContainer : ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 1))
    colBackgroundHover: Appearance.colors.colSecondaryContainer
    colRipple: Appearance.colors.colSecondaryContainerActive

    property string highlightPrefix: `<u><font color="${Appearance.colors.colPrimary}">`
    property string highlightSuffix: `</font></u>`

    function calculateFuzzyScore(text, query) {
        if (!text || !query)
            return {
                score: 0,
                positions: []
            };

        const textLower = text.toLowerCase();
        const queryLower = query.toLowerCase();
        let score = 0;
        let positions = [];
        let queryIndex = 0;
        let consecutiveMatches = 0;
        let lastMatchPos = -2;

        for (let i = 0; i < textLower.length && queryIndex < queryLower.length; i++) {
            if (textLower[i] === queryLower[queryIndex]) {
                positions.push(i);
                queryIndex++;

                if (i === lastMatchPos + 1) {
                    consecutiveMatches++;
                    score += 10;
                } else {
                    consecutiveMatches = 0;
                    score += 5;
                }

                if (i === 0 || textLower[i - 1] === ' ' || textLower[i - 1] === '-' || textLower[i - 1] === '_') {
                    score += 15;
                }

                lastMatchPos = i;
            }
        }

        if (queryIndex < queryLower.length) {
            return {
                score: 0,
                positions: []
            };
        }

        if (positions[0] === 0) {
            score += 20;
        }

        score -= (text.length - query.length) * 0.1;

        return {
            score: Math.max(0, score),
            positions: positions
        };
    }

    function performFuzzySearch(query) {
        if (!query || query.length === 0) {
            root.searchScore = 0;
            root.matchedField = "";
            return;
        }

        let scores = {
            name: calculateFuzzyScore(root.itemName, query),
            genericName: calculateFuzzyScore(root.genericName, query),
            comment: calculateFuzzyScore(root.comment, query),
            categories: 0
        };

        if (root.categories && Array.isArray(root.categories)) {
            for (let category of root.categories) {
                let categoryScore = calculateFuzzyScore(category, query);
                if (categoryScore.score > scores.categories) {
                    scores.categories = categoryScore.score;
                }
            }
        }

        let weightedScores = {
            name: scores.name.score * 10,
            genericName: scores.genericName.score * 4,
            comment: scores.comment.score * 2,
            categories: scores.categories * 3
        };

        let maxScore = 0;
        let bestField = "";
        for (let field in weightedScores) {
            if (weightedScores[field] > maxScore) {
                maxScore = weightedScores[field];
                bestField = field;
            }
        }

        root.searchScore = maxScore;
        root.matchedField = bestField;
    }

    onQueryChanged: performFuzzySearch(query)

    function highlightContent(content, query) {
        if (!query || query.length === 0 || content == query || fontType === "monospace")
            return StringUtils.escapeHtml(content);

        let contentLower = content.toLowerCase();
        let queryLower = query.toLowerCase();

        let result = "";
        let lastIndex = 0;
        let qIndex = 0;

        for (let i = 0; i < content.length && qIndex < query.length; i++) {
            if (contentLower[i] === queryLower[qIndex]) {
                if (i > lastIndex)
                    result += StringUtils.escapeHtml(content.slice(lastIndex, i));
                result += root.highlightPrefix + StringUtils.escapeHtml(content[i]) + root.highlightSuffix;
                lastIndex = i + 1;
                qIndex++;
            }
        }
        if (lastIndex < content.length)
            result += StringUtils.escapeHtml(content.slice(lastIndex));

        return result;
    }

    property string displayContent: highlightContent(root.itemName, root.query)
    property string displayGenericName: root.genericName && root.matchedField !== "name" ? highlightContent(root.genericName, root.query) : StringUtils.escapeHtml(root.genericName)

    property list<string> urls: {
        if (!root.itemName)
            return [];
        const urlRegex = /https?:\/\/[^\s<>"{}|\\^`[\]]+/gi;
        const matches = root.itemName?.match(urlRegex)?.filter(url => !url.includes("…"));
        return matches ? matches : [];
    }

    PointingHandInteraction {}

    background {
        anchors.fill: root
        anchors.leftMargin: root.horizontalMargin
        anchors.rightMargin: root.horizontalMargin
    }

    onClicked: {
        GlobalStates.overviewOpen = false;
        root.itemExecute();
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Delete && event.modifiers === Qt.ShiftModifier) {
            const deleteAction = root.entry.actions.find(action => action.name == "Delete");

            if (deleteAction) {
                deleteAction.execute();
            }
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.keyboardDown = true;
            root.clicked();
            event.accepted = true;
        }
    }
    Keys.onReleased: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.keyboardDown = false;
            event.accepted = true;
        }
    }

    RowLayout {
        id: rowLayout
        spacing: iconLoader.sourceComponent === null ? 0 : 10
        anchors.fill: parent
        anchors.leftMargin: root.horizontalMargin + root.buttonHorizontalPadding
        anchors.rightMargin: root.horizontalMargin + root.buttonHorizontalPadding

        Loader {
            id: iconLoader
            active: true
            sourceComponent: root.materialSymbol !== "" ? materialSymbolComponent : root.bigText ? bigTextComponent : root.itemIcon !== "" ? iconImageComponent : null
        }

        Component {
            id: iconImageComponent
            IconImage {
                source: Quickshell.iconPath(root.itemIcon, "image-missing")
                width: 35
                height: 35
            }
        }

        Component {
            id: materialSymbolComponent
            MaterialSymbol {
                text: root.materialSymbol
                iconSize: 30
                color: Appearance.m3colors.m3onSurface
            }
        }

        Component {
            id: bigTextComponent
            StyledText {
                text: root.bigText
                font.pixelSize: Appearance.font.pixelSize.larger
                color: Appearance.m3colors.m3onSurface
            }
        }

        ColumnLayout {
            id: contentColumn
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
            StyledText {
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                visible: root.itemType && root.itemType != Translation.tr("App")
                text: root.itemType
            }
            RowLayout {
                Loader {
                    visible: itemName == Quickshell.clipboardText && root.cliphistRawString
                    active: itemName == Quickshell.clipboardText && root.cliphistRawString
                    sourceComponent: Rectangle {
                        implicitWidth: activeText.implicitHeight
                        implicitHeight: activeText.implicitHeight
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colPrimary
                        MaterialSymbol {
                            id: activeText
                            anchors.centerIn: parent
                            text: "check"
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.m3colors.m3onPrimary
                        }
                    }
                }
                Repeater {
                    model: root.query == root.itemName ? [] : root.urls
                    Favicon {
                        required property var modelData
                        size: parent.height
                        url: modelData
                    }
                }
                StyledText {
                    id: nameText
                    Layout.fillWidth: true
                    textFormat: Text.StyledText
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.family: Appearance.font.family[root.fontType]
                    color: Appearance.m3colors.m3onSurface
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideRight
                    text: {
                        let mainText = root.displayContent;
                        if (root.genericName && root.genericName.length > 0) {
                            let genericColor = root.matchedField === "genericName" ? Appearance.colors.colPrimary : Appearance.colors.colSubtext;
                            let genericDisplay = root.matchedField === "genericName" ? root.displayGenericName : StringUtils.escapeHtml(root.genericName);
                            mainText += ` <font color="${genericColor}"><i>[${genericDisplay}]</i></font>`;
                        }
                        return mainText;
                    }
                }
            }
            Loader {
                active: root.cliphistRawString && Cliphist.entryIsImage(root.cliphistRawString)
                sourceComponent: CliphistImage {
                    Layout.fillWidth: true
                    entry: root.cliphistRawString
                    maxWidth: contentColumn.width
                    maxHeight: 140
                    blur: root.blurImage
                    blurText: root.blurImageText
                }
            }
        }

        StyledText {
            id: clickAction
            Layout.fillWidth: false
            visible: (root.hovered || root.focus)
            font.pixelSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colSubtext
            horizontalAlignment: Text.AlignRight
            text: root.itemClickActionName
        }

        RowLayout {
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: root.buttonVerticalPadding
            Layout.bottomMargin: -root.buttonVerticalPadding
            spacing: 4
            Repeater {
                model: (root.entry.actions ?? []).slice(0, 4)
                delegate: RippleButton {
                    id: actionButton
                    required property var modelData
                    property string iconName: modelData.icon ?? ""
                    property string materialIconName: modelData.materialIcon ?? ""
                    implicitHeight: 34
                    implicitWidth: 34

                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                    colRipple: Appearance.colors.colSecondaryContainerActive

                    contentItem: Item {
                        id: actionContentItem
                        anchors.centerIn: parent
                        Loader {
                            anchors.centerIn: parent
                            active: !(actionButton.iconName !== "") || actionButton.materialIconName
                            sourceComponent: MaterialSymbol {
                                text: actionButton.materialIconName || "video_settings"
                                font.pixelSize: Appearance.font.pixelSize.hugeass
                                color: Appearance.m3colors.m3onSurface
                            }
                        }
                        Loader {
                            anchors.centerIn: parent
                            active: actionButton.materialIconName.length == 0 && actionButton.iconName && actionButton.iconName !== ""
                            sourceComponent: IconImage {
                                source: Quickshell.iconPath(actionButton.iconName)
                                implicitSize: 20
                            }
                        }
                    }

                    onClicked: modelData.execute()

                    StyledToolTip {
                        text: modelData.name
                    }
                }
            }
        }
    }
}
