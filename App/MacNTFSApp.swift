//
//  MacNTFSApp.swift
//

import SwiftUI

@main
struct MacNTFSApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("mac-ntfs", systemImage: "externaldrive.fill") {
            MenuBarContent(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }
}

struct MenuBarContent: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("mac-ntfs")
                    .font(.headline)
                Spacer()
                Text(extensionLabel)
                    .font(.caption)
                    .foregroundStyle(extensionColor)
            }

            if model.extensionStatus.state != .enabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enable the file system extension once. No SIP or Recovery Mode required.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Enable Extension") {
                            Task { _ = await model.extensionStatus.enableExtension() }
                        }
                        .buttonStyle(.borderedProminent)
                        Button("System Settings") {
                            ExtensionStatus.openSettings()
                        }
                    }
                }
            }

            Divider()

            if model.devices.isEmpty {
                Text("No NTFS volumes detected")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(model.devices) { device in
                    DeviceRow(device: device, model: model)
                }
            }

            Divider()

            HStack {
                Button("Refresh") {
                    Task { await model.refresh() }
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 360)
        .task {
            await model.refresh()
        }
    }

    private var extensionLabel: String {
        switch model.extensionStatus.state {
        case .enabled: return "Extension on"
        case .disabled: return "Extension off"
        case .bundled, .notInstalled: return "Not registered"
        case .unknown: return "Checking…"
        }
    }

    private var extensionColor: Color {
        switch model.extensionStatus.state {
        case .enabled: return .green
        case .disabled, .notInstalled: return .orange
        default: return .secondary
        }
    }
}

struct DeviceRow: View {
    let device: NTFSDevice
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: device.kind == .diskImage ? "doc" : "externaldrive")
                Text(device.displayName)
                    .fontWeight(.medium)
                Spacer()
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(device.id) · \(device.sizeBytes.humanSize)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack {
                if device.state.isMounted {
                    Button("Open") { model.openInFinder(device) }
                    Button("Eject") { model.eject(device) }
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private var statusText: String {
        switch device.state {
        case .mounted:
            if device.mountedByMacNTFS {
                return device.readOnly ? "mac-ntfs · RO" : "mac-ntfs · RW"
            }
            if device.mountDriver == .system {
                return "Apple NTFS · RO"
            }
            return "Mounted"
        case .unmounted:
            return "Unmounted"
        case .failed(let message):
            return message
        case .mounting:
            return "Mounting…"
        case .unmounting:
            return "Ejecting…"
        }
    }
}

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section("Extension") {
                Text(model.extensionStatus.diagnosticReport)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Button("Copy Diagnostics") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(model.extensionStatus.diagnosticReport, forType: .string)
                }
            }
            Section("Safety") {
                Text("Dirty or hibernated Windows volumes mount read-only. Shut down Windows fully (disable Fast Startup) before writing from Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("After large copies, eject the volume in Finder before unplugging. FSKit cannot force a device write-cache flush.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 360)
        .task { await model.refresh() }
    }
}
