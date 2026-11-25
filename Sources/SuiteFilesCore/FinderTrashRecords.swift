import Foundation

/// Where Finder says the items in a Trash came from. Finder writes it in the Trash folder's `.DS_Store`,
/// as a "put back" location (`ptbL`, the folder, relative to the volume's root) and name (`ptbN`) for each
/// item. The file format is not documented by Apple but is well known: a buddy allocator holding a B-tree
/// of records. Only read here, never written.
public enum FinderTrashRecords {
    private static var cache: [String: (modified: Date, origins: [String: URL])] = [:]
    private static let lock = NSLock()

    /// Trashed item name → where it was deleted from, for the Trash folder `trash`. Read again only
    /// when the file changes.
    public static func origins(in trash: URL) -> [String: URL] {
        let file = trash.appendingPathComponent(".DS_Store")
        guard let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate else { return [:] }
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[file.path], cached.modified == modified { return cached.origins }
        let volume = (try? trash.resourceValues(forKeys: [.volumeURLKey]))?.volume ?? URL(fileURLWithPath: "/")
        let origins = (try? Data(contentsOf: file)).flatMap { try? parse($0, volumeRoot: volume) } ?? [:]
        cache[file.path] = (modified, origins)
        return origins
    }

    /// The original location of an item in a Trash (`~/.Trash` or a disk's `.Trashes/<uid>`), if Finder
    /// recorded one.
    public static func originalLocation(of trashed: URL) -> URL? {
        let folder = trashed.deletingLastPathComponent()
        let isTrash = folder.lastPathComponent == ".Trash"
            || folder.deletingLastPathComponent().lastPathComponent == ".Trashes"
        guard isTrash else { return nil }
        return origins(in: folder)[trashed.lastPathComponent]
    }

    // MARK: Parsing

    enum Failure: Error { case notADSStore, truncated, noDirectory }

    /// The put-back records of a `.DS_Store` file, as trashed name → original URL on `volumeRoot`.
    static func parse(_ data: Data, volumeRoot: URL) throws -> [String: URL] {
        let records = try DSStore(data).records()
        var folders: [String: String] = [:], names: [String: String] = [:]
        for record in records {
            guard case .string(let value) = record.value else { continue }
            switch record.code {
            case "ptbL": folders[record.name] = value
            case "ptbN": names[record.name] = value
            default: break
            }
        }
        var origins: [String: URL] = [:]
        for (trashedName, folder) in folders {
            let name = names[trashedName] ?? trashedName
            let directory = folder.isEmpty ? volumeRoot : volumeRoot.appendingPathComponent(folder, isDirectory: true)
            origins[trashedName] = directory.appendingPathComponent(name)
        }
        return origins
    }
}

/// A read-only `.DS_Store` reader: the records Finder keeps for a folder's items (Put Back origins, icon
/// positions and so on), by item name and four-letter code.
public struct DSStore {
    public enum Value: Equatable, Sendable {
        case string(String), number(Int), bool(Bool), data(Data), other
    }

    public struct Record: Equatable, Sendable {
        public var name: String
        public var code: String
        public var value: Value
    }

    private let bytes: [UInt8]

    public init(_ data: Data) throws {
        bytes = [UInt8](data)
        // A four-byte prefix (1), then "Bud1".
        guard bytes.count >= 36, try u32(0) == 1, String(bytes: bytes[4..<8], encoding: .ascii) == "Bud1" else {
            throw FinderTrashRecords.Failure.notADSStore
        }
    }

    public func records() throws -> [Record] {
        // The header points at the allocator's root block: the block addresses, then the directory of
        // named trees, of which "DSDB" is the one with the records. Offsets count from after the prefix.
        let rootOffset = Int(try u32(8)) + 4
        let blockCount = Int(try u32(rootOffset))
        var addresses: [UInt32] = []
        for index in 0..<blockCount { addresses.append(try u32(rootOffset + 8 + index * 4)) }
        // The address table is padded to a multiple of 256 entries.
        var position = rootOffset + 8 + ((blockCount + 255) / 256) * 256 * 4
        let directoryCount = Int(try u32(position))
        position += 4
        var tree: Int?
        for _ in 0..<directoryCount {
            let length = Int(try byte(position))
            let name = String(bytes: try slice(position + 1, length), encoding: .ascii)
            let block = Int(try u32(position + 1 + length))
            position += 1 + length + 4
            if name == "DSDB" { tree = block }
        }
        guard let tree else { throw FinderTrashRecords.Failure.noDirectory }

        func offset(ofBlock block: Int) throws -> Int {
            guard block < addresses.count else { throw FinderTrashRecords.Failure.truncated }
            return Int(addresses[block] & ~0x1f) + 4
        }

        let header = try offset(ofBlock: tree)
        var records: [Record] = []
        var visited = Set<Int>()
        func readNode(_ block: Int) throws {
            // A damaged file must not loop forever.
            guard visited.insert(block).inserted else { return }
            var position = try offset(ofBlock: block)
            let rightmost = Int(try u32(position))
            let count = Int(try u32(position + 4))
            position += 8
            for _ in 0..<count {
                if rightmost != 0 {
                    try readNode(Int(try u32(position)))
                    position += 4
                }
                let (record, next) = try readRecord(at: position)
                records.append(record)
                position = next
            }
            if rightmost != 0 { try readNode(rightmost) }
        }
        try readNode(Int(try u32(header)))
        return records
    }

    private func readRecord(at start: Int) throws -> (Record, Int) {
        var position = start
        let nameLength = Int(try u32(position))
        let name = try utf16(position + 4, nameLength)
        position += 4 + nameLength * 2
        let code = String(bytes: try slice(position, 4), encoding: .ascii) ?? ""
        let type = String(bytes: try slice(position + 4, 4), encoding: .ascii) ?? ""
        position += 8
        let value: Value
        switch type {
        case "bool":
            value = .bool(try byte(position) != 0)
            position += 1
        case "long", "shor":
            value = .number(Int(try u32(position)))
            position += 4
        case "type":
            value = .other
            position += 4
        case "comp", "dutc":
            value = .other
            position += 8
        case "blob":
            let length = Int(try u32(position))
            value = .data(Data(try slice(position + 4, length)))
            position += 4 + length
        case "ustr":
            let length = Int(try u32(position))
            value = .string(try utf16(position + 4, length))
            position += 4 + length * 2
        default:
            throw FinderTrashRecords.Failure.truncated
        }
        return (Record(name: name, code: code, value: value), position)
    }

    // MARK: Bytes (big-endian)

    private func slice(_ start: Int, _ length: Int) throws -> ArraySlice<UInt8> {
        guard start >= 0, length >= 0, start + length <= bytes.count else { throw FinderTrashRecords.Failure.truncated }
        return bytes[start..<start + length]
    }

    private func byte(_ at: Int) throws -> UInt8 { try slice(at, 1).first! }

    private func u32(_ at: Int) throws -> UInt32 {
        try slice(at, 4).reduce(0) { $0 << 8 | UInt32($1) }
    }

    private func utf16(_ at: Int, _ count: Int) throws -> String {
        let raw = try slice(at, count * 2)
        let units = stride(from: raw.startIndex, to: raw.endIndex, by: 2).map { UInt16(raw[$0]) << 8 | UInt16(raw[$0 + 1]) }
        return String(decoding: units, as: UTF16.self)
    }
}
