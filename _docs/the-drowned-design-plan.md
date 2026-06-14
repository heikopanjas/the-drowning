# The Drowned — Design & Implementation Plan

**Status:** design complete, ready to build · **Target:** macOS (v1) · **Stack:**
Swift 6.2, SwiftUI, GRDB, MapKit · **Last updated:** 13 June 2026

A monitoring application for the IOM Missing Migrants Project dataset. Two
surfaces — a background agent that acquires data and posts notifications on
newly recorded incidents, and a SwiftUI map of incidents in the selected
region(s).
macOS is the v1 target; iOS is deferred but designed for reuse from the start
(§3.4). A server tier is deferred too, and the architecture is shaped so both
can be introduced later without touching the app.

> The name treats "The Drowned" as a proper name, not a literal field
> description. The default region of interest is the Mediterranean, where
> drowning is the dominant fate and the name is most true. When the user
> switches to a land route (Sahara, US–Mexico desert, Darién Gap) the records
> describe other causes; the name stands as the app's identity regardless.

## Contents

1. Scope and platforms
2. Data source — what it is · update cadence · UI caveats · licence · CSV schema
3. Architecture — the seam · module layout · UI framework decision · iOS reuse
4. The shared core — model · store · CSV parsing · `SyncEngine` · `LocalPollingSync` · notifications
5. Platform shells — macOS app + LaunchAgent · iOS (deferred) · map · window layout
6. Concurrency model
7. Settings and persistence — shared settings · view-state persistence
8. Notifications — flow
9. Server-tier migration path
10. Testing
11. Implementation sequencing
12. Open questions to revisit
13. Attribution block

**Build order:** §11 is the sequencing. Start with the model + `IncidentFilter`,
then the CSV parser with its fixtures (the two parsing gotchas in §2.5 plus the
non-unique-`web_id` cases), then the store — these are the foundation everything
else compiles against.

---

## 1. Scope and platforms

**v1 is macOS-only.** iOS is deferred to a later phase but kept in mind
throughout: the architecture is structured so iOS reuses the maximum amount of
code (see §3.4). iOS specifics below are retained as the forward plan, not v1
work.

- **Agent (acquisition + notification).** macOS: a headless `LSUIElement` helper
  *app bundle* registered as a LaunchAgent (`SMAppService.agent`), scheduled by
  launchd. iOS *(deferred)*: the app itself driving `BGTaskScheduler`
  (best-effort by OS scheduling — see §5.2).
- **App (map).** SwiftUI surface: a MapKit map of
  incidents filtered to the selected region(s), an incident detail view, region
  filters, and the required source attribution and caveats.
- **Deferred:** the iOS app (§3.4, §5.2) and a server tier that moves polling
  off-device and delivers notifications via APNs. The server tier is what later
  makes iOS notifications reliable; macOS is fully functional locally today.
  See §9.

---

## 2. Data source

### 2.1 What it is

The IOM Missing Migrants Project records incidents in which migrants —
including refugees and asylum-seekers — have died or gone missing during
migration toward an international destination, since 2014. It is distributed as
an open dataset (CSV/XLS) with an accompanying codebook.

- **Stable CSV endpoint (Humanitarian Data Exchange):**
  `https://data.humdata.org/dataset/fc59785a-31d2-4018-aac7-6b9f619ae8ec/resource/99078436-9c4a-473b-a073-428304a9cf8a/download/iom-missing-migrants-project-data.csv`
- **Project site:** `https://missingmigrants.iom.int/`

### 2.2 Update cadence — design implication

The dataset is **curated and published in batches**, not a live feed. Records
are verified and added (and sometimes revised) days to weeks after an event.
Consequences:

- A "new incident" in this app means a **newly published record**, not a
  breaking event. Notification copy must say "newly recorded" rather than imply
  immediacy.
- Polling can be gentle: **once daily is sufficient.** There is no value in a
  high-frequency poll.
- Records can change after first publication (corrected counts, fixed
  coordinates). The diff must detect **revisions** as well as **new rows**
  (§4.6).

### 2.3 Caveats to surface in the UI

- **Minimum estimates.** The figures are explicitly a lower bound — many deaths
  go unrecorded. Show this near any aggregate count, not buried.
- **Approximate locations.** Coordinates are approximate; the map should not
  imply pinpoint precision (consider a subtle radius/uncertainty treatment or a
  note in the detail view).
- **No personal identities.** Records are incident-level and anonymous, so there
  is no personal-data sensitivity in the dataset itself. SQLCipher is therefore
  **not required** here (unlike Dashboard of Doom) — a plain SQLite store keeps
  it simple.

### 2.4 Licence and attribution (CC BY 4.0)

The data is licensed CC BY 4.0. Attribution is mandatory and must state the
source and note if changes were made. Drop-in text for the About screen:

```
Data: IOM's Missing Migrants Project (missingmigrants.iom.int),
licensed under CC BY 4.0. Data has been reformatted and filtered for
display; figures are minimum estimates and locations are approximate.
```

### 2.5 Exact CSV schema

Twenty-one columns. Types below are the *parsed* target types; every numeric
field can be **empty** in the source and must be treated as optional.

| Column (source)            | Parsed type   | Notes |
|----------------------------|---------------|-------|
| `web_id`                   | `String`      | Per-incident id, **not row-unique** — incidents are sometimes split into multiple rows by origin, and exact-duplicate rows occur. See §4.1/§4.2. |
| `region`                   | `String`→enum | e.g. `Mediterranean`, `North America`, `South-eastern Asia`. Drives the region filter. |
| `reported_date`            | `Date`        | `yyyy-MM-dd`. Incident date (approximate). |
| `number_dead`              | `Int?`        | May be empty. |
| `number_missing`           | `Int?`        | May be empty. |
| `total_dead_and_missing`   | `Int?`        | Usually present. |
| `number_of_survivors`      | `Int?`        | Often empty. |
| `number_of_female`         | `Int?`        | Often empty. |
| `number_of_male`           | `Int?`        | Often empty. |
| `number_of_children`       | `Int?`        | Often empty. |
| `cause_death`              | `String`      | e.g. `Drowning`, `Mixed or unknown`, `Harsh environmental conditions / lack of adequate shelter, food, water`. |
| `country_of_incident`      | `String`      | |
| `location_description`     | `String`      | **Contains embedded newlines inside quotes.** |
| `unsd_geographic_grouping` | `String`      | |
| `location_coodinates`      | `Coordinate?` | **Misspelled in source** (`coodinates`). Single field `"lat, lon"`. May be empty → unmappable. |
| `migration_route`          | `String?`     | Finer than `region`, e.g. `Central Mediterranean`, `Eastern Mediterranean`, `US-Mexico border crossing`. May be empty. |
| `information_source`       | `String?`     | |
| `url`                      | `String?`     | Source link. |
| `source_quality`           | `Int?`        | 1–5 scale. |
| `region_origin`            | `String?`     | |
| `country_origin`           | `String?`     | |

**Parsing gotchas (all are first-class requirements):**

1. **Use an RFC-4180 CSV parser, never line-splitting.** `location_description`
   embeds raw newlines inside quoted fields; splitting on `\n` corrupts every
   record after the first multiline one.
2. **Coordinate column key is `location_coodinates`** (typo). Hard-code the
   misspelling; do not "correct" it.
3. **Coordinate value is one field** of the form `"32.22804, -112.590416"`
   (lat first, lon second). Split on comma, trim, parse two `Double`s; if either
   fails or the field is empty, the incident is **not mappable** (store it, omit
   from the map).
4. **Empty numerics** are empty strings, not `0`. Map `""` → `nil`.

---

## 3. Architecture

### 3.1 The seam

The app reads only from the **local store** — never from the network. That one
decision makes the UI source-agnostic: the map does not care whether a record
arrived via local CSV poll or a future server push. The swap point for the
server tier is therefore *not in the app*; it is the boundary of **who fills the
store and who decides what is new**, expressed as the `SyncEngine` protocol.

```
IOM CSV (now) ─┐                          ┌─ macOS LaunchAgent helper (launchd-scheduled)
               ├─▶ SyncEngine ─▶ store ◀──┤   + windowed macOS app (reads store)
Server (later)─┘   (LocalPollingSync now,  └─ iOS app (BGTaskScheduler, best-effort)
                    RemoteSync later)
                         │
                         └─▶ NotificationCoordinator
```

Only the left edge changes when the server arrives: a new `RemoteSync` conforms
to the same `SyncEngine`, and APNs feeds the same `NotificationCoordinator`. The
store, the notification logic, and the entire SwiftUI surface are untouched.

### 3.2 Module layout (Swift Package + app targets)

A single SPM package holds everything reusable; thin platform targets wrap it.

```
TheDrowned/                       (Xcode workspace)
├── Packages/
│   └── DrownedCore/              (Swift package — Swift 6.2, strict concurrency)
│       ├── Sources/
│       │   ├── DrownedModel/     Incident, Region, Coordinate, SyncOutcome
│       │   ├── DrownedStore/     GRDB store, migrations, queries, ValueObservation
│       │   ├── DrownedSync/      SyncEngine protocol, LocalPollingSync, CSV parser
│       │   ├── DrownedNotify/    NotificationCoordinator
│       │   └── DrownedUI/        SwiftUI map, view models, filters, detail
│       └── Tests/
│           ├── DrownedSyncTests/
│           ├── DrownedStoreTests/
│           └── DrownedModelTests/
├── TheDrowned-macOS/             (windowed app target → depends on DrownedCore)
├── TheDrowned-macOS-Agent/       (LSUIElement helper app bundle → DrownedCore;
│                                  embedded in the macOS app, run as a LaunchAgent)
└── TheDrowned-iOS/               (app target → depends on DrownedCore)
```

Rationale: mirrors the AranetKit / Dashboard of Doom pattern. `DrownedUI` is a
package target holding the shared UI substrate — view models, the map
controller/coordinator, the incident detail, reusable components — but **not a
single identical screen layout for both platforms**. The macOS and iOS
presentations are expected to diverge (see §3.3); `DrownedUI` namespaces the
per-platform views (`MapScreen_macOS`, `MapScreen_iOS`) over a shared model and
data layer. The macOS background work lives in a **separate helper app bundle**
(it cannot live in a bare CLI tool — see §5.1); scheduler/helper wiring and
window hosting live in the app targets.

### 3.3 UI framework: decision and rationale

**Decision.** SwiftUI shell on both platforms, with an `MKMapView` wrapped in a
representable (`NSViewRepresentable` / `UIViewRepresentable`) for the map itself,
to get native `MKClusterAnnotation` clustering. Not a full AppKit/UIKit UI.

**Why this was a real question.** The architecture's seam means the UI framework
is a swappable concern, not a load-bearing one. The entire spine — model, store,
`SyncEngine`/`LocalPollingSync`, `NotificationCoordinator`, App Group, and the
background acquisition (a launchd-scheduled LaunchAgent on macOS, `BGTaskScheduler`
on iOS — neither is SwiftUI) — contains no SwiftUI. A UI-framework switch is
confined to
`DrownedUI` and the presentation half of the two shells. So evaluating
AppKit/UIKit is reasonable, not a rewrite.

**What a full AppKit/UIKit design would gain.** `MKMapView` becomes a first-class
citizen rather than a wrapped guest: direct instantiation, mature native
clustering, annotation-view reuse, precise cluster styling, and better
performance when pushing thousands of live annotations than the declarative
SwiftUI `Map` provides. For a map-dominated, high-density app that control is
real.

**What it would cost.** AppKit and UIKit are different frameworks and share no
view-layer code. Useful nuance: MapKit is a *single* framework across macOS and
iOS, so a map controller coordinating `MKMapView`, the annotation set, and
delegate callbacks can be largely shared behind a few `#if os()` seams. But
everything around the map — windows/scenes, region filters, incident detail,
settings, navigation — is `NSViewController`/`NSWindow` on one side and
`UIViewController`/`UINavigationController` on the other, written twice, by hand,
including the accessibility and platform adaptation SwiftUI provides for free.
Data binding also becomes manual: instead of `ValueObservation.values(in:)`
feeding an `@Observable` model the view re-reads, you consume the same
observation via `start(in:onChange:)` and imperatively diff incoming incidents
against the map's current annotations (add/remove). GRDB supports this fine; it
is just wiring you own.

**Clustering is not a reason to switch.** The baseline already captures native
`MKClusterAnnotation` through the representable. So the *marginal* gain of going
fully native over the baseline is not "we can now cluster" — it is "maximum map
control and peak performance at extreme annotation counts, with no SwiftUI in the
map path." That is a narrower benefit than it first appears.

**Field note (Dashboard of Doom experience).** The premise that SwiftUI buys "one
shared UI for both platforms" is too strong, and prior experience bears this out:
the iOS and macOS UIs diverged substantially in practice, and **map-view design
decisions in particular did not transfer between platforms**. This refines —
rather than overturns — the decision. The accurate comparison is not "shared
(SwiftUI) vs. duplicated (AppKit/UIKit)," because the per-platform views diverge
either way. It is about the size of the *shared substrate beneath* the divergent
views:

- With SwiftUI, divergent `MapScreen_macOS` and `MapScreen_iOS` still share one
  language, the same view-model and `@Observable`/`ValueObservation` binding
  model, the same reusable components (detail, filters, notices), the same map
  representable, and the data layer. The divergence is in layout and interaction,
  over a large common base.
- With AppKit/UIKit, the divergent screens share *nothing* at the view layer —
  two frameworks, two idioms — and the only meaningful shared UI code is the
  MapKit controller, which is shareable in the SwiftUI design too.

So platform divergence, which is real and expected here, is an argument *for*
keeping SwiftUI, not against it: it makes the inevitable divergence cheaper by
maximizing what sits underneath it. The map screens will be written per-platform
under either framework; SwiftUI just lets the rest be shared.

**When the full-native call would flip.** If The Drowned became map-*dominated* —
overlay-heavy, custom annotation rendering, extreme scale, minimal chrome — the
SwiftUI shell would add little and an `MKMapView`-centric native design would be
cleaner. The app today is not that: it has genuine chrome (region filters, detail,
settings, a primary map window the user explores at length) where SwiftUI earns
its keep, and the map benefit that matters (clustering) is already captured via
the representable.

**The macOS background split is orthogonal to the UI framework.** Acquisition and
notification run in a separate headless LaunchAgent helper (§5.1) regardless of
whether the main UI is SwiftUI or AppKit, so it exerts no pull toward AppKit. The
main app is a normal windowed app either way.

**Revisit if:** annotation counts on a single screen routinely exceed what a
wrapped `MKMapView` renders smoothly; or custom map overlay/rendering needs grow
past what the representable cleanly exposes; or the chrome shrinks to the point
that the map is effectively the whole app.

### 3.4 iOS reuse plan (deferred)

iOS is deferred, but every decision is made so that adding it later is additive,
not a refactor. What gets reused versus newly written when iOS arrives:

**Reused unchanged (no platform code):**

- The entire `DrownedCore` non-UI spine — `DrownedModel`, `DrownedStore`,
  `DrownedSync` (incl. `LocalPollingSync`), `DrownedNotify`. These are pure Swift
  over Foundation + GRDB + UserNotifications, all cross-platform.
- The view models (`@Observable`) and the `ValueObservation`-based data binding.
- `IncidentFilter` and the query it compiles to (§5.3) — the filtering *logic* is
  core; only the sidebar's presentation differs per platform.
- View-state persistence — `ViewStateStore` and `CameraState` (§7.2) are
  platform-neutral (`UserDefaults` + `Codable`); only the `scenePhase` save hook
  is wired per app target.
- The **map controller** (§5.3): all `MKMapView` behavior — annotation diffing,
  clustering configuration, delegate callbacks — lives in a platform-neutral
  `@MainActor` class, because `MKMapView`/MapKit is one framework across both
  OSes.
- Reusable SwiftUI components: incident detail, the minimum-estimate notice,
  attribution.

**Newly written for iOS (small, bounded):**

- A thin `UIViewRepresentable` wrapping the shared map controller (the macOS side
  is the `NSViewRepresentable`; ~20 lines each, same controller).
- `MapScreen_iOS` layout — touch targets, sheets/`NavigationStack` instead of an
  inspector, the filter sidebar re-presented as a compact filter sheet. Diverges
  from `MapScreen_macOS` by design (§3.3); consumes the same view model and the
  same `IncidentFilter`.
- The iOS background trigger — `BGTaskScheduler` registration in the app target
  (§5.2). It calls the same `SyncEngine` + `NotificationCoordinator` the macOS
  helper calls; only the *trigger* differs.

**The one discipline that protects all of this:** keep every `#if os(macOS)`
confined to the macOS app target, the LaunchAgent helper, and the map
representable. Nothing platform-specific (`SMAppService`, launchd, AppKit) may
leak into `DrownedModel`/`Store`/`Sync`/`Notify`. If it needs a guard inside the
core, that is the signal to lift it into a shell instead.

---

## 4. The shared core

> All snippets target **Swift 6.2 with strict concurrency**. They are
> scaffolding to anchor the design, not finished implementations.

### 4.1 Model

```swift
public struct Coordinate: Sendable, Hashable, Codable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Parses the source `"lat, lon"` single-field format. Returns nil on
    /// empty/malformed input (incident is then non-mappable).
    public init?(field: String) {
        let parts = field.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard parts.count == 2,
              let lat = Double(parts[0]), let lon = Double(parts[1]) else {
            return nil
        }
        self.latitude = lat
        self.longitude = lon
    }
}

public struct Incident: Sendable, Identifiable, Hashable, Codable {
    /// Synthetic row identity. `web_id` is NOT row-unique (incidents split by
    /// origin share one), so identity is web_id + content fingerprint.
    public var id: String { "\(webID)#\(contentHash)" }

    public let webID: String                 // indexed, non-unique (§4.2)
    public let region: Region
    public let reportedDate: Date
    public let numberDead: Int?
    public let numberMissing: Int?
    public let totalDeadAndMissing: Int?
    public let numberOfSurvivors: Int?
    public let numberOfFemale: Int?
    public let numberOfMale: Int?
    public let numberOfChildren: Int?
    public let causeOfDeath: String
    public let countryOfIncident: String
    public let locationDescription: String
    public let unsdGeographicGrouping: String
    public let latitude: Double?             // split from the single CSV field at import
    public let longitude: Double?            // nil ⇒ not mappable
    public var coordinate: Coordinate? {     // computed — not stored, not a column
        guard let latitude, let longitude else { return nil }
        return Coordinate(latitude: latitude, longitude: longitude)
    }
    public let migrationRoute: String?
    public let informationSource: String?
    public let sourceURL: String?
    public let sourceQuality: Int?
    public let regionOrigin: String?
    public let countryOrigin: String?

    /// Content fingerprint for revision detection (see §4.6). Excludes webID.
    public let contentHash: Int
}
```

```swift
public enum Region: String, Sendable, CaseIterable, Codable, Identifiable {
    // Confirmed present in the data:
    case mediterranean       = "Mediterranean"
    case northAmerica        = "North America"
    case centralAmerica      = "Central America"
    case southAmerica        = "South America"
    case caribbean           = "Caribbean"
    case northernAfrica      = "Northern Africa"
    case easternAfrica       = "Eastern Africa"
    case westernAfrica       = "Western Africa"
    case middleAfrica        = "Middle Africa"
    case southernAfrica      = "Southern Africa"
    case westernAsia         = "Western Asia"
    case centralAsia         = "Central Asia"
    case southernAsia        = "Southern Asia"
    case southEasternAsia    = "South-eastern Asia"
    case easternAsia         = "Eastern Asia"
    case europe              = "Europe"          // UN's four Europe regions, combined
    case oceania             = "Oceania"         // combined
    case unknown             = "Unknown"         // fallback for unmapped strings

    public var id: String { rawValue }

    public init(source: String) { self = Region(rawValue: source) ?? .unknown }
}
```

> **The value set is not frozen.** The cases above marked from the 2014 slice are
> confirmed by exact spelling (Mediterranean, North/Central America, Caribbean,
> Europe, Northern/Eastern Africa, Western/Southern/South-eastern Asia); the rest
> follow the documented UNSD-subregion scheme (Europe and Oceania each collapsed
> to one region, the Mediterranean added as its own) and should be reconciled
> against `cut -d, -f2 data.csv | tail -n +2 | sort -u` on the live download.
> There is **no** "Sub-Saharan Africa" in `region` — that appears only in
> `region_origin`. IOM states the categories may change, so keep the `.unknown`
> fallback and persist the *raw* region string alongside the enum. Each region
> also carries a default `MKCoordinateRegion` viewport for cold-start framing
> (§5.4).

### 4.2 Store: GRDB schema

Plain SQLite (no SQLCipher — public data) in the **App Group container** so the
agent writes and the app reads the same file.

```swift
import GRDB

enum AppGroup {
    static let identifier = "group.com.panjas.thedrowned"

    static func storeURL() -> URL {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: identifier)!
            .appendingPathComponent("drowned.sqlite")
    }
}

extension Incident: FetchableRecord, PersistableRecord {
    static let databaseTableName = "incident"
}

func makeMigrator() -> DatabaseMigrator {
    var m = DatabaseMigrator()
    m.registerMigration("v1") { db in
        try db.create(table: "incident") { t in
            t.autoIncrementedPrimaryKey("rowID")        // synthetic; web_id is not unique
            t.column("webID", .text).notNull().indexed()  // non-unique index
            t.column("region", .text).notNull().indexed()
            t.column("reportedDate", .date).notNull().indexed()
            t.column("numberDead", .integer)
            t.column("numberMissing", .integer)
            t.column("totalDeadAndMissing", .integer)
            t.column("numberOfSurvivors", .integer)
            t.column("numberOfFemale", .integer)
            t.column("numberOfMale", .integer)
            t.column("numberOfChildren", .integer)
            t.column("causeOfDeath", .text).notNull()
            t.column("countryOfIncident", .text).notNull()
            t.column("locationDescription", .text).notNull()
            t.column("unsdGeographicGrouping", .text).notNull()
            t.column("latitude", .double)        // flattened Coordinate
            t.column("longitude", .double)
            t.column("migrationRoute", .text)
            t.column("informationSource", .text)
            t.column("sourceURL", .text)
            t.column("sourceQuality", .integer)
            t.column("regionOrigin", .text)
            t.column("countryOrigin", .text)
            t.column("contentHash", .integer).notNull()
        }
    }
    return m
}
```

Open the database with WAL mode (`DatabasePool`) so the writing agent and the
reading UI don't block each other. Compound index on `(region, reportedDate)`
serves the default Mediterranean-by-date query.

### 4.3 Store: the writer/reader boundary

```swift
public actor IncidentStore {
    /// `Sendable` + `nonisolated`: the @MainActor UI observes reads directly via
    /// `store.dbPool` (no actor hop); all writes go through this actor's methods.
    public nonisolated let dbPool: DatabasePool

    public init(url: URL = AppGroup.storeURL()) throws {
        dbPool = try DatabasePool(path: url.path)
        try makeMigrator().migrate(dbPool)
    }

    /// Monotonic set of every web_id ever imported (small kv table), for
    /// first-seen notification — survives the full-replace below.
    public func seenWebIDs() throws -> Set<String> { /* dbPool.read { … } */ }
    public func markSeen(_ webIDs: Set<String>) throws { /* dbPool.write { … } */ }

    /// Full-replace reconcile in one transaction: dedupe byte-identical rows,
    /// truncate, bulk-insert. The download is the complete dataset each import,
    /// which sidesteps per-row identity (web_id isn't unique).
    public func replaceAll(_ incidents: [Incident]) throws { /* dbPool.write { delete + insert } */ }
}
```

### 4.4 CSV parsing

Prefer a **zero-dependency** parser. Two viable routes:

- **`TabularData` (Apple framework)** — RFC-4180 compliant, handles quoted
  multiline fields, no third-party dependency. Reads into a `DataFrame`; for
  ~tens of thousands of rows once daily this is acceptable. Read every column as
  `String` and map manually (avoids type-inference surprises on empty cells).
- **A small hand-rolled RFC-4180 state-machine parser** if you want streaming
  and zero in-memory `DataFrame`. More code, but matches the minimal-dependency
  preference and gives full control.

Either way the parser is isolated behind a function and runs **off the main
actor** (it's CPU/IO work):

```swift
struct IncidentCSVParser {
    // @concurrent (Swift 6.2) so it runs off the caller's actor.
    @concurrent
    func parse(_ data: Data) async throws -> [Incident] {
        // 1. RFC-4180 decode (TabularData or state machine)
        // 2. For each row: map columns → Incident
        //    - empty string → nil for numerics
        //    - reported_date via a fixed DateFormatter: en_US_POSIX, UTC, "yyyy-MM-dd"
        //    - split row["location_coodinates"] (typo; single "lat, lon" field)
        //      via Coordinate(field:) → store latitude & longitude separately
        //    - Region(source: row["region"])
        //    - compute contentHash over all fields except webID
    }
}
```

### 4.5 The seam: `SyncEngine`

```swift
public struct SyncOutcome: Sendable {
    public let newWebIDs: Set<String>         // first-seen this import → notify
    public let newIncidents: [Incident]       // the rows belonging to those web_ids
    public let totalRows: Int
    public let completedAt: Date
}

public protocol SyncEngine: Sendable {
    /// Reconcile the local store with the latest data, returning what changed.
    func sync() async throws -> SyncOutcome
}
```

### 4.6 `LocalPollingSync` (today's implementation)

```swift
public actor LocalPollingSync: SyncEngine {
    private let endpoint: URL
    private let store: IncidentStore
    private let parser = IncidentCSVParser()
    private let session: URLSession

    public func sync() async throws -> SyncOutcome {
        try Task.checkCancellation()
        let (data, _) = try await session.data(from: endpoint)

        let incidents = try await parser.parse(data)        // off-actor; dedupes identical rows
        try Task.checkCancellation()

        let seen = try await store.seenWebIDs()
        let incomingIDs = Set(incidents.map(\.webID))
        let newIDs = incomingIDs.subtracting(seen)

        try await store.replaceAll(incidents)               // full reconcile
        try await store.markSeen(incomingIDs)

        let newIncidents = incidents.filter { newIDs.contains($0.webID) }
        return SyncOutcome(newWebIDs: newIDs, newIncidents: newIncidents,
                           totalRows: incidents.count, completedAt: .now)
    }
}
```

Diff rule: **a "new incident" is a `web_id` not present in any prior import.**
Because rows that share a `web_id` (origin splits) collapse to one id in the
set, a multi-row incident notifies exactly once. The store is kept in step with
the file by full replace, so revisions need no per-row identity. First-ever run:
the seen-set is empty, so mark everything seen but **suppress notifications**
(cold start, not 90k new incidents).

### 4.7 `NotificationCoordinator`

```swift
import UserNotifications

public struct NotificationCoordinator: Sendable {
    /// Posts one grouped notification per affected region the user opted into.
    public func post(_ outcome: SyncOutcome,
                     notifyRegions: Set<Region>) async {
        let relevant = outcome.newIncidents.filter {
            notifyRegions.contains($0.region)
        }
        guard !relevant.isEmpty else { return }

        for (region, group) in Dictionary(grouping: relevant, by: \.region) {
            let count = Set(group.map(\.webID)).count        // distinct incidents, not rows
            let dead = group.compactMap(\.totalDeadAndMissing).reduce(0, +)
            let content = UNMutableNotificationContent()
            content.title = region.rawValue
            content.body  = "\(count) newly recorded "
                + (count == 1 ? "incident" : "incidents")
                + " · \(dead) dead or missing"
            content.threadIdentifier = "region.\(region.rawValue)"  // groups
            // schedule with a nil trigger (deliver now)
        }
    }
}
```

Copy guidelines: **"newly recorded," never "just happened."** Batch per region
per sync — one refresh can add dozens of rows; never fire one notification per
row. Respect the user's `notifyRegions` setting (§7.1). Tone: factual and grave;
no badges-as-gamification, no celebratory language.

---

## 5. Platform shells

### 5.1 macOS — windowed app + LaunchAgent helper

The map is a place the user spends real time in, so the main app is a **standard
windowed app** (`WindowGroup`, full chrome, Dock presence), not a menubar/popover
app. But a windowed app only runs while open — to acquire data and notify when
it's closed, the background work lives in a **separate helper**, and the helper's
form is constrained by how macOS notifications work.

**Why the helper must be an app bundle, run as a LaunchAgent.** Posting a
`UNUserNotification` requires a bundle identity: a bare CLI binary calling
`UNUserNotificationCenter.current()` crashes with `bundleProxyForCurrentProcess
is nil`, and the framework only delivers from **signed** executables. A plain
launch-agent tool also gets `UNErrorCodeNotificationsNotAllowed`. And it must be
a **LaunchAgent** (runs in the user GUI session), never a **LaunchDaemon** (runs
outside the session and cannot reach Notification Center). So the helper is a
headless **app bundle** with `LSUIElement = true` (no Dock icon, no window),
launched by launchd.

**Shape:**

- `TheDrowned-macOS-Agent.app` — `LSUIElement` helper bundle, embedded in the
  main app (e.g. `Contents/Library/…`), signed with the same team.
- Registered via `SMAppService.agent(plistName:)`; the bundled launchd plist
  uses `StartCalendarInterval` (≈ daily). launchd starts the helper on schedule
  in the user session — and if the Mac was asleep at the scheduled time, at the
  next wake. The helper polls, writes the store, posts notifications, then exits;
  it does **not** stay resident (no `NSBackgroundActivityScheduler` — launchd is
  the scheduler).
- The helper requests its **own** notification authorization (authorization is
  per bundle id). Set its `CFBundleDisplayName`/icon so notifications read as
  "The Drowned."
- **Notification taps relaunch the poster** (the helper). The helper therefore
  owns a tiny `UNUserNotificationCenterDelegate`; on tap it opens the main app
  via a custom URL scheme, passing the region so the map deep-links.
- Both the helper and the main app carry the **App Group** entitlement and share
  the SQLite store (§4.2). The main app additionally runs a foreground `sync()`
  on launch and on demand, so an open window is always current.

> Optional hardening (defer): if per-bundle-id notification authorization for the
> helper proves fiddly, the documented fallback is a non-UI agent that hands off
> to a small UI bundle over XPC, which posts. Not needed for v1 — the headless
> helper-bundle path is sufficient.

### 5.2 iOS — app with background refresh *(deferred — see §3.4)*

Not v1. Retained as the forward plan. When built, the app target adds:

- Register `BGAppRefreshTaskRequest` (light) and/or `BGProcessingTaskRequest`
  (for the heavier parse) with the earliest-begin-date set ~daily.
- `Info.plist`: `BGTaskSchedulerPermittedIdentifiers` +
  `UIBackgroundModes` (`fetch`/`processing`).
- **Honest limitation:** the OS decides if/when these run. Notifications are
  **best-effort** until the server tier exists. Mitigate by always running a
  foreground `sync()` on launch and on `scenePhase == .active`, so the map is
  current whenever the user opens the app even if background fire was skipped.
- Reschedule the next task at the end of each run (tasks are one-shot).

### 5.3 Shared SwiftUI map (`DrownedUI`)

Follows *The SwiftUI Way*: `@Observable` view model, narrow view dependencies,
`task(id:)` for lifecycle, native components, no heavy work in `init`/`body`.

The model observes the store by the **whole filter set**, not region alone (the
sidebar in §5.4 drives every field). `IncidentFilter` is a `Sendable`,
`Hashable`, `Codable` value type living in `DrownedModel`/`DrownedStore`, so it —
the query it compiles to, and its persistence (§7.2) — are reused on iOS
unchanged (§3.4).

```swift
public struct IncidentFilter: Sendable, Hashable, Codable {
    public var regions: Set<Region> = [.mediterranean]  // empty = all; default region of interest
    public var routes: Set<String> = []                 // empty = all routes in selected regions; cascades (§5.4)
    public var dateRange: ClosedRange<Date>? = nil
    public var causes: Set<String> = []                 // empty = all causes
    public var mappableOnly = true
    // …extend as needed (source quality, origin, counts)

    /// Compiles to a GRDB query. Central place the predicates live.
    /// Empty sets mean "no constraint", so the user sees everything in scope.
    func request() -> QueryInterfaceRequest<Incident> {
        var r = Incident.all()
        if !regions.isEmpty {
            r = r.filter(regions.map(\.rawValue).contains(Column("region")))  // IN (…)
        }
        if !routes.isEmpty {
            r = r.filter(Array(routes).contains(Column("migrationRoute")))   // IN (…)
        }
        if let dateRange {
            r = r.filter(dateRange.contains(Column("reportedDate")))
        }
        if !causes.isEmpty {
            r = r.filter(Array(causes).contains(Column("causeOfDeath")))     // IN (…)
        }
        if mappableOnly { r = r.filter(Column("latitude") != nil) }
        return r.order(Column("reportedDate").desc)
    }
}
```

```swift
@Observable @MainActor
final class MapModel {
    private(set) var incidents: [Incident] = []
    var filter: IncidentFilter                     // bound to the sidebar

    private let store: IncidentStore
    private let viewState: ViewStateStore           // §7.2

    init(store: IncidentStore, viewState: ViewStateStore = .standard,
         defaultRegions: Set<Region>) {
        self.store = store
        self.viewState = viewState
        // Restore, else seed from the regions of interest. Decode is defensive.
        self.filter = viewState.loadFilter() ?? IncidentFilter(regions: defaultRegions)
    }

    /// Drive from .task(id: filter) — re-subscribes when any filter field changes.
    func observe(_ filter: IncidentFilter) async {
        viewState.save(filter: filter)             // persist on settle (debounced upstream)
        do {
            let observation = ValueObservation.tracking { db in
                try filter.request().fetchAll(db)
            }
            for try await rows in observation.values(in: store.dbPool) {
                self.incidents = rows
            }
        } catch { /* surface a non-fatal error state */ }
    }
}
```

The map is the chosen design from §3.3: a shared, platform-neutral controller
owning an `MKMapView`, wrapped by a thin per-platform representable. The view
model above feeds it `incidents`; the controller diffs them against the current
annotations. Native `MKClusterAnnotation` handles the Mediterranean's density.

```swift
import MapKit

/// Codable snapshot of the full camera — center, zoom, tilt, rotation — so
/// "last location" restores faithfully (§7.2). Reused on iOS.
public struct CameraState: Sendable, Codable, Hashable {
    public var latitude, longitude, distance, pitch, heading: Double

    init(_ cam: MKMapCamera) {
        latitude = cam.centerCoordinate.latitude
        longitude = cam.centerCoordinate.longitude
        distance = cam.centerCoordinateDistance
        pitch = cam.pitch
        heading = cam.heading
    }
    var mkCamera: MKMapCamera {
        MKMapCamera(lookingAtCenter: .init(latitude: latitude, longitude: longitude),
                    fromDistance: distance, pitch: pitch, heading: heading)
    }
}

/// Platform-neutral. MKMapView/MapKit is one framework across macOS + iOS,
/// so this entire class is reused on iOS unchanged (§3.4).
@MainActor
final class IncidentMapController: NSObject, MKMapViewDelegate {
    let mapView = MKMapView()
    private var shown: [String: IncidentAnnotation] = [:]   // keyed by Incident.id

    /// Fired (debounced) when the camera settles, for persistence (§7.2).
    var onCameraIdle: ((CameraState) -> Void)?
    /// Set true once a restored camera is applied, to suppress the launch
    /// auto-frame (§5.4) that would otherwise clobber the restored location.
    private(set) var cameraRestored = false

    override init() {
        super.init()
        mapView.delegate = self
        mapView.register(IncidentAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: "incident")
        mapView.register(MKMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
    }

    func apply(_ state: CameraState) {            // restore on launch
        mapView.camera = state.mkCamera
        cameraRestored = true
    }

    /// Auto-frame after a filter reload. No-ops once if a camera was restored.
    /// Falls back to a default region when there are no annotations yet
    /// (cold start, before the first sync populates the store).
    func frame(to incidents: [Incident], fallback: MKCoordinateRegion) {
        guard !cameraRestored else { cameraRestored = false; return }
        if mapView.annotations.isEmpty {
            mapView.setRegion(fallback, animated: false)
        } else {
            mapView.showAnnotations(mapView.annotations, animated: false)
        }
    }

    func mapViewDidChangeVisibleRegion(_ map: MKMapView) {
        onCameraIdle?(CameraState(map.camera))    // debounce in the binding
    }

    /// Called by the representable's update; diff, don't reload.
    func update(_ incidents: [Incident]) {
        let incoming = Set(incidents.map(\.id))
        let toRemove = shown.keys.filter { !incoming.contains($0) }
        for id in toRemove { mapView.removeAnnotation(shown.removeValue(forKey: id)!) }
        for incident in incidents where shown[incident.id] == nil {
            let a = IncidentAnnotation(incident)
            shown[incident.id] = a
            mapView.addAnnotation(a)
        }
    }

    func mapView(_ map: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation is IncidentAnnotation else { return nil }
        let v = map.dequeueReusableAnnotationView(withIdentifier: "incident",
                                                  for: annotation) as! IncidentAnnotationView
        v.clusteringIdentifier = "incident"      // native clustering
        return v
    }
}
```

```swift
#if os(macOS)
struct IncidentMapView: NSViewRepresentable {
    var incidents: [Incident]
    var restoredCamera: CameraState?            // applied once (§7.2)
    var fallback: MKCoordinateRegion            // cold-start framing (§5.4)
    var onCameraIdle: (CameraState) -> Void     // → ViewStateStore.save (§7.2)

    func makeCoordinator() -> IncidentMapController { IncidentMapController() }

    func makeNSView(context: Context) -> MKMapView {
        let c = context.coordinator
        c.onCameraIdle = onCameraIdle
        if let restoredCamera { c.apply(restoredCamera) }   // restore wins
        return c.mapView
    }
    func updateNSView(_ v: MKMapView, context: Context) {
        context.coordinator.update(incidents)
        context.coordinator.frame(to: incidents, fallback: fallback)
    }
}
#elseif os(iOS)   // deferred — same shape with makeUIView/updateUIView over the
                  // same IncidentMapController (§3.4).
#endif
```

`MapScreen_macOS` hosts `IncidentMapView(...)` inside the SwiftUI chrome
described in §5.4, driven by `.task(id: model.filter) { await
model.observe(model.filter) }`. `MapScreen_iOS` will host the *same*
`IncidentMapView` in a touch-appropriate layout later (§3.4).

**Why not the declarative `Map`.** SwiftUI's `Map` has no built-in clustering and
the Mediterranean holds thousands of points, so the representable + native
`MKClusterAnnotation` is the v1 choice (§3.3). The fallback, if you ever want
fully SwiftUI-native styling, is in-query grid aggregation rendered as ordinary
`Annotation`s — more code, and not needed now.

### 5.4 macOS window layout

`NavigationSplitView` gives the collapsible sidebar, the content pane, and the
standard collapse toggle for free:

```swift
@Bindable var model: MapModel              // @Observable needs @Bindable for $

NavigationSplitView {
    FilterSidebar(filter: $model.filter)      // collapsible, see below
} detail: {
    MapScreen_macOS()                         // search field + map + caveat
}
```

**Filter sidebar** (the `column` content). Native controls bound to
`model.filter`: a date-range pair (`DatePicker` ×2), a **multi-select region
list**, a **multi-select route list**, a multi-select cause list, and room to
extend (source quality, origin). A reset button restores the default filter.
Behaviors:

- **Regions are multi-select.** Same toggle pattern as routes — the user can
  view e.g. Mediterranean + Western Asia together. Empty selection = all regions;
  the default is `[.mediterranean]`.
- **Routes are multi-select.** The user can show any subset — e.g. two of the
  three Mediterranean routes (Central + Eastern, not Western). Inline
  checkboxes/toggles, not a dropdown, so the subset choice and the cascade stay
  visible. Empty selection = all routes in the selected regions. Causes work the
  same way.
- **Routes cascade from the selected regions (union).** The route toggles are the
  union of routes across all selected regions; when more than one region is
  selected, group the toggles under region headers for legibility. Deselecting a
  region **prunes** its routes from the selection (intersect with the new union)
  rather than clearing everything, so an unrelated region's route choices
  survive.
- **Debounce rapid changes.** Continuous controls (date scrubbing) should
  debounce before the filter mutates, so the `ValueObservation` re-subscribes on
  settle, not on every tick. (`task(id: filter)` already cancels the prior
  observation cleanly when `filter` changes.)

**Content pane (`MapScreen_macOS`).** Top to bottom:

- **Location search field**, pinned above the map. This drives the **camera**,
  not the data: `MKLocalSearchCompleter` for type-ahead, `MKLocalSearch` to
  resolve a selection, then move the map camera. It does **not** touch
  `IncidentFilter`. (Search = where you look; filters = what is plotted. Keeping
  these mechanically separate keeps both predictable.)
- **The map** (`IncidentMapView`), filling the pane. Native `MKMapView` gestures
  cover the interaction requirements directly: `isZoomEnabled`,
  `isScrollEnabled` (pan), `isPitchEnabled` (tilt), `isRotateEnabled` — plus an
  optional on-map control cluster for zoom/tilt. (Tilt via `MKMapCamera.pitch`
  is another reason the representable beats the declarative `Map`, whose camera
  control is thinner.)
- **Minimum-estimate / attribution strip** at the bottom (`safeAreaInset`).

**Camera ↔ filter coupling.** The two input surfaces are orthogonal, with one
deliberate link: when `filter` changes, auto-frame the camera to fit the
resulting incidents (otherwise filtering to a region while the camera sits
elsewhere shows an empty map). The search field is the manual override of that
framing. `frame(to:fallback:)` runs after a filter-driven reload; user
pan/zoom/search is never overridden mid-gesture.

**Cold-start framing.** On a first launch the store is empty until the first
sync completes, so there are no annotations to frame to. `Region` carries a
default `MKCoordinateRegion` viewport (e.g. a Mediterranean bounding box); the
`fallback` passed to `frame(to:fallback:)` is the union of the selected regions'
default viewports, so the map opens on the right area rather than the whole
globe.

**States `MapScreen` must handle.**

- *First run / loading* — store empty, first sync in flight: a quiet loading
  indicator over the fallback-framed map, not a blank pane.
- *Fetch failure / offline* — the last good data stays on the map (it's cached;
  the store is the source of truth); surface a non-blocking banner rather than
  clearing anything.
- *Empty result* — a filter that matches nothing: an unobtrusive "no incidents
  match these filters" overlay with a reset affordance, so an empty map isn't
  mistaken for a bug.

---

## 6. Concurrency model (Swift 6.2, strict)

- `IncidentStore`, `LocalPollingSync` are **actors**; their state is isolated.
- CSV parsing is **`@concurrent`** so it runs off the calling actor; it's pure
  CPU work over the downloaded `Data`.
- `MapModel` is `@MainActor @Observable`; it only ever *reads* via
  `ValueObservation.values(in:)`, an `AsyncSequence` consumed inside
  `.task(id:)` (cooperative cancellation when `filter` changes or the view
  disappears).
- All cross-actor types (`Incident`, `Coordinate`, `Region`, `SyncOutcome`) are
  `Sendable` value types.
- **No `@unchecked Sendable`.** GRDB's `DatabasePool` is `Sendable` and built for
  concurrent access: it's exposed as a `nonisolated let` so the `@MainActor` model
  can observe reads directly, while every write goes through the store actor's
  methods. No annotating around the type system.
- Check `Task.checkCancellation()` around the network fetch and after the parse
  so a cancelled background task stops promptly.

---

## 7. Settings and persistence

### 7.1 Shared settings (App Group `UserDefaults`)

Shared agent ↔ app, because the LaunchAgent helper reads them:

- `regionsOfInterest: Set<Region>` — default `[.mediterranean]`. Seeds
  `IncidentFilter.regions` on first run and the default camera framing.
- `notifyRegions: Set<Region>` — which regions raise notifications (default: the
  regions of interest).
- `pollIntervalHours: Int` — default 24.
- `lastSyncAt: Date?` — shown in the app, and used to suppress the
  cold-start notification flood.
- `notificationsAuthorized: Bool` — mirror of the UN authorization status.

### 7.2 View-state persistence (app-local `UserDefaults`)

The current filter and map camera are restored across launches. This is pure
view state — the helper has no use for it — so it lives in
`UserDefaults.standard`, **not** the App Group suite. Note the deliberate
separation: the persisted filter is *what the user is viewing*;
`regionsOfInterest` / `notifyRegions` are *notification preferences*. They are
allowed to diverge (view North America, still be notified about the
Mediterranean).

```swift
@MainActor
struct ViewStateStore {
    static let standard = ViewStateStore(defaults: .standard)
    let defaults: UserDefaults
    private let filterKey = "viewState.filter"
    private let cameraKey = "viewState.camera"

    func save(filter: IncidentFilter) {
        defaults.set(try? JSONEncoder().encode(filter), forKey: filterKey)
    }
    func save(camera: CameraState) {
        defaults.set(try? JSONEncoder().encode(camera), forKey: cameraKey)
    }
    // Defensive: a stale/corrupt blob (e.g. after a field is added) decodes to
    // nil and the caller falls back to defaults. Never throws into launch.
    func loadFilter() -> IncidentFilter? {
        defaults.data(forKey: filterKey).flatMap { try? JSONDecoder().decode(IncidentFilter.self, from: $0) }
    }
    func loadCamera() -> CameraState? {
        defaults.data(forKey: cameraKey).flatMap { try? JSONDecoder().decode(CameraState.self, from: $0) }
    }
}
```

**Restore order (the subtlety).** On launch:

1. `MapModel.init` restores the filter (`loadFilter() ?? seed`).
2. `MapScreen` applies the saved camera via `controller.apply(_:)` if present,
   which sets `cameraRestored = true`.
3. The first filter-driven reload calls `controller.frame(to:fallback:)`, which
   **no-ops once** when `cameraRestored` is set — so the restored location wins
   over the auto-frame. Subsequent user filter changes auto-frame normally.

**Save timing:**

- Filter — in `observe(_:)`, which already runs on the debounced
  `task(id: filter)`, so saves coalesce with query re-subscription.
- Camera — `onCameraIdle` fires on `mapViewDidChangeVisibleRegion`; debounce it
  (it fires continuously during a pan) and `save(camera:)` on settle.
- Safety net — on `scenePhase == .background`, force a final save of both, in
  case a debounce was still pending.

Both `ViewStateStore` and `CameraState` are platform-neutral and reused on iOS;
only the `scenePhase`/termination save hook is wired in each app target (§3.4).

---

## 8. Notifications — flow

1. On first launch, request `UNUserNotificationCenter` authorization with a
   short rationale screen (why, and that it's "newly recorded" data).
2. After each `sync()`, hand the `SyncOutcome` to `NotificationCoordinator`.
3. Group per region via `threadIdentifier`; one summary per region per sync.
4. Suppress entirely when the store was empty before the sync (cold start).
5. Tapping a notification deep-links the map to that region (carry the region in
   `userInfo`).

---

## 9. Server-tier migration path (why the seam pays off)

When you build the server (small poller on the Hetzner/FreeBSD box, Swift core
reusable there):

- Add **`RemoteSync: SyncEngine`** — fetches a normalized delta from the server;
  diffing already done upstream. It writes to the same `IncidentStore` and
  returns the same `SyncOutcome`.
- The server sends **APNs**: either a content-bearing push (post on receipt via
  the same `NotificationCoordinator`) or a silent push that triggers a
  `RemoteSync().sync()`.
- **Unchanged:** `IncidentStore`, `NotificationCoordinator`, every view, every
  view model, both platform UIs. The macOS LaunchAgent helper can keep
  `LocalPollingSync` or switch to `RemoteSync` by changing one injection site.

This is the entire reason the agent talks to the store through a protocol rather
than the app talking to the network.

---

## 10. Testing (Swift Testing, Swift 6.2)

Structs, `#expect`/`#require`, parameterized cases, no timing-based tests.

- **CSV parsing fixtures** (highest value): small `.csv` resources covering
  - a multiline quoted `location_description` (must not corrupt following rows),
  - empty numeric cells → `nil`,
  - empty / malformed `location_coodinates` → non-mappable,
  - the misspelled coordinate column key.
- **Coordinate parsing** — parameterized over valid/invalid/empty inputs.
- **Region mapping** — parameterized over known region strings + an unknown
  string → `.unknown`.
- **Diff / reconcile** — inject a fake store with a known seen-set; assert that
  only first-seen `web_id`s count as new, that a multi-row incident (shared
  `web_id`) yields one new entry, and that the empty seen-set (cold start) is
  suppressed.
- **`NotificationCoordinator`** — a spy conforming to a small posting protocol;
  assert grouping per region, distinct-incident counts (not row counts),
  count/sum copy, and notify-regions filtering.
  (`UNUserNotificationCenter` itself is wrapped behind a protocol so it's
  mockable.)
- **Store** — in-memory/temp `DatabaseQueue`; assert migration, `replaceAll`
  dedupe of byte-identical rows, `seenWebIDs` persistence across a replace, and
  the mappable-only / filtered query.

```swift
@Test("Multiline quoted field does not corrupt subsequent rows")
func multilineQuotedField() async throws {
    let csv = try fixture("multiline.csv")
    let incidents = try await IncidentCSVParser().parse(csv)
    #expect(incidents.count == 3)
    let second = try #require(incidents.first { $0.webID == "2014.MMP00259" })
    #expect(second.region == .southEasternAsia)
}
```

---

## 11. Implementation sequencing

1. **`DrownedModel`** — `Incident`, `Region`, `Coordinate`, `SyncOutcome`. Lock
   the `Region` set against the codebook.
2. **`DrownedSync` parser** + CSV fixtures + parsing tests. (De-risks the two
   gotchas first.)
3. **`DrownedStore`** — schema (synthetic PK, non-unique `web_id` index),
   migration, `replaceAll`, `seenWebIDs`, store tests.
4. **`LocalPollingSync`** — wire fetch → parse → seen-set diff → `replaceAll`;
   tests with a fake store.
5. **`DrownedNotify`** — coordinator + grouping tests.
6. **`DrownedUI`** — shared map controller + macOS representable, region
   filters, detail, caveat/attribution surfaces. (Controller written platform-neutral for
   iOS reuse — §3.4.)
7. **macOS shell** — windowed app + `LSUIElement` LaunchAgent helper registered
   via `SMAppService.agent`, launchd `StartCalendarInterval` scheduling, App Group
   sharing, notification authorization + tap-relaunch deep link.
8. **Settings**, deep-linking, polish. *(End of v1 — macOS shippable here.)*
9. *(Deferred)* **iOS shell** — `UIViewRepresentable` over the shared map
   controller, `MapScreen_iOS`, `BGTaskScheduler` registration, foreground
   refresh, plist.
10. *(Deferred)* server tier + `RemoteSync` + APNs (also what makes iOS
    notifications reliable).

---

## 12. Open questions to revisit

- The `region` set is confirmed for the 2014 slice and the documented scheme;
  before freezing the enum, run `sort -u` on the live `region` column to catch
  any later-added values (the `.unknown` fallback covers misses regardless).
- Add a parse fixture for a non-unique `web_id` (origin-split rows) and an
  exact-duplicate row, alongside the multiline / missing-coordinate fixtures.
- Confirm whether the HDX S3 download URL is stable enough to hard-code, or
  whether to resolve it via the HDX dataset API each run (the signed S3 link in
  responses is temporary; the `data.humdata.org/.../download/...` path that
  redirects to it is the stable one to use).
- Decide map precision treatment for "approximate" coordinates (radius vs. note).
- Decide whether revised incidents ever warrant a subtle "updated" surface in
  the app (not a notification).

---

## 13. Attribution block (ready to paste)

```
The Drowned monitors the IOM Missing Migrants Project dataset.

Source: IOM's Missing Migrants Project — missingmigrants.iom.int
Licence: Creative Commons Attribution 4.0 International (CC BY 4.0)
Changes: data is reformatted, filtered by region, and cached locally for display.

Figures are minimum estimates; many deaths during migration go unrecorded.
Locations are approximate. Each record represents a person, and the family
and community they left behind.
```
