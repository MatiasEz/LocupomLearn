import SwiftUI

private enum LocupomRootTab: String, CaseIterable, Identifiable {
    case today
    case music
    case topics
    case practice
    case progress

    var id: Self { self }

    var title: String {
        switch self {
        case .today: "Hoy"
        case .music: "Música"
        case .topics: "Temas"
        case .practice: "Práctica"
        case .progress: "Avances"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "house.fill"
        case .music: "music.note"
        case .topics: "book.fill"
        case .practice: "bolt.fill"
        case .progress: "chart.bar.fill"
        }
    }

    var color: Color {
        switch self {
        case .today: Color(red: 0.18, green: 0.72, blue: 0.76)
        case .music: Color(red: 0.46, green: 0.33, blue: 0.96)
        case .topics: Color(red: 0.18, green: 0.39, blue: 0.98)
        case .practice: Color(red: 1.0, green: 0.78, blue: 0.05)
        case .progress: Color(red: 0.20, green: 0.72, blue: 0.77)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var learningProgress: LearningProgressStore
    @State private var selectedTab: LocupomRootTab = .today
    @State private var hidesFloatingTabBar = false

    var body: some View {
        Group {
            if learningProgress.profile.onboardingCompleted {
                mainTabs
            } else {
                OnboardingView()
            }
        }
    }

    private var mainTabs: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                LearningHubView()
                    .tag(LocupomRootTab.today)

                LearningMusicTabView()
                    .tag(LocupomRootTab.music)

                LearningTopicsTabView()
                    .tag(LocupomRootTab.topics)

                LearningPracticeTabView()
                    .tag(LocupomRootTab.practice)

                LearningProgressTabView()
                    .tag(LocupomRootTab.progress)
            }
            .toolbar(.hidden, for: .tabBar)

            if !hidesFloatingTabBar {
                LocupomFloatingTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 0)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onPreferenceChange(LocupomFloatingTabBarHiddenPreferenceKey.self) { isHidden in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                hidesFloatingTabBar = isHidden
            }
        }
    }
}

private struct LocupomFloatingTabBarHiddenPreferenceKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {
    func locupomFloatingTabBarHidden(_ hidden: Bool) -> some View {
        preference(key: LocupomFloatingTabBarHiddenPreferenceKey.self, value: hidden)
    }
}

private struct LocupomFloatingTabBar: View {
    @Binding var selectedTab: LocupomRootTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(LocupomRootTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    LocupomTabBarItem(
                        tab: tab,
                        isSelected: selectedTab == tab
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(height: 86)
    }
}

private struct LocupomTabBarItem: View {
    let tab: LocupomRootTab
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 5) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: isSelected ? 28 : 26, weight: .black))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? tab.color : Color.gray.opacity(0.78))

                if tab == .today && !isSelected {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.80, blue: 0.0))
                        .frame(width: 8, height: 8)
                        .offset(x: 7, y: -3)
                }
            }
            .frame(height: 30)

            Text(tab.title)
                .font(.system(size: 12, weight: isSelected ? .bold : .semibold, design: .rounded))
                .foregroundStyle(isSelected ? tab.color : Color.gray.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(tab == .practice ? tab.color.opacity(0.18) : Color(.tertiarySystemBackground))
                    .shadow(color: tab.color.opacity(0.18), radius: 14, x: 0, y: 8)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

private struct OnboardingView: View {
    @EnvironmentObject private var learningProgress: LearningProgressStore
    @State private var selectedLevel: LearningLevel = .beginner
    @State private var selectedFocus: LearningFocus = .songs
    @State private var dailyGoal = 15.0

    var body: some View {
        NavigationStack {
            ZStack {
                LocupomLearningBackground()

                ScrollView {
                    onboardingContent
                        .padding(.horizontal, 22)
                        .padding(.top, 28)
                        .padding(.bottom, 38)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var onboardingContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingHeaderView()
            levelSection
            focusSection
            goalSection
            startButton
        }
    }

    private var levelSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Nivel")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(LocupomTheme.ink)

            ForEach(LearningLevel.allCases) { level in
                LevelOptionRow(
                    level: level,
                    isSelected: selectedLevel == level,
                    action: {
                        selectedLevel = level
                    }
                )
            }
        }
    }

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Foco")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(LocupomTheme.ink)

            Picker("Foco", selection: $selectedFocus) {
                ForEach(LearningFocus.allCases) { focus in
                    Text(focus.title).tag(focus)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(18)
        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(LocupomTheme.ink.opacity(0.07), lineWidth: 1)
        }
        .shadow(color: LocupomTheme.primary.opacity(0.07), radius: 18, x: 0, y: 10)
    }

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Meta diaria")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(LocupomTheme.ink)
                Spacer()
                Text("\(Int(dailyGoal)) min")
                    .font(.system(size: 18, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(LocupomTheme.primary)
            }

            Slider(value: $dailyGoal, in: 5...30, step: 5)
                .tint(LocupomTheme.primary)
        }
        .padding(18)
        .background(LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(LocupomTheme.ink.opacity(0.07), lineWidth: 1)
        }
        .shadow(color: LocupomTheme.primary.opacity(0.07), radius: 18, x: 0, y: 10)
    }

    private var startButton: some View {
        Button {
            learningProgress.completeOnboarding(
                level: selectedLevel,
                focus: selectedFocus,
                dailyGoalMinutes: Int(dailyGoal)
            )
        } label: {
            Label("Empezar", systemImage: "play.fill")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [LocupomTheme.primary, LocupomTheme.secondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
                .shadow(color: LocupomTheme.primary.opacity(0.20), radius: 16, x: 0, y: 9)
        }
        .buttonStyle(.plain)
    }
}

private struct OnboardingHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                LocupomLogoMark(size: 56)

                Text("Locupom")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(LocupomTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Armá tu práctica")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(LocupomTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.80)

                Text("Elegí un nivel, un foco y una meta diaria para arrancar sin ruido.")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(LocupomTheme.ink.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct LevelOptionRow: View {
    let level: LearningLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(isSelected ? LocupomTheme.primary : LocupomTheme.muted.opacity(0.70))

                VStack(alignment: .leading, spacing: 3) {
                    Text(level.title)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(LocupomTheme.ink)
                    Text(level.detail)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(LocupomTheme.ink.opacity(0.54))
                }

                Spacer()
            }
            .padding(16)
            .background(isSelected ? LocupomTheme.primary.opacity(0.10) : LocupomTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? LocupomTheme.primary.opacity(0.38) : LocupomTheme.ink.opacity(0.07), lineWidth: 1)
            }
            .shadow(color: LocupomTheme.primary.opacity(isSelected ? 0.10 : 0.06), radius: 16, x: 0, y: 9)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RootView()
        .environmentObject(SongLibraryStore.preview)
        .environmentObject(YouTubeAPISettings())
        .environmentObject(LearningProgressStore.preview)
}
