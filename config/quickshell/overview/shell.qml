pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: root

    property bool opened: false
    property int selected: 0
    property var theme: ({})

    readonly property var palette: ({
        background: "#0f0e08",
        surfaceContainer: "#1b1a10",
        surfaceContainerHigh: "#212015",
        surfaceContainerHighest: "#27261a",
        onSurface: "#eae6d2",
        onSurfaceVariant: "#afab9a",
        outline: "#787666",
        outlineVariant: "#4a483a",
        primary: "#cec98c",
        primaryContainer: "#575423",
        onPrimary: "#444213",
        secondary: "#ccc8a4",
        tertiary: "#ffdaa8"
    })

    function col(name) {
        return (theme && theme[name]) ? theme[name] : (palette[name] ?? "#ffffff");
    }

    function openOverview() {
        const ws = Hyprland.focusedWorkspace;
        selected = Math.max(0, Math.min(9, (ws ? ws.id : 1) - 1));
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
        opened = true;
    }

    function closeOverview() {
        opened = false;
    }

    function navigate(dir) {
        selected = Math.max(0, Math.min(9, selected + dir));
    }

    function activate(index) {
        const id = index + 1;
        Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.focus({ workspace = "${id}" })` : `workspace ${id}`);
        opened = false;
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Space && (event.modifiers & Qt.MetaModifier)) {
            closeOverview();
            return;
        }
        switch (event.key) {
        case Qt.Key_Escape:
            closeOverview();
            return;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            activate(selected);
            return;
        case Qt.Key_Right:
        case Qt.Key_Down:
        case Qt.Key_Tab:
        case Qt.Key_L:
            navigate(1);
            return;
        case Qt.Key_Left:
        case Qt.Key_Up:
        case Qt.Key_Backtab:
        case Qt.Key_H:
            navigate(-1);
            return;
        }
        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            selected = event.key - Qt.Key_1;
            return;
        }
        if (event.key === Qt.Key_0) {
            selected = 9;
            return;
        }
        event.accepted = false;
    }

    FileView {
        id: themeFile

        path: Qt.resolvedUrl("theme.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.theme = JSON.parse(themeFile.text());
            } catch (e) {
                console.warn("overview: invalid theme.json", e);
            }
        }
    }

    IpcHandler {
        target: "overview"

        function toggle(): void {
            if (root.opened)
                root.closeOverview();
            else
                root.openOverview();
        }

        function open(): void {
            root.openOverview();
        }

        function close(): void {
            root.closeOverview();
        }

        function setSelected(index: int): void {
            root.selected = Math.max(0, Math.min(9, index));
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: win

            required property var modelData

            screen: modelData
            color: "#00000000"
            visible: root.opened
            focusable: root.opened
            exclusiveZone: 0
            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "caelestia-overview"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Connections {
                target: root
                function onOpenedChanged() {
                    if (root.opened)
                        focusTimer.restart();
                    else
                        input.focus = false;
                }
            }

            Timer {
                id: focusTimer
                interval: 30
                onTriggered: input.forceActiveFocus()
            }

            FocusScope {
                id: input

                anchors.fill: parent
                focus: root.opened

                Keys.onPressed: (event) => {
                    root.handleKey(event);
                    event.accepted = true;
                }

                WheelHandler {
                    onWheel: (event) => {
                        root.navigate(event.angleDelta.y > 0 ? -1 : 1);
                        event.accepted = true;
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.48)
                }

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 26
                    spacing: 3

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("WORKSPACES")
                        color: root.col("onSurfaceVariant")
                        opacity: 0.75
                        font.pixelSize: 11
                        font.letterSpacing: 4
                        font.weight: Font.DemiBold
                    }
                }

                Item {
                    id: stage

                    anchors.fill: parent
                    clip: true

                    readonly property real cardW: Math.min(win.width * 0.36, 620)
                    readonly property real cardH: cardW * 0.5625
                    readonly property real gap: cardW * 0.62

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.closeOverview()
                    }

                    Repeater {
                        model: 10

                        delegate: WorkspaceCard {
                            required property int index

                            theme: root.theme
                            overviewOpen: root.opened
                            wsId: index + 1
                            delta: index - root.selected
                            selectedIndex: root.selected
                            stageW: stage.width
                            stageH: stage.height
                            cardW: stage.cardW
                            cardH: stage.cardH
                            step: stage.gap
                            screen: win.screen

                            onActivateRequested: index => root.activate(index)
                        }
                    }
                }

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 44
                    spacing: 8

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Workspace %1").arg(root.selected + 1)
                        color: root.col("primary")
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("←/→ navegar   ·   Enter ir   ·   1-9 salto directo   ·   Esc cerrar")
                        color: root.col("onSurfaceVariant")
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
