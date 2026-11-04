cask "mac-ntfs" do
  version "0.1.0"
  sha256 :no_check # replace with release asset digest

  depends_on macos: ">= :tahoe"
  depends_on arch: :arm64

  url "https://github.com/zhoulujun/mac-ntfs/releases/download/v#{version}/mac-ntfs-#{version}.dmg"
  name "mac-ntfs"
  desc "FSKit NTFS read/write for macOS (no SIP changes)"
  homepage "https://github.com/zhoulujun/mac-ntfs"

  app "mac-ntfs.app"
  binary "#{appdir}/mac-ntfs.app/Contents/MacOS/mac-ntfs-cli", target: "mac-ntfs"

  caveats <<~EOS
    Open mac-ntfs once and press Enable Extension.
    On macOS 26, System Settings → File System Extensions may not enable
    third-party modules; the in-app button applies the known workaround.

    Requires a signed build with the FSKit entitlement. No SIP or Recovery
    Mode changes are needed.
  EOS

  zap trash: [
    "~/Library/Group Containers/group.com.zhoulujun.mac-ntfs",
    "~/Library/Preferences/com.zhoulujun.mac-ntfs.plist",
  ]
end
