import Foundation

/// 24-hour ticker statistics.
///
/// Binance returns every number as a JSON string (`"67000.50"`); this type parses them to `Double`
/// during decoding so callers get clean numeric values.
public struct Ticker24h: Decodable, Sendable, Equatable {
    public let symbol: String
    public let lastPrice: Double
    public let priceChangePercent: Double
    public let highPrice: Double
    public let lowPrice: Double
    public let volume: Double
    public let quoteVolume: Double

    enum CodingKeys: String, CodingKey {
        case symbol, lastPrice, priceChangePercent, highPrice, lowPrice, volume, quoteVolume
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try c.decode(String.self, forKey: .symbol)
        lastPrice = try Ticker24h.double(c, .lastPrice)
        priceChangePercent = try Ticker24h.double(c, .priceChangePercent)
        highPrice = try Ticker24h.double(c, .highPrice)
        lowPrice = try Ticker24h.double(c, .lowPrice)
        volume = try Ticker24h.double(c, .volume)
        quoteVolume = try Ticker24h.double(c, .quoteVolume)
    }

    public init(
        symbol: String, lastPrice: Double, priceChangePercent: Double,
        highPrice: Double, lowPrice: Double, volume: Double, quoteVolume: Double
    ) {
        self.symbol = symbol
        self.lastPrice = lastPrice
        self.priceChangePercent = priceChangePercent
        self.highPrice = highPrice
        self.lowPrice = lowPrice
        self.volume = volume
        self.quoteVolume = quoteVolume
    }

    private static func double(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) throws -> Double {
        let raw = try c.decode(String.self, forKey: key)
        guard let value = Double(raw) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: c, debugDescription: "Not a number: \(raw)")
        }
        return value
    }
}

/// One OHLCV candle.
///
/// The `/klines` endpoint returns each candle as a **positional array**, not a keyed object:
/// `[openTime, "open", "high", "low", "close", "volume", closeTime, …]`. We decode by index,
/// tolerating both `String` and numeric JSON for the price fields.
public struct Kline: Sendable, Equatable {
    public let openTime: Int64
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double
    public let volume: Double
    public let closeTime: Int64

    public init(
        openTime: Int64, open: Double, high: Double, low: Double,
        close: Double, volume: Double, closeTime: Int64
    ) {
        self.openTime = openTime
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
        self.closeTime = closeTime
    }

    /// Decodes Binance's array-of-arrays klines payload.
    public static func decode(from data: Data) throws -> [Kline] {
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[Any]] else {
            throw BinanceClient.ClientError.decoding("klines: expected an array of arrays")
        }
        return try rows.map { row in
            guard row.count >= 7 else {
                throw BinanceClient.ClientError.decoding("klines: row too short (\(row.count) fields)")
            }
            return Kline(
                openTime: Kline.int64(row[0]),
                open: Kline.double(row[1]),
                high: Kline.double(row[2]),
                low: Kline.double(row[3]),
                close: Kline.double(row[4]),
                volume: Kline.double(row[5]),
                closeTime: Kline.int64(row[6])
            )
        }
    }

    private static func double(_ any: Any) -> Double {
        if let d = any as? Double { return d }
        if let s = any as? String { return Double(s) ?? 0 }
        if let n = any as? NSNumber { return n.doubleValue }
        return 0
    }

    private static func int64(_ any: Any) -> Int64 {
        if let n = any as? NSNumber { return n.int64Value }
        if let d = any as? Double { return Int64(d) }
        if let s = any as? String { return Int64(s) ?? 0 }
        return 0
    }
}
