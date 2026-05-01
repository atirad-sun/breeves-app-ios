import SwiftUI
import DesignSystem
import Models

struct ArticleCardView: View {
    let article: Article
    let index: Int
    let total: Int
    let lens: ReadingLens
    let isRead: Bool
    let onOpenFull: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Hairline(strength: .standard)

            counterRow
                .padding(.top, BreevesSpace.s5)
                .padding(.bottom, BreevesSpace.s2)

            headline
                .padding(.bottom, BreevesSpace.s4)

            Hairline(strength: .faint)
                .padding(.bottom, BreevesSpace.s4)

            bullets

            footer
                .padding(.top, BreevesSpace.s4)
                .padding(.bottom, BreevesSpace.s5)
        }
        .accessibilityElement(children: .contain)
    }

    private var counterRow: some View {
        HStack(spacing: BreevesSpace.s2) {
            HStack(spacing: 4) {
                if isRead {
                    Circle()
                        .fill(BreevesColor.accentPrimary)
                        .frame(width: 6, height: 6)
                }
                Text("\(twoDigit(index + 1)) / \(twoDigit(total))")
                    .breevesMonoS()
                    .foregroundStyle(BreevesColor.textTertiary)
            }
            DotLeader()
            Text("\(article.estimatedReadTimeMinutes) MIN READ")
                .breevesCaption()
                .foregroundStyle(BreevesColor.textTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Article \(index + 1) of \(total), \(article.estimatedReadTimeMinutes) minute read\(isRead ? ", read" : "")")
    }

    private var headline: some View {
        Text(article.headline)
            .breevesHeadlineL()
            .multilineTextAlignment(.leading)
            .foregroundStyle(isRead ? BreevesColor.stateRead : BreevesColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(article.headline)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var bullets: some View {
        switch lens {
        case .universal:
            VStack(alignment: .leading, spacing: BreevesSpace.s4) {
                ForEach(Array(article.universalMode.orderedBullets.enumerated()), id: \.offset) { _, text in
                    UniversalBulletRow(text: text)
                }
            }
            .id("universal-\(article.id)")
            .transition(.opacity.combined(with: .offset(y: -4)))
        case .topicSpecific:
            VStack(alignment: .leading, spacing: BreevesSpace.s5) {
                ForEach(Array(article.topicSpecificMode.orderedBullets.enumerated()), id: \.offset) { _, b in
                    HeaderedBulletRow(header: b.header, text: b.text)
                }
            }
            .id("deep-\(article.id)")
            .transition(.opacity.combined(with: .offset(y: -4)))
        case .executive:
            VStack(alignment: .leading, spacing: BreevesSpace.s5) {
                ForEach(Array(article.executiveMode.orderedBullets.enumerated()), id: \.offset) { idx, b in
                    HeaderedBulletRow(header: b.header, text: b.text, emphasized: idx == 3)
                }
            }
            .id("action-\(article.id)")
            .transition(.opacity.combined(with: .offset(y: -4)))
        }
    }

    private var footer: some View {
        HStack {
            Button(action: onOpenFull) {
                HStack(spacing: 4) {
                    Text("Read full")
                        .breevesCaption()
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(BreevesColor.accentPrimary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Read full article")

            Spacer()

            Button {
                // Share / bookmark — v1 leaves this as a placeholder.
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(BreevesColor.textTertiary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share")
        }
    }

    private func twoDigit(_ n: Int) -> String { String(format: "%02d", n) }
}

private struct UniversalBulletRow: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(BreevesColor.accentPrimary)
                .frame(width: 1)
            Text(text)
                .breevesBodyL()
                .foregroundStyle(BreevesColor.textPrimary)
                .padding(.leading, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct HeaderedBulletRow: View {
    let header: String
    let text: String
    var emphasized: Bool = false
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if emphasized {
                Rectangle()
                    .fill(BreevesColor.accentPrimary)
                    .frame(width: 2)
                    .padding(.trailing, 10)
            }
            VStack(alignment: .leading, spacing: BreevesSpace.s1) {
                Text(header)
                    .breevesLabelM()
                    .foregroundStyle(BreevesColor.accentPrimary)
                Text(text)
                    .breevesBodyL()
                    .fontWeight(emphasized ? .medium : .regular)
                    .foregroundStyle(BreevesColor.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
