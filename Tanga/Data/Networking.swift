import Foundation

/// Все внешние адреса. Ключи API не нужны.
nonisolated enum Endpoints {
    /// Живые курсы фиата и крипты к USD, обновляются примерно раз в минуту.
    static let coinbaseRates = URL(string: "https://api.coinbase.com/v2/exchange-rates?currency=USD")!
    /// Список криптовалют Coinbase: название, фирменный цвет, порядок популярности.
    static let coinbaseCrypto = URL(string: "https://api.coinbase.com/v2/currencies/crypto")!

    /// Currency API (fawazahmed0): основной CDN и запасное зеркало.
    static func currencyAPI(version: String, file: String) -> [URL] {
        [
            URL(string: "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@\(version)/v1/\(file)")!,
            URL(string: "https://\(version).currency-api.pages.dev/v1/\(file)")!,
        ]
    }

    static var latestUSD: [URL] { currencyAPI(version: "latest", file: "currencies/usd.json") }
    static var currencyNames: [URL] { currencyAPI(version: "latest", file: "currencies.json") }
    static func usd(on day: String) -> [URL] { currencyAPI(version: day, file: "currencies/usd.json") }

    static func flag(_ region: String) -> URL {
        URL(string: "https://flagcdn.com/w160/\(region.lowercased()).png")!
    }

    static func cryptoIcons(_ code: String) -> [URL] {
        let code = code.lowercased()
        return [
            URL(string: "https://assets.coincap.io/assets/icons/\(code)@2x.png")!,
            URL(string: "https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/\(code).png")!,
        ]
    }
}

final class HTTPClient {
    private let session: URLSession

    init(timeout: TimeInterval = 15) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        session = URLSession(configuration: config)
    }

    /// Пробует адреса по очереди, возвращает первый успешный ответ.
    func data(from urls: [URL]) async throws -> Data {
        var lastError: Error = URLError(.badURL)
        for url in urls {
            do {
                let (data, response) = try await session.data(from: url)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    lastError = URLError(.badServerResponse)
                    continue
                }
                return data
            } catch {
                lastError = error
                if (error as? URLError)?.code == .cancelled { break }
            }
        }
        throw lastError
    }
}

/// Простое файловое хранилище в папке приложения.
final class FileStore {
    let directory: URL

    init(_ base: FileManager.SearchPathDirectory, folder: String) {
        let root = (try? FileManager.default.url(for: base, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        directory = root.appendingPathComponent(folder, isDirectory: true)
        createDirectory()
    }

    func read(_ name: String) -> Data? {
        try? Data(contentsOf: directory.appendingPathComponent(name))
    }

    func write(_ data: Data, _ name: String) {
        try? data.write(to: directory.appendingPathComponent(name), options: .atomic)
    }

    func decode<T: Decodable>(_ type: T.Type, _ name: String) -> T? {
        read(name).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    func encode<T: Encodable>(_ value: T, _ name: String) {
        if let data = try? JSONEncoder().encode(value) { write(data, name) }
    }

    private func createDirectory() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
