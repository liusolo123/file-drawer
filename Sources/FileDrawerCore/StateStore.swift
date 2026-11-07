import Foundation

public enum StateStoreError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
}

/// 带版本号的 JSON 状态文件。
public struct StateStore: Sendable {
    public let fileURL: URL

    public init(directory: URL) {
        fileURL = directory.appendingPathComponent("state.json", isDirectory: false)
    }

    public func load() throws -> DrawerState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .empty
        }

        let data = try Data(contentsOf: fileURL)
        let state = try JSONDecoder().decode(DrawerState.self, from: data)

        guard state.schemaVersion <= DrawerState.currentSchemaVersion else {
            throw StateStoreError.unsupportedSchemaVersion(state.schemaVersion)
        }

        return state
    }

    /// 原子写入：先写临时文件再替换，避免中途失败留下半个文件。
    public func save(_ state: DrawerState) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: .atomic)
    }
}
