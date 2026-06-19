import Testing
import Foundation
@testable import BinanceClient

@Suite("BinanceClient")
struct BinanceClientTests {

    // MARK: - Kline decoding (positional arrays)

    @Test("Decodes klines from Binance's array-of-arrays payload")
    func decodeKlines() throws {
        let json = Data("""
        [[1609459200000,"29000.0","29500.5","28800.0","29250.1","1234.5",1609462799999,"3.6e7",100,"y","z","0"]]
        """.utf8)

        let candles = try Kline.decode(from: json)

        #expect(candles.count == 1)
        #expect(candles[0].openTime == 1609459200000)
        #expect(candles[0].open == 29000.0)
        #expect(candles[0].high == 29500.5)
        #expect(candles[0].low == 28800.0)
        #expect(candles[0].close == 29250.1)
        #expect(candles[0].closeTime == 1609462799999)
    }

    @Test("Decodes multiple candles in order")
    func decodeMultipleKlines() throws {
        let json = Data("""
        [[1,"10","11","9","10.5","1",2,"x",1,"a","b","0"],
         [3,"10.5","12","10","11.8","2",4,"x",1,"a","b","0"]]
        """.utf8)

        let candles = try Kline.decode(from: json)

        #expect(candles.count == 2)
        #expect(candles[0].close == 10.5)
        #expect(candles[1].close == 11.8)
    }

    @Test("A malformed (too-short) kline row throws")
    func shortRowThrows() {
        let json = Data("[[1,2,3]]".utf8)
        #expect(throws: BinanceClient.ClientError.self) {
            try Kline.decode(from: json)
        }
    }

    @Test("Non-array klines payload throws")
    func nonArrayThrows() {
        let json = Data("{\"code\":-1121}".utf8)
        #expect(throws: BinanceClient.ClientError.self) {
            try Kline.decode(from: json)
        }
    }

    // MARK: - Ticker decoding (string numbers → Double)

    @Test("Decodes 24h ticker, parsing string numbers to Double")
    func decodeTicker() throws {
        let json = Data("""
        {"symbol":"BTCUSDT","lastPrice":"67000.50","priceChangePercent":"2.35",
         "highPrice":"68000.0","lowPrice":"66000.0","volume":"1234.5","quoteVolume":"82000000.0"}
        """.utf8)

        let ticker = try JSONDecoder().decode(Ticker24h.self, from: json)

        #expect(ticker.symbol == "BTCUSDT")
        #expect(ticker.lastPrice == 67000.50)
        #expect(ticker.priceChangePercent == 2.35)
        #expect(ticker.highPrice == 68000.0)
    }

    @Test("Non-numeric price field throws a decoding error")
    func tickerBadNumberThrows() {
        let json = Data("""
        {"symbol":"BTCUSDT","lastPrice":"oops","priceChangePercent":"0",
         "highPrice":"0","lowPrice":"0","volume":"0","quoteVolume":"0"}
        """.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Ticker24h.self, from: json)
        }
    }

    // MARK: - URL building

    @Test("klines URL includes path and sorted query items")
    func klinesURL() throws {
        let client = BinanceClient()
        let url = try client.makeURL(path: "/api/v3/klines", query: [
            "symbol": "BTCUSDT", "interval": "1h", "limit": "100",
        ])
        let s = url.absoluteString
        #expect(s.hasPrefix("https://api.binance.com/api/v3/klines?"))
        #expect(s.contains("symbol=BTCUSDT"))
        #expect(s.contains("interval=1h"))
        #expect(s.contains("limit=100"))
    }

    @Test("Custom base URL is honored")
    func customBaseURL() throws {
        let client = BinanceClient(baseURL: URL(string: "https://example.test")!)
        let url = try client.makeURL(path: "/api/v3/ticker/24hr", query: ["symbol": "ETHUSDT"])
        #expect(url.absoluteString == "https://example.test/api/v3/ticker/24hr?symbol=ETHUSDT")
    }

    @Test("Interval covers the common timeframes")
    func intervals() {
        #expect(BinanceClient.Interval.h1.rawValue == "1h")
        #expect(BinanceClient.Interval.allCases.contains(.d1))
    }
}
