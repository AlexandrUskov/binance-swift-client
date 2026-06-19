# BinanceClient

A tiny, dependency-free async Swift client for Binance's **public** market-data REST API —
no API key, no signing, runs anywhere (including CI).

Built with `async/await` and `URLSession`. Numbers Binance returns as strings are parsed to
`Double`; the positional-array `klines` payload is decoded by index.

```swift
import BinanceClient

let client = BinanceClient()

// 24h stats
let btc = try await client.ticker24h(symbol: "BTCUSDT")
print(btc.lastPrice, btc.priceChangePercent)   // 67000.5  2.35

// OHLCV candles
let candles = try await client.klines(symbol: "ETHUSDT", interval: .h1, limit: 100)
print(candles.last?.close ?? 0)
```

## Why it's more than a `URLSession` wrapper

Real exchange APIs are messier than they look, and the handling here is the point:

- **String numbers → `Double`.** Binance encodes prices as JSON strings (`"67000.50"`); `Ticker24h`
  parses them during decoding and fails loudly on garbage rather than silently returning `0`.
- **Positional-array decoding.** `klines` come back as `[[openTime, "open", "high", "low", "close", …]]`
  — arrays, not objects. `Kline.decode` reads them by index and tolerates both string and numeric JSON.
- **Typed errors** (`invalidURL`, `http(status:)`, `decoding`, `transport`) and non-2xx detection.
- **Injectable `URLSession` and base URL**, so it's testable and mockable without hitting the network.

## API

```swift
func ticker24h(symbol: String) async throws -> Ticker24h
func klines(symbol: String, interval: Interval, limit: Int = 100) async throws -> [Kline]
```

`Interval`: `.m1 .m5 .m15 .h1 .h4 .d1 .w1`

## Install (Swift Package Manager)

```swift
.package(url: "https://github.com/OleksandrUskov/binance-swift-client.git", from: "1.0.0")
```

## Test

```bash
swift test
```

The test suite is **offline and deterministic** — it exercises decoding (string-number parsing,
positional-array klines, malformed-row handling) and URL building against embedded fixtures, so it
needs no network and never flakes.

## Background

Extracted and cleaned from **Cursaris**, a multi-exchange crypto-futures terminal that integrates
11 exchanges. This is the public, no-auth slice of that exchange layer.

## License

MIT
