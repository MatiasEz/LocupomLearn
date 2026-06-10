import Foundation
import SwiftUI
import WebKit

struct YouTubePlayerCommand: Equatable, Identifiable {
    let id = UUID()
    let script: String

    static func play() -> YouTubePlayerCommand {
        YouTubePlayerCommand(script: "window.LocupomPlayer.play();")
    }

    static func pause() -> YouTubePlayerCommand {
        YouTubePlayerCommand(script: "window.LocupomPlayer.pause();")
    }

    static func seek(to time: TimeInterval) -> YouTubePlayerCommand {
        YouTubePlayerCommand(script: "window.LocupomPlayer.seek(\(jsNumber(time)));")
    }

    static func setRate(_ rate: Double) -> YouTubePlayerCommand {
        YouTubePlayerCommand(script: "window.LocupomPlayer.setRate(\(jsNumber(rate)));")
    }

    static func playSegment(start: TimeInterval, end: TimeInterval) -> YouTubePlayerCommand {
        YouTubePlayerCommand(script: "window.LocupomPlayer.playSegment(\(jsNumber(start)), \(jsNumber(end)));")
    }

    private static func jsNumber(_ value: Double) -> String {
        String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

enum YouTubePlayerEvent {
    case ready
    case state(Int)
    case time(TimeInterval)
    case segmentEnded
    case error(Int)
}

struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    @Binding var command: YouTubePlayerCommand?
    var onEvent: (YouTubePlayerEvent) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "locupom")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.loadHTMLString(makeHTML(videoID: videoID), baseURL: URL(string: "https://locupomlyrics.local"))
        context.coordinator.loadedVideoID = videoID

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self

        if context.coordinator.loadedVideoID != videoID {
            context.coordinator.loadedVideoID = videoID
            context.coordinator.lastCommandID = nil
            webView.loadHTMLString(makeHTML(videoID: videoID), baseURL: URL(string: "https://locupomlyrics.local"))
        }

        guard let command, context.coordinator.lastCommandID != command.id else {
            return
        }

        context.coordinator.lastCommandID = command.id
        webView.evaluateJavaScript(command.script)
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: YouTubePlayerView
        var loadedVideoID: String?
        var lastCommandID: UUID?

        init(parent: YouTubePlayerView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard
                let body = message.body as? [String: Any],
                let type = body["type"] as? String
            else {
                return
            }

            let payload = body["payload"] as? [String: Any]

            switch type {
            case "ready":
                parent.onEvent(.ready)
            case "state":
                let value = payload?["value"] as? Int ?? 0
                parent.onEvent(.state(value))
            case "time":
                let current = payload?["current"] as? Double ?? 0
                parent.onEvent(.time(current))
            case "segmentEnded":
                parent.onEvent(.segmentEnded)
            case "error":
                let code = payload?["code"] as? Int ?? -1
                parent.onEvent(.error(code))
            default:
                break
            }
        }
    }

    private func makeHTML(videoID: String) -> String {
        let escapedVideoID = videoID
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")

        return """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
          <meta name="referrer" content="strict-origin-when-cross-origin">
          <style>
            html, body, #player {
              width: 100%;
              height: 100%;
              margin: 0;
              padding: 0;
              overflow: hidden;
              background: #050505;
            }
          </style>
        </head>
        <body>
          <div id="player"></div>
          <script>
            var player = null;
            var playerReady = false;
            var timeTimer = null;
            var segmentEnd = null;

            function send(type, payload) {
              try {
                window.webkit.messageHandlers.locupom.postMessage({
                  type: type,
                  payload: payload || {}
                });
              } catch (error) {}
            }

            function onYouTubeIframeAPIReady() {
              player = new YT.Player('player', {
                width: '100%',
                height: '100%',
                videoId: '\(escapedVideoID)',
                playerVars: {
                  playsinline: 1,
                  controls: 1,
                  rel: 0,
                  enablejsapi: 1,
                  origin: 'https://locupomlyrics.local'
                },
                events: {
                  onReady: function() {
                    playerReady = true;
                    send('ready');
                  },
                  onStateChange: onPlayerStateChange,
                  onError: function(event) {
                    send('error', { code: event.data });
                  }
                }
              });
            }

            function onPlayerStateChange(event) {
              send('state', { value: event.data });

              if (event.data === YT.PlayerState.PLAYING) {
                startTimeTimer();
              } else {
                stopTimeTimer();
              }
            }

            function startTimeTimer() {
              stopTimeTimer();
              timeTimer = setInterval(function() {
                if (!playerReady || !player || !player.getCurrentTime) { return; }
                var current = player.getCurrentTime();
                send('time', { current: current });

                if (segmentEnd !== null && current >= segmentEnd) {
                  player.pauseVideo();
                  segmentEnd = null;
                  send('segmentEnded');
                }
              }, 200);
            }

            function stopTimeTimer() {
              if (timeTimer !== null) {
                clearInterval(timeTimer);
                timeTimer = null;
              }
            }

            window.LocupomPlayer = {
              play: function() {
                if (!playerReady) { return; }
                player.playVideo();
              },
              pause: function() {
                if (!playerReady) { return; }
                segmentEnd = null;
                player.pauseVideo();
              },
              seek: function(time) {
                if (!playerReady) { return; }
                player.seekTo(time, true);
              },
              setRate: function(rate) {
                if (!playerReady) { return; }
                player.setPlaybackRate(rate);
              },
              playSegment: function(start, end) {
                if (!playerReady) { return; }
                segmentEnd = end;
                player.seekTo(start, true);
                player.playVideo();
              }
            };

            var tag = document.createElement('script');
            tag.src = "https://www.youtube.com/iframe_api";
            var firstScriptTag = document.getElementsByTagName('script')[0];
            firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
          </script>
        </body>
        </html>
        """
    }
}
