# Project Instructions for AI Coding Agents

**Last updated:** 2026-09-05

<!-- {preamble} -->

# ⚠️ Before You Start

Run `/init-session` at the beginning of each new session, OR read this entire file before proceeding.

**DO NOT** make code changes or commits until you have done one of the above.

<!-- {mission} -->

## Mission Statement

The Drowning is a macOS-first monitoring application for the IOM Missing
Migrants Project dataset. It has two v1 surfaces: a windowed SwiftUI map for
exploring incidents by region, route, cause, and date; and a headless macOS
LaunchAgent helper that performs gentle local polling, updates a shared store,
and posts notifications for newly recorded incidents.

The app treats the dataset as curated batch data, not a live emergency feed.
User-facing copy must say "newly recorded" rather than imply immediacy. The UI
must surface that figures are minimum estimates and locations are approximate.
iOS and a server tier are deferred, but the architecture must keep their future
addition additive by isolating shared model, store, sync, notification, and UI
substrate code in reusable package targets.

## Technology Stack

- **Language:** Swift 6.2 with strict concurrency
- **Framework:** SwiftUI shell with MapKit `MKMapView` wrapped through
  `NSViewRepresentable` for native clustering
- **Database:** GRDB over plain SQLite in the App Group container
- **Architecture:** Swift Package Manager core modules plus thin macOS app and
  LaunchAgent helper targets
- **Version Control:** Git
- **Package Manager:** Swift Package Manager
- **Testing:** Swift Testing
- **Data Source:** IOM Missing Migrants Project CSV from Humanitarian Data
  Exchange, licensed CC BY 4.0
- **License:** App license undecided; dataset attribution follows CC BY 4.0

## Session Protocol

When starting a new session, read this entire file and confirm you have
understood the project instructions before proceeding. Summarize the project
purpose and key conventions briefly. Do not make changes until you have
confirmed your understanding.

<!-- {principles} -->

## Primary Instructions

- Avoid making assumptions. If you need additional context to accurately answer the user, ask the user for the missing information. Be specific about which context you need.
- Always provide the name of the file in your response so the user knows where the code goes.
- Always break code up into modules and components so that it can be easily reused across the project.
- All code you write MUST be fully optimized. ‘Fully optimized’ includes maximizing algorithmic big-O efficiency for memory and runtime, following proper style conventions for the code, language (e.g. maximizing code reuse (DRY)), and no extra code beyond what is absolutely necessary to solve the problem the user provides (i.e. no technical debt). If the code is not fully optimized, you will be fined $100.

### Working Together

This file (`AGENTS.md`) is the primary instructions file for AI coding assistants working on this project. Agent-specific instruction files (such as `.github/copilot-instructions.md`, `CLAUDE.md`) reference this document, maintaining a single source of truth.

When initializing a session or analyzing the workspace, refer to instruction files in this order:

1. `AGENTS.md` (this file - primary instructions and single source of truth)
2. Agent-specific reference file (if present - points back to AGENTS.md)

### Update Protocol (CRITICAL)

**PROACTIVELY update this file (`AGENTS.md`) as we work together.** Whenever you make a decision, choose a technology, establish a convention, or define a standard, you MUST update AGENTS.md immediately in the same response.

**Update this file (`AGENTS.md`) for current guidance and `UPDATES.md` for history** when coding standards, conventions, or project decisions evolve. Do not modify agent-specific reference files unless the reference mechanism itself needs changes.

**When to update** (do this automatically, without being asked):

- Technology choices (build tools, languages, frameworks)
- Directory structure decisions
- Coding conventions and style guidelines
- Architecture decisions
- Naming conventions
- Build/test/deployment procedures

**How to update AGENTS.md:**

- Maintain the "Last updated" timestamp at the top
- Add content to the relevant section (Project Overview, Coding Standards, etc.)
- Load the `recent-updates` skill and add entries to the append-only log in
  `UPDATES.md`, directly below its changelog marker, newest first, with:
  - Date (with time if multiple updates per day)
  - Brief description
  - Reasoning for the change
- Preserve this structure: title header → timestamp → main instructions
- Keep historical entries in `UPDATES.md`; never edit or delete existing entries

## Best Practices

### When Updating This Repository

1. **Maintain Consistency**: Keep code style consistent across the codebase
2. **Test First**: Write tests before implementing features when applicable
3. **Document Changes**: Update documentation when changing functionality
4. **Code Review**: Review for correctness, concurrency safety, data-source
   caveats, notification tone, and test coverage before merging
5. **Date Changes**: Update the "Last updated" timestamp in this file when making changes
6. **Log Updates**: Add entries to `UPDATES.md` using the `recent-updates` skill

### Development Guidelines

- Keep the app reading from the local store only. Network acquisition belongs
  behind `SyncEngine` implementations such as `LocalPollingSync` now and
  `RemoteSync` later.
- Keep reusable code in the Swift package modules: `DrownedModel`,
  `DrownedStore`, `DrownedSync`, `DrownedNotify`, and `DrownedUI`. Platform
  shells should stay thin.
- The root Xcode project is generated from `project.yml` with
  `xcodegen generate`. Do not hand-edit `TheDrowning.xcodeproj` for settings that
  belong in the spec.
- The root `build.sh` script generates `TheDrowning.xcodeproj` from
  `project.yml` with XcodeGen when the project is missing, then builds the
  `TheDrowning` scheme; debug products use `.build/Products`, and release
  exports use the checked-in root `exportOptions.plist`. Configure Xcode's
  custom workspace-relative build locations as `.build/Products` and
  `.build/Intermediates`; the script passes `.build` as its derived-data path,
  keeping products, intermediates, derived data, and Swift package artifacts
  together without project-level `SYMROOT` or `OBJROOT` settings. Debug clean
  and build commands disable code signing so they work without a local Mac
  Development certificate; release builds use manual Developer ID Application
  signing and archive/export commands retain signing.
- The root layout contains `DrownedCore/` for the Swift package,
  `App/TheDrowning/` for the windowed app, `App/TheDrowningAgent/` for the
  LaunchAgent helper app, and `LaunchAgents/` for launchd plists.
- The macOS app icon lives in
  `App/TheDrowning/Assets.xcassets/AppIcon.appiconset`; keep generated icon
  rasters in the asset catalog so Xcode can compile `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`.
- Confine platform-specific APIs such as `SMAppService`, launchd, AppKit, and
  bundle wiring to the macOS app target, LaunchAgent helper, or map
  representable.
- Use a standard windowed macOS app for the map and a separate signed
  `LSUIElement` helper app bundle registered as a LaunchAgent for background
  polling and notifications.
- Keep the LaunchAgent helper target set to `SKIP_INSTALL=YES` so release
  archives export one top-level app while still embedding the helper inside the
  main app bundle.
- Set the LaunchAgent plist `RunAtLoad` to `true` so the helper performs one
  sync as soon as launchd loads it after registration, in addition to the daily
  scheduled poll.
- Store public incident data in plain SQLite, not SQLCipher. Use WAL mode and a
  GRDB `DatabasePool` so the helper can write while the UI reads.
- Treat `web_id` as non-unique. Use a synthetic row identity based on `web_id`
  plus content fingerprint, dedupe byte-identical rows, and notify only once per
  first-seen `web_id`.
- Parse the CSV with an RFC-4180-compliant parser. Never split on newlines,
  because `location_description` can contain embedded newlines inside quotes.
- Preserve the source column typo `location_coodinates`. Parse it as one
  `"lat, lon"` field, and treat malformed or empty values as non-mappable
  incidents rather than dropping the record.
- Support both the design-plan snake_case HDX schema and current
  human-readable IOM export headers such as `Main ID`, `Region of Incident`,
  `Incident Date`, `Coordinates`, and `Location of death`.
- Treat CRLF as a row delimiter in the RFC-4180 parser; Swift can surface CRLF
  as one `Character`.
- Map empty numeric CSV cells to `nil`, never `0`.
- Accept thousands separators in numeric count fields, such as `1,022`.
- Keep notification copy factual and grave. Group notifications by region per
  sync, respect `notifyRegions`, and never post one notification per row.
- Default region of interest is the Mediterranean. Empty filter selections mean
  all values in scope.
- The map should expose native 2D controls for zoom, scale, and compass. Keep
  pitch disabled and hide pitch controls so the app does not present 3D map
  affordances.
- Location search should use a standard macOS search field backed by
  `MKLocalSearchCompleter`, with live inline location suggestions. Selecting a
  suggestion moves only the map camera and must not mutate incident filters. The
  suggestion panel should be rendered as a map-level overlay, not inside the
  toolbar field's fixed-height layout.
- Map annotations should stay lightweight: use custom `MKAnnotationView`
  instances with a plain black circular image by default. Cluster annotations
  should use a matching black circle with a white count label. Create incident
  detail popup content lazily when a marker is selected. Incident detail popups
  should use an explicit `NSPopover`, not MapKit's built-in callout, so the
  default annotation title bubble never appears. While full data loads, popups
  should show only a native spinner in the same fixed-size frame used for loaded
  details. Loaded popups should use the location description as a fixed header,
  then wrap and expose all remaining available incident fields in a scrollable
  left-aligned two-column label/value body without truncation. Use constrained
  row views for the label/value layout so columns keep fixed x-positions. Source
  URL rows should detect every URL in the field and open clicked links in the
  default browser.
- Individual incident annotations should render as black circles with a visible
  white `person.fill` SF Symbol using a tinted `NSImageView` subview; clusters
  should stay black circles with white incident counts.
- Cluster annotation labels count clustered incident annotations, not affected
  people. When several incidents share the same source coordinate, keep source
  data unchanged but apply a tiny deterministic display spread so close zooms
  reveal the individual selectable markers instead of perfectly stacking them.
- Map annotation queries must be SQL-limited before data reaches SwiftUI or
  MapKit. Show the full matching incident count separately from the displayed
  marker count when the query is capped.
- Map annotation queries should also be constrained to the visible map
  coordinate bounds. Broad filters are acceptable, but the map must not request
  off-screen incidents for annotation rendering.
- Debounce map idle updates before saving the camera, changing visible bounds,
  or reloading annotations. Do not update annotation query bounds continuously
  during pan or zoom gestures.
- Do not auto-frame the map after ordinary annotation reloads. Only frame the
  initial empty-to-data annotation load, and consume pending auto-frame when a
  restored or requested camera is applied.
- Recenter and fit the map only when the user changes the region selection.
  Region selection must clear the location search box, compute mappable
  incident bounds without the previous viewport constraint, draw that bounds
  rectangle, and zoom to it. For large region result sets, fit bounds should
  ignore tiny coordinate outlier tails while leaving underlying incident data
  unchanged.
- Keep the map as the primary full-window surface. Filters live in a toolbar
  popover opened by the `line.3.horizontal.decrease.circle` SF Symbol button to
  the left of search; group filter categories into compact disclosure sections
  for Regions, Routes, Causes, and Map. The filter button should be an
  icon-only plain button aligned to the search field, and popover rows should
  keep labels and switches aligned without card-like section boxes.
- Toolbar icon actions should use plain icon-only buttons with a consistent
  fixed control size. Map style selection lives immediately to the right of the
  location search field and drives the wrapped `MKMapView.mapType`.
- Relax annotation clustering at close camera distances with unique, non-nil
  per-incident clustering identifiers so users can zoom far enough to select
  individual incidents without triggering MapKit's nil cluster-key crash path.
- Persist notification and polling settings in App Group `UserDefaults`; persist
  view-only state such as filters and map camera in standard `UserDefaults`.
- App versions are managed in `project.yml` via `MARKETING_VERSION` and
  `CURRENT_PROJECT_VERSION`; regenerate `TheDrowning.xcodeproj` after changing
  either value.

### Security & Safety

- Never include API keys, tokens, or credentials in code
- Always require explicit human confirmation before commits
- Maintain conventional commit message standards
- Keep change history transparent through commit messages
- The dataset is public incident-level, anonymous data. Do not introduce
  encryption or secret storage complexity unless new private data is added.
- Use the App Group container only for shared app/helper state that both targets
  need.
- The LaunchAgent helper must run in the user GUI session as a LaunchAgent, not
  as a LaunchDaemon, so notifications can be delivered correctly.

### Testing

- Unit tests live under the Swift package `Tests/` tree, grouped by module:
  `DrownedModelTests`, `DrownedSyncTests`, and `DrownedStoreTests`.
- Use Swift Testing with `@Test`, `#expect`, `#require`, and parameterized test
  cases. Avoid timing-based tests.
- Prioritize CSV parser fixtures covering quoted multiline fields, empty
  numeric cells, empty or malformed `location_coodinates`, the misspelled
  coordinate column key, non-unique `web_id` rows, and exact duplicate rows.
- Test coordinate parsing, region mapping with `.unknown` fallback, first-seen
  `web_id` diffing, cold-start notification suppression, notification grouping,
  notify-region filtering, store migrations, `replaceAll`, `seenWebIDs`, and
  filtered/mappable-only queries.
- Wrap `UNUserNotificationCenter` behind a small protocol so notification
  behavior can be tested with a spy.

### Documentation

- Keep `_docs/the-drowned-design-plan.md` as the detailed product and
  implementation design reference.
- Update `AGENTS.md` whenever project decisions, coding standards, directory
  layout, architecture, build/test procedures, or naming conventions change.
- Include source attribution wherever data is presented:
  "Data: IOM's Missing Migrants Project (missingmigrants.iom.int), licensed
  under CC BY 4.0. Data has been reformatted and filtered for display; figures
  are minimum estimates and locations are approximate."
- Use comments sparingly, mainly for non-obvious concurrency, persistence,
  notification, or parsing behavior.

<!-- {languages} -->

## Swift Coding Standards

Load the `swift-coding-conventions` skill before writing, reviewing, or refactoring Swift code.
Load the `swift-build-commands` skill when building or running the project.
When a condition only checks whether an optional value is present or absent,
compare directly with `nil` using `== nil` or `!= nil`. Do not use optional
binding as an implicit nil check unless the unwrapped value is actually used.
When the unwrapped value is used in the branch, prefer `if let` or `guard let`
instead of an explicit nil check followed by force unwrap.
Place `else` and `catch` on their own line after the previous block's closing
brace, matching `.swift-format`'s `lineBreakBeforeControlFlowKeywords: true`
setting.
Use `.swift-format` for mechanical formatting and lint rules it supports,
including function opening braces on the same line as the signature. Use the
`swift-coding-conventions` skill for conventions that `swift-format` cannot
represent, including explicit `-> Void` return types, explicit Boolean
comparisons, explicit return statements for non-void functions, methods,
computed properties, and multi-line value-producing closures, nested `if`
conditions instead of combined conditions, and one primary type per file. Keep
`NoVoidReturnOnFunctionSignature` disabled so explicit `-> Void` is allowed.
Concise single-line functional closures, including `map`, `filter`,
`compactMap`, `sorted`, `reduce`, `forEach`, `first(where:)`, and SwiftUI
builders, may use Swift shorthand style and should not be rewritten into loops
solely to avoid implicit returns.
Keep `.swift-format`'s `UseEarlyExits` disabled because it can conflict with the
style guide's guard-placement guidance. Treat `UseWhereClausesInForLoops`
suggestions as optional when a `where` clause would obscure nested control flow.

<!-- {integration} -->

## Commit Protocol

- **NEVER commit automatically** — always wait for explicit user confirmation
- Stage changes, write a conventional commits message (max 50-char subject, 72-char body lines), then commit
- Load the `git-workflow` skill for the full message format, character limits, and examples before committing

## Semantic Versioning

Automatically bump the project version after every code change and include it in the same commit. Load the `semantic-versioning` skill for the full PATCH/MINOR/MAJOR decision rules.
