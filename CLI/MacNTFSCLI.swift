//
//  mac-ntfs CLI
//

import Foundation

@main
enum MacNTFSCLI {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        let command = args.first ?? "help"
        switch command {
        case "help", "-h", "--help":
            printUsage()
        case "status":
            await printStatus()
        case "list":
            await printList()
        case "enable":
            await runEnable()
        case "doctor":
            await runDoctor()
        default:
            fputs("unknown command: \(command)\n", stderr)
            printUsage()
            exit(1)
        }
    }

    static func printUsage() {
        print(
            """
            mac-ntfs — NTFS read/write for macOS via FSKit (no SIP changes)

            Usage:
              mac-ntfs status    Extension enablement summary
              mac-ntfs list      NTFS volumes currently visible
              mac-ntfs enable    Try to enable the FSKit extension (macOS 26 workaround)
              mac-ntfs doctor    Diagnostics for install / registration / OS
              mac-ntfs help
            """
        )
    }

    static func appURL() -> URL? {
        let candidates = [
            "/Applications/mac-ntfs.app",
            "/Applications/MacNTFS.app"
        ].map(URL.init(fileURLWithPath:))
        if let found = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            return found
        }
        let exe = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        let nearby = exe.deletingLastPathComponent().appendingPathComponent("mac-ntfs.app")
        if FileManager.default.fileExists(atPath: nearby.path) { return nearby }
        return nil
    }

    @MainActor
    static func printStatus() async {
        let status = ExtensionStatus()
        if let app = appURL() {
            await status.refresh(appURL: app)
        } else {
            await status.refresh()
        }
        print("module: \(ExtensionStatus.bundleID)")
        print("state: \(status.state)")
        print("installed: \(status.installedCount)")
        print("bundled: \(status.bundledExtensionURL?.path ?? "none")")
        for url in status.moduleURLs {
            print("registration: \(url.path)")
        }
    }

    static func printList() async {
        guard let monitor = DiskArbitrationMonitor() else {
            fputs("error: DiskArbitration unavailable\n", stderr)
            exit(1)
        }
        let sem = DispatchSemaphore(value: 0)
        var devices: [NTFSDevice] = []
        monitor.onDevicesChanged = { list in
            devices = list
            sem.signal()
        }
        monitor.start()
        _ = sem.wait(timeout: .now() + 1.5)
        monitor.refresh()
        _ = sem.wait(timeout: .now() + 0.5)
        if devices.isEmpty {
            print("(no NTFS volumes)")
            return
        }
        for device in devices {
            let mount = device.state.mountPoint?.path ?? "-"
            let driver = device.mountedFileSystemType ?? "-"
            let mode = device.state.isMounted ? (device.readOnly ? "ro" : "rw") : "-"
            print("\(device.id)\t\(device.displayName)\t\(device.sizeBytes.humanSize)\t\(driver)\t\(mode)\t\(mount)")
        }
    }

    @MainActor
    static func runEnable() async {
        guard let app = appURL() else {
            fputs("error: mac-ntfs.app not found in /Applications\n", stderr)
            exit(1)
        }
        let status = ExtensionStatus()
        await status.refresh(appURL: app)
        let ok = await status.enableExtension()
        print(status.lastEnableMessage ?? (ok ? "enabled" : "failed"))
        print("state: \(status.state)")
        exit(ok ? 0 : 2)
    }

    @MainActor
    static func runDoctor() async {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        print("os: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        if os.majorVersion < 26 {
            print("warn: physical-disk NTFS write support targets macOS 26+")
        } else {
            print("ok: macOS 26+ detected")
        }
        #if arch(arm64)
        print("ok: Apple Silicon")
        #else
        print("warn: Intel is not a primary support target")
        #endif

        if let app = appURL() {
            print("app: \(app.path)")
        } else {
            print("warn: mac-ntfs.app not found in /Applications")
        }

        let status = ExtensionStatus()
        if let app = appURL() {
            await status.refresh(appURL: app)
        } else {
            await status.refresh()
        }
        print(status.diagnosticReport)
        print("hint: \(status.pluginkitCommand)")
        if status.state != .enabled {
            print("hint: run `mac-ntfs enable` or open the menu-bar app and press Enable Extension")
        }
        if status.isDuplicated {
            print("warn: duplicate FSKit registrations — remove old copies from /Applications and DerivedData")
        }
    }
}
