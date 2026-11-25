import AppKit

/// A name cell with room for a symbol after the name (the cloud state).
public final class StatusCellView: NSTableCellView {
    let status = NSImageView()
    private var statusWidth: NSLayoutConstraint?

    public func setStatus(_ image: NSImage?, tip: String?) {
        status.image = image
        status.toolTip = tip
        statusWidth?.constant = image == nil ? 0 : 14
    }

    fileprivate func install(after text: NSTextField) {
        status.imageScaling = .scaleProportionallyUpOrDown
        status.contentTintColor = .secondaryLabelColor
        status.translatesAutoresizingMaskIntoConstraints = false
        addSubview(status)
        let width = status.widthAnchor.constraint(equalToConstant: 0)
        statusWidth = width
        NSLayoutConstraint.activate([
            width,
            status.heightAnchor.constraint(equalToConstant: 14),
            status.centerYAnchor.constraint(equalTo: centerYAnchor),
            status.leadingAnchor.constraint(equalTo: text.trailingAnchor, constant: 4),
            status.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
        ])
    }
}

public enum TableCells {
    public static func make(_ identifier: NSUserInterfaceItemIdentifier, withIcon: Bool,
                     alignment: NSTextAlignment = .left, withStatus: Bool = false) -> NSTableCellView {
        let cell = withStatus ? StatusCellView() : NSTableCellView()
        cell.identifier = identifier

        let text = NSTextField(labelWithString: "")
        text.lineBreakMode = .byTruncatingMiddle
        text.alignment = alignment
        text.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(text)
        cell.textField = text

        var constraints = [text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)]
        if let cell = cell as? StatusCellView {
            cell.install(after: text)
            // The name gives way to the symbol, which then sits right after it.
            text.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        } else {
            constraints.append(text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2))
        }
        if withIcon {
            let image = NSImageView()
            image.imageScaling = .scaleProportionallyUpOrDown
            image.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(image)
            cell.imageView = image
            constraints += [
                image.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                image.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                image.widthAnchor.constraint(equalToConstant: 16),
                image.heightAnchor.constraint(equalToConstant: 16),
                text.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 6),
            ]
        } else {
            constraints.append(text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2))
        }
        NSLayoutConstraint.activate(constraints)
        return cell
    }
}
