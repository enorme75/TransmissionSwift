import Foundation

public enum TableColumn: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    case name
    case size
    case progress
    case downloadSpeed
    case uploadSpeed
    case eta
    case ratio
    case addedAt
    case completedAt
    case startedAt
    case lastActivityAt
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
    case downloadedEver
    case uploadedEver
    case leftUntilDone
    case sizeWhenDone
    case secondsDownloading
    case secondsSeeding
    case downloadLimit
    case uploadLimit
    case seedRatioLimit
    case seedIdleLimit
    case peerLimit

    public var id: String { rawValue }

    // Presentation specs (titles, widths, default visibility) live in the app
    // target's `TorrentTableColumns` — the single source of truth for the table.
}

/// Sorts by an optional date, placing torrents without the date last in both
/// sort directions. A `KeyPathComparator` over a fallback date (`.distantFuture`)
/// cannot express that: the fallback is the "newest" value, so it lands on top
/// of the descending sort a header click produces.
public struct NilLastDateComparator: SortComparator {
    public typealias Compared = Torrent

    public var order: SortOrder = .forward
    private let date: KeyPath<Torrent, Date?>

    public init(_ date: KeyPath<Torrent, Date?>, order: SortOrder) {
        self.date = date
        self.order = order
    }

    public func compare(_ lhs: Torrent, _ rhs: Torrent) -> ComparisonResult {
        switch (lhs[keyPath: date], rhs[keyPath: date]) {
        case (nil, nil):
            return .orderedSame
        case (nil, _?):
            return .orderedDescending
        case (_?, nil):
            return .orderedAscending
        case (let l?, let r?):
            let forward = l.compare(r)
            guard order == .forward else {
                return forward == .orderedAscending
                    ? .orderedDescending : (forward == .orderedDescending ? .orderedAscending : .orderedSame)
            }
            return forward
        }
    }
}

extension TableColumn {
    public func comparator(order: SortOrder) -> any SortComparator<Torrent> {
        switch self {
        case .name: return KeyPathComparator(\Torrent.name, order: order)
        case .size: return KeyPathComparator(\Torrent.size, order: order)
        case .progress: return KeyPathComparator(\Torrent.progress, order: order)
        case .downloadSpeed: return KeyPathComparator(\Torrent.downloadSpeed, order: order)
        case .uploadSpeed: return KeyPathComparator(\Torrent.uploadSpeed, order: order)
        case .eta: return KeyPathComparator(\Torrent.etaSortKey, order: order)
        case .ratio: return KeyPathComparator(\Torrent.ratio, order: order)
        case .addedAt: return KeyPathComparator(\Torrent.addedAt, order: order)
        case .completedAt: return NilLastDateComparator(\Torrent.completedAt, order: order)
        case .startedAt: return NilLastDateComparator(\Torrent.startedAt, order: order)
        case .lastActivityAt: return NilLastDateComparator(\Torrent.lastActivityAt, order: order)
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
        case .downloadedEver: return KeyPathComparator(\Torrent.downloadedEver, order: order)
        case .uploadedEver: return KeyPathComparator(\Torrent.uploadedEver, order: order)
        case .leftUntilDone: return KeyPathComparator(\Torrent.leftUntilDone, order: order)
        case .sizeWhenDone: return KeyPathComparator(\Torrent.sizeWhenDone, order: order)
        case .secondsDownloading: return KeyPathComparator(\Torrent.secondsDownloading, order: order)
        case .secondsSeeding: return KeyPathComparator(\Torrent.secondsSeeding, order: order)
        case .downloadLimit: return KeyPathComparator(\Torrent.downloadLimitSortKey, order: order)
        case .uploadLimit: return KeyPathComparator(\Torrent.uploadLimitSortKey, order: order)
        case .seedRatioLimit: return KeyPathComparator(\Torrent.seedRatioLimitSortKey, order: order)
        case .seedIdleLimit: return KeyPathComparator(\Torrent.seedIdleLimitSortKey, order: order)
        case .peerLimit: return KeyPathComparator(\Torrent.options.peerLimit, order: order)
        }
    }
}

public struct TablePreferences: Codable, Sendable {
    public var sortColumn: String
    public var sortAscending: Bool

    public init(
        sortColumn: String = "name",
        sortAscending: Bool = true
    ) {
        self.sortColumn = sortColumn
        self.sortAscending = sortAscending
    }
}
