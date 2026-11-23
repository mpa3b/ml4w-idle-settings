pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Colors follow the same Material-role JSON the power menu uses, so this panel
// recolors with the rest of the shell when matugen rewrites colors.json.
Singleton {
    id: root

    readonly property var defaultColors: ({
        "background": "#111318",
        "on_background": "#e1e2e9",
        "surface_container": "#1d2024",
        "on_surface": "#e1e2e9",
        "on_surface_variant": "#c3c6cf",
        "primary": "#a4c9fe",
        "on_primary": "#00315c",
        "error": "#ffb4ab",
        "outline": "#8d9199",
        "shadow": "#000000"
    })

    property color background: defaultColors.background
    property color onBackground: defaultColors.on_background
    property color surfaceContainer: defaultColors.surface_container
    property color onSurface: defaultColors.on_surface
    property color onSurfaceVariant: defaultColors.on_surface_variant
    property color primary: defaultColors.primary
    property color onPrimary: defaultColors.on_primary
    property color error: defaultColors.error
    property color outline: defaultColors.outline
    property color shadow: defaultColors.shadow

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string colorsFile: home + "/.config/ml4w-powermenu/colors.json"
    readonly property string opacityFile: home + "/.config/ml4w/settings/quickshell-opacity"

    // 0-100 from the ML4W opacity slider; -1 means "not set", so the panel's
    // own default applies. Kept in one place so the card and its shadow agree.
    property int globalOpacity: -1
    readonly property real cardOpacity: globalOpacity >= 0 ? globalOpacity / 100 : 0.96

    function applyColors(text): void {
        let parsed = {}
        if (text && text.trim() !== "") {
            try {
                parsed = JSON.parse(text)
            } catch (e) {
                console.warn("idle settings theme: could not parse", colorsFile, e)
            }
        }
        for (let key in root.defaultColors) {
            const value = typeof parsed[key] === "string" && parsed[key] !== ""
                ? parsed[key] : root.defaultColors[key]
            switch (key) {
                case "background": root.background = value; break
                case "on_background": root.onBackground = value; break
                case "surface_container": root.surfaceContainer = value; break
                case "on_surface": root.onSurface = value; break
                case "on_surface_variant": root.onSurfaceVariant = value; break
                case "primary": root.primary = value; break
                case "on_primary": root.onPrimary = value; break
                case "error": root.error = value; break
                case "outline": root.outline = value; break
                case "shadow": root.shadow = value; break
            }
        }
    }

    FileView {
        id: colorsView
        path: root.colorsFile
        watchChanges: true
        printErrors: false
        onFileChanged: colorsView.reload()
        onLoaded: root.applyColors(colorsView.text())
        onLoadFailed: root.applyColors("")
    }

    FileView {
        id: opacityView
        path: root.opacityFile
        watchChanges: true
        printErrors: false
        onFileChanged: opacityView.reload()
        onLoaded: {
            const value = parseInt(opacityView.text().trim())
            root.globalOpacity = isNaN(value) ? -1 : Math.max(0, Math.min(100, value))
        }
        onLoadFailed: root.globalOpacity = -1
    }
}
