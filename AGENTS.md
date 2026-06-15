# Project Instructions for AI Coding Agents

**Last updated:** 2026-06-15

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

**Update ONLY this file (`AGENTS.md`)** when coding standards, conventions, or project decisions evolve. Do not modify agent-specific reference files unless the reference mechanism itself needs changes.

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
- Add entries to the "Recent Updates & Decisions" log at the bottom with:
  - Date (with time if multiple updates per day)
  - Brief description
  - Reasoning for the change
- Preserve this structure: title header → timestamp → main instructions → "Recent Updates & Decisions" section

## Best Practices

### When Updating This Repository

1. **Maintain Consistency**: Keep code style consistent across the codebase
2. **Test First**: Write tests before implementing features when applicable
3. **Document Changes**: Update documentation when changing functionality
4. **Code Review**: Review for correctness, concurrency safety, data-source
   caveats, notification tone, and test coverage before merging
5. **Date Changes**: Update the "Last updated" timestamp in this file when making changes
6. **Log Updates**: Add entries to "Recent Updates & Decisions" section below

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
- The root `build.sh` script builds the `TheDrowning` scheme from
  `TheDrowning.xcodeproj`; debug products use `.build/Products`, and release
  exports use the checked-in root `exportOptions.plist`.
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

---

<!-- {changelog} -->

## Recent Updates & Decisions

### 2026-06-15

- Replaced the generated AppIcon rasters with the exported pre-Tahoe macOS icon
  images from `~/Downloads/Icon Exports (pre Tahoe)`
- Bumped `MARKETING_VERSION` to `1.6.33` and `CURRENT_PROJECT_VERSION` to `54`
- Reasoning: the app icon asset catalog should use the prepared final icon
  export set while preserving Xcode's standard macOS AppIcon slots
- Added a generated macOS app icon asset catalog for The Drowning and populated
  the standard AppIcon sizes from a 1024px source image
- Bumped `MARKETING_VERSION` to `1.6.32` and `CURRENT_PROJECT_VERSION` to `53`
- Reasoning: the app should ship with a project-local macOS icon asset compiled
  by Xcode rather than relying on a missing or external icon resource
- Added an XcodeGen-generated build script phase that copies
  `com.panjas.thedrowning.agent.plist` into
  `Contents/Library/LaunchAgents` alongside the embedded helper app
- Bumped `MARKETING_VERSION` to `1.6.31` and `CURRENT_PROJECT_VERSION` to `52`
- Reasoning: `SMAppService.agent(plistName:)` can only register the bundled
  LaunchAgent if the plist is actually present in the app bundle
- Enabled `RunAtLoad` for the bundled LaunchAgent plist
- Bumped `MARKETING_VERSION` to `1.6.30` and `CURRENT_PROJECT_VERSION` to `51`
- Reasoning: the helper should run once immediately after ServiceManagement
  registration loads the LaunchAgent, then continue with the daily schedule
- Renamed the checked-in Developer ID export options file from
  `ExportOptions.plist` to `exportOptions.plist` and updated the release script
  to use the new casing
- Bumped `MARKETING_VERSION` to `1.6.29` and `CURRENT_PROJECT_VERSION` to `50`
- Reasoning: release tooling should match the requested export options filename
  while keeping notarization behavior unchanged
- Switched the root `ExportOptions.plist` to automatic Developer ID export
  settings after manual export failed without an installed matching Developer ID
  provisioning profile
- Bumped `MARKETING_VERSION` to `1.6.28` and `CURRENT_PROJECT_VERSION` to `49`
- Reasoning: the project can export successfully through Xcode-managed Developer
  ID signing, while manual export requires local profile installation outside
  the repository
- Switched the release build script to use the checked-in root
  `ExportOptions.plist` for manual Developer ID export settings and corrected
  its main app provisioning profile key to `com.panjas.thedrowning`
- Bumped `MARKETING_VERSION` to `1.6.27` and `CURRENT_PROJECT_VERSION` to `48`
- Reasoning: notarization should use the prepared signing/export configuration
  rather than regenerating automatic export options under `.build`
- Set the LaunchAgent helper target to `SKIP_INSTALL=YES` for archive exports
- Bumped `MARKETING_VERSION` to `1.6.26` and `CURRENT_PROJECT_VERSION` to `47`
- Reasoning: Xcode release export needs a single top-level app in the archive;
  the helper should be embedded in the main app, not installed beside it
- Adapted the root `build.sh` script for The Drowning's generated root Xcode
  project, app name, scheme, build artifact paths, Developer ID export options,
  and notarization profile naming
- Bumped `MARKETING_VERSION` to `1.6.25` and `CURRENT_PROJECT_VERSION` to `46`
- Reasoning: the copied build script should operate on this repository's actual
  XcodeGen project layout and provide a repeatable local debug/release workflow
- Refactored repeated sync completion, Missing Migrants date handling, SQL
  value-list queries, SwiftUI toolbar/filter/search widgets, map callout/detail
  views, display-coordinate spreading, map camera helpers, annotation metrics,
  and store-test fixtures into focused reusable types
- Bumped `MARKETING_VERSION` to `1.6.24` and `CURRENT_PROJECT_VERSION` to `45`
- Reasoning: the app, agent, core modules, and tests should share single sources
  of truth for repeated behavior while preserving the local-store-first
  architecture and existing map/detail behavior

### 2026-06-14

- Disabled `.swift-format`'s `UseEarlyExits` rule and documented the potential
  `UseWhereClausesInForLoops` tension in the Swift style guide
- Reasoning: formatter-backed rewrites must not override the style guide's
  preference for clear guard placement and nested control flow
- Disabled `.swift-format`'s `ReplaceForEachWithForLoop` rule
- Reasoning: the formatter must match the documented Swift style convention
  that concise single-line functional closures, including `forEach`, are
  allowed when they stay readable
- Clarified that concise single-line functional closures may keep Swift
  shorthand style, while multi-line value-producing closures still require
  explicit `return`
- Reasoning: the implicit-return rule should make non-void control flow clear
  without making readable functional chaining noisier
- Added the Swift style rule that non-void functions, methods, computed
  properties, and multi-line value-producing closures must use explicit
  `return` statements, and applied it
  across the app, LaunchAgent helper, DrownedCore sources, and package tests
- Bumped `MARKETING_VERSION` to `1.6.23` and `CURRENT_PROJECT_VERSION` to `44`
- Reasoning: explicit returns keep value-producing control flow visually
  consistent with the rest of the manual Swift style guide
- Refactored `DrownedCore/Sources` to match the Swift coding conventions:
  removed URL force unwraps, applied explicit Boolean/nil checks, split combined
  guards and switch cases, added explicit `-> Void`, and split shared types into
  dedicated files (`AppGroup`, `DrownedDefaultsKey`, `SyncOutcome`, `CameraState`,
  `SyncEngine`, `LocationCompletion`, `MapFitRequest`, `MapQueryKey`)
- Bumped `MARKETING_VERSION` to `1.6.22` and `CURRENT_PROJECT_VERSION` to `43`
- Reasoning: core package code should follow the same enforced style rules as the
  app shells before further UI or parser refactors
- Aligned function brace guidance with `.swift-format` same-line Apple style
- Reasoning: the formatter cannot enforce next-line function braces, so manual
  Allman-style requirements should not fight automatic formatting
- Clarified in the Swift style guide when to use explicit nil comparisons versus
  optional binding, including SwiftUI `if let value { use(value) }` cases
- Reasoning: style reviews should not treat the absence of `== nil` as a
  violation when the unwrapped optional is actually used
- Restored next-line function opening braces in App and Agent entry files after
  formatter drift
- Bumped `MARKETING_VERSION` to `1.6.21` and `CURRENT_PROJECT_VERSION` to `42`
- Reasoning: the style refactor plan requires Allman function braces, which
  `swift-format` cannot enforce automatically
- Aligned App and Agent entry Swift files with the style guide and renamed the
  helper entry file to `TheDrowningAgent.swift`
- Bumped `MARKETING_VERSION` to `1.6.20` and `CURRENT_PROJECT_VERSION` to `41`
- Reasoning: app shell code should follow explicit Void signatures, next-line
  function braces, and `else`/`catch` line breaks before broader refactors
- Extended `.swift-format` with `AvoidRetroactiveConformances`,
  `NoEmptyLinesOpeningClosingBraces`, `multilineTrailingCommaBehavior`,
  `reflowMultilineStringLiterals`, `indentBlankLines`, and explicit
  `orderedImports` settings
- Reasoning: formatter-supported rules should be encoded in `.swift-format`
  while style-guide-only conventions stay documented separately
- Documented the split between `.swift-format` and the Swift style guide in
  AGENTS.md
- Reasoning: agents should know which conventions are formatter-enforced and
  which still require manual review
- Documented the Swift style requirement that `else` and `catch` start on their
  own line after a closing brace
- Reasoning: the style guide should explicitly match the existing
  `.swift-format` `lineBreakBeforeControlFlowKeywords: true` setting
- Added an explicit Swift style rule requiring direct `nil` comparisons for
  presence checks and allowing optional binding only when the unwrapped value is
  used
- Reasoning: nil checks should follow the same explicit comparison style as
  Boolean literal checks and match `swift-format`'s
  `UseExplicitNilCheckInConditions` behavior
- Renamed all active bundle IDs, URL names/schemes, LaunchAgent labels, and App
  Group identifiers from `thedrowned` to `thedrowning`
- Bumped `MARKETING_VERSION` to `1.6.19` and `CURRENT_PROJECT_VERSION` to `40`
- Reasoning: bundle identity should match the final app name across the app,
  helper, launchd plist, deep link registration, and shared container
- Renamed app and helper source files, target schemes, generated Xcode project,
  and embedded helper paths from `TheDrowned` to `TheDrowning`
- Bumped `MARKETING_VERSION` to `1.6.18` and `CURRENT_PROJECT_VERSION` to `39`
- Reasoning: filesystem and generated project names should match the app name
  while stable bundle identifiers and App Group settings continue to preserve
  installed data
- Renamed the user-facing app from `The Drowned` to `The Drowning` while
  keeping target names, bundle identifiers, URL scheme, and App Group stable
- Bumped `MARKETING_VERSION` to `1.6.17` and `CURRENT_PROJECT_VERSION` to `38`
- Reasoning: the display/product name should match the chosen title without
  breaking existing local data, LaunchAgent registration, or deep links
- Smoothed two-finger trackpad panning by increasing the map-idle debounce and
  ignoring tiny visible-bounds shifts before refreshing map annotations
- Bumped `MARKETING_VERSION` to `1.6.16` and `CURRENT_PROJECT_VERSION` to `37`
- Reasoning: trackpad momentum can emit many small region changes, and those
  should not repeatedly restart the visible annotation query while panning
- Added a clickable IOM Missing Migrants Project link to the bottom attribution
  bar and removed the dashed fitted-region map overlay
- Bumped `MARKETING_VERSION` to `1.6.15` and `CURRENT_PROJECT_VERSION` to `36`
- Reasoning: source attribution should open the primary data publisher directly,
  and selected region bounds should not remain as a visual rectangle on the map
- Removed the relative last-sync time from the toolbar next to the refresh
  button
- Bumped `MARKETING_VERSION` to `1.6.14` and `CURRENT_PROJECT_VERSION` to `35`
- Reasoning: the toolbar status area should stay focused on map/filter incident
  counts and leave refresh as a simple icon-only action
- Split the toolbar incident status into smaller map-visible and filter-total
  labels
- Bumped `MARKETING_VERSION` to `1.6.13` and `CURRENT_PROJECT_VERSION` to `34`
- Reasoning: region-fit transitions can change visible-bounds counts
  independently from filter totals, so the UI must distinguish those values
- Reduced the visible map annotation cap to 1,000 and changed capped map
  annotation queries to keep the deadliest incidents in the visible map region
  first
- Bumped `MARKETING_VERSION` to `1.6.12` and `CURRENT_PROJECT_VERSION` to `33`
- Reasoning: 7,500 visible annotations made map interaction slow, while
  deadliest-first capping preserves the most significant incidents under load
- Raised the visible map annotation cap from 750 to 7,500 for performance
  testing
- Bumped `MARKETING_VERSION` to `1.6.11` and `CURRENT_PROJECT_VERSION` to `32`
- Reasoning: evaluating a larger annotation window helps find the practical
  responsiveness limit for the current MapKit clustering implementation
- Replaced the map style selector with a plain `map` icon button that toggles
  Standard/Hybrid styles, persists the choice in `UserDefaults`, and defaults
  to Standard
- Reset incident popup detail scrolling to the top after the data table is
  rebuilt
- Bumped `MARKETING_VERSION` to `1.6.10` and `CURRENT_PROJECT_VERSION` to `31`
- Reasoning: map style is now a compact toolbar toggle rather than a menu, and
  incident details must open with the first data row visible
- Added a plain globe toolbar button to the right of location search that clears
  search text and fits the map to the currently selected regions
- Bumped `MARKETING_VERSION` to `1.6.9` and `CURRENT_PROJECT_VERSION` to `30`
- Reasoning: users need a direct way to return from searched or manually panned
  map views to the active regional filter context without changing filters
- Left-aligned the incident popup header and switched individual incident
  markers to a tinted SF Symbol subview
- Bumped `MARKETING_VERSION` to `1.6.7` and `CURRENT_PROJECT_VERSION` to `28`
- Reasoning: header text should align with the detail table, and drawing an SF
  Symbol into a raster marker image did not reliably preserve the white tint
- Constrained the incident popup header to the full popup content width
- Bumped `MARKETING_VERSION` to `1.6.8` and `CURRENT_PROJECT_VERSION` to `29`
- Reasoning: text alignment alone was insufficient because the stack view could
  place an intrinsic-width header away from the popup's left content edge
- Replaced stack-based incident popup rows with constrained row views and fixed
  the incident marker SF Symbol tint
- Bumped `MARKETING_VERSION` to `1.6.6` and `CURRENT_PROJECT_VERSION` to `27`
- Reasoning: stack-view row sizing caused the popup columns to drift and center,
  and template symbol drawing could render the person icon black on black
- Left-aligned incident popup detail columns, rendered source URLs as clickable
  links, and restored the visible white `person.fill` marker symbol
- Bumped `MARKETING_VERSION` to `1.6.5` and `CURRENT_PROJECT_VERSION` to `26`
- Reasoning: selected incident metadata should scan as a table, external source
  references should be directly usable, and individual markers need to remain
  visually distinct from clusters
- Moved incident popup location text into a fixed larger header and changed the
  loaded detail body to a scrollable two-column label/value layout
- Bumped `MARKETING_VERSION` to `1.6.4` and `CURRENT_PROJECT_VERSION` to `25`
- Reasoning: the location is the most useful identifier for a selected incident,
  while the remaining fields scan better as aligned metadata rows
- Replaced MapKit's built-in incident callout with an explicit `NSPopover`
  anchored to the marker and disabled incident annotation titles/callouts
- Bumped `MARKETING_VERSION` to `1.6.3` and `CURRENT_PROJECT_VERSION` to `24`
- Reasoning: MapKit's built-in callout could briefly flash a small "Incident"
  title bubble before the custom detail view appeared
- Stabilized incident callout sizing so loading and loaded states use the same
  fixed popup frame with scrollable loaded content
- Bumped `MARKETING_VERSION` to `1.6.2` and `CURRENT_PROJECT_VERSION` to `23`
- Reasoning: MapKit could cache or restore the smaller preview-sized callout,
  making full loaded details flash briefly and then collapse
- Changed incident callouts to use a spinner while full data loads and a
  scrollable wrapped detail view that exposes every available incident field
  without truncation
- Bumped `MARKETING_VERSION` to `1.6.1` and `CURRENT_PROJECT_VERSION` to `22`
- Reasoning: selected incident popups were clipping longer/full database
  details, and a spinner is clearer than loading text for the progressive fetch
- Added progressive incident callouts that show available annotation data first,
  then load and display full incident details from the database
- Added a focused `IncidentStore.fetchIncident(id:)` lookup and store test for
  compound incident IDs
- Bumped `MARKETING_VERSION` to `1.6.0` and `CURRENT_PROJECT_VERSION` to `21`
- Reasoning: incident details should stay lightweight during map annotation
  rendering while still exposing full row data on demand

### 2026-06-13

- Added viewport-bounded map annotation queries and replaced marker annotations
  with custom black circular `person.fill` annotation views
- Fixed relaxed clustering to use unique non-nil per-incident clustering
  identifiers at close camera distances
- Simplified individual annotations to plain black circles and cluster
  annotations to black count circles
- Debounced map idle updates so annotation reloads and clustering transitions
  happen after pan and zoom movement settles
- Stopped ordinary annotation reloads from calling `showAnnotations`, preserving
  the user's visible map region during pan and zoom
- Made region selection the explicit recenter action: it clears location search,
  computes matching mappable incident bounds, draws a bounding rectangle, and
  zooms to it
- Made region-fit bounds robust against a tiny number of bad source coordinates,
  such as North Africa incidents with Libya descriptions but India-range
  longitudes
- Refreshed cluster labels from current incident members and spread
  same-coordinate incident markers slightly for close zoom selection
- Bumped `MARKETING_VERSION` to `1.5.1` and `CURRENT_PROJECT_VERSION` to `20`
- Reasoning: same-coordinate incidents could make a correct cluster count look
  wrong because individual markers overlapped exactly after zooming in
- Aligned toolbar icon controls, changed Refresh to a plain icon button, and
  added map style selection next to location search
- Bumped `MARKETING_VERSION` to `1.5.0` and `CURRENT_PROJECT_VERSION` to `19`
- Reasoning: map style selection is a new user-facing map control and toolbar
  action icons should share one visual language
- Refined the filter popover to use a plain icon button, flatter disclosure
  sections, and aligned label/switch filter rows
- Bumped `MARKETING_VERSION` to `1.4.1` and `CURRENT_PROJECT_VERSION` to `18`
- Reasoning: the first popover pass looked visually heavy and the filter
  controls were not aligned cleanly with the search field or each other
- Removed the split sidebar and moved filters into a compact toolbar popover
  with disclosure sections for Regions, Routes, Causes, and Map
- Bumped `MARKETING_VERSION` to `1.4.0` and `CURRENT_PROJECT_VERSION` to `17`
- Reasoning: keep map exploration full-width while keeping filters accessible
  from the toolbar next to location search
- Bumped `MARKETING_VERSION` to `1.3.6` and `CURRENT_PROJECT_VERSION` to `16`
- Reasoning: bad coordinate outliers made the region bounding rectangle and zoom
  extent much larger than the selected regions
- Bumped `MARKETING_VERSION` to `1.3.5` and `CURRENT_PROJECT_VERSION` to `15`
- Reasoning: recentering should be user-directed from region selection, not a
  side effect of annotation loading or map movement
- Bumped `MARKETING_VERSION` to `1.3.4` and `CURRENT_PROJECT_VERSION` to `14`
- Reasoning: fitting each newly loaded annotation subset changed the visible
  region repeatedly, feeding back into the visible-bounds query and creating map
  wobble
- Bumped `MARKETING_VERSION` to `1.3.3` and `CURRENT_PROJECT_VERSION` to `13`
- Reasoning: continuous visible-region queries during gestures caused MapKit
  annotation replacement while the camera was moving, which made panning and
  zooming feel jittery
- Bumped `MARKETING_VERSION` to `1.3.2` and `CURRENT_PROJECT_VERSION` to `12`
- Reasoning: reduce map visual noise while keeping cluster counts legible and
  stylistically aligned with incident markers
- Bumped `MARKETING_VERSION` to `1.3.1` and `CURRENT_PROJECT_VERSION` to `11`
- Reasoning: MapKit can abort when annotation views use nil clustering
  identifiers while clusters are being updated, so relaxed clustering must stay
  keyed with stable non-nil identifiers
- Relaxed clustering by disabling it below close camera distances
- Bumped `MARKETING_VERSION` to `1.3.0` and `CURRENT_PROJECT_VERSION` to `10`
- Reasoning: improve map responsiveness and make individual incident selection
  possible at high zoom levels
- Moved search suggestions out of the toolbar field layout into a map-level
  overlay and forwarded AppKit search-field text changes directly to the search
  model
- Bumped `MARKETING_VERSION` to `1.2.3` and `CURRENT_PROJECT_VERSION` to `9`
- Reasoning: bridged macOS search-field updates and live result previews must be
  visible and reliable while the user types
- Limited map annotation queries in SQL and added a separate full matching
  incident count for capped views
- Bumped `MARKETING_VERSION` to `1.2.2` and `CURRENT_PROJECT_VERSION` to `8`
- Reasoning: clearing broad filters can match the whole dataset, so the map must
  not load every matching incident as an annotation
- Made map annotations coordinate-only and moved incident details into lazy
  marker-selection callouts
- Bumped `MARKETING_VERSION` to `1.2.1` and `CURRENT_PROJECT_VERSION` to `7`
- Reasoning: reduce per-annotation payload and defer incident detail UI until a
  user selects a marker
- Replaced the location search text field/menu with a standard macOS search
  field and live inline MapKit location suggestions
- Bumped `MARKETING_VERSION` to `1.2.0` and `CURRENT_PROJECT_VERSION` to `6`
- Reasoning: search should preview found locations as the user types and remain
  mechanically separate from incident filtering
- Enabled native 2D map controls for zoom, scale, and compass while disabling
  pitch and hiding the pitch control
- Bumped `MARKETING_VERSION` to `1.1.3` and `CURRENT_PROJECT_VERSION` to `5`
- Reasoning: users need clearer map navigation controls, but the app should not
  expose 3D tilt-related interactions
- Fixed live HDX endpoint parsing by treating Swift CRLF characters as row
  delimiters and accepting comma thousands separators in numeric count fields
- Added localized parser error descriptions so UI banners report actionable
  messages instead of enum case numbers
- Bumped `MARKETING_VERSION` to `1.1.2` and `CURRENT_PROJECT_VERSION` to `4`
- Reasoning: the first CSV fix covered local exports, but the live endpoint uses
  CRLF records and grouped numerics that also need to parse cleanly
- Fixed CSV import for current IOM exports by stripping a leading UTF-8 BOM,
  resolving human-readable column aliases, accepting alternate incident-date
  strings, and tolerating comma-separated source-quality values
- Bumped `MARKETING_VERSION` to `1.1.1` and `CURRENT_PROJECT_VERSION` to `3`
- Reasoning: the app was rejecting the live/current CSV with
  `IncidentCSVParserError.malformedCSV`; parser behavior now matches both the
  original design schema and the current export shape
- Implemented the initial macOS app and LaunchAgent helper across the
  `DrownedCore` modules and app targets
- Added deterministic RFC-4180 CSV parsing, GRDB persistence, local polling,
  notification grouping, SwiftUI/MapKit map UI, LaunchAgent sync entry point,
  and Swift Testing coverage for model, parser, and store behavior
- Bumped `MARKETING_VERSION` to `1.1.0` and `CURRENT_PROJECT_VERSION` to `2`
- Reasoning: establish a functional v1 implementation path while preserving the
  local-store-first architecture and documented CSV/data caveats
- Created the root XcodeGen-based project structure and generated
  `TheDrowning.xcodeproj` using Team ID `8J2G689FCZ`
- Documented the root layout and `xcodegen generate` regeneration workflow
- Reasoning: make the generated project reproducible and keep future build
  settings changes in `project.yml`
- Replaced project placeholders with The Drowned app details from
  `_docs/the-drowned-design-plan.md`
- Documented the Swift 6.2, SwiftUI, MapKit, GRDB, Swift Package Manager, and
  Swift Testing stack
- Captured key architecture decisions: local-store-first UI, `SyncEngine`
  boundary, reusable package modules, macOS LaunchAgent helper, App Group
  persistence, RFC-4180 CSV parsing, and factual notification copy
- Reasoning: give coding agents concrete project context and prevent generic
  placeholder instructions from guiding implementation

### 2025-10-05

- Initial AGENTS.md setup
- Established core coding standards and conventions
- Created agent-specific reference files
- Defined repository structure and governance principles
