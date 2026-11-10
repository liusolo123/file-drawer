import Foundation

/// 列表排序规则。文件夹组与文件组各自应用同一条规则，组间顺序不变。
public struct SortRule: Codable, Equatable, Sendable {
    public enum Key: String, Codable, Sendable {
        case name
        case modified
    }

    public var key: Key
    public var ascending: Bool

    public init(key: Key, ascending: Bool) {
        self.key = key
        self.ascending = ascending
    }

    /// 默认：修改时间降序。
    public static let `default` = SortRule(key: .modified, ascending: false)

    public var displayName: String {
        switch key {
        case .name:
            return ascending ? "名称 ↑" : "名称 ↓"
        case .modified:
            return ascending ? "修改时间 ↑" : "修改时间 ↓"
        }
    }
}
