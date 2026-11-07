import Foundation
import FileDrawerCore

enum AppPaths {
    /// ~/Library/Application Support/com.liusolo.filedrawer
    static var stateDirectory: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)

        return base.appendingPathComponent(AppMetadata.bundleIdentifier, isDirectory: true)
    }
}
