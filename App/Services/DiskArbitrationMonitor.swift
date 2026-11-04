//
//  DiskArbitrationMonitor.swift
//

import DiskArbitration
import Foundation
import IOKit

final class DiskArbitrationMonitor {
    var onDevicesChanged: (([NTFSDevice]) -> Void)?

    private let session: DASession
    private let queue = DispatchQueue(label: "com.zhoulujun.mac-ntfs.diskarb")
    private let callbackContext = MonitorCallbackContext()
    private var devices: [String: NTFSDevice] = [:]
    private let lock = NSLock()

    init?() {
        guard let session = DASessionCreate(kCFAllocatorDefault) else { return nil }
        self.session = session
        DASessionSetDispatchQueue(session, queue)
        callbackContext.monitor = self
    }

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            let ctx = Unmanaged.passUnretained(self.callbackContext).toOpaque()
            DARegisterDiskAppearedCallback(self.session, nil, MonitorCallbackContext.appeared, ctx)
            DARegisterDiskDisappearedCallback(self.session, nil, MonitorCallbackContext.disappeared, ctx)
            DARegisterDiskDescriptionChangedCallback(self.session, nil, nil, MonitorCallbackContext.changed, ctx)
        }
    }

    deinit {
        let session = session
        let context = callbackContext
        queue.async {
            withExtendedLifetime(context) {
                let ctx = Unmanaged.passUnretained(context).toOpaque()
                DAUnregisterCallback(session, unsafeBitCast(MonitorCallbackContext.appeared as DADiskAppearedCallback, to: UnsafeMutableRawPointer.self), ctx)
                DAUnregisterCallback(session, unsafeBitCast(MonitorCallbackContext.disappeared as DADiskDisappearedCallback, to: UnsafeMutableRawPointer.self), ctx)
                DAUnregisterCallback(session, unsafeBitCast(MonitorCallbackContext.changed as DADiskDescriptionChangedCallback, to: UnsafeMutableRawPointer.self), ctx)
                DASessionSetDispatchQueue(session, nil)
            }
        }
    }

    func refresh() {
        queue.async { [weak self] in
            guard let self else { return }
            for device in self.currentDevices {
                if let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, self.session, device.id) {
                    self.handleAppearedOrChanged(disk)
                }
            }
        }
    }

    var currentDevices: [NTFSDevice] {
        lock.lock(); defer { lock.unlock() }
        return Array(devices.values).sorted { $0.id < $1.id }
    }

    fileprivate func handleAppearedOrChanged(_ disk: DADisk) {
        guard let bsd = bsdName(disk) else { return }
        guard let device = makeDevice(disk, bsd: bsd) else {
            lock.lock(); let removed = devices.removeValue(forKey: bsd) != nil; lock.unlock()
            if removed { publish() }
            return
        }
        lock.lock(); devices[bsd] = device; lock.unlock()
        publish()
    }

    fileprivate func handleDisappeared(_ disk: DADisk) {
        guard let bsd = bsdName(disk) else { return }
        lock.lock(); devices[bsd] = nil; lock.unlock()
        publish()
    }

    private func publish() {
        let list = currentDevices
        DispatchQueue.main.async { [weak self] in self?.onDevicesChanged?(list) }
    }

    private func bsdName(_ disk: DADisk) -> String? {
        guard let c = DADiskGetBSDName(disk) else { return nil }
        return String(cString: c)
    }

    private func description(_ disk: DADisk) -> [String: Any]? {
        DADiskCopyDescription(disk) as? [String: Any]
    }

    static let moduleFSType = MacNTFSConfig.fileSystemTypeName
    static let imageDeviceModel = "Disk Image"

    private func makeDevice(_ disk: DADisk, bsd: String) -> NTFSDevice? {
        guard let desc = description(disk) else { return nil }
        let content = desc[kDADiskDescriptionMediaContentKey as String] as? String ?? ""
        let fsName = desc[kDADiskDescriptionVolumeKindKey as String] as? String
        let looksNTFS = content == "Windows_NTFS"
            || content.caseInsensitiveCompare("EBD0A0A2-B9E5-4433-87C0-68B6B72699C7") == .orderedSame
            || fsName?.lowercased() == "ntfs"
            || fsName?.lowercased() == Self.moduleFSType
        guard looksNTFS else { return nil }

        let name = desc[kDADiskDescriptionVolumeNameKey as String] as? String ?? ""
        let size = (desc[kDADiskDescriptionMediaSizeKey as String] as? NSNumber)?.uint64Value ?? 0
        let removable = (desc[kDADiskDescriptionMediaRemovableKey as String] as? Bool) ?? false
        let writable = (desc[kDADiskDescriptionMediaWritableKey as String] as? Bool) ?? true
        let model = desc[kDADiskDescriptionDeviceModelKey as String] as? String
        let whole = desc[kDADiskDescriptionMediaBSDNameKey as String] as? String ?? bsd
        let kind: DeviceKind
        if model?.localizedCaseInsensitiveContains("disk image") == true {
            kind = .diskImage
        } else if removable {
            kind = .removable
        } else {
            kind = .fixed
        }

        var device = NTFSDevice(
            id: bsd,
            volumeName: name,
            sizeBytes: size,
            kind: kind,
            contentHint: content,
            isRemovable: removable,
            devicePath: "/dev/\(bsd)",
            mediaWritable: writable,
            wholeDiskBSD: whole
        )

        if let path = desc[kDADiskDescriptionVolumePathKey as String] as? URL {
            device.state = .mounted(path)
            var s = statfs()
            if path.path.withCString({ statfs($0, &s) }) == 0 {
                let fstype = withUnsafeBytes(of: s.f_fstypename) { raw in
                    String(cString: raw.bindMemory(to: CChar.self).baseAddress!)
                }
                device.mountedFileSystemType = fstype
                device.readOnly = (Int32(s.f_flags) & MNT_RDONLY) != 0
            }
        } else {
            device.state = .unmounted
        }
        return device
    }
}

private final class MonitorCallbackContext {
    weak var monitor: DiskArbitrationMonitor?

    static let appeared: DADiskAppearedCallback = { disk, ctx in
        guard let ctx else { return }
        Unmanaged<MonitorCallbackContext>.fromOpaque(ctx).takeUnretainedValue().monitor?.handleAppearedOrChanged(disk)
    }

    static let disappeared: DADiskDisappearedCallback = { disk, ctx in
        guard let ctx else { return }
        Unmanaged<MonitorCallbackContext>.fromOpaque(ctx).takeUnretainedValue().monitor?.handleDisappeared(disk)
    }

    static let changed: DADiskDescriptionChangedCallback = { disk, _, ctx in
        guard let ctx else { return }
        Unmanaged<MonitorCallbackContext>.fromOpaque(ctx).takeUnretainedValue().monitor?.handleAppearedOrChanged(disk)
    }
}
