//@ pragma UseQApplication

import Quickshell
import qs.IdleApp

// Start with:
//   qs -p ~/.local/share/ml4w-idle-settings
// Control over IPC:
//   qs -p ~/.local/share/ml4w-idle-settings ipc call idle toggle
ShellRoot {
    IdleWindow {}
}
