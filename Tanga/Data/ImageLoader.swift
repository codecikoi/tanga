import UIKit

/// Загрузка флагов и иконок монет: память → диск → сеть (несколько адресов по очереди).
final class ImageLoader {
    static let shared = ImageLoader()

    private let memory = NSCache<NSString, UIImage>()
    private let disk = FileStore(.cachesDirectory, folder: "Tanga/icons")
    private let http = HTTPClient(timeout: 12)
    private var inflight: [String: Task<UIImage?, Never>] = [:]
    private var failed: Set<String> = []

    func cached(_ key: String) -> UIImage? {
        memory.object(forKey: key as NSString)
    }

    func image(key: String, urls: [URL]) async -> UIImage? {
        if let image = cached(key) { return image }
        if failed.contains(key) { return nil }
        if let task = inflight[key] { return await task.value }

        let task = Task { [disk, http] () -> UIImage? in
            let file = "\(key).png"
            if let data = disk.read(file), let image = UIImage(data: data) { return image }
            for url in urls {
                if let data = try? await http.data(from: [url]), let image = UIImage(data: data) {
                    disk.write(data, file)
                    return image
                }
            }
            return nil
        }
        inflight[key] = task
        let image = await task.value
        inflight[key] = nil

        if let image {
            memory.setObject(image, forKey: key as NSString)
        } else {
            failed.insert(key)
        }
        return image
    }
}
