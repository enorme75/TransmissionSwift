import Foundation

public enum TableColumn: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    case name
    case size
    case progress
    case downloadSpeed
    case uploadSpeed
    case eta
    case ratio
    case sent
    case addedAt
    case activityAt
    case primaryTracker
    case connectedPeers
    case availablePeers
    case seeds
    case queuePosition
    case label
    case priority
    case status
    case errorMessage
    case pieces
    case downloadFolder
    case hash

    public var id: String { rawValue }

    // Presentation specs (titles, widths, default visibility) live in the app
    // target's `TorrentTableColumns` — the single source of truth for the table.
}

extension TableColumn {
    public func comparator(order: SortOrder) -> KeyPathComparator<Torrent> {
        switch self {
        case .name: return KeyPathComparator(\Torrent.name, order: order)
        case .size: return KeyPathComparator(\Torrent.size, order: order)
        case .progress: return KeyPathComparator(\Torrent.progress, order: order)
        case .downloadSpeed: return KeyPathComparator(\Torrent.downloadSpeed, order: order)
        case .uploadSpeed: return KeyPathComparator(\Torrent.uploadSpeed, order: order)
        case .eta: return KeyPathComparator(\Torrent.etaSortKey, order: order)
        case .ratio: return KeyPathComparator(\Torrent.ratio, order: order)
        case .sent: return KeyPathComparator(\Torrent.uploadedEver, order: order)
        case .addedAt: return KeyPathComparator(\Torrent.addedAt, order: order)
        case .activityAt: return KeyPathComparator(\Torrent.lastActivityAt, order: order)
        case .primaryTracker: return KeyPathComparator(\Torrent.primaryTracker, order: order)
        case .connectedPeers: return KeyPathComparator(\Torrent.connectedPeerCount, order: order)
        case .availablePeers: return KeyPathComparator(\Torrent.availablePeerCount, order: order)
        case .seeds: return KeyPathComparator(\Torrent.seedCount, order: order)
        case .queuePosition: return KeyPathComparator(\Torrent.queuePositionSortKey, order: order)
        case .label: return KeyPathComparator(\Torrent.labelSortKey, order: order)
        case .priority: return KeyPathComparator(\Torrent.priority.rawValue, order: order)
        case .status: return KeyPathComparator(\Torrent.status.rawValue, order: order)
        case .errorMessage: return KeyPathComparator(\Torrent.errorMessageSortKey, order: order)
        case .pieces: return KeyPathComparator(\Torrent.havePieces, order: order)
        case .downloadFolder: return KeyPathComparator(\Torrent.downloadFolder, order: order)
        case .hash: return KeyPathComparator(\Torrent.hash, order: order)
        }
    }
}

public struct TablePreferences: Codable, Sendable {
    public var sortColumn: String
    public var sortAscending: Bool
    public var visibleColumns: [String]
    public var columnOrder: [String]
    public var columnWidths: [String: Double]

    public static let storageKey = "torrentTablePreferences"

    public init(
        sortColumn: String = "name",
        sortAscending: Bool = true,
        visibleColumns: [String] = [],
        columnOrder: [String] = [],
        columnWidths: [String: Double] = [:]
    ) {
        self.sortColumn = sortColumn
        self.sortAscending = sortAscending
        self.visibleColumns = visibleColumns
        self.columnOrder = columnOrder
        self.columnWidths = columnWidths
    }

    private enum CodingKeys: String, CodingKey {
        case sortColumn
        case sortAscending
        case visibleColumns
        case columnOrder
        case columnWidths
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sortColumn = try container.decodeIfPresent(String.self, forKey: .sortColumn) ?? "name"
        self.sortAscending = try container.decodeIfPresent(Bool.self, forKey: .sortAscending) ?? true
        self.visibleColumns = try container.decodeIfPresent([String].self, forKey: .visibleColumns) ?? []
        self.columnOrder = try container.decodeIfPresent([String].self, forKey: .columnOrder) ?? []
        self.columnWidths = try container.decodeIfPresent([String: Double].self, forKey: .columnWidths) ?? [:]
    }
}
