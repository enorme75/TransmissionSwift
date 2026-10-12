import AppKit
import SwiftUI
import TransmissionCore

/// The inspector's peers table: read-only rows, but with a fully
/// user-configurable column layout — resize by dragging dividers, reorder by
/// dragging headers, show/hide via the header's context menu. Widths, order
/// and visibility persist across launches through NSTableView's column
/// autosave, the same mechanism the main torrent table builds on.
struct PeersTableRepresentable: NSViewRepresentable {
    let peers: [Peer]

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let tableView = NSTableView()
        tableView.rowHeight = 24
        tableView.usesAutomaticRowHeights = false
        tableView.allowsMultipleSelection = true
        tableView.allowsEmptySelection = true
        tableView.allowsColumnResizing = true
        tableView.allowsColumnReordering = true
        // The Address column (first) absorbs spare horizontal space so the
        // table fills the inspector's width; beyond it, the horizontal
        // scroller takes over — same policy as the main torrent table.
        tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        tableView.style = .inset
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.gridStyleMask = []
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.headerView = NSTableHeaderView()
        tableView.setAccessibilityIdentifier("inspector.peers.table")

        // Column layout persistence: autosave restores order, widths and each
        // column's isHidden state under this key on subsequent launches.
        tableView.autosaveName = "inspectorPeersTableColumns"
        tableView.autosaveTableColumns = true

        for spec in PeerTableColumns.all {
            tableView.addTableColumn(context.coordinator.makeColumn(from: spec))
        }

        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        // Restore the persisted sort so the header indicator shows on launch
        // and incoming polls arrive pre-sorted.
        context.coordinator.restorePersistedSort(into: tableView)

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tableView = scrollView.documentView as? NSTableView else { return }
        context.coordinator.apply(peers: peers, to: tableView)
    }

    @MainActor
    final class Coordinator: NSObject {
        static let sortDefaultsKey = "inspectorPeersTableSort"

        private var displayedPeers: [Peer] = []
        private var sortState: PeerSortState?

        /// Reloads only when a poll actually moved something; a per-second
        /// snapshot with identical peers skips the table entirely. Incoming
        /// snapshots are re-sorted so the user's chosen order survives polls.
        func apply(peers: [Peer], to tableView: NSTableView) {
            let sorted = PeerSorter.sorted(peers, by: sortState)
            guard sorted != displayedPeers else { return }
            displayedPeers = sorted
            tableView.reloadData()
        }

        func makeColumn(from spec: PeerTableColumnSpec) -> NSTableColumn {
            let column = NSTableColumn(
                identifier: NSUserInterfaceItemIdentifier(spec.column.rawValue))
            column.headerCell = PaddedPeerTableHeaderCell(textCell: spec.title)
            column.minWidth = spec.minWidth
            column.maxWidth = spec.maxWidth
            column.width = spec.idealWidth
            column.resizingMask = [.userResizingMask, .autoresizingMask]
            column.sortDescriptorPrototype = NSSortDescriptor(
                key: spec.column.rawValue, ascending: true)
            return column
        }

        // MARK: - Sort persistence

        func restorePersistedSort(into tableView: NSTableView) {
            guard
                let stored = UserDefaults.standard.dictionary(forKey: Self.sortDefaultsKey),
                let rawColumn = stored["column"] as? String,
                let column = PeerTableColumn(rawValue: rawColumn),
                let ascending = stored["ascending"] as? Bool
            else { return }
            sortState = PeerSortState(column: column, ascending: ascending)
            // Drives the header's sort indicator; the resulting delegate
            // callback would just echo this state back, so no loop.
            tableView.sortDescriptors = [
                NSSortDescriptor(key: column.rawValue, ascending: ascending)
            ]
        }

        private func persistSort(_ state: PeerSortState?) {
            guard let state else {
                UserDefaults.standard.removeObject(forKey: Self.sortDefaultsKey)
                return
            }
            UserDefaults.standard.set(
                ["column": state.column.rawValue, "ascending": state.ascending],
                forKey: Self.sortDefaultsKey)
        }
    }
}

// MARK: - Data source & delegate

extension PeersTableRepresentable.Coordinator: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        displayedPeers.count
    }
}

extension PeersTableRepresentable.Coordinator: NSTableViewDelegate {
    func tableView(
        _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int
    ) -> NSView? {
        guard displayedPeers.indices.contains(row), let tableColumn,
            let column = PeerTableColumn(rawValue: tableColumn.identifier.rawValue)
        else { return nil }

        let reuseID = NSUserInterfaceItemIdentifier(
            PeerTableColumns.cellReuseIdentifierPrefix + column.rawValue)
        let cell =
            tableView.makeView(withIdentifier: reuseID, owner: self) as? PeerTableCellView
            ?? PeerTableCellView()
        cell.identifier = reuseID
        cell.configure(
            content: PeerCellContent.make(
                for: column,
                peer: displayedPeers[row]))
        return cell
    }

    // Keep the header's show/hide menu from collapsing the table to zero
    // columns — same guard the main torrent table applies.
    func tableView(
        _ tableView: NSTableView,
        userCanChangeVisibilityOf column: NSTableColumn
    ) -> Bool {
        let visibleCount = tableView.tableColumns.filter { !$0.isHidden }.count
        return visibleCount > 1 || column.isHidden
    }

    // MARK: - Sorting

    func tableView(
        _ tableView: NSTableView,
        sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]
    ) {
        // AppKit promotes the clicked column to PRIMARY of its descriptor
        // list, keeping older entries as secondaries. Single-sort table:
        // collapse to the primary (same normalization the main torrent
        // table applies).
        guard let descriptor = tableView.sortDescriptors.first else { return }
        if tableView.sortDescriptors.count > 1 {
            tableView.sortDescriptors = [descriptor]
        }
        guard let key = descriptor.key,
            let column = PeerTableColumn(rawValue: key)
        else { return }
        // A launch-time restore lands here too with identical state; the
        // equality check skips the redundant reload in that case.
        let newState = PeerSortState(column: column, ascending: descriptor.ascending)
        guard newState != sortState else { return }
        sortState = newState
        persistSort(newState)
        displayedPeers = PeerSorter.sorted(displayedPeers, by: newState)
        tableView.reloadData()
    }
}

// MARK: - Sorting

/// The peers table's persisted sort. Top-level (not nested in the @MainActor
/// coordinator) so the pure sorter and the unit tests can construct it from
/// nonisolated contexts.
struct PeerSortState: Equatable {
    var column: PeerTableColumn
    var ascending: Bool
}

/// Pure in-memory sort for the peers table. The rows live in the torrent's
/// snapshot, so ordering is applied locally (the store owns no peers state)
/// — re-applied on every poll so the chosen order survives snapshots.
enum PeerSorter {
    static func sorted(
        _ peers: [Peer],
        by state: PeerSortState?
    ) -> [Peer] {
        guard let state else { return peers }
        return peers.sorted { lhs, rhs in
            let result = compare(lhs, rhs, column: state.column)
            return state.ascending
                ? result == .orderedAscending
                : result == .orderedDescending
        }
    }

    private static func compare(
        _ lhs: Peer, _ rhs: Peer, column: PeerTableColumn
    ) -> ComparisonResult {
        switch column {
        // Numeric-aware so "10.0.0.2" sorts before "10.0.0.10".
        case .address:
            return lhs.ipAddress.compare(rhs.ipAddress, options: [.numeric])
        case .client:
            return lhs.client.compare(rhs.client, options: [.numeric, .caseInsensitive])
        case .flags:
            return lhs.flags.compare(rhs.flags)
        case .progress:
            if lhs.progress < rhs.progress { return .orderedAscending }
            if lhs.progress > rhs.progress { return .orderedDescending }
            return .orderedSame
        case .downloadSpeed:
            if lhs.downloadSpeed < rhs.downloadSpeed { return .orderedAscending }
            if lhs.downloadSpeed > rhs.downloadSpeed { return .orderedDescending }
            return .orderedSame
        case .uploadSpeed:
            if lhs.uploadSpeed < rhs.uploadSpeed { return .orderedAscending }
            if lhs.uploadSpeed > rhs.uploadSpeed { return .orderedDescending }
            return .orderedSame
        }
    }
}

// MARK: - Column specs

enum PeerTableColumn: String, CaseIterable, Identifiable {
    case address
    case client
    case flags
    case progress
    case downloadSpeed
    case uploadSpeed

    var id: String { rawValue }
}

struct PeerTableColumnSpec {
    let column: PeerTableColumn
    let title: String
    let minWidth: CGFloat
    let idealWidth: CGFloat
    let maxWidth: CGFloat
    let hiddenByDefault: Bool
}

enum PeerTableColumns {
    /// All columns start visible; the autosave overlays the user's saved
    /// layout (order, widths, hidden state) on subsequent launches.
    static let all: [PeerTableColumnSpec] = [
        PeerTableColumnSpec(
            column: .address, title: "Address",
            minWidth: 130, idealWidth: 150, maxWidth: 400, hiddenByDefault: false),
        PeerTableColumnSpec(
            column: .client, title: "Client",
            minWidth: 90, idealWidth: 110, maxWidth: 300, hiddenByDefault: false),
        PeerTableColumnSpec(
            column: .flags, title: "Flags",
            minWidth: 48, idealWidth: 52, maxWidth: 120, hiddenByDefault: false),
        PeerTableColumnSpec(
            column: .progress, title: "%",
            minWidth: 36, idealWidth: 40, maxWidth: 80, hiddenByDefault: false),
        PeerTableColumnSpec(
            column: .downloadSpeed, title: "Down",
            minWidth: 68, idealWidth: 76, maxWidth: 130, hiddenByDefault: false),
        PeerTableColumnSpec(
            column: .uploadSpeed, title: "Up",
            minWidth: 60, idealWidth: 68, maxWidth: 130, hiddenByDefault: false),
    ]

    static let cellReuseIdentifierPrefix = "peerCell."
}

// MARK: - Cell content

/// Display value for one peers-table cell. Kept as an explicit projection (like
/// `TorrentCellContent`) so the cell's equality guard compares exactly what it
/// renders — a poll that changed nothing a column shows skips the cell.
struct PeerCellContent: Equatable {
    /// nil renders as a plain text cell; non-nil prefixes a country chip.
    var country: String?
    var text: String
    var font: NSFont
    var color: NSColor
    var alignment: NSTextAlignment
}

extension PeerCellContent {
    private static let labelFont = NSFont.systemFont(ofSize: 12)
    private static let monoFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    private static let monoDigitFont = NSFont.monospacedDigitSystemFont(
        ofSize: 12, weight: .regular)

    static func make(for column: PeerTableColumn, peer: Peer) -> PeerCellContent {
        switch column {
        case .address:
            return PeerCellContent(
                country: peer.countryCode,
                text: peer.ipAddress,
                font: monoFont,
                color: .labelColor,
                alignment: .left)
        case .client:
            return PeerCellContent(
                country: nil,
                text: peer.client,
                font: labelFont,
                color: .secondaryLabelColor,
                alignment: .left)
        case .flags:
            return PeerCellContent(
                country: nil,
                text: peer.flags,
                font: monoFont,
                color: .secondaryLabelColor,
                alignment: .left)
        case .progress:
            return PeerCellContent(
                country: nil,
                text: "\(Int(peer.progress * 100))",
                font: monoDigitFont,
                color: .secondaryLabelColor,
                alignment: .right)
        case .downloadSpeed:
            return PeerCellContent(
                country: nil,
                text: ColumnFormatters.humanizedSpeed(peer.downloadSpeed),
                font: monoDigitFont,
                color: .labelColor,
                alignment: .right)
        case .uploadSpeed:
            return PeerCellContent(
                country: nil,
                text: ColumnFormatters.humanizedSpeed(peer.uploadSpeed),
                font: monoDigitFont,
                color: .labelColor,
                alignment: .right)
        }
    }
}

// MARK: - Cell view

/// Native cell for the peers table: an optional country chip followed by a
/// single label. Per-column reuse means the chip's presence is normally
/// constant for a cell's lifetime, but the rebuild handles a reused cell whose
/// country appears or disappears.
final class PeerTableCellView: NSTableCellView {
    static let cellInset: CGFloat = 6

    private var content: PeerCellContent?
    private var stackView: NSStackView?
    private var countryChip: PeerCountryChipView?
    private var label: NSTextField?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(content: PeerCellContent) {
        if accessibilityLabel() != content.text {
            setAccessibilityLabel(content.text)
        }
        guard content != self.content else { return }
        self.content = content
        render(content)
    }

    private func render(_ content: PeerCellContent) {
        let stack = containerStack()
        let hasChip = content.country != nil
        if hasChip, countryChip == nil {
            let chip = PeerCountryChipView()
            stack.insertArrangedSubview(chip, at: 0)
            countryChip = chip
        } else if !hasChip, let chip = countryChip {
            stack.removeArrangedSubview(chip)
            chip.removeFromSuperview()
            countryChip = nil
        }
        if label == nil {
            let field = NSTextField(labelWithString: "")
            field.lineBreakMode = .byTruncatingTail
            field.maximumNumberOfLines = 1
            // Fills the cell; the field's own alignment handles left/right.
            field.setContentHuggingPriority(.defaultLow, for: .horizontal)
            field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            field.setAccessibilityElement(false)
            stack.addArrangedSubview(field)
            label = field
        }

        countryChip?.text = content.country ?? ""
        stack.spacing = hasChip ? 6 : 0
        label?.stringValue = content.text
        label?.font = content.font
        label?.textColor = content.color
        label?.alignment = content.alignment
    }

    private func containerStack() -> NSStackView {
        if let stackView { return stackView }
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .fill
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(
                equalTo: leadingAnchor, constant: Self.cellInset),
            stack.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -Self.cellInset),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        stackView = stack
        return stack
    }
}

/// Two-letter country chip: caption-size code in a hairline rounded border,
/// mirroring the SwiftUI version's stroked capsule.
final class PeerCountryChipView: NSView {
    var text: String = "" {
        didSet {
            if textLabel.stringValue != text { textLabel.stringValue = text }
            invalidateIntrinsicContentSize()
        }
    }

    private let textLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 3
        layer?.borderWidth = 1
        applyBorderColor()

        textLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        textLabel.textColor = .secondaryLabelColor
        textLabel.setAccessibilityElement(false)
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textLabel)
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
        NSLayoutConstraint.activate([
            textLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            textLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
            textLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 16),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: textLabel.intrinsicContentSize.width + 6, height: 16)
    }

    /// Layer border colors are static CGColor snapshots and don't follow
    /// light/dark appearance flips on their own.
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyBorderColor()
    }

    private func applyBorderColor() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }
}

/// Header cell with the same leading inset the body cells use, so column
/// titles don't sit flush against the divider (see `PaddedTableHeaderCell`
/// in TorrentTableRepresentable for the drawing-hook rationale).
private final class PaddedPeerTableHeaderCell: NSTableHeaderCell {
    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        var inset = cellFrame
        inset.origin.x += PeerTableCellView.cellInset
        inset.size.width -= PeerTableCellView.cellInset
        super.drawInterior(withFrame: inset, in: controlView)
    }
}
