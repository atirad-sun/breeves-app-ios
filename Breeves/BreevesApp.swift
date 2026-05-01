import SwiftUI
import SwiftData
import DesignSystem
import Models
import Networking
import Persistence

@main
struct BreevesApp: App {
    @State private var appModel: AppModel
    private let modelContainer: ModelContainer

    init() {
        let schema = Schema(BreevesSchema.allModels)
        let config = ModelConfiguration("BreevesStore", schema: schema)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("SwiftData container failed: \(error)")
        }
        self.modelContainer = container
        let cache = BriefingCache(context: container.mainContext)
        let backend = BreevesBackend.resolve()
        if backend.mode == .live, let clientID = backend.googleClientID {
            MainActor.assumeIsolated {
                GoogleSignInCoordinator.shared.configure(clientID: clientID)
            }
        }
        self._appModel = State(initialValue: AppModel(backend: backend, cache: cache))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .preferredColorScheme(colorScheme(for: appModel.preferences.colorScheme))
                .background(BreevesColor.bgCanvas.ignoresSafeArea())
                .task { await appModel.bootstrap() }
                .onOpenURL { url in
                    _ = GoogleSignInCoordinator.shared.handle(url: url)
                }
        }
        .modelContainer(modelContainer)
    }

    private func colorScheme(for pref: ColorSchemePreference) -> ColorScheme? {
        switch pref {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}
