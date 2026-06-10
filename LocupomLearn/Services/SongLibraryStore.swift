import Foundation

@MainActor
final class SongLibraryStore: ObservableObject {
    @Published private(set) var songs: [Song] = []

    private let fileManager: FileManager
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        load()
    }

    func upsert(_ song: Song) {
        if let existingIndex = songs.firstIndex(where: { $0.id == song.id }) {
            songs[existingIndex] = song
        } else {
            songs.insert(song, at: 0)
        }

        save()
    }

    func delete(_ song: Song) {
        songs.removeAll { $0.id == song.id }
        save()
    }

    func delete(at offsets: IndexSet) {
        songs.remove(atOffsets: offsets)
        save()
    }

    func recordAttempt(songID: UUID, wasCorrect: Bool) {
        guard let songIndex = songs.firstIndex(where: { $0.id == songID }) else {
            return
        }

        songs[songIndex].practiceStats.recordAttempt(wasCorrect: wasCorrect)
        songs[songIndex].updatedAt = Date()
        save()
    }

    func shiftTimings(songID: UUID, by offset: TimeInterval) {
        guard let songIndex = songs.firstIndex(where: { $0.id == songID }) else {
            return
        }

        songs[songIndex].lines = songs[songIndex].lines.map { line in
            let duration = max(0.5, line.endTime - line.startTime)
            let startTime = max(0, line.startTime + offset)
            let shiftedEnd = max(0, line.endTime + offset)

            return LyricLine(
                id: line.id,
                index: line.index,
                text: line.text,
                startTime: startTime,
                endTime: max(startTime + 0.5, shiftedEnd, startTime + duration)
            )
        }
        songs[songIndex].updatedAt = Date()
        save()
    }

    func song(withID id: UUID) -> Song? {
        songs.first { $0.id == id }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: libraryURL)
            songs = try decoder.decode([Song].self, from: data)
        } catch {
            songs = []
        }
    }

    private func save() {
        do {
            let directory = libraryURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try encoder.encode(songs)
            try data.write(to: libraryURL, options: [.atomic])
        } catch {
            assertionFailure("Could not save song library: \(error)")
        }
    }

    private var libraryURL: URL {
        fileManager
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("locupom-lyrics-library.json")
    }
}

extension SongLibraryStore {
    static var preview: SongLibraryStore {
        let store = SongLibraryStore()
        store.songs = [
            Song(
                id: UUID(),
                title: "Demo line practice",
                artist: "Locupom",
                language: "English",
                youtubeURL: "https://www.youtube.com/watch?v=M7lc1UVf-VE",
                videoID: "M7lc1UVf-VE",
                lines: [
                    LyricLine(id: UUID(), index: 0, text: "This is a practice line", startTime: 0, endTime: 4),
                    LyricLine(id: UUID(), index: 1, text: "Listen and type what you hear", startTime: 4, endTime: 8)
                ],
                createdAt: Date(),
                updatedAt: Date(),
                practiceStats: .empty
            )
        ]
        return store
    }
}
