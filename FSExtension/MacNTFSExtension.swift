//
//  MacNTFSExtension.swift
//  FSKit file-system extension entry point for mac-ntfs.
//

import ExtensionFoundation
import Foundation
import FSKit

@main
struct MacNTFSExtension: UnaryFileSystemExtension {
    let fileSystem = MacNTFSFileSystem()
}
