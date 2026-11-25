import AppKit
import SuiteFilesCore
import QuickLookThumbnailing

/// Previews of file contents shown in place of icons, as Finder and Explorer do for images, videos and
/// documents. Made by Quick Look, so installed Quick Look add-ons provide thumbnails too.
public enum Thumbnails {
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 2000
        return cache
    }()

    /// Folders, apps and shortcuts keep their icon; everything else may have a preview.
    public static func applies(to item: FileItem) -> Bool {
        !item.isFolder && !item.isAlias && item.url.pathExtension.lowercased() != "app"
    }

    /// A thumbnail already made for this version of the file, if any.
    public static func cached(for item: FileItem, side: CGFloat) -> NSImage? {
        cache.object(forKey: key(item, side))
    }

    /// Makes the thumbnail in the background; `completion` runs on the main thread, only if there is one.
    public static func load(for item: FileItem, side: CGFloat, scale: CGFloat,
                            completion: @escaping (NSImage) -> Void) {
        let key = key(item, side)
        if let image = cache.object(forKey: key) {
            completion(image)
            return
        }
        let request = QLThumbnailGenerator.Request(fileAt: item.url, size: CGSize(width: side, height: side),
                                                   scale: scale, representationTypes: .thumbnail)
        // Drawn like an icon: a border for pictures, a page for documents.
        request.iconMode = true
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
            guard let image = representation?.nsImage else { return }
            DispatchQueue.main.async {
                cache.setObject(image, forKey: key)
                completion(image)
            }
        }
    }

    private static func key(_ item: FileItem, _ side: CGFloat) -> NSString {
        "\(item.url.path)|\(item.modified?.timeIntervalSinceReferenceDate ?? 0)|\(Int(side))" as NSString
    }
}
