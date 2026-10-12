import SwiftUI
import TransmissionCore

/// Read-only table of connected peers. Columns resize, reorder and show/hide
/// like the main torrent table; the layout persists across launches.
struct InspectorPeersTab: View {
    let torrent: Torrent

    var body: some View {
        PeersTableRepresentable(peers: torrent.peers)
            .overlay {
                if torrent.peers.isEmpty {
                    ContentUnavailableView(
                        "No Peers",
                        systemImage: "person.2.slash",
                        description: Text("No peers are connected right now.")
                    )
                }
            }
    }
}

#Preview {
    InspectorPeersTab(torrent: Torrent.samples[4])
        .frame(width: 322, height: 400)
}
