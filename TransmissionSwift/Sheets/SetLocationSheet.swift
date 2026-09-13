import SwiftUI
import TransmissionCore

/// Sheet for relocating one or more torrents on the daemon host.
///
/// The text field takes a path on the *daemon's* filesystem. Paths starting
/// with `/` are absolute (from the daemon's root); anything else is relative to
/// the daemon's default download directory (`store.downloadDirectory`). `..`
/// and `.` are resolved lexically so the preview always shows the real target.
/// `move` mirrors RPC `torrent-set-location`'s flag: true relocates the existing
/// data, false only repoints the torrent when the data was moved out-of-band.
struct SetLocationSheet: View {
    @Environment(TorrentStore.self) private var store
    @Binding var isPresented: Bool
    let ids: [Torrent.ID]

    @State private var location: String = ""
    @State private var moveData = true
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Set Location")
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                TextField("Location on the server", text: $location)
                    .disabled(isSaving)
                Text("Full path: \(resolvedPath)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Known folders")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(suggestions, id: \.self) { folder in
                                Button(folder) { location = folder }
                                    .font(.caption)
                                    .buttonStyle(.borderless)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .help("Use \(folder)")
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }
            }

            Toggle("Move data to the new location", isOn: $moveData)
                .disabled(isSaving)
                .help(
                    "On: Transmission moves the existing files. Off: only update the path (use when you moved the data yourself)."
                )

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button(isSaving ? "Applying…" : "Apply") {
                    Task { await apply() }
                }
                .buttonStyle(.glassProminent)
                .disabled(isSaving || location.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear { location = initialLocation }
    }

    private var initialLocation: String {
        let selected = store.torrents.filter { ids.contains($0.id) }
        if let first = selected.first {
            return first.downloadFolder
        }
        return store.downloadDirectory ?? ""
    }

    private var subtitle: String {
        ids.count == 1 ? "1 torrent selected" : "\(ids.count) torrents selected"
    }

    private var resolvedPath: String {
        resolveServerPath(location, relativeTo: store.downloadDirectory)
    }

    private var suggestions: [String] {
        let known = store.facets.folders.map(\.name)
        let trimmed = location.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return known }
        let resolved = resolvedPath
        return known.filter {
            $0.localizedCaseInsensitiveContains(trimmed)
                || resolved.localizedCaseInsensitiveContains(resolveServerPath($0, relativeTo: store.downloadDirectory))
        }
    }

    private func apply() async {
        isSaving = true
        defer { isSaving = false }
        let trimmed = location.trimmingCharacters(in: .whitespaces)
        let resolved = resolveServerPath(trimmed, relativeTo: store.downloadDirectory)
        await store.setLocation(ids, location: resolved, move: moveData)
        isPresented = false
    }
}

/// Resolve a torrent location path as the daemon would:
/// - leading `/`  -> absolute from the daemon's root;
/// - otherwise    -> joined onto `base` (the daemon's default download dir);
/// `.` and `..` are resolved lexically without touching the filesystem. `/`
/// paths can't climb above root; relative paths can't climb above `base`.
func resolveServerPath(_ input: String, relativeTo base: String?) -> String {
    let trimmed = input.trimmingCharacters(in: .whitespaces)
    let isAbsolute = trimmed.hasPrefix("/")
    let baseTrimmed = (base ?? "").trimmingCharacters(in: .whitespaces)

    let working: String
    if isAbsolute {
        working = trimmed
    } else if baseTrimmed.isEmpty {
        working = trimmed.isEmpty ? "/" : trimmed
    } else {
        working = trimmed.isEmpty ? baseTrimmed : baseTrimmed + "/" + trimmed
    }

    var out: [String] = []
    for component in working.split(separator: "/", omittingEmptySubsequences: false) {
        let part = String(component)
        if part.isEmpty { continue }
        if part == "." { continue }
        if part == ".." {
            if !out.isEmpty {
                out.removeLast()
            }
            continue
        }
        out.append(part)
    }

    let result = (isAbsolute ? "/" : "") + out.joined(separator: "/")
    if result.isEmpty { return isAbsolute ? "/" : (baseTrimmed.isEmpty ? "" : baseTrimmed) }
    return result
}

#Preview("Set Location") {
    let store = TorrentStore(service: MockTorrentService())
    return SetLocationSheet(isPresented: .constant(true), ids: [2])
        .environment(store)
        .environment(TagColorStore())
        .frame(width: 460)
}
