# Recent Updates & Decisions

This file is the append-only log of project decisions and notable changes, maintained by coding agents following the `recent-updates` skill. Everything below the marker line is user-owned history: slopctl never overwrites it during init or merge.

<!-- {changelog} -->

### 2026-09-05 (v1.6.38, 14:25 CEST, consolidate decision history)

- moved the remaining history from AGENTS.md into UPDATES.md, preserving original entries and existing overlapping records
- updated AGENTS.md to direct future history entries to UPDATES.md
- rationale: keep current project instructions separate from the append-only decision log
- version bump: none (documentation-only migration)

### 2026-09-05 (v1.6.38, developer id release signing)

- configured release builds for manual developer id application signing
- added reference and utilities categories to the main app and launchagent helper bundles
- rationale: archive builds use the installed developer id identity and both bundles provide required category metadata
- version bump: 1.6.37 to 1.6.38 (PATCH - release build configuration correction)

### 2026-09-05 (v1.6.37, unsigned debug builds)

- disabled code signing for build.sh debug clean and build commands
- retained code signing for release archive and export commands
- rationale: local debug builds no longer require the team's private mac development certificate
- version bump: 1.6.36 to 1.6.37 (PATCH - local build tooling correction)

### 2026-09-05 (v1.6.36, unified build directory)

- configured xcode custom workspace-relative product and intermediate paths plus .build derived data
- updated debug product path plus release cleanup and archive commands to use the shared path
- rationale: all generated target and swift package artifacts now stay in one ignored workspace location while project settings remain compatible with swift packages
- version bump: 1.6.35 to 1.6.36 (PATCH - internal build tooling configuration)

### 2026-09-05 (v1.6.35, helper app icon)

- added the main app icon asset catalog to the launchagent helper target
- rationale: the helper bundle now compiles the same branded app icon as the main app
- version bump: 1.6.34 to 1.6.35 (PATCH - internal build configuration correction)

### 2026-09-05

- Configured Release builds for manual Developer ID Application signing and
  added macOS application categories for the main app and helper bundle
- Bumped `MARKETING_VERSION` to `1.6.38` and `CURRENT_PROJECT_VERSION` to `59`
- Reasoning: archives must use the installed Developer ID identity instead of
  seeking a Mac Development certificate, and both bundles need category metadata

- Disabled code signing for `build.sh` debug clean/build commands while
  preserving release archive/export signing
- Bumped `MARKETING_VERSION` to `1.6.37` and `CURRENT_PROJECT_VERSION` to `58`
- Reasoning: local debug builds must not require the team’s private Mac
  Development certificate, while distributable builds still require signing

- Configured Xcode's workspace-relative product and intermediate locations and
  debug/release tooling to use the root `.build/` directory
- Bumped `MARKETING_VERSION` to `1.6.36` and `CURRENT_PROJECT_VERSION` to `57`
- Reasoning: all generated target artifacts should stay in one ignored location
  while project build settings remain compatible with Swift package builds

- Added the main app's AppIcon asset catalog to the LaunchAgent helper target
- Bumped `MARKETING_VERSION` to `1.6.35` and `CURRENT_PROJECT_VERSION` to `56`
- Reasoning: the helper app bundle should carry the same branded icon instead
  of declaring an AppIcon setting without compiling the shared asset catalog

### 2026-06-15

- Updated `build.sh` to generate `TheDrowning.xcodeproj` from `project.yml`
  with XcodeGen when the project is missing
- Bumped `MARKETING_VERSION` to `1.6.34` and `CURRENT_PROJECT_VERSION` to `55`
- Reasoning: freshly cloned repositories should be buildable with `build.sh`
  without requiring a separate manual `xcodegen generate` step
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

### 2025-10-05 (v0.1.0, initial setup)

- initial AGENTS.md setup
- established core coding standards and conventions
- defined repository structure and governance principles
