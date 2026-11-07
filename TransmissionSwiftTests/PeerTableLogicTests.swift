import Foundation
import Testing
import TransmissionCore

@testable import TransmissionSwift

/// Unit coverage for the peers table's pure sort logic. UI behaviors (header
/// clicks, autosave, indicator rendering) are AppKit-side; this targets
/// `PeerSorter` — the piece the snapshot UI test can't reach.
struct PeerTableLogicTests {
    // MARK: - Fixture

    private func makePeer(
        ipAddress: String,
        client: String = "Transmission 4.0",
        flags: String = "D",
        progress: Double = 0.5,
        downloadSpeed: Int64 = 0,
        uploadSpeed: Int64 = 0
    ) -> Peer {
        Peer(
            ipAddress: ipAddress,
            client: client,
            countryCode: nil,
            flags: flags,
            progress: progress,
            downloadSpeed: downloadSpeed,
            uploadSpeed: uploadSpeed)
    }

    private let unsortedPeers = [
        Peer(
            ipAddress: "10.0.0.10", client: "qBittorrent 5", flags: "U",
            progress: 0.9, downloadSpeed: 500, uploadSpeed: 3_000),
        Peer(
            ipAddress: "10.0.0.2", client: "Transmission 4.1", flags: "D",
            progress: 0.1, downloadSpeed: 50_000, uploadSpeed: 0),
        Peer(
            ipAddress: "192.168.1.3", client: "Deluge 2", flags: "K",
            progress: 0.5, downloadSpeed: 1_000, uploadSpeed: 1_000),
    ]

    // MARK: - No sort state

    @Test func sorted_withoutState_keepsSnapshotOrder() {
        #expect(PeerSorter.sorted(unsortedPeers, by: nil) == unsortedPeers)
    }

    // MARK: - Per-column ordering

    @Test func sorted_byAddress_isNumericAware() {
        // Plain string compare would put "10.0.0.10" before "10.0.0.2".
        let sorted = PeerSorter.sorted(
            unsortedPeers,
            by: PeerSortState(column: .address, ascending: true))
        #expect(
            sorted.map(\.ipAddress) == ["10.0.0.2", "10.0.0.10", "192.168.1.3"])
    }

    @Test func sorted_byClient_ascending() {
        let sorted = PeerSorter.sorted(
            unsortedPeers,
            by: PeerSortState(column: .client, ascending: true))
        #expect(
            sorted.map(\.client) == ["Deluge 2", "qBittorrent 5", "Transmission 4.1"])
    }

    @Test func sorted_byProgress_descending() {
        let sorted = PeerSorter.sorted(
            unsortedPeers,
            by: PeerSortState(column: .progress, ascending: false))
        #expect(sorted.map(\.progress) == [0.9, 0.5, 0.1])
    }

    @Test func sorted_byDownloadSpeed_descending() {
        let sorted = PeerSorter.sorted(
            unsortedPeers,
            by: PeerSortState(column: .downloadSpeed, ascending: false))
        #expect(
            sorted.map(\.downloadSpeed) == [50_000, 1_000, 500])
    }

    @Test func sorted_byUploadSpeed_ascending() {
        let sorted = PeerSorter.sorted(
            unsortedPeers,
            by: PeerSortState(column: .uploadSpeed, ascending: true))
        #expect(sorted.map(\.uploadSpeed) == [0, 1_000, 3_000])
    }

    @Test func sorted_byFlags_ascending() {
        let sorted = PeerSorter.sorted(
            unsortedPeers,
            by: PeerSortState(column: .flags, ascending: true))
        #expect(sorted.map(\.flags) == ["D", "K", "U"])
    }

    @Test func sortState_equality() {
        #expect(
            PeerSortState(column: .progress, ascending: true)
                == PeerSortState(column: .progress, ascending: true))
        #expect(
            PeerSortState(column: .progress, ascending: true)
                != PeerSortState(column: .progress, ascending: false))
        #expect(
            PeerSortState(column: .progress, ascending: true)
                != PeerSortState(column: .client, ascending: true))
    }
}
