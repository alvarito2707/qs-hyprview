# Quickshell Window Switcher

A modern, fluid, and highly customizable **Window Switcher (Exposé)** for **Hyprland**, built entirely in QML using the [Quickshell](https://github.com/outfoxxed/quickshell) framework.

It provides a native Wayland experience similar to macOS Mission Control or GNOME Activities, featuring advanced layout algorithms that mathematically optimize screen space usage.

![Main Screenshot](screenshots/preview.png)
*(Please add a real screenshot here)*

## ✨ Features

*   **⚡ Native Performance:** Built on Qt6/QML and Wayland Layershell for zero latency and smooth 60fps animations.
*   **🧮 6+1 Layout Algorithms:** A suite of mathematical layouts designed to fit windows perfectly on any screen size (details below).
*   **🔍 Instant Search:** Filter windows by title, class, or app name immediately upon typing.
*   **🎮 Full Navigation:** Supports both Keyboard (Arrows/Tab/Enter) and Mouse (Hover/Click).
*   **🎨 Smart Safe Area:** All layouts calculate a 90% "Safe Area" to ensure hover animations never clip against screen edges.
*   **⚙️ Live Thumbnails:** Optional support for live window contents (via Hyprland screencopy).

## 🛠️ Dependencies

*   **Hyprland**: The Wayland compositor.
*   **Quickshell**: The QML shell framework.
*   **Qt6**: Core libraries (usually pulled in by Quickshell).

## 🚀 Installation

1.  Clone this repository:
    ```bash
    git clone https://github.com/YOUR_USERNAME/quickshell-window-switcher.git
    cd quickshell-window-switcher
    ```

2.  Ensure `quickshell` is installed and in your PATH.

## ⚙️ Configuration & Usage

### Launching
To start the daemon (add this to your `hyprland.conf` with `exec-once`):

```bash
quickshell -p /path/to/cloned/repo
```

### Toggle (Open/Close)
The project exposes an IPC handler named `expose`. You can bind a key in Hyprland to toggle the view.

**In `hyprland.conf`:**
```ini
# Adjust the piping command based on your Quickshell IPC setup
bind = SUPER, Tab, exec, echo "expose.toggle()" | quickshell-ipc
```

### Customization
You can modify the core properties at the top of `PanelWindow.qml` (or `shell.qml`):

```qml
// Available: "smartgrid", "simplegrid", "masonry", "bands", "hero", "spiral", "random"
property string layoutAlgorithm: "smartgrid"

// Set to true for live window updates (higher CPU usage), false for static snapshots
property bool liveCapture: false

// Automatically move mouse cursor to the selected window
property bool moveCursorToActiveWindow: true
```

## 📐 Layout Algorithms

This project includes a sophisticated `LayoutsManager` with 6 distinct algorithms plus a randomizer.

### 1. Smart Grid (`smartgrid`)
The default layout. It uses an **Iterative Best-Fit** algorithm. It simulates every possible row/column combination to find the exact grid configuration that results in the largest possible thumbnails without overflowing the screen. Perfect for maximizing visibility.

### 2. Simple Grid (`simplegrid`)
A **Justified Layout** (similar to Google Images). It places windows in rows, maintaining their original aspect ratios, and scales the row to fit the screen width perfectly. Ideal if you have windows with very different shapes (e.g., tall terminals mixed with wide browsers).

### 3. Masonry (`masonry`)
A **Waterfall** layout (Pinterest-style). It optimizes vertical space by placing windows in dynamic columns.
*   *Smart Feature:* It iteratively calculates the minimum number of columns needed to fit all windows vertically within the screen height, ensuring thumbnails are as large as possible.

### 4. Bands (`bands`)
Organizes windows by **Workspace**.
*   Creates a horizontal "Band" for each active workspace.
*   Windows inside the band are justified and centered.
*   Great for visualizing your mental model of open tasks.

### 5. Hero (`hero`)
A focus-centric layout inspired by master/stack tiling.
*   **Hero Area:** The active window takes up 40% of the screen (left side).
*   **Stack:** All other windows share the remaining 60% (right side).
*   *Smart Stack:* The stack automatically switches between a single column and a grid depending on the number of windows, ensuring they remain readable.

### 6. Spiral (`spiral`)
A scenic layout based on the **Golden Ratio (BSP)**.
*   The first few windows (configurable) split the screen in a spiral pattern (Left half, Top-Right half, etc.).
*   The first window is visually separated by a larger gap to emphasize focus.
*   **Overflow Grid:** If you have many windows, the spiral stops after 3 cuts, and the remaining windows are neatly arranged in a grid in the final section.

### 7. Random (`random`)
Feeling adventurous? This mode selects one of the above algorithms at random every time you open the dashboard.

## ⌨️ Controls

| Input | Action |
| :--- | :--- |
| **Typing** | Instantly filters windows by Title, Class, or App ID |
| **Arrows (↑ ↓ ← →)** | Spatial navigation between thumbnails |
| **Tab / Shift+Tab** | Sequential navigation |
| **Enter** | Activate selected window |
| **Esc / Click BG** | Close dashboard |

## 🤝 Contributing

Pull Requests are welcome! If you want to add a new layout algorithm or improve performance, please open an issue or submit a PR.

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.
