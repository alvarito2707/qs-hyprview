import QtQuick
import Quickshell
import './modules'

ShellRoot {
  Hyprview {
    // scegli il layout: 'smartgrid', 'justified', 'bands', 'masonry', 'spiral', 'hero'
    layoutAlgorithm: "hero"
    liveCapture: false
    moveCursorToActiveWindow: false
  }
}
