# The Drowned — project scaffold

Project-as-code: the `.xcodeproj` is generated, never hand-edited.

## First run
```sh
brew install xcodegen xcode-build-server xcbeautify swiftformat
cd TheDrowned
xcodegen generate            # produces TheDrowned.xcodeproj from project.yml
```
Open the folder in Cursor → command palette → **Sweetpad: Generate Build Server
Config** (writes `buildServer.json`, needed for LSP). Pick a scheme in the
Sweetpad panel and Build & Run.

## Before it builds for real
- Set `DEVELOPMENT_TEAM` in `project.yml` to your Team ID.
- After the first build, confirm the agent embeds at
  `TheDrowned.app/Contents/Library/LaunchAgents/TheDrownedAgent.app` and that the
  plist's `BundleProgram` matches. (The wrapper+subpath base is the one knob.)
- Replace the placeholder sources per the design plan.

## Release (direct / Developer ID, no App Store)
```sh
xcodebuild -scheme TheDrowned -configuration Release archive -archivePath build/TheDrowned.xcarchive
# export with a Developer ID ExportOptions.plist, then:
xcrun notarytool submit <app-or-zip> --keychain-profile <profile> --wait
xcrun stapler staple <app>
```
No Xcode GUI required at any step.
