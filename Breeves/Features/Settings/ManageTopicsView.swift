import SwiftUI
import DesignSystem
import Models

struct ManageTopicsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @Binding var didSave: Bool

    @State private var initial: [TopicSuggestion] = []
    @State private var selected: [TopicSuggestion] = []
    @State private var query: String = ""
    @FocusState private var inputFocused: Bool
    @State private var saving = false
    @State private var errorText: String?

    private var hasChanges: Bool {
        selected.map(\.name) != initial.map(\.name)
    }

    private var canSave: Bool {
        selected.count == 3 && hasChanges && !saving
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Hairline()

            TopicSelectionContent(
                selected: $selected,
                query: $query,
                inputFocused: $inputFocused
            )
            .padding(.horizontal, BreevesSpace.s5)
            .padding(.top, BreevesSpace.s4)

            if let errorText {
                Text(errorText)
                    .breevesCaption()
                    .foregroundStyle(BreevesColor.stateDanger)
                    .padding(.horizontal, BreevesSpace.s5)
                    .padding(.bottom, BreevesSpace.s2)
            }
        }
        .background(BreevesColor.bgCanvas.ignoresSafeArea())
        .interactiveDismissDisabled(hasChanges)
        .onAppear {
            let snapshot = app.topics.map { TopicSuggestion(userTopic: $0) }
            initial = snapshot
            if selected.isEmpty {
                selected = snapshot
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Button { dismiss() } label: {
                Text("Cancel")
                    .breevesBodyM()
                    .foregroundStyle(BreevesColor.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Manage topics")
                .breevesHeadlineS()
                .foregroundStyle(BreevesColor.textPrimary)

            Spacer()

            Button { Task { await save() } } label: {
                Text("Save")
                    .breevesBodyM()
                    .fontWeight(.semibold)
                    .foregroundStyle(canSave ? BreevesColor.accentPrimary : BreevesColor.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
        }
        .padding(.horizontal, BreevesSpace.s5)
        .padding(.top, BreevesSpace.s4)
        .padding(.bottom, BreevesSpace.s3)
    }

    private func save() async {
        let topics = selected.enumerated().map { idx, t in
            UserTopic(name: t.name, slot: idx + 1, descriptionText: t.descriptionText)
        }
        saving = true
        defer { saving = false }
        do {
            try await app.updateTopics(topics)
            didSave = true
            dismiss()
        } catch {
            errorText = "Couldn't save topics. Try again."
        }
    }
}
