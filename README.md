# TCPView for macOS

A native macOS network monitoring tool inspired by [Sysinternals TCPView](https://learn.microsoft.com/en-us/sysinternals/downloads/tcpview) for Windows. Displays all active TCP and UDP connections on your system with real-time updates, process information, and connection management.

Built with SwiftUI. Zero external dependencies.

![macOS](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Real-time connection monitoring** — View all TCP/UDP (IPv4 and IPv6) endpoints with automatic refresh (1s, 2s, 5s, or paused)
- **Color-coded updates** — New connections highlight green, state changes yellow, closing connections red
- **Sortable & searchable table** — Sort by any column, search across process name, address, port, or state
- **DNS resolution** — Toggle reverse DNS lookup for IP addresses
- **Process management** — Kill or force-kill processes directly from the context menu (with admin elevation when needed)
- **WHOIS lookup** — Look up remote IP ownership inline or in browser
- **Process info** — View full path, bundle ID, and open in Finder or Activity Monitor
- **Export** — Save connection list as CSV or JSON
- **Filters** — Toggle listening endpoints and IPv6 connections
- **Dark mode** — Fully supported via native SwiftUI
- **Keyboard shortcuts** — Cmd+R (refresh), Cmd+D (DNS toggle), Cmd+F (search)

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+ (to build from source)

## Build & Run

```bash
# Clone the repository
git clone https://github.com/yourusername/tcpview-macos.git
cd tcpview-macos

# Generate Xcode project (requires xcodegen)
xcodegen generate

# Build
xcodebuild -project TCPViewMac.xcodeproj -scheme TCPViewMac -configuration Release build

# Or open in Xcode and press Cmd+R
open TCPViewMac.xcodeproj
```

If you don't have `xcodegen`, install it with:

```bash
brew install xcodegen
```

## Usage

Launch the app. It immediately begins enumerating all network connections on your system.

| Action | How |
|--------|-----|
| **Sort** | Click any column header |
| **Search** | Type in the toolbar search field |
| **Refresh** | Cmd+R or click the refresh button |
| **Pause/Resume** | Click the pause button or change refresh rate |
| **DNS resolution** | Toggle the DNS button in the toolbar |
| **Kill a process** | Right-click a connection → Kill Process |
| **WHOIS** | Right-click a connection → Whois |
| **Export** | File → Export to CSV / JSON |

### Permissions

The app runs without admin privileges by default. In this mode, only your user's processes are visible (the status bar shows a "Limited visibility" warning).

To see all system connections, run with elevated privileges — the app will prompt for your admin password when you attempt to kill a process you don't own.

## Project Structure

```
TCPViewMac/
├── App/                  # App entry point
├── Models/               # NetworkConnection, TCPState, ConnectionSnapshot
├── Services/             # LibProcBridge (C interop), ConnectionMonitor, DNSResolver,
│                         #   WhoisService, ConnectionKiller, TrafficMonitor
├── ViewModels/           # ConnectionListViewModel, FilterState
├── Views/                # MainWindow, ConnectionTableView, Toolbar, StatusBar,
│                         #   WhoisSheet, ProcessInfoSheet
└── Utilities/            # CSV and JSON exporters
```

### How It Works

The app uses macOS `libproc` APIs directly via Swift C interop to enumerate network sockets:

1. `proc_listallpids()` — enumerates all process IDs
2. `proc_pidinfo(PROC_PIDLISTFDS)` — lists file descriptors per process
3. `proc_pidfdinfo(PROC_PIDFDSOCKETINFO)` — extracts socket details (addresses, ports, TCP state)

Connections are refreshed on a configurable interval. Each refresh diffs against the previous snapshot to determine color coding (new, changed, or closing).

## License

MIT License

Copyright (c) 2026 Mahatab Rashid

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
