import SwiftUI
import DesignSystem
import Models

struct TopicSelectionView: View {
    @Environment(AppModel.self) private var app

    @State private var query: String = ""
    @State private var selected: [TopicSuggestion] = []
    @FocusState private var inputFocused: Bool
    @State private var saving = false
    @State private var errorText: String?

    private var canContinue: Bool { selected.count == 3 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            TopicSelectionContent(
                selected: $selected,
                query: $query,
                inputFocused: $inputFocused
            )
            .padding(.horizontal, BreevesSpace.s5)

            VStack(spacing: 0) {
                if let errorText {
                    Text(errorText)
                        .breevesCaption()
                        .foregroundStyle(BreevesColor.stateDanger)
                        .padding(.bottom, BreevesSpace.s2)
                }
                PrimaryButton("Continue", isEnabled: canContinue && !saving) {
                    Task { await save() }
                }
            }
            .padding(.horizontal, BreevesSpace.s5)
            .padding(.bottom, BreevesSpace.s4)
            .padding(.top, BreevesSpace.s3)
        }
        .background(BreevesColor.bgCanvas.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: BreevesSpace.s2) {
            HStack(alignment: .firstTextBaseline) {
                Text("Pick three.")
                    .breevesDisplayL()
                    .foregroundStyle(BreevesColor.textPrimary)
                Spacer()
                Text("\(selected.count) / 3")
                    .breevesMonoS()
                    .foregroundStyle(canContinue ? BreevesColor.accentPrimary : BreevesColor.textTertiary)
            }
            Text("Three topics, six articles each. Change them anytime.")
                .breevesBodyM()
                .foregroundStyle(BreevesColor.textSecondary)
        }
        .padding(.horizontal, BreevesSpace.s5)
        .padding(.top, BreevesSpace.s6)
        .padding(.bottom, BreevesSpace.s4)
    }

    private func save() async {
        let topics = selected.enumerated().map { idx, t in
            UserTopic(name: t.name, slot: idx + 1, descriptionText: t.descriptionText)
        }
        saving = true
        defer { saving = false }
        do {
            try await app.saveOnboardingTopics(topics)
        } catch {
            errorText = "Couldn't save topics. Try again."
        }
    }
}
