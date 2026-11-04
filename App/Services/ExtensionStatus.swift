//
//  ExtensionStatus.swift
//  Detects FSKit extension install/enable state and helps enable it on macOS 26.
//

import AppKit
import Foundation
import FSKit
import Observation

@MainActor
@Observable
final class ExtensionStatus {
    enum State: Equatable {
        case unknown, bundled, notInstalled, disabled, enabled
    }

    private(set) var state: State = .unknown
    private(set) var queryError: NSError?
    private(set) var moduleURLs: [URL] = []
    private(set) var installedCount = 0
    private(set) var bundledExtensionURL: URL?
    private(set) var lastEnableMessage: String?

    static let bundleID = MacNTFSConfig.extensionBundleID

    var isEnabled: Bool? {
        switch state {
        case .enabled: return true
        case .disabled: return false
        default: return nil
        }
    }

    var isDuplicated: Bool { installedCount > 1 }

    var pluginkitCommand: String { "pluginkit -mAvvv -i \(Self.bundleID)" }

    var diagnosticReport: String {
        let app = Bundle.main
        let version = app.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = app.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        var lines = [
            "mac-ntfs \(version) (\(build))",
            "OS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "App: \(app.bundleURL.path)",
            "Module: \(Self.bundleID)",
            "State: \(state)",
            "Bundled extension: \(bundledExtensionURL?.path ?? "not found")",
            "Registered copies: \(installedCount)"
        ]
        lines.append(contentsOf: moduleURLs.map { "Registration: \($0.path)" })
        if let queryError {
            lines.append("FSClient error: \(queryError.domain) (\(queryError.code)): \(queryError.localizedDescription)")
        }
        if let lastEnableMessage {
            lines.append("Enable: \(lastEnableMessage)")
        }
        return lines.joined(separator: "\n")
    }

    /// Unsupported but practical workaround used by peer FSKit NTFS apps on macOS 26
    /// when System Settings refuses to enable third-party modules.
    var enableFallbackScript: String {
        """
        PLIST="$HOME/Library/Group Containers/group.com.apple.fskit.settings/enabledModules.plist"
        BID="\(Self.bundleID)"
        if [ ! -f "$PLIST" ]; then echo "enabledModules.plist not found — toggle any File System Extension once in System Settings, then retry."; exit 1; fi
        if ! /usr/libexec/PlistBuddy -c "Print" "$PLIST" | head -1 | grep -q "Array"; then echo "Root is not an array; refusing to modify."; exit 1; fi
        /usr/libexec/PlistBuddy -c "Print" "$PLIST" | grep -qF "$BID" || /usr/libexec/PlistBuddy -c "Add :0 string $BID" "$PLIST"
        pkill -9 fskit_agent
        """
    }

    func refresh(appURL: URL = Bundle.main.bundleURL) async {
        queryError = nil
        bundledExtensionURL = Self.embeddedExtension(in: appURL)
        do {
            let modules = try await FSClient.shared.installedExtensions
            let mine = modules.filter { $0.bundleIdentifier == Self.bundleID }
            installedCount = mine.count
            moduleURLs = mine.compactMap { $0.url }
            if mine.isEmpty {
                state = bundledExtensionURL == nil ? .notInstalled : .bundled
            } else {
                state = mine.contains { $0.isEnabled } ? .enabled : .disabled
            }
        } catch {
            queryError = error as NSError
            state = bundledExtensionURL == nil ? .unknown : .bundled
            installedCount = 0
            moduleURLs = []
        }
    }

    /// Try pluginkit enable, then the macOS 26 enabledModules.plist workaround.
    @discardableResult
    func enableExtension() async -> Bool {
        lastEnableMessage = nil
        let appex = bundledExtensionURL ?? Self.embeddedExtension(in: Bundle.main.bundleURL)
        if let appex {
            let pk = Process()
            pk.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
            pk.arguments = ["-e", "use", "-i", Self.bundleID]
            pk.standardOutput = Pipe()
            pk.standardError = Pipe()
            try? pk.run()
            pk.waitUntilExit()

            let register = Process()
            register.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
            register.arguments = ["-a", appex.path]
            register.standardOutput = Pipe()
            register.standardError = Pipe()
            try? register.run()
            register.waitUntilExit()
        }

        let script = enableFallbackScript
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = ["-lc", script]
        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = out
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = out.fileHandleForReading.readDataToEndOfFile()
            lastEnableMessage = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if proc.terminationStatus != 0 {
                lastEnableMessage = (lastEnableMessage?.isEmpty == false ? lastEnableMessage! : "enable script failed (\(proc.terminationStatus))")
            }
        } catch {
            lastEnableMessage = error.localizedDescription
        }

        await refresh()
        return state == .enabled
    }

    static func embeddedExtension(in appURL: URL) -> URL? {
        let url = appURL.appendingPathComponent("Contents/PlugIns/MacNTFSFS.appex", isDirectory: true)
        let alt = appURL.appendingPathComponent("Contents/Extensions/MacNTFSFS.appex", isDirectory: true)
        for candidate in [url, alt] {
            guard let data = try? Data(contentsOf: candidate.appendingPathComponent("Contents/Info.plist")),
                  let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  info["CFBundleIdentifier"] as? String == bundleID,
                  let executable = info["CFBundleExecutable"] as? String,
                  FileManager.default.isExecutableFile(atPath: candidate.appendingPathComponent("Contents/MacOS/\(executable)").path)
            else { continue }
            return candidate
        }
        return nil
    }

    @discardableResult
    static func openSettings() -> Bool {
        if #available(macOS 27.0, *) {
            if FSClient.shared.openFileSystemExtensionsSettings() { return true }
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            return NSWorkspace.shared.open(url)
        }
        return false
    }
}
