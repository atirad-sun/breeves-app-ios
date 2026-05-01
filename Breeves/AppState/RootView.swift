import SwiftUI
import DesignSystem

struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        ZStack {
            BreevesColor.bgCanvas.ignoresSafeArea()
            content
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.35), value: app.route)
        .fullScreenCover(isPresented: .init(
            get: { app.isCompletionShown },
            set: { app.isCompletionShown = $0 }
        )) {
            CompletionView()
                .environment(app)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch app.route {
        case .splash:
            SplashView()
        case .auth:
            AuthView()
        case .onboardingTopics:
            TopicSelectionView()
        case .onboardingPreferences:
            PreferencesView()
        case .dashboard:
            DashboardView()
        }
    }
}
