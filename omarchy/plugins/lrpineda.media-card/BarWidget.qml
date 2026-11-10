import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Ui
import qs.Commons

// Now-playing widget with a hover-summoned player card.
//
// Bar strip: album art thumb + a dancing equalizer + marquee title.
// Hover card: large art, track info, seek bar, transport controls, and a
// source list so a paused YouTube tab can take over from Spotify (or the
// other way round) in one click.
//
// Everything paints from the Color/Style singletons, so the card follows
// whatever theme is applied without a restart.
BarWidget {
  id: root
  moduleName: "omarchy.media"

  readonly property var mediaService: bar?.shell?.firstPartyServiceFor("omarchy.media")
  readonly property var activePlayer: mediaService ? mediaService.activePlayer : null
  readonly property var sourcePlayers: mediaService ? mediaService.sourcePlayers : []

  readonly property bool hasMedia: activePlayer !== null && (activePlayer.trackTitle || activePlayer.trackArtist)
  readonly property bool playing: activePlayer ? !!activePlayer.isPlaying : false
  readonly property string title: activePlayer ? (activePlayer.trackTitle || "") : ""
  readonly property string artist: activePlayer ? (activePlayer.trackArtist || "") : ""
  readonly property string album: activePlayer && activePlayer.trackAlbum ? activePlayer.trackAlbum : ""
  readonly property string artUrl: activePlayer && activePlayer.trackArtUrl ? activePlayer.trackArtUrl : ""
  readonly property string sourceName: activePlayer ? (activePlayer.identity || activePlayer.desktopEntry || "") : ""

  // Popup palette, all theme-derived.
  readonly property color fg: Color.popups.text
  readonly property color fgSoft: Util.alpha(Color.popups.text, 0.68)
  readonly property color fgFaint: Util.alpha(Color.popups.text, 0.42)
  readonly property color accent: Color.accent

  readonly property real maxLabelWidth: Style.space(setting("maxLabelWidth", 180))
  readonly property bool showArt: setting("showArt", true)
  readonly property int hoverDelay: setting("hoverDelay", 130)

  property bool popupOpen: false
  property bool widgetHovered: false

  function close() { popupOpen = false }
  function closeForPopoutSwitch() { popupOpen = false }

  function act(action, key) {
    if (mediaService) mediaService.runAction(action, false, key)
  }

  // Hand playback to `player`: select it as the active source, start it, and
  // pause whoever was playing so two apps never talk over each other.
  function takeOver(player) {
    if (!player || !mediaService) return
    var previous = root.activePlayer
    mediaService.selectPlayer(mediaService.playerKey(player))
    if (player.isPlaying) {
      mediaService.pausePlayer(player)
      return
    }
    if (mediaService.playPlayer(player) && previous && previous !== player)
      mediaService.pausePlayer(previous)
  }

  // MPRIS reports seconds, but a few players hand back microseconds. Anything
  // longer than a day is the latter, so scale it back into seconds.
  function seconds(value) {
    var n = Number(value)
    if (!isFinite(n) || n <= 0) return 0
    return n > 86400 ? n / 1000000 : n
  }

  function clockText(value) {
    var total = Math.floor(root.seconds(value))
    var mins = Math.floor(total / 60)
    var secs = total % 60
    var hours = Math.floor(mins / 60)
    var pad = function(n) { return n < 10 ? "0" + n : String(n) }
    return hours > 0 ? hours + ":" + pad(mins % 60) + ":" + pad(secs) : mins + ":" + pad(secs)
  }

  visible: hasMedia
  implicitWidth: hasMedia ? strip.implicitWidth + Style.space(14) : 0
  implicitHeight: barSize

  // ------------------------------------------------------------ bar strip

  Row {
    id: strip
    anchors.centerIn: parent
    spacing: Style.space(7)

    // Album art thumb, with the equalizer/pause glyph as the fallback face.
    Item {
      id: thumb
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(17)
      height: Style.space(17)
      visible: root.showArt

      Rectangle {
        id: thumbClip
        anchors.fill: parent
        radius: Style.space(4)
        color: Util.alpha(root.bar.barForeground, 0.10)
        clip: true

        Image {
          anchors.fill: parent
          source: root.artUrl
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: true
          smooth: true
          visible: status === Image.Ready
          opacity: status === Image.Ready ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }

        Text {
          anchors.centerIn: parent
          visible: root.artUrl === ""
          text: "󰝚"
          color: root.bar.barForeground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      // Dim the art while paused so the bar reads at a glance.
      Rectangle {
        anchors.fill: parent
        radius: thumbClip.radius
        color: Util.alpha(Color.background, 0.55)
        visible: !root.playing
      }
    }

    // Four dancing bars while playing, a pause glyph while not.
    Item {
      id: meter
      anchors.verticalCenter: parent.verticalCenter
      // 4 bars of 2px with 2px gaps — sized so the equalizer never clips.
      width: Style.space(14)
      height: Style.space(12)

      Row {
        anchors.centerIn: parent
        spacing: Style.space(2)
        visible: root.playing

        Repeater {
          model: [0, 160, 80, 240]

          Item {
            required property int modelData

            width: Style.space(2)
            height: Style.space(11)

            Rectangle {
              anchors.bottom: parent.bottom
              width: parent.width
              radius: width / 2
              color: root.bar.barForeground
              height: Style.space(3)

              SequentialAnimation on height {
                running: root.playing && root.visible
                loops: Animation.Infinite
                PauseAnimation { duration: modelData }
                NumberAnimation { to: Style.space(11); duration: 380; easing.type: Easing.InOutSine }
                NumberAnimation { to: Style.space(3); duration: 380; easing.type: Easing.InOutSine }
                NumberAnimation { to: Style.space(7); duration: 260; easing.type: Easing.InOutSine }
                NumberAnimation { to: Style.space(3); duration: 300; easing.type: Easing.InOutSine }
              }
            }
          }
        }
      }

      Text {
        anchors.centerIn: parent
        visible: !root.playing
        text: "󰏤"
        color: Qt.darker(root.bar.barForeground, 1.5)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
        Behavior on color {
          enabled: !root.bar || root.bar.foregroundAnimationEnabled
          ColorAnimation { duration: 160 }
        }
      }
    }

    Item {
      id: scrollClip
      width: Math.min(root.maxLabelWidth, labelText.implicitWidth)
      height: meter.height
      clip: true
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.bar.vertical && root.title !== ""

      Text {
        id: labelText
        text: root.title + (root.artist ? "  ·  " + root.artist : "")
        color: root.bar.barForeground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
        anchors.verticalCenter: parent.verticalCenter

        property bool needsScroll: implicitWidth > scrollClip.width

        NumberAnimation on x {
          id: scrollAnim
          running: labelText.needsScroll && !root.popupOpen && !root.bar.vertical
          loops: Animation.Infinite
          duration: Math.max(6000, labelText.implicitWidth * 25)
          from: scrollClip.width
          to: -labelText.implicitWidth
          easing.type: Easing.Linear
          onRunningChanged: if (!running) labelText.x = 0
        }
      }
    }
  }

  MouseArea {
    id: stripMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.activePlayer ? Qt.PointingHandCursor : Qt.ArrowCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: function(mouse) {
      if (!root.activePlayer) return
      if (mouse.button === Qt.MiddleButton) root.act("next")
      else if (mouse.button === Qt.RightButton) {
        if (root.activePlayer.canRaise) root.activePlayer.raise()
      } else root.act("playPause")
    }
    onWheel: function(wheel) {
      if (!root.activePlayer) return
      root.act(wheel.angleDelta.y > 0 ? "previous" : "next")
    }
    onEntered: {
      root.widgetHovered = true
      closeTimer.stop()
      openTimer.restart()
    }
    onExited: {
      root.widgetHovered = false
      openTimer.stop()
      closeTimer.restart()
    }
  }

  // Hover in/out grace. The open delay keeps the card from flashing when the
  // pointer merely crosses the bar; the close delay covers the gap the
  // pointer has to traverse between the bar and the card.
  Timer {
    id: openTimer
    interval: root.hoverDelay
    onTriggered: if (root.widgetHovered && root.hasMedia) root.popupOpen = true
  }

  Timer {
    id: closeTimer
    interval: 260
    onTriggered: if (!root.widgetHovered && !popup.containsMouse) root.popupOpen = false
  }

  Connections {
    target: popup
    function onContainsMouseChanged() {
      if (popup.containsMouse) closeTimer.stop()
      else if (!root.widgetHovered) closeTimer.restart()
    }
  }

  // MPRIS position is a pull property — nudge it while the card is visible.
  Timer {
    running: root.popupOpen && root.playing && !seekBar.dragging
    interval: 500
    repeat: true
    onTriggered: if (root.activePlayer) root.activePlayer.positionChanged()
  }

  onHasMediaChanged: if (!hasMedia) popupOpen = false

  // ------------------------------------------------------------ hover card

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    triggerMode: "hover"
    contentWidth: popup.fittedContentWidth(Style.space(348))
    contentHeight: popup.fittedContentHeight(card.implicitHeight)

    Item {
      anchors.fill: parent
      clip: true

      // A heavily downscaled copy of the cover art, stretched back out: a
      // cheap, shader-free color wash that tints the card to the album.
      Image {
        anchors.fill: parent
        source: root.artUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        sourceSize.width: 14
        sourceSize.height: 14
        opacity: status === Image.Ready ? 0.20 : 0
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
      }

      Column {
        id: card
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        // ---------------------------------------------------- header

        Row {
          width: parent.width
          spacing: Style.space(12)

          Item {
            id: cover
            width: Style.space(84)
            height: Style.space(84)
            anchors.verticalCenter: parent.verticalCenter

            // Soft bloom behind the sleeve, brighter while playing.
            Image {
              anchors.centerIn: parent
              width: parent.width * 1.18
              height: parent.height * 1.18
              source: root.artUrl
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              smooth: true
              sourceSize.width: 10
              sourceSize.height: 10
              opacity: status === Image.Ready ? (root.playing ? 0.55 : 0.25) : 0
              Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }

            Rectangle {
              id: sleeve
              anchors.fill: parent
              radius: Style.space(12)
              color: Util.alpha(root.fg, 0.06)
              border.width: 1
              border.color: Util.alpha(root.accent, root.playing ? 0.55 : 0.25)
              clip: true
              scale: coverMouse.containsMouse ? 1.04 : 1.0

              Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
              Behavior on border.color { ColorAnimation { duration: 300 } }

              Image {
                anchors.fill: parent
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
              }

              Text {
                anchors.centerIn: parent
                visible: root.artUrl === ""
                text: "󰝚"
                color: root.fgFaint
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.displayLarge
              }
            }

            MouseArea {
              id: coverMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: root.activePlayer && root.activePlayer.canRaise ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: if (root.activePlayer && root.activePlayer.canRaise) root.activePlayer.raise()
            }
          }

          Column {
            width: parent.width - cover.width - Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(3)

            // Source pill — which app this card is driving right now.
            Rectangle {
              visible: root.sourceName !== ""
              width: sourceLabel.implicitWidth + Style.space(14)
              height: sourceLabel.implicitHeight + Style.space(6)
              radius: height / 2
              color: Util.alpha(root.accent, 0.16)
              border.width: 1
              border.color: Util.alpha(root.accent, 0.35)

              Text {
                id: sourceLabel
                anchors.centerIn: parent
                text: root.sourceName
                color: root.accent
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Item { width: 1; height: Style.space(3) }

            Text {
              text: root.title || "Nothing playing"
              color: root.fg
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
              elide: Text.ElideRight
              maximumLineCount: 2
              wrapMode: Text.WordWrap
              width: parent.width
            }

            Text {
              text: root.artist
              color: root.fgSoft
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              width: parent.width
              visible: text !== ""
            }

            Text {
              text: root.album
              color: root.fgFaint
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
              visible: text !== ""
            }
          }
        }

        // ---------------------------------------------------- seek bar

        Column {
          id: seekBar
          width: parent.width
          spacing: Style.space(5)
          visible: root.activePlayer && root.activePlayer.lengthSupported && root.seconds(root.activePlayer.length) > 0

          property bool dragging: false
          property real dragRatio: 0
          readonly property real length: root.activePlayer ? root.seconds(root.activePlayer.length) : 0
          readonly property real position: root.activePlayer ? root.seconds(root.activePlayer.position) : 0
          readonly property real ratio: dragging
            ? dragRatio
            : (length > 0 ? Util.clamp(position / length, 0, 1) : 0)
          readonly property bool seekable: root.activePlayer ? !!root.activePlayer.canSeek : false

          Item {
            width: parent.width
            height: Style.space(14)

            Rectangle {
              id: track
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width
              height: Style.space(4)
              radius: height / 2
              color: Util.alpha(root.fg, 0.14)

              Rectangle {
                width: Math.max(0, Math.min(parent.width, parent.width * seekBar.ratio))
                height: parent.height
                radius: parent.radius
                color: root.accent

                Behavior on width {
                  enabled: !seekBar.dragging
                  NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                }
              }
            }

            // Knob appears on hover, so the bar stays a clean line at rest.
            Rectangle {
              width: Style.space(10)
              height: width
              radius: width / 2
              color: root.accent
              anchors.verticalCenter: track.verticalCenter
              x: Math.max(0, Math.min(track.width, track.width * seekBar.ratio)) - width / 2
              opacity: seekBar.seekable && (seekMouse.containsMouse || seekBar.dragging) ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: 140 } }
            }

            MouseArea {
              id: seekMouse
              anchors.fill: parent
              hoverEnabled: true
              enabled: seekBar.seekable
              cursorShape: seekBar.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor

              function ratioAt(x) { return Util.clamp(x / Math.max(1, track.width), 0, 1) }

              onPressed: function(mouse) {
                seekBar.dragRatio = ratioAt(mouse.x)
                seekBar.dragging = true
              }
              onPositionChanged: function(mouse) {
                if (seekBar.dragging) seekBar.dragRatio = ratioAt(mouse.x)
              }
              onReleased: function(mouse) {
                var target = ratioAt(mouse.x) * seekBar.length
                seekBar.dragging = false
                if (root.activePlayer) root.activePlayer.position = target
              }
              onCanceled: seekBar.dragging = false
            }
          }

          Item {
            width: parent.width
            height: elapsed.implicitHeight

            Text {
              id: elapsed
              anchors.left: parent.left
              text: root.clockText(seekBar.dragging ? seekBar.dragRatio * seekBar.length : seekBar.position)
              color: root.fgSoft
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              anchors.right: parent.right
              text: root.clockText(seekBar.length)
              color: root.fgFaint
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        // ---------------------------------------------------- transport

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(4)

          // Shuffle
          MediaIconButton {
            glyph: "󰒟"
            size: Style.space(30)
            fontSize: Style.font.body
            tint: root.activePlayer && root.activePlayer.shuffle ? root.accent : root.fgSoft
            active: root.activePlayer ? !!root.activePlayer.shuffle : false
            enabled: root.activePlayer ? !!root.activePlayer.shuffleSupported : false
            onTriggered: root.activePlayer.shuffle = !root.activePlayer.shuffle
          }

          MediaIconButton {
            glyph: "󰒮"
            size: Style.space(34)
            fontSize: Style.font.iconLarge
            tint: root.fg
            enabled: root.activePlayer ? !!root.activePlayer.canGoPrevious : false
            onTriggered: root.act("previous", root.mediaService.playerKey(root.activePlayer))
          }

          // The big one.
          MediaIconButton {
            glyph: root.playing ? "󰏤" : "󰐊"
            size: Style.space(44)
            fontSize: Style.font.display
            filled: true
            tint: Color.background
            enabled: root.activePlayer
              && (root.activePlayer.canTogglePlaying || root.activePlayer.canPlay || root.activePlayer.canPause)
            onTriggered: root.act("playPause", root.mediaService.playerKey(root.activePlayer))
          }

          MediaIconButton {
            glyph: "󰒭"
            size: Style.space(34)
            fontSize: Style.font.iconLarge
            tint: root.fg
            enabled: root.activePlayer ? !!root.activePlayer.canGoNext : false
            onTriggered: root.act("next", root.mediaService.playerKey(root.activePlayer))
          }

          // Loop: off -> playlist -> track -> off
          MediaIconButton {
            readonly property int loop: root.activePlayer ? root.activePlayer.loopState : MprisLoopState.None
            glyph: loop === MprisLoopState.Track ? "󰑘" : "󰑖"
            size: Style.space(30)
            fontSize: Style.font.body
            tint: loop === MprisLoopState.None ? root.fgSoft : root.accent
            active: loop !== MprisLoopState.None
            enabled: root.activePlayer ? !!root.activePlayer.loopSupported : false
            onTriggered: {
              if (loop === MprisLoopState.None) root.activePlayer.loopState = MprisLoopState.Playlist
              else if (loop === MprisLoopState.Playlist) root.activePlayer.loopState = MprisLoopState.Track
              else root.activePlayer.loopState = MprisLoopState.None
            }
          }
        }

        // ---------------------------------------------------- sources

        PanelSeparator {
          visible: root.sourcePlayers.length > 1
          foreground: root.fg
        }

        Text {
          visible: root.sourcePlayers.length > 1
          text: "Sources"
          color: root.fgFaint
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        Column {
          id: sourceList
          visible: root.sourcePlayers.length > 1
          width: parent.width
          spacing: Style.space(3)

          Repeater {
            model: root.sourcePlayers

            Rectangle {
              id: sourceRow
              required property var modelData

              readonly property var player: modelData
              readonly property bool selected: root.activePlayer && player && root.mediaService
                && root.mediaService.playerKey(root.activePlayer) === root.mediaService.playerKey(player)
              readonly property string appName: player ? (player.identity || player.desktopEntry || "Media") : "Media"
              readonly property string trackLine: player
                ? (player.trackTitle || player.identity || "Nothing queued")
                : ""
              readonly property string artLine: player && player.trackArtist ? player.trackArtist : ""

              width: sourceList.width
              height: sourceInner.implicitHeight + Style.space(12)
              radius: Style.space(9)
              color: selected
                ? Util.alpha(root.accent, 0.16)
                : (rowMouse.containsMouse ? Util.alpha(root.fg, 0.07) : "transparent")
              border.width: 1
              border.color: selected ? Util.alpha(root.accent, 0.4) : "transparent"

              Behavior on color { ColorAnimation { duration: 140 } }

              Row {
                id: sourceInner
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(6)
                spacing: Style.space(9)

                Rectangle {
                  width: Style.space(30)
                  height: Style.space(30)
                  radius: Style.space(6)
                  anchors.verticalCenter: parent.verticalCenter
                  color: Util.alpha(root.fg, 0.08)
                  clip: true

                  Image {
                    anchors.fill: parent
                    source: sourceRow.player && sourceRow.player.trackArtUrl ? sourceRow.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    visible: status === Image.Ready
                  }

                  Text {
                    anchors.centerIn: parent
                    visible: !sourceRow.player || !sourceRow.player.trackArtUrl
                    text: "󰝚"
                    color: root.fgFaint
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                }

                Column {
                  width: parent.width - Style.space(30) - Style.space(32) - Style.space(18)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(1)

                  Text {
                    text: sourceRow.appName
                    color: sourceRow.selected ? root.accent : root.fgSoft
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width
                  }

                  Text {
                    text: sourceRow.trackLine + (sourceRow.artLine ? "  ·  " + sourceRow.artLine : "")
                    color: root.fg
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    elide: Text.ElideRight
                    width: parent.width
                  }
                }

                // Per-source play/pause: resumes that app and pauses whoever
                // was holding the speakers.
                MediaIconButton {
                  anchors.verticalCenter: parent.verticalCenter
                  glyph: sourceRow.player && sourceRow.player.isPlaying ? "󰏤" : "󰐊"
                  size: Style.space(28)
                  fontSize: Style.font.body
                  tint: sourceRow.player && sourceRow.player.isPlaying ? root.accent : root.fgSoft
                  onTriggered: root.takeOver(sourceRow.player)
                }
              }

              MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                z: -1
                onClicked: if (root.mediaService)
                  root.mediaService.selectPlayer(root.mediaService.playerKey(sourceRow.player))
              }
            }
          }
        }
      }
    }
  }

  // Round, springy transport button. Kept local so the card can have its own
  // shape language without touching the shared Ui kit.
  component MediaIconButton: Rectangle {
    id: btn

    property string glyph: ""
    property real size: Style.space(32)
    property real fontSize: Style.font.icon
    property color tint: root.fg
    property bool filled: false
    property bool active: false

    signal triggered()

    width: size
    height: size
    radius: size / 2
    opacity: enabled ? 1.0 : 0.32
    color: filled
      ? (btnMouse.containsMouse ? Qt.lighter(root.accent, 1.15) : root.accent)
      : (btnMouse.containsMouse ? Util.alpha(root.fg, 0.12)
                                : (active ? Util.alpha(root.accent, 0.14) : "transparent"))
    scale: btnMouse.pressed ? 0.92 : (btnMouse.containsMouse ? 1.08 : 1.0)

    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
    Behavior on opacity { NumberAnimation { duration: 160 } }

    Text {
      anchors.centerIn: parent
      text: btn.glyph
      color: btn.tint
      font.family: root.bar.fontFamily
      font.pixelSize: btn.fontSize
    }

    MouseArea {
      id: btnMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: btn.triggered()
    }
  }
}
