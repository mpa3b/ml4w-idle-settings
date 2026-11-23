# Idle timers panel (Quickshell)

A small modal panel for Hyprland that controls hypridle's four idle timers. It
lives outside the ML4W dotfiles profile so dotfiles updates do not remove it.

## What it does

For each timer — dim the screen, lock the screen, switch the display off (DPMS),
and suspend — the panel shows:

- an **on/off switch** that comments out the whole listener in `hypridle.conf`,
  so e.g. the lock screen or suspend can be disabled completely;
- a **± 5 minutes** stepper;
- an **input field** where an exact number of minutes can be typed.

Changes are staged until **Применить** is pressed; then all four timers are
written to `~/.config/hypr/hypridle.conf` in one pass and hypridle is restarted.
**Сбросить** restores 8 / 10 / 11 / 30 minutes with all timers enabled.

Separate switches control the runtime state (these act immediately):

- **hypridle** — start or stop the idle daemon entirely;
- **Caffeine** — hold a logind idle inhibitor (same state as SUPER + F8).

The panel reads its colors from the same `~/.config/ml4w-powermenu/colors.json`
as the ML4W power menu, so it follows the shell theme.

## Installation

The repository is private, so authenticate git with GitHub once before the
first install (`gh auth login && gh auth setup-git`, or configure a PAT).

```bash
git clone https://github.com/mpa3b/ml4w-idle-settings.git /tmp/ml4w-idle-settings
bash /tmp/ml4w-idle-settings/install.sh
```

The script clones the repo into `~/.local/share/ml4w-idle-settings` and links
`ml4w-idle-settings` into `~/.local/bin`. Running it again updates an existing
clone. To remove the panel:

```bash
bash ~/.local/share/ml4w-idle-settings/uninstall.sh
```

Add the keybinding and autostart to your Hyprland config:

```lua
hl.bind("SUPER + SHIFT + F8", hl.dsp.exec_cmd("~/.local/bin/ml4w-idle-settings toggle"), { description = "Idle timers settings" })
hl.on("hyprland.start", function()
    hl.exec_cmd("~/.local/bin/ml4w-idle-settings")
end)
```

## Usage

```bash
~/.local/bin/ml4w-idle-settings            # start (also started from Hyprland)
~/.local/bin/ml4w-idle-settings toggle     # show/hide
~/.local/bin/ml4w-idle-settings open
~/.local/bin/ml4w-idle-settings close
```

Keybinding: **SUPER + SHIFT + F8**. Escape or a click outside closes the panel.

The helper `IdleApp/idleconf.py` can also be used directly:

```bash
python3 IdleApp/idleconf.py get
HYPRIDLE_CONF=/tmp/test.conf python3 IdleApp/idleconf.py set-many \
  '{"dim":{"seconds":300,"enabled":true},"lock":{"seconds":600,"enabled":false},"screenOff":{"seconds":480,"enabled":true},"suspend":{"seconds":1800,"enabled":false}}'
```

`HYPRIDLE_CONF` overrides the config path; no other settings are needed.
