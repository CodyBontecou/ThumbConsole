import Foundation

struct PairingPayload: Codable {
    static let payloadType = "pocketpad-pair"
    static let defaultServiceType = "_pocketpad._tcp"
    static let defaultServiceDomain = "local"

    let type: String
    let urls: [String]
    let pairingCode: String?
    let serviceName: String?
    let serviceType: String?
    let serviceDomain: String?
    let serverID: String?
    let generatedAt: Int64

    init(
        urls: [String],
        pairingCode: String?,
        serviceName: String? = nil,
        serviceType: String? = Self.defaultServiceType,
        serviceDomain: String? = Self.defaultServiceDomain,
        serverID: String? = nil
    ) {
        self.type = Self.payloadType
        self.urls = urls
        self.pairingCode = pairingCode
        self.serviceName = serviceName?.trimmedNilIfEmpty
        self.serviceType = serviceType?.trimmedNilIfEmpty
        self.serviceDomain = serviceDomain?.trimmedNilIfEmpty
        self.serverID = serverID?.trimmedNilIfEmpty
        self.generatedAt = Date.currentMilliseconds
    }

    var hasServiceDiscoveryInfo: Bool {
        serviceName?.trimmedNilIfEmpty != nil || serverID?.trimmedNilIfEmpty != nil
    }

    var normalizedServiceType: String {
        (serviceType?.trimmedNilIfEmpty ?? Self.defaultServiceType).trimmingTrailingDots
    }

    var normalizedServiceDomain: String {
        (serviceDomain?.trimmedNilIfEmpty ?? Self.defaultServiceDomain).trimmingTrailingDots
    }

    static func decode(from text: String) -> PairingPayload? {
        guard let data = text.data(using: .utf8),
              let payload = try? JSONDecoder().decode(PairingPayload.self, from: data),
              payload.type == Self.payloadType,
              (!payload.urls.isEmpty || payload.hasServiceDiscoveryInfo)
        else {
            return nil
        }

        return payload
    }
}

private extension String {
    var trimmedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var trimmingTrailingDots: String {
        trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
}
