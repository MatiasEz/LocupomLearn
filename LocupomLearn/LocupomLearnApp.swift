import SwiftUI

@main
struct LocupomLearnApp: App {
    @StateObject private var libraryStore = SongLibraryStore()
    @StateObject private var youtubeSettings = YouTubeAPISettings()
    @StateObject private var learningProgress = LearningProgressStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(libraryStore)
                .environmentObject(youtubeSettings)
                .environmentObject(learningProgress)
        }
    }
}
