import QtQuick
import QtQuick.Effects
import QtMultimedia

Item {
    id: card
    required property var item
    property bool active: false
    property bool videoPlaying: false
    signal picked()
    signal applied()

    Rectangle {
        id: surface
        anchors.fill: parent
        anchors.margins: 10
        radius: 22
        color: "#0b0e14"
        clip: true
        border.width: 0
        scale: (card.active ? 1.018 : 1) * (hover.hovered ? 1.008 : 1)
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: card.active ? 0.84 : 0.64
            shadowBlur: 1.0
            shadowScale: card.active ? 1.17 : 1.13
            shadowVerticalOffset: card.active ? 8 : 5
            blurMax: card.active ? 120 : 96
            autoPaddingEnabled: true
        }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Image {
            id: preview
            property int inset: 0
            anchors.fill: parent; anchors.margins: inset
            source: card.item.thumb || ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true; cache: true
            opacity: card.videoPlaying ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 220 } }
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: imageMask
            }
        }
        Loader {
            id: previewVideo
            anchors.fill: parent
            anchors.margins: preview.inset
            active: card.active && card.item.animated && (card.item.preview || "") !== ""
            enabled: false
            opacity: card.videoPlaying ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }
            layer.enabled: active
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: imageMask
            }

            sourceComponent: Item {
                MediaPlayer {
                    id: player
                    source: card.item.preview || ""
                    loops: MediaPlayer.Infinite
                    autoPlay: true
                    audioOutput: AudioOutput { muted: true }
                    videoOutput: output
                    onPlayingChanged: card.videoPlaying = player.playing
                }
                VideoOutput {
                    id: output
                    anchors.fill: parent
                    fillMode: VideoOutput.PreserveAspectCrop
                }
            }
        }
        Rectangle {
            id: imageMask
            anchors.fill: preview
            radius: Math.max(0, surface.radius - preview.inset)
            visible: false
            layer.enabled: true
        }
        Rectangle {
            anchors.fill: parent
            radius: surface.radius
            gradient: Gradient {
                GradientStop { position: 0.62; color: "transparent" }
                GradientStop { position: 1; color: "#99080a10" }
            }
        }
        Column {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: 18; spacing: 3
            Text {
                width: parent.width; text: card.item.title || card.item.id
                color: "white"; font.pixelSize: 13; font.weight: Font.Medium; font.letterSpacing: 0.15; elide: Text.ElideRight
            }
            Text {
                text: card.item.resolution || card.item.source
                color: "#aeb7c8"; font.pixelSize: 9; font.letterSpacing: 1.0
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: surface.radius
            color: hover.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
            Behavior on color { ColorAnimation { duration: 140 } }
        }
        Rectangle {
            visible: card.item.animated === true
            anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 16
            width: badgeText.implicitWidth + 16; height: 20; radius: 10
            color: Qt.rgba(0.02, 0.03, 0.05, 0.62)
            Text {
                id: badgeText
                anchors.centerIn: parent
                text: "▶ LIVE"
                color: card.active ? "#ffffff" : "#c9d6ea"
                font.pixelSize: 9; font.weight: Font.DemiBold; font.letterSpacing: 1.1
            }
        }
    }

    onActiveChanged: if (!active) videoPlaying = false

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { acceptedButtons: Qt.LeftButton; onTapped: card.picked(); onDoubleTapped: { card.picked(); card.applied(); } }
}
