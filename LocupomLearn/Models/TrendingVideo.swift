import Foundation

struct TrendingVideo: Identifiable, Equatable {
    let id: String
    let title: String
    let channelTitle: String
    let thumbnailURL: URL?
    let publishedAt: Date?

    var youtubeURL: String {
        "https://www.youtube.com/watch?v=\(id)"
    }

    var editorSeed: SongEditorSeed {
        SongEditorSeed(
            title: title,
            artist: channelTitle,
            language: "English",
            youtubeInput: youtubeURL
        )
    }
}

struct SongEditorSeed: Equatable {
    let title: String
    let artist: String
    let language: String
    let youtubeInput: String
}
