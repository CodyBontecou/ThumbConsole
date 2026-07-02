import Foundation

struct PairingPayload: Codable {
    static let payloadType = "pocketpad-pair"

    let type: String
    let urls: [String]
    let pairingCode: String?
    let generatedAt: Int64

    init(urls: [String], pairingCode: String?) {
        self.type = Self.payloadType
        self.urls = urls
        self.pairingCode = pairingCode
        self.generatedAt = Date.currentMilliseconds
    }

    static func decode(from text: String) -> PairingPayload? {
        guard let data = text.data(using: .utf8),
              let payload = try? JSONDecoder().decode(PairingPayload.self, from: data),
              payload.type == Self.payloadType,
              !payload.urls.isEmpty
        else {
            return nil
        }

        return payload
    }
}
