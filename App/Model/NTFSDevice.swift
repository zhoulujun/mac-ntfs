//
//  NTFSDevice.swift
//

import Foundation

enum DeviceKind: Equatable {
    case removable
    case diskImage
    case fixed
}

enum MountState: Equatable {
    case unmounted
    case mounting
    case mounted(URL)
    case unmounting
    case failed(String)

    var isMounted: Bool {
        if case .mounted = self { return true }
        return false
    }

    var mountPoint: URL? {
        if case .mounted(let url) = self { return url }
        return nil
    }
}

enum MountDriver: Equatable {
    case macNTFS
    case system
    case other(String)
    case unknown

    init(fileSystemType: String?) {
        switch fileSystemType?.lowercased() {
        case MacNTFSConfig.fileSystemTypeName:
            self = .macNTFS
        case "ntfs":
            self = .system
        case nil, "":
            self = .unknown
        case let name?:
            self = .other(name)
        }
    }
}

struct NTFSDevice: Identifiable, Equatable {
    let id: String
    var volumeName: String
    var sizeBytes: UInt64
    var kind: DeviceKind
    var contentHint: String
    var isRemovable: Bool
    var devicePath: String
    var state: MountState = .unmounted
    var mountedFileSystemType: String?
    var readOnly: Bool = false
    var mediaWritable: Bool = true
    var wholeDiskBSD: String = ""
    var registryEntryID: UInt64?

    var displayName: String { volumeName.isEmpty ? id : volumeName }

    var mountDriver: MountDriver {
        state.isMounted ? MountDriver(fileSystemType: mountedFileSystemType) : .unknown
    }

    var mountedByMacNTFS: Bool { mountDriver == .macNTFS }

    static func == (lhs: NTFSDevice, rhs: NTFSDevice) -> Bool {
        lhs.id == rhs.id &&
            lhs.volumeName == rhs.volumeName &&
            lhs.state == rhs.state &&
            lhs.sizeBytes == rhs.sizeBytes &&
            lhs.kind == rhs.kind &&
            lhs.mountedFileSystemType == rhs.mountedFileSystemType &&
            lhs.readOnly == rhs.readOnly &&
            lhs.mediaWritable == rhs.mediaWritable &&
            lhs.registryEntryID == rhs.registryEntryID
    }
}

extension UInt64 {
    var humanSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .file)
    }
}
