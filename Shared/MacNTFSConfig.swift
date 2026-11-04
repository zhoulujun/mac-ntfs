//
//  MacNTFSConfig.swift
//  Shared identifiers for the host app, CLI, and FSKit extension.
//

import Foundation

enum MacNTFSConfig {
    static let appBundleID = "com.zhoulujun.mac-ntfs"
    static let extensionBundleID = "com.zhoulujun.mac-ntfs.fsmodule"
    /// Must match FSShortName in the extension Info.plist / EXAppExtensionAttributes.
    static let fileSystemTypeName = "mac-ntfs"
    /// Prefer TeamID-prefixed group when signed with a paid team.
    /// Override at build time with MACNTFS_APP_GROUP if your Team ID differs.
    static let appGroupID: String = {
        if let env = ProcessInfo.processInfo.environment["MACNTFS_APP_GROUP"], !env.isEmpty {
            return env
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "MacNTFSAppGroup") as? String, !plist.isEmpty {
            return plist
        }
        return "group.com.zhoulujun.mac-ntfs"
    }()
}
