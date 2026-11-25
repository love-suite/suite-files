import AppKit
import SuiteFilesCore

/// The collection view hides the items being dragged out of it; while left in place as a ghost, the
/// item's view and its layer stay shown.
private final class ShownLayer: CALayer {
    var keepsShown = false

    override init() { super.init() }
    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { super.init(coder: coder) }

    override var isHidden: Bool {
        get { super.isHidden }
        set { super.isHidden = keepsShown ? false : newValue }
    }

    override var opacity: Float {
        get { super.opacity }
        set { if !keepsShown { super.opacity = newValue } }
    }
}

private final class ItemView: NSView {
    var keepsShown = false {
        didSet { (layer as? ShownLayer)?.keepsShown = keepsShown }
    }

    override func makeBackingLayer() -> CALayer { ShownLayer() }

    override var isHidden: Bool {
        get { super.isHidden }
        set { super.isHidden = keepsShown ? false : newValue }
    }
}

/// One icon with its name, for the desktop and the icon view. As on Windows, selection shows
/// only on the name, in the system selection colour.
public final class IconItemView: NSCollectionViewItem {
    public static let reuseID = NSUserInterfaceItemIdentifier("IconItem")
    public static let size = IconSize.medium.cellSize
    /// Names as Finder writes them under icons: 12 points by default (its Text Size).
    static let font = NSFont.systemFont(ofSize: 12)

    /// Where the name starts, from the top of the cell (inset + icon + gap).
    public static func nameTop(iconSide: CGFloat) -> CGFloat { 4 + iconSide + 4 }

    /// On the wallpaper names are white with a shadow; in a window they use the normal text colour.
    public var onDesktop = false {
        didSet { updateHighlight() }
    }

    public var iconSide: CGFloat = IconSize.medium.iconSide {
        didSet {
            iconWidth?.constant = iconSide
            iconHeight?.constant = iconSide
        }
    }

    /// The name on the icon's right, left-aligned, instead of under it: Finder's Label Position › Right.
    public var labelOnRight = false {
        didSet {
            guard labelOnRight != oldValue else { return }
            _ = view
            NSLayoutConstraint.deactivate(labelOnRight ? bottomLabelPlacement : rightLabelPlacement)
            NSLayoutConstraint.activate(labelOnRight ? rightLabelPlacement : bottomLabelPlacement)
            label.alignment = labelOnRight ? .left : .center
            infoLabel.alignment = label.alignment
            layOutName()
        }
    }

    /// A second line after the name, in blue, as Finder's Show Item Info writes it (a picture's size, a
    /// folder's item count); nil for none.
    public var info: String? {
        didSet {
            _ = view
            infoLabel.stringValue = info ?? ""
            infoLabel.isHidden = info == nil
            placeName()
        }
    }

    /// Thumbnails of the contents instead of icons: Finder's Show Icon Preview for this view; nil follows
    /// the display settings (`DisplaySettings.showsThumbnails`).
    public var showsPreview: Bool?

    private var iconWidth: NSLayoutConstraint?
    private var iconHeight: NSLayoutConstraint?
    /// The icon at the top, centred (names under it), or on the left, centred vertically (names on its
    /// right).
    private var bottomLabelPlacement: [NSLayoutConstraint] = []
    private var rightLabelPlacement: [NSLayoutConstraint] = []
    /// The name's frame as wide as its longest line, measured here rather than left to AppKit.

    private let iconView: NSImageView = {
        let v = NSImageView()
        v.imageScaling = .scaleProportionallyUpOrDown
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let label: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.alignment = .center
        // Two lines at most, laid out as Finder does (`FinderName`): the line break is in the text.
        f.lineBreakMode = .byClipping
        f.maximumNumberOfLines = 2
        f.font = IconItemView.font
        f.wantsLayer = true
        f.layer?.cornerRadius = 3
        f.translatesAutoresizingMaskIntoConstraints = false
        // Long names shrink (and truncate) to the cell width; short ones hug their text.
        f.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return f
    }()

    /// The item info's line.
    private let infoLabel: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.alignment = .center
        f.lineBreakMode = .byTruncatingMiddle
        f.maximumNumberOfLines = 1
        f.isHidden = true
        return f
    }()

    /// Finder's cloud sign after the name, when the cloud state shows there.
    private let status: NSImageView = {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    /// The cloud sign's width: 14 points when there is one, none otherwise.
    private var statusSide: CGFloat = 0

    /// The name, hidden while it is renamed in place.
    public var nameView: NSView { label }

    /// The number of items in a stack, on the icon's top-right corner.
    private let badge: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.font = .boldSystemFont(ofSize: 10)
        f.textColor = .white
        f.alignment = .center
        f.wantsLayer = true
        f.layer?.backgroundColor = NSColor.systemGray.cgColor
        f.layer?.cornerRadius = 8
        f.isHidden = true
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }()

    private static let wallpaperShadow: NSShadow = {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.8)
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowBlurRadius = 2
        return shadow
    }()

    public override var isSelected: Bool {
        didSet { updateHighlight() }
    }

    public override var highlightState: NSCollectionViewItem.HighlightState {
        didSet { updateHighlight() }
    }

    /// Left in place, faded, while dragged. The contents fade rather than the view itself, whose alpha
    /// the collection view manages.
    public func setGhost(_ ghost: Bool) {
        _ = view
        let itemView = view as? ItemView
        itemView?.keepsShown = false
        if ghost {
            view.isHidden = false
            view.layer?.isHidden = false
            view.alphaValue = naturalAlpha
        }
        itemView?.keepsShown = ghost
        setContentAlpha(ghost ? DragGhost.alpha : 1)
    }

    /// Hidden files are dimmed.
    private var naturalAlpha: CGFloat = 1

    /// Icons moved under the pointer show through, as a drag image does.
    public func setContentAlpha(_ alpha: CGFloat) {
        _ = view
        for part in [iconView, label, infoLabel, status, badge] as [NSView] { part.alphaValue = alpha }
    }

    private func updateHighlight() {
        let on = isSelected || highlightState == .forSelection
        label.layer?.backgroundColor = on ? NSColor.selectedContentBackgroundColor.cgColor : nil
        label.textColor = on || onDesktop ? .white : .labelColor
        label.shadow = onDesktop && !on ? Self.wallpaperShadow : nil
        status.contentTintColor = onDesktop ? .white : .secondaryLabelColor
        // Finder's blue; lighter on the wallpaper, where it has the names' shadow.
        infoLabel.textColor = on ? .white : onDesktop ? Self.desktopInfoColor : .systemBlue
        infoLabel.shadow = label.shadow
    }

    private static let desktopInfoColor = NSColor(name: nil) { _ in
        NSColor.systemBlue.blended(withFraction: 0.45, of: .white) ?? .systemBlue
    }

    public override func loadView() {
        view = ItemView()
        view.addSubview(iconView)
        view.addSubview(label)
        view.addSubview(infoLabel)
        view.addSubview(badge)
        view.addSubview(status)
        // The name and the cloud sign are placed by hand (`placeName`): AppKit's own width constraints on a
        // text field would win over a width measured here.
        label.translatesAutoresizingMaskIntoConstraints = true
        status.translatesAutoresizingMaskIntoConstraints = true
        infoLabel.translatesAutoresizingMaskIntoConstraints = true
        let width = iconView.widthAnchor.constraint(equalToConstant: iconSide)
        let height = iconView.heightAnchor.constraint(equalToConstant: iconSide)
        iconWidth = width
        iconHeight = height
        bottomLabelPlacement = [
            iconView.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            iconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ]
        rightLabelPlacement = [
            iconView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            iconView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ]
        NSLayoutConstraint.activate(labelOnRight ? rightLabelPlacement : bottomLabelPlacement)
        NSLayoutConstraint.activate([
            width, height,


            badge.centerXAnchor.constraint(equalTo: iconView.trailingAnchor, constant: -4),
            badge.centerYAnchor.constraint(equalTo: iconView.topAnchor, constant: 6),
            badge.heightAnchor.constraint(equalToConstant: 16),
            badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 16),
        ])
        updateHighlight()
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        updateHighlight()
    }

    /// The file the thumbnail being made is for, so a reused cell ignores one that arrives late.
    private var thumbnailFor: URL?

    /// A file or folder: its thumbnail or icon, with its cloud state; hidden items are dimmed.
    public func configure(with item: FileItem) {
        configure(name: DisplaySettings.name(of: item),
                  image: SyncBadge.decorate(FileIcons.icon(for: item), with: item.sync,
                                            displaySide: iconSide, isAlias: item.isAlias), count: nil)
        naturalAlpha = item.isHidden ? 0.5 : 1
        view.alphaValue = naturalAlpha
        view.toolTip = DisplaySettings.showsSyncBadges ? item.sync.map(SyncBadge.description) : nil
        let sign = DisplaySettings.syncBadgeStyle == .afterName ? item.sync.flatMap(SyncBadge.nameSign) : nil
        status.image = sign
        statusSide = sign == nil ? 0 : 14
        placeName()
        guard showsPreview ?? DisplaySettings.showsThumbnails, Thumbnails.applies(to: item) else { return }
        if let image = Thumbnails.cached(for: item, side: iconSide) {
            iconView.image = SyncBadge.decorate(image, with: item.sync, displaySide: iconSide)
            return
        }
        thumbnailFor = item.url
        let scale = view.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        Thumbnails.load(for: item, side: iconSide, scale: scale) { [weak self] image in
            guard let self, self.thumbnailFor == item.url else { return }
            self.iconView.image = SyncBadge.decorate(image, with: item.sync, displaySide: self.iconSide)
        }
    }

    /// `count` shows a stack's size as a badge.
    public func configure(name: String, icon: URL, count: Int?) {
        configure(name: name, image: NSWorkspace.shared.icon(forFile: icon.path), count: count)
    }

    /// The names' size, in points (the desktop takes Finder's Text Size).
    public var nameSize: CGFloat = 12 {
        didSet { updateNameFont() }
    }

    /// The whole name, laid out on two lines for the cell's width.
    private var fullName = ""

    /// Names in bold, as Finder's desktop writes them (the desktop sets it); regular in a window.
    public var boldName = false {
        didSet { updateNameFont() }
    }

    private func updateNameFont() {
        // Finder's desktop writes its names semibold, which is narrower than bold.
        label.font = .systemFont(ofSize: nameSize, weight: boldName ? .semibold : .regular)
        infoLabel.font = .systemFont(ofSize: nameSize)
        layOutName()
    }

    /// The room the name has: the cell's width, or what is left on the icon's right.
    private var nameWidth: CGFloat {
        max(labelOnRight ? view.bounds.width - iconSide - 12 : view.bounds.width, 20)
    }

    private func layOutName() {
        let width = nameWidth
        label.preferredMaxLayoutWidth = width
        let text: String
        if DisplaySettings.namesOnTwoLines {
            label.maximumNumberOfLines = 2
            label.lineBreakMode = .byClipping
            // A margin on each side, as Finder leaves one (the text field also draws inside its frame).
            text = FinderName.layout(fullName, font: label.font ?? Self.font, width: width - 8)
        } else {
            label.maximumNumberOfLines = 1
            label.lineBreakMode = .byTruncatingMiddle
            text = fullName
        }
        if label.stringValue != text { label.stringValue = text }
        placeName()
    }

    /// The name under the icon, as wide as its longest line (a few points more: the text field draws inside
    /// its frame), centred, the cloud sign after it, the item info under it; on the right, the name and
    /// the item info start after the icon, centred together on it.
    private func placeName() {
        let font = label.font ?? Self.font
        let lines = label.stringValue.components(separatedBy: "\n")
        let widest = lines.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        let gap: CGFloat = statusSide > 0 ? 3 : 0
        let bounds = view.bounds
        let room = nameWidth
        let width = min(ceil(widest) + 6, max(room - statusSide - gap, 20))
        let lineHeight = ceil(font.ascender - font.descender + font.leading)
        let height = lineHeight * CGFloat(lines.count) + 2
        let infoFont = infoLabel.font ?? font
        let infoHeight = info == nil ? 0 : ceil(infoFont.ascender - infoFont.descender + infoFont.leading) + 2
        let x: CGFloat
        let top: CGFloat
        if labelOnRight {
            x = 4 + iconSide + 6
            top = max(0, ((bounds.height - height - infoHeight) / 2).rounded())
        } else {
            x = ((bounds.width - width - gap - statusSide) / 2).rounded()
            top = 4 + iconSide + 4
        }
        let y = view.isFlipped ? top : bounds.height - top - height
        label.frame = NSRect(x: x, y: y, width: width, height: height)
        status.frame = NSRect(x: x + width + gap, y: y + (height - 13) / 2, width: statusSide, height: 13)
        // The text field's own measure: centred text needs a little more room than the text's width.
        let infoWidth = min(ceil(infoLabel.cell?.cellSize.width ?? 0) + 2, room)
        let infoX = labelOnRight ? x : ((bounds.width - infoWidth) / 2).rounded()
        let infoY = view.isFlipped ? top + height : y - infoHeight
        infoLabel.frame = NSRect(x: infoX, y: infoY, width: infoWidth, height: infoHeight)
    }

    public override func viewDidLayout() {
        super.viewDidLayout()
        layOutName()
    }

    public func configure(name: String, image: NSImage?, count: Int?) {
        _ = view
        thumbnailFor = nil
        naturalAlpha = 1
        view.alphaValue = 1
        view.toolTip = nil
        iconView.image = image
        fullName = name
        layOutName()
        status.image = nil
        statusSide = 0
        info = nil
        badge.isHidden = count == nil
        badge.stringValue = count.map { " \($0) " } ?? ""
    }
}
