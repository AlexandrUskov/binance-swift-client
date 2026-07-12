#if canImport(Darwin)
import Testing
import Foundation
@testable import BinanceClient

/// A `URLProtocol` stub that feeds a canned `(status, body)` to `URLSession` without touching the
/// network. This is what makes the client's injectable-`URLSession` seam provable end-to-end:
/// a real request goes through the same `session.data(from:)` path, but the bytes are ours.
private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var stub: (status: Int, body: Data) = (200, Data())

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.stub.status,
                                       httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}

    /// A `URLSession` whose traffic is intercepted by this stub.
    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }
}

/// End-to-end request→response tests through a mocked `URLSession` — proving the injectable seam,
/// not just the decoders. Serialized because the stub is shared process-wide. Darwin-only:
/// `URLProtocol` interception isn't reliable on Linux's swift-corelibs-foundation.
@Suite("BinanceClient network (mocked URLSession)", .serialized)
struct BinanceClientNetworkTests {

    @Test("ticker24h parses a stubbed 200 response end-to-end")
    func mockedTickerRoundTrip() async throws {
        StubURLProtocol.stub = (200, Data("""
        {"symbol":"BTCUSDT","lastPrice":"67000.50","priceChangePercent":"2.35",
         "highPrice":"68000.0","lowPrice":"66000.0","volume":"1234.5","quoteVolume":"82000000.0"}
        """.utf8))
        let client = BinanceClient(baseURL: URL(string: "https://mock.test")!,
                                   session: StubURLProtocol.makeSession())

        let ticker = try await client.ticker24h(symbol: "BTCUSDT")

        #expect(ticker.symbol == "BTCUSDT")
        #expect(ticker.lastPrice == 67000.50)
        #expect(ticker.priceChangePercent == 2.35)
    }

    @Test("A non-2xx response surfaces ClientError.http(status:)")
    func mockedHTTPErrorMapped() async {
        StubURLProtocol.stub = (429, Data("{}".utf8))
        let client = BinanceClient(baseURL: URL(string: "https://mock.test")!,
                                   session: StubURLProtocol.makeSession())

        await #expect(throws: BinanceClient.ClientError.http(status: 429)) {
            _ = try await client.ticker24h(symbol: "BTCUSDT")
        }
    }
}
#endif
