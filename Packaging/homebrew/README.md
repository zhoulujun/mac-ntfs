# Homebrew tap draft for mac-ntfs

Publish signed DMGs to GitHub Releases, then:

```bash
# from a tap repo (e.g. homebrew-mac-ntfs)
brew tap zhoulujun/mac-ntfs
brew install --cask mac-ntfs
```

Update `sha256` in `Casks/mac-ntfs.rb` for each release. The cask installs the app; run `mac-ntfs enable` or use the menu bar **Enable Extension** button after install.

CLI: the draft cask expects an optional helper binary path. Prefer shipping the ArgumentParser tool as `Contents/MacOS/mac-ntfs` inside the app bundle or as a separate bottle once packaging is finalized.
