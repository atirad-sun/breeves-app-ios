import SwiftUI
import DesignSystem
import Models

struct TopicSuggestion: Identifiable, Hashable {
    let name: String
    let descriptionText: String
    var id: String { name }
}

let topicCatalog: [TopicSuggestion] = [
    .init(name: "AI", descriptionText: "Artificial Intelligence — models, research, applications"),
    .init(name: "Finance", descriptionText: "Global markets, banking, investment"),
    .init(name: "Geopolitics", descriptionText: "International relations, diplomacy, conflict"),
    .init(name: "Climate", descriptionText: "Climate change, energy transition, ESG"),
    .init(name: "Crypto", descriptionText: "Cryptocurrency, DeFi, blockchain"),
    .init(name: "Biotech", descriptionText: "Biotechnology, drug development, genomics"),
    .init(name: "Defense", descriptionText: "Defense industry, military technology, NATO"),
    .init(name: "NVIDIA", descriptionText: "NVIDIA Corp. — GPUs, AI chips, data center"),
    .init(name: "Apple", descriptionText: "Apple Inc. — iPhone, Mac, services ecosystem"),
    .init(name: "SpaceX", descriptionText: "SpaceX — rockets, Starlink, Mars ambitions"),
    .init(name: "Real Estate", descriptionText: "Property markets, REITs, commercial real estate"),
    .init(name: "Markets", descriptionText: "Equity, fixed income, commodities"),
]

extension TopicSuggestion {
    init(userTopic: UserTopic) {
        self.init(
            name: userTopic.name,
            descriptionText: userTopic.descriptionText ?? "Custom topic — news will be curated daily."
        )
    }
}

/// Shared body for picking up to 3 topics. Used by onboarding `TopicSelectionView`
/// and Settings `ManageTopicsView`. The parent owns `selected` / `query` /
/// `inputFocused` so it can drive enable-state, focus, and validation.
struct TopicSelectionContent: View {
    @Binding var selected: [TopicSuggestion]
    @Binding var query: String
    @FocusState.Binding var inputFocused: Bool

    private var filtered: [TopicSuggestion] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let names = Set(selected.map { $0.name.lowercased() })
        let pool = topicCatalog.filter { !names.contains($0.name.lowercased()) }
        if q.isEmpty { return pool }
        return pool.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchInput
                .padding(.bottom, BreevesSpace.s3)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !selected.isEmpty {
                        Text("YOUR TOPICS")
                            .breevesLabelM()
                            .foregroundStyle(BreevesColor.textTertiary)
                            .padding(.bottom, BreevesSpace.s3)

                        ForEach(Array(selected.enumerated()), id: \.offset) { idx, topic in
                            selectedRow(topic, slot: idx)
                            Hairline(strength: .faint)
                        }
                        Spacer().frame(height: BreevesSpace.s5)
                    }

                    if selected.count < 3 {
                        Text(query.isEmpty ? "POPULAR TOPICS" : "MATCHING TOPICS")
                            .breevesLabelM()
                            .foregroundStyle(BreevesColor.textTertiary)
                            .padding(.bottom, BreevesSpace.s3)

                        ForEach(filtered) { topic in
                            suggestionRow(topic)
                            Hairline(strength: .faint)
                        }

                        let trimmed = query.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty &&
                           !filtered.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) &&
                           !selected.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) {
                            Button {
                                addCustom()
                            } label: {
                                HStack(spacing: BreevesSpace.s3) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(BreevesColor.accentPrimary)
                                    Text("Add \"\(trimmed)\" as custom topic")
                                        .breevesBodyM()
                                        .foregroundStyle(BreevesColor.accentPrimary)
                                    Spacer()
                                }
                                .padding(.vertical, BreevesSpace.s3)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer().frame(height: BreevesSpace.s7)
                }
            }
        }
    }

    private var searchInput: some View {
        HStack(spacing: BreevesSpace.s2) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(BreevesColor.textTertiary)
            TextField("e.g. NVIDIA, Climate…", text: $query)
                .focused($inputFocused)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(BreevesFont.bodyM)
                .foregroundStyle(BreevesColor.textPrimary)
                .submitLabel(.done)
                .disabled(selected.count >= 3)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(BreevesColor.textTertiary)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, BreevesSpace.s3)
        .frame(height: 48)
        .background(BreevesColor.bgElevated1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(BreevesColor.hairlineStandard, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(selected.count >= 3 ? 0.4 : 1)
    }

    private func selectedRow(_ topic: TopicSuggestion, slot: Int) -> some View {
        HStack(alignment: .top, spacing: BreevesSpace.s3) {
            Rectangle()
                .fill(BreevesColor.topic(slot: slot))
                .frame(width: 2, height: 28)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(topic.name)
                    .breevesHeadlineS()
                    .foregroundStyle(BreevesColor.textPrimary)
                Text(topic.descriptionText)
                    .breevesCaption()
                    .foregroundStyle(BreevesColor.textTertiary)
            }
            Spacer()
            Button {
                selected.removeAll { $0.id == topic.id }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(BreevesColor.textTertiary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(topic.name)")
        }
        .padding(.vertical, BreevesSpace.s4)
    }

    private func suggestionRow(_ topic: TopicSuggestion) -> some View {
        Button {
            addTopic(topic)
        } label: {
            HStack(alignment: .top, spacing: BreevesSpace.s3) {
                Rectangle()
                    .fill(BreevesColor.hairlineStrong)
                    .frame(width: 2, height: 20)
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(topic.name)
                        .breevesBodyM()
                        .fontWeight(.semibold)
                        .foregroundStyle(BreevesColor.textPrimary)
                    Text(topic.descriptionText)
                        .breevesCaption()
                        .foregroundStyle(BreevesColor.textTertiary)
                }
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(BreevesColor.textTertiary)
                    .frame(width: 32, height: 32)
            }
            .padding(.vertical, BreevesSpace.s3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func addTopic(_ topic: TopicSuggestion) {
        guard selected.count < 3, !selected.contains(where: { $0.name == topic.name }) else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            selected.append(topic)
            query = ""
        }
        inputFocused = false
    }

    private func addCustom() {
        let name = query.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        addTopic(TopicSuggestion(name: name, descriptionText: "Custom topic — news will be curated daily."))
    }
}
