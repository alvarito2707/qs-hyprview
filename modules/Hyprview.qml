import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects
import '../layouts'
import '.'

PanelWindow {
    id: root

    // --- CONFIGURAZIONE ---
    property string layoutAlgorithm: ""
    property string lastLayoutAlgorithm: ""
    property bool liveCapture: false
    property bool moveCursorToActiveWindow: false

    // --- STATO INTERNO ---
    property bool isActive: false
    property bool specialActive: false
    property bool animateWindows: false
    property var lastPositions: {}

    // Configurazione Finestra
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: isActive

    // LayerShell Config
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1 // Occupa tutto lo schermo sopra le app
    WlrLayershell.keyboardFocus: isActive ? 1 : 0
    WlrLayershell.namespace: "quickshell:expose"

    // --- IPC & EVENTI ---

    IpcHandler {
        target: "expose"
        function toggle(layout: string) {
            root.layoutAlgorithm = layout
            root.toggleExpose()
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            // Ascoltiamo eventi solo se attivi o per monitorare lo special workspace
            if (!root.isActive && ev.name !== "activespecial") return

            switch (ev.name) {
                case "openwindow":
                case "closewindow":
                case "changefloatingmode":
                case "movewindow":
                    Hyprland.refreshToplevels()
                    refreshThumbs()
                    return

                case "activespecial":
                    var dataStr = String(ev.data)
                    var namePart = dataStr.split(",")[0]
                    root.specialActive = (namePart.length > 0)
                    return

                default:
                    return
            }
        }
    }

    // Timer per aggiornare le miniature (se liveCapture è false)
    Timer {
        id: screencopyTimer
        interval: 125
        repeat: true
        running: !root.liveCapture && root.isActive
        onTriggered: root.refreshThumbs()
    }

    // --- LOGICA FUNZIONALE ---

    function toggleExpose() {
        root.isActive = !root.isActive
        if (root.isActive) {
            if (root.layoutAlgorithm === 'random') {
                var layouts = ['justified', 'bands', 'masonry', 'spiral', 'hero', 'smartgrid'].filter((l) => l !== root.lastLayoutAlgorithm)
                var randomLayout = layouts[Math.floor(Math.random() * layouts.length)]
                root.lastLayoutAlgorithm = randomLayout
            } else {
                root.lastLayoutAlgorithm = root.layoutAlgorithm
            }

            console.log(root.layoutAlgorithm, root.lastLayoutAlgorithm)

            exposeArea.currentIndex = 0
            exposeArea.searchText = ""
            Hyprland.refreshToplevels()
            searchInput.forceActiveFocus()
            refreshThumbs()
        } else {
            root.animateWindows = false
            root.lastPositions = {}
        }
    }

    function refreshThumbs() {
        if (!root.isActive) return
        for (var i = 0; i < winRepeater.count; ++i) {
            var it = winRepeater.itemAt(i)
            if (it && it.visible && it.refreshThumb) {
                it.refreshThumb()
            }
        }
    }

    // --- INTERFACCIA UTENTE ---

    FocusScope {
        id: mainScope
        anchors.fill: parent
        focus: true

        // Gestione Tastiera (Navigazione)
        Keys.onPressed: (event) => {
            if (!root.isActive) return

            // ESC: Chiudi
            if (event.key === Qt.Key_Escape) {
                root.toggleExpose()
                event.accepted = true
                return
            }

            const total = winRepeater.count
            if (total <= 0) return

            // Funzione helper navigazione orizzontale
            function moveSelectionHorizontal(delta) {
                var start = exposeArea.currentIndex
                for (var step = 1; step <= total; ++step) {
                    var candidate = (start + delta * step + total) % total
                    var it = winRepeater.itemAt(candidate)
                    if (it && it.visible) {
                        exposeArea.currentIndex = candidate
                        return
                    }
                }
            }

            // Funzione helper navigazione spaziale (Su/Giù)
            function moveSelectionVertical(dir) {
                var startIndex = exposeArea.currentIndex
                var currentItem = winRepeater.itemAt(startIndex)

                if (!currentItem || !currentItem.visible) {
                    moveSelectionHorizontal(dir > 0 ? 1 : -1)
                    return
                }

                var curCx = currentItem.x + currentItem.width  / 2
                var curCy = currentItem.y + currentItem.height / 2

                var bestIndex = -1
                var bestDy = 99999999
                var bestDx = 99999999

                for (var i = 0; i < total; ++i) {
                    var it = winRepeater.itemAt(i)
                    if (!it || !it.visible || i === startIndex) continue

                    var cx = it.x + it.width  / 2
                    var cy = it.y + it.height / 2
                    var dy = cy - curCy

                    // Filtra direzione
                    if (dir > 0 && dy <= 0) continue // Cercavamo giù, ma è sopra
                    if (dir < 0 && dy >= 0) continue // Cercavamo su, ma è sotto

                    var absDy = Math.abs(dy)
                    var absDx = Math.abs(cx - curCx)

                    // Cerca il più vicino (privilegiando vicinanza verticale, poi orizzontale)
                    if (absDy < bestDy || (absDy === bestDy && absDx < bestDx)) {
                        bestDy = absDy
                        bestDx = absDx
                        bestIndex = i
                    }
                }

                if (bestIndex >= 0) {
                    exposeArea.currentIndex = bestIndex
                }
            }

            // Mapping Tasti
            if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                moveSelectionHorizontal(1)
                event.accepted = true
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
                moveSelectionHorizontal(-1)
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                moveSelectionVertical(1)
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                moveSelectionVertical(-1)
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                var item = winRepeater.itemAt(exposeArea.currentIndex)
                if (item && item.activateWindow) {
                    item.activateWindow()
                    event.accepted = true
                }
            }
        }

        // Click sullo sfondo chiude
        MouseArea {
            anchors.fill: parent
            hoverEnabled: false
            z: -1
            onClicked: root.toggleExpose()
        }

        Item {
            id: layoutContainer
            anchors.fill: parent
            anchors.margins: 32

            Column {
                id: layoutRoot
                anchors.fill: parent
                anchors.margins: 48
                spacing: 20

                // AREA DELLE MINIATURE
                Item {
                    id: exposeArea
                    width: layoutRoot.width
                    height: layoutRoot.height - searchBox.implicitHeight - layoutRoot.spacing

                    property int currentIndex: 0
                    property string searchText: ""

                    // Quando cambia la ricerca, resetta la selezione
                    onSearchTextChanged: {
                        currentIndex = (windowLayoutModel.count > 0) ? 0 : -1
                    }

                    // --- FIX BINDING LOOP ---
                    // ScriptModel separato dal Repeater con proprietà "gate"
                    ScriptModel {
                        id: windowLayoutModel

                        // Proprietà Gate: isolano il binding loop
                        // Il modello si aggiorna SOLO se queste cambiano valore
                        property int areaW: exposeArea.width
                        property int areaH: exposeArea.height
                        property string query: exposeArea.searchText
                        property string algo: root.lastLayoutAlgorithm
                        property var rawToplevels: Hyprland.toplevels.values

                        values: {
                            // Validazione dimensioni
                            if (areaW <= 0 || areaH <= 0) return []

                            var q = (query || "").toLowerCase()
                            var windowList = []
                            var idx = 0

                            if (!rawToplevels) return []

                            for (var it of rawToplevels) {
                                var w = it
                                var clientInfo = w && w.lastIpcObject ? w.lastIpcObject : {}
                                var workspace = clientInfo && clientInfo.workspace ? clientInfo.workspace : null
                                var workspaceId = workspace && workspace.id !== undefined ? workspace.id : undefined

                                // Filtra workspace non validi o finestre off-screen
                                if (workspaceId === undefined || workspaceId === null) continue
                                var size = clientInfo && clientInfo.size ? clientInfo.size : [0, 0]
                                var at = clientInfo && clientInfo.at ? clientInfo.at : [-1000, -1000]
                                if (at[1] + size[1] <= 0) continue

                                // Filtra Testo
                                var title = (w.title || clientInfo.title || "").toLowerCase()
                                var clazz = (clientInfo["class"] || "").toLowerCase()
                                var ic = (clientInfo.initialClass || "").toLowerCase()
                                var app = (w.appId || clientInfo.initialClass || "").toLowerCase()

                                if (q.length > 0) {
                                    var match = title.indexOf(q) !== -1 || clazz.indexOf(q) !== -1 ||
                                                ic.indexOf(q) !== -1 || app.indexOf(q) !== -1
                                    if (!match) continue
                                }

                                windowList.push({
                                    win: w,
                                    clientInfo: clientInfo,
                                    workspaceId: workspaceId,
                                    width: size[0],
                                    height: size[1],
                                    originalIndex: idx++,
                                    lastIpcObject: w.lastIpcObject
                                })
                            }

                            // Ordinamento
                            windowList.sort(function(a, b) {
                                if (a.workspaceId < b.workspaceId) return -1
                                if (a.workspaceId > b.workspaceId) return 1
                                if (a.originalIndex < b.originalIndex) return -1
                                if (a.originalIndex > b.originalIndex) return 1
                                return 0
                            })

                            // Layout
                            // Nota: LayoutsManager deve essere un Singleton importato o un file js
                            return LayoutsManager.doLayout(algo, windowList, areaW, areaH)
                        }
                    }

                    Repeater {
                        id: winRepeater
                        model: windowLayoutModel

                        delegate: WindowMiniature {
                            // Dati dal modello
                            hWin: modelData.win
                            wHandle: hWin.wayland
                            winKey: String(hWin.address)
                            thumbW: modelData.width
                            thumbH: modelData.height
                            clientInfo: hWin.lastIpcObject

                            // Coordinate calcolate
                            targetX: modelData.x
                            targetY: modelData.y

                            // Stato Interattivo
                            hovered: visible && (exposeArea.currentIndex === index)
                            moveCursorToActiveWindow: root.moveCursorToActiveWindow
                        }
                    }
                }

                // BARRA DI RICERCA
                Rectangle {
                    id: searchBox
                    width: Math.min(layoutRoot.width * 0.6, 480)
                    height: 40
                    radius: 20
                    color: "#66000000"
                    border.width: 1
                    border.color: "#33ffffff"
                    anchors.horizontalCenter: parent.horizontalCenter

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        verticalAlignment: TextInput.AlignVCenter
                        color: "white"
                        font.pixelSize: 16
                        text: exposeArea.searchText
                        activeFocusOnTab: false
                        selectByMouse: true

                        // Aggiorna la proprietà di exposeArea
                        onTextChanged: {
                            exposeArea.searchText = text
                            root.animateWindows = true
                        }

                        // Previene che i tasti di navigazione muovano il cursore testo
                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Left   || event.key === Qt.Key_Right  ||
                                event.key === Qt.Key_Up     || event.key === Qt.Key_Down   ||
                                event.key === Qt.Key_Return || event.key === Qt.Key_Enter  ||
                                event.key === Qt.Key_Tab    || event.key === Qt.Key_Backtab) {
                                event.accepted = false // Lascia gestire al FocusScope padre
                            } else {
                                root.animateWindows = true
                            }
                        }

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            color: "#88ffffff"
                            font.pixelSize: 14
                            text: "Type to filter windows..."
                            visible: !searchInput.text || searchInput.text.length === 0
                        }
                    }
                }
            }
        }
    }
}
