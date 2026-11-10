import QtQuick
import qs.Ui
import qs.Commons

// Drop-in replacement for omarchy.menu's bar widget: same click behaviour,
// but painted with the Rebel Alliance starbird (nf-fa-rebel, U+F1D0) instead
// of the omarchy mark. The stock omarchy.menu plugin stays installed and keeps
// receiving updates — it just no longer puts its own button on the bar.
BarWidget {
  id: root
  moduleName: "lrpineda.rebel-menu"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    fontFamily: "JetBrainsMono Nerd Font"
    // The starbird is a touch lighter than the omarchy mark at the same size.
    fontSize: Style.font.body * 1.15
    horizontalMargin: 7.5
    onPressed: function(button) {
      if (!root.bar) return
      if (button === Qt.RightButton) root.bar.run("xdg-terminal-exec")
      else root.bar.run("omarchy-shell shell toggle omarchy.menu '{\"menu\":\"root\"}'")
    }
  }
}
