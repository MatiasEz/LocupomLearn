import Foundation

enum YouTubeURLParser {
    static func videoID(from rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if isLikelyVideoID(trimmed) {
            return trimmed
        }

        guard let url = URL(string: trimmed) else {
            return nil
        }

        let host = (url.host() ?? "").lowercased()
        let pathComponents = url.pathComponents

        if host.contains("youtu.be") {
            return cleanedVideoID(pathComponents.dropFirst().first)
        }

        guard host.contains("youtube.com") || host.contains("youtube-nocookie.com") else {
            return nil
        }

        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        if let videoID = queryItems?.first(where: { $0.name == "v" })?.value {
            return cleanedVideoID(videoID)
        }

        let supportedPathMarkers = ["embed", "shorts", "live"]
        for marker in supportedPathMarkers {
            if let markerIndex = pathComponents.firstIndex(of: marker) {
                let nextIndex = pathComponents.index(after: markerIndex)
                if pathComponents.indices.contains(nextIndex) {
                    return cleanedVideoID(pathComponents[nextIndex])
                }
            }
        }

        return nil
    }

    private static func cleanedVideoID(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value
            .components(separatedBy: CharacterSet(charactersIn: "?&#/"))
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let cleaned, isLikelyVideoID(cleaned) else {
            return nil
        }

        return cleaned
    }

    private static func isLikelyVideoID(_ value: String) -> Bool {
        value.range(of: "^[A-Za-z0-9_-]{6,20}$", options: .regularExpression) != nil
    }
}
