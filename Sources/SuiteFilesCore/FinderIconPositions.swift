import Foundation

/// Where Finder placed a folder's icons, as its icon view shows them: the `Iloc` records of the folder's
/// `.DS_Store` (the desktop's is `~/Desktop/.DS_Store`). Each is an icon's centre, in points from the
/// top-left of the folder's view. Only what Finder wrote is there: icons it never placed have none, and
/// while Finder keeps a folder arranged (by name, kind and so on) the positions are not used.
public enum FinderIconPositions {
    /// Item name → the centre of its icon.
    public static func positions(in folder: URL) -> [String: CGPoint] {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent(".DS_Store")) else { return [:] }
        return (try? positions(from: data)) ?? [:]
    }

    static func positions(from data: Data) throws -> [String: CGPoint] {
        var result: [String: CGPoint] = [:]
        for record in try DSStore(data).records() where record.code == "Iloc" {
            guard case .data(let blob) = record.value, let point = point(from: blob) else { continue }
            result[record.name] = point
        }
        return result
    }

    /// An `Iloc` blob: x and y, four bytes each, big-endian, then eight bytes Finder doesn't explain.
    static func point(from blob: Data) -> CGPoint? {
        let bytes = [UInt8](blob)
        guard bytes.count >= 8 else { return nil }
        func u32(_ at: Int) -> UInt32 {
            UInt32(bytes[at]) << 24 | UInt32(bytes[at + 1]) << 16 | UInt32(bytes[at + 2]) << 8 | UInt32(bytes[at + 3])
        }
        return CGPoint(x: Double(u32(0)), y: Double(u32(4)))
    }
}
