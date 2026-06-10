import Foundation

@MainActor
final class YouTubeAPISettings: ObservableObject {
    @Published var apiKey: String {
        didSet {
            userDefaults.set(apiKey, forKey: apiKeyKey)
        }
    }

    @Published var regionCode: String {
        didSet {
            userDefaults.set(regionCode, forKey: regionCodeKey)
        }
    }

    static let supportedRegions = [
        Region(code: "AR", name: "Argentina"),
        Region(code: "US", name: "United States"),
        Region(code: "MX", name: "Mexico"),
        Region(code: "ES", name: "Spain"),
        Region(code: "BR", name: "Brazil"),
        Region(code: "GB", name: "United Kingdom"),
        Region(code: "JP", name: "Japan"),
        Region(code: "KR", name: "South Korea")
    ]

    private let userDefaults: UserDefaults
    private let apiKeyKey = "youtubeDataAPIKey"
    private let regionCodeKey = "youtubeTrendingRegionCode"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let savedAPIKey = userDefaults.string(forKey: apiKeyKey) ?? ""
        apiKey = savedAPIKey
        regionCode = userDefaults.string(forKey: regionCodeKey) ?? "AR"
    }
}

extension YouTubeAPISettings {
    struct Region: Identifiable, Equatable {
        var id: String { code }
        let code: String
        let name: String
    }
}
