//
//  AppModel.swift
//

import AppKit
import DiskArbitration
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    var devices: [NTFSDevice] = []
    let extensionStatus = ExtensionStatus()
    private var monitor: DiskArbitrationMonitor?

    init() {
        monitor = DiskArbitrationMonitor()
        monitor?.onDevicesChanged = { [weak self] list in
            Task { @MainActor in self?.devices = list }
        }
        monitor?.start()
    }

    func refresh() async {
        monitor?.refresh()
        await extensionStatus.refresh()
        devices = monitor?.currentDevices ?? devices
    }

    func openInFinder(_ device: NTFSDevice) {
        guard let url = device.state.mountPoint else { return }
        NSWorkspace.shared.open(url)
    }

    func eject(_ device: NTFSDevice) {
        guard let session = DASessionCreate(kCFAllocatorDefault),
              let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, device.id) else { return }
        DADiskUnmount(disk, DADiskUnmountOptions(kDADiskUnmountOptionDefault), nil, nil)
    }
}
