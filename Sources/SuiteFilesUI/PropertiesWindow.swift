import AppKit
import SuiteFilesCore

/// A Windows-style Properties window (the General tab) for one file or folder.
public enum PropertiesWindow {
    private static var open: [URL: NSWindowController] = [:]

    /// One window per item; a few at most, as Windows does for a large selection.
    public static func show(_ urls: [URL]) {
        for url in urls.prefix(8) { show(url) }
    }

    public static func show(_ url: URL) {
        let key = url.standardizedFileURL
        if let existing = open[key] {
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }
        guard let properties = try? ItemProperties.load(url) else { return }
        let controller = PropertiesViewController(properties: properties)
        let window = NSWindow(contentViewController: controller)
        window.title = String(format: FL("%@ Properties"), properties.name)
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        if let last = open.values.compactMap(\.window).first {
            window.setFrameTopLeftPoint(NSPoint(x: last.frame.minX + 24, y: last.frame.maxY - 24))
        } else {
            window.center()
        }
        let windowController = NSWindowController(window: window)
        open[key] = windowController
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window,
                                               queue: .main) { _ in
            controller.cancel()
            open[key] = nil
        }
        NSApp.activate(ignoringOtherApps: true)
        windowController.showWindow(nil)
    }
}

private final class PropertiesViewController: NSViewController {
    private let properties: ItemProperties
    private var measuring: Task<Void, Never>?
    // Filled in once a folder has been measured.
    private let sizeField = PropertiesViewController.value("")
    private let diskField = PropertiesViewController.value("")
    private let containsField = PropertiesViewController.value("")

    init(properties: ItemProperties) {
        self.properties = properties
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func loadView() {
        let icon = NSImageView(image: NSWorkspace.shared.icon(forFile: properties.url.path))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 40).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 40).isActive = true
        let name = Self.value(properties.name)
        name.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        let header = NSStackView(views: [icon, name])
        header.spacing = 12

        var rows: [[NSView]] = [[Self.label(FL("Type:")), Self.value(properties.kind ?? "—")]]
        if let app = openingApp { rows.append([Self.label(FL("Opens with:")), Self.value(app)]) }
        rows.append(Self.separatorRow)
        rows.append([Self.label(FL("Location:")), Self.value(properties.location.path)])
        rows.append([Self.label(FL("Size:")), sizeField])
        rows.append([Self.label(FL("Size on disk:")), diskField])
        if properties.isFolder { rows.append([Self.label(FL("Contains:")), containsField]) }
        rows.append(Self.separatorRow)
        rows.append([Self.label(FL("Created:")), Self.value(Self.date(properties.created))])
        rows.append([Self.label(FL("Modified:")), Self.value(Self.date(properties.modified))])
        rows.append([Self.label(FL("Accessed:")), Self.value(Self.date(properties.accessed))])
        rows.append(Self.separatorRow)
        let readOnly = NSButton(checkboxWithTitle: FL("Read-only"), target: nil, action: nil)
        readOnly.state = properties.isReadOnly ? .on : .off
        let hidden = NSButton(checkboxWithTitle: FL("Hidden"), target: nil, action: nil)
        hidden.state = properties.isHidden ? .on : .off
        [readOnly, hidden].forEach { $0.isEnabled = false }
        rows.append([Self.label(FL("Attributes:")), NSStackView(views: [readOnly, hidden])])

        let grid = NSGridView(views: rows)
        grid.rowSpacing = 6
        grid.columnSpacing = 16
        grid.column(at: 0).xPlacement = .trailing
        for index in 0..<grid.numberOfRows where rows[index].first is NSBox {
            grid.row(at: index).mergeCells(in: NSRange(location: 0, length: 2))
            grid.row(at: index).topPadding = 4
            grid.row(at: index).bottomPadding = 4
        }

        let stack = NSStackView(views: [header, Self.separator(), grid])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.widthAnchor.constraint(equalToConstant: 460).isActive = true
        view = stack

        if properties.isFolder {
            [sizeField, diskField, containsField].forEach { $0.stringValue = FL("Calculating") }
            measure()
        } else {
            sizeField.stringValue = Self.size(properties.size)
            diskField.stringValue = Self.size(properties.sizeOnDisk)
        }
    }

    private func measure() {
        let url = properties.url
        measuring = Task { [weak self] in
            let contents = await Task.detached(priority: .userInitiated) {
                FolderMeasure.measure(url) { Task.isCancelled }
            }.value
            guard let self, !Task.isCancelled else { return }
            self.sizeField.stringValue = Self.size(contents.size)
            self.diskField.stringValue = Self.size(contents.sizeOnDisk)
            self.containsField.stringValue =
                "\(Self.count(contents.files, "file")), \(Self.count(contents.folders, "folder"))"
        }
    }

    func cancel() { measuring?.cancel() }

    private var openingApp: String? {
        guard !properties.isFolder, let app = NSWorkspace.shared.urlForApplication(toOpen: properties.url) else {
            return nil
        }
        return FileManager.default.displayName(atPath: app.path)
    }

    // MARK: Building blocks

    private static func label(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.textColor = .secondaryLabelColor
        return field
    }

    private static func value(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.isSelectable = true
        field.lineBreakMode = .byTruncatingMiddle
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    private static func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    private static var separatorRow: [NSView] { [separator(), NSGridCell.emptyContentView] }

    /// "1.2 MB (1,234,567 bytes)", as Windows shows it.
    private static func size(_ bytes: Int64?) -> String {
        guard let bytes else { return "—" }
        let exact = NumberFormatter.localizedString(from: NSNumber(value: bytes), number: .decimal)
        return "\(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)) (\(exact) \(FL("bytes")))"
    }

    private static func date(_ date: Date?) -> String {
        date.map { DateFormatter.localizedString(from: $0, dateStyle: .long, timeStyle: .medium) } ?? "—"
    }

    private static func count(_ n: Int, _ noun: String) -> String {
        let formatted = NumberFormatter.localizedString(from: NSNumber(value: n), number: .decimal)
        return String(format: FL(n == 1 ? "%@ \(noun)" : "%@ \(noun)s"), formatted)
    }
}
