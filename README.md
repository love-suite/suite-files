# Suite Files

The file layer of Love Suite's apps that handle files (Explorer, Desktop, Bar, Viewer):
what a file is, what a folder holds, the rules of each operation, the Trash, and the file views they
share. A Swift package, no app.

```swift
.package(url: "https://github.com/love-suite/suite-files", .upToNextMinor(from: "27.1.0"))
```

Products: `SuiteFilesCore` (no UI) and `SuiteFilesUI` (AppKit). macOS 13 or later.
