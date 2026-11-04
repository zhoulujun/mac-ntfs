# mac-ntfs

Read/write **NTFS** on macOS with Apple **FSKit** — no kernel extension, no macFUSE, **no SIP / Recovery Mode** changes.

Built around statically linked [ntfs-3g](https://github.com/tuxera/ntfs-3g), with a SwiftUI menu-bar app, a CLI, and optional Homebrew Cask install.

## Requirements

- macOS **26 Tahoe** or later (physical-disk write)
- Apple Silicon (M1/M2/…)
- Paid Apple Developer team to **load** the FSKit module (restricted entitlement `com.apple.developer.fskit.fsmodule`)

## Install (end users)

```bash
brew tap zhoulujun/mac-ntfs   # when published
brew install --cask mac-ntfs
open -a mac-ntfs
```

1. Open the menu-bar app and press **Enable Extension** (System Settings’ toggle is unreliable for third-party FSKit modules on macOS 26).
2. Plug in an NTFS drive — it should mount read/write under `/Volumes`.

Or use the CLI:

```bash
mac-ntfs doctor
mac-ntfs enable
mac-ntfs list
```

## Build from source

```bash
brew install xcodegen autoconf automake libtool  # once
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
./Scripts/build.sh          # fetch ntfs-3g, build lib, xcodegen, compile
open mac-ntfs.xcodeproj
```

Select your **Development Team**, enable the FSKit File System Module capability on App IDs `com.zhoulujun.mac-ntfs` and `com.zhoulujun.mac-ntfs.fsmodule`, then archive/sign. Copy `mac-ntfs.app` to `/Applications` before enabling the extension.

Release packaging (Developer ID + notarize):

```bash
export MACNTFS_TEAM_ID=YOURTEAMID
export MACNTFS_NOTARY_PROFILE=mac-ntfs-notary
./Scripts/package.sh
```

Homebrew Cask draft: [Packaging/homebrew/Casks/mac-ntfs.rb](Packaging/homebrew/Casks/mac-ntfs.rb).

## Architecture

| Target | Role |
|--------|------|
| `MacNTFS.app` | Menu bar: enable extension, list volumes, open/eject |
| `MacNTFSFS.appex` | FSKit module + ntfs-3g bridge (incl. kernel-offloaded I/O) |
| `mac-ntfs` CLI | `status` / `list` / `enable` / `doctor` |

Inspired by [xntfs](https://github.com/HuanchuanTech/xntfs) (engine/bridge), [ntfskit](https://github.com/whereteam/ntfskit) (KOIO), and [ttntfs](https://github.com/dr-kbadawi/ttntfs) (enable/cask UX). Independent project; not affiliated with those authors or Tuxera.

## Safety

- Hibernated / dirty Windows volumes stay **read-only** until Windows shuts down cleanly (disable Fast Startup).
- After large copies, **Eject** in Finder before unplugging (FSKit cannot force device write-cache flush).

## License

**GPL-2.0** — see [LICENSE](LICENSE) and [COPYRIGHT](COPYRIGHT). Linking ntfs-3g requires GPL-2.0 for the combined work.
