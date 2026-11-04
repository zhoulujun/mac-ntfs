# mac-ntfs

在 macOS 上通过 Apple **FSKit** 读写 **NTFS**：无内核扩展、无 macFUSE、**无需关闭 SIP / 进入恢复模式**。

基于静态链接的 [ntfs-3g](https://github.com/tuxera/ntfs-3g)，提供 SwiftUI 菜单栏应用、命令行，以及可选的 Homebrew Cask 安装。

## 环境要求

- macOS **26 Tahoe** 及以上（物理磁盘可写）
- Apple Silicon（M1/M2/…）
- 付费 Apple Developer 账号（FSKit 受限 entitlement：`com.apple.developer.fskit.fsmodule`）

## 安装

```bash
brew tap zhoulujun/mac-ntfs   # 发布后
brew install --cask mac-ntfs
open -a mac-ntfs
```

1. 打开菜单栏应用，点击 **Enable Extension**（Tahoe 上系统设置开关对第三方模块经常无效）。
2. 插入 NTFS 盘，应在 `/Volumes` 下以读写方式挂载。

```bash
mac-ntfs doctor
mac-ntfs enable
mac-ntfs list
```

## 从源码构建

```bash
./Scripts/fetch-ntfs3g.sh
./Scripts/build-libntfs.sh
brew install xcodegen
xcodegen generate
open mac-ntfs.xcodeproj
```

在 Xcode 中选择开发团队，为 App / Extension 配置 FSKit 能力后编译 `MacNTFS`，将 `mac-ntfs.app` 拷到 `/Applications` 再启用扩展。

## 许可

**GPL-2.0**（因链接 ntfs-3g）。详见 [LICENSE](LICENSE)、[COPYRIGHT](COPYRIGHT)。
