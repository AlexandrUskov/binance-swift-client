import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A tiny, dependency-free async client for Binance's **public** market-data REST API.
///
/// Public endpoints only — no API key, no request signing — so it runs anywhere, including CI.
/// Built with `async/await` and `URLSession`; numbers that Binance returns as strings are parsed
/// to `Double`, and the positional-array `klines` payload is decoded by index.
///
/// ```swift
/// let client = BinanceClient()
/// let ticker = try await client.ticker24h(symbol: "BTCUSDT")
/// let candles = try await client.klines(symbol: "ETHUSDT", interval: .h1, limit: 100)
/// ```
public struct BinanceClient: Sendable {

    /// Candle interval supported by the `/klines` endpoint.
    public enum Interval: String, CaseIterable, Sendable {
        case m1 = "1m", m5 = "5m", m15 = "15m"
        case h1 = "1h", h4 = "4h"
        case d1 = "1d", w1 = "1w"
    }

    /// Errors surfaced by the client.
    public enum ClientError: Error, Equatable {
        case invalidURL
        case http(status: Int)
        case decoding(String)
        case transport(String)
    }

    private let baseURL: URL
    private let session: URLSession

    /// - Parameters:
    ///   - baseURL: Binance REST base. Override to point at a mock or a regional mirror.
    ///   - session: inject a custom `URLSession` for tests or proxying.
    public init(
        baseURL: URL = URL(string: "https://api.binance.com")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    /// 24-hour rolling-window statistics for one symbol (e.g. `"BTCUSDT"`).
    public func ticker24h(symbol: String) async throws -> Ticker24h {
        let url = try makeURL(path: "/api/v3/ticker/24hr", query: ["symbol": symbol])
        let data = try await get(url)
        do {
            return try JSONDecoder().decode(Ticker24h.self, from: data)
        } catch {
            throw ClientError.decoding(String(describing: error))
        }
    }

    /// OHLCV candlesticks for one symbol, newest last.
    /// - Parameter limit: number of candles (Binance caps this at 1000).
    public func klines(symbol: String, interval: Interval, limit: Int = 100) async throws -> [Kline] {
        let url = try makeURL(path: "/api/v3/klines", query: [
            "symbol": symbol,
            "interval": interval.rawValue,
            "limit": String(max(1, min(limit, 1000))),
        ])
        let data = try await get(url)
        return try Kline.decode(from: data)
    }

    // MARK: - Internals (internal for testability)

    /// Builds a request URL with deterministically ordered query items.
    func makeURL(path: String, query: [String: String]) throws -> URL {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else { throw ClientError.invalidURL }

        components.queryItems = query
            .map { URLQueryItem(name: $0.key, value: $0.value) }
            .sorted { $0.name < $1.name }

        guard let url = components.url else { throw ClientError.invalidURL }
        return url
    }

    private func get(_ url: URL) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw ClientError.transport(String(describing: error))
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ClientError.http(status: http.statusCode)
        }
        return data
    }
}
