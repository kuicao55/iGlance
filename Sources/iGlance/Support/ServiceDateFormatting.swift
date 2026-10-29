import Foundation

enum ServiceDateFormatting {
    private static let formatters: [ISO8601DateFormatter] = {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]

        return [fractional, plain]
    }()

    static func parse(_ value: String) -> Date? {
        for formatter in formatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }
}

enum ServiceJSON {
    /// Decoder for status/memory payloads. Timestamps are RFC3339.
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let date = ServiceDateFormatting.parse(raw) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Expected an RFC3339 timestamp, got '\(raw)'"
                )
            }
            return date
        }
        return decoder
    }()
}
