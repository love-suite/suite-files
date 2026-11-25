import CoreGraphics
import Foundation

/// The size of icons in the file views (the desktop's and the windows' icons views).
public enum IconSize: String, Codable, CaseIterable, Sendable {
    case small, medium, large

    public var iconSide: CGFloat {
        switch self {
        case .small: return 40
        case .medium: return 60
        case .large: return 84
        }
    }

    /// One grid cell: the icon and one line of name, with some air around.
    public var cellSize: CGSize {
        CGSize(width: max(iconSide + 24, 72), height: 4 + iconSide + 4 + 32 + 8)
    }
}
