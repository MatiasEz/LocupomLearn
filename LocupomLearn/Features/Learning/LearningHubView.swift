import AVFoundation
import Speech
import SwiftUI

struct LearningHubView: View {
    @EnvironmentObject private var learningProgress: LearningProgressStore
    @State private var path: [LearningModule] = []

    private var recommendedModule: LearningModule {
        .daily
    }

    private var courseProgress: Double {
        if learningProgress.totalAttempts == 0 {
            return 0.35
        }

        return min(max(learningProgress.overallAccuracy, 0.18), 1)
    }

    private var continueTopicTitle: String {
        GrammarTopic.deck(for: selectedCEFRLevel.fallbackLearningLevel).first?.title ?? "English basics"
    }

    private var selectedCEFRLevel: TopicCEFRLevel {
        TopicCEFRLevel(rawValue: learningProgress.cefrLevelCode) ?? TopicCEFRLevel(profileLevel: learningProgress.profile.level)
    }

    private var cefrLevelBinding: Binding<TopicCEFRLevel> {
        Binding(
            get: { selectedCEFRLevel },
            set: { learningProgress.updateCEFRLevel($0.rawValue) }
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                LocupomLearningBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        LocupomHomeHeroCard(
                            level: learningProgress.profile.level,
                            dailyGoalMinutes: learningProgress.profile.dailyGoalMinutes,
                            startAction: {
                                path.append(recommendedModule)
                            },
                            vocabularyAction: {
                                path.append(.explorer)
                            }
                        )

                        TopicLevelSelectorCard(selectedLevel: cefrLevelBinding)

                        LocupomPracticeShortcutsCard { module in
                            path.append(module)
                        }

                        LocupomContinueLearningCard(
                            topicTitle: continueTopicTitle,
                            progress: courseProgress,
                            action: {
                                path.append(.topics)
                            }
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LearningModule.self) { module in
                module.destination
            }
        }
    }
}

struct LearningMusicTabView: View {
    var body: some View {
        NavigationStack {
            SongsLearningView()
        }
    }
}

struct LearningTopicsTabView: View {
    var body: some View {
        NavigationStack {
            TopicsPracticeView(showsCloseButton: false, hidesTabBar: false)
        }
    }
}

struct LearningPracticeTabView: View {
    @State private var path: [LearningModule] = []

    private let modules: [LearningModule] = [
        .translate,
        .writing,
        .listening,
        .reading,
        .speaking,
        .sentences,
        .grammar
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                LocupomPracticeBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Ejercicios")
                                .font(.system(size: 25, weight: .black, design: .rounded))
                                .foregroundStyle(LocupomTheme.ink)
                                .lineLimit(1)

                            VStack(spacing: 12) {
                                ForEach(modules) { module in
                                    NavigationLink(value: module) {
                                        LocupomPracticeExerciseRow(module: module)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 18)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LearningModule.self) { module in
                module.destination
            }
        }
    }
}

struct LearningProgressTabView: View {
    @EnvironmentObject private var store: SongLibraryStore
    @EnvironmentObject private var learningProgress: LearningProgressStore

    var body: some View {
        NavigationStack {
            ZStack {
                LocupomLearningBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        LearningProgressPanel()
                        LearningErrorBankPanel()
                        LearningSourcesSummaryCard(songCount: store.songs.count)
                    }
                    .padding()
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

enum LocupomTheme {
    static let ink = Color(.label)
    static let muted = Color(.secondaryLabel)
    static let primary = Color(red: 0.20, green: 0.36, blue: 0.98)
    static let secondary = Color(red: 0.47, green: 0.35, blue: 0.98)
    static let mint = Color(red: 0.38, green: 0.78, blue: 0.73)
    static let surface = Color(.secondarySystemBackground)
    static let elevatedSurface = Color(.systemBackground)
    static let softSurface = Color(.tertiarySystemBackground)
}

struct LocupomLearningBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topLeading) {
            LocupomDotPattern()
                .foregroundStyle(LocupomTheme.secondary.opacity(0.25))
                .frame(width: 120, height: 90)
                .padding(.top, 26)
                .padding(.leading, 18)
        }
    }

    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.04, green: 0.06, blue: 0.13),
                Color(red: 0.08, green: 0.09, blue: 0.20),
                Color(red: 0.03, green: 0.08, blue: 0.11)
            ]
        }

        return [
            Color(red: 0.97, green: 0.98, blue: 1.0),
            Color(red: 0.93, green: 0.95, blue: 1.0),
            Color(red: 0.98, green: 0.99, blue: 1.0)
        ]
    }
}

struct LocupomPracticeBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .bottomTrailing) {
            RadialGradient(
                colors: [
                    Color(red: 0.67, green: 0.91, blue: 0.88).opacity(0.48),
                    Color(red: 0.67, green: 0.91, blue: 0.88).opacity(0)
                ],
                center: .center,
                startRadius: 10,
                endRadius: 240
            )
            .frame(width: 320, height: 320)
            .offset(x: 94, y: 48)
            .allowsHitTesting(false)
        }
    }

    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.04, green: 0.06, blue: 0.13),
                Color(red: 0.07, green: 0.08, blue: 0.18),
                Color(red: 0.03, green: 0.09, blue: 0.11)
            ]
        }

        return [
            Color(red: 0.99, green: 0.99, blue: 1.0),
            Color(red: 0.95, green: 0.97, blue: 1.0),
            Color(red: 0.98, green: 1.0, blue: 1.0)
        ]
    }
}

private struct LocupomDotPattern: View {
    private let columns = Array(repeating: GridItem(.fixed(10), spacing: 8), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(0..<36, id: \.self) { _ in
                Circle()
                    .frame(width: 4, height: 4)
            }
        }
    }
}

private struct LocupomPracticeExerciseRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let module: LearningModule

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(iconBackground)

                Image(systemName: module.practiceListSystemImage)
                    .font(.system(size: 31, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(module.practiceAccent)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(module.practiceListTitle)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(LocupomTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(module.practiceListSubtitle)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(LocupomTheme.ink.opacity(0.52))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Text(module.practiceListDuration)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(module.practiceAccent)
                .monospacedDigit()
                .lineLimit(1)
                .frame(minWidth: 50, alignment: .trailing)

            Image(systemName: "chevron.right")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(LocupomTheme.muted.opacity(0.72))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(LocupomTheme.surface.opacity(0.98), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(LocupomTheme.ink.opacity(0.08), lineWidth: 1)
        }
    }

    private var iconBackground: Color {
        colorScheme == .dark ? module.practiceAccent.opacity(0.18) : module.practiceIconBackground
    }
}

struct LocupomLogoMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28)
                .fill(
                    LinearGradient(
                        colors: [LocupomTheme.primary, LocupomTheme.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "globe.americas.fill")
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: LocupomTheme.primary.opacity(0.22), radius: 12, x: 0, y: 6)
    }
}

private struct LocupomHomeHeroCard: View {
    let level: LearningLevel
    let dailyGoalMinutes: Int
    let startAction: () -> Void
    let vocabularyAction: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Tu sesión\nde hoy")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(LocupomTheme.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.74)
                        .frame(maxWidth: 206, alignment: .leading)

                    HStack(spacing: 6) {
                        Text("\(dailyGoalMinutes) min")
                            .font(.system(size: 19, weight: .black, design: .rounded))
                            .foregroundStyle(LocupomTheme.secondary)

                        Text("para avanzar")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(LocupomTheme.ink.opacity(0.62))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack(alignment: .bottomTrailing) {
                    Ellipse()
                        .fill(LocupomTheme.secondary.opacity(0.10))
                        .frame(width: 86, height: 154)
                        .rotationEffect(.degrees(28))
                        .offset(x: -6, y: 24)

                    Ellipse()
                        .fill(LocupomTheme.primary.opacity(0.08))
                        .frame(width: 68, height: 132)
                        .rotationEffect(.degrees(-24))
                        .offset(x: -56, y: 28)

                    Image("Ajolote_Home")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 170)
                        .shadow(color: Color(red: 1.0, green: 0.76, blue: 0.18).opacity(0.24), radius: 16, x: 0, y: 9)
                        .offset(x: 15, y: 24)
                }
                .allowsHitTesting(false)
            }
            .frame(height: 214)

            Button(action: startAction) {
                HStack(spacing: 13) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 24, weight: .black))

                    Text("Empezar")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    LinearGradient(
                        colors: [LocupomTheme.primary, LocupomTheme.secondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 21, style: .continuous)
                )
                .shadow(color: LocupomTheme.primary.opacity(0.18), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(.plain)

            Button(action: vocabularyAction) {
                HStack(spacing: 14) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(LocupomTheme.secondary)
                        .frame(width: 50, height: 50)
                        .background(LocupomTheme.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Text("Explorar vocabulario")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(LocupomTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.80)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 21, weight: .black))
                        .foregroundStyle(LocupomTheme.secondary)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(LocupomTheme.elevatedSurface.opacity(0.88), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(LocupomTheme.primary.opacity(0.08), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            LocupomTheme.surface.opacity(0.98),
                            LocupomTheme.softSurface.opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(LocupomTheme.elevatedSurface.opacity(0.70), lineWidth: 1.4)
        }
        .shadow(color: LocupomTheme.primary.opacity(0.10), radius: 24, x: 0, y: 14)
    }
}

private struct LocupomHomeStatsCard: View {
    let streak: Int
    let xpScore: Int
    let dueReviews: Int

    var body: some View {
        HStack(spacing: 0) {
            LocupomHomeMetricColumn(
                title: "Racha",
                value: streakText,
                detail: streak > 0 ? "¡Sigue así!" : "Empieza hoy",
                systemImage: "flame.fill",
                tint: .orange
            )

            LocupomHomeDivider()

            LocupomHomeMetricColumn(
                title: "XP",
                value: "\(xpScore)",
                detail: "Puntos totales",
                systemImage: "star.fill",
                tint: LocupomTheme.secondary
            )

            LocupomHomeDivider()

            LocupomHomeMetricColumn(
                title: "Repaso",
                value: "\(dueReviews)",
                detail: "Pendientes",
                systemImage: "arrow.triangle.2.circlepath",
                tint: LocupomTheme.mint
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 18)
        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: LocupomTheme.primary.opacity(0.08), radius: 20, x: 0, y: 10)
    }

    private var streakText: String {
        streak == 1 ? "1 día" : "\(streak) días"
    }
}

private struct LocupomHomeDivider: View {
    var body: some View {
        Rectangle()
            .fill(LocupomTheme.ink.opacity(0.09))
            .frame(width: 1, height: 68)
    }
}

private struct LocupomHomeMetricColumn: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.13), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(LocupomTheme.ink.opacity(0.58))
                    .lineLimit(1)

                Text(value)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(detail)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(LocupomTheme.ink.opacity(0.50))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

private struct LocupomPracticeShortcutsCard: View {
    let openModule: (LearningModule) -> Void

    private let shortcuts: [LocupomHomeShortcut] = [
        LocupomHomeShortcut(title: "Mix", module: .daily, systemImage: "sparkles", tint: LocupomTheme.secondary),
        LocupomHomeShortcut(title: "Palabras", module: .vocabulary, systemImage: "quote.bubble.fill", tint: LocupomTheme.mint),
        LocupomHomeShortcut(title: "Oído", module: .listening, systemImage: "headphones", tint: .orange),
        LocupomHomeShortcut(title: "Voz", module: .speaking, systemImage: "mic.fill", tint: .pink)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Práctica a tu manera")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(LocupomTheme.ink)

                Spacer()

                Button {
                    openModule(.daily)
                } label: {
                    Text("Ver todo")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(LocupomTheme.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                ForEach(shortcuts) { shortcut in
                    Button {
                        openModule(shortcut.module)
                    } label: {
                        LocupomHomeShortcutTile(shortcut: shortcut)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: LocupomTheme.primary.opacity(0.07), radius: 18, x: 0, y: 10)
    }
}

private struct LocupomHomeShortcut: Identifiable {
    let title: String
    let module: LearningModule
    let systemImage: String
    let tint: Color

    var id: LearningModule { module }
}

private struct LocupomHomeShortcutTile: View {
    let shortcut: LocupomHomeShortcut

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: shortcut.systemImage)
                .font(.system(size: 25, weight: .black))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(shortcut.tint)
                .frame(width: 48, height: 48)
                .background(shortcut.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(shortcut.title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(LocupomTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 94)
        .background(LocupomTheme.elevatedSurface.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LocupomTheme.ink.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct LocupomContinueLearningCard: View {
    let topicTitle: String
    let progress: Double
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Seguir aprendiendo")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(LocupomTheme.ink)

            Button(action: action) {
                HStack(spacing: 16) {
                    Image(systemName: "book")
                        .font(.system(size: 31, weight: .bold))
                        .foregroundStyle(LocupomTheme.secondary)
                        .frame(width: 62, height: 62)
                        .background(
                            LinearGradient(
                                colors: [LocupomTheme.secondary.opacity(0.20), LocupomTheme.primary.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 7) {
                        Text(topicTitle)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(LocupomTheme.ink)
                            .lineLimit(1)

                        Text("Grammar")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(LocupomTheme.secondary)

                        HStack(spacing: 12) {
                            LocupomHomeProgressBar(progress: progress)

                            Text(progressText)
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(LocupomTheme.secondary)
                                .frame(width: 45, alignment: .trailing)
                        }
                    }

                    Spacer(minLength: 6)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 27, weight: .black))
                        .foregroundStyle(LocupomTheme.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: LocupomTheme.primary.opacity(0.07), radius: 18, x: 0, y: 10)
    }

    private var progressText: String {
        "\(Int((min(max(progress, 0), 1) * 100).rounded()))%"
    }
}

private struct LocupomHomeProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LocupomTheme.secondary.opacity(0.18))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [LocupomTheme.secondary, LocupomTheme.primary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(10, proxy.size.width * min(max(progress, 0), 1)))
            }
        }
        .frame(height: 8)
    }
}

private struct LocupomAvatarView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.83, green: 0.88, blue: 1), Color(red: 0.72, green: 0.78, blue: 1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(LocupomTheme.ink.opacity(0.86))
                .padding(size * 0.12)
        }
        .frame(width: size, height: size)
    }
}

private struct LocupomWelcomeCard: View {
    let level: LearningLevel
    let dailyGoalMinutes: Int

    var body: some View {
        HStack(spacing: 14) {
            LocupomAvatarView(size: 58)

            VStack(alignment: .leading, spacing: 4) {
                Text("Hi, Alex!")
                    .font(.headline)
                    .foregroundStyle(LocupomTheme.ink)

                Text("Ready for \(dailyGoalMinutes) minutes of English?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(LocupomTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: LocupomTheme.primary.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

private struct LocupomStatCard: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                Text(value)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(LocupomTheme.ink)
            }

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LocupomTheme.ink)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(LocupomTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: LocupomTheme.primary.opacity(0.07), radius: 14, x: 0, y: 8)
    }
}

private struct LocupomTodayPlanCard: View {
    let level: LearningLevel
    let dailyGoalMinutes: Int
    let streak: Int
    let xpScore: Int
    let dueReviews: Int
    let progress: Double
    let recommendedModule: LearningModule
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Plan de hoy")
                        .font(.title2.bold())
                        .foregroundStyle(LocupomTheme.ink)

                    Text("\(dailyGoalMinutes) min para avanzar en \(level.shortCode)")
                        .font(.subheadline)
                        .foregroundStyle(LocupomTheme.ink.opacity(0.62))
                }

                Spacer()
            }

            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(recommendedModule.tint.opacity(0.13))
                        .frame(width: 58, height: 58)

                    Image(systemName: recommendedModule.systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(recommendedModule.tint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendedModule.title)
                        .font(.headline)
                        .foregroundStyle(LocupomTheme.ink)
                        .lineLimit(1)

                    Text("\(recommendedModule.subtitle) · \(recommendedModule.duration)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            Button(action: action) {
                Label("Empezar ahora", systemImage: "play.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LocupomTheme.primary, in: Capsule())
            }
            .buttonStyle(.plain)

            ProgressView(value: progress)
                .tint(LocupomTheme.primary)
                .background(LocupomTheme.primary.opacity(0.12), in: Capsule())
        }
        .padding(18)
        .background(LocupomTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(LocupomTheme.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: LocupomTheme.primary.opacity(0.10), radius: 22, x: 0, y: 12)
    }
}

private struct LearningGoalSelectorCard: View {
    @Binding var selectedGoal: LearningGoal
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Modo de estudio")
                        .font(.headline)
                        .foregroundStyle(LocupomTheme.ink)

                    Text(detail.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(LocupomTheme.primary)
            }

            Picker("Modo de estudio", selection: $selectedGoal) {
                ForEach(LearningGoal.allCases) { goal in
                    Text(goal.title).tag(goal)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(14)
        .background(LocupomTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: LocupomTheme.primary.opacity(0.06), radius: 14, x: 0, y: 8)
    }
}

private struct HomeSectionHeader: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(LocupomTheme.ink)

            Text(detail)
                .font(.caption)
                .foregroundStyle(LocupomTheme.ink.opacity(0.56))
        }
        .padding(.top, 4)
    }
}

private struct PrimaryLearningPathCard: View {
    let module: LearningModule
    let stat: LearningModuleStat?
    let isRecommended: Bool
    let action: () -> Void

    private var attempts: Int {
        stat?.attempts ?? 0
    }

    private var progress: Double {
        attempts == 0 ? 0.16 : min(max(stat?.accuracy ?? 0, 0.12), 1)
    }

    private var stateText: String {
        attempts == 0 ? "Nuevo" : "\(Int((stat?.accuracy ?? 0) * 100))%"
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(module.tint.opacity(0.13))
                            .frame(width: 62, height: 62)

                        Image(systemName: module.systemImage)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(module.tint)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(module.title)
                                .font(.headline)
                                .foregroundStyle(LocupomTheme.ink)
                                .lineLimit(1)

                            if isRecommended {
                                Text("Sugerido")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(module.tint)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(module.tint.opacity(0.10), in: Capsule())
                            }
                        }

                        Text(module.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(module.tint)
                }

                HStack(spacing: 8) {
                    Text(module.duration)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(module.tint)

                    Text(stateText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Spacer()
                }

                ProgressView(value: progress)
                    .tint(module.tint)
            }
            .padding(16)
            .background(LocupomTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .shadow(color: module.tint.opacity(0.08), radius: 16, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }
}

private struct CompactLearningModuleCard: View {
    let module: LearningModule
    let stat: LearningModuleStat?
    let isRecommended: Bool

    private var attempts: Int {
        stat?.attempts ?? 0
    }

    private var scoreText: String {
        attempts == 0 ? "nuevo" : "\(Int((stat?.accuracy ?? 0) * 100))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: module.systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(module.tint, in: RoundedRectangle(cornerRadius: 10))

                Spacer()

                if isRecommended {
                    Circle()
                        .fill(module.tint)
                        .frame(width: 8, height: 8)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(module.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(LocupomTheme.ink)
                    .lineLimit(1)

                Text(module.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            HStack {
                Text(module.duration)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(module.tint)
                Spacer()
                Text(scoreText)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 134, alignment: .leading)
        .padding(14)
        .background(LocupomTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(module.tint.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct LocupomCourseCard: View {
    let title: String
    let subtitle: String
    let progress: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CURRENT COURSE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.78))

                    Text(title)
                        .font(.title3.bold())
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.86))
                }

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("\(Int(progress * 100))% Complete")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)

                        ProgressView(value: progress)
                            .tint(.white)
                            .background(.white.opacity(0.22), in: Capsule())
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.18))
                            .frame(width: 82, height: 82)

                        Image(systemName: "music.mic")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(18)
            .background(
                LinearGradient(
                    colors: [LocupomTheme.primary, LocupomTheme.secondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 20)
            )
            .shadow(color: LocupomTheme.primary.opacity(0.22), radius: 20, x: 0, y: 12)
        }
        .buttonStyle(.plain)
    }
}

private struct LocupomContinueLessonCard: View {
    let module: LearningModule
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LocupomTheme.primary.opacity(0.11))
                        .frame(width: 54, height: 54)

                    Image(systemName: module.systemImage)
                        .font(.title3)
                        .foregroundStyle(LocupomTheme.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Continue Lesson")
                        .font(.headline)
                        .foregroundStyle(LocupomTheme.ink)
                    Text("\(module.homeTitle) · \(module.duration)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(LocupomTheme.primary)
            }
            .padding(16)
            .background(LocupomTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .shadow(color: LocupomTheme.primary.opacity(0.08), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }
}

private struct VocabularyPreviewItem: Identifiable {
    let id = UUID()
    let word: String
    let detail: String
    let systemImage: String
    let tint: Color
    let isDone: Bool
}

private struct LocupomVocabularyReviewCard: View {
    let items: [VocabularyPreviewItem]
    let dueReviews: Int
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Vocabulary Review")
                    .font(.headline)
                    .foregroundStyle(LocupomTheme.ink)

                Spacer()

                Button("See all", action: action)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LocupomTheme.primary)
            }

            HStack(spacing: 10) {
                ForEach(items.prefix(3)) { item in
                    LocupomVocabularyMiniCard(item: item)
                }
            }

            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(LocupomTheme.secondary)
                        .frame(width: 34, height: 34)
                        .background(LocupomTheme.secondary.opacity(0.10), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(dueReviews > 0 ? "Review \(dueReviews) words" : "Review saved words")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(LocupomTheme.ink)
                        Text("Practice to strengthen your memory.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(LocupomTheme.softSurface, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(LocupomTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: LocupomTheme.primary.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

private struct LocupomTopicsPreviewCard: View {
    let level: LearningLevel
    let topics: [GrammarTopic]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Topics")
                            .font(.headline)
                            .foregroundStyle(LocupomTheme.ink)
                        Text("\(level.shortCode) grammar map")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "map.fill")
                        .font(.title3)
                        .foregroundStyle(LocupomTheme.primary)
                        .frame(width: 42, height: 42)
                        .background(LocupomTheme.primary.opacity(0.10), in: Circle())
                }

                VStack(spacing: 8) {
                    ForEach(topics) { topic in
                        HStack(spacing: 10) {
                            Image(systemName: topic.systemImage)
                                .foregroundStyle(topic.tint)
                                .frame(width: 30, height: 30)
                                .background(topic.tint.opacity(0.12), in: Circle())

                            Text(topic.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(LocupomTheme.ink)
                                .lineLimit(1)

                            Spacer()

                            Text(topic.level.shortCode)
                                .font(.caption2.bold())
                                .foregroundStyle(topic.tint)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(topic.tint.opacity(0.10), in: Capsule())
                        }
                    }
                }
            }
            .padding(16)
            .background(LocupomTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .shadow(color: LocupomTheme.primary.opacity(0.08), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }
}

private struct LocupomVocabularyMiniCard: View {
    let item: VocabularyPreviewItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: item.systemImage)
                    .font(.title3)
                    .foregroundStyle(item.tint)

                Spacer()

                Image(systemName: item.isDone ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath.circle.fill")
                    .font(.caption)
                    .foregroundStyle(item.isDone ? LocupomTheme.mint : LocupomTheme.primary)
            }

            Text(item.word)
                .font(.caption.weight(.bold))
                .foregroundStyle(LocupomTheme.ink)
                .lineLimit(1)

            Text(item.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(12)
        .background(item.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct DailyRoutinePanel: View {
    let songCount: Int
    let dueReviews: Int
    let streak: Int
    let dailyGoalMinutes: Int
    let adaptiveMessage: String
    let recommendedModule: LearningModule
    let startAction: () -> Void
    let quickAction: () -> Void

    @State private var isBreathing = false

    private var phases: [LearningSessionPhase] {
        LearningSessionPhase.today(recommendedModule: recommendedModule, dueReviews: dueReviews)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tu practica de hoy")
                        .font(.title2.bold())
                    Text("Arranca por \(recommendedModule.title.lowercased()) y cambia de ritmo antes de cansarte.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(recommendedModule.tint.opacity(isBreathing ? 0.22 : 0.08))
                        .frame(width: 56, height: 56)
                        .scaleEffect(isBreathing ? 1.08 : 0.94)

                    Image(systemName: recommendedModule.systemImage)
                        .font(.title2)
                        .foregroundStyle(recommendedModule.tint)
                }
            }

            SessionRhythmStrip(phases: phases)

            HStack(spacing: 10) {
                Button(action: startAction) {
                    Label("Rutina guiada", systemImage: "calendar")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: quickAction) {
                    Label("Ir a \(recommendedModule.title.lowercased())", systemImage: recommendedModule.systemImage)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .buttonStyle(.bordered)
                .tint(recommendedModule.tint)
            }

            HStack(spacing: 0) {
                SummaryMetric(title: "Canciones", value: "\(songCount)", systemImage: "music.note")
                Divider()
                SummaryMetric(title: "Repasos", value: "\(dueReviews)", systemImage: "repeat")
                Divider()
                SummaryMetric(title: "Racha", value: "\(streak)d", systemImage: "flame")
                Divider()
                SummaryMetric(title: "Meta", value: "\(dailyGoalMinutes)m", systemImage: "timer")
            }

            Label(adaptiveMessage, systemImage: "sparkles")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(LocupomTheme.softSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(16)
        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }
}

private struct LearningSessionPhase: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color

    static func today(recommendedModule: LearningModule, dueReviews: Int) -> [LearningSessionPhase] {
        var result: [LearningSessionPhase] = []

        result.append(
            LearningSessionPhase(
                title: dueReviews > 0 ? "Repasar" : "Calentar",
                detail: dueReviews > 0 ? "\(dueReviews) reps" : "2 min",
                systemImage: dueReviews > 0 ? "repeat.circle" : "flame",
                tint: dueReviews > 0 ? .mint : .orange
            )
        )

        result.append(
            LearningSessionPhase(
                title: recommendedModule.title,
                detail: recommendedModule.duration,
                systemImage: recommendedModule.systemImage,
                tint: recommendedModule.tint
            )
        )

        result.append(
            LearningSessionPhase(
                title: "Refuerzo",
                detail: "errores",
                systemImage: "target",
                tint: .green
            )
        )

        result.append(
            LearningSessionPhase(
                title: "Cierre",
                detail: "resumen",
                systemImage: "checkmark.seal",
                tint: .blue
            )
        )

        return result
    }
}

private struct SessionRhythmStrip: View {
    let phases: [LearningSessionPhase]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(phases) { phase in
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: phase.systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(phase.tint)

                    Text(phase.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(phase.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(phase.tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

private struct SummaryMetric: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
            Text(value)
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
    }
}

private struct LearningStatPill: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color = .teal

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(LocupomTheme.softSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct LearningProgressSummaryCard: View {
    @EnvironmentObject private var learningProgress: LearningProgressStore
    @State private var isExpanded = false

    private var accuracy: Int {
        Int(learningProgress.overallAccuracy * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Progreso", detail: "\(learningProgress.totalAttempts) ejercicios")

            HStack(spacing: 0) {
                SummaryMetric(title: "Precision", value: "\(accuracy)%", systemImage: "target")
                Divider()
                SummaryMetric(title: "Palabras", value: "\(learningProgress.savedWords.count)", systemImage: "bookmark")
                Divider()
                SummaryMetric(title: "Frases", value: "\(learningProgress.cachedSentences.count)", systemImage: "text.quote")
            }
            .padding(4)
            .background(LocupomTheme.softSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Label(isExpanded ? "Ocultar detalle" : "Ver detalle por habilidad", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(LocupomTheme.primary)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(LearningModule.practiceStatsModules) { module in
                        ModuleProgressRow(
                            title: module.title,
                            tint: module.tint,
                            stat: learningProgress.stat(for: module.rawValue),
                            effectiveLevel: learningProgress.effectiveLevel(for: module.rawValue)
                        )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(LocupomTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: LocupomTheme.primary.opacity(0.06), radius: 14, x: 0, y: 8)
    }
}

private struct LearningSourcesSummaryCard: View {
    @State private var isExpanded = false
    let songCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "cloud.fill")
                    .font(.title3)
                    .foregroundStyle(LocupomTheme.primary)
                    .frame(width: 42, height: 42)
                    .background(LocupomTheme.primary.opacity(0.11), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Contenido")
                        .font(.headline)
                        .foregroundStyle(LocupomTheme.ink)

                    Text("\(songCount) canciones guardadas y APIs de apoyo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.title3)
                        .foregroundStyle(LocupomTheme.primary)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(LearningSource.allCases) { source in
                        HStack(spacing: 10) {
                            Image(systemName: source.systemImage)
                                .frame(width: 28, height: 28)
                                .foregroundStyle(LocupomTheme.primary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(LocupomTheme.ink)
                                Text(source.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()
                        }
                        .padding(10)
                        .background(LocupomTheme.softSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(LocupomTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: LocupomTheme.primary.opacity(0.06), radius: 14, x: 0, y: 8)
    }
}

private struct LearningProgressPanel: View {
    @EnvironmentObject private var learningProgress: LearningProgressStore

    private var accuracy: Int {
        Int(learningProgress.overallAccuracy * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Progreso", detail: "\(learningProgress.totalAttempts) ejercicios")

            HStack(spacing: 0) {
                SummaryMetric(title: "Precision", value: "\(accuracy)%", systemImage: "target")
                Divider()
                SummaryMetric(title: "Vocabulario", value: "\(learningProgress.savedWords.count)", systemImage: "bookmark")
                Divider()
                SummaryMetric(title: "Cache", value: "\(learningProgress.cachedSentences.count)", systemImage: "externaldrive")
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(LearningModule.practiceStatsModules) { module in
                    ModuleProgressRow(
                        title: module.title,
                        tint: module.tint,
                        stat: learningProgress.stat(for: module.rawValue),
                        effectiveLevel: learningProgress.effectiveLevel(for: module.rawValue)
                    )
                }
            }
        }
        .padding(14)
        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct ModuleProgressRow: View {
    let title: String
    let tint: Color
    let stat: LearningModuleStat?
    let effectiveLevel: LearningLevel

    private var attempts: Int {
        stat?.attempts ?? 0
    }

    private var accuracy: Double {
        stat?.accuracy ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(attempts == 0 ? "sin datos" : "\(Int(accuracy * 100))% · \(effectiveLevel.title)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: attempts == 0 ? 0 : accuracy)
                .tint(tint)
        }
    }
}

private struct LearningErrorBankPanel: View {
    @EnvironmentObject private var learningProgress: LearningProgressStore

    private var errors: [LearningErrorPattern] {
        learningProgress.topErrors(limit: 4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Banco de errores", detail: errors.isEmpty ? "sin patrones" : "\(errors.count) activos")

            if errors.isEmpty {
                Label("Cuando falles una palabra, frase o correccion, la guardo aca para reutilizarla en ejercicios.", systemImage: "tray")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(LocupomTheme.softSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(errors) { error in
                        LearningErrorRow(error: error)
                    }
                }
            }
        }
        .padding(14)
        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct LearningErrorRow: View {
    let error: LearningErrorPattern

    private var module: LearningModule? {
        LearningModule(rawValue: error.module)
    }

    private var tint: Color {
        module?.tint ?? .teal
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: module?.systemImage ?? "exclamationmark.circle")
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(error.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Spacer()

                    Text("\(max(error.count - error.resolvedCount, 1))x")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(tint)
                }

                Text(error.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                ProgressView(value: error.mastery)
                    .tint(tint)
            }
        }
        .padding(10)
        .background(LocupomTheme.softSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SectionHeader: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(title)
                .font(.headline)

            Spacer()

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct LearningModuleCard: View {
    let module: LearningModule
    let stat: LearningModuleStat?
    let isRecommended: Bool

    private var attempts: Int {
        stat?.attempts ?? 0
    }

    private var accuracy: Double {
        stat?.accuracy ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: module.systemImage)
                    .font(.headline)
                    .frame(width: 34, height: 34)
                    .foregroundStyle(.white)
                    .background(module.tint, in: Circle())

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if isRecommended {
                        Text("Ahora")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(module.tint)
                    }

                    Text(module.duration)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(module.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(module.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Text(module.level)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(module.tint)
                Spacer()
                Text(attempts == 0 ? "nuevo" : "\(Int(accuracy * 100))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: attempts == 0 ? 0.12 : accuracy)
                .tint(module.tint)
        }
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
        .padding(14)
        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(module.tint)
                .frame(height: 4)
        }
    }
}

private struct LearningAPIRoadmap: View {
    let songCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "APIs activas", detail: "\(songCount) canciones guardadas")

            ForEach(LearningSource.allCases) { source in
                HStack(spacing: 10) {
                    Image(systemName: source.systemImage)
                        .frame(width: 28, height: 28)
                        .foregroundStyle(.tint)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.title)
                            .font(.subheadline.weight(.semibold))
                        Text(source.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()
                }
                .padding(12)
                .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }
}

private struct SongsLearningView: View {
    @EnvironmentObject private var store: SongLibraryStore
    @State private var isShowingEditor = false
    @State private var isShowingTrending = false

    private var recommendedSong: Song? {
        store.songs.min {
            songPriority($0) < songPriority($1)
        }
    }

    private var totalLines: Int {
        store.songs.reduce(0) { $0 + $1.lines.count }
    }

    private var practicedSongs: Int {
        store.songs.filter { $0.practiceStats.attempts > 0 }.count
    }

    var body: some View {
        ZStack {
            LocupomLearningBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    musicHeader

                    if store.songs.isEmpty {
                        musicEmptyState
                    } else {
                        if let recommendedSong {
                            NavigationLink {
                                PracticeView(songID: recommendedSong.id)
                            } label: {
                                SongSpotlightCard(song: recommendedSong)
                            }
                            .buttonStyle(.plain)
                        }

                        HStack(spacing: 0) {
                            SummaryMetric(title: "Canciones", value: "\(store.songs.count)", systemImage: "music.note")
                            Divider()
                            SummaryMetric(title: "Líneas", value: "\(totalLines)", systemImage: "text.quote")
                            Divider()
                            SummaryMetric(title: "Activas", value: "\(practicedSongs)", systemImage: "target")
                        }
                        .padding(6)
                        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                        SectionHeader(title: "Biblioteca", detail: "\(store.songs.count) canciones")

                        ForEach(store.songs) { song in
                            NavigationLink {
                                PracticeView(songID: song.id)
                            } label: {
                                SongPracticeRow(song: song, isRecommended: false)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingEditor) {
            SongEditorView(song: nil)
        }
        .sheet(isPresented: $isShowingTrending) {
            TrendingView()
        }
    }

    private var musicHeader: some View {
        HStack(spacing: 12) {
            LocupomLogoMark(size: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text("Música")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(LocupomTheme.ink)

                Text("\(store.songs.count) canciones")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(LocupomTheme.primary)
            }

            Spacer()

            Button {
                isShowingTrending = true
            } label: {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(LocupomTheme.primary)
                    .frame(width: 44, height: 44)
                    .background(LocupomTheme.surface.opacity(0.92), in: Circle())
            }
            .buttonStyle(.plain)

            Button {
                isShowingEditor = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(LocupomTheme.ink)
                    .frame(width: 44, height: 44)
                    .background(LocupomTheme.surface.opacity(0.92), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var musicEmptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(LocupomTheme.primary)
                .frame(width: 66, height: 66)
                .background(LocupomTheme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text("Sin canciones")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(LocupomTheme.ink)

                Text("Guardá una canción y queda lista para practicar.")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(LocupomTheme.ink.opacity(0.58))
            }

            Button {
                isShowingEditor = true
            } label: {
                Label("Crear canción", systemImage: "plus")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(
                            colors: [LocupomTheme.primary, LocupomTheme.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(LocupomTheme.ink.opacity(0.07), lineWidth: 1)
        }
    }

    private func songPriority(_ song: Song) -> Double {
        let accuracyPenalty = song.practiceStats.attempts == 0 ? 1 : 1 - song.practiceStats.accuracy
        let recencyPenalty: Double
        if let lastPracticedAt = song.practiceStats.lastPracticedAt {
            recencyPenalty = max(0, 1 - Date().timeIntervalSince(lastPracticedAt) / (3 * 24 * 60 * 60))
        } else {
            recencyPenalty = 0
        }
        return recencyPenalty - accuracyPenalty
    }
}

private struct SongSpotlightCard: View {
    let song: Song

    private var accuracyText: String {
        song.practiceStats.attempts == 0 ? "Nueva" : "\(Int(song.practiceStats.accuracy * 100))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(0.12))
                        .frame(width: 54, height: 54)

                    Image(systemName: "music.note.list")
                        .font(.title3)
                        .foregroundStyle(.teal)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Sugerida ahora")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.teal)
                    Text(song.displayTitle)
                        .font(.title3.bold())
                        .lineLimit(2)
                    Text(song.displaySubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }

            Text("Practica un tramo corto, mira contexto y deja que la app te mueva linea por linea.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                LearningStatPill(title: "Lineas", value: "\(song.lines.count)", systemImage: "text.quote")
                LearningStatPill(title: "Precision", value: accuracyText, systemImage: "target")
                LearningStatPill(title: "Modo", value: "Palabra", systemImage: "rectangle.and.pencil.and.ellipsis")
            }
        }
        .padding(16)
        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.teal)
                .frame(width: 4)
        }
    }
}

private struct SongPracticeRow: View {
    let song: Song
    let isRecommended: Bool

    private var accuracyValue: Double {
        song.practiceStats.attempts == 0 ? 0.12 : song.practiceStats.accuracy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(song.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if isRecommended {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.tint)
                }
            }

            Text(song.displaySubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 10) {
                Label("\(song.lines.count) lineas", systemImage: "text.quote")
                Label(song.practiceStats.attempts == 0 ? "sin practicar" : "\(Int(song.practiceStats.accuracy * 100))%", systemImage: "target")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            ProgressView(value: accuracyValue)
                .tint(.teal)
        }
        .padding(14)
        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct DailyRoutineView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SongLibraryStore
    @EnvironmentObject private var learningProgress: LearningProgressStore
    @State private var currentStepIndex = 0
    @State private var completedStepIndexes = Set<Int>()

    private var steps: [RoutineStep] {
        var result: [RoutineStep] = []

        if !learningProgress.dueVocabulary().isEmpty {
            result.append(RoutineStep(module: .review, detail: "Repasa lo que esta por olvidarse", focus: "Memoria"))
        }

        let topErrors = learningProgress.topErrors(limit: 3)
        if !topErrors.isEmpty {
            result.append(
                RoutineStep(
                    module: .sentences,
                    detail: "Repara \(topErrors.count) patrones del banco de errores",
                    focus: "Refuerzo"
                )
            )
        }

        result.append(
            RoutineStep(
                module: store.songs.isEmpty ? .explorer : .songs,
                detail: store.songs.isEmpty ? "Busca una palabra y guardala" : "Practica una cancion guardada",
                focus: store.songs.isEmpty ? "Descubrir" : "Musica"
            )
        )
        result.append(RoutineStep(module: .vocabulary, detail: "Calenta con palabras utiles", focus: "Vocabulario"))
        result.append(RoutineStep(module: .topics, detail: "Entende un tema de tu nivel", focus: "Topics"))
        result.append(RoutineStep(module: .sentences, detail: "Ordena frases reales", focus: "Estructura"))
        result.append(RoutineStep(module: .translate, detail: "Traduce una idea con tus palabras", focus: "Translate"))
        result.append(RoutineStep(module: .writing, detail: "Escribi y corregi un texto breve", focus: "Writing"))
        result.append(RoutineStep(module: .speaking, detail: "Cerra con pronunciacion", focus: "Voz"))

        return result
    }

    private var isComplete: Bool {
        currentStepIndex >= steps.count
    }

    private var nextStep: RoutineStep? {
        let nextIndex = currentStepIndex + 1
        guard steps.indices.contains(nextIndex) else { return nil }
        return steps[nextIndex]
    }

    private var routinePhases: [LearningSessionPhase] {
        steps.prefix(4).map { step in
            LearningSessionPhase(
                title: step.focus,
                detail: step.module.duration,
                systemImage: step.module.systemImage,
                tint: step.module.tint
            )
        }
    }

    var body: some View {
        ZStack {
            TranslatePracticeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ExerciseSessionTopBar(
                        title: "Rutina",
                        closeAction: { dismiss() }
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sesión de \(learningProgress.profile.dailyGoalMinutes) minutos")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(TranslateTheme.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)

                        Text("Pensada para \(learningProgress.profile.level.title.lowercased()): poca fricción, varias habilidades y repaso cuando toca.")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(TranslateTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    SessionRhythmStrip(phases: routinePhases)

                    if isComplete {
                        RoutineCompletionCard(
                            completedCount: completedStepIndexes.count,
                            totalCount: steps.count,
                            restartAction: restartSession
                        )
                    } else if steps.indices.contains(currentStepIndex) {
                        RoutineCurrentStepCard(
                            step: steps[currentStepIndex],
                            nextStep: nextStep,
                            completeAction: completeCurrentStep,
                            skipAction: skipCurrentStep
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Plan de hoy", detail: "Rutina")

                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            RoutineChecklistRow(
                                index: index,
                                step: step,
                                state: checklistState(for: index)
                            )
                        }
                    }
                }
                .padding(.horizontal, 26)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private func checklistState(for index: Int) -> RoutineChecklistState {
        if completedStepIndexes.contains(index) {
            return .done
        }

        if index == currentStepIndex, !isComplete {
            return .current
        }

        return .pending
    }

    private func completeCurrentStep() {
        guard steps.indices.contains(currentStepIndex) else { return }

        completedStepIndexes.insert(currentStepIndex)
        learningProgress.recordModule(steps[currentStepIndex].module.rawValue)
        currentStepIndex += 1
    }

    private func skipCurrentStep() {
        currentStepIndex += 1
    }

    private func restartSession() {
        currentStepIndex = 0
        completedStepIndexes = []
    }
}

private struct ReviewQueueView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var learningProgress: LearningProgressStore
    @State private var sessionWords: [SavedVocabularyItem] = []
    @State private var isAnswerVisible = false
    @State private var feedback: LearningFeedback?

    var body: some View {
        ZStack {
            TranslatePracticeBackground()

            if sessionWords.isEmpty {
                VStack(alignment: .leading, spacing: 24) {
                    ExerciseSessionTopBar(
                        title: "Repaso",
                        closeAction: { dismiss() }
                    )

                    VStack(alignment: .leading, spacing: 14) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(TranslateTheme.mint)
                            .frame(width: 66, height: 66)
                            .background(TranslateTheme.mint.opacity(0.14), in: Circle())

                        Text("Nada para repasar")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(TranslateTheme.ink)

                        Text(learningProgress.savedWords.isEmpty ? "Guardá palabras desde canciones o Explorar." : "Tus palabras guardadas todavía no vencieron.")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(TranslateTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(22)
                    .background(TranslateTheme.surface.opacity(0.97), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 24, x: 0, y: 12)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 26)
                .padding(.top, 18)
            } else {
                reviewContent(item: sessionWords[0])
            }
        }
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            if sessionWords.isEmpty {
                sessionWords = learningProgress.dueVocabulary(limit: 20)
            }
        }
    }

    private func reviewContent(item: SavedVocabularyItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ExerciseSessionTopBar(
                    title: "Repaso",
                    closeAction: { dismiss() }
                )

                ProgressHeader(
                    currentIndex: max(0, learningProgress.dueVocabulary(limit: 20).count - sessionWords.count),
                    total: max(1, learningProgress.dueVocabulary(limit: 20).count)
                )

                VStack(alignment: .leading, spacing: 14) {
                    Text(item.word)
                        .font(.largeTitle.bold())
                    Text(item.source)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Label("\(Int(item.accuracy * 100))% precision", systemImage: "target")
                        Label(nextReviewText(for: item), systemImage: "calendar")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if isAnswerVisible {
                        ExampleBox(title: "Nota", bodyText: item.note.isEmpty ? "Sin nota guardada." : item.note)
                    }

                    if let feedback {
                        LearningFeedbackView(feedback: feedback)
                    }

                    HStack(spacing: 10) {
                        Button {
                            isAnswerVisible.toggle()
                        } label: {
                            Label(isAnswerVisible ? "Ocultar" : "Mostrar", systemImage: "eye")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(TranslateSecondaryButtonStyle())

                        Button {
                            answer(item, wasCorrect: false)
                        } label: {
                            Label("Me costo", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(TranslateSecondaryButtonStyle())

                        Button {
                            answer(item, wasCorrect: true)
                        } label: {
                            Label("La recorde", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(TranslatePrimaryButtonStyle())
                    }
                }
                .padding(16)
                .background(TranslateTheme.surface.opacity(0.97), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 24, x: 0, y: 12)
            }
            .padding(.horizontal, 26)
            .padding(.top, 18)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    private func answer(_ item: SavedVocabularyItem, wasCorrect: Bool) {
        learningProgress.recordWordReview(word: item.word, wasCorrect: wasCorrect)
        feedback = LearningFeedback(
            title: wasCorrect ? "Queda para mas adelante" : "Vuelve pronto",
            detail: wasCorrect ? "La repeticion espaciada lo empuja unos dias." : "Te la vuelvo a mostrar en un rato.",
            score: wasCorrect ? 1 : 0,
            isCorrect: wasCorrect
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            sessionWords.removeAll { $0.id == item.id }
            isAnswerVisible = false
            feedback = nil
        }
    }

    private func nextReviewText(for item: SavedVocabularyItem) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "vuelve \(formatter.localizedString(for: item.nextReviewAt, relativeTo: Date()))"
    }
}

private struct RoutineStep {
    let module: LearningModule
    let detail: String
    let focus: String
}

private enum RoutineChecklistState {
    case pending
    case current
    case done
}

private struct RoutineCurrentStepCard: View {
    let step: RoutineStep
    let nextStep: RoutineStep?
    let completeAction: () -> Void
    let skipAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(step.module.tint.opacity(0.14))
                        .frame(width: 54, height: 54)

                    Image(systemName: step.module.systemImage)
                        .font(.title3)
                        .foregroundStyle(step.module.tint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Ahora")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(step.module.tint)
                    Text(step.module.title)
                        .font(.title3.bold())
                    Text(step.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Label(step.focus, systemImage: "scope")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(.tertiarySystemBackground), in: Capsule())

            HStack(spacing: 10) {
                NavigationLink(value: step.module) {
                    Label("Abrir practica", systemImage: "arrow.right.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TranslatePrimaryButtonStyle())

                Button(action: completeAction) {
                    Label("Hecho", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TranslateSecondaryButtonStyle())
            }

            Button(action: skipAction) {
                Label("Saltar por ahora", systemImage: "forward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(TranslateSecondaryButtonStyle())

            if let nextStep {
                HStack(spacing: 10) {
                    Image(systemName: nextStep.module.systemImage)
                        .foregroundStyle(nextStep.module.tint)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sigue")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(nextStep.module.title)
                            .font(.caption.weight(.semibold))
                    }

                    Spacer()
                }
                .padding(10)
                .background(LocupomTheme.softSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(16)
        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(step.module.tint)
                .frame(width: 4)
        }
    }
}

private struct RoutineCompletionCard: View {
    let completedCount: Int
    let totalCount: Int
    let restartAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Rutina completada", systemImage: "checkmark.seal.fill")
                .font(.title3.bold())
                .foregroundStyle(.green)

            Text("Marcaste \(completedCount) de \(totalCount) pasos. Ya quedo registrada la practica de hoy.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                SummaryMetric(title: "Hechos", value: "\(completedCount)", systemImage: "checkmark")
                Divider()
                SummaryMetric(title: "Saltados", value: "\(max(totalCount - completedCount, 0))", systemImage: "forward")
                Divider()
                SummaryMetric(title: "Vuelta", value: "\(totalCount)", systemImage: "arrow.clockwise")
            }

            Button(action: restartAction) {
                Label("Hacer otra vuelta", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(TranslatePrimaryButtonStyle())
        }
        .padding(16)
        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct RoutineChecklistRow: View {
    let index: Int
    let step: RoutineStep
    let state: RoutineChecklistState

    private var statusImage: String {
        switch state {
        case .pending:
            return "circle"
        case .current:
            return "play.circle.fill"
        case .done:
            return "checkmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch state {
        case .pending:
            return .secondary
        case .current:
            return step.module.tint
        case .done:
            return .green
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusImage)
                .foregroundStyle(statusColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(index + 1). \(step.module.title)")
                    .font(.subheadline.weight(.semibold))
                Text(step.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(step.focus)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(step.module.tint)
        }
        .padding(12)
        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct WordExplorerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var learningProgress: LearningProgressStore
    @StateObject private var pronunciationPlayer = PronunciationPlayer()
    @State private var query = "belong"
    @State private var toolkit: WordToolkit?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var saveMessage: String?
    @State private var translation: TranslationResult?
    @State private var isTranslating = false

    private let service = LanguageLearningService()
    private var quickWords: [String] {
        switch learningProgress.profile.level {
        case .beginner:
            return ["home", "want", "time", "friend", "music"]
        case .intermediate:
            return ["belong", "through", "wonder", "brave", "instead"]
        case .advanced:
            return ["although", "however", "eventually", "ordinary", "meaningful"]
        }
    }

    var body: some View {
        ZStack {
            TranslatePracticeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ExerciseSessionTopBar(
                        title: "Explorar",
                        closeAction: { dismiss() }
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Buscá palabras")
                            .font(.system(size: 39, weight: .black, design: .rounded))
                            .foregroundStyle(TranslateTheme.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)

                        Text("Definición, pronunciación, palabras cercanas y frases reales.")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(TranslateTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        TextField("Palabra en inglés", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .padding(16)
                            .background(TranslateTheme.softSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(TranslateTheme.primary.opacity(0.16), lineWidth: 1)
                            }
                            .onSubmit {
                                Task { await search() }
                            }

                        FlowLayout(spacing: 8) {
                            ForEach(quickWords, id: \.self) { word in
                                Button(word) {
                                    query = word
                                    Task { await search() }
                                }
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(TranslateTheme.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(TranslateTheme.primary.opacity(0.10), in: Capsule())
                                .buttonStyle(.plain)
                            }
                        }

                        Button {
                            Task { await search() }
                        } label: {
                            Label(isLoading ? "Buscando" : "Buscar", systemImage: "magnifyingglass")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(TranslatePrimaryButtonStyle())
                        .disabled(isLoading || query.trimmed.isEmpty)
                    }
                    .padding(22)
                    .background(TranslateTheme.surface.opacity(0.97), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 24, x: 0, y: 12)

                    if isLoading {
                        ProgressView("Conectando APIs...")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .tint(TranslateTheme.primary)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    }

                    if let errorMessage {
                        LearningNoticeView(
                            systemImage: "wifi.exclamationmark",
                            title: "No pude cargar datos",
                            detail: errorMessage
                        )
                    }

                    if let toolkit {
                        WordSummaryView(
                            toolkit: toolkit,
                            playAudio: {
                                if let audioURL = toolkit.audioURL {
                                    pronunciationPlayer.play(audioURL)
                                }
                            }
                        )

                        LearningAPISection(title: "Acciones", source: "Personal") {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    Button {
                                        saveCurrentWord(toolkit)
                                    } label: {
                                        Label("Guardar", systemImage: "bookmark")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(TranslatePrimaryButtonStyle())

                                    NavigationLink(value: LearningModule.review) {
                                        Label("Repasar", systemImage: "repeat")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(TranslateSecondaryButtonStyle())
                                }

                                Button {
                                    Task { await translateCurrentWord(toolkit) }
                                } label: {
                                    Label(isTranslating ? "Traduciendo" : "Traducir", systemImage: "globe.americas")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(TranslateSecondaryButtonStyle())
                                .disabled(isTranslating)

                                if let saveMessage {
                                    Label(saveMessage, systemImage: "checkmark.circle")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let translation {
                                    ExampleBox(
                                        title: "Traduccion opcional",
                                        bodyText: translation.translatedText
                                    )
                                }
                            }
                        }

                        if !toolkit.definitions.isEmpty {
                            LearningAPISection(title: "Definiciones", source: "Dictionary API") {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(toolkit.definitions) { definition in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(definition.partOfSpeech.capitalized)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.tint)
                                            Text(definition.text)
                                                .font(.subheadline)
                                            if let example = definition.example {
                                                Text(example)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                        if definition.id != toolkit.definitions.last?.id {
                                            Divider()
                                        }
                                    }
                                }
                            }
                        }

                        if !toolkit.relatedWords.isEmpty {
                            LearningAPISection(title: "Palabras cercanas", source: "Datamuse") {
                                FlowLayout(spacing: 8) {
                                    ForEach(toolkit.relatedWords) { suggestion in
                                        Button {
                                            query = suggestion.word
                                            Task { await search() }
                                        } label: {
                                            VStack(spacing: 2) {
                                                Text(suggestion.word)
                                                    .font(.callout.weight(.semibold))
                                                Text(suggestion.kind)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                        }
                                        .buttonStyle(TranslateSecondaryButtonStyle())
                                    }
                                }
                            }
                        }

                        if !toolkit.examples.isEmpty {
                            LearningAPISection(title: "Frases reales", source: "Tatoeba") {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(toolkit.examples) { example in
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(example.text)
                                                .font(.subheadline.weight(.semibold))
                                            if let translation = example.translation {
                                                Text(translation)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(10)
                                        .background(LocupomTheme.softSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    }
                                }
                            }
                        }

                        if !toolkit.hasContent {
                            LearningNoticeView(
                                systemImage: "questionmark.folder",
                                title: "Sin resultados",
                                detail: "Proba con una palabra mas comun o revisa la conexion."
                            )
                        }
                    }
                }
                .padding(.horizontal, 26)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task {
            if toolkit == nil {
                await search()
            }
        }
    }

    private func search() async {
        let cleanQuery = query.trimmed
        guard !cleanQuery.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        saveMessage = nil
        translation = nil
        let result = await service.fetchWordToolkit(word: cleanQuery)
        toolkit = result
        learningProgress.cacheSentences(result.examples)
        isLoading = false

        if !result.hasContent {
            errorMessage = "Las APIs respondieron, pero no encontre contenido util para \"\(cleanQuery)\"."
        }
    }

    private func saveCurrentWord(_ toolkit: WordToolkit) {
        let note = toolkit.definitions.first?.text
            ?? toolkit.examples.first?.translation
            ?? "Guardada desde Explorar"
        let inserted = learningProgress.saveWord(
            word: toolkit.word,
            note: note,
            source: "Explorar"
        )
        saveMessage = inserted ? "Agregada a tu vocabulario." : "Ya estaba guardada, actualice la nota."
    }

    private func translateCurrentWord(_ toolkit: WordToolkit) async {
        isTranslating = true
        defer { isTranslating = false }

        do {
            translation = try await service.translate(text: toolkit.word)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct TranslatePracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var learningProgress: LearningProgressStore
    @State private var promptIndex = 0
    @State private var answer = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var feedback: TranslationPracticeFeedback?
    @State private var corrections: [WritingCorrection] = []
    @State private var showHint = false
    @State private var showWordBank = false
    @State private var showExample = false
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var remotePrompts: [TranslationPracticePrompt] = []
    @State private var loadedRemoteLevel: TopicCEFRLevel?
    @State private var isLoadingPrompts = false

    private let service = LanguageLearningService()

    private var selectedCEFRLevel: TopicCEFRLevel {
        TopicCEFRLevel(rawValue: learningProgress.cefrLevelCode) ?? TopicCEFRLevel(profileLevel: learningProgress.profile.level)
    }

    private var level: LearningLevel {
        selectedCEFRLevel.fallbackLearningLevel
    }

    private var prompts: [TranslationPracticePrompt] {
        remotePrompts.isEmpty ? TranslationPracticePrompt.deck(for: level) : remotePrompts
    }

    private var prompt: TranslationPracticePrompt {
        if prompts.indices.contains(promptIndex) {
            return prompts[promptIndex]
        }
        return TranslationPracticePrompt.deck(for: .beginner)[0]
    }

    var body: some View {
        ZStack {
            TranslatePracticeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    ExerciseSessionTopBar(
                        title: nil,
                        closeAction: { dismiss() }
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Traducí\nlibremente")
                            .font(.system(size: 39, weight: .black, design: .rounded))
                            .foregroundStyle(TranslateTheme.ink)
                            .lineSpacing(-2)
                            .padding(.top, 8)

                        Text("Transmití la idea con tus propias palabras.")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(TranslateTheme.muted)
                    }

                    if isLoadingPrompts {
                        Label("Cargando...", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(TranslateTheme.muted)
                    }

                    TranslatePromptCard(prompt: prompt.sourceText, speakAction: speakPrompt)

                    TranslateAnswerEditor(answer: $answer, limit: 500)

                    TranslateAssistActions(
                        hintAction: { withAnimation { showHint.toggle() } },
                        wordBankAction: { withAnimation { showWordBank.toggle() } },
                        exampleAction: { withAnimation { showExample.toggle() } }
                    )

                    if showHint {
                        TranslateInfoCard(systemImage: "lightbulb.fill", title: "Hint", detail: prompt.hint, tint: .orange)
                    }

                    if showWordBank {
                        TranslateWordBank(words: prompt.wordBank) { word in
                            appendWord(word)
                        }
                    }

                    if showExample {
                        TranslateInfoCard(systemImage: "sparkles", title: "Example", detail: prompt.expectedTranslation, tint: TranslateTheme.secondary)
                    }

                    TranslateAxoTipCard()

                    if feedback != nil || isSubmitting {
                        TranslateFeedbackCard(feedback: feedback, corrections: corrections, isLoading: isSubmitting)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if let errorMessage {
                        TranslateInfoCard(systemImage: "wifi.exclamationmark", title: "Review unavailable", detail: errorMessage, tint: .orange)
                    }
                }
                .padding(.horizontal, 26)
                .padding(.top, 18)
                .padding(.bottom, 112)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                if feedback == nil {
                    Task { await submitAnswer() }
                } else {
                    nextPrompt()
                }
            } label: {
                Label(
                    feedback == nil ? (isSubmitting ? "Revisando..." : "Revisar respuesta") : "Siguiente frase",
                    systemImage: feedback == nil ? "play.fill" : "arrow.right"
                )
                .font(.system(size: 22, weight: .black, design: .rounded))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(TranslatePrimaryButtonStyle())
            .disabled(isSubmitting || answer.trimmed.isEmpty)
            .padding(.horizontal, 26)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task(id: selectedCEFRLevel) {
            await loadTranslationPrompts(for: selectedCEFRLevel)
        }
        .onChange(of: learningProgress.cefrLevelCode) { _, _ in
            promptIndex = 0
            remotePrompts = []
            loadedRemoteLevel = nil
            resetCurrentPromptState()
        }
    }

    private var progress: Double {
        guard !prompts.isEmpty else { return 0 }
        return Double(promptIndex + 1) / Double(prompts.count)
    }

    @MainActor
    private func loadTranslationPrompts(for selectedLevel: TopicCEFRLevel, forceRefresh: Bool = false) async {
        if !forceRefresh, loadedRemoteLevel == selectedLevel, !remotePrompts.isEmpty {
            return
        }

        isLoadingPrompts = true

        do {
            let response = try await LocupomTopicsAPIClient.fetchPracticeExercises(
                skill: "translation",
                level: selectedLevel.rawValue,
                learnerId: learningProgress.apiLearnerId,
                completedKeys: Array(learningProgress.completedRemoteContentKeys)
            )
            let mappedPrompts = response.exercises.compactMap {
                TranslationPracticePrompt(remote: $0, fallbackLevel: selectedLevel.fallbackLearningLevel)
            }

            loadedRemoteLevel = selectedLevel
            remotePrompts = mappedPrompts
            promptIndex = 0
            resetCurrentPromptState()
        } catch {
            remotePrompts = []
            loadedRemoteLevel = selectedLevel
        }

        isLoadingPrompts = false
    }

    private func submitAnswer() async {
        isSubmitting = true
        errorMessage = nil
        corrections = []

        let translationScore = TextMatcher.evaluate(answer: answer, target: prompt.expectedTranslation)
        let accuracyScore = translationScore.isExact ? 1 : translationScore.similarity

        do {
            corrections = try await service.checkWriting(text: answer, language: "es")
        } catch {
            corrections = []
            errorMessage = error.localizedDescription
        }

        let grammarScore = max(0.15, 1 - Double(corrections.count) * 0.16)
        let lengthRatio = min(1, Double(answer.trimmed.split(separator: " ").count) / Double(max(prompt.expectedTranslation.split(separator: " ").count, 1)))
        let naturalnessScore = min(1, max(0, accuracyScore * 0.55 + grammarScore * 0.25 + lengthRatio * 0.20))
        let isStrong = accuracyScore >= 0.68 && grammarScore >= 0.68

        feedback = TranslationPracticeFeedback(
            accuracy: accuracyScore,
            grammar: grammarScore,
            naturalness: naturalnessScore,
            isStrong: isStrong
        )

        learningProgress.recordModule(LearningModule.translate.rawValue, wasCorrect: isStrong)
        if isStrong {
            learningProgress.recordErrorResolved(module: LearningModule.translate.rawValue, expected: prompt.expectedTranslation)
            markTranslationCompletedIfNeeded(prompt)
        } else {
            learningProgress.recordError(
                module: LearningModule.translate.rawValue,
                expected: prompt.expectedTranslation,
                actual: answer,
                context: prompt.sourceText
            )
        }

        isSubmitting = false
    }

    private func markTranslationCompletedIfNeeded(_ prompt: TranslationPracticePrompt) {
        guard let apiContentId = prompt.apiContentId else {
            return
        }

        let learnerId = learningProgress.apiLearnerId
        let completedLevel = selectedCEFRLevel.rawValue
        let completedTitle = prompt.sourceText
        let didInsert = learningProgress.markRemoteContentCompleted(kind: "exercise", itemId: apiContentId)
        guard didInsert else {
            return
        }

        Task {
            try? await LocupomTopicsAPIClient.markCompleted(
                learnerId: learnerId,
                kind: "exercise",
                itemId: apiContentId,
                level: completedLevel,
                title: completedTitle
            )
        }
    }

    private func nextPrompt() {
        promptIndex = promptIndex >= prompts.count - 1 ? 0 : promptIndex + 1
        resetCurrentPromptState()
    }

    private func resetCurrentPromptState() {
        answer = ""
        feedback = nil
        corrections = []
        errorMessage = nil
        showHint = false
        showWordBank = false
        showExample = false
    }

    private func appendWord(_ word: String) {
        let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        answer = trimmedAnswer.isEmpty ? word : "\(trimmedAnswer) \(word)"
    }

    private func speakPrompt() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: prompt.sourceText)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = level.speechRate
        speechSynthesizer.speak(utterance)
    }
}

private struct WritingCoachView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var learningProgress: LearningProgressStore
    @State private var promptIndex = 0
    @State private var answer = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var feedback: WritingPracticeFeedback?
    @State private var corrections: [WritingCorrection] = []
    @State private var showVocabularyHelp = false
    @State private var showGrammarTips = false
    @State private var showRewriteSuggestion = false
    @State private var remotePrompts: [WritingPracticePrompt] = []
    @State private var loadedRemoteLevel: TopicCEFRLevel?
    @State private var isLoadingPrompts = false

    private let service = LanguageLearningService()

    private var selectedCEFRLevel: TopicCEFRLevel {
        TopicCEFRLevel(rawValue: learningProgress.cefrLevelCode) ?? TopicCEFRLevel(profileLevel: learningProgress.profile.level)
    }

    private var level: LearningLevel {
        selectedCEFRLevel.fallbackLearningLevel
    }

    private var prompts: [WritingPracticePrompt] {
        remotePrompts.isEmpty ? WritingPracticePrompt.deck(for: level) : remotePrompts
    }

    private var prompt: WritingPracticePrompt {
        if prompts.indices.contains(promptIndex) {
            return prompts[promptIndex]
        }
        return WritingPracticePrompt.deck(for: .beginner)[0]
    }

    private var wordCount: Int {
        normalizedWords(in: answer).count
    }

    private var previewFeedback: WritingPracticeFeedback? {
        guard wordCount > 0 else { return nil }
        return makeFeedback(corrections: [])
    }

    var body: some View {
        ZStack {
            TranslatePracticeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    ExerciseSessionTopBar(
                        title: "Writing",
                        closeAction: { dismiss() }
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Write & improve")
                            .font(.system(size: 39, weight: .black, design: .rounded))
                            .foregroundStyle(TranslateTheme.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)

                        Text("Get focused feedback on your English.")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(TranslateTheme.muted)
                    }

                    if isLoadingPrompts {
                        Label("Cargando...", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(TranslateTheme.muted)
                    }

                    WritingPromptCard(prompt: prompt)

                    WritingAnswerEditor(
                        answer: $answer,
                        wordCount: wordCount,
                        limit: prompt.characterLimit
                    )

                    WritingAssistActions(
                        vocabularyAction: { withAnimation { showVocabularyHelp.toggle() } },
                        grammarAction: { withAnimation { showGrammarTips.toggle() } },
                        rewriteAction: { withAnimation { showRewriteSuggestion.toggle() } }
                    )

                    if showVocabularyHelp {
                        TranslateInfoCard(systemImage: "book.closed.fill", title: "Vocabulary help", detail: prompt.vocabularyHelp, tint: TranslateTheme.primary)
                    }

                    if showGrammarTips {
                        TranslateInfoCard(systemImage: "checkmark.shield.fill", title: "Grammar tips", detail: prompt.grammarTip, tint: TranslateTheme.mint)
                    }

                    if showRewriteSuggestion {
                        TranslateInfoCard(systemImage: "wand.and.sparkles", title: "Rewrite suggestion", detail: rewriteSuggestion, tint: TranslateTheme.secondary)
                    }

                    WritingFeedbackSummaryCard(
                        feedback: feedback,
                        preview: previewFeedback,
                        isLoading: isSubmitting
                    )

                    if !corrections.isEmpty {
                        WritingCorrectionsCard(corrections: corrections)
                    }

                    if let errorMessage {
                        TranslateInfoCard(systemImage: "wifi.exclamationmark", title: "Feedback unavailable", detail: errorMessage, tint: .orange)
                    }

                    Button {
                        if feedback == nil {
                            Task { await submitWriting() }
                        } else {
                            nextPrompt()
                        }
                    } label: {
                        Label(
                            feedback == nil ? (isSubmitting ? "Checking..." : "Get feedback") : "Next prompt",
                            systemImage: feedback == nil ? "sparkles" : "arrow.right"
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(TranslatePrimaryButtonStyle())
                    .disabled(isSubmitting || answer.trimmed.isEmpty)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task(id: selectedCEFRLevel) {
            await loadWritingPrompts(for: selectedCEFRLevel)
        }
        .onChange(of: learningProgress.cefrLevelCode) { _, _ in
            promptIndex = 0
            remotePrompts = []
            loadedRemoteLevel = nil
            resetCurrentPromptState()
        }
    }

    private var rewriteSuggestion: String {
        if answer.trimmed.isEmpty {
            return prompt.sampleAnswer
        }

        return "Try connecting your ideas with transitions, keeping one clear main idea per sentence, and replacing repeated words with more specific vocabulary."
    }

    @MainActor
    private func loadWritingPrompts(for selectedLevel: TopicCEFRLevel, forceRefresh: Bool = false) async {
        if !forceRefresh, loadedRemoteLevel == selectedLevel, !remotePrompts.isEmpty {
            return
        }

        isLoadingPrompts = true

        do {
            let response = try await LocupomTopicsAPIClient.fetchPracticeExercises(
                skill: "writing",
                level: selectedLevel.rawValue,
                learnerId: learningProgress.apiLearnerId,
                completedKeys: Array(learningProgress.completedRemoteContentKeys)
            )
            let mappedPrompts = response.exercises.compactMap {
                WritingPracticePrompt(remote: $0, fallbackLevel: selectedLevel.fallbackLearningLevel)
            }

            loadedRemoteLevel = selectedLevel
            remotePrompts = mappedPrompts
            promptIndex = 0
            resetCurrentPromptState()
        } catch {
            remotePrompts = []
            loadedRemoteLevel = selectedLevel
        }

        isLoadingPrompts = false
    }

    private func submitWriting() async {
        isSubmitting = true
        errorMessage = nil
        corrections = []

        do {
            corrections = try await service.checkWriting(text: answer, language: "en-US")
        } catch {
            corrections = []
            errorMessage = error.localizedDescription
        }

        let result = makeFeedback(corrections: corrections)
        feedback = result

        learningProgress.recordModule(LearningModule.writing.rawValue, wasCorrect: result.isStrong)
        if result.isStrong {
            learningProgress.recordErrorResolved(module: LearningModule.writing.rawValue, expected: prompt.title)
            markWritingCompletedIfNeeded(prompt)
        } else {
            learningProgress.recordError(
                module: LearningModule.writing.rawValue,
                expected: prompt.title,
                actual: answer,
                context: prompt.instruction
            )
        }

        isSubmitting = false
    }

    private func markWritingCompletedIfNeeded(_ prompt: WritingPracticePrompt) {
        guard let apiContentId = prompt.apiContentId else {
            return
        }

        let learnerId = learningProgress.apiLearnerId
        let completedLevel = selectedCEFRLevel.rawValue
        let completedTitle = prompt.title
        let didInsert = learningProgress.markRemoteContentCompleted(kind: "exercise", itemId: apiContentId)
        guard didInsert else {
            return
        }

        Task {
            try? await LocupomTopicsAPIClient.markCompleted(
                learnerId: learnerId,
                kind: "exercise",
                itemId: apiContentId,
                level: completedLevel,
                title: completedTitle
            )
        }
    }

    private func nextPrompt() {
        promptIndex = promptIndex >= prompts.count - 1 ? 0 : promptIndex + 1
        resetCurrentPromptState()
    }

    private func resetCurrentPromptState() {
        answer = ""
        feedback = nil
        corrections = []
        errorMessage = nil
        showVocabularyHelp = false
        showGrammarTips = false
        showRewriteSuggestion = false
    }

    private func makeFeedback(corrections: [WritingCorrection]) -> WritingPracticeFeedback {
        let grammarScore = max(0.12, min(1, 0.98 - Double(corrections.count) * 0.11))
        let vocabularyScore = vocabularyScore()
        let fluencyScore = fluencyScore()
        let isStrong = grammarScore >= 0.70 && vocabularyScore >= 0.68 && fluencyScore >= 0.68 && wordCount >= prompt.wordRange.lowerBound

        return WritingPracticeFeedback(
            grammar: grammarScore,
            vocabulary: vocabularyScore,
            fluency: fluencyScore,
            isStrong: isStrong
        )
    }

    private func vocabularyScore() -> Double {
        let words = normalizedWords(in: answer)
        guard !words.isEmpty else { return 0 }
        let uniqueRatio = Double(Set(words).count) / Double(words.count)
        let targetHits = prompt.vocabularyTargets.filter { target in
            words.contains(target.lowercased())
        }.count
        let targetScore = prompt.vocabularyTargets.isEmpty ? 0.7 : Double(targetHits) / Double(prompt.vocabularyTargets.count)
        return min(1, uniqueRatio * 0.48 + targetScore * 0.34 + wordTargetScore() * 0.18)
    }

    private func fluencyScore() -> Double {
        let words = normalizedWords(in: answer)
        guard !words.isEmpty else { return 0 }
        let transitions = ["because", "then", "also", "however", "although", "while", "after", "before", "finally", "usually"]
        let transitionHits = transitions.filter { words.contains($0) }.count
        let transitionScore = min(1, Double(transitionHits) / 3)
        let sentenceCount = max(1, answer.split { ".!?".contains($0) }.count)
        let sentenceScore = min(1, Double(sentenceCount) / 4)
        return min(1, wordTargetScore() * 0.52 + transitionScore * 0.24 + sentenceScore * 0.24)
    }

    private func wordTargetScore() -> Double {
        guard wordCount > 0 else { return 0 }
        if prompt.wordRange.contains(wordCount) {
            return 1
        }

        let nearest = wordCount < prompt.wordRange.lowerBound ? prompt.wordRange.lowerBound : prompt.wordRange.upperBound
        let distance = abs(wordCount - nearest)
        let span = max(prompt.wordRange.upperBound - prompt.wordRange.lowerBound, 1)
        return max(0.25, 1 - Double(distance) / Double(span))
    }

    private func normalizedWords(in text: String) -> [String] {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}

private struct WritingPracticePrompt: Identifiable {
    let id: UUID
    let apiContentId: String?
    let title: String
    let instruction: String
    let wordRange: ClosedRange<Int>
    let vocabularyHelp: String
    let grammarTip: String
    let sampleAnswer: String
    let vocabularyTargets: [String]
    let level: LearningLevel

    init(
        apiContentId: String? = nil,
        title: String,
        instruction: String,
        wordRange: ClosedRange<Int>,
        vocabularyHelp: String,
        grammarTip: String,
        sampleAnswer: String,
        vocabularyTargets: [String],
        level: LearningLevel
    ) {
        self.id = UUID()
        self.apiContentId = apiContentId
        self.title = title
        self.instruction = instruction
        self.wordRange = wordRange
        self.vocabularyHelp = vocabularyHelp
        self.grammarTip = grammarTip
        self.sampleAnswer = sampleAnswer
        self.vocabularyTargets = vocabularyTargets
        self.level = level
    }

    init?(remote: LocupomRemotePracticeExercise, fallbackLevel: LearningLevel) {
        guard let range = remote.wordRange, range.count >= 2 else {
            return nil
        }

        let lower = max(1, min(range[0], range[1]))
        let upper = max(lower, max(range[0], range[1]))
        self.init(
            apiContentId: remote.id,
            title: remote.title,
            instruction: remote.instruction,
            wordRange: lower...upper,
            vocabularyHelp: remote.vocabularyHelp ?? "Use precise words from the prompt.",
            grammarTip: remote.grammarTip ?? "Keep one clear main idea per sentence.",
            sampleAnswer: remote.sampleAnswer ?? "",
            vocabularyTargets: remote.vocabularyTargets ?? [],
            level: remote.level.trimmed.isEmpty ? fallbackLevel : LearningLevel.fromCEFRCode(remote.level)
        )
    }

    var characterLimit: Int {
        max(500, wordRange.upperBound * 8)
    }

    static func deck(for level: LearningLevel) -> [WritingPracticePrompt] {
        all.filter { $0.level == level }
    }

    private static let all: [WritingPracticePrompt] = [
        WritingPracticePrompt(
            title: "Describe your favorite song",
            instruction: "Write about why you like it and when you listen to it.",
            wordRange: 35...55,
            vocabularyHelp: "Useful words: favorite, melody, lyrics, happy, calm, listen, remember.",
            grammarTip: "Use simple present for habits: I listen, it makes me feel, I like.",
            sampleAnswer: "My favorite song is calm and happy. I listen to it when I study or walk. The melody helps me relax, and the lyrics are easy to remember.",
            vocabularyTargets: ["favorite", "listen", "lyrics", "melody", "feel"],
            level: .beginner
        ),
        WritingPracticePrompt(
            title: "Write about your morning routine",
            instruction: "Describe three things you usually do before starting your day.",
            wordRange: 35...55,
            vocabularyHelp: "Useful words: wake up, breakfast, usually, after, before, start.",
            grammarTip: "Use adverbs of frequency: usually, often, sometimes, always.",
            sampleAnswer: "I usually wake up at seven. After that, I have breakfast and check my phone. Before I start work, I listen to a short English podcast.",
            vocabularyTargets: ["usually", "breakfast", "after", "before", "start"],
            level: .beginner
        ),
        WritingPracticePrompt(
            title: "Explain a simple goal",
            instruction: "Write about one English goal you want to complete this week.",
            wordRange: 40...60,
            vocabularyHelp: "Useful words: goal, improve, practice, every day, learn, remember.",
            grammarTip: "Use want to + verb: I want to improve, I want to learn.",
            sampleAnswer: "This week, I want to learn ten new words and practice listening every day. My goal is small, but it can help me feel more confident.",
            vocabularyTargets: ["goal", "improve", "practice", "learn", "confident"],
            level: .beginner
        ),
        WritingPracticePrompt(
            title: "Describe a place you like",
            instruction: "Write about a place and why it feels special.",
            wordRange: 40...60,
            vocabularyHelp: "Useful words: quiet, busy, beautiful, comfortable, near, visit.",
            grammarTip: "Use there is / there are to describe what exists in a place.",
            sampleAnswer: "I like a small cafe near my house. It is quiet and comfortable. There are many books, and the music is soft. I visit it on weekends.",
            vocabularyTargets: ["quiet", "comfortable", "near", "visit", "weekends"],
            level: .beginner
        ),
        WritingPracticePrompt(
            title: "Tell me about a friend",
            instruction: "Describe one friend using personality words.",
            wordRange: 40...60,
            vocabularyHelp: "Useful words: kind, funny, patient, helpful, honest, friendly.",
            grammarTip: "Use because to explain your opinion: He is kind because...",
            sampleAnswer: "My friend Lucas is funny and helpful. He listens when I have a problem, and he is patient when I practice English. I like talking with him.",
            vocabularyTargets: ["friend", "funny", "helpful", "patient", "practice"],
            level: .beginner
        ),
        WritingPracticePrompt(
            title: "Describe your ideal weekend",
            instruction: "Write a short response in English.",
            wordRange: 80...120,
            vocabularyHelp: "Useful words: balance, relaxation, adventure, catch up, explore, restaurant, routine.",
            grammarTip: "Use connectors to organize time: On Saturday, then, in the afternoon, on Sunday.",
            sampleAnswer: "My ideal weekend is a balance of rest and adventure. On Saturday, I sleep a little later, make breakfast, and meet a friend for coffee. In the afternoon, I explore a new place in the city. On Sunday, I stay home, read, and prepare for the week.",
            vocabularyTargets: ["balance", "relaxation", "adventure", "explore", "afternoon", "weekend"],
            level: .intermediate
        ),
        WritingPracticePrompt(
            title: "Explain a song that changed your mood",
            instruction: "Describe the situation, the song, and how you felt after listening.",
            wordRange: 80...120,
            vocabularyHelp: "Useful words: mood, lyrics, energy, remind, suddenly, calm down, focus.",
            grammarTip: "Use past simple for the situation and present simple for general opinions.",
            sampleAnswer: "Last week, I felt tired after a long day. I played an upbeat song, and the rhythm changed my mood almost immediately. The lyrics reminded me to keep moving, so I cleaned my room, cooked dinner, and felt much lighter.",
            vocabularyTargets: ["mood", "lyrics", "energy", "reminded", "felt", "rhythm"],
            level: .intermediate
        ),
        WritingPracticePrompt(
            title: "Give advice to a beginner",
            instruction: "Write advice for someone who is starting to learn English.",
            wordRange: 80...120,
            vocabularyHelp: "Useful words: consistent, mistake, confidence, improve, aloud, routine.",
            grammarTip: "Use should / could / try to for advice.",
            sampleAnswer: "A beginner should practice a little every day instead of studying for many hours once a week. It is important to repeat useful phrases aloud and not worry too much about mistakes. Confidence grows when the routine is simple.",
            vocabularyTargets: ["beginner", "practice", "mistakes", "confidence", "routine", "should"],
            level: .intermediate
        ),
        WritingPracticePrompt(
            title: "Compare two ways of learning",
            instruction: "Compare learning with songs and learning with textbooks.",
            wordRange: 85...125,
            vocabularyHelp: "Useful words: compared with, while, however, natural, structure, motivation.",
            grammarTip: "Use while or however to show contrast between two ideas.",
            sampleAnswer: "Learning with songs feels natural because I hear real pronunciation and emotion. Textbooks, however, give me more structure and clear explanations. I think both methods are useful: songs keep me motivated, while textbooks help me understand grammar.",
            vocabularyTargets: ["compared", "while", "however", "natural", "structure", "motivation"],
            level: .intermediate
        ),
        WritingPracticePrompt(
            title: "Describe a challenge you solved",
            instruction: "Write about a small problem and how you handled it.",
            wordRange: 85...125,
            vocabularyHelp: "Useful words: challenge, solution, decided, managed to, because, result.",
            grammarTip: "Use past simple to describe completed actions: I decided, I tried, I managed.",
            sampleAnswer: "I had a challenge when I could not understand fast English videos. I decided to watch shorter clips and repeat one sentence at a time. After two weeks, I managed to recognize more words, and the videos felt less stressful.",
            vocabularyTargets: ["challenge", "solution", "decided", "managed", "result", "understand"],
            level: .intermediate
        ),
        WritingPracticePrompt(
            title: "Argue for daily practice",
            instruction: "Write a persuasive paragraph about why consistency matters.",
            wordRange: 120...170,
            vocabularyHelp: "Useful words: consistency, sustainable, progress, motivation, evidence, habit.",
            grammarTip: "Use complex sentences with because, although, and even if.",
            sampleAnswer: "Daily practice matters because it turns learning into a habit instead of a rare event. Although one short session may feel small, repeated sessions create visible progress. Even if motivation changes from day to day, a sustainable routine helps learners keep moving.",
            vocabularyTargets: ["consistency", "sustainable", "progress", "motivation", "habit", "although"],
            level: .advanced
        ),
        WritingPracticePrompt(
            title: "Analyze a lyric",
            instruction: "Choose one line from a song and explain its meaning in context.",
            wordRange: 120...170,
            vocabularyHelp: "Useful words: suggests, implies, contrast, emotion, metaphor, perspective.",
            grammarTip: "Use cautious language for interpretation: it suggests, it may imply, it could mean.",
            sampleAnswer: "The line suggests that the speaker is trying to hide a strong emotion. In context, the image works like a metaphor for distance: the person is present physically but absent emotionally. This contrast makes the lyric feel more intimate.",
            vocabularyTargets: ["suggests", "implies", "contrast", "emotion", "metaphor", "context"],
            level: .advanced
        ),
        WritingPracticePrompt(
            title: "Defend your learning method",
            instruction: "Explain which method works best for you and why.",
            wordRange: 125...175,
            vocabularyHelp: "Useful words: effective, retain, feedback, exposure, weakness, strategy.",
            grammarTip: "Use relative clauses to add detail: a method that..., feedback that...",
            sampleAnswer: "The most effective method for me is combining listening with immediate feedback. Songs give me repeated exposure to real pronunciation, while correction tools show the weaknesses in my writing. This strategy helps me retain vocabulary because I use it in context.",
            vocabularyTargets: ["effective", "retain", "feedback", "exposure", "weaknesses", "strategy"],
            level: .advanced
        ),
        WritingPracticePrompt(
            title: "Reflect on a mistake",
            instruction: "Write about an English mistake that taught you something useful.",
            wordRange: 125...175,
            vocabularyHelp: "Useful words: misunderstanding, pattern, realize, improve, correction, avoid.",
            grammarTip: "Use past perfect if one action happened before another: I had confused...",
            sampleAnswer: "One useful mistake happened when I used a false friend in a conversation. I had confused two similar words, and the sentence sounded strange. The correction helped me realize that vocabulary is not only translation; it also depends on context and usage.",
            vocabularyTargets: ["mistake", "pattern", "realize", "correction", "context", "usage"],
            level: .advanced
        ),
        WritingPracticePrompt(
            title: "Summarize a short opinion",
            instruction: "Write a nuanced opinion about whether music helps language learning.",
            wordRange: 130...180,
            vocabularyHelp: "Useful words: nuance, benefit, limitation, authentic, repetition, passive.",
            grammarTip: "Balance your opinion with although / however / on the other hand.",
            sampleAnswer: "Music can be a powerful language tool because it provides repetition, emotion, and authentic pronunciation. However, it also has limitations: lyrics can be poetic, fast, or grammatically unusual. The best approach is to use music actively, not passively.",
            vocabularyTargets: ["nuanced", "benefit", "limitation", "authentic", "repetition", "however"],
            level: .advanced
        )
    ]
}

private struct WritingPracticeFeedback {
    let grammar: Double
    let vocabulary: Double
    let fluency: Double
    let isStrong: Bool
}

private struct WritingPromptCard: View {
    let prompt: WritingPracticePrompt

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "square.and.pencil")
                .font(.title3)
                .foregroundStyle(TranslateTheme.primary)
                .frame(width: 52, height: 52)
                .background(TranslateTheme.primary.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 5) {
                Text(prompt.title)
                    .font(.headline)
                    .foregroundStyle(TranslateTheme.ink)

                (Text("in ")
                    + Text("\(prompt.wordRange.lowerBound)-\(prompt.wordRange.upperBound)")
                        .foregroundColor(TranslateTheme.primary)
                    + Text(" words."))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TranslateTheme.muted)
            }

            Spacer()
        }
        .padding(18)
        .background(TranslateTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

private struct WritingAnswerEditor: View {
    @Binding var answer: String
    let wordCount: Int
    let limit: Int

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $answer)
                .frame(minHeight: 230)
                .scrollContentBackground(.hidden)
                .padding(10)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .font(.body)
                .lineSpacing(5)
                .onChange(of: answer) { _, newValue in
                    if newValue.count > limit {
                        answer = String(newValue.prefix(limit))
                    }
                }

            if answer.isEmpty {
                Text("Start writing in English...")
                    .foregroundStyle(TranslateTheme.muted.opacity(0.75))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                    .allowsHitTesting(false)
            }
        }
        .background(TranslateTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(TranslateTheme.primary.opacity(0.75), lineWidth: 1.2)
        }
        .overlay(alignment: .bottomTrailing) {
            Text("\(wordCount) \(wordCount == 1 ? "word" : "words")")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(TranslateTheme.primary)
                .padding(14)
        }
        .shadow(color: TranslateTheme.primary.opacity(0.06), radius: 14, x: 0, y: 8)
    }
}

private struct WritingAssistActions: View {
    let vocabularyAction: () -> Void
    let grammarAction: () -> Void
    let rewriteAction: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            TranslateActionChip(title: "Vocabulary help", systemImage: "book.closed.fill", action: vocabularyAction)
            TranslateActionChip(title: "Grammar tips", systemImage: "checkmark.shield.fill", action: grammarAction)
            TranslateActionChip(title: "Rewrite suggestion", systemImage: "wand.and.sparkles", action: rewriteAction)
        }
    }
}

private struct WritingFeedbackSummaryCard: View {
    let feedback: WritingPracticeFeedback?
    let preview: WritingPracticeFeedback?
    let isLoading: Bool

    private var activeFeedback: WritingPracticeFeedback? {
        feedback ?? preview
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(TranslateTheme.secondary)

                VStack(alignment: .leading, spacing: 3) {
                    Text("AI feedback preview")
                        .font(.headline)
                        .foregroundStyle(TranslateTheme.ink)
                    Text(feedback == nil ? "Get instant AI feedback to improve your writing." : "Use these scores to rewrite with more intention.")
                        .font(.caption)
                        .foregroundStyle(TranslateTheme.muted)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            HStack(spacing: 0) {
                WritingScoreColumn(title: "Grammar", value: activeFeedback?.grammar, tint: TranslateTheme.primary)
                Divider().frame(height: 58)
                WritingScoreColumn(title: "Vocabulary", value: activeFeedback?.vocabulary, tint: TranslateTheme.mint)
                Divider().frame(height: 58)
                WritingScoreColumn(title: "Fluency", value: activeFeedback?.fluency, tint: TranslateTheme.secondary)
            }
        }
        .padding(16)
        .background(TranslateTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

private struct WritingScoreColumn: View {
    let title: String
    let value: Double?
    let tint: Color

    var body: some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(TranslateTheme.ink)
            Text(value.map { "\(Int($0 * 100))/100" } ?? "--/100")
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(tint)
            Text(status)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
    }

    private var status: String {
        guard let value else { return "Waiting" }
        if value >= 0.82 { return "Great" }
        if value >= 0.68 { return "Good" }
        return "Needs work"
    }
}

private struct WritingCorrectionsCard: View {
    let corrections: [WritingCorrection]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Suggested fixes", systemImage: "exclamationmark.circle.fill")
                .font(.headline)
                .foregroundStyle(TranslateTheme.ink)

            ForEach(Array(corrections.prefix(3))) { correction in
                VStack(alignment: .leading, spacing: 5) {
                    Text(correction.displayMessage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TranslateTheme.ink)
                    Text(correction.message)
                        .font(.caption)
                        .foregroundStyle(TranslateTheme.muted)
                    if !correction.replacements.isEmpty {
                        Text("Try: \(correction.replacements.prefix(3).joined(separator: ", "))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TranslateTheme.primary)
                    }
                }
                .padding(12)
                .background(TranslateTheme.softSurface, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(16)
        .background(TranslateTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

private enum TranslateTheme {
    static let ink = Color(.label)
    static let muted = Color(.secondaryLabel)
    static let primary = Color(red: 0.20, green: 0.36, blue: 0.98)
    static let secondary = Color(red: 0.47, green: 0.35, blue: 0.98)
    static let mint = Color(red: 0.38, green: 0.78, blue: 0.73)
    static let surface = Color(.secondarySystemBackground)
    static let elevatedSurface = Color(.systemBackground)
    static let softSurface = Color(.tertiarySystemBackground)
}

private struct TranslationPracticePrompt: Identifiable {
    let id: UUID
    let apiContentId: String?
    let sourceText: String
    let expectedTranslation: String
    let hint: String
    let wordBank: [String]
    let level: LearningLevel

    init(
        apiContentId: String? = nil,
        sourceText: String,
        expectedTranslation: String,
        hint: String,
        wordBank: [String],
        level: LearningLevel
    ) {
        self.id = UUID()
        self.apiContentId = apiContentId
        self.sourceText = sourceText
        self.expectedTranslation = expectedTranslation
        self.hint = hint
        self.wordBank = wordBank
        self.level = level
    }

    init?(remote: LocupomRemotePracticeExercise, fallbackLevel: LearningLevel) {
        let sourceText = remote.sourceText?.trimmed ?? remote.prompt?.trimmed ?? remote.instruction.trimmed
        guard let expectedTranslation = remote.expectedTranslation?.trimmed, !sourceText.isEmpty, !expectedTranslation.isEmpty else {
            return nil
        }

        self.init(
            apiContentId: remote.id,
            sourceText: sourceText,
            expectedTranslation: expectedTranslation,
            hint: remote.hint ?? remote.instruction,
            wordBank: remote.wordBank ?? expectedTranslation
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 2 },
            level: remote.level.trimmed.isEmpty ? fallbackLevel : LearningLevel.fromCEFRCode(remote.level)
        )
    }

    static func deck(for level: LearningLevel) -> [TranslationPracticePrompt] {
        all.filter { $0.level == level }
    }

    private static let all: [TranslationPracticePrompt] = [
        TranslationPracticePrompt(
            sourceText: "I like this song.",
            expectedTranslation: "Me gusta esta cancion.",
            hint: "Start with 'Me gusta...' when you talk about liking something.",
            wordBank: ["me", "gusta", "esta", "cancion"],
            level: .beginner
        ),
        TranslationPracticePrompt(
            sourceText: "Can you help me?",
            expectedTranslation: "Podes ayudarme?",
            hint: "Use a question form. In casual Spanish, 'Podes ayudarme?' works well.",
            wordBank: ["podes", "ayudarme", "por", "favor"],
            level: .beginner
        ),
        TranslationPracticePrompt(
            sourceText: "I am learning English.",
            expectedTranslation: "Estoy aprendiendo ingles.",
            hint: "For an action happening now, use 'estoy' + gerund.",
            wordBank: ["estoy", "aprendiendo", "ingles"],
            level: .beginner
        ),
        TranslationPracticePrompt(
            sourceText: "This is my friend.",
            expectedTranslation: "Este es mi amigo.",
            hint: "Use 'este es...' for 'this is' when introducing someone.",
            wordBank: ["este", "es", "mi", "amigo"],
            level: .beginner
        ),
        TranslationPracticePrompt(
            sourceText: "We need more time.",
            expectedTranslation: "Necesitamos mas tiempo.",
            hint: "The subject 'we' is already inside 'necesitamos'.",
            wordBank: ["necesitamos", "mas", "tiempo"],
            level: .beginner
        ),
        TranslationPracticePrompt(
            sourceText: "I’ve been looking forward to this trip for months.",
            expectedTranslation: "Hace meses que espero con ganas este viaje.",
            hint: "'Looking forward to' is more natural as 'esperar con ganas'.",
            wordBank: ["hace", "meses", "espero", "con", "ganas", "viaje"],
            level: .intermediate
        ),
        TranslationPracticePrompt(
            sourceText: "She is getting better every day.",
            expectedTranslation: "Ella mejora cada dia.",
            hint: "'Getting better' can be short and natural: 'mejora'.",
            wordBank: ["ella", "mejora", "cada", "dia"],
            level: .intermediate
        ),
        TranslationPracticePrompt(
            sourceText: "Could you say that one more time?",
            expectedTranslation: "Podrias decir eso una vez mas?",
            hint: "'Could you...' usually becomes 'Podrias...?'",
            wordBank: ["podrias", "decir", "eso", "una", "vez", "mas"],
            level: .intermediate
        ),
        TranslationPracticePrompt(
            sourceText: "I was about to call you.",
            expectedTranslation: "Estaba por llamarte.",
            hint: "'About to' often maps to 'estar por'.",
            wordBank: ["estaba", "por", "llamarte"],
            level: .intermediate
        ),
        TranslationPracticePrompt(
            sourceText: "The meaning depends on the context.",
            expectedTranslation: "El significado depende del contexto.",
            hint: "This one can stay close to the English structure.",
            wordBank: ["significado", "depende", "del", "contexto"],
            level: .intermediate
        ),
        TranslationPracticePrompt(
            sourceText: "Although the song is fast, I can follow it.",
            expectedTranslation: "Aunque la cancion es rapida, puedo seguirla.",
            hint: "'Although' is 'aunque'. Keep the contrast in one sentence.",
            wordBank: ["aunque", "cancion", "rapida", "puedo", "seguirla"],
            level: .advanced
        ),
        TranslationPracticePrompt(
            sourceText: "I would rather practice before speaking.",
            expectedTranslation: "Preferiria practicar antes de hablar.",
            hint: "'Would rather' can be expressed as 'preferiria'.",
            wordBank: ["preferiria", "practicar", "antes", "hablar"],
            level: .advanced
        ),
        TranslationPracticePrompt(
            sourceText: "She has been improving since last month.",
            expectedTranslation: "Ella viene mejorando desde el mes pasado.",
            hint: "For an ongoing change, 'viene mejorando' sounds natural.",
            wordBank: ["ella", "viene", "mejorando", "desde", "mes", "pasado"],
            level: .advanced
        ),
        TranslationPracticePrompt(
            sourceText: "I could barely understand what he was saying.",
            expectedTranslation: "Apenas pude entender lo que estaba diciendo.",
            hint: "'Barely' is usually 'apenas'.",
            wordBank: ["apenas", "pude", "entender", "estaba", "diciendo"],
            level: .advanced
        ),
        TranslationPracticePrompt(
            sourceText: "Eventually, I understood why the singer changed the tense.",
            expectedTranslation: "Con el tiempo entendi por que el cantante cambio el tiempo verbal.",
            hint: "'Eventually' is not always 'eventualmente'; here 'con el tiempo' is more natural.",
            wordBank: ["con", "tiempo", "entendi", "cantante", "cambio", "verbal"],
            level: .advanced
        )
    ]
}

private struct TranslationPracticeFeedback {
    let accuracy: Double
    let grammar: Double
    let naturalness: Double
    let isStrong: Bool
}

private struct TranslatePracticeBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            TranslateDotPattern()
                .foregroundStyle(TranslateTheme.secondary.opacity(0.20))
                .frame(width: 118, height: 90)
                .padding(.top, 24)
                .padding(.trailing, 18)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(TranslateTheme.primary.opacity(0.08))
                .frame(width: 260, height: 260)
                .offset(x: -140, y: 120)
        }
    }

    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.04, green: 0.06, blue: 0.13),
                Color(red: 0.08, green: 0.08, blue: 0.20),
                Color(red: 0.03, green: 0.09, blue: 0.12)
            ]
        }

        return [
            Color(red: 0.98, green: 0.99, blue: 1.0),
            Color(red: 0.93, green: 0.95, blue: 1.0),
            Color(red: 0.98, green: 0.99, blue: 1.0)
        ]
    }
}

private struct TopicsLearningBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            TranslateDotPattern()
                .foregroundStyle(TranslateTheme.secondary.opacity(0.20))
                .frame(width: 132, height: 96)
                .padding(.top, 54)
                .padding(.trailing, 14)
        }
        .overlay(alignment: .topLeading) {
            Image(systemName: "sparkle")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.12))
                .rotationEffect(.degrees(8))
                .padding(.top, 72)
                .padding(.leading, 206)
        }
        .overlay(alignment: .bottomTrailing) {
            LocupomDotPattern()
                .foregroundStyle(TranslateTheme.primary.opacity(0.10))
                .frame(width: 118, height: 84)
                .padding(.bottom, 88)
                .padding(.trailing, 20)
        }
    }

    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.04, green: 0.07, blue: 0.15),
                Color(red: 0.08, green: 0.06, blue: 0.18),
                Color(red: 0.03, green: 0.10, blue: 0.12)
            ]
        }

        return [
            Color(red: 0.94, green: 0.97, blue: 1.0),
            Color(red: 0.98, green: 0.96, blue: 1.0),
            Color(red: 0.92, green: 0.99, blue: 1.0)
        ]
    }
}

private struct TranslateDotPattern: View {
    private let columns = Array(repeating: GridItem(.fixed(9), spacing: 8), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(0..<36, id: \.self) { _ in
                Circle()
                    .frame(width: 4, height: 4)
            }
        }
    }
}

private struct ExerciseSessionTopBar: View {
    let title: String?
    let closeAction: () -> Void

    var body: some View {
        ZStack {
            HStack {
                Button(action: closeAction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(TranslateTheme.ink)
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cerrar")

                Spacer(minLength: 0)
            }

            if let title {
                Text(title)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(TranslateTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 54)
            }
        }
        .frame(height: 42)
    }
}

private struct TranslateLessonHeader: View {
    let lessonNumber: Int
    let totalLessons: Int
    let progress: Double
    let closeAction: (() -> Void)?

    var body: some View {
        ZStack {
            HStack(spacing: 12) {
                if let closeAction {
                    Button(action: closeAction) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(TranslateTheme.ink)
                            .frame(width: 42, height: 42)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear
                        .frame(width: 42, height: 42)
                }

                Spacer(minLength: 0)
            }

            Text("Práctica")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(TranslateTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 54)
        }
        .frame(height: 42)
    }
}

private struct TranslateProgressSegments: View {
    let progress: Double
    private let segmentCount = 5

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<segmentCount, id: \.self) { index in
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(red: 0.86, green: 0.88, blue: 0.95))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [TranslateTheme.primary, TranslateTheme.secondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: proxy.size.width * fillAmount(for: index))
                    }
                }
                .frame(height: 8)
            }
        }
    }

    private func fillAmount(for index: Int) -> Double {
        let scaled = progress * Double(segmentCount)
        return min(max(scaled - Double(index), 0), 1)
    }
}

private struct TranslatePromptCard: View {
    let prompt: String
    let speakAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(prompt)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(TranslateTheme.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.top, 62)
                .padding(.bottom, 34)
        }
        .background(TranslateTheme.surface.opacity(0.98), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(alignment: .top) {
            Button(action: speakAction) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 25, weight: .black))
                    .foregroundStyle(TranslateTheme.primary)
                    .frame(width: 64, height: 64)
                    .background(TranslateTheme.softSurface, in: Circle())
            }
            .buttonStyle(.plain)
            .offset(y: -32)
        }
        .padding(.top, 32)
        .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 22, x: 0, y: 12)
    }
}

private struct TranslateAnswerEditor: View {
    @Binding var answer: String
    let limit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your translation")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(TranslateTheme.muted)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $answer)
                    .frame(minHeight: 210)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 0)
                    .padding(.vertical, 0)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(TranslateTheme.ink)
                    .onChange(of: answer) { _, newValue in
                        if newValue.count > limit {
                            answer = String(newValue.prefix(limit))
                        }
                    }

                if answer.isEmpty {
                    Text("Escribí tu versión en español...")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(TranslateTheme.muted.opacity(0.58))
                        .padding(.top, 7)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 258, alignment: .topLeading)
        .background(TranslateTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(TranslateTheme.primary.opacity(0.78), lineWidth: 1.4)
        }
        .overlay(alignment: .bottomTrailing) {
            Text("\(answer.count) / \(limit)")
                .font(.system(size: 18, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(TranslateTheme.muted)
                .padding(18)
        }
        .shadow(color: TranslateTheme.primary.opacity(0.04), radius: 14, x: 0, y: 8)
    }
}

private struct TranslateAssistActions: View {
    let hintAction: () -> Void
    let wordBankAction: () -> Void
    let exampleAction: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            ExerciseActionChip(title: "Pista", systemImage: "lightbulb", action: hintAction)
            ExerciseActionChip(title: "Banco de palabras", systemImage: "rectangle.split.2x1", action: wordBankAction)
            ExerciseActionChip(title: "Ejemplo", systemImage: "sparkles", action: exampleAction)
        }
    }
}

private struct ExerciseActionChip: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(TranslateTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.70)
                .padding(.horizontal, 12)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .background(TranslateTheme.surface.opacity(0.96), in: Capsule())
        .shadow(color: TranslateTheme.primary.opacity(0.10), radius: 16, x: 0, y: 8)
    }
}

private struct TranslateActionChip: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(TranslateTheme.ink)
        .background(TranslateTheme.surface, in: Capsule())
        .shadow(color: TranslateTheme.primary.opacity(0.06), radius: 10, x: 0, y: 5)
    }
}

private struct TranslateInfoCard: View {
    let systemImage: String
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(TranslateTheme.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(TranslateTheme.muted)
                    .lineLimit(4)
            }

            Spacer()
        }
        .padding(14)
        .background(TranslateTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: TranslateTheme.primary.opacity(0.06), radius: 14, x: 0, y: 8)
    }
}

private struct TranslateWordBank: View {
    let words: [String]
    let insert: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Word bank")
                .font(.subheadline.bold())
                .foregroundStyle(TranslateTheme.ink)

            FlowLayout(spacing: 8) {
                ForEach(words, id: \.self) { word in
                    Button {
                        insert(word)
                    } label: {
                        Text(word)
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(TranslateTheme.primary)
                    .background(TranslateTheme.primary.opacity(0.08), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(TranslateTheme.primary.opacity(0.25), lineWidth: 1)
                    }
                }
            }
        }
        .padding(14)
        .background(TranslateTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: TranslateTheme.primary.opacity(0.06), radius: 14, x: 0, y: 8)
    }
}

private struct TranslateAxoTipCard: View {
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image("Ajolote_Home")
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 84)
                .shadow(color: Color(red: 1.0, green: 0.75, blue: 0.18).opacity(0.18), radius: 10, x: 0, y: 6)

            VStack(alignment: .leading, spacing: 10) {
                Text("Axo tip")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(TranslateTheme.ink)

                Text("Keep the meaning first. Your answer doesn’t need to copy every word.")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(TranslateTheme.muted)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    TranslateTipPill(title: "Meaning", tint: TranslateTheme.secondary)
                    TranslateTipPill(title: "Natural", tint: TranslateTheme.mint)
                    TranslateTipPill(title: "Grammar", tint: .orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(TranslateTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: TranslateTheme.primary.opacity(0.06), radius: 18, x: 0, y: 10)
    }
}

private struct TranslateTipPill: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .black, design: .rounded))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.74)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

private struct TranslateFeedbackCard: View {
    let feedback: TranslationPracticeFeedback?
    let corrections: [WritingCorrection]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(TranslateTheme.secondary)

                Text(feedback == nil ? "Feedback preview" : "Feedback")
                    .font(.headline)
                    .foregroundStyle(TranslateTheme.ink)

                Spacer()

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            TranslateMetricRow(
                title: "Accuracy",
                detail: feedback == nil ? "Will evaluate word choice and overall correctness." : "Meaning compared with the target idea.",
                systemImage: "target",
                tint: TranslateTheme.mint,
                value: feedback?.accuracy
            )

            Divider()

            TranslateMetricRow(
                title: "Grammar",
                detail: feedback == nil ? "Will check structure and agreement." : "\(corrections.count) issue\(corrections.count == 1 ? "" : "s") found by LanguageTool.",
                systemImage: "pencil",
                tint: TranslateTheme.secondary,
                value: feedback?.grammar
            )

            Divider()

            TranslateMetricRow(
                title: "Naturalness",
                detail: feedback == nil ? "Will assess how natural your translation sounds." : "Balanced score from meaning, grammar and length.",
                systemImage: "bubble.left.and.bubble.right.fill",
                tint: TranslateTheme.primary,
                value: feedback?.naturalness
            )
        }
        .padding(16)
        .background(TranslateTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

private struct TranslateMetricRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
    let value: Double?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(TranslateTheme.ink)

                    Spacer()

                    Text(value.map { "\(Int($0 * 100))%" } ?? "--")
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(TranslateTheme.ink)
                }

                TranslateScoreBars(value: value, tint: tint)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(TranslateTheme.muted)
                    .lineLimit(2)
            }
        }
    }
}

private struct TranslateScoreBars: View {
    let value: Double?
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<6, id: \.self) { index in
                Capsule()
                    .fill(isFilled(index) ? tint : Color(red: 0.86, green: 0.88, blue: 0.95))
                    .frame(width: 20, height: 7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func isFilled(_ index: Int) -> Bool {
        guard let value else { return false }
        return Double(index + 1) / 6 <= value + 0.001
    }
}

private struct TranslatePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: isEnabled
                        ? [TranslateTheme.primary, TranslateTheme.secondary]
                        : [Color.gray.opacity(0.45), Color.gray.opacity(0.35)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct TranslateSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .black, design: .rounded))
            .foregroundStyle(isEnabled ? TranslateTheme.primary : TranslateTheme.muted.opacity(0.62))
            .padding(.vertical, 15)
            .background(TranslateTheme.primary.opacity(isEnabled ? 0.10 : 0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct VocabularyPracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var learningProgress: LearningProgressStore
    @State private var index = 0
    @State private var answer = ""
    @State private var feedback: LearningFeedback?
    @State private var isShowingAnswer = false
    @State private var remoteCards: [VocabularyCard] = []
    @State private var loadedRemoteLevel: TopicCEFRLevel?
    @State private var isLoadingCards = false

    private var selectedCEFRLevel: TopicCEFRLevel {
        TopicCEFRLevel(rawValue: learningProgress.cefrLevelCode) ?? TopicCEFRLevel(profileLevel: learningProgress.profile.level)
    }

    private var level: LearningLevel {
        selectedCEFRLevel.fallbackLearningLevel
    }

    private var cards: [VocabularyCard] {
        remoteCards.isEmpty ? VocabularyCard.deck(for: level) : remoteCards
    }

    var body: some View {
        let safeIndex = min(index, max(cards.count - 1, 0))
        let card = cards[safeIndex]

        ZStack {
            TranslatePracticeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ExerciseSessionTopBar(
                        title: "Vocabulario",
                        closeAction: { dismiss() }
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Palabras útiles")
                            .font(.system(size: 39, weight: .black, design: .rounded))
                            .foregroundStyle(TranslateTheme.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)

                        Text("Recordá la palabra desde su significado.")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(TranslateTheme.muted)
                    }

                    if isLoadingCards {
                        Label("Cargando...", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(TranslateTheme.muted)
                    }

                    ProgressHeader(currentIndex: safeIndex, total: cards.count)

                    VStack(alignment: .leading, spacing: 16) {
                        Label("Adaptado a \(level.title)", systemImage: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(TranslateTheme.primary)

                        Text(card.translation)
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(TranslateTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(card.definition)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(TranslateTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)

                        TextField("Escribí la palabra en inglés", text: $answer)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .padding(16)
                            .background(TranslateTheme.softSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(TranslateTheme.primary.opacity(0.16), lineWidth: 1)
                            }
                            .onSubmit { validate(card) }

                        if isShowingAnswer {
                            ExampleBox(title: card.word, bodyText: card.example)
                        }

                        if let feedback {
                            LearningFeedbackView(feedback: feedback)
                        }

                        HStack(spacing: 10) {
                            Button {
                                validate(card)
                            } label: {
                                Label("Comprobar", systemImage: "checkmark")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(TranslatePrimaryButtonStyle())
                            .disabled(answer.trimmed.isEmpty)

                            Button {
                                isShowingAnswer.toggle()
                            } label: {
                                Label(level.showsExtraHints ? "Ayuda" : "Ejemplo", systemImage: "lightbulb")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(TranslateSecondaryButtonStyle())
                        }

                        Button {
                            moveNext()
                        } label: {
                            Label("Siguiente", systemImage: "arrow.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(TranslateSecondaryButtonStyle())
                    }
                    .padding(22)
                    .background(TranslateTheme.surface.opacity(0.97), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 24, x: 0, y: 12)
                }
                .padding(.horizontal, 26)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task(id: selectedCEFRLevel) {
            await loadVocabulary(for: selectedCEFRLevel)
        }
        .onChange(of: learningProgress.cefrLevelCode) { _, _ in
            index = 0
            remoteCards = []
            loadedRemoteLevel = nil
            answer = ""
            feedback = nil
            isShowingAnswer = false
        }
    }

    @MainActor
    private func loadVocabulary(for selectedLevel: TopicCEFRLevel, forceRefresh: Bool = false) async {
        if !forceRefresh, loadedRemoteLevel == selectedLevel, !remoteCards.isEmpty {
            return
        }

        isLoadingCards = true

        do {
            let response = try await LocupomTopicsAPIClient.fetchVocabulary(
                level: selectedLevel.rawValue,
                learnerId: learningProgress.apiLearnerId,
                completedKeys: Array(learningProgress.completedRemoteContentKeys)
            )
            let mappedCards = response.vocabulary.compactMap {
                VocabularyCard(remote: $0, fallbackLevel: selectedLevel.fallbackLearningLevel)
            }

            loadedRemoteLevel = selectedLevel
            remoteCards = mappedCards
            index = 0
            answer = ""
            feedback = nil
            isShowingAnswer = false
        } catch {
            remoteCards = []
            loadedRemoteLevel = selectedLevel
        }

        isLoadingCards = false
    }

    private func validate(_ card: VocabularyCard) {
        let result = TextMatcher.evaluate(answer: answer, target: card.word)
        let isCorrect = level.acceptsCloseAnswers ? result.isCorrect : result.isExact
        learningProgress.recordModule(LearningModule.vocabulary.rawValue, wasCorrect: isCorrect)
        learningProgress.saveWord(word: card.word, note: card.translation, source: "Vocabulario")
        if isCorrect {
            learningProgress.recordErrorResolved(module: LearningModule.vocabulary.rawValue, expected: card.word)
            markVocabularyCompletedIfNeeded(card)
        } else {
            learningProgress.recordError(
                module: LearningModule.vocabulary.rawValue,
                expected: card.word,
                actual: answer,
                context: card.translation
            )
        }

        feedback = LearningFeedback(
            title: isCorrect ? "Muy bien" : result.isClose ? "Casi" : "Probemos otra vez",
            detail: isCorrect ? card.example : "Respuesta esperada: \(card.word)",
            score: result.similarity,
            isCorrect: isCorrect
        )
    }

    private func markVocabularyCompletedIfNeeded(_ card: VocabularyCard) {
        guard let apiContentId = card.apiContentId else {
            return
        }

        let learnerId = learningProgress.apiLearnerId
        let completedLevel = selectedCEFRLevel.rawValue
        let completedTitle = card.word
        let didInsert = learningProgress.markRemoteContentCompleted(kind: "vocabulary", itemId: apiContentId)
        guard didInsert else {
            return
        }

        Task {
            try? await LocupomTopicsAPIClient.markCompleted(
                learnerId: learnerId,
                kind: "vocabulary",
                itemId: apiContentId,
                level: completedLevel,
                title: completedTitle
            )
        }
    }

    private func moveNext() {
        index = (index + 1) % cards.count
        answer = ""
        feedback = nil
        isShowingAnswer = false
    }
}

private struct ListeningPracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var learningProgress: LearningProgressStore
    @StateObject private var speaker = PromptSpeaker()
    @State private var index = 0
    @State private var answer = ""
    @State private var selectedWords: [String] = []
    @State private var feedback: LearningFeedback?
    @State private var lastCheckedAnswer = ""
    @State private var remoteItems: [ListeningItem] = []
    @State private var loadedRemoteLevel: TopicCEFRLevel?
    @State private var isLoadingItems = false

    private var selectedCEFRLevel: TopicCEFRLevel {
        TopicCEFRLevel(rawValue: learningProgress.cefrLevelCode) ?? TopicCEFRLevel(profileLevel: learningProgress.profile.level)
    }

    private var level: LearningLevel {
        selectedCEFRLevel.fallbackLearningLevel
    }

    private var items: [ListeningItem] {
        remoteItems.isEmpty ? ListeningItem.deck(for: level) : remoteItems
    }

    var body: some View {
        let safeIndex = min(index, max(items.count - 1, 0))
        let item = items[safeIndex]
        let challenge = ListeningClozeChallenge(item: item, deck: items, level: level)

        ZStack {
            TranslatePracticeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ExerciseSessionTopBar(
                        title: "Listening",
                        closeAction: { dismiss() }
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Listen & complete")
                            .font(.system(size: 39, weight: .black, design: .rounded))
                            .foregroundStyle(TranslateTheme.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)

                        Text("Catch the missing words.")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(TranslateTheme.muted)
                    }

                    if isLoadingItems {
                        Label("Cargando...", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(TranslateTheme.muted)
                    }

                    ListeningAudioCard(
                        title: challenge.trackTitle,
                        artist: challenge.artistName,
                        playAction: { speaker.speak(item.phrase, rate: level.speechRate) }
                    )

                    ListeningClozeCard(
                        challenge: challenge,
                        selectedWords: selectedWords,
                        feedback: feedback,
                        lastCheckedAnswer: lastCheckedAnswer,
                        chooseWord: { chooseWord($0, challenge: challenge) },
                        removeWord: removeWord
                    )

                    ListeningHelpCard()
                }
                .padding(.horizontal, 26)
                .padding(.top, 18)
                .padding(.bottom, 140)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                if feedback == nil {
                    validate(item, challenge: challenge)
                } else {
                    moveNext()
                }
            } label: {
                Text(feedback == nil ? "Check answers" : "Next line")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(TranslatePrimaryButtonStyle())
            .disabled(feedback == nil && selectedWords.count < challenge.answerWords.count)
            .padding(.horizontal, 26)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task(id: selectedCEFRLevel) {
            await loadListeningItems(for: selectedCEFRLevel)
        }
        .onChange(of: learningProgress.cefrLevelCode) { _, _ in
            index = 0
            remoteItems = []
            loadedRemoteLevel = nil
            answer = ""
            selectedWords = []
            feedback = nil
            lastCheckedAnswer = ""
        }
    }

    @MainActor
    private func loadListeningItems(for selectedLevel: TopicCEFRLevel, forceRefresh: Bool = false) async {
        if !forceRefresh, loadedRemoteLevel == selectedLevel, !remoteItems.isEmpty {
            return
        }

        isLoadingItems = true

        do {
            let response = try await LocupomTopicsAPIClient.fetchPracticeExercises(
                skill: "listening",
                level: selectedLevel.rawValue,
                learnerId: learningProgress.apiLearnerId,
                completedKeys: Array(learningProgress.completedRemoteContentKeys)
            )
            let mappedItems = response.exercises.compactMap {
                ListeningItem(remote: $0, fallbackLevel: selectedLevel.fallbackLearningLevel)
            }

            loadedRemoteLevel = selectedLevel
            remoteItems = mappedItems
            index = 0
            answer = ""
            selectedWords = []
            feedback = nil
            lastCheckedAnswer = ""
        } catch {
            remoteItems = []
            loadedRemoteLevel = selectedLevel
        }

        isLoadingItems = false
    }

    private func chooseWord(_ word: String, challenge: ListeningClozeChallenge) {
        feedback = nil
        lastCheckedAnswer = ""

        if selectedWords.contains(word) {
            removeWord(word)
        } else if selectedWords.count < challenge.answerWords.count {
            selectedWords.append(word)
        }

        answer = challenge.completedPhrase(with: selectedWords)
    }

    private func removeWord(_ word: String) {
        selectedWords.removeAll { $0 == word }
        feedback = nil
        lastCheckedAnswer = ""
    }

    private func validate(_ item: ListeningItem, challenge: ListeningClozeChallenge) {
        let checkedAnswer = challenge.completedPhrase(with: selectedWords)
        answer = checkedAnswer
        lastCheckedAnswer = checkedAnswer
        let result = TextMatcher.evaluate(answer: checkedAnswer, target: item.phrase)
        let isCorrect = level.acceptsCloseAnswers ? result.isClose : result.isExact
        learningProgress.recordModule(LearningModule.listening.rawValue, wasCorrect: isCorrect)
        if isCorrect {
            learningProgress.recordErrorResolved(module: LearningModule.listening.rawValue, expected: item.phrase)
            markListeningCompletedIfNeeded(item)
        } else {
            learningProgress.recordError(
                module: LearningModule.listening.rawValue,
                expected: item.phrase,
                actual: answer,
                context: item.translation
            )
        }

        feedback = LearningFeedback(
            title: isCorrect ? "Bien escuchado" : result.isClose ? "Muy cerca" : "Escuchalo otra vez",
            detail: isCorrect ? item.phrase : "Respuesta esperada: \(item.phrase)",
            score: result.similarity,
            isCorrect: isCorrect
        )
    }

    private func markListeningCompletedIfNeeded(_ item: ListeningItem) {
        guard let apiContentId = item.apiContentId else {
            return
        }

        let learnerId = learningProgress.apiLearnerId
        let completedLevel = selectedCEFRLevel.rawValue
        let completedTitle = item.trackTitle
        let didInsert = learningProgress.markRemoteContentCompleted(kind: "exercise", itemId: apiContentId)
        guard didInsert else {
            return
        }

        Task {
            try? await LocupomTopicsAPIClient.markCompleted(
                learnerId: learnerId,
                kind: "exercise",
                itemId: apiContentId,
                level: completedLevel,
                title: completedTitle
            )
        }
    }

    private func moveNext() {
        index = (index + 1) % items.count
        answer = ""
        selectedWords = []
        lastCheckedAnswer = ""
        feedback = nil
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

private struct ListeningClozeChallenge {
    let item: ListeningItem
    let rawTokens: [String]
    let missingIndices: [Int]
    let answerWords: [String]
    let options: [String]
    let trackTitle: String
    let artistName: String

    init(item: ListeningItem, deck: [ListeningItem], level: LearningLevel) {
        let parsedTokens = item.phrase.split(separator: " ").map(String.init)

        let candidateIndices = parsedTokens.indices.filter { index in
            TextMatcher.normalize(parsedTokens[index]).count >= 3
        }
        let blankCount = min(level == .beginner ? 1 : 2, max(candidateIndices.count, 1))
        var chosenIndices: [Int] = []
        let preferredOffsets = [
            max(0, candidateIndices.count / 2),
            max(0, candidateIndices.count - 2),
            max(0, candidateIndices.count / 3),
            0
        ]

        for offset in preferredOffsets where chosenIndices.count < blankCount {
            guard candidateIndices.indices.contains(offset) else { continue }
            let candidate = candidateIndices[offset]
            if !chosenIndices.contains(candidate) {
                chosenIndices.append(candidate)
            }
        }

        if chosenIndices.isEmpty, let firstCandidate = candidateIndices.first {
            chosenIndices = [firstCandidate]
        }

        let sortedMissingIndices = chosenIndices.sorted()
        let resolvedAnswerWords = sortedMissingIndices.map { TextMatcher.normalize(parsedTokens[$0]) }

        let answerSet = Set(resolvedAnswerWords)
        let distractors = deck
            .flatMap { $0.phrase.split(separator: " ").map(String.init) }
            .map { TextMatcher.normalize($0) }
            .filter { !$0.isEmpty && $0.count >= 3 && !answerSet.contains($0) }
            .uniqued()

        var builtOptions: [String] = []
        if let firstDistractor = distractors.first {
            builtOptions.append(firstDistractor)
        }
        builtOptions.append(contentsOf: resolvedAnswerWords)
        builtOptions.append(contentsOf: distractors.dropFirst().prefix(max(2, 4 - builtOptions.count)))

        self.item = item
        rawTokens = parsedTokens
        missingIndices = sortedMissingIndices
        answerWords = resolvedAnswerWords
        options = Array(builtOptions.uniqued().prefix(max(4, resolvedAnswerWords.count + 2)))

        trackTitle = item.trackTitle
        artistName = item.artistName
    }

    func displayPhrase(with selectedWords: [String]) -> String {
        rawTokens.enumerated().map { index, token in
            guard let answerPosition = missingIndices.firstIndex(of: index) else {
                return token
            }

            if selectedWords.indices.contains(answerPosition) {
                return selectedWords[answerPosition]
            }

            return "____"
        }
        .joined(separator: " ")
    }

    func completedPhrase(with selectedWords: [String]) -> String {
        rawTokens.enumerated().map { index, token in
            guard let answerPosition = missingIndices.firstIndex(of: index) else {
                return token
            }

            return selectedWords.indices.contains(answerPosition) ? selectedWords[answerPosition] : "____"
        }
        .joined(separator: " ")
    }
}

private struct ListeningAudioCard: View {
    let title: String
    let artist: String
    let playAction: () -> Void

    private let barHeights: [CGFloat] = [13, 22, 17, 35, 19, 27, 14, 31]

    var body: some View {
        VStack(spacing: -6) {
            HStack(spacing: 24) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [TranslateTheme.primary, TranslateTheme.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: "pentagon.fill")
                        .font(.system(size: 62, weight: .black))
                        .foregroundStyle(.white)
                }
                .frame(width: 104, height: 104)

                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(TranslateTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(artist)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(TranslateTheme.muted)

                    HStack(alignment: .bottom, spacing: 9) {
                        ForEach(Array(barHeights.enumerated()), id: \.offset) { index, height in
                            Capsule()
                                .fill(index % 3 == 0 ? TranslateTheme.secondary : TranslateTheme.primary.opacity(0.42))
                                .frame(width: 8, height: height)
                        }
                    }
                    .padding(.top, 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: playAction) {
                Image(systemName: "play.fill")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 70, height: 70)
                    .background(TranslateTheme.primary, in: Circle())
                    .shadow(color: TranslateTheme.primary.opacity(0.22), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .offset(y: -10)
        }
        .padding(.horizontal, 22)
        .padding(.top, 24)
        .padding(.bottom, 8)
        .background(TranslateTheme.surface.opacity(0.97), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color(red: 0.82, green: 0.87, blue: 1.0).opacity(0.62), lineWidth: 1)
        }
        .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 24, x: 0, y: 12)
    }
}

private struct ListeningClozeCard: View {
    let challenge: ListeningClozeChallenge
    let selectedWords: [String]
    let feedback: LearningFeedback?
    let lastCheckedAnswer: String
    let chooseWord: (String) -> Void
    let removeWord: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(challenge.displayPhrase(with: selectedWords))
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundStyle(TranslateTheme.ink)
                .lineSpacing(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            FlowLayout(spacing: 10) {
                ForEach(challenge.options, id: \.self) { word in
                    Button {
                        chooseWord(word)
                    } label: {
                        Text(word)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(TranslateTheme.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(.plain)
                    .background(selectedWords.contains(word) ? TranslateTheme.primary.opacity(0.13) : TranslateTheme.elevatedSurface, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(TranslateTheme.primary.opacity(selectedWords.contains(word) ? 0.95 : 0.58), lineWidth: 1.2)
                    }
                }
            }

            if !selectedWords.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(selectedWords, id: \.self) { word in
                        Button {
                            removeWord(word)
                        } label: {
                            Label(word, systemImage: "xmark.circle.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(TranslateTheme.ink)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                        }
                        .buttonStyle(.plain)
                        .background(TranslateTheme.softSurface, in: Capsule())
                    }
                }
            }

            if let feedback {
                LearningFeedbackView(feedback: feedback)

                if !feedback.isCorrect {
                    LearningWordDiffView(answer: lastCheckedAnswer, target: challenge.item.phrase)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
        .background(TranslateTheme.surface.opacity(0.97), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 24, x: 0, y: 12)
    }
}

private struct ListeningHelpCard: View {
    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: "sparkle")
                .font(.system(size: 27, weight: .black))
                .foregroundStyle(TranslateTheme.mint)
                .frame(width: 66, height: 66)
                .background(TranslateTheme.mint.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 8) {
                Text("Need help?")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(TranslateTheme.ink)

                Text("Try slow mode or replay one line.")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(TranslateTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .background(TranslateTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: TranslateTheme.primary.opacity(0.06), radius: 18, x: 0, y: 10)
    }
}

private struct SentenceBuilderPracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var learningProgress: LearningProgressStore
    @State private var index = 0
    @State private var availableTokens: [WordToken] = []
    @State private var selectedTokens: [WordToken] = []
    @State private var feedback: LearningFeedback?
    @State private var puzzles: [SentencePuzzle] = []
    @State private var isLoadingMore = false
    @State private var isLoadingInitialPuzzles = false
    @State private var sourceMessage = "Estas primeras frases vienen incluidas en la app."
    @State private var errorMessage: String?
    @State private var recordedCorrectPuzzleIDs = Set<UUID>()
    @State private var lastCheckedAnswer = ""
    @State private var loadedRemoteLevel: TopicCEFRLevel?

    private let service = LanguageLearningService()

    private var selectedCEFRLevel: TopicCEFRLevel {
        TopicCEFRLevel(rawValue: learningProgress.cefrLevelCode) ?? TopicCEFRLevel(profileLevel: learningProgress.profile.level)
    }

    private var level: LearningLevel {
        selectedCEFRLevel.fallbackLearningLevel
    }

    private var activePuzzles: [SentencePuzzle] {
        puzzles.isEmpty ? SentencePuzzle.deck(for: level) : puzzles
    }

    var body: some View {
        if activePuzzles.isEmpty {
            ZStack {
                TranslatePracticeBackground()
                ContentUnavailableView("No hay frases para este nivel", systemImage: "text.word.spacing")
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
        } else {
            let safeIndex = min(index, max(activePuzzles.count - 1, 0))
            let puzzle = activePuzzles[safeIndex]
            let isLastPuzzle = safeIndex == activePuzzles.count - 1

            ZStack {
                TranslatePracticeBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ExerciseSessionTopBar(
                            title: "Frases",
                            closeAction: { dismiss() }
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Armá oraciones")
                                .font(.system(size: 39, weight: .black, design: .rounded))
                                .foregroundStyle(TranslateTheme.ink)
                                .lineLimit(2)
                                .minimumScaleFactor(0.78)

                            Text("Ordená las palabras y controlá el significado.")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundStyle(TranslateTheme.muted)
                        }

                        ProgressHeader(currentIndex: safeIndex, total: activePuzzles.count)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                Label(puzzle.source, systemImage: "quote.bubble")
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                    .foregroundStyle(TranslateTheme.primary)

                                Spacer()

                                Button {
                                    Task { await loadMorePuzzles() }
                                } label: {
                                    Label(isLoadingMore ? "Buscando" : "Más", systemImage: "arrow.down.circle")
                                        .font(.system(size: 13, weight: .black, design: .rounded))
                                        .foregroundStyle(TranslateTheme.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(TranslateTheme.primary.opacity(0.10), in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .disabled(isLoadingMore || isLoadingInitialPuzzles)
                            }

                            if isLoadingInitialPuzzles {
                                Label("Cargando...", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(TranslateTheme.muted)
                            }

                            Text(sourceMessage)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(TranslateTheme.muted)

                            Label("Adaptado a \(level.title): \(level.sentenceWordRange.lowerBound)-\(level.sentenceWordRange.upperBound) palabras", systemImage: "slider.horizontal.3")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(TranslateTheme.muted)

                            if let errorMessage {
                                Label(errorMessage, systemImage: "exclamationmark.triangle")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(16)
                        .background(TranslateTheme.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                        VStack(alignment: .leading, spacing: 16) {
                            Text(puzzle.translation)
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundStyle(TranslateTheme.ink)
                                .fixedSize(horizontal: false, vertical: true)

                            TokenArea(title: "Tu frase", tokens: selectedTokens) { token in
                                selectedTokens.removeAll { $0.id == token.id }
                                availableTokens.append(token)
                                feedback = nil
                            }

                            TokenArea(title: "Palabras disponibles", tokens: availableTokens) { token in
                                availableTokens.removeAll { $0.id == token.id }
                                selectedTokens.append(token)
                                feedback = nil
                                autoValidateIfComplete(puzzle)
                            }

                            if let feedback {
                                LearningFeedbackView(feedback: feedback)
                                if !feedback.isCorrect {
                                    LearningWordDiffView(answer: lastCheckedAnswer, target: puzzle.answer)
                                }
                            }

                            HStack(spacing: 10) {
                                Button {
                                    validate(puzzle)
                                } label: {
                                    Label("Comprobar", systemImage: "checkmark")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(TranslatePrimaryButtonStyle())
                                .disabled(selectedTokens.isEmpty)

                                Button {
                                    resetPuzzle(puzzle)
                                } label: {
                                    Label("Reiniciar", systemImage: "arrow.counterclockwise")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(TranslateSecondaryButtonStyle())
                            }

                            Button {
                                Task { await moveNextOrLoadMore() }
                            } label: {
                                Label(
                                    isLastPuzzle ? (isLoadingMore ? "Buscando" : "Siguiente tanda") : "Siguiente",
                                    systemImage: isLastPuzzle ? "arrow.down.circle" : "arrow.right"
                                )
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(TranslateSecondaryButtonStyle())
                            .disabled(isLoadingMore)
                        }
                        .padding(22)
                        .background(TranslateTheme.surface.opacity(0.97), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 24, x: 0, y: 12)
                    }
                    .padding(.horizontal, 26)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .task(id: selectedCEFRLevel) {
                await loadInitialPuzzles(for: selectedCEFRLevel)
            }
            .onAppear {
                if availableTokens.isEmpty && selectedTokens.isEmpty {
                    resetPuzzle(puzzle)
                }
            }
            .onChange(of: index) { _, newValue in
                guard activePuzzles.indices.contains(newValue) else { return }
                resetPuzzle(activePuzzles[newValue])
            }
            .onChange(of: learningProgress.cefrLevelCode) { _, _ in
                puzzles = []
                loadedRemoteLevel = nil
                sourceMessage = "Estas primeras frases vienen incluidas en la app."
                errorMessage = nil
                recordedCorrectPuzzleIDs = []
                lastCheckedAnswer = ""
                index = 0
                availableTokens = []
                selectedTokens = []
                feedback = nil
                if let first = activePuzzles.first {
                    resetPuzzle(first)
                }
            }
        }
    }

    @MainActor
    private func loadInitialPuzzles(for selectedLevel: TopicCEFRLevel, forceRefresh: Bool = false) async {
        if !forceRefresh, loadedRemoteLevel == selectedLevel, !puzzles.isEmpty {
            return
        }

        isLoadingInitialPuzzles = true
        errorMessage = nil

        do {
            let response = try await LocupomTopicsAPIClient.fetchPracticeExercises(
                skill: "sentence_builder",
                level: selectedLevel.rawValue,
                learnerId: learningProgress.apiLearnerId,
                completedKeys: Array(learningProgress.completedRemoteContentKeys)
            )
            let mappedPuzzles = response.exercises.compactMap {
                SentencePuzzle(remote: $0, fallbackLevel: selectedLevel.fallbackLearningLevel)
            }

            loadedRemoteLevel = selectedLevel
            index = 0
            recordedCorrectPuzzleIDs = []
            lastCheckedAnswer = ""

            if mappedPuzzles.isEmpty {
                puzzles = []
                sourceMessage = "Frases locales para nivel \(selectedLevel.fallbackLearningLevel.title.lowercased())."
            } else {
                puzzles = mappedPuzzles
                sourceMessage = "Frases nuevas para tu nivel."
            }

            if let first = activePuzzles.first {
                resetPuzzle(first)
            }
        } catch {
            loadedRemoteLevel = selectedLevel
            puzzles = []
            sourceMessage = "Frases locales para nivel \(selectedLevel.fallbackLearningLevel.title.lowercased())."
        }

        isLoadingInitialPuzzles = false
    }

    @discardableResult
    private func validate(_ puzzle: SentencePuzzle) -> Bool {
        let answer = selectedTokens.map(\.text).joined(separator: " ")
        lastCheckedAnswer = answer
        let result = TextMatcher.evaluate(answer: answer, target: puzzle.answer)
        let isCorrect = level.acceptsCloseAnswers ? result.isCorrect : result.isExact
        if !isCorrect || recordedCorrectPuzzleIDs.insert(puzzle.id).inserted {
            learningProgress.recordModule(LearningModule.sentences.rawValue, wasCorrect: isCorrect)
        }
        if isCorrect {
            learningProgress.recordErrorResolved(module: LearningModule.sentences.rawValue, expected: puzzle.answer)
            markSentenceCompletedIfNeeded(puzzle)
        } else {
            learningProgress.recordError(
                module: LearningModule.sentences.rawValue,
                expected: puzzle.answer,
                actual: answer,
                context: puzzle.translation
            )
        }

        feedback = LearningFeedback(
            title: isCorrect ? "Correcto" : "Todavia no",
            detail: isCorrect ? puzzle.answer : "Orden correcto: \(puzzle.answer)",
            score: result.similarity,
            isCorrect: isCorrect
        )

        return isCorrect
    }

    private func markSentenceCompletedIfNeeded(_ puzzle: SentencePuzzle) {
        guard let apiContentId = puzzle.apiContentId else {
            return
        }

        let learnerId = learningProgress.apiLearnerId
        let completedLevel = selectedCEFRLevel.rawValue
        let completedTitle = puzzle.answer
        let didInsert = learningProgress.markRemoteContentCompleted(kind: "exercise", itemId: apiContentId)
        guard didInsert else {
            return
        }

        Task {
            try? await LocupomTopicsAPIClient.markCompleted(
                learnerId: learnerId,
                kind: "exercise",
                itemId: apiContentId,
                level: completedLevel,
                title: completedTitle
            )
        }
    }

    private func autoValidateIfComplete(_ puzzle: SentencePuzzle) {
        let expectedTokenCount = puzzle.answer.split(separator: " ").count
        guard selectedTokens.count == expectedTokenCount else { return }

        validate(puzzle)
    }

    private func resetPuzzle(_ puzzle: SentencePuzzle) {
        availableTokens = puzzle.answer
            .split(separator: " ")
            .map { WordToken(text: String($0)) }
            .shuffled()
        selectedTokens = []
        feedback = nil
        lastCheckedAnswer = ""
    }

    private func moveNextOrLoadMore() async {
        guard !activePuzzles.isEmpty else { return }

        if index >= activePuzzles.count - 1 {
            await loadMorePuzzles()
        } else {
            index += 1
        }
    }

    private func loadMorePuzzles() async {
        guard !isLoadingMore else { return }

        isLoadingMore = true
        errorMessage = nil

        let seedWords = (learningProgress.errorSeeds(limit: 4) + learningProgress.savedWords.map(\.word) + SentencePuzzle.seedWords(for: level))
            .shuffled()
            .prefix(4)
            .map { $0 }
        let examples = await service.fetchPracticeSentences(seedWords: seedWords, level: level, limit: level.practiceLimit)
        learningProgress.cacheSentences(examples)

        let sourceExamples = examples.isEmpty ? learningProgress.cachedSentenceExamples(limit: level.practiceLimit) : examples
        let fetchedPuzzles = sourceExamples.compactMap(SentencePuzzle.init(example:))

        if fetchedPuzzles.isEmpty {
            let fallbackPuzzles = SentencePuzzle.alternateDeck(
                for: level,
                excluding: Set(activePuzzles.map { TextMatcher.normalize($0.answer) })
            )
            puzzles = fallbackPuzzles
            index = 0
            if let first = fallbackPuzzles.first {
                resetPuzzle(first)
            }
            sourceMessage = "Tatoeba no devolvio frases nuevas para este nivel. Cargue una tanda local distinta."
            errorMessage = nil
        } else {
            puzzles = fetchedPuzzles.filter { $0.level == level }
            if puzzles.isEmpty {
                puzzles = fetchedPuzzles
            }
            index = 0
            resetPuzzle(puzzles[0])
            sourceMessage = examples.isEmpty
                ? "Use \(puzzles.count) frases guardadas en cache local."
                : "Traje \(puzzles.count) frases nuevas desde Tatoeba."
        }

        isLoadingMore = false
    }
}

private struct LocupomRemoteTopic: Decodable {
    let id: String
    let title: String
    let level: String
    let levelOrder: Int?
    let order: Int?
    let category: String
    let categoryLabel: String?
    let summary: String
    let pattern: String
    let sourceBasis: [String]?
    let lessonBlocks: [LocupomRemoteLessonBlock]?
    let learningObjectives: [String]
    let examples: [String]
    let commonMistakes: [String]
    let practiceIdeas: [String]?
    let practiceTasks: [LocupomRemotePracticeTask]?
    let externalResources: LocupomRemoteExternalResources?
    let quiz: LocupomRemoteTopicQuiz
    let source: LocupomRemoteTopicSource?
}

private struct LocupomRemoteLessonBlock: Decodable {
    let title: String
    let body: String
}

private struct LocupomRemotePracticeTask: Decodable {
    let id: String
    let kind: String
    let title: String
    let instruction: String
    let prompt: String
    let options: [String]
    let answer: String
    let explanation: String
}

private struct LocupomRemoteExternalResources: Decodable {
    let sourcePdf: LocupomRemoteExternalResource?
    let authenticExamples: LocupomRemoteExternalResource?
    let wordBank: LocupomRemoteExternalResource?
    let writingCheck: LocupomRemoteExternalResource?
}

private struct LocupomRemoteExternalResource: Decodable {
    let provider: String
    let query: String?
    let description: String?
    let documentId: String?
    let path: String?
    let pages: [Int]?
}

private struct LocupomRemoteTopicSource: Decodable {
    let documentId: String?
    let documentTitle: String?
    let fullText: String?
    let outlinePath: [String]?
    let pageStart: Int?
    let pageEnd: Int?
    let pdfPath: String?
}

private struct LocupomRemoteTopicQuiz: Decodable {
    let question: String
    let options: [String]
    let answer: String
    let explanation: String
}

private struct LocupomTopicsResponse: Decodable {
    let topics: [LocupomRemoteTopic]
}

private struct LocupomReadingResponse: Decodable {
    let provider: String
    let providerConfigured: Bool
    let providerError: String?
    let message: String?
    let reading: LocupomLevelledReading?
}

private struct LocupomLevelledReading: Identifiable, Decodable {
    let id: String
    let title: String
    let level: String
    let cefrLevel: String
    let topic: String
    let estimatedMinutes: Int
    let source: String
    let provider: String
    let summary: String
    let content: String
    let questions: [LocupomReadingQuestion]

    static func fallback(for level: TopicCEFRLevel) -> LocupomLevelledReading {
        let questions = [
            LocupomReadingQuestion(
                id: "offline-main",
                prompt: "What is the main idea?",
                options: ["Small regular practice helps learning.", "Learning only works with long texts.", "Grammar should be skipped."],
                answer: "Small regular practice helps learning.",
                explanation: "The text focuses on a short routine that can be repeated often."
            ),
            LocupomReadingQuestion(
                id: "offline-action",
                prompt: "Which action does the text suggest?",
                options: ["Choose three useful words.", "Read one long book every day.", "Avoid saying sentences aloud."],
                answer: "Choose three useful words.",
                explanation: "The text says to choose three useful words and say one sentence aloud."
            ),
            LocupomReadingQuestion(
                id: "offline-effect",
                prompt: "Why does the habit help?",
                options: ["It brings English into daily practice.", "It removes all grammar rules.", "It replaces listening practice."],
                answer: "It brings English into daily practice.",
                explanation: "The passage says the simple practice helps your brain meet English every day."
            )
        ]

        return LocupomLevelledReading(
            id: "offline-\(level.rawValue.lowercased())",
            title: "\(level.shortCode) Reading: A small habit",
            level: level.rawValue,
            cefrLevel: level.rawValue == "Pre-A1" ? "A1" : level.rawValue,
            topic: level.defaultReadingTopic,
            estimatedMinutes: 3,
            source: "Offline Locupom",
            provider: "offline",
            summary: "A short offline reading for \(level.shortCode).",
            content: "A small habit can make English feel easier. Read a short text, choose three useful words, and say one sentence aloud. The practice is simple, but it helps your brain meet English every day.",
            questions: questions
        )
    }
}

private struct LocupomReadingQuestion: Identifiable, Decodable {
    let id: String
    let prompt: String
    let options: [String]
    let answer: String
    let explanation: String
}

private struct LocupomSpeakingResponse: Decodable {
    let generatedAt: String?
    let count: Int
    let speakingPrompts: [LocupomRemoteSpeakingPrompt]
}

private struct LocupomRemoteSpeakingPrompt: Decodable {
    let id: String
    let level: String
    let title: String
    let prompt: String
    let support: [String]?
    let targetLanguage: [String]?
    let targetPhrase: String?
    let targetPhrases: [String]?
}

private struct LocupomPracticeExercisesResponse: Decodable {
    let generatedAt: String?
    let count: Int
    let exercises: [LocupomRemotePracticeExercise]
}

private struct LocupomRemotePracticeExercise: Decodable {
    let id: String
    let level: String
    let skill: String?
    let type: String?
    let title: String
    let instruction: String
    let prompt: String?
    let sourceText: String?
    let expectedTranslation: String?
    let hint: String?
    let wordBank: [String]?
    let phrase: String?
    let translation: String?
    let trackTitle: String?
    let artistName: String?
    let options: [String]?
    let answer: FlexibleStringArray?
    let explanation: String?
    let wordRange: [Int]?
    let vocabularyHelp: String?
    let grammarTip: String?
    let sampleAnswer: String?
    let vocabularyTargets: [String]?
    let source: String?
}

private enum FlexibleStringArray: Decodable {
    case string(String)
    case strings([String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            self = .strings((try? container.decode([String].self)) ?? [])
        }
    }

    var firstString: String? {
        switch self {
        case .string(let value):
            return value
        case .strings(let values):
            return values.first
        }
    }

    var strings: [String] {
        switch self {
        case .string(let value):
            return [value]
        case .strings(let values):
            return values
        }
    }
}

private struct LocupomVocabularyResponse: Decodable {
    let generatedAt: String?
    let count: Int
    let vocabulary: [LocupomRemoteVocabularyItem]
}

private struct LocupomRemoteVocabularyItem: Decodable {
    let id: String
    let level: String?
    let word: String
    let translation: String?
    let meaning: String?
    let usageNote: String?
    let example: String?
}

private enum TopicCEFRLevel: String, CaseIterable, Identifiable, Hashable {
    case preA1 = "Pre-A1"
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"
    case c2 = "C2"

    var id: Self { self }

    var shortCode: String {
        rawValue
    }

    var title: String {
        switch self {
        case .preA1: "Primer contacto"
        case .a1: "Principiante"
        case .a2: "Basico alto"
        case .b1: "Intermedio"
        case .b2: "Intermedio alto"
        case .c1: "Avanzado"
        case .c2: "Dominio"
        }
    }

    var detail: String {
        switch self {
        case .preA1: "Palabras, frases fijas y reconocimiento inicial."
        case .a1: "Presente, frases cortas, preguntas simples y vocabulario cotidiano."
        case .a2: "Rutinas, pasado simple, planes y comparaciones basicas."
        case .b1: "Tiempos principales, experiencias, opiniones y explicaciones simples."
        case .b2: "Matices, pasiva, reported speech, conditionals y textos mas naturales."
        case .c1: "Precision, registro, inversion, nominalizacion y estructuras avanzadas."
        case .c2: "Dominio fino, estilo, enfasis, idiomaticidad y control avanzado."
        }
    }

    var accent: Color {
        switch self {
        case .preA1:
            Color(red: 0.18, green: 0.59, blue: 0.98)
        case .a1:
            TranslateTheme.primary
        case .a2:
            Color(red: 0.34, green: 0.78, blue: 0.72)
        case .b1:
            Color(red: 0.95, green: 0.71, blue: 0.22)
        case .b2:
            Color(red: 0.97, green: 0.48, blue: 0.24)
        case .c1:
            Color(red: 0.74, green: 0.42, blue: 0.96)
        case .c2:
            Color(red: 0.39, green: 0.25, blue: 0.96)
        }
    }

    var levelIconName: String {
        switch self {
        case .preA1: "CEFRPreA1Icon"
        case .a1: "CEFRA1Icon"
        case .a2: "CEFRA2Icon"
        case .b1: "CEFRB1Icon"
        case .b2: "CEFRB2Icon"
        case .c1: "CEFRC1Icon"
        case .c2: "CEFRC2Icon"
        }
    }

    var tileTint: Color {
        switch self {
        case .preA1:
            Color(red: 0.72, green: 0.48, blue: 0.98)
        case .a1:
            TranslateTheme.primary
        case .a2:
            Color(red: 0.22, green: 0.72, blue: 0.55)
        case .b1:
            Color(red: 0.91, green: 0.66, blue: 0.18)
        case .b2:
            Color(red: 0.98, green: 0.39, blue: 0.52)
        case .c1:
            Color(red: 0.34, green: 0.56, blue: 0.98)
        case .c2:
            Color(red: 0.65, green: 0.38, blue: 0.98)
        }
    }

    var fallbackLearningLevel: LearningLevel {
        switch self {
        case .preA1, .a1, .a2:
            return .beginner
        case .b1, .b2:
            return .intermediate
        case .c1, .c2:
            return .advanced
        }
    }

    var apiLevels: [String] {
        [rawValue]
    }

    var defaultReadingTopic: String {
        switch self {
        case .preA1:
            "school"
        case .a1:
            "daily routines"
        case .a2:
            "weekend plans"
        case .b1:
            "community gardens"
        case .b2:
            "museum access"
        case .c1:
            "urban memory"
        case .c2:
            "public communication"
        }
    }

    init(profileLevel: LearningLevel) {
        switch profileLevel {
        case .beginner:
            self = .a1
        case .intermediate:
            self = .b1
        case .advanced:
            self = .c1
        }
    }
}

private enum LocupomTopicsAPIClient {
    static let baseURL = URL(string: "https://locupom-topics-api.vercel.app")!

    static func fetchGrammarTopics(levels: [String], learnerId: String? = nil, completedKeys: [String] = []) async throws -> [LocupomRemoteTopic] {
        var topics: [LocupomRemoteTopic] = []
        for level in levels {
            topics.append(contentsOf: try await fetchGrammarTopics(level: level, learnerId: learnerId, completedKeys: completedKeys))
        }
        return topics
    }

    private static func fetchGrammarTopics(level: String, learnerId: String?, completedKeys: [String]) async throws -> [LocupomRemoteTopic] {
        var components = URLComponents(url: baseURL.appendingPathComponent("topics"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "level", value: level),
            learnerId.map { URLQueryItem(name: "learnerId", value: $0) },
            completedQueryItem(completedKeys)
        ].compactMap { $0 }
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 4

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            return []
        }

        return try JSONDecoder().decode(LocupomTopicsResponse.self, from: data).topics
    }

    static func fetchReading(level: String, topic: String, length: String = "standard", learnerId: String? = nil, completedKeys: [String] = []) async throws -> LocupomReadingResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("readings"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "level", value: level),
            URLQueryItem(name: "topic", value: topic),
            URLQueryItem(name: "length", value: length),
            learnerId.map { URLQueryItem(name: "learnerId", value: $0) },
            completedQueryItem(completedKeys)
        ].compactMap { $0 }
        guard let url = components.url else {
            throw LanguageLearningError.invalidQuery
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            throw LanguageLearningError.server(statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(LocupomReadingResponse.self, from: data)
    }

    static func fetchSpeakingPrompts(level: String, learnerId: String? = nil, completedKeys: [String] = []) async throws -> LocupomSpeakingResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("speaking"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "level", value: level),
            learnerId.map { URLQueryItem(name: "learnerId", value: $0) },
            completedQueryItem(completedKeys)
        ].compactMap { $0 }
        guard let url = components.url else {
            throw LanguageLearningError.invalidQuery
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            throw LanguageLearningError.server(statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(LocupomSpeakingResponse.self, from: data)
    }

    static func fetchPracticeExercises(skill: String, level: String, learnerId: String? = nil, completedKeys: [String] = []) async throws -> LocupomPracticeExercisesResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("exercises"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "level", value: level),
            URLQueryItem(name: "skill", value: skill),
            learnerId.map { URLQueryItem(name: "learnerId", value: $0) },
            completedQueryItem(completedKeys)
        ].compactMap { $0 }
        guard let url = components.url else {
            throw LanguageLearningError.invalidQuery
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            throw LanguageLearningError.server(statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(LocupomPracticeExercisesResponse.self, from: data)
    }

    static func fetchVocabulary(level: String, learnerId: String? = nil, completedKeys: [String] = []) async throws -> LocupomVocabularyResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("vocabulary"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "level", value: level),
            learnerId.map { URLQueryItem(name: "learnerId", value: $0) },
            completedQueryItem(completedKeys)
        ].compactMap { $0 }
        guard let url = components.url else {
            throw LanguageLearningError.invalidQuery
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            throw LanguageLearningError.server(statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(LocupomVocabularyResponse.self, from: data)
    }

    private static func completedQueryItem(_ completedKeys: [String]) -> URLQueryItem? {
        guard !completedKeys.isEmpty else {
            return nil
        }
        return URLQueryItem(name: "completed", value: completedKeys.joined(separator: ","))
    }

    static func markCompleted(learnerId: String, kind: String, itemId: String, level: String? = nil, title: String? = nil) async throws {
        let url = baseURL.appendingPathComponent("progress/completed")
        let payload = CompletionPayload(
            learnerId: learnerId,
            kind: kind,
            itemId: itemId,
            level: level,
            title: title
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            throw LanguageLearningError.server(statusCode: httpResponse.statusCode)
        }
    }

    private struct CompletionPayload: Encodable {
        let learnerId: String
        let kind: String
        let itemId: String
        let level: String?
        let title: String?
    }
}

private struct TopicsPracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var learningProgress: LearningProgressStore
    private let showsCloseButton: Bool
    private let hidesTabBar: Bool
    @State private var remoteTopicsByLevel: [TopicCEFRLevel: [GrammarTopic]] = [:]

    init(showsCloseButton: Bool = true, hidesTabBar: Bool = true) {
        self.showsCloseButton = showsCloseButton
        self.hidesTabBar = hidesTabBar
    }

    private var selectedLevel: TopicCEFRLevel {
        TopicCEFRLevel(rawValue: learningProgress.cefrLevelCode) ?? TopicCEFRLevel(profileLevel: learningProgress.profile.level)
    }

    private var topics: [GrammarTopic] {
        if let remoteTopics = remoteTopicsByLevel[selectedLevel], !remoteTopics.isEmpty {
            let incompleteTopics = remoteTopics.filter {
                !learningProgress.isRemoteContentCompleted(kind: "topic", itemId: $0.apiContentId)
            }
            return incompleteTopics
        }

        return GrammarTopic.deck(for: selectedLevel.fallbackLearningLevel)
    }

    var body: some View {
        ZStack {
            TopicsLearningBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TopicsBrowserHeader(
                        selectedLevel: selectedLevel,
                        topicCount: topics.count,
                        showsCloseButton: showsCloseButton,
                        closeAction: { dismiss() }
                    )

                    TopicLevelTopicListCard(
                        topics: topics,
                        selectedLevel: selectedLevel
                    )
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, hidesTabBar ? 34 : 112)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task(id: selectedLevel) {
            await loadTopics(for: selectedLevel)
        }
    }

    @MainActor
    private func loadTopics(for level: TopicCEFRLevel, forceRefresh: Bool = false) async {
        if !forceRefresh, let cachedTopics = remoteTopicsByLevel[level], !cachedTopics.isEmpty {
            return
        }

        do {
            let remoteTopics = try await LocupomTopicsAPIClient.fetchGrammarTopics(
                levels: level.apiLevels,
                learnerId: learningProgress.apiLearnerId,
                completedKeys: Array(learningProgress.completedRemoteContentKeys)
            )
            let mappedTopics = remoteTopics.sorted(by: topicAPISort).enumerated().map { index, remoteTopic in
                makeTopic(from: remoteTopic, level: level, index: index)
            }

            if !mappedTopics.isEmpty {
                remoteTopicsByLevel[level] = mappedTopics
            }
        } catch {
            return
        }
    }

    private func makeTopic(from remoteTopic: LocupomRemoteTopic, level: TopicCEFRLevel, index: Int) -> GrammarTopic {
        let style = topicStyle(index: index)
        let categoryLabel = remoteTopic.categoryLabel ?? remoteTopic.category.capitalized
        let sourceTitle = remoteTopic.source?.documentTitle ?? remoteTopic.externalResources?.sourcePdf?.documentId
        let examples = remoteTopic.examples.map {
            GrammarTopicExample(sentence: $0, note: sourceTitle.map { "From \($0)." } ?? "\(remoteTopic.level) example from Locupom API.")
        }
        let mistakes = remoteTopic.commonMistakes.isEmpty
            ? ["Check meaning and form before choosing the answer."]
            : remoteTopic.commonMistakes
        let objectives = remoteTopic.learningObjectives.prefix(3).joined(separator: " ")
        let quizOptions = remoteTopic.quiz.options.isEmpty
            ? [remoteTopic.quiz.answer, "Meaning, form and context", "Only memorising rules"]
            : remoteTopic.quiz.options
        let externalResources = GrammarTopicExternalResources(remote: remoteTopic.externalResources)
        let source = remoteTopic.source.map(GrammarTopicSource.init(remote:))
        let fallbackSearchTerm = externalResources.authenticExamples?.query
            ?? externalResources.wordBank?.query
            ?? remoteTopic.title

        return GrammarTopic(
            apiContentId: remoteTopic.id,
            title: remoteTopic.title,
            tagline: "\(remoteTopic.level) - \(categoryLabel)",
            summary: remoteTopic.summary,
            formula: remoteTopic.pattern,
            whenToUse: objectives.isEmpty ? remoteTopic.summary : objectives,
            examples: examples.isEmpty
                ? [GrammarTopicExample(sentence: "Create one sentence using \(remoteTopic.title.lowercased()).", note: "Your turn.")]
                : examples,
            commonMistakes: mistakes,
            objectives: remoteTopic.learningObjectives,
            category: remoteTopic.category,
            categoryLabel: categoryLabel,
            apiOrder: remoteTopic.order,
            sourceBasis: remoteTopic.sourceBasis ?? [],
            practiceIdeas: remoteTopic.practiceIdeas ?? [],
            lessonBlocks: (remoteTopic.lessonBlocks ?? []).map {
                GrammarTopicLessonBlock(title: $0.title, body: $0.body)
            },
            practiceTasks: (remoteTopic.practiceTasks ?? []).map {
                GrammarTopicPracticeTask(
                    id: $0.id,
                    kind: $0.kind,
                    title: $0.title,
                    instruction: $0.instruction,
                    prompt: $0.prompt,
                    options: $0.options,
                    answer: $0.answer,
                    explanation: $0.explanation
                )
            },
            source: source,
            externalResources: externalResources,
            externalSearchTerm: fallbackSearchTerm,
            quizQuestion: remoteTopic.quiz.question,
            quizOptions: quizOptions,
            quizAnswer: remoteTopic.quiz.answer,
            quizExplanation: remoteTopic.quiz.explanation,
            level: level.fallbackLearningLevel,
            systemImage: style.image,
            tint: style.tint
        )
    }

    private func topicAPISort(_ first: LocupomRemoteTopic, _ second: LocupomRemoteTopic) -> Bool {
        if (first.levelOrder ?? 0) != (second.levelOrder ?? 0) {
            return (first.levelOrder ?? 0) < (second.levelOrder ?? 0)
        }

        if first.category != second.category {
            return first.category < second.category
        }

        if (first.order ?? 0) != (second.order ?? 0) {
            return (first.order ?? 0) < (second.order ?? 0)
        }

        return first.title < second.title
    }

    private func topicStyle(index: Int) -> (image: String, tint: Color) {
        let styles: [(String, Color)] = [
            ("textformat.abc", TranslateTheme.primary),
            ("arrow.triangle.branch", .purple),
            ("quote.bubble.fill", .teal),
            ("checklist", .orange),
            ("sparkles", .indigo),
            ("book.closed.fill", .mint)
        ]
        let style = styles[index % styles.count]
        return (style.0, style.1)
    }

}

private struct ReadingPracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var learningProgress: LearningProgressStore
    @State private var selectedLevel: TopicCEFRLevel = .a1
    @State private var hasInitializedLevel = false
    @State private var reading: LocupomLevelledReading?
    @State private var readingErrorMessage: String?
    @State private var isLoadingReading = false
    @State private var selectedReadingAnswers: [String: String] = [:]

    var body: some View {
        ZStack {
            TranslatePracticeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ExerciseSessionTopBar(
                        title: "Reading",
                        closeAction: { dismiss() }
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Leer & responder")
                            .font(.system(size: 39, weight: .black, design: .rounded))
                            .foregroundStyle(TranslateTheme.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)

                        Text("Comprendé un texto corto por nivel.")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(TranslateTheme.muted)
                    }

                    TopicLevelReadingCard(
                        reading: reading,
                        isLoading: isLoadingReading,
                        errorMessage: readingErrorMessage,
                        selectedLevel: selectedLevel,
                        selectedAnswers: selectedReadingAnswers,
                        refreshAction: {
                            Task {
                                await loadReading(for: selectedLevel, forceRefresh: true)
                            }
                        },
                        chooseAnswer: chooseReadingAnswer
                    )
                }
                .padding(.horizontal, 26)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .locupomFloatingTabBarHidden(true)
        .onAppear {
            if !hasInitializedLevel {
                selectedLevel = TopicCEFRLevel(rawValue: learningProgress.cefrLevelCode) ?? TopicCEFRLevel(profileLevel: learningProgress.profile.level)
                hasInitializedLevel = true
            }
        }
        .task(id: selectedLevel) {
            await loadReading(for: selectedLevel)
        }
    }

    @MainActor
    private func loadReading(for level: TopicCEFRLevel, forceRefresh: Bool = false) async {
        if !forceRefresh, reading?.level == level.rawValue {
            return
        }

        isLoadingReading = true
        readingErrorMessage = nil
        selectedReadingAnswers = [:]

        do {
            let response = try await LocupomTopicsAPIClient.fetchReading(
                level: level.rawValue,
                topic: level.defaultReadingTopic,
                learnerId: learningProgress.apiLearnerId,
                completedKeys: Array(learningProgress.completedRemoteContentKeys)
            )
            reading = response.reading
            readingErrorMessage = response.providerError ?? response.message
        } catch {
            reading = LocupomLevelledReading.fallback(for: level)
            readingErrorMessage = "Usando lectura offline hasta que el API local este disponible."
        }

        isLoadingReading = false
    }

    private func chooseReadingAnswer(question: LocupomReadingQuestion, answer: String) {
        selectedReadingAnswers[question.id] = answer
        let isCorrect = answer == question.answer
        learningProgress.recordModule(LearningModule.reading.rawValue, wasCorrect: isCorrect)

        if isCorrect {
            learningProgress.recordErrorResolved(module: LearningModule.reading.rawValue, expected: question.answer)
            markReadingCompletedIfNeeded()
        } else {
            learningProgress.recordError(
                module: LearningModule.reading.rawValue,
                expected: question.answer,
                actual: answer,
                context: question.prompt
            )
        }
    }

    private func markReadingCompletedIfNeeded() {
        guard let reading, reading.provider != "offline" else {
            return
        }
        let visibleQuestions = Array(reading.questions.prefix(3))
        guard !visibleQuestions.isEmpty else {
            return
        }
        let allVisibleQuestionsAreCorrect = visibleQuestions.allSatisfy { question in
            selectedReadingAnswers[question.id] == question.answer
        }
        guard allVisibleQuestionsAreCorrect else {
            return
        }

        let completedReading = reading
        let completedLevel = selectedLevel
        let learnerId = learningProgress.apiLearnerId
        let didInsert = learningProgress.markRemoteContentCompleted(kind: "reading", itemId: completedReading.id)
        guard didInsert else {
            return
        }

        Task {
            try? await LocupomTopicsAPIClient.markCompleted(
                learnerId: learnerId,
                kind: "reading",
                itemId: completedReading.id,
                level: completedReading.level,
                title: completedReading.title
            )
            try? await Task.sleep(nanoseconds: 800_000_000)
            let shouldLoadNext = await MainActor.run {
                selectedLevel == completedLevel
            }
            if shouldLoadNext {
                await loadReading(for: completedLevel, forceRefresh: true)
            }
        }
    }
}

private struct TopicsBrowserHeader: View {
    let selectedLevel: TopicCEFRLevel
    let topicCount: Int
    let showsCloseButton: Bool
    let closeAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsCloseButton {
                Button(action: closeAction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(TranslateTheme.ink)
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct TopicLevelSelectorCard: View {
    @Binding var selectedLevel: TopicCEFRLevel
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [TranslateTheme.secondary, TranslateTheme.primary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Nivel CEFR")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(TranslateTheme.ink)

                    Spacer(minLength: 92)
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(TopicCEFRLevel.allCases) { level in
                        Button {
                            selectedLevel = level
                        } label: {
                            TopicCEFRLevelChip(
                                level: level,
                                isSelected: level == selectedLevel
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(14)
            .background(TranslateTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 22))
            .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 18, x: 0, y: 10)

            Image("Ajolote_Header")
                .resizable()
                .scaledToFit()
                .frame(width: 88)
                .shadow(color: Color(red: 1.0, green: 0.75, blue: 0.18).opacity(0.22), radius: 12, x: 0, y: 7)
                .offset(x: 8, y: -48)
                .allowsHitTesting(false)
        }
        .padding(.top, 38)
    }
}

private struct TopicCEFRLevelChip: View {
    let level: TopicCEFRLevel
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(level.tileTint.opacity(isSelected ? 0.0 : 0.055))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(level.tileTint.opacity(isSelected ? 0.0 : 0.28), lineWidth: 1.1)
                    }

                if isSelected {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [TranslateTheme.primary, TranslateTheme.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: TranslateTheme.secondary.opacity(0.26), radius: 12, x: 0, y: 7)
                }

                VStack(spacing: 3) {
                    Text(level.shortCode.uppercased())
                        .font(.system(size: level == .preA1 ? 13 : 16, weight: .black, design: .rounded))
                        .foregroundStyle(isSelected ? .white : TranslateTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)

                    Image(level.levelIconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 29, height: 29)
                        .shadow(color: level.tileTint.opacity(isSelected ? 0.22 : 0.12), radius: 5, x: 0, y: 3)
                }
                .padding(.horizontal, 4)
            }

            if isSelected {
                ZStack {
                    Circle()
                        .fill(TranslateTheme.elevatedSurface)
                        .frame(width: 25, height: 25)
                        .shadow(color: TranslateTheme.secondary.opacity(0.18), radius: 6, x: 0, y: 4)

                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(TranslateTheme.primary)
                }
                .offset(x: 6, y: -8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 74)
    }
}

private struct TopicLevelTopicListCard: View {
    let topics: [GrammarTopic]
    let selectedLevel: TopicCEFRLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Text("Temas de \(selectedLevel.shortCode)")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(TranslateTheme.ink)

                Spacer(minLength: 8)

                Text(topicCountText)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(TranslateTheme.ink.opacity(0.42))

                Image(systemName: "list.bullet")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(TranslateTheme.primary)
            }

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(TranslateTheme.primary.opacity(0.13))
                    .frame(height: 4)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [TranslateTheme.primary, TranslateTheme.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 68, height: 4)
            }

            VStack(spacing: 0) {
                ForEach(Array(topics.enumerated()), id: \.offset) { index, topic in
                    NavigationLink {
                        TopicDetailView(
                            topic: topic,
                            topicIndex: index,
                            totalTopics: topics.count,
                            selectedLevel: selectedLevel
                        )
                    } label: {
                        TopicLevelTopicRow(
                            number: index + 1,
                            topic: topic
                        )
                    }
                    .buttonStyle(.plain)

                    if index < topics.count - 1 {
                        Divider()
                            .background(TranslateTheme.ink.opacity(0.06))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(TranslateTheme.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: TranslateTheme.primary.opacity(0.06), radius: 18, x: 0, y: 10)
    }

    private var topicCountText: String {
        topics.count == 1 ? "1 tema" : "\(topics.count) temas"
    }
}

private struct TopicLevelReadingCard: View {
    let reading: LocupomLevelledReading?
    let isLoading: Bool
    let errorMessage: String?
    let selectedLevel: TopicCEFRLevel
    let selectedAnswers: [String: String]
    let refreshAction: () -> Void
    let chooseAnswer: (LocupomReadingQuestion, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Label("Lectura CEFR", systemImage: "book.pages.fill")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(TranslateTheme.ink)

                Spacer(minLength: 8)

                if let reading {
                    Text(reading.source)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(selectedLevel.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(selectedLevel.accent.opacity(0.10), in: Capsule())
                }

                Button(action: refreshAction) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(selectedLevel.accent)
                        .frame(width: 34, height: 34)
                        .background(selectedLevel.accent.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(selectedLevel.accent)
                    Text("Cargando lectura de \(selectedLevel.shortCode)...")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TranslateTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            } else if let reading {
                readingContent(reading)
            } else {
                Text(errorMessage ?? "No pude cargar una lectura para este nivel.")
                    .font(.caption)
                    .foregroundStyle(TranslateTheme.muted)
                    .lineSpacing(3)
            }
        }
        .padding(16)
        .background(TranslateTheme.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: TranslateTheme.primary.opacity(0.07), radius: 18, x: 0, y: 10)
    }

    @ViewBuilder
    private func readingContent(_ reading: LocupomLevelledReading) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let errorMessage {
                Label(errorMessage, systemImage: "wifi.slash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.orange)
                    .lineLimit(2)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(reading.title)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(TranslateTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                HStack(spacing: 8) {
                    ReadingMetaPill(text: "\(reading.estimatedMinutes)m", systemImage: "timer", tint: TranslateTheme.mint)
                    ReadingMetaPill(text: reading.topic, systemImage: "tag.fill", tint: .orange)
                }
            }

            Text(reading.content)
                .font(.subheadline)
                .lineSpacing(4)
                .foregroundStyle(TranslateTheme.ink.opacity(0.86))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(13)
                .background(TranslateTheme.softSurface, in: RoundedRectangle(cornerRadius: 15))

            let visibleQuestions = Array(reading.questions.prefix(3))
            if !visibleQuestions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(visibleQuestions.enumerated()), id: \.element.id) { index, question in
                        readingQuestion(question, number: index + 1, total: visibleQuestions.count)
                    }
                }
            }
        }
    }

    private func readingQuestion(_ question: LocupomReadingQuestion, number: Int, total: Int) -> some View {
        let selectedAnswer = selectedAnswers[question.id]

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("Pregunta \(number)", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(TranslateTheme.ink)

                Spacer()

                Text("\(number)/\(total)")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(selectedLevel.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(selectedLevel.accent.opacity(0.10), in: Capsule())
            }

            Text(question.prompt)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TranslateTheme.ink)
                .lineSpacing(3)

            VStack(spacing: 8) {
                ForEach(question.options.isEmpty ? [question.answer] : question.options, id: \.self) { option in
                    Button {
                        chooseAnswer(question, option)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: selectedAnswer == option ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(selectedAnswer == option ? selectedLevel.accent : TranslateTheme.muted.opacity(0.65))
                                .padding(.top, 2)

                            Text(option)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(TranslateTheme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                        }
                        .padding(11)
                        .background(optionBackground(option, question: question, selectedAnswer: selectedAnswer), in: RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let selectedAnswer {
                TranslateInfoCard(
                    systemImage: selectedAnswer == question.answer ? "checkmark.seal.fill" : "lightbulb.fill",
                    title: selectedAnswer == question.answer ? "Correct" : "Review",
                    detail: selectedAnswer == question.answer ? question.explanation : "Answer: \(question.answer). \(question.explanation)",
                    tint: selectedAnswer == question.answer ? TranslateTheme.mint : .orange
                )
            }
        }
        .padding(13)
        .background(TranslateTheme.elevatedSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(selectedLevel.accent.opacity(0.12), lineWidth: 1)
        )
    }

    private func optionBackground(_ option: String, question: LocupomReadingQuestion, selectedAnswer: String?) -> Color {
        guard let selectedAnswer else {
            return TranslateTheme.softSurface
        }

        if option == question.answer {
            return TranslateTheme.mint.opacity(0.16)
        }

        if option == selectedAnswer {
            return Color.orange.opacity(0.13)
        }

        return TranslateTheme.softSurface
    }
}

private struct ReadingMetaPill: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.black))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.70)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(tint.opacity(0.10), in: Capsule())
    }
}

private struct TopicLevelTopicRow: View {
    let number: Int
    let topic: GrammarTopic

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text("\(number)")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(topic.tint)
                .frame(width: 46, height: 46)
                .background(
                    LinearGradient(
                        colors: [topic.tint.opacity(0.16), topic.tint.opacity(0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 15)
                )

            VStack(alignment: .leading, spacing: 7) {
                Text(topic.title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(TranslateTheme.ink)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 7) {
                    TopicMetaChip(text: topic.categoryLabel, tint: topic.tint)

                    if let pageRangeText = topic.source?.pageRangeText {
                        TopicMetaChip(text: pageRangeText, tint: TranslateTheme.mint)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(TranslateTheme.ink.opacity(0.36))
                .frame(width: 24, height: 44)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private struct TopicMetaChip: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.black))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(0.10), in: Capsule())
    }
}

private struct TopicDetailView: View {
    @EnvironmentObject private var learningProgress: LearningProgressStore
    let topic: GrammarTopic
    let topicIndex: Int
    let totalTopics: Int
    let selectedLevel: TopicCEFRLevel

    @State private var selectedQuizOption: String?
    @State private var feedback: LearningFeedback?
    @State private var practiceAnswers: [String: String] = [:]
    @State private var authenticExamples: [SentenceExample] = []
    @State private var isLoadingAuthenticExamples = false
    @State private var wordBank: [WordSuggestion] = []
    @State private var isLoadingWordBank = false
    private let languageService = LanguageLearningService()

    var body: some View {
        ZStack {
            TopicsLearningBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TopicDetailHeaderCard(
                        topic: topic,
                        selectedLevel: selectedLevel,
                        topicIndex: topicIndex,
                        totalTopics: totalTopics
                    )

                    TopicHeroCard(topic: topic)
                    TopicSourceCard(topic: topic)
                    TopicLessonBlocksCard(blocks: topic.lessonBlocks, tint: topic.tint)
                    TopicFormulaCard(topic: topic)
                    TopicObjectivesCard(objectives: topic.objectives, tint: topic.tint)
                    TopicPracticeIdeasCard(ideas: topic.practiceIdeas, tint: topic.tint)
                    TopicExternalResourcesCard(resources: topic.externalResources, tint: topic.tint)
                    TopicAuthenticExamplesCard(
                        query: topic.authenticExamplesQuery,
                        resource: topic.externalResources.authenticExamples,
                        examples: authenticExamples,
                        isLoading: isLoadingAuthenticExamples
                    )
                    TopicWordBankCard(
                        resource: topic.externalResources.wordBank,
                        words: wordBank,
                        isLoading: isLoadingWordBank,
                        tint: topic.tint
                    )
                    TopicPracticeTasksCard(
                        topic: topic,
                        selectedAnswers: practiceAnswers,
                        choose: choosePracticeAnswer
                    )
                    TopicExamplesCard(examples: topic.examples)
                    TopicMistakesCard(mistakes: topic.commonMistakes)
                    TopicQuizCard(
                        topic: topic,
                        selectedOption: selectedQuizOption,
                        feedback: feedback,
                        choose: validate
                    )
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .locupomFloatingTabBarHidden(true)
        .task(id: topic.id) {
            await loadExternalContext()
        }
    }

    @MainActor
    private func loadExternalContext() async {
        isLoadingAuthenticExamples = true
        let examples = await languageService.fetchSentenceExamples(word: topic.authenticExamplesQuery, limit: 3)
        authenticExamples = examples
        isLoadingAuthenticExamples = false

        isLoadingWordBank = true
        let words = await languageService.fetchRelatedWords(word: topic.wordBankQuery)
        wordBank = Array(words.filter(isUsefulWordBankItem).prefix(8))
        isLoadingWordBank = false
    }

    private func validate(_ option: String) {
        selectedQuizOption = option
        let isCorrect = option == topic.quizAnswer
        learningProgress.recordModule(LearningModule.topics.rawValue, wasCorrect: isCorrect)

        if isCorrect {
            learningProgress.recordErrorResolved(module: LearningModule.topics.rawValue, expected: topic.quizAnswer)
            markTopicCompletedIfNeeded()
        } else {
            learningProgress.recordError(
                module: LearningModule.topics.rawValue,
                expected: topic.quizAnswer,
                actual: option,
                context: topic.quizQuestion
            )
        }

        feedback = LearningFeedback(
            title: isCorrect ? "Correct" : "Almost",
            detail: isCorrect ? topic.quizExplanation : "Answer: \(topic.quizAnswer). \(topic.quizExplanation)",
            score: isCorrect ? 1 : 0,
            isCorrect: isCorrect
        )
    }

    private func markTopicCompletedIfNeeded() {
        guard let apiContentId = topic.apiContentId else {
            return
        }

        let learnerId = learningProgress.apiLearnerId
        let didInsert = learningProgress.markRemoteContentCompleted(kind: "topic", itemId: apiContentId)
        guard didInsert else {
            return
        }

        Task {
            try? await LocupomTopicsAPIClient.markCompleted(
                learnerId: learnerId,
                kind: "topic",
                itemId: apiContentId,
                level: selectedLevel.rawValue,
                title: topic.title
            )
        }
    }

    private func choosePracticeAnswer(task: GrammarTopicPracticeTask, answer: String) {
        practiceAnswers[task.id] = answer
        learningProgress.recordModule(LearningModule.topics.rawValue, wasCorrect: answer == task.answer)
    }

    private func isUsefulWordBankItem(_ suggestion: WordSuggestion) -> Bool {
        let word = suggestion.word.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet.letters
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-'"))
        return !word.isEmpty
            && word.count <= 18
            && word.split(separator: " ").count <= 2
            && word.rangeOfCharacter(from: allowed.inverted) == nil
    }
}

private struct TopicDetailHeaderCard: View {
    let topic: GrammarTopic
    let selectedLevel: TopicCEFRLevel
    let topicIndex: Int
    let totalTopics: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: topic.systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(topic.tint)
                .frame(width: 46, height: 46)
                .background(topic.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 5) {
                Text("\(selectedLevel.shortCode) · Tema \(topicIndex + 1) de \(max(totalTopics, 1))")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(topic.tint)

                Text(topic.title)
                    .font(.title2.bold())
                    .foregroundStyle(TranslateTheme.ink)
                    .lineLimit(2)

                Text(topic.tagline)
                    .font(.subheadline)
                    .foregroundStyle(TranslateTheme.muted)
                    .lineLimit(2)

                HStack(spacing: 7) {
                    TopicMetaChip(text: topic.categoryLabel, tint: topic.tint)

                    if let pageRangeText = topic.source?.pageRangeText {
                        TopicMetaChip(text: pageRangeText, tint: TranslateTheme.mint)
                    }

                    if let apiOrder = topic.apiOrder {
                        TopicMetaChip(text: "#\(apiOrder)", tint: TranslateTheme.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .background(TranslateTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: TranslateTheme.primary.opacity(0.07), radius: 16, x: 0, y: 9)
    }
}

private struct TopicHeroCard: View {
    let topic: GrammarTopic

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: topic.systemImage)
                    .font(.headline)
                    .foregroundStyle(topic.tint)
                    .frame(width: 42, height: 42)
                    .background(topic.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 13))

                VStack(alignment: .leading, spacing: 5) {
                    Text(topic.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(TranslateTheme.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                    Text(topic.tagline)
                        .font(.caption)
                        .foregroundStyle(TranslateTheme.muted)
                        .lineLimit(1)
                }

                Spacer()
            }

            Text(topic.summary)
                .font(.footnote)
                .lineSpacing(3)
                .foregroundStyle(TranslateTheme.ink.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(TranslateTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: TranslateTheme.primary.opacity(0.07), radius: 14, x: 0, y: 8)
    }
}

private struct TopicSourceCard: View {
    let topic: GrammarTopic
    @State private var isExpanded = false

    var body: some View {
        if topic.hasSourceContext {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Fuente del contenido", systemImage: "doc.text.magnifyingglass")
                        .font(.headline)
                        .foregroundStyle(TranslateTheme.ink)

                    Spacer()

                    if let provider = topic.externalResources.sourcePdf?.provider {
                        TopicMetaChip(text: provider, tint: topic.tint)
                    }
                }

                if let source = topic.source {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(source.documentTitle ?? "PDF curriculum")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(TranslateTheme.ink)
                            .lineLimit(2)

                        HStack(spacing: 7) {
                            if let pageRangeText = source.pageRangeText {
                                TopicMetaChip(text: pageRangeText, tint: TranslateTheme.mint)
                            }

                            if let outlineText = source.outlineText {
                                TopicMetaChip(text: outlineText, tint: topic.tint)
                            }
                        }
                    }
                }

                if !topic.sourceBasis.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(topic.sourceBasis, id: \.self) { basis in
                            HStack(alignment: .top, spacing: 9) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(topic.tint)
                                    .padding(.top, 1)

                                Text(basis)
                                    .font(.caption)
                                    .foregroundStyle(TranslateTheme.muted)
                                    .lineSpacing(3)
                            }
                        }
                    }
                }

                if let sourceText = topic.source?.previewText(expanded: isExpanded) {
                    Text(sourceText)
                        .font(.caption)
                        .foregroundStyle(TranslateTheme.ink.opacity(0.78))
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(TranslateTheme.softSurface, in: RoundedRectangle(cornerRadius: 14))

                    if topic.source?.canExpandText == true {
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            Label(isExpanded ? "Ver menos" : "Ver texto del PDF", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.black))
                                .foregroundStyle(topic.tint)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .background(TranslateTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 18, x: 0, y: 10)
        }
    }
}

private struct TopicLessonBlocksCard: View {
    let blocks: [GrammarTopicLessonBlock]
    let tint: Color

    var body: some View {
        if !blocks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Mini lesson", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(TranslateTheme.ink)

                ForEach(blocks) { block in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(block.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(tint)
                        Text(block.body)
                            .font(.caption)
                            .foregroundStyle(TranslateTheme.muted)
                            .lineSpacing(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(16)
            .background(TranslateTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 18, x: 0, y: 10)
        }
    }
}

private struct TopicFormulaCard: View {
    let topic: GrammarTopic

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("Pattern", systemImage: "function")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(TranslateTheme.ink)

            Text(topic.formula)
                .font(.system(.footnote, design: .monospaced).weight(.semibold))
                .foregroundStyle(topic.tint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
                .background(topic.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            Text(topic.whenToUse)
                .font(.caption)
                .foregroundStyle(TranslateTheme.muted)
                .lineLimit(2)
        }
        .padding(14)
        .background(TranslateTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: TranslateTheme.primary.opacity(0.07), radius: 14, x: 0, y: 8)
    }
}

private struct TopicObjectivesCard: View {
    let objectives: [String]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Goal for this topic", systemImage: "target")
                .font(.headline)
                .foregroundStyle(TranslateTheme.ink)

            ForEach(Array(objectives.prefix(3).enumerated()), id: \.offset) { index, objective in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(tint, in: Circle())

                    Text(objective)
                        .font(.caption)
                        .foregroundStyle(TranslateTheme.muted)
                        .lineSpacing(3)
                }
            }
        }
        .padding(16)
        .background(TranslateTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

private struct TopicPracticeIdeasCard: View {
    let ideas: [String]
    let tint: Color

    var body: some View {
        if !ideas.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Practica sugerida", systemImage: "figure.run.circle.fill")
                    .font(.headline)
                    .foregroundStyle(TranslateTheme.ink)

                ForEach(Array(ideas.enumerated()), id: \.offset) { index, idea in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(tint, in: Circle())

                        Text(idea)
                            .font(.caption)
                            .foregroundStyle(TranslateTheme.muted)
                            .lineSpacing(3)
                    }
                }
            }
            .padding(16)
            .background(TranslateTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 18, x: 0, y: 10)
        }
    }
}

private struct TopicExternalResourcesCard: View {
    let resources: GrammarTopicExternalResources
    let tint: Color

    var body: some View {
        let visibleResources = resources.visibleResources
        if !visibleResources.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Recursos de la API", systemImage: "link.circle.fill")
                    .font(.headline)
                    .foregroundStyle(TranslateTheme.ink)

                ForEach(visibleResources) { resource in
                    TopicExternalResourceRow(resource: resource, tint: tint)
                }
            }
            .padding(16)
            .background(TranslateTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 18, x: 0, y: 10)
        }
    }
}

private struct TopicExternalResourceRow: View {
    let resource: GrammarTopicExternalResource
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center, spacing: 8) {
                TopicMetaChip(text: resource.provider, tint: tint)

                if let query = resource.query {
                    Text(query)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TranslateTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                }

                Spacer(minLength: 0)
            }

            if let detailText = resource.detailText {
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(TranslateTheme.muted)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct TopicAuthenticExamplesCard: View {
    let query: String
    let resource: GrammarTopicExternalResource?
    let examples: [SentenceExample]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Real examples", systemImage: "quote.bubble.fill")
                    .font(.headline)
                    .foregroundStyle(TranslateTheme.ink)

                Spacer()

                TopicMetaChip(text: resource?.provider ?? "Tatoeba", tint: TranslateTheme.primary)
            }

            if let description = resource?.description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(TranslateTheme.muted)
                    .lineSpacing(3)
            }

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(TranslateTheme.primary)
                    Text("Looking for real sentences with '\(query)'...")
                        .font(.caption)
                        .foregroundStyle(TranslateTheme.muted)
                }
            } else if examples.isEmpty {
                Text("No real examples found yet. The local lesson still works, and you can refresh later.")
                    .font(.caption)
                    .foregroundStyle(TranslateTheme.muted)
                    .lineSpacing(3)
            } else {
                ForEach(examples.prefix(3)) { example in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(example.text)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(TranslateTheme.ink)
                        if let translation = example.translation {
                            Text(translation)
                                .font(.caption)
                                .foregroundStyle(TranslateTheme.muted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(TranslateTheme.softSurface, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(16)
        .background(TranslateTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

private struct TopicWordBankCard: View {
    let resource: GrammarTopicExternalResource?
    let words: [WordSuggestion]
    let isLoading: Bool
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Word bank", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.headline)
                    .foregroundStyle(TranslateTheme.ink)

                Spacer()

                TopicMetaChip(text: resource?.provider ?? "Datamuse", tint: tint)
            }

            if let description = resource?.description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(TranslateTheme.muted)
                    .lineSpacing(3)
            }

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(tint)
                    Text("Building a word bank...")
                        .font(.caption)
                        .foregroundStyle(TranslateTheme.muted)
                }
            } else if words.isEmpty {
                Text("No extra words yet. Try another topic or refresh the API later.")
                    .font(.caption)
                    .foregroundStyle(TranslateTheme.muted)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(words) { word in
                            Text(word.word)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(TranslateTheme.ink)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(tint.opacity(0.10), in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(TranslateTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

private struct TopicPracticeTasksCard: View {
    let topic: GrammarTopic
    let selectedAnswers: [String: String]
    let choose: (GrammarTopicPracticeTask, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Practice path", systemImage: "checklist")
                .font(.headline)
                .foregroundStyle(TranslateTheme.ink)

            ForEach(topic.practiceTasks) { task in
                TopicPracticeTaskRow(
                    task: task,
                    tint: topic.tint,
                    selectedAnswer: selectedAnswers[task.id],
                    choose: { choose(task, $0) }
                )
            }
        }
        .padding(16)
        .background(TranslateTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

private struct TopicPracticeTaskRow: View {
    let task: GrammarTopicPracticeTask
    let tint: Color
    let selectedAnswer: String?
    let choose: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(task.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(tint)

                    TopicMetaChip(text: task.kindLabel, tint: tint)
                }

                Text(task.instruction)
                    .font(.caption)
                    .foregroundStyle(TranslateTheme.muted)
            }

            Text(task.prompt)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TranslateTheme.ink)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(TranslateTheme.softSurface, in: RoundedRectangle(cornerRadius: 14))

            if task.options.isEmpty {
                Label("Use the Writing section or your notes to check this answer.", systemImage: "square.and.pencil")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TranslateTheme.muted)
            } else {
                VStack(spacing: 8) {
                    ForEach(task.options, id: \.self) { option in
                        Button {
                            choose(option)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: selectedAnswer == option ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(selectedAnswer == option ? tint : TranslateTheme.muted.opacity(0.7))
                                    .padding(.top, 2)

                                Text(option)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(TranslateTheme.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(11)
                            .background(optionBackground(option), in: RoundedRectangle(cornerRadius: 13))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let selectedAnswer {
                TranslateInfoCard(
                    systemImage: selectedAnswer == task.answer ? "checkmark.seal.fill" : "lightbulb.fill",
                    title: selectedAnswer == task.answer ? "Good" : "Review",
                    detail: task.explanation,
                    tint: selectedAnswer == task.answer ? TranslateTheme.mint : .orange
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(TranslateTheme.elevatedSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(tint.opacity(0.10), lineWidth: 1)
        )
    }

    private func optionBackground(_ option: String) -> Color {
        guard let selectedAnswer else {
            return TranslateTheme.softSurface
        }

        if option == task.answer {
            return TranslateTheme.mint.opacity(0.16)
        }

        if option == selectedAnswer {
            return Color.orange.opacity(0.13)
        }

        return TranslateTheme.softSurface
    }
}

private struct TopicExamplesCard: View {
    let examples: [GrammarTopicExample]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Examples", systemImage: "quote.bubble.fill")
                .font(.headline)
                .foregroundStyle(TranslateTheme.ink)

            ForEach(examples) { example in
                VStack(alignment: .leading, spacing: 5) {
                    Text(example.sentence)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TranslateTheme.ink)
                    Text(example.note)
                        .font(.caption)
                        .foregroundStyle(TranslateTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(TranslateTheme.softSurface, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(16)
        .background(TranslateTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

private struct TopicMistakesCard: View {
    let mistakes: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Watch out", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(TranslateTheme.ink)

            ForEach(mistakes, id: \.self) { mistake in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.orange.opacity(0.78))
                        .frame(width: 7, height: 7)
                        .padding(.top, 6)

                    Text(mistake)
                        .font(.caption)
                        .foregroundStyle(TranslateTheme.muted)
                        .lineSpacing(3)
                }
            }
        }
        .padding(16)
        .background(TranslateTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

private struct TopicQuizCard: View {
    let topic: GrammarTopic
    let selectedOption: String?
    let feedback: LearningFeedback?
    let choose: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quick check", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(TranslateTheme.ink)

            Text(topic.quizQuestion)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TranslateTheme.ink)

            VStack(spacing: 8) {
                ForEach(topic.quizOptions, id: \.self) { option in
                    Button {
                        choose(option)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selectedOption == option ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(selectedOption == option ? topic.tint : TranslateTheme.muted.opacity(0.65))

                            Text(option)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(TranslateTheme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(12)
                        .background(optionBackground(option), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let feedback {
                TranslateInfoCard(
                    systemImage: feedback.isCorrect ? "checkmark.seal.fill" : "lightbulb.fill",
                    title: feedback.title,
                    detail: feedback.detail,
                    tint: feedback.isCorrect ? TranslateTheme.mint : .orange
                )
            }
        }
        .padding(16)
        .background(TranslateTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 18, x: 0, y: 10)
    }

    private func optionBackground(_ option: String) -> Color {
        guard let selectedOption else {
            return TranslateTheme.softSurface
        }

        if option == topic.quizAnswer {
            return TranslateTheme.mint.opacity(0.16)
        }

        if option == selectedOption {
            return Color.orange.opacity(0.13)
        }

        return TranslateTheme.softSurface
    }
}

private struct GrammarTopicSource {
    let documentId: String?
    let documentTitle: String?
    let fullText: String?
    let outlinePath: [String]
    let pageStart: Int?
    let pageEnd: Int?
    let pdfPath: String?

    init(
        documentId: String? = nil,
        documentTitle: String? = nil,
        fullText: String? = nil,
        outlinePath: [String] = [],
        pageStart: Int? = nil,
        pageEnd: Int? = nil,
        pdfPath: String? = nil
    ) {
        self.documentId = documentId
        self.documentTitle = documentTitle
        self.fullText = fullText
        self.outlinePath = outlinePath
        self.pageStart = pageStart
        self.pageEnd = pageEnd
        self.pdfPath = pdfPath
    }

    init(remote: LocupomRemoteTopicSource) {
        self.init(
            documentId: remote.documentId,
            documentTitle: remote.documentTitle,
            fullText: remote.fullText,
            outlinePath: remote.outlinePath ?? [],
            pageStart: remote.pageStart,
            pageEnd: remote.pageEnd,
            pdfPath: remote.pdfPath
        )
    }

    var pageRangeText: String? {
        guard let pageStart else {
            return nil
        }

        if let pageEnd, pageEnd != pageStart {
            return "Pags. \(pageStart)-\(pageEnd)"
        }

        return "Pag. \(pageStart)"
    }

    var outlineText: String? {
        outlinePath.last
    }

    var canExpandText: Bool {
        (cleanFullText?.count ?? 0) > 520
    }

    func previewText(expanded: Bool) -> String? {
        guard let cleanFullText else {
            return nil
        }

        let limit = expanded ? 2200 : 520
        guard cleanFullText.count > limit else {
            return cleanFullText
        }

        return String(cleanFullText.prefix(limit)) + "..."
    }

    private var cleanFullText: String? {
        guard let fullText else {
            return nil
        }

        let clean = fullText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        return clean.isEmpty ? nil : clean
    }
}

private struct GrammarTopicExternalResource: Identifiable {
    let id: String
    let provider: String
    let query: String?
    let description: String?
    let documentId: String?
    let path: String?
    let pages: [Int]

    init(
        id: String,
        provider: String,
        query: String? = nil,
        description: String? = nil,
        documentId: String? = nil,
        path: String? = nil,
        pages: [Int] = []
    ) {
        self.id = id
        self.provider = provider
        self.query = query
        self.description = description
        self.documentId = documentId
        self.path = path
        self.pages = pages
    }

    init?(id: String, remote: LocupomRemoteExternalResource?) {
        guard let remote else {
            return nil
        }

        self.init(
            id: id,
            provider: remote.provider,
            query: remote.query,
            description: remote.description,
            documentId: remote.documentId,
            path: remote.path,
            pages: remote.pages ?? []
        )
    }

    var detailText: String? {
        let details = [
            description,
            documentId.map { "Documento: \($0)" },
            pageRangeText,
            path
        ].compactMap { $0 }

        return details.isEmpty ? nil : details.joined(separator: " · ")
    }

    private var pageRangeText: String? {
        guard let firstPage = pages.first else {
            return nil
        }

        if let lastPage = pages.last, lastPage != firstPage {
            return "Pags. \(firstPage)-\(lastPage)"
        }

        return "Pag. \(firstPage)"
    }
}

private struct GrammarTopicExternalResources {
    let sourcePdf: GrammarTopicExternalResource?
    let authenticExamples: GrammarTopicExternalResource?
    let wordBank: GrammarTopicExternalResource?
    let writingCheck: GrammarTopicExternalResource?

    static let empty = GrammarTopicExternalResources()

    init(
        sourcePdf: GrammarTopicExternalResource? = nil,
        authenticExamples: GrammarTopicExternalResource? = nil,
        wordBank: GrammarTopicExternalResource? = nil,
        writingCheck: GrammarTopicExternalResource? = nil
    ) {
        self.sourcePdf = sourcePdf
        self.authenticExamples = authenticExamples
        self.wordBank = wordBank
        self.writingCheck = writingCheck
    }

    init(remote: LocupomRemoteExternalResources?) {
        self.init(
            sourcePdf: GrammarTopicExternalResource(id: "source_pdf", remote: remote?.sourcePdf),
            authenticExamples: GrammarTopicExternalResource(id: "authentic_examples", remote: remote?.authenticExamples),
            wordBank: GrammarTopicExternalResource(id: "word_bank", remote: remote?.wordBank),
            writingCheck: GrammarTopicExternalResource(id: "writing_check", remote: remote?.writingCheck)
        )
    }

    var visibleResources: [GrammarTopicExternalResource] {
        [sourcePdf, authenticExamples, wordBank, writingCheck].compactMap { $0 }
    }
}

private struct GrammarTopic: Identifiable {
    let id = UUID()
    let apiContentId: String?
    let title: String
    let tagline: String
    let summary: String
    let formula: String
    let whenToUse: String
    let examples: [GrammarTopicExample]
    let commonMistakes: [String]
    let objectives: [String]
    let category: String
    let categoryLabel: String
    let apiOrder: Int?
    let sourceBasis: [String]
    let practiceIdeas: [String]
    let lessonBlocks: [GrammarTopicLessonBlock]
    let practiceTasks: [GrammarTopicPracticeTask]
    let source: GrammarTopicSource?
    let externalResources: GrammarTopicExternalResources
    let externalSearchTerm: String
    let quizQuestion: String
    let quizOptions: [String]
    let quizAnswer: String
    let quizExplanation: String
    let level: LearningLevel
    let systemImage: String
    let tint: Color

    init(
        apiContentId: String? = nil,
        title: String,
        tagline: String,
        summary: String,
        formula: String,
        whenToUse: String,
        examples: [GrammarTopicExample],
        commonMistakes: [String],
        objectives: [String] = [],
        category: String = "grammar",
        categoryLabel: String? = nil,
        apiOrder: Int? = nil,
        sourceBasis: [String] = [],
        practiceIdeas: [String] = [],
        lessonBlocks: [GrammarTopicLessonBlock] = [],
        practiceTasks: [GrammarTopicPracticeTask] = [],
        source: GrammarTopicSource? = nil,
        externalResources: GrammarTopicExternalResources = .empty,
        externalSearchTerm: String? = nil,
        quizQuestion: String,
        quizOptions: [String],
        quizAnswer: String,
        quizExplanation: String,
        level: LearningLevel,
        systemImage: String,
        tint: Color
    ) {
        self.apiContentId = apiContentId
        self.title = title
        self.tagline = tagline
        self.summary = summary
        self.formula = formula
        self.whenToUse = whenToUse
        self.examples = examples
        self.commonMistakes = commonMistakes
        self.objectives = objectives.isEmpty
            ? [
                "Recognize \(title.lowercased()) in context.",
                "Use \(title.lowercased()) in a controlled task.",
                "Produce one sentence and review it."
            ]
            : objectives
        self.category = category
        self.categoryLabel = categoryLabel ?? tagline
        self.apiOrder = apiOrder
        self.sourceBasis = sourceBasis
        self.practiceIdeas = practiceIdeas
        self.lessonBlocks = lessonBlocks.isEmpty
            ? GrammarTopicLessonBlock.defaults(title: title, summary: summary, formula: formula)
            : lessonBlocks
        self.practiceTasks = practiceTasks.isEmpty
            ? GrammarTopicPracticeTask.defaults(title: title, formula: formula, example: examples.first?.sentence, mistake: commonMistakes.first)
            : practiceTasks
        self.source = source
        self.externalResources = externalResources
        self.externalSearchTerm = externalSearchTerm
            ?? externalResources.authenticExamples?.query
            ?? externalResources.wordBank?.query
            ?? title
        self.quizQuestion = quizQuestion
        self.quizOptions = quizOptions
        self.quizAnswer = quizAnswer
        self.quizExplanation = quizExplanation
        self.level = level
        self.systemImage = systemImage
        self.tint = tint
    }

    var authenticExamplesQuery: String {
        externalResources.authenticExamples?.query ?? externalSearchTerm
    }

    var wordBankQuery: String {
        externalResources.wordBank?.query ?? externalSearchTerm
    }

    var hasSourceContext: Bool {
        source != nil || !sourceBasis.isEmpty || externalResources.sourcePdf != nil
    }

    static func deck(for level: LearningLevel) -> [GrammarTopic] {
        all.filter { $0.level == level }
    }

    private static let all: [GrammarTopic] = [
        GrammarTopic(
            title: "Verb to be",
            tagline: "am, is, are",
            summary: "Use be to identify people, describe states, say where something is, or talk about age and feelings.",
            formula: "subject + am/is/are + complement",
            whenToUse: "This is the base for introductions, descriptions and simple daily sentences.",
            examples: [
                GrammarTopicExample(sentence: "I am tired.", note: "I always goes with am."),
                GrammarTopicExample(sentence: "She is from Chile.", note: "He, she and it go with is."),
                GrammarTopicExample(sentence: "They are ready.", note: "You, we and they go with are.")
            ],
            commonMistakes: [
                "Do not say 'I is'. Use 'I am'.",
                "In English, you usually need a subject: say 'It is late', not only 'is late'."
            ],
            quizQuestion: "Choose the natural sentence.",
            quizOptions: ["I am ready.", "I is ready.", "I are ready."],
            quizAnswer: "I am ready.",
            quizExplanation: "I uses am in the present.",
            level: .beginner,
            systemImage: "person.fill.questionmark",
            tint: .blue
        ),
        GrammarTopic(
            title: "Present simple",
            tagline: "habits and facts",
            summary: "Use present simple for routines, general truths, likes, dislikes and things that happen regularly.",
            formula: "subject + verb(s) + object",
            whenToUse: "It is ideal for daily routines: I listen, she studies, they practice.",
            examples: [
                GrammarTopicExample(sentence: "I listen to music every day.", note: "A repeated habit."),
                GrammarTopicExample(sentence: "She likes pop songs.", note: "Add s with he, she and it."),
                GrammarTopicExample(sentence: "They study English at night.", note: "No s with they.")
            ],
            commonMistakes: [
                "Remember the third-person s: she likes, he works, it sounds.",
                "For negatives, use do not or does not: she does not like it."
            ],
            quizQuestion: "Complete: She ___ English every day.",
            quizOptions: ["studies", "study", "studying"],
            quizAnswer: "studies",
            quizExplanation: "She needs the third-person form: studies.",
            level: .beginner,
            systemImage: "calendar.badge.clock",
            tint: .indigo
        ),
        GrammarTopic(
            title: "Articles",
            tagline: "a, an, the",
            summary: "Use a or an for one non-specific thing. Use the when the listener knows exactly which thing you mean.",
            formula: "a/an + singular noun | the + known noun",
            whenToUse: "Articles make nouns clearer: a song, an artist, the chorus.",
            examples: [
                GrammarTopicExample(sentence: "I heard a song.", note: "Any song, not specific yet."),
                GrammarTopicExample(sentence: "The song was beautiful.", note: "Now both people know which song."),
                GrammarTopicExample(sentence: "She is an artist.", note: "Use an before a vowel sound.")
            ],
            commonMistakes: [
                "Use an for vowel sounds, not only vowel letters: an hour.",
                "Do not use a with plural nouns: say 'songs', not 'a songs'."
            ],
            quizQuestion: "Choose the correct option.",
            quizOptions: ["an old song", "a old song", "the old song yesterday"],
            quizAnswer: "an old song",
            quizExplanation: "Old begins with a vowel sound, so use an.",
            level: .beginner,
            systemImage: "textformat.abc",
            tint: .purple
        ),
        GrammarTopic(
            title: "There is / There are",
            tagline: "existence",
            summary: "Use there is for one thing and there are for more than one thing.",
            formula: "there is + singular | there are + plural",
            whenToUse: "Useful for describing places, rooms, playlists and scenes.",
            examples: [
                GrammarTopicExample(sentence: "There is a guitar in the room.", note: "One guitar."),
                GrammarTopicExample(sentence: "There are three singers on stage.", note: "More than one singer."),
                GrammarTopicExample(sentence: "There is some music outside.", note: "Music is uncountable here.")
            ],
            commonMistakes: [
                "Do not say 'there are a song'. Use 'there is a song'.",
                "For questions, invert: Is there...? Are there...?"
            ],
            quizQuestion: "Complete: ___ many people at the concert.",
            quizOptions: ["There are", "There is", "There am"],
            quizAnswer: "There are",
            quizExplanation: "Many people is plural, so use there are.",
            level: .beginner,
            systemImage: "mappin.and.ellipse",
            tint: .teal
        ),
        GrammarTopic(
            title: "Past simple",
            tagline: "finished actions",
            summary: "Use past simple for actions that started and finished in the past.",
            formula: "subject + past verb + time/context",
            whenToUse: "It helps you tell stories: what happened, when it happened, and what changed.",
            examples: [
                GrammarTopicExample(sentence: "I watched a video yesterday.", note: "Finished action with a past time."),
                GrammarTopicExample(sentence: "She went home after class.", note: "Went is the past of go."),
                GrammarTopicExample(sentence: "They did not like the song.", note: "Use did not + base verb.")
            ],
            commonMistakes: [
                "After did not, use the base verb: did not go, not did not went.",
                "Irregular verbs need memorizing: go/went, hear/heard, make/made."
            ],
            quizQuestion: "Choose the correct negative.",
            quizOptions: ["I did not hear it.", "I did not heard it.", "I not heard it."],
            quizAnswer: "I did not hear it.",
            quizExplanation: "After did not, the verb returns to base form.",
            level: .beginner,
            systemImage: "clock.arrow.circlepath",
            tint: .orange
        ),
        GrammarTopic(
            title: "Present perfect",
            tagline: "past connected to now",
            summary: "Use present perfect when the past action matters now, or when the exact time is not the focus.",
            formula: "have/has + past participle",
            whenToUse: "Good for experiences, recent changes and results: I have learned, she has finished.",
            examples: [
                GrammarTopicExample(sentence: "I have learned five new words.", note: "The result matters now."),
                GrammarTopicExample(sentence: "She has never been to London.", note: "Life experience."),
                GrammarTopicExample(sentence: "They have just arrived.", note: "Recent event.")
            ],
            commonMistakes: [
                "Do not use present perfect with a finished time like yesterday.",
                "Use has with he, she and it."
            ],
            quizQuestion: "Choose the present perfect sentence.",
            quizOptions: ["I have seen that video.", "I saw that video yesterday.", "I have see that video."],
            quizAnswer: "I have seen that video.",
            quizExplanation: "Have + past participle creates present perfect.",
            level: .intermediate,
            systemImage: "clock.badge.checkmark",
            tint: .blue
        ),
        GrammarTopic(
            title: "Passive voice",
            tagline: "focus on the action",
            summary: "Use passive voice when the action or result matters more than who did it.",
            formula: "be + past participle",
            whenToUse: "Common in news, explanations and descriptions: was written, is played, has been recorded.",
            examples: [
                GrammarTopicExample(sentence: "The song was written in 2020.", note: "The song is the focus."),
                GrammarTopicExample(sentence: "English is spoken in many countries.", note: "General fact."),
                GrammarTopicExample(sentence: "The video has been watched millions of times.", note: "Present perfect passive.")
            ],
            commonMistakes: [
                "Do not forget be: say 'was written', not 'written' alone.",
                "Use by only when the agent matters: written by Adele."
            ],
            quizQuestion: "Choose the passive sentence.",
            quizOptions: ["The song was recorded yesterday.", "The song recorded yesterday.", "They recorded the song yesterday."],
            quizAnswer: "The song was recorded yesterday.",
            quizExplanation: "Passive uses be + past participle: was recorded.",
            level: .intermediate,
            systemImage: "arrow.triangle.branch",
            tint: .indigo
        ),
        GrammarTopic(
            title: "Reported speech",
            tagline: "say what someone said",
            summary: "Use reported speech to tell another person what someone said, usually shifting tense back.",
            formula: "said/told + that + shifted clause",
            whenToUse: "Useful for stories, conversations and explaining lyrics in your own words.",
            examples: [
                GrammarTopicExample(sentence: "She said that she was tired.", note: "Am becomes was."),
                GrammarTopicExample(sentence: "He told me he liked the song.", note: "Like becomes liked."),
                GrammarTopicExample(sentence: "They said they would call later.", note: "Will becomes would.")
            ],
            commonMistakes: [
                "After told, mention the person: told me, told her, told us.",
                "Do not keep quotation marks when you report indirectly."
            ],
            quizQuestion: "Direct: 'I am busy.' Reported:",
            quizOptions: ["She said she was busy.", "She said she is busy yesterday.", "She told busy."],
            quizAnswer: "She said she was busy.",
            quizExplanation: "In reported speech, am often shifts to was.",
            level: .intermediate,
            systemImage: "text.bubble.fill",
            tint: .purple
        ),
        GrammarTopic(
            title: "Conditionals",
            tagline: "real and imagined results",
            summary: "Use conditionals to connect a condition with a result.",
            formula: "if + condition, result",
            whenToUse: "First conditional talks about real future possibilities; second conditional talks about imagined situations.",
            examples: [
                GrammarTopicExample(sentence: "If I practice, I will improve.", note: "Real future possibility."),
                GrammarTopicExample(sentence: "If I had more time, I would study more.", note: "Imagined present."),
                GrammarTopicExample(sentence: "If the song is slow, I can understand it.", note: "Real condition.")
            ],
            commonMistakes: [
                "Do not use will in the if-clause: say 'If I practice', not 'If I will practice'.",
                "Second conditional uses past form + would."
            ],
            quizQuestion: "Choose the first conditional.",
            quizOptions: ["If I practice, I will improve.", "If I practiced, I would improve.", "If I will practice, I improve."],
            quizAnswer: "If I practice, I will improve.",
            quizExplanation: "First conditional: if + present, will + verb.",
            level: .intermediate,
            systemImage: "arrow.left.and.right",
            tint: .green
        ),
        GrammarTopic(
            title: "Relative clauses",
            tagline: "who, which, that",
            summary: "Use relative clauses to add information about a person, thing or idea without starting a new sentence.",
            formula: "noun + who/which/that + clause",
            whenToUse: "It makes your speech smoother: the singer who..., the song that...",
            examples: [
                GrammarTopicExample(sentence: "The singer who wrote this song is famous.", note: "Who refers to a person."),
                GrammarTopicExample(sentence: "The video that I watched was helpful.", note: "That refers to a thing."),
                GrammarTopicExample(sentence: "This is the app which helps me practice.", note: "Which refers to a thing.")
            ],
            commonMistakes: [
                "Use who for people when possible.",
                "Do not repeat the subject: 'the song that I like', not 'the song that I like it'."
            ],
            quizQuestion: "Choose the natural sentence.",
            quizOptions: ["The song that I like is new.", "The song that I like it is new.", "The song who I like is new."],
            quizAnswer: "The song that I like is new.",
            quizExplanation: "Do not repeat it after the relative clause.",
            level: .intermediate,
            systemImage: "link",
            tint: .orange
        ),
        GrammarTopic(
            title: "Mixed conditionals",
            tagline: "past cause, present result",
            summary: "Use mixed conditionals when a past situation has a present result, or a present condition affected a past result.",
            formula: "if + past perfect, would + base verb",
            whenToUse: "Useful for regret, reflection and complex explanations.",
            examples: [
                GrammarTopicExample(sentence: "If I had practiced more, I would be more confident now.", note: "Past action, present result."),
                GrammarTopicExample(sentence: "If she spoke English, she would have understood the interview.", note: "Present ability, past result."),
                GrammarTopicExample(sentence: "If we had left earlier, we would be there now.", note: "Past decision, present situation.")
            ],
            commonMistakes: [
                "Keep the timeline clear: past perfect for the past cause, would for the present result.",
                "Do not mix randomly; decide which time each clause refers to."
            ],
            quizQuestion: "Choose the mixed conditional.",
            quizOptions: ["If I had studied, I would understand it now.", "If I study, I will understand it.", "If I studied, I would understand it."],
            quizAnswer: "If I had studied, I would understand it now.",
            quizExplanation: "Past perfect cause plus present result.",
            level: .advanced,
            systemImage: "point.3.connected.trianglepath.dotted",
            tint: .blue
        ),
        GrammarTopic(
            title: "Inversion",
            tagline: "negative adverbials",
            summary: "Use inversion after negative or limiting adverbials to create emphasis and a formal tone.",
            formula: "negative adverbial + auxiliary + subject + verb",
            whenToUse: "Common in advanced writing and dramatic statements: never have I..., rarely do we...",
            examples: [
                GrammarTopicExample(sentence: "Never have I heard such a clear explanation.", note: "Never triggers inversion."),
                GrammarTopicExample(sentence: "Rarely do we notice every word in a song.", note: "Do supports present simple."),
                GrammarTopicExample(sentence: "Hardly had I arrived when the lesson began.", note: "Hardly had... when...")
            ],
            commonMistakes: [
                "Do not forget the auxiliary after the negative adverbial.",
                "Use inversion sparingly; it sounds formal or emphatic."
            ],
            quizQuestion: "Choose the inverted sentence.",
            quizOptions: ["Never have I heard this song.", "Never I have heard this song.", "Never I heard this song."],
            quizAnswer: "Never have I heard this song.",
            quizExplanation: "After never at the beginning, use auxiliary + subject.",
            level: .advanced,
            systemImage: "arrow.up.arrow.down",
            tint: .indigo
        ),
        GrammarTopic(
            title: "Hedging",
            tagline: "sound precise, not absolute",
            summary: "Use hedging to make claims softer, more careful and more academic.",
            formula: "may/might/seems/tends to + claim",
            whenToUse: "Useful when interpreting lyrics, giving opinions or writing nuanced arguments.",
            examples: [
                GrammarTopicExample(sentence: "The line may suggest regret.", note: "May softens the interpretation."),
                GrammarTopicExample(sentence: "This phrase seems more informal.", note: "Seems avoids sounding too absolute."),
                GrammarTopicExample(sentence: "Learners tend to confuse these tenses.", note: "Tend to describes a pattern.")
            ],
            commonMistakes: [
                "Do not overuse hedging in every sentence.",
                "Choose a hedge that matches your certainty: might is weaker than probably."
            ],
            quizQuestion: "Which sentence is hedged?",
            quizOptions: ["The lyric may suggest sadness.", "The lyric means sadness forever.", "This is always wrong."],
            quizAnswer: "The lyric may suggest sadness.",
            quizExplanation: "May suggest makes the claim careful and flexible.",
            level: .advanced,
            systemImage: "scale.3d",
            tint: .purple
        ),
        GrammarTopic(
            title: "Cleft sentences",
            tagline: "emphasis",
            summary: "Use cleft sentences to emphasize one part of a sentence by splitting the idea.",
            formula: "it is/was + focus + that/who + clause",
            whenToUse: "Great for contrast: It was the chorus that helped me remember the phrase.",
            examples: [
                GrammarTopicExample(sentence: "It was the melody that caught my attention.", note: "The melody is emphasized."),
                GrammarTopicExample(sentence: "What I need is more listening practice.", note: "What-cleft emphasizes the need."),
                GrammarTopicExample(sentence: "It is the context that changes the meaning.", note: "The context is the focus.")
            ],
            commonMistakes: [
                "Make sure the sentence still has a full clause after that or who.",
                "Use clefts for emphasis, not for every ordinary sentence."
            ],
            quizQuestion: "Choose the cleft sentence.",
            quizOptions: ["It was the rhythm that helped me.", "The rhythm helped me.", "It rhythm helped was me."],
            quizAnswer: "It was the rhythm that helped me.",
            quizExplanation: "It was + focus + that creates the cleft.",
            level: .advanced,
            systemImage: "spotlight",
            tint: .green
        ),
        GrammarTopic(
            title: "Advanced passive",
            tagline: "reporting verbs",
            summary: "Use advanced passive structures to report beliefs, claims and expectations in a formal way.",
            formula: "subject + is said/believed/expected + to + verb",
            whenToUse: "Common in news and formal writing: is said to, is thought to, is expected to.",
            examples: [
                GrammarTopicExample(sentence: "The singer is said to be working on a new album.", note: "Reported claim."),
                GrammarTopicExample(sentence: "The song is believed to have influenced many artists.", note: "Perfect infinitive for earlier influence."),
                GrammarTopicExample(sentence: "The concert is expected to sell out.", note: "Expectation.")
            ],
            commonMistakes: [
                "Use to after reporting passives: is said to be, not is said be.",
                "Use have + participle when the reported action happened earlier."
            ],
            quizQuestion: "Choose the advanced passive.",
            quizOptions: ["The artist is said to be recording.", "The artist said to be recording.", "The artist is said be recording."],
            quizAnswer: "The artist is said to be recording.",
            quizExplanation: "Advanced reporting passive: is said to be.",
            level: .advanced,
            systemImage: "newspaper.fill",
            tint: .orange
        )
    ]
}

private struct GrammarTopicLessonBlock: Identifiable {
    let id = UUID()
    let title: String
    let body: String

    static func defaults(title: String, summary: String, formula: String) -> [GrammarTopicLessonBlock] {
        [
            GrammarTopicLessonBlock(title: "1. Notice it", body: "Find \(title.lowercased()) in a short example before trying to produce it."),
            GrammarTopicLessonBlock(title: "2. Understand the job", body: summary),
            GrammarTopicLessonBlock(title: "3. Control the form", body: "Use the pattern slowly: \(formula)"),
            GrammarTopicLessonBlock(title: "4. Produce your own", body: "Write one sentence that is true for you, then check the grammar.")
        ]
    }
}

private struct GrammarTopicPracticeTask: Identifiable, Hashable {
    let id: String
    let kind: String
    let title: String
    let instruction: String
    let prompt: String
    let options: [String]
    let answer: String
    let explanation: String

    var kindLabel: String {
        kind
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    static func defaults(title: String, formula: String, example: String?, mistake: String?) -> [GrammarTopicPracticeTask] {
        let exampleText = example ?? "Create one clear example with \(title.lowercased())."
        let mistakeText = mistake ?? "Check meaning and form before choosing the answer."

        return [
            GrammarTopicPracticeTask(
                id: "notice",
                kind: "multiple_choice",
                title: "Notice",
                instruction: "Choose the most useful thing to notice.",
                prompt: exampleText,
                options: ["Meaning, form and context", "Only the translation", "Only the spelling"],
                answer: "Meaning, form and context",
                explanation: "A topic becomes useful when you connect the structure with real meaning."
            ),
            GrammarTopicPracticeTask(
                id: "pattern",
                kind: "sentence_builder",
                title: "Build",
                instruction: "Choose the pattern that controls the sentence.",
                prompt: formula,
                options: [formula, "random words without context", "memorise only the title"],
                answer: formula,
                explanation: "The pattern is your scaffold for producing the sentence."
            ),
            GrammarTopicPracticeTask(
                id: "mistake",
                kind: "error_fix",
                title: "Fix",
                instruction: "Choose the safest correction strategy.",
                prompt: mistakeText,
                options: [
                    "Rewrite the sentence and check the form.",
                    "Ignore it if the idea is clear.",
                    "Translate word by word."
                ],
                answer: "Rewrite the sentence and check the form.",
                explanation: "Rewriting the sentence helps you check the full structure, not only one word."
            ),
            GrammarTopicPracticeTask(
                id: "production",
                kind: "production",
                title: "Your turn",
                instruction: "Produce your own sentence.",
                prompt: "Use \(title.lowercased()) to say something true about your life, music, work or plans.",
                options: [],
                answer: "",
                explanation: "Production is the step that turns recognition into usable English."
            )
        ]
    }
}

private struct GrammarTopicExample: Identifiable {
    let id = UUID()
    let sentence: String
    let note: String
}

private struct GrammarPracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var learningProgress: LearningProgressStore
    @State private var index = 0
    @State private var selectedOption: String?
    @State private var feedback: LearningFeedback?
    @State private var remoteQuestions: [GrammarQuestion] = []
    @State private var loadedRemoteLevel: TopicCEFRLevel?
    @State private var isLoadingQuestions = false

    private var selectedCEFRLevel: TopicCEFRLevel {
        TopicCEFRLevel(rawValue: learningProgress.cefrLevelCode) ?? TopicCEFRLevel(profileLevel: learningProgress.profile.level)
    }

    private var level: LearningLevel {
        selectedCEFRLevel.fallbackLearningLevel
    }

    private var questions: [GrammarQuestion] {
        remoteQuestions.isEmpty ? GrammarQuestion.deck(for: level) : remoteQuestions
    }

    var body: some View {
        let safeIndex = min(index, max(questions.count - 1, 0))
        let question = questions[safeIndex]

        ZStack {
            TranslatePracticeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ExerciseSessionTopBar(
                        title: "Gramática",
                        closeAction: { dismiss() }
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Elegí la forma")
                            .font(.system(size: 39, weight: .black, design: .rounded))
                            .foregroundStyle(TranslateTheme.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)

                        Text("Detectá la opción que suena natural.")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(TranslateTheme.muted)
                    }

                    if isLoadingQuestions {
                        Label("Cargando...", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(TranslateTheme.muted)
                    }

                    ProgressHeader(currentIndex: safeIndex, total: questions.count)

                    VStack(alignment: .leading, spacing: 16) {
                        Label(question.level.title, systemImage: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(TranslateTheme.primary)

                        Text(question.prompt)
                            .font(.system(size: 25, weight: .black, design: .rounded))
                            .foregroundStyle(TranslateTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(question.options, id: \.self) { option in
                            Button {
                                selectedOption = option
                                validate(question, option: option)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: selectedOption == option ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(selectedOption == option ? TranslateTheme.primary : TranslateTheme.muted.opacity(0.62))

                                    Text(option)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(TranslateTheme.ink)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer()
                                }
                                .padding(14)
                                .background(selectedOption == option ? TranslateTheme.primary.opacity(0.10) : TranslateTheme.softSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }

                        if let feedback {
                            LearningFeedbackView(feedback: feedback)
                        }

                        Button {
                            moveNext()
                        } label: {
                            Label("Siguiente", systemImage: "arrow.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(TranslateSecondaryButtonStyle())
                    }
                    .padding(22)
                    .background(TranslateTheme.surface.opacity(0.97), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 24, x: 0, y: 12)
                }
                .padding(.horizontal, 26)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task(id: selectedCEFRLevel) {
            await loadGrammarQuestions(for: selectedCEFRLevel)
        }
        .onChange(of: learningProgress.cefrLevelCode) { _, _ in
            index = 0
            remoteQuestions = []
            loadedRemoteLevel = nil
            selectedOption = nil
            feedback = nil
        }
    }

    @MainActor
    private func loadGrammarQuestions(for selectedLevel: TopicCEFRLevel, forceRefresh: Bool = false) async {
        if !forceRefresh, loadedRemoteLevel == selectedLevel, !remoteQuestions.isEmpty {
            return
        }

        isLoadingQuestions = true

        do {
            let response = try await LocupomTopicsAPIClient.fetchPracticeExercises(
                skill: "grammar",
                level: selectedLevel.rawValue,
                learnerId: learningProgress.apiLearnerId,
                completedKeys: Array(learningProgress.completedRemoteContentKeys)
            )
            let mappedQuestions = response.exercises.compactMap {
                GrammarQuestion(remote: $0, fallbackLevel: selectedLevel.fallbackLearningLevel)
            }

            loadedRemoteLevel = selectedLevel
            remoteQuestions = mappedQuestions
            index = 0
            selectedOption = nil
            feedback = nil
        } catch {
            remoteQuestions = []
            loadedRemoteLevel = selectedLevel
        }

        isLoadingQuestions = false
    }

    private func validate(_ question: GrammarQuestion, option: String) {
        let isCorrect = option == question.answer
        learningProgress.recordModule(LearningModule.grammar.rawValue, wasCorrect: isCorrect)
        if isCorrect {
            learningProgress.recordErrorResolved(module: LearningModule.grammar.rawValue, expected: question.answer)
            markGrammarCompletedIfNeeded(question)
        } else {
            learningProgress.recordError(
                module: LearningModule.grammar.rawValue,
                expected: question.answer,
                actual: option,
                context: question.prompt
            )
        }

        feedback = LearningFeedback(
            title: isCorrect ? "Correcto" : "Casi",
            detail: isCorrect ? question.explanation : "Respuesta esperada: \(question.answer)",
            score: isCorrect ? 1 : 0,
            isCorrect: isCorrect
        )
    }

    private func markGrammarCompletedIfNeeded(_ question: GrammarQuestion) {
        guard let apiContentId = question.apiContentId else {
            return
        }

        let learnerId = learningProgress.apiLearnerId
        let completedLevel = selectedCEFRLevel.rawValue
        let completedTitle = question.prompt
        let didInsert = learningProgress.markRemoteContentCompleted(kind: "exercise", itemId: apiContentId)
        guard didInsert else {
            return
        }

        Task {
            try? await LocupomTopicsAPIClient.markCompleted(
                learnerId: learnerId,
                kind: "exercise",
                itemId: apiContentId,
                level: completedLevel,
                title: completedTitle
            )
        }
    }

    private func moveNext() {
        index = (index + 1) % questions.count
        selectedOption = nil
        feedback = nil
    }
}

private struct SpeakingPracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var learningProgress: LearningProgressStore
    @StateObject private var speaker = PromptSpeaker()
    @StateObject private var speechModel = SpeechPracticeModel()
    @State private var index = 0
    @State private var remotePrompts: [SpeakingPrompt] = []
    @State private var loadedRemoteLevel: TopicCEFRLevel?
    @State private var isLoadingPrompts = false
    @State private var feedback: LearningFeedback?
    @State private var lastCheckedTranscript = ""

    private var selectedCEFRLevel: TopicCEFRLevel {
        TopicCEFRLevel(rawValue: learningProgress.cefrLevelCode) ?? TopicCEFRLevel(profileLevel: learningProgress.profile.level)
    }

    private var level: LearningLevel {
        selectedCEFRLevel.fallbackLearningLevel
    }

    private var prompts: [SpeakingPrompt] {
        remotePrompts.isEmpty ? SpeakingPrompt.deck(for: level) : remotePrompts
    }

    var body: some View {
        let safeIndex = min(index, max(prompts.count - 1, 0))
        let prompt = prompts[safeIndex]

        ZStack {
            TranslatePracticeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ExerciseSessionTopBar(
                        title: "Speaking",
                        closeAction: { dismiss() }
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Repetí & compará")
                            .font(.system(size: 39, weight: .black, design: .rounded))
                            .foregroundStyle(TranslateTheme.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)

                        Text("Decí la frase y revisá qué reconoció el sistema.")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(TranslateTheme.muted)
                    }

                    if isLoadingPrompts {
                        Label("Cargando...", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(TranslateTheme.muted)
                    }

                    ProgressHeader(currentIndex: safeIndex, total: prompts.count)

                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text(prompt.title)
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .foregroundStyle(TranslateTheme.ink)

                                Spacer(minLength: 0)
                            }

                            Text(prompt.instruction.isEmpty ? prompt.translation : prompt.instruction)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(TranslateTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if !prompt.targetLanguage.isEmpty {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
                                ForEach(prompt.targetLanguage.prefix(3), id: \.self) { target in
                                    Text(target)
                                        .font(.system(size: 12, weight: .black, design: .rounded))
                                        .foregroundStyle(TranslateTheme.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.72)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(TranslateTheme.primary.opacity(0.10), in: Capsule())
                                }
                            }
                        }

                        Text("Decí esta frase")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(TranslateTheme.muted)

                        Text(prompt.phrase)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(TranslateTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(prompt.source == "Local" && level == .advanced ? "Decilo con ritmo natural." : "Podés usarlo como arranque y completar la idea en voz alta.")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(TranslateTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 10) {
                            Button {
                                speaker.speak(prompt.phrase, rate: level.speechRate)
                            } label: {
                                Label("Escuchar", systemImage: "speaker.wave.2.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(TranslateSecondaryButtonStyle())

                            Button {
                                speechModel.toggleRecording()
                            } label: {
                                Label(speechModel.isRecording ? "Parar" : "Hablar", systemImage: speechModel.isRecording ? "stop.fill" : "mic.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(TranslatePrimaryButtonStyle())
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reconocido")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(TranslateTheme.muted)

                            Text(speechModel.transcript.isEmpty ? "..." : speechModel.transcript)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(TranslateTheme.ink)
                                .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
                                .padding(14)
                                .background(TranslateTheme.softSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        if let message = speechModel.message {
                            Label(message, systemImage: "info.circle")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(TranslateTheme.muted)
                        }

                        if let feedback {
                            LearningFeedbackView(feedback: feedback)
                            if !feedback.isCorrect {
                                LearningWordDiffView(answer: lastCheckedTranscript, target: prompt.phrase)
                            }
                        }

                        HStack(spacing: 10) {
                            Button {
                                validate(prompt)
                            } label: {
                                Label("Comprobar", systemImage: "checkmark")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(TranslatePrimaryButtonStyle())
                            .disabled(speechModel.transcript.trimmed.isEmpty)

                            Button {
                                moveNext()
                            } label: {
                                Label("Siguiente", systemImage: "arrow.right")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(TranslateSecondaryButtonStyle())
                        }
                    }
                    .padding(22)
                    .background(TranslateTheme.surface.opacity(0.97), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: TranslateTheme.primary.opacity(0.08), radius: 24, x: 0, y: 12)
                }
                .padding(.horizontal, 26)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task(id: selectedCEFRLevel) {
            await loadSpeakingPrompts(for: selectedCEFRLevel)
        }
        .onChange(of: learningProgress.cefrLevelCode) { _, _ in
            index = 0
            remotePrompts = []
            loadedRemoteLevel = nil
            speechModel.resetTranscript()
            feedback = nil
        }
    }

    @MainActor
    private func loadSpeakingPrompts(for selectedLevel: TopicCEFRLevel, forceRefresh: Bool = false) async {
        if !forceRefresh, loadedRemoteLevel == selectedLevel, !remotePrompts.isEmpty {
            return
        }

        isLoadingPrompts = true

        do {
            let response = try await LocupomTopicsAPIClient.fetchSpeakingPrompts(
                level: selectedLevel.rawValue,
                learnerId: learningProgress.apiLearnerId,
                completedKeys: Array(learningProgress.completedRemoteContentKeys)
            )
            let mappedPrompts = response.speakingPrompts.compactMap {
                SpeakingPrompt(remote: $0, fallbackLevel: selectedLevel.fallbackLearningLevel)
            }

            loadedRemoteLevel = selectedLevel
            remotePrompts = mappedPrompts
            index = 0
            speechModel.resetTranscript()
            feedback = nil
            lastCheckedTranscript = ""
        } catch {
            remotePrompts = []
            loadedRemoteLevel = selectedLevel
        }

        isLoadingPrompts = false
    }

    private func validate(_ prompt: SpeakingPrompt) {
        lastCheckedTranscript = speechModel.transcript
        let result = TextMatcher.evaluate(answer: speechModel.transcript, target: prompt.phrase)
        let isCorrect = level.acceptsCloseAnswers ? result.isClose : result.isCorrect
        learningProgress.recordModule(LearningModule.speaking.rawValue, wasCorrect: isCorrect)
        if isCorrect {
            learningProgress.recordErrorResolved(module: LearningModule.speaking.rawValue, expected: prompt.phrase)
            markSpeakingCompletedIfNeeded(prompt)
        } else {
            learningProgress.recordError(
                module: LearningModule.speaking.rawValue,
                expected: prompt.phrase,
                actual: speechModel.transcript,
                context: prompt.translation
            )
        }

        feedback = LearningFeedback(
            title: isCorrect ? "Suena bien" : "Probemos mas lento",
            detail: isCorrect ? prompt.phrase : "Frase objetivo: \(prompt.phrase)",
            score: result.similarity,
            isCorrect: isCorrect
        )
    }

    private func markSpeakingCompletedIfNeeded(_ prompt: SpeakingPrompt) {
        guard let apiContentId = prompt.apiContentId else {
            return
        }

        let learnerId = learningProgress.apiLearnerId
        let completedLevel = selectedCEFRLevel.rawValue
        let completedTitle = prompt.title
        let didInsert = learningProgress.markRemoteContentCompleted(kind: "speaking", itemId: apiContentId)
        guard didInsert else {
            return
        }

        Task {
            try? await LocupomTopicsAPIClient.markCompleted(
                learnerId: learnerId,
                kind: "speaking",
                itemId: apiContentId,
                level: completedLevel,
                title: completedTitle
            )
        }
    }

    private func moveNext() {
        index = (index + 1) % prompts.count
        speechModel.resetTranscript()
        lastCheckedTranscript = ""
        feedback = nil
    }
}

private struct ProgressHeader: View {
    let currentIndex: Int
    let total: Int

    var body: some View {
        EmptyView()
    }
}

private struct WordSummaryView: View {
    let toolkit: WordToolkit
    let playAudio: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(toolkit.word)
                        .font(.largeTitle.bold())
                    if let phonetic = toolkit.phonetic {
                        Text(phonetic)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button(action: playAudio) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(toolkit.audioURL == nil)
            }

            HStack(spacing: 8) {
                LearningSourcePill(title: "Dictionary", systemImage: "book")
                LearningSourcePill(title: "Datamuse", systemImage: "point.3.connected.trianglepath.dotted")
                LearningSourcePill(title: "Tatoeba", systemImage: "quote.bubble")
            }
        }
        .padding(16)
        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct LearningAPISection<Content: View>: View {
    let title: String
    let source: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(source)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemBackground), in: Capsule())
            }

            content
        }
        .padding(16)
        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct LearningSourcePill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemBackground), in: Capsule())
    }
}

private struct LearningNoticeView: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.tint)
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct WritingCorrectionRow: View {
    let correction: WritingCorrection
    let apply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text(correction.displayMessage)
                        .font(.headline)
                    Text(correction.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Por que: \(correction.ruleDescription)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(correction.category)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tint)
                }

                Spacer()
            }

            Text(correction.context)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(LocupomTheme.softSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            if !correction.replacements.isEmpty {
                HStack(alignment: .center, spacing: 8) {
                    Text(correction.replacements.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Spacer()

                    Button("Usar") {
                        apply()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(12)
        .background(LocupomTheme.softSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ExampleBox: View {
    let title: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(bodyText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(LocupomTheme.softSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct TokenArea: View {
    let title: String
    let tokens: [WordToken]
    let action: (WordToken) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            FlowLayout(spacing: 8) {
                ForEach(tokens) { token in
                    Button {
                        action(token)
                    } label: {
                        Text(token.text)
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .padding(10)
            .background(LocupomTheme.softSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > width, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }

            rowWidth += size.width + (rowWidth > 0 ? spacing : 0)
            rowHeight = max(rowHeight, size.height)
        }

        totalHeight += rowHeight
        return CGSize(width: width, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var point = bounds.origin
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if point.x + size.width > bounds.maxX, point.x > bounds.minX {
                point.x = bounds.minX
                point.y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: point, proposal: ProposedViewSize(size))
            point.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

@MainActor
private final class PromptSpeaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String, rate: Float = 0.45) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
    }
}

@MainActor
private final class PronunciationPlayer: ObservableObject {
    private var player: AVPlayer?

    func play(_ url: URL) {
        player = AVPlayer(url: url)
        player?.play()
    }
}

@MainActor
private final class SpeechPracticeModel: NSObject, ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var message: String?

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            requestAuthorizationAndStart()
        }
    }

    func resetTranscript() {
        transcript = ""
        message = nil
    }

    private func requestAuthorizationAndStart() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self else { return }

                switch status {
                case .authorized:
                    self.startRecording()
                case .denied:
                    self.message = "Permiso de reconocimiento denegado."
                case .restricted:
                    self.message = "Reconocimiento restringido en este dispositivo."
                case .notDetermined:
                    self.message = "Permiso de reconocimiento pendiente."
                @unknown default:
                    self.message = "No se pudo iniciar el reconocimiento."
                }
            }
        }
    }

    private func startRecording() {
        stopRecording()
        transcript = ""
        message = nil

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            message = "Reconocimiento de voz no disponible."
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            recognitionRequest = request

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
                request?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true

            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                    }

                    if error != nil || result?.isFinal == true {
                        self.stopRecording()
                    }
                }
            }
        } catch {
            message = error.localizedDescription
            stopRecording()
        }
    }

    private func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
    }
}

private enum LearningModule: String, CaseIterable, Identifiable, Hashable {
    case daily
    case review
    case songs
    case explorer
    case topics
    case translate
    case writing
    case vocabulary
    case listening
    case reading
    case speaking
    case sentences
    case grammar

    var id: Self { self }

    static var practiceStatsModules: [LearningModule] {
        [.songs, .topics, .reading, .vocabulary, .listening, .sentences, .grammar, .speaking, .translate, .writing]
    }

    var title: String {
        switch self {
        case .daily: "Rutina"
        case .review: "Repaso"
        case .songs: "Canciones"
        case .explorer: "Explorar"
        case .topics: "Temas"
        case .translate: "Traducir"
        case .writing: "Escribir"
        case .vocabulary: "Vocabulario"
        case .listening: "Escuchar"
        case .reading: "Leer"
        case .speaking: "Hablar"
        case .sentences: "Frases"
        case .grammar: "Gramatica"
        }
    }

    var homeTitle: String {
        switch self {
        case .daily: "Rutina diaria"
        case .review: "Repaso"
        case .songs: "Canciones"
        case .explorer: "Explorar"
        case .topics: "Temas"
        case .translate: "Traducir"
        case .writing: "Escribir"
        case .vocabulary: "Vocabulario"
        case .listening: "Escuchar"
        case .reading: "Leer"
        case .speaking: "Hablar"
        case .sentences: "Frases"
        case .grammar: "Gramatica"
        }
    }

    var subtitle: String {
        switch self {
        case .daily: "Sesion guiada"
        case .review: "Repeticion espaciada"
        case .songs: "Escucha y completa"
        case .explorer: "Diccionario y ejemplos"
        case .topics: "Temas por nivel"
        case .translate: "Traduccion libre"
        case .writing: "Escritura guiada"
        case .vocabulary: "Palabras utiles"
        case .listening: "Escucha y escribe"
        case .reading: "Comprension lectora"
        case .speaking: "Repite y compara"
        case .sentences: "Arma oraciones"
        case .grammar: "Elegi la opcion natural"
        }
    }

    var duration: String {
        switch self {
        case .daily: "15m"
        case .review: "4m"
        case .songs: "10m"
        case .explorer: "4m"
        case .topics: "8m"
        case .translate: "6m"
        case .writing: "6m"
        case .vocabulary: "5m"
        case .listening: "7m"
        case .reading: "5m"
        case .speaking: "6m"
        case .sentences: "5m"
        case .grammar: "5m"
        }
    }

    var level: String {
        switch self {
        case .daily: "Plan"
        case .review: "Memoria"
        case .songs: "Inmersivo"
        case .explorer: "API"
        case .topics: "CEFR"
        case .translate: "Libre"
        case .writing: "Coach"
        case .vocabulary: "Suave"
        case .listening: "Oido"
        case .reading: "Texto"
        case .speaking: "Voz"
        case .sentences: "Orden"
        case .grammar: "Uso"
        }
    }

    var systemImage: String {
        switch self {
        case .daily: "calendar"
        case .review: "repeat.circle"
        case .songs: "music.note.list"
        case .explorer: "sparkle.magnifyingglass"
        case .topics: "map.fill"
        case .translate: "globe.americas"
        case .writing: "square.and.pencil"
        case .vocabulary: "character.book.closed"
        case .listening: "ear"
        case .reading: "book.pages.fill"
        case .speaking: "mic"
        case .sentences: "text.word.spacing"
        case .grammar: "checklist.checked"
        }
    }

    var tint: Color {
        switch self {
        case .daily: .teal
        case .review: .mint
        case .songs: .teal
        case .explorer: .purple
        case .topics: .blue
        case .translate: .cyan
        case .writing: .indigo
        case .vocabulary: .indigo
        case .listening: .orange
        case .reading: .blue
        case .speaking: .pink
        case .sentences: .green
        case .grammar: .blue
        }
    }

    var practiceListTitle: String {
        switch self {
        case .grammar: "Gramática"
        default: title
        }
    }

    var practiceListSubtitle: String {
        switch self {
        case .translate: "Traducción libre"
        case .writing: "Respuesta guiada"
        case .listening: "Escucha y escribe"
        case .reading: "Comprensión guiada"
        case .speaking: "Repite y compara"
        case .sentences: "Armá oraciones"
        case .grammar: "La opción natural"
        default: subtitle
        }
    }

    var practiceListDuration: String {
        duration.replacingOccurrences(of: "m", with: " min")
    }

    var practiceListSystemImage: String {
        switch self {
        case .translate: "globe.americas"
        case .writing: "square.and.pencil"
        case .listening: "headphones"
        case .reading: "book.pages.fill"
        case .speaking: "mic.fill"
        case .sentences: "list.bullet"
        case .grammar: "list.bullet.rectangle"
        default: systemImage
        }
    }

    var practiceAccent: Color {
        switch self {
        case .translate: Color(red: 0.08, green: 0.72, blue: 0.82)
        case .writing: Color(red: 0.45, green: 0.31, blue: 0.96)
        case .listening: Color(red: 1.0, green: 0.57, blue: 0.0)
        case .reading: Color(red: 0.18, green: 0.59, blue: 0.98)
        case .speaking: Color(red: 0.96, green: 0.31, blue: 0.50)
        case .sentences: Color(red: 0.12, green: 0.76, blue: 0.39)
        case .grammar: Color(red: 0.04, green: 0.57, blue: 0.89)
        default: tint
        }
    }

    var practiceIconBackground: Color {
        switch self {
        case .translate: Color(red: 0.84, green: 0.96, blue: 0.97)
        case .writing: Color(red: 0.91, green: 0.84, blue: 1.0)
        case .listening: Color(red: 1.0, green: 0.92, blue: 0.80)
        case .reading: Color(red: 0.84, green: 0.91, blue: 1.0)
        case .speaking: Color(red: 1.0, green: 0.85, blue: 0.90)
        case .sentences: Color(red: 0.84, green: 0.96, blue: 0.89)
        case .grammar: Color(red: 0.84, green: 0.94, blue: 0.99)
        default: tint.opacity(0.13)
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .daily:
            DailyRoutineView()
        case .review:
            ReviewQueueView()
        case .songs:
            SongsLearningView()
        case .explorer:
            WordExplorerView()
        case .topics:
            TopicsPracticeView()
                .locupomFloatingTabBarHidden(true)
        case .translate:
            TranslatePracticeView()
                .locupomFloatingTabBarHidden(true)
        case .writing:
            WritingCoachView()
                .locupomFloatingTabBarHidden(true)
        case .vocabulary:
            VocabularyPracticeView()
                .locupomFloatingTabBarHidden(true)
        case .listening:
            ListeningPracticeView()
                .locupomFloatingTabBarHidden(true)
        case .reading:
            ReadingPracticeView()
                .locupomFloatingTabBarHidden(true)
        case .speaking:
            SpeakingPracticeView()
                .locupomFloatingTabBarHidden(true)
        case .sentences:
            SentenceBuilderPracticeView()
                .locupomFloatingTabBarHidden(true)
        case .grammar:
            GrammarPracticeView()
                .locupomFloatingTabBarHidden(true)
        }
    }
}

private enum LearningGoal: String, CaseIterable, Identifiable {
    case balanced
    case words
    case ear
    case voice

    var id: Self { self }

    var title: String {
        switch self {
        case .balanced: "Mix"
        case .words: "Palabras"
        case .ear: "Oido"
        case .voice: "Voz"
        }
    }

    var detail: String {
        switch self {
        case .balanced: "rutina completa"
        case .words: "vocabulario y frases"
        case .ear: "listening y musica"
        case .voice: "speaking guiado"
        }
    }

    func includes(_ module: LearningModule) -> Bool {
        switch self {
        case .balanced:
            return true
        case .words:
            return [.daily, .review, .explorer, .topics, .reading, .vocabulary, .sentences, .grammar, .translate, .writing].contains(module)
        case .ear:
            return [.daily, .review, .listening, .songs, .explorer, .vocabulary].contains(module)
        case .voice:
            return [.daily, .review, .speaking, .listening, .sentences, .translate, .writing].contains(module)
        }
    }

    func recommendedModule(songCount: Int) -> LearningModule {
        switch self {
        case .balanced:
            return .daily
        case .words:
            return .review
        case .ear:
            return songCount > 0 ? .songs : .listening
        case .voice:
            return .speaking
        }
    }
}

private enum LearningSource: CaseIterable, Identifiable {
    case lyrics
    case dictionary
    case relatedWords
    case sentences
    case correction
    case translation

    var id: Self { self }

    var title: String {
        switch self {
        case .lyrics: "Letras"
        case .dictionary: "Dictionary API"
        case .relatedWords: "Datamuse"
        case .sentences: "Tatoeba"
        case .correction: "LanguageTool"
        case .translation: "MyMemory"
        }
    }

    var detail: String {
        switch self {
        case .lyrics: "Canciones sincronizadas cuando estan disponibles."
        case .dictionary: "Definiciones, fonetica y audio de pronunciacion."
        case .relatedWords: "Sinonimos y palabras relacionadas para ampliar vocabulario."
        case .sentences: "Frases reales con traduccion al espanol."
        case .correction: "Correcciones de gramatica y estilo al escribir."
        case .translation: "Traduccion opcional de textos cortos sin API key."
        }
    }

    var systemImage: String {
        switch self {
        case .lyrics: "music.quarternote.3"
        case .dictionary: "book.closed"
        case .relatedWords: "point.3.connected.trianglepath.dotted"
        case .sentences: "quote.bubble"
        case .correction: "wand.and.stars"
        case .translation: "globe.americas"
        }
    }
}

private struct VocabularyCard: Identifiable {
    let id: UUID
    let apiContentId: String?
    let word: String
    let translation: String
    let definition: String
    let example: String
    let level: LearningLevel

    init(
        apiContentId: String? = nil,
        word: String,
        translation: String,
        definition: String,
        example: String,
        level: LearningLevel
    ) {
        self.id = UUID()
        self.apiContentId = apiContentId
        self.word = word
        self.translation = translation
        self.definition = definition
        self.example = example
        self.level = level
    }

    init?(remote: LocupomRemoteVocabularyItem, fallbackLevel: LearningLevel) {
        let word = remote.word.trimmed
        guard !word.isEmpty else { return nil }

        self.init(
            apiContentId: remote.id,
            word: word,
            translation: remote.translation ?? remote.meaning ?? "Useful word",
            definition: remote.meaning ?? remote.usageNote ?? "Practice this word in context.",
            example: remote.example ?? remote.usageNote ?? "Make your own sentence with \(word).",
            level: remote.level.map(LearningLevel.fromCEFRCode) ?? fallbackLevel
        )
    }

    static func deck(for level: LearningLevel) -> [VocabularyCard] {
        Array(sampleDeck.filter { $0.level == level }.prefix(level.practiceLimit))
    }

    static let sampleDeck = [
        VocabularyCard(word: "home", translation: "casa / hogar", definition: "The place where you live or feel safe.", example: "I am going home.", level: .beginner),
        VocabularyCard(word: "want", translation: "querer", definition: "To wish for something.", example: "I want to learn.", level: .beginner),
        VocabularyCard(word: "friend", translation: "amigo / amiga", definition: "Someone you like and trust.", example: "She is my friend.", level: .beginner),
        VocabularyCard(word: "music", translation: "musica", definition: "Sounds arranged in rhythm and melody.", example: "I like music.", level: .beginner),
        VocabularyCard(word: "today", translation: "hoy", definition: "This day.", example: "Today is a good day.", level: .beginner),
        VocabularyCard(word: "belong", translation: "pertenecer / encajar", definition: "To be in the right place or group.", example: "You belong here.", level: .intermediate),
        VocabularyCard(word: "brave", translation: "valiente", definition: "Ready to face difficulty or fear.", example: "She was brave enough to try again.", level: .intermediate),
        VocabularyCard(word: "through", translation: "a traves de / por", definition: "From one side or stage to another.", example: "We got through the hard part.", level: .intermediate),
        VocabularyCard(word: "instead", translation: "en lugar de", definition: "As an alternative.", example: "I stayed home instead.", level: .intermediate),
        VocabularyCard(word: "wonder", translation: "preguntarse / maravilla", definition: "To think about something with curiosity.", example: "I wonder what it means.", level: .intermediate),
        VocabularyCard(word: "although", translation: "aunque", definition: "Used to contrast two ideas.", example: "Although it was late, we kept studying.", level: .intermediate),
        VocabularyCard(word: "eventually", translation: "finalmente / con el tiempo", definition: "After some time or after several events.", example: "Eventually, the chorus made sense.", level: .advanced),
        VocabularyCard(word: "meaningful", translation: "significativo", definition: "Important because it has value or purpose.", example: "That line felt meaningful.", level: .advanced),
        VocabularyCard(word: "nevertheless", translation: "sin embargo", definition: "Despite what was just mentioned.", example: "It was difficult; nevertheless, she continued.", level: .advanced),
        VocabularyCard(word: "ordinary", translation: "comun / normal", definition: "Not special or unusual.", example: "It was an ordinary morning.", level: .advanced),
        VocabularyCard(word: "meanwhile", translation: "mientras tanto", definition: "At the same time.", example: "Meanwhile, the melody changed.", level: .advanced),
        VocabularyCard(word: "approach", translation: "enfoque / acercarse", definition: "A way of dealing with something.", example: "This approach helps me remember words.", level: .advanced),
        VocabularyCard(word: "barely", translation: "apenas", definition: "Only just; almost not.", example: "I could barely hear the verse.", level: .advanced),
        VocabularyCard(word: "noticeable", translation: "notable / evidente", definition: "Easy to see or hear.", example: "Her progress was noticeable.", level: .advanced)
    ]
}

private struct ListeningItem: Identifiable {
    let id: UUID
    let apiContentId: String?
    let phrase: String
    let translation: String
    let level: LearningLevel
    let trackTitle: String
    let artistName: String

    init(
        apiContentId: String? = nil,
        phrase: String,
        translation: String,
        level: LearningLevel,
        trackTitle: String = "Locupom Voice",
        artistName: String = "Locupom"
    ) {
        self.id = UUID()
        self.apiContentId = apiContentId
        self.phrase = phrase
        self.translation = translation
        self.level = level
        self.trackTitle = trackTitle
        self.artistName = artistName
    }

    init?(remote: LocupomRemotePracticeExercise, fallbackLevel: LearningLevel) {
        let phrase = remote.phrase?.trimmed ?? remote.answer?.firstString?.trimmed ?? remote.prompt?.trimmed
        guard let phrase, !phrase.isEmpty else {
            return nil
        }

        self.init(
            apiContentId: remote.id,
            phrase: phrase,
            translation: remote.translation ?? remote.instruction,
            level: remote.level.trimmed.isEmpty ? fallbackLevel : LearningLevel.fromCEFRCode(remote.level),
            trackTitle: remote.trackTitle ?? remote.title,
            artistName: remote.artistName ?? "Locupom Voice"
        )
    }

    static func deck(for level: LearningLevel) -> [ListeningItem] {
        Array(sampleDeck.filter { $0.level == level }.prefix(level.practiceLimit))
    }

    static let sampleDeck = [
        ListeningItem(phrase: "I like this song.", translation: "Me gusta esta cancion.", level: .beginner),
        ListeningItem(phrase: "Can you help me?", translation: "Podes ayudarme?", level: .beginner),
        ListeningItem(phrase: "I am learning English.", translation: "Estoy aprendiendo ingles.", level: .beginner),
        ListeningItem(phrase: "This is my friend.", translation: "Este es mi amigo.", level: .beginner),
        ListeningItem(phrase: "I have never been there before.", translation: "Nunca estuve ahi antes.", level: .intermediate),
        ListeningItem(phrase: "Could you say that one more time?", translation: "Podrias decirlo una vez mas?", level: .intermediate),
        ListeningItem(phrase: "She is getting better every day.", translation: "Ella mejora cada dia.", level: .intermediate),
        ListeningItem(phrase: "I was about to call you.", translation: "Estaba por llamarte.", level: .intermediate),
        ListeningItem(phrase: "The lyrics are harder than I expected.", translation: "La letra es mas dificil de lo que esperaba.", level: .advanced),
        ListeningItem(phrase: "She kept studying even though she was exhausted.", translation: "Ella siguio estudiando aunque estaba agotada.", level: .advanced),
        ListeningItem(phrase: "I would have called you if I had known.", translation: "Te habria llamado si lo hubiera sabido.", level: .advanced),
        ListeningItem(phrase: "I can barely understand the chorus.", translation: "Apenas puedo entender el estribillo.", level: .advanced),
        ListeningItem(phrase: "By the end of the song, the meaning became clear.", translation: "Al final de la cancion, el significado quedo claro.", level: .advanced)
    ]
}

private struct SentencePuzzle: Identifiable {
    let id: UUID
    let apiContentId: String?
    let answer: String
    let translation: String
    let source: String
    let level: LearningLevel

    init(apiContentId: String? = nil, answer: String, translation: String, source: String = "Local", level: LearningLevel) {
        self.id = UUID()
        self.apiContentId = apiContentId
        self.answer = answer
        self.translation = translation
        self.source = source
        self.level = level
    }

    init?(example: SentenceExample) {
        let answer = example.text.trimmed
        guard let translation = example.translation?.trimmed,
              !answer.isEmpty,
              !translation.isEmpty else {
            return nil
        }

        self.init(
            answer: answer,
            translation: translation,
            source: "Tatoeba",
            level: SentencePuzzle.level(for: answer)
        )
    }

    init?(remote: LocupomRemotePracticeExercise, fallbackLevel: LearningLevel) {
        let answer = remote.answer?.firstString?.trimmed ?? remote.phrase?.trimmed ?? remote.prompt?.trimmed
        guard let answer, !answer.isEmpty else {
            return nil
        }

        self.init(
            apiContentId: remote.id,
            answer: answer,
            translation: remote.translation ?? remote.instruction,
            source: remote.source ?? "Locupom API",
            level: remote.level.trimmed.isEmpty ? fallbackLevel : LearningLevel.fromCEFRCode(remote.level)
        )
    }

    static let sampleDeck = [
        SentencePuzzle(answer: "I like music", translation: "Me gusta la musica.", level: .beginner),
        SentencePuzzle(answer: "This is my friend", translation: "Este es mi amigo.", level: .beginner),
        SentencePuzzle(answer: "I want to learn", translation: "Quiero aprender.", level: .beginner),
        SentencePuzzle(answer: "She is at home", translation: "Ella esta en casa.", level: .beginner),
        SentencePuzzle(answer: "We need more time", translation: "Necesitamos mas tiempo.", level: .beginner),
        SentencePuzzle(answer: "He likes this song", translation: "A el le gusta esta cancion.", level: .beginner),
        SentencePuzzle(answer: "Can you help me", translation: "Podes ayudarme?", level: .beginner),
        SentencePuzzle(answer: "Today I feel good", translation: "Hoy me siento bien.", level: .beginner),
        SentencePuzzle(answer: "I am learning English with music", translation: "Estoy aprendiendo ingles con musica.", level: .intermediate),
        SentencePuzzle(answer: "She has already finished the lesson", translation: "Ella ya termino la leccion.", level: .intermediate),
        SentencePuzzle(answer: "We should practice a little every day", translation: "Deberiamos practicar un poco cada dia.", level: .intermediate),
        SentencePuzzle(answer: "This song is easier than the last one", translation: "Esta cancion es mas facil que la anterior.", level: .intermediate),
        SentencePuzzle(answer: "Could you say that one more time", translation: "Podrias decirlo una vez mas?", level: .intermediate),
        SentencePuzzle(answer: "I was about to call you", translation: "Estaba por llamarte.", level: .intermediate),
        SentencePuzzle(answer: "They have been waiting for us", translation: "Ellos estuvieron esperandonos.", level: .intermediate),
        SentencePuzzle(answer: "The verse sounds better when I repeat it", translation: "El verso suena mejor cuando lo repito.", level: .intermediate),
        SentencePuzzle(answer: "I wonder what this line means", translation: "Me pregunto que significa esta linea.", level: .intermediate),
        SentencePuzzle(answer: "I would rather practice before speaking", translation: "Preferiria practicar antes de hablar.", level: .advanced),
        SentencePuzzle(answer: "Although the song is fast I can follow it", translation: "Aunque la cancion es rapida, puedo seguirla.", level: .advanced),
        SentencePuzzle(answer: "She has been improving since last month", translation: "Ella viene mejorando desde el mes pasado.", level: .advanced),
        SentencePuzzle(answer: "The meaning depends on the context", translation: "El significado depende del contexto.", level: .advanced),
        SentencePuzzle(answer: "I could barely understand what he was saying", translation: "Apenas pude entender lo que estaba diciendo.", level: .advanced),
        SentencePuzzle(answer: "By the end of the song the chorus felt familiar", translation: "Al final de la cancion, el estribillo se sentia familiar.", level: .advanced),
        SentencePuzzle(answer: "If I had listened carefully I would have noticed it", translation: "Si hubiera escuchado con atencion, lo habria notado.", level: .advanced),
        SentencePuzzle(answer: "The sentence sounds natural even though the grammar is complex", translation: "La frase suena natural aunque la gramatica es compleja.", level: .advanced),
        SentencePuzzle(answer: "Eventually I understood why the singer changed the tense", translation: "Con el tiempo entendi por que el cantante cambio el tiempo verbal.", level: .advanced)
    ]

    static func deck(for level: LearningLevel) -> [SentencePuzzle] {
        Array(sampleDeck.filter { $0.level == level }.prefix(level.practiceLimit))
    }

    static func alternateDeck(for level: LearningLevel, excluding excludedAnswers: Set<String>) -> [SentencePuzzle] {
        let levelPuzzles = sampleDeck.filter { $0.level == level }
        let freshPuzzles = levelPuzzles.filter { !excludedAnswers.contains(TextMatcher.normalize($0.answer)) }
        let pool = freshPuzzles.isEmpty ? levelPuzzles : freshPuzzles
        return Array(pool.shuffled().prefix(level.practiceLimit))
    }

    static func seedWords(for level: LearningLevel) -> [String] {
        switch level {
        case .beginner:
            return ["music", "home", "friend", "want", "learn", "today", "like", "help"]
        case .intermediate:
            return ["music", "learn", "time", "work", "travel", "study", "feel", "speak"]
        case .advanced:
            return ["although", "meaning", "context", "improve", "barely", "eventually", "practice", "understand"]
        }
    }

    static func level(for answer: String) -> LearningLevel {
        let wordCount = TextMatcher.normalize(answer).split(separator: " ").count
        if LearningLevel.beginner.sentenceWordRange.contains(wordCount) {
            return .beginner
        }

        if LearningLevel.intermediate.sentenceWordRange.contains(wordCount) {
            return .intermediate
        }

        return .advanced
    }
}

private struct GrammarQuestion: Identifiable {
    let id: UUID
    let apiContentId: String?
    let prompt: String
    let options: [String]
    let answer: String
    let explanation: String
    let level: LearningLevel

    init(
        apiContentId: String? = nil,
        prompt: String,
        options: [String],
        answer: String,
        explanation: String,
        level: LearningLevel
    ) {
        self.id = UUID()
        self.apiContentId = apiContentId
        self.prompt = prompt
        self.options = options
        self.answer = answer
        self.explanation = explanation
        self.level = level
    }

    init?(remote: LocupomRemotePracticeExercise, fallbackLevel: LearningLevel) {
        let prompt = remote.prompt?.trimmed ?? remote.instruction.trimmed
        let answer = remote.answer?.firstString?.trimmed
        guard let answer, !prompt.isEmpty, !answer.isEmpty else {
            return nil
        }

        let options = remote.options?.filter { !$0.trimmed.isEmpty } ?? []
        guard !options.isEmpty else {
            return nil
        }

        self.init(
            apiContentId: remote.id,
            prompt: prompt,
            options: options,
            answer: answer,
            explanation: remote.explanation ?? remote.instruction,
            level: remote.level.trimmed.isEmpty ? fallbackLevel : LearningLevel.fromCEFRCode(remote.level)
        )
    }

    static func deck(for level: LearningLevel) -> [GrammarQuestion] {
        Array(sampleDeck.filter { $0.level == level }.prefix(level.practiceLimit))
    }

    static let sampleDeck = [
        GrammarQuestion(
            prompt: "I ___ happy.",
            options: ["am", "are", "is"],
            answer: "am",
            explanation: "Con I se usa am.",
            level: .beginner
        ),
        GrammarQuestion(
            prompt: "She ___ music.",
            options: ["likes", "like", "liking"],
            answer: "likes",
            explanation: "Con she/he/it agregamos s al verbo en presente simple.",
            level: .beginner
        ),
        GrammarQuestion(
            prompt: "They ___ at home.",
            options: ["are", "is", "am"],
            answer: "are",
            explanation: "Con they usamos are.",
            level: .beginner
        ),
        GrammarQuestion(
            prompt: "I ___ a friend.",
            options: ["have", "has", "am"],
            answer: "have",
            explanation: "Con I usamos have para posesion.",
            level: .beginner
        ),
        GrammarQuestion(
            prompt: "I ___ never been to London.",
            options: ["have", "has", "am"],
            answer: "have",
            explanation: "Con I se usa have en present perfect.",
            level: .intermediate
        ),
        GrammarQuestion(
            prompt: "She ___ studying when I called.",
            options: ["was", "were", "is"],
            answer: "was",
            explanation: "Past continuous: was studying.",
            level: .intermediate
        ),
        GrammarQuestion(
            prompt: "This is ___ than the first exercise.",
            options: ["easier", "more easy", "easyer"],
            answer: "easier",
            explanation: "Easy cambia a easier en comparativo.",
            level: .intermediate
        ),
        GrammarQuestion(
            prompt: "If I ___ known, I would have called.",
            options: ["had", "have", "would"],
            answer: "had",
            explanation: "Third conditional: if + past perfect, would have + participle.",
            level: .advanced
        ),
        GrammarQuestion(
            prompt: "She kept studying ___ she was tired.",
            options: ["although", "because of", "despite"],
            answer: "although",
            explanation: "Although introduce una oracion con sujeto y verbo.",
            level: .advanced
        ),
        GrammarQuestion(
            prompt: "The song was ___ difficult than I expected.",
            options: ["more", "most", "much"],
            answer: "more",
            explanation: "Difficult usa more para el comparativo.",
            level: .advanced
        ),
        GrammarQuestion(
            prompt: "Hardly ___ I heard the intro when the verse began.",
            options: ["had", "have", "did"],
            answer: "had",
            explanation: "Con hardly al inicio se invierte: hardly had I heard...",
            level: .advanced
        )
    ]
}

private struct SpeakingPrompt: Identifiable {
    let id: UUID
    let apiContentId: String?
    let phrase: String
    let translation: String
    let level: LearningLevel
    let title: String
    let instruction: String
    let support: [String]
    let targetLanguage: [String]
    let source: String

    init(
        apiContentId: String? = nil,
        phrase: String,
        translation: String,
        level: LearningLevel,
        title: String = "Frase objetivo",
        instruction: String = "",
        support: [String] = [],
        targetLanguage: [String] = [],
        source: String = "Local"
    ) {
        self.id = UUID()
        self.apiContentId = apiContentId
        self.phrase = phrase
        self.translation = translation
        self.level = level
        self.title = title
        self.instruction = instruction
        self.support = support
        self.targetLanguage = targetLanguage
        self.source = source
    }

    init?(remote: LocupomRemoteSpeakingPrompt, fallbackLevel: LearningLevel) {
        let support = (remote.support ?? [])
            .map { $0.trimmed }
            .filter { !$0.isEmpty }
        let targetLanguage = (remote.targetLanguage ?? [])
            .map { $0.trimmed }
            .filter { !$0.isEmpty }
        let explicitPhrase = [remote.targetPhrase]
            .compactMap { $0 }
            .map(Self.cleanSupportPhrase)
            .first { !$0.isEmpty }
        let supportPhrase = support
            .map(Self.cleanSupportPhrase)
            .first { !$0.isEmpty }
        let phrase = explicitPhrase ?? supportPhrase ?? Self.cleanSupportPhrase(remote.prompt)
        let remoteTargetPhrases = (remote.targetPhrases ?? [])
            .map(Self.cleanSupportPhrase)
            .filter { !$0.isEmpty }
        let level = remote.level.trimmed.isEmpty ? fallbackLevel : LearningLevel.fromCEFRCode(remote.level)

        guard !phrase.isEmpty else {
            return nil
        }

        self.init(
            apiContentId: remote.id,
            phrase: phrase,
            translation: remote.prompt,
            level: level,
            title: remote.title,
            instruction: remote.prompt,
            support: remoteTargetPhrases.isEmpty ? support : remoteTargetPhrases,
            targetLanguage: targetLanguage,
            source: "Locupom API"
        )
    }

    static func deck(for level: LearningLevel) -> [SpeakingPrompt] {
        Array(sampleDeck.filter { $0.level == level }.prefix(level.practiceLimit))
    }

    private static func cleanSupportPhrase(_ rawValue: String) -> String {
        var text = rawValue.trimmed
        if let rewriteRange = text.range(of: "->") {
            text = String(text[rewriteRange.upperBound...]).trimmed
        }
        text = text
            .replacingOccurrences(of: "...", with: "")
            .replacingOccurrences(of: "___", with: "")
            .replacingOccurrences(of: "__", with: "")
            .trimmed

        guard !text.isEmpty else {
            return ""
        }

        if let last = text.last, !".?!".contains(last) {
            text += "."
        }
        return text
    }

    static let sampleDeck = [
        SpeakingPrompt(phrase: "I like music.", translation: "Me gusta la musica.", level: .beginner),
        SpeakingPrompt(phrase: "I am learning English.", translation: "Estoy aprendiendo ingles.", level: .beginner),
        SpeakingPrompt(phrase: "Can you help me?", translation: "Podes ayudarme?", level: .beginner),
        SpeakingPrompt(phrase: "This is my friend.", translation: "Este es mi amigo.", level: .beginner),
        SpeakingPrompt(phrase: "I want to improve my English.", translation: "Quiero mejorar mi ingles.", level: .intermediate),
        SpeakingPrompt(phrase: "Can you speak more slowly?", translation: "Podes hablar mas lento?", level: .intermediate),
        SpeakingPrompt(phrase: "I am still learning.", translation: "Todavia estoy aprendiendo.", level: .intermediate),
        SpeakingPrompt(phrase: "That sounds interesting.", translation: "Eso suena interesante.", level: .intermediate),
        SpeakingPrompt(phrase: "I would rather practice before speaking.", translation: "Preferiria practicar antes de hablar.", level: .advanced),
        SpeakingPrompt(phrase: "The meaning depends on the context.", translation: "El significado depende del contexto.", level: .advanced),
        SpeakingPrompt(phrase: "Although it was difficult, I kept going.", translation: "Aunque fue dificil, segui adelante.", level: .advanced),
        SpeakingPrompt(phrase: "By the end of the song, I understood the chorus.", translation: "Al final de la cancion, entendi el estribillo.", level: .advanced),
        SpeakingPrompt(phrase: "I can barely pronounce that sentence naturally.", translation: "Apenas puedo pronunciar esa frase de forma natural.", level: .advanced)
    ]
}

private struct WordToken: Identifiable, Hashable {
    let id = UUID()
    let text: String
}

private struct LearningFeedback {
    let title: String
    let detail: String
    let score: Double
    let isCorrect: Bool
}

private struct LearningFeedbackView: View {
    let feedback: LearningFeedback

    private var tint: Color {
        feedback.isCorrect ? .green : .orange
    }

    private var coachTip: String {
        if feedback.isCorrect && feedback.score >= 0.9 {
            return "Fijalo con una repeticion rapida antes de pasar."
        }

        if feedback.isCorrect {
            return "Va bien: todavia sirve comparar palabra por palabra."
        }

        if feedback.score >= 0.65 {
            return "Estas cerca. Mira la diferencia chica y repetilo lento."
        }

        return "Usa el contexto, escucha de nuevo y busca la palabra que cambia el sentido."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: feedback.isCorrect ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(feedback.title)
                        .font(.headline)
                    Text(feedback.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Spacer()

                Text("\(Int(feedback.score * 100))%")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(tint.opacity(0.12), in: Capsule())
            }

            ProgressView(value: feedback.score)
                .tint(tint)

            Label(coachTip, systemImage: "sparkles")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(LocupomTheme.softSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct LearningWordDiffView: View {
    let answer: String
    let target: String

    private var tokens: [TextComparisonToken] {
        TextMatcher.wordComparison(answer: answer, target: target)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Palabra por palabra")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            FlowLayout(spacing: 6) {
                ForEach(tokens) { token in
                    Text(label(for: token))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(foreground(for: token.status))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(background(for: token.status), in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(LocupomTheme.softSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func label(for token: TextComparisonToken) -> String {
        switch token.status {
        case .exact:
            return token.expected
        case .close:
            return "\(token.actual ?? "") -> \(token.expected)"
        case .wrong:
            return "\(token.actual ?? "") -> \(token.expected)"
        case .missing:
            return "+ \(token.expected)"
        case .extra:
            return "- \(token.actual ?? token.expected)"
        }
    }

    private func foreground(for status: TextComparisonStatus) -> Color {
        switch status {
        case .exact:
            return .green
        case .close:
            return .yellow
        case .wrong:
            return .orange
        case .missing, .extra:
            return .secondary
        }
    }

    private func background(for status: TextComparisonStatus) -> Color {
        switch status {
        case .exact:
            return .green.opacity(0.14)
        case .close:
            return .yellow.opacity(0.18)
        case .wrong:
            return .orange.opacity(0.14)
        case .missing, .extra:
            return Color(.secondarySystemBackground)
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    LearningHubView()
        .environmentObject(SongLibraryStore.preview)
        .environmentObject(LearningProgressStore.preview)
}
