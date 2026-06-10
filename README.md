# LocupomLearn

Skeleton iOS app for personal lyric listening practice, inspired by the core loop of LingoClip:

1. Add a YouTube URL or video ID.
2. Paste the lyrics.
3. Generate lyric lines.
4. Mark start/end times while listening.
5. Practice each line by listening, typing, checking, asking for hints, or revealing the answer.

You can also open the `Tendencias` tab, add a YouTube Data API key, and load popular Music-category videos by region.

## Project

- App name: `LocupomLearn`
- Platform: iOS 17+
- UI: SwiftUI
- YouTube playback: `WKWebView` + YouTube IFrame Player API
- YouTube trends: YouTube Data API `videos.list` with `chart=mostPopular` and `videoCategoryId=10`
- Storage: local JSON in the app documents directory

## Run

Open `LocupomLearn.xcodeproj` in Xcode, select the `LocupomLearn` scheme, then run on an iPhone simulator or your own device.

From the terminal:

```sh
xcodebuild -project LocupomLearn.xcodeproj -scheme LocupomLearn -destination 'generic/platform=iOS Simulator' build
```

## Current Scope

The scaffold intentionally keeps YouTube embedded and visible. It does not download audio/video, separate audio from video, hide the player, or provide background playback.

Trending videos require your own YouTube Data API key. The key is stored locally through `UserDefaults` for this personal prototype.

## Next Good Steps

- Add import/export for song JSON files.
- Improve the timestamp editor with waveform-like shortcuts.
- Add shuffled practice, weak-line review, and per-line stats.
- Add a real app icon.
- Add unit tests for matching and YouTube URL parsing.
