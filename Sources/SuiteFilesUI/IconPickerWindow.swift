import AppKit
import SuiteFilesCore
import UniformTypeIdentifiers

/// "Change Icon…": pick from Apple's icons, your own library, or a coloured folder with an emoji.
/// The icon is written on the item itself, so it shows everywhere, Finder included.
public enum IconPickerWindow {
    /// Posted with the changed URLs (`object`) after an icon is applied or restored.
    public static let didChange = Notification.Name("IconPickerDidChange")
    private static var open: [NSWindowController] = []

    public static func show(for urls: [URL]) {
        guard !urls.isEmpty else { return }
        let window = NSWindow(contentViewController: IconPickerViewController(targets: urls))
        window.title = urls.count == 1
            ? String(format: FL("Change Icon \u{2014} %@"), urls[0].lastPathComponent)
            : String(format: FL("Change Icon \u{2014} %d items"), urls.count)
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        let controller = NSWindowController(window: window)
        open.append(controller)
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window,
                                               queue: .main) { _ in open.removeAll { $0 === controller } }
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
    }
}

private final class IconPickerViewController: NSViewController, NSCollectionViewDataSource,
                                              NSCollectionViewDelegate, NSTextFieldDelegate {
    private enum Tab: Int { case library, mine, colorAndEmoji }

    private let targets: [URL]
    private var folders: [URL] {
        targets.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]))
            .map { $0.isDirectory == true && $0.isPackage != true } ?? false }
    }
    private var tab = Tab.library
    private var choices: [URL] = []
    private var images: [URL: NSImage] = [:]
    private var color: NSColor?
    private var emoji = ""

    private let tabs = NSSegmentedControl(labels: [FL("Library"), FL("My Icons"), FL("Color & Emoji")],
                                          trackingMode: .selectOne, target: nil, action: nil)
    private let grid = NSCollectionView()
    private let gridScroll = NSScrollView()
    private let mineButtons = NSStackView()
    private let colorPane = NSStackView()
    private let preview = NSImageView()
    private let emojiField = NSTextField()
    private let colorWell = NSColorWell()
    private var swatches: [NSButton] = []
    private let applyButton = NSButton(title: FL("Apply"), target: nil, action: nil)
    private let note = NSTextField(labelWithString: "")

    init(targets: [URL]) {
        self.targets = targets
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: Layout

    override func loadView() {
        tabs.selectedSegment = 0
        tabs.target = self
        tabs.action = #selector(tabChanged)

        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 72, height: 72)
        layout.minimumInteritemSpacing = 6
        layout.minimumLineSpacing = 6
        layout.sectionInset = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        grid.collectionViewLayout = layout
        grid.dataSource = self
        grid.delegate = self
        grid.isSelectable = true
        grid.backgroundColors = [.clear]
        grid.register(IconChoiceItem.self, forItemWithIdentifier: IconChoiceItem.id)
        let doubleClick = NSClickGestureRecognizer(target: self, action: #selector(gridDoubleClicked(_:)))
        doubleClick.numberOfClicksRequired = 2
        doubleClick.delaysPrimaryMouseButtonEvents = false
        grid.addGestureRecognizer(doubleClick)
        gridScroll.documentView = grid
        gridScroll.hasVerticalScroller = true
        gridScroll.borderType = .bezelBorder
        gridScroll.heightAnchor.constraint(equalToConstant: 300).isActive = true

        mineButtons.orientation = .horizontal
        mineButtons.addArrangedSubview(NSButton(title: FL("Add Icons"), target: self, action: #selector(addIcons)))
        mineButtons.addArrangedSubview(NSButton(title: FL("Open Folder"), target: self, action: #selector(openLibrary)))

        buildColorPane()

        note.textColor = .secondaryLabelColor
        note.font = .systemFont(ofSize: NSFont.smallSystemFontSize)

        let restore = NSButton(title: FL("Restore Default Icon"), target: self, action: #selector(restoreDefault))
        let cancel = NSButton(title: FL("Cancel"), target: self, action: #selector(cancel))
        cancel.keyEquivalent = "\u{1b}"
        applyButton.target = self
        applyButton.action = #selector(apply)
        applyButton.keyEquivalent = "\r"
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttons = NSStackView(views: [restore, spacer, cancel, applyButton])

        let stack = NSStackView(views: [tabs, gridScroll, colorPane, mineButtons, note, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        for view in [gridScroll, colorPane, buttons] {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32).isActive = true
        }
        stack.widthAnchor.constraint(equalToConstant: 540).isActive = true
        view = stack
        show(.library)
    }

    private func buildColorPane() {
        let palette = [("Default", nil as NSColor?)] + FolderArtist.colors.map { ($0.name, $0.color as NSColor?) }
        for (name, swatchColor) in palette {
            let swatch = NSButton(title: "", target: self, action: #selector(swatchChosen(_:)))
            swatch.isBordered = false
            swatch.wantsLayer = true
            swatch.layer?.cornerRadius = 11
            swatch.layer?.backgroundColor = (swatchColor ?? NSColor(calibratedRed: 0.36, green: 0.68, blue: 0.95,
                                                                    alpha: 1)).cgColor
            swatch.toolTip = name
            swatch.translatesAutoresizingMaskIntoConstraints = false
            swatch.widthAnchor.constraint(equalToConstant: 22).isActive = true
            swatch.heightAnchor.constraint(equalToConstant: 22).isActive = true
            swatch.tag = swatches.count
            swatches.append(swatch)
        }
        colorWell.target = self
        colorWell.action = #selector(colorWellChanged)
        colorWell.toolTip = FL("Any colour")
        // Two rows of seven, the colour well closing the second one.
        let firstRow: [NSView] = Array(swatches.prefix(7))
        let secondRow: [NSView] = Array(swatches.dropFirst(7)) + [colorWell]
        let rows = [firstRow, secondRow].map { views -> NSView in
            let row = NSStackView(views: views)
            row.spacing = 6
            return row
        }
        let colors = NSStackView(views: rows)
        colors.orientation = .vertical
        colors.alignment = .leading
        colors.spacing = 6

        emojiField.placeholderString = FL("Emoji")
        emojiField.delegate = self
        emojiField.alignment = .center
        emojiField.font = .systemFont(ofSize: 22)
        emojiField.widthAnchor.constraint(equalToConstant: 70).isActive = true
        let emojiButton = NSButton(title: FL("Emoji & Symbols"), target: self, action: #selector(showCharacterPalette))
        let emojiRow = NSStackView(views: [NSTextField(labelWithString: FL("Emoji:")), emojiField, emojiButton])

        preview.imageScaling = .scaleProportionallyUpOrDown
        preview.widthAnchor.constraint(equalToConstant: 160).isActive = true
        preview.heightAnchor.constraint(equalToConstant: 160).isActive = true

        let controls = NSStackView(views: [NSTextField(labelWithString: FL("Color:")), colors, emojiRow])
        controls.orientation = .vertical
        controls.alignment = .leading
        controls.spacing = 10
        colorPane.orientation = .horizontal
        colorPane.alignment = .top
        colorPane.spacing = 20
        colorPane.addArrangedSubview(controls)
        colorPane.addArrangedSubview(preview)
        updateSwatches()
    }

    // MARK: Tabs

    @objc private func tabChanged() {
        show(Tab(rawValue: tabs.selectedSegment) ?? .library)
    }

    private func show(_ tab: Tab) {
        self.tab = tab
        gridScroll.isHidden = tab == .colorAndEmoji
        mineButtons.isHidden = tab != .mine
        colorPane.isHidden = tab != .colorAndEmoji
        switch tab {
        case .library:
            choices = IconLibrary.defaultIcons
            note.stringValue = FL("Icons that come with macOS.")
        case .mine:
            choices = IconLibrary.icons(in: IconLibrary.personalFolder)
            note.stringValue = choices.isEmpty
                ? FL("Your library is empty: add images (PNG, ICNS, JPEG, HEIC, and more) to use them as icons.")
                : FL("Your own icons, kept for your account only.")
        case .colorAndEmoji:
            note.stringValue = folders.isEmpty ? FL("Colours and emoji apply to folders only.")
                : folders.count < targets.count ? FL("Applies to the selected folders only.") : ""
            updatePreview()
        }
        grid.reloadData()
        updateApplyButton()
    }

    private func updateApplyButton() {
        switch tab {
        case .library, .mine: applyButton.isEnabled = !grid.selectionIndexPaths.isEmpty
        case .colorAndEmoji: applyButton.isEnabled = !folders.isEmpty
        }
    }

    // MARK: Grid

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        choices.count
    }

    func collectionView(_ collectionView: NSCollectionView,
                        itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: IconChoiceItem.id, for: indexPath)
        let url = choices[indexPath.item]
        let image = images[url] ?? NSImage(contentsOf: url)
        images[url] = image
        (item as? IconChoiceItem)?.show(image, name: url.deletingPathExtension().lastPathComponent)
        return item
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        updateApplyButton()
    }

    @objc private func gridDoubleClicked(_ recognizer: NSClickGestureRecognizer) {
        let point = recognizer.location(in: grid)
        guard grid.indexPathForItem(at: point) != nil else { return }
        apply()
    }

    // MARK: Personal library

    @objc private func addIcons() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image, .icns]
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        do {
            try IconLibrary.add(panel.urls, to: IconLibrary.personalFolder)
        } catch {
            FileActions.showError(error.localizedDescription)
        }
        show(.mine)
    }

    @objc private func openLibrary() {
        let folder = IconLibrary.personalFolder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        FileViewer.openFolder(folder)
    }

    // MARK: Colour and emoji

    @objc private func swatchChosen(_ sender: NSButton) {
        color = sender.tag == 0 ? nil : FolderArtist.colors[sender.tag - 1].color
        updateSwatches()
        updatePreview()
    }

    @objc private func colorWellChanged() {
        color = colorWell.color
        updateSwatches()
        updatePreview()
    }

    private func updateSwatches() {
        for swatch in swatches {
            let chosen = swatch.tag == 0 ? color == nil : FolderArtist.colors[swatch.tag - 1].color == color
            swatch.layer?.borderWidth = chosen ? 2.5 : 0
            swatch.layer?.borderColor = NSColor.labelColor.cgColor
        }
    }

    func controlTextDidChange(_ notification: Notification) {
        emoji = emojiField.stringValue
        updatePreview()
    }

    @objc private func showCharacterPalette() {
        view.window?.makeFirstResponder(emojiField)
        NSApp.orderFrontCharacterPalette(nil)
    }

    private func updatePreview() {
        preview.image = FolderArtist.folder(color: color, emoji: emoji, side: 320)
    }

    // MARK: Applying

    @objc private func apply() {
        var changed: [URL] = []
        switch tab {
        case .library, .mine:
            guard let index = grid.selectionIndexPaths.first?.item,
                  let image = images[choices[index]] ?? NSImage(contentsOf: choices[index]) else { return }
            changed = targets.filter { NSWorkspace.shared.setIcon(image, forFile: $0.path) }
        case .colorAndEmoji:
            let image = FolderArtist.folder(color: color, emoji: emoji)
            changed = folders.filter { NSWorkspace.shared.setIcon(image, forFile: $0.path) }
        }
        finish(changed, failed: changed.count < (tab == .colorAndEmoji ? folders.count : targets.count))
    }

    @objc private func restoreDefault() {
        let changed = targets.filter { NSWorkspace.shared.setIcon(nil, forFile: $0.path) }
        finish(changed, failed: changed.count < targets.count)
    }

    @objc private func cancel() {
        view.window?.close()
    }

    private func finish(_ changed: [URL], failed: Bool) {
        if !changed.isEmpty {
            NotificationCenter.default.post(name: IconPickerWindow.didChange, object: changed)
        }
        if failed {
            FileActions.showError(FL("Some icons couldn't be changed. You may not have permission to modify those items."))
        }
        view.window?.close()
    }
}

/// One choice in the grid: the icon, highlighted when selected.
private final class IconChoiceItem: NSCollectionViewItem {
    static let id = NSUserInterfaceItemIdentifier("IconChoice")
    private let picture = NSImageView()

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 8
        picture.imageScaling = .scaleProportionallyUpOrDown
        picture.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(picture)
        NSLayoutConstraint.activate([
            picture.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            picture.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
            picture.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            picture.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
        ])
    }

    override var isSelected: Bool {
        didSet {
            view.layer?.backgroundColor = isSelected
                ? NSColor.selectedContentBackgroundColor.withAlphaComponent(0.35).cgColor : nil
        }
    }

    func show(_ image: NSImage?, name: String) {
        picture.image = image
        view.toolTip = name
    }
}
