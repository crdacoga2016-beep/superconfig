pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: card

    required property var theme
    required property bool overviewOpen
    required property int wsId
    required property int delta
    required property int selectedIndex
    required property real stageW
    required property real stageH
    required property real cardW
    required property real cardH
    required property real step
    required property var screen

    signal activateRequested(int wsIndex)

    readonly property int wsIndex: wsId - 1
    readonly property bool isSelected: wsIndex === selectedIndex
    readonly property bool near: Math.abs(delta) <= 1

    readonly property var ws: {
        const list = Hyprland.workspaces.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].id === wsId)
                return list[i];
        return null;
    }

    readonly property var windows: Hyprland.toplevels.values.filter(t => {
        if (!t.workspace || t.workspace.id !== wsId)
            return false;
        if (!t.wayland)
            return false;
        const ipc = t.lastIpcObject;
        if (ipc) {
            if (ipc.mapped === false || ipc.hidden)
                return false;
            if (ipc.size && (ipc.size[0] <= 0 || ipc.size[1] <= 0))
                return false;
        }
        return true;
    })

    readonly property var mon: (ws && ws.monitor) ? ws.monitor : Hyprland.monitorFor(screen)
    readonly property real monX: mon ? mon.x : 0
    readonly property real monY: mon ? mon.y : 0
    readonly property real monW: (mon && mon.width > 0) ? mon.width : 1920
    readonly property real monH: (mon && mon.height > 0) ? mon.height : 1080

    property real tilt: Math.max(-52, Math.min(52, -delta * 30))

    width: cardW
    height: cardH
    visible: Math.abs(delta) <= 2
    z: 100 - Math.abs(delta)
    x: (stageW - cardW) / 2 + delta * step
    y: (stageH - cardH) / 2 + (isSelected ? -26 : 18)
    scale: isSelected ? 1.0 : 0.82
    opacity: Math.abs(delta) === 0 ? 1.0 : Math.abs(delta) === 1 ? 0.72 : 0.0

    Behavior on x { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    Behavior on tilt { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }

    function col(name) {
        return (theme && theme[name]) ? theme[name] : "#ffffff";
    }

    Item {
        id: visual

        anchors.fill: parent

        transform: Rotation {
            axis { x: 0; y: 1; z: 0 }
            angle: card.tilt
            origin.x: card.width / 2
            origin.y: card.height / 2
        }

        Rectangle {
        anchors.fill: parent
        anchors.margins: -12
        radius: 30
        color: card.col("primary")
        opacity: card.isSelected ? 0.16 : 0.0

        Behavior on opacity { NumberAnimation { duration: 220 } }
    }

    Rectangle {
        id: body

        anchors.fill: parent
        radius: 18
        color: card.col("surfaceContainer")
        border.width: card.isSelected ? 2 : 1
        border.color: card.isSelected ? card.col("primary") : card.col("outlineVariant")
        clip: true

        Behavior on border.color { ColorAnimation { duration: 200 } }

        Item {
            id: preview

            anchors.fill: parent
            anchors.margins: 7
            anchors.topMargin: 42
            clip: true
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: previewMask
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: card.col("surfaceContainerHigh") }
                    GradientStop { position: 1.0; color: card.col("background") }
                }
            }

            Repeater {
                model: card.near ? card.windows : []

                delegate: ScreencopyView {
                    id: windowPreview

                    required property var modelData

                    readonly property var ipc: modelData.lastIpcObject
                    readonly property real previewScale: Math.min(preview.width / card.monW, preview.height / card.monH)

                    x: ((ipc && ipc.at ? ipc.at[0] : 0) - card.monX) * previewScale + (preview.width - card.monW * previewScale) / 2
                    y: ((ipc && ipc.at ? ipc.at[1] : 0) - card.monY) * previewScale + (preview.height - card.monH * previewScale) / 2
                    width: (ipc && ipc.size ? ipc.size[0] : 0) * previewScale
                    height: (ipc && ipc.size ? ipc.size[1] : 0) * previewScale
                    captureSource: (card.overviewOpen && card.near) ? modelData.wayland : null
                    live: false
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 2
                visible: card.windows.length === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: card.wsId
                    color: card.col("primary")
                    opacity: 0.9
                    font.pixelSize: Math.round(card.cardH * 0.30)
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("sin ventanas")
                    color: card.col("onSurfaceVariant")
                    font.pixelSize: 12
                }
            }
        }

        Item {
            id: previewMask

            anchors.fill: preview
            visible: false
            layer.enabled: true

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: "black"
            }
        }

        Rectangle {
            id: header

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 42
            color: card.col("surfaceContainerHigh")
            opacity: 0.92

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("WORKSPACE %1").arg(card.wsId)
                color: card.isSelected ? card.col("primary") : card.col("onSurfaceVariant")
                font.pixelSize: 11
                font.letterSpacing: 1.2
                font.weight: Font.DemiBold
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: card.windows.length === 1 ? qsTr("1 ventana") : qsTr("%1 ventanas").arg(card.windows.length)
                color: card.col("onSurfaceVariant")
                font.pixelSize: 11
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 7
            width: 7
            height: 7
            radius: 4
            color: card.col("primary")
            visible: card.ws ? card.ws.active : false
        }
    }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.activateRequested(card.wsIndex)
    }
}
