<div align="center">

<img src="Assets/AppIcon-1024.png" alt="iGlance" width="180" />

# iGlance

### A lightweight macOS menu bar utility for monitoring your system at a glance.

[![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift&logoColor=white)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Release](https://img.shields.io/github/v/release/kuicao55/iGlance)](https://github.com/kuicao55/iGlance/releases)
[![Platform](https://img.shields.io/badge/platform-arm64%20%7C%20x86__64-lightgrey)](https://github.com/kuicao55/iGlance)

[Features](#-features) · [Installation](#-installation) · [Usage](#-usage) · [Build](#-build-from-source) · [Roadmap](#-roadmap) · [License](#-license)

</div>

---

## 👁️ What is iGlance?

**iGlance** lives quietly in your menu bar and shows you what your Mac is doing — CPU, GPU, memory, temperature — without opening Activity Monitor. Need to keep your machine awake during a long render? One click. Want to start and watch a headless service? One click. No Dock icon, no clutter, no waiting.

Designed native-first: pure **SwiftUI + AppKit**, no Electron, no web view, no dependencies.

---

## ✨ Features

### 📊 Monitor
- **CPU, GPU, Memory, Temperature** — real-time readings on a 2×2 grid of animated gauges
- **Real die temperatures** — CPU and GPU from AppleSMC (`TCMb` / `TRDX`) with an IOHID `PMU tdie` fallback; battery via the gas gauge
- **Sparkline charts** — 60-second rolling history per metric
- **Tap-to-flip cards** — click any card (except Temperature) for detailed history and top processes
- **Color-coded thresholds** — green / yellow / orange / red as load climbs

### 💤 Status
- **Prevent System Sleep** — holds an `IOPMAssertion` so your Mac won't nap mid-task
- **Prevent Display Sleep** — keeps the screen awake for presentations
- **SleepDisabled indicator** — see when *another* process is holding your Mac awake

### 🧩 Services
- **Bind headless services** — a name, a start command, and an optional API token; works with Gofer and anything else that speaks `iglance.service.v1`
- **Manifest handshake** — runs the command, reads its `IGLANCE_SERVICE_MANIFEST` line, and caches `base_url` + endpoints
- **Start / Stop / Pause / Resume** — drives the service over HTTP once it has introduced itself
- **Open Panel** — one click opens the service's own web UI in your default browser
- **Memory by group** — total RSS, per-group breakdown, and a rolling sparkline
- **Keychain tokens** — tokens never touch `UserDefaults` or the bindings file
- **Approval gate** — a command never runs until you tick *Allow iGlance to run this command*

### 🎯 Menu Bar
- **Dynamic load indicator** — a tiny arc on the menu bar icon grows with system load (weighted average of CPU/GPU/Memory/Temp)
- **Template-rendered** — automatically adapts to Light / Dark menu bar
- **Click to open** — popover anchors directly under the menu bar icon

### ⚙️ Settings
- **Software Update** — reads the latest GitHub release, shows the notes, and installs in place after verifying the bundle's identity and signature (with a rollback copy)
- **Orange badge** on the Settings tab when a newer release exists
- **Quit iGlance** — a visible exit button (⌘Q works there too); sleep assertions are released on the way out
- Update checks run at most once every 6 hours when the popover opens

### 🪟 The Look
- Liquid Glass surfaces on macOS 26, with a material fallback on macOS 14–15
- 400 × 545 fixed-size popover, one consistent 16pt padding rhythm
- Monitor, Status, Services, and Settings share one segmented glass bar
- 3D card flips, a morphing tab selection, and Reduce Motion support
- 2-second refresh interval, automatic cleanup of power assertions on quit

---

## 📦 Installation

### Download (recommended)

Grab the latest `.app.zip` from the [**Releases page**](https://github.com/kuicao55/iGlance/releases/latest), then:

```bash
# Unzip, then move to Applications
open ~/Downloads/iGlance.app.zip
cp -R ~/Downloads/iGlance.app /Applications/
open /Applications/iGlance.app
```

> First launch: macOS may ask you to confirm opening an app from the internet. Click **Open**. Releases are notarized when published with the Developer ID flow; see [docs/SIGNING.md](docs/SIGNING.md).

Once installed, open the popover and click **Settings** at the right of the segmented bar, then **Install Update**. iGlance downloads the latest release, verifies it, replaces itself, and relaunches.

### Build from source

Requires **macOS 14+** and **Swift 5.9+** (Xcode 15 / Command Line Tools).

```bash
git clone https://github.com/kuicao55/iGlance.git
cd iGlance
./build-app.sh
open .build/release/iGlance.app
```

`build-app.sh` compiles a release binary, assembles the `.app` bundle, embeds the icon, and ad-hoc code-signs the result. For distribution signing and notarization see [docs/SIGNING.md](docs/SIGNING.md).

#### Command-line build options

```bash
swift build                  # Debug build (fast, unoptimized)
swift build -c release       # Release build (optimized)
./build-app.sh               # Bundle the release build into iGlance.app
./build-app.sh --install     # Build and copy to /Applications
./build-app.sh --release     # Also produce dist/iGlance.app.zip for GitHub
./build-app.sh --notarize    # Developer ID sign, notarize, staple, and zip
```

`SIGN_IDENTITY` selects the signing identity (defaults to ad-hoc). Set
`NOTARY_PROFILE` to a `notarytool` keychain profile for notarization. Full
instructions: [docs/SIGNING.md](docs/SIGNING.md).

---

## 🚀 Usage

1. Launch iGlance — the eye icon appears in your menu bar
2. **Click it** to open the popover
3. Switch panes with the segmented bar at the top: **Monitor** / **Status** / **Services** / **Settings**
4. In **Monitor**, click any card to flip it to its detail side; click again to flip back
5. In **Services**, click **+** to bind a headless service — see [Binding a service](#-binding-a-service-step-by-step)
6. In **Settings**, check GitHub releases, install an update in place, or quit iGlance
7. The menu bar icon's arc fills as your system load increases

> The menu bar icon lives under the date/time by default. Drag it out, or add it to *Always Shown* via **System Settings → Menu Bar**.

---

## 🔌 Binding a service (step by step)

A service only needs a **name** and a **start command**. Everything else —
address, endpoints, auth header, memory breakdown — is discovered from the
manifest the command prints once the service is ready.

### 1. Open the editor

Popover → **Services** → **+** in the top-right corner (or **Add Service** on
the empty state). The editor opens in the pane itself.

> The editor is a page, not a sheet, so it behaves well while you gather
> information: switching to another app to copy a command no longer dismisses
> the popover, and if it does close, reopening iGlance brings you back to the
> same page with everything you typed still there.

### 2. Fill in the fields

| Field | What to put |
|---|---|
| **Name** | Shown on the card, e.g. `Gofer` |
| **Start command** | The exact line you'd type in Terminal to start (or reuse) the service, e.g. `~/Applications/Gofer/start-gofer.sh start --manifest`. It runs through `/bin/zsh -lc` from your home directory, so `~`, pipes and `&&` all work. **Choose Script…** appends a shell-quoted path for you. |
| **API token** (optional) | Sent in the header named by the manifest's `auth.header`. Stored in the login Keychain keyed by the binding's UUID — never in the bindings file. Leave blank if the service has no auth. |
| **Refresh every Ns** | How often to poll `endpoints.status` while the Services pane is open. 2–60 s, default 5 s. |
| **Allow iGlance to run this command and control the service** | The execution gate. While off, **Test Start**, **Start**, **Pause**, **Resume** and **Stop** are disabled. Changing the command of an existing binding switches it off again until you re-approve. |

### 3. Test before saving

- **Test Start** runs the command and waits up to **20 s** for the manifest
  line. On success the sheet reports the service name, version, `base_url`,
  and endpoint count. On failure it shows the exit status and the tail of
  stderr. Pressing it while the service is already running is safe — a good
  start command is idempotent and still prints the manifest.
- **Test Connection** calls `endpoints.status` with the stored or entered
  token and reports state, pid and memory. It's the quickest way to check a
  token: `401` comes back as *unauthorized*.

### 4. Manifest fallback

If your start command can't print a manifest — a launchd-managed daemon, a
service that's already running, a script you don't want to modify — expand
**Manifest (optional)**, paste the `IGLANCE_SERVICE_MANIFEST {...}` line (or
just the `{...}` JSON), and click **Use Manifest**. iGlance caches `base_url`,
endpoints and auth on the binding, so polling works without running anything.

### 5. Save

Press **Save** (↩). The card appears in the list and polling starts
immediately.

### What the card shows

- **State** — running / paused / starting / stopping / offline / unauthorized,
  with uptime, pid and `host:port`; offline cards keep a *last seen* stamp
- **Memory** — total RSS, a rolling sparkline, and a **N groups** disclosure
  with per-group RSS and process counts
- **Controls** — **Start**, **Pause** / **Resume**, **Stop**, plus a **⋯** menu
  with *Edit Service…*, *Toggle Pause* and *Delete Service*
- **Open Panel** — a Safari button that opens the service's web UI while it is
  running or paused. It appears only when the manifest or status reports a
  panel (`endpoints.panel` / `urls.panel`); the browser handles login, and the
  API token is never put in the URL
- **Delete** removes the binding and its Keychain token. It does **not** stop
  the service, and iGlance never starts bound services automatically at launch.

### Writing a service iGlance can drive

iGlance runs `/bin/zsh -lc "<start command>"`, reads stdout line by line, and
waits for the first line that begins with `IGLANCE_SERVICE_MANIFEST `. The rest
of that line is JSON:

```text
IGLANCE_SERVICE_MANIFEST {"schema":"iglance.service.v1","service":{"id":"gofer","name":"Gofer","version":"0.4.0"},"base_url":"http://127.0.0.1:8790","auth":{"type":"header","header":"X-Gofer-Token"},"endpoints":{"health":"/health","status":"/api/v1/service","memory":"/api/v1/service/memory","pause":"/api/v1/service/pause","resume":"/api/v1/service/resume","toggle":"/api/v1/service/toggle","stop":"/api/v1/service/stop"}}
```

Rules for the start command:

- **Idempotent** — running it while the service is up must succeed and still
  print the manifest.
- **Print the manifest only when ready** — after the health check passes.
- **Logs are fine** — iGlance ignores every other stdout/stderr line.
- **No secrets** — a token must never appear in the command or its output.

| Manifest field | Meaning |
|---|---|
| `schema` | Must be `iglance.service.v1` |
| `service.id` / `.name` / `.version` | Stable id, display name, version |
| `base_url` | HTTP root, no trailing `/` |
| `auth.type` / `auth.header` | `header` or `none`; header name for the token |
| `endpoints.status` | Required — state, pid, uptime, memory, controls |
| `endpoints.health` | Public health check |
| `endpoints.panel` | Optional web UI path; enables the card's **Open Panel** button |
| `endpoints.memory` | Memory-only snapshot, used when `status` has none |
| `endpoints.pause` / `resume` / `toggle` / `stop` | Optional controls; missing ones disable their buttons |

`GET endpoints.status` returns the shape below; all fields are optional except
a recognizable state. Memory is always in **bytes**, and
`memory.available: false` renders as `—` rather than `0`.

```json
{
  "schema": "iglance.service.v1",
  "state": "running",
  "paused": false,
  "pid": 12345,
  "uptime_sec": 3600,
  "urls": {
    "base": "http://127.0.0.1:8790",
    "display": "http://127.0.0.1:8790",
    "health": "http://127.0.0.1:8790/health",
    "panel": "http://127.0.0.1:8790/"
  },
  "memory": {
    "available": true,
    "source": "ps-rss",
    "total_rss_bytes": 435896320,
    "total_processes": 13,
    "groups": [
      { "id": "service", "label": "Gofer", "rss_bytes": 12603392, "processes": 1, "pids": [12345] },
      { "id": "xhs_browser", "label": "小红书浏览器", "rss_bytes": 423292928, "processes": 12, "pids": [12346] }
    ]
  }
}
```

For the **Open Panel** button iGlance uses `urls.panel` (an absolute address,
so a Tailscale/public URL declared by the service wins), then resolves the
manifest's relative `endpoints.panel` against `urls.display` → `urls.base` →
the cached `base_url`. Only `http` / `https` is accepted, and a service that
declares no panel simply doesn't get the button.

`groups` is what the card renders; the named top-level groups Gofer also
returns are compatibility fields. Control endpoints answer `POST` with `200`
(`stop` may answer `202` and then exit — a subsequent connection failure is
treated as *stopped*). `401` marks the card *unauthorized* and stops retrying;
connection failures mark it *offline* while keeping the last snapshot.

---

## 🏗 Architecture

| Layer | Tech | Notes |
|---|---|---|
| UI | SwiftUI + AppKit | NSPopover anchors UI to menu bar |
| State | Combine + ObservableObject | `AppStore` / `MonitorStore` / `StatusStore` / `ServicesStore` / `UpdateStore` |
| Data | `host_processor_info`, `sysctl`, `vm_stat`, `ps`, IOKit | CPU / memory / GPU read directly; unsupported sensors degrade to `—` |
| Sensors | AppleSMC + IOHIDEventSystem | CPU `TCMb`, GPU `TRDX`, `PMU tdie` fallback, gas-gauge battery |
| Storage | JSON in Application Support + Keychain | Bindings in JSON; service tokens keyed by binding UUID in the Keychain |
| Power | IOKit `IOPMAssertion` | Auto-released on quit |
| Build | SwiftPM + `build-app.sh` | No Xcode project required |

```
Sources/iGlance/
├── App/           # Lifecycle, AppDelegate, scene plumbing
├── Controllers/   # Status item + popover controllers
├── Models/        # Data structures
├── Services/      # CPU/GPU/Memory/Temp providers, power mgmt, service client/launcher
├── Stores/        # Reactive state
├── Support/       # Logging, utilities
└── Views/         # SwiftUI views (cards, gauges, sparklines, tabs)
```

---

## 🧪 Verified

`swift test` runs the unit suite (93 tests).

- ✅ Build & launch
- ✅ Menu bar presence (LSUIElement)
- ✅ Live CPU / GPU / Memory data
- ✅ Real CPU / GPU / battery temperatures (AppleSMC `TCMb` / `TRDX`, IOHID fallback)
- ✅ Card flip animations
- ✅ Sleep assertion toggle + cleanup
- ✅ Service manifest parsing, 401 / connection-failure handling, memory decoding
- ✅ Service start/stop/pause/resume against the `iglance.service.v1` protocol
- ✅ Panel URL resolution (`urls.panel` → `display`/`base` + `endpoints.panel`, http(s) only)
- ✅ Add / Edit Service draft survives closing the popover and switching sections
- ✅ GitHub release decoding and numeric version comparison
- ✅ Update install checks bundle identity and signature before swapping

---

## 🗺 Roadmap

- [ ] Homebrew Cask (`brew install --cask iglance`)
- [ ] DMG installer with drag-to-Applications UX
- [x] In-app update from GitHub releases
- [ ] Developer ID notarized release pipeline (script ready — see [docs/SIGNING.md](docs/SIGNING.md))
- [ ] Customizable refresh interval (currently fixed at 2s)
- [ ] Threshold-based notifications (e.g. alert when CPU > 90% for 30s)
- [ ] Menu bar icon style options (gauge, percentage, sparkline)
- [ ] Export monitoring history to CSV
- [ ] Localization

---

## 🤝 Contributing

PRs welcome. Before opening one:

1. Run `./verify-all-features.sh` — all tests must pass
2. Keep changes focused; one feature per PR
3. Match the existing Swift style (4-space indent, no external dependencies)
4. If you change UI, attach a screenshot

---

## 📄 License

[MIT](LICENSE) © 2024 kui.

---

## 🙏 Credits

Built with love and a lot of `man powermetrics`.

<div align="center">

**[⬇ Download](https://github.com/kuicao55/iGlance/releases/latest)** · **[🐛 Report Bug](https://github.com/kuicao55/iGlance/issues)** · **[✨ Request Feature](https://github.com/kuicao55/iGlance/issues)**

</div>