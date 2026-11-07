# Fork status: upstream sync & port track

This fork tracks [jvacek/TransmissionSwift](https://github.com/jvacek/TransmissionSwift)
via the `upstream` remote. This file records the sync strategy, what this fork
carries on top of upstream, and the open follow-ups — so a future session (or
agent) picks up the fork the same way `doc/ui-buildout.md` used to pick up the
mock-first UI slices.

## Strategy

- `origin` = this fork, `upstream` = jvacek. Never push to `upstream`.
- Sync by **merging** `upstream/main` into `main`. The first merge
  (`7cf3e9b`, upstream v0.7.2, 222 commits) resolved all three conflicts in
  upstream's favour — the fork's local features were all superseded
  (see "Dropped on merge" below).
- Fork features live on `feature/*` branches built on top of merged `main`,
  one porting concern per branch. Current: `feature/peers-columns-port`.
- Branch protection on `main`: force-push and deletion blocked, direct pushes
  allowed, no PR requirement (`enforce_admins` on). Anti-accident only.

## What this fork carries on top of upstream

All on `feature/peers-columns-port`, one commit each:

| Change | Rationale |
|---|---|
| `NilLastDateComparator` — optional date columns (`completedAt`, `startedAt`, `lastActivityAt`) sort missing dates **last in both directions** | Upstream's `Torrent.swift` sort keys use `?? .distantFuture`, which lands undated torrents on top of the descending sort. Upstream's own doc comment already promises "bottom in both directions" — the code contradicts it. Fixes the first visible symptom: sorting "Last Active" newest-first put never-active torrents first. |
| Fixed date formats in the date columns (`dd/MM/yyyy`, `dd/MM/yyyy HH:mm` via `ColumnFormatters.cellDate`/`cellDateTime`, en_GB templates) | Preference over relative renderings ("5 yr. ago"), which hide the actual date in a table. |
| Inspector (`InspectorModel.isVisible`) starts **collapsed** on first launch | A fresh install used to open with the inspector open, hiding the torrents list. |
| Configurable peers table (`PeersTableRepresentable`) in the inspector | Ported from the old `feature/peers-table-columns` branch: resize/reorder/show-hide columns, autosave layout (`inspectorPeersTableColumns`), persisted sort, `PeerSorter` pure sort + tests. Merged with upstream's GeoIP: resolved codes feed the cells through `countryCodes` on every `updateNSView`. |
| Peer country chips render as **flag emoji** (upstream's `countryFlagEmoji`), code chip as fallback | Matches upstream's visual, keeps the AppKit cell design. VoiceOver reads the ISO code. |
| Seeds column shows `active/announced` (`peersSendingToUs`/`seedCount`), em dash when both zero | The numerator is the only live seeds count available in the list poll; a true connected-seed count would require `peers` in `listFields` (rejected — inspector-only by design, heavy payload). |

`peersSendingToUs` also participates in `TorrentRowDisplay` equality, and the
drift test (`TorrentRowDisplayTests`) mutates it alongside `seedCount`.

## Dropped on merge (deliberately)

| Old fork feature | Why dropped |
|---|---|
| Activity column + `activityAt` sorting | Upstream's "Last Active" (v0.5.5) maps the same RPC field (`activityDate`) with sentinel handling and tests. |
| Sent column (`uploadedEver`) | Upstream's "Total UL" column shows the same field. |
| `columnOrder`/`columnWidths` persistence plumbing | Upstream persists order/widths/visibility via `NSTableView` autosave (`torrentsTableColumns`). |
| Seed display `connected/announced` from `torrent.peers` | `peers` is fetched only for the inspector torrent (`inspectorFields`); table rows carried an empty array, so the fork always rendered "0/N". |
| `af15f44` persistent-sort fix | Superseded by upstream's "persisted table preferences as the single sort source". |

## Open follow-ups

1. **PR upstream: the `NilLastDateComparator` fix.** Small (one Core file + one
   test), fixes a real ordering bug against upstream's documented intent.
   Branch it off upstream/main directly, not off this fork's merged base.
2. **Sentry DSN before any public distribution.** `SENTRY_DSN` (jvacek's
   ingest URL) is committed for Debug and Release: crash reports from
   distributed builds land in his Sentry project (opt-in, default off).
   Empty the build setting or substitute your own DSN before shipping a
   fork release. Irrelevant for personal builds.
3. **Old feature branches on origin** (`activity-sort`, `column-persistence`,
   `torrent-table-columns`, `peers-table-columns`) are archives of pre-merge
   work; delete when comfortable.
4. Optional: a true connected-seeds column would need `peers` (or a lighter
   per-peer field set) in `listFields` — upstream keeps that inspector-only
   for payload reasons; do not regress lightly.

## Notes on GeoIP flags

The DB-IP country database is **not bundled**: it downloads on first display
of the inspector's Peers tab (~seconds, cached a month in the app container's
`Application Support/net.jvacek.TransmissionSwift/GeoIP`). First-ever view of
the tab shows no flags until that lands; resolution is local afterwards —
peer IPs never leave the machine. Toggle: Settings → peer country flags
(default on).
