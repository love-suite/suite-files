# Suite Files: project brief

The file layer of the suite's apps that handle files (Explorer, Desktop, Bar, Viewer, Suite Settings for
the Trash's settings): what a file is, what a folder holds, the rules of each operation, the Trash, and
the file views they share. A library repository, no app. Only the apps handling files depend on it; the
others never see it. It was part of Explorer (`ExplorerCore`, `ExplorerUI`) and of `suite-core` until
2026-11-24; its history is Explorer's for the files that came from there.

## What it holds

```
SuiteFilesCore  (library, no UI, unit-tested)
    FileItem, DirectoryLoader, DirectoryWatcher (FSEvents), ShortcutResolver (aliases, links),
    SyncState and CloudStorage (iCloud Drive, File Provider apps), FileSorter and FolderViewStore (how
    folders are sorted and shown), FileTransfer (copies and moves, name conflicts as Windows asks),
    FileOperation (what Undo and Redo replay), FileUndoJournal (the one Undo history every app shares, a
    file under a lock), CutClipboard, FileRenamer, FileTemplate, Archiver (zip),
    FileShortcuts (what a key does in a file view), TrashLocations and SuiteTrash (the Trash's folders,
    moving to the Trash with the record Restore reads), TrashFolder, TrashLedger, FinderTrashRecords
    (where Finder says Trash items came from), FinderIconPositions (where Finder placed the desktop's
    icons, from its `.DS_Store`), ItemProperties, IconLibrary, SearchScope,
    DisplaySettings and IconSize (display preferences shared by the desktop and the windows, kept in
    Explorer's defaults domain for now), DisplayName
SuiteFilesUI    (library, AppKit)
    FileActions (open, rename, new, Trash, Put Back, erase), FileCommands, FileDrop, FileOperations
    (FileUndo over the shared journal, FileClipboard: Copy, Cut and Paste through the system pasteboard
    with a cut mark, InlineRenamer), FileIcons, IconItemView, IconCollectionView, DragGhost,
    FullNameOverlay, StackIcon, SyncBadge, TableCells, Thumbnails, QuickLook, PropertiesWindow,
    IconPickerWindow, FolderArtist, DefaultFileViewer, ViewerHandoff, FinderSounds, MenuAction,
    FileViewer, FinderName, Localization (`FL`, this library's own strings catalog)
```

What the apps set at launch (`SuiteFilesUI` knows no app):

- `FileViewer.openFolder`, `FileViewer.reveal`: where folders open and items are shown. Explorer sets
  them to its windows; elsewhere they go to the system's file viewer (Finder, or the default one).
- `FileActions.didPutBack`: after Put Back (Explorer opens the folder, when chosen in its settings).
- `FileActions.eraseNeedingRoot`: Trash items that need root to be erased; Explorer sends them to its
  Suite Trash helper. Unset, they are reported as not deleted.

**(to build)**: the variants of each view as settings, display settings in a domain of their own.
In depth: `suite/docs/5-internals/files.md`.

## Building and testing

- `swift build`, `swift test`. No app, so no build script and no update feed: a version is a tag, as
  for `suite-core` (`v27.1-dev.N` while 27.1 is prepared, then `v27.1`).
- UI can't be checked by unit tests and screenshots of the user's screen are not available: check views
  by rendering them offscreen (`cacheDisplay`) from a scratch package that compiles the sources.

## The suite

This repository is part of Love Suite, one repository per app under `github.com/love-suite`:
`suite-core` (the shared library), `suite-files` (the file layer of the apps handling files),
`suite-guard`, `suite-desktop` (the desktop), `suite-explorer`, `suite-bar` (the Dock), `suite-viewer`,
`suite-clipboard`, `suite-settings` (the settings), `suite-awake` (keeping the Mac awake), `suite-launcher`, `suite-bindings`,
`suite-ai-organizer`; `homebrew-tap` (the tap `love-suite/tap`, one cask per app) and `suite` (the
front page, the suite's version, the scripts that act on every repository). Locally they sit side by side
in `~/GitHub/paul-amour/suite/`.

## Conventions (the same in every repository of the suite)

- The user writes in French and expects answers in French; everything in the code stays in English: code,
  comments, tests, docs, commit messages. Do not add co-author trailers.
- No "…" in menu items, buttons or messages: the user wants none, anywhere.
- Behaviour follows Windows unless Apple's design is asked for.
- Swift Package Manager, `swift-tools-version:5.9`, macOS 13+. Tests use Swift Testing (`import Testing`).
- Toolchain: swiftly, Swift 6.4.2 (`.swift-version`, git-ignored). If `swift test` complains about a
  missing toolchain: `swiftly use 6.4.2`.
- AppKit for windows that need fine control; SwiftUI is allowed for small panels (settings, pickers).
- No private APIs and no system modifications (SIP stays on).
- Git: one worktree per feature under `.worktrees/` (git-ignored), one branch per change
  (`feat/<feature>`, `fix/<area>/<what>`), merged into `main` one by one; `main` stays stable.
- Versions are `AA.Y`, then `AA.Y.Z` for a fix (`VERSION`, tag `vVERSION`: 27.1, then 27.1.1; SwiftPM reads
  `v27.1` as 27.1.0): `AA` is the latest macOS in production (27), `AA.Y` is the same in every repository of
  the suite so the apps work together, `Z` is this repository's own. A change of `AA.Y` is made in `suite`
  and reaches every repository. While a version is being prepared, `VERSION` doesn't move (27.1 now):
  development builds are `VERSION-dev.N`, N the commits since `VERSION` was set, merges aside, from 1 (`make-app.sh`),
  and a change another repository needs gets a development tag, `vVERSION-dev.N`, which releases nothing.
  Dependencies on other repositories of the suite (`suite-core`, `suite-files`, `suite-guard`, settings
  libraries) use
  `.upToNextMinor(from: "27.1.0-dev.1")` (the latest development tag, then the release);
  `Package.resolved` is committed. Tags are never moved once pushed. The build number (`CFBundleVersion`,
  which the updater compares) stays the number of commits.
- Changing two repositories at once: `swift package edit <Package> --path ../<repository>` points at the
  neighbour's working copy until its tag exists, `swift package unedit` goes back. Never committed.
- Code goes only where it is used: `suite-core` holds what every app needs; what only some apps share lives
  in a library repository of its own (`suite-files` for the apps handling files), which only those apps
  depend on. An app's own code never goes into another app's repository, and an app exposes only its
  settings, as `<App>Settings`, for Suite Settings. See `suite/docs/architecture.md`.
- Do not run commands that delete user data. Trash instead of delete.
- No code converting saved settings at launch. Before the first release nothing needs converting (the
  developer's own settings don't count): rename freely. Between released versions, a change to saved
  settings is a `SettingsMigration` (suite-core) for the version that brought it, given to the app's
  `SuiteUpdater`, which runs it once after the update.
