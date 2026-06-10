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
        case .music: "Musica"
        case .topics: "Temas"
        case .practice: "Practica"
        case .progress: "Avance"
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

            LocupomFloatingTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
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
        .background(.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .shadow(color: Color(red: 0.11, green: 0.16, blue: 0.30).opacity(0.13), radius: 24, x: 0, y: 12)
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
                    .fill(.white)
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
            ScrollView {
                onboardingContent
                .padding()
            }
            .navigationTitle("Locupom")
        }
    }

    private var onboardingContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingHeaderView()
            levelSection
            focusSection
            goalSection
            startButton
        }
    }

    private var levelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nivel")
                .font(.headline)

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
        VStack(alignment: .leading, spacing: 10) {
            Text("Foco")
                .font(.headline)

            Picker("Foco", selection: $selectedFocus) {
                ForEach(LearningFocus.allCases) { focus in
                    Text(focus.title).tag(focus)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Meta diaria")
                    .font(.headline)
                Spacer()
                Text("\(Int(dailyGoal)) min")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.tint)
            }

            Slider(value: $dailyGoal, in: 5...30, step: 5)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var startButton: some View {
        Button {
            learningProgress.completeOnboarding(
                level: selectedLevel,
                focus: selectedFocus,
                dailyGoalMinutes: Int(dailyGoal)
            )
        } label: {
            Label("Empezar", systemImage: "arrow.right.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}

private struct OnboardingHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "graduationcap.fill")
                .font(.largeTitle)
                .foregroundStyle(.tint)

            Text("Locupom")
                .font(.largeTitle.bold())
            Text("Learn with music, context and short daily practice.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct LevelOptionRow: View {
    let level: LearningLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                VStack(alignment: .leading, spacing: 3) {
                    Text(level.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(level.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
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
