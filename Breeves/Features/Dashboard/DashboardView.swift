import SwiftUI
import DesignSystem
import Models
import SafariServices

struct DashboardView: View {
    @Environment(AppModel.self) private var app
    @State private var activeTopic: Int = {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-BREEVES_TOPIC2") { return 1 }
        if args.contains("-BREEVES_TOPIC3") { return 2 }
        return 0
    }()
    @State private var activeArticle: Int = {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-BREEVES_NUDGE") { return 6 }
        if args.contains("-BREEVES_ART2") { return 1 }
        return 0
    }()
    @State private var showSettings = ProcessInfo.processInfo.arguments.contains("-BREEVES_SETTINGS")
    @State private var fullArticleURL: URL?

    /// Live scroll offset of the currently visible article page. Drives the
    /// collapsing top bar and the auto-hide bottom bar.
    @State private var scrollOffset: CGFloat = {
        ProcessInfo.processInfo.arguments.contains("-BREEVES_COLLAPSED") ? 200 : 0
    }()
    @State private var lastScrollDirection: ScrollDirection = .idle
    @State private var lastScrollActivity: Date = .now
    @State private var bottomBarVisible: Bool = true

    /// Threshold (pt) past which the top bar fully collapses.
    private let collapseThreshold: CGFloat = 80
    /// Idle duration after which the bottom bar fades out.
    private let bottomBarIdleSeconds: TimeInterval = 2.0

    private enum ScrollDirection { case up, down, idle }

    private var topicCount: Int { app.briefing?.topics.count ?? app.topics.count }
    private var topicColors: [Color] { (0..<3).map { BreevesColor.topic(slot: $0) } }
    private var collapseFraction: CGFloat {
        if ProcessInfo.processInfo.arguments.contains("-BREEVES_COLLAPSED") { return 1 }
        return min(1, max(0, scrollOffset / collapseThreshold))
    }

    var body: some View {
        ZStack {
            BreevesColor.bgCanvas.ignoresSafeArea()

            // Pager fills the screen; top + bottom chrome float over it.
            if let briefing = app.briefing {
                pager(briefing: briefing)
            } else if app.isLoadingBriefing {
                skeleton.padding(.top, expandedHeaderHeight)
            } else if let err = app.briefingError {
                errorState(message: err).padding(.top, expandedHeaderHeight)
            }

            VStack(spacing: 0) {
                topBar
                    .background(
                        // Subtle blur scrim only when collapsed so content below is legible.
                        Group {
                            if collapseFraction > 0.5 {
                                Rectangle()
                                    .fill(BreevesColor.bgCanvas.opacity(0.92))
                                    .background(.ultraThinMaterial)
                                    .ignoresSafeArea(edges: .top)
                            }
                        }
                    )
                Spacer(minLength: 0)
                bottomBar
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(app)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: Binding(
            get: { fullArticleURL.map(IdentifiableURL.init) },
            set: { fullArticleURL = $0?.url }
        )) { wrapped in
            SafariSheet(url: wrapped.url)
                .ignoresSafeArea()
        }
        .onChange(of: activeTopic) { oldValue, _ in
            if let briefing = app.briefing,
               oldValue >= 0,
               oldValue < briefing.topics.count,
               activeArticle >= 0,
               activeArticle < briefing.topics[oldValue].articles.count {
                let leftBehind = briefing.topics[oldValue].articles[activeArticle]
                app.markArticleRead(leftBehind.id)
            }
            activeArticle = 0
            // Reset scroll cosmetics when switching topic.
            scrollOffset = 0
            bottomBarVisible = true
            lastScrollActivity = .now
        }
        .onChange(of: activeArticle) { oldValue, newValue in
            guard oldValue != newValue,
                  let briefing = app.briefing,
                  activeTopic < briefing.topics.count else { return }
            let articles = briefing.topics[activeTopic].articles
            if oldValue >= 0, oldValue < articles.count {
                app.markArticleRead(articles[oldValue].id)
            }
            // Each article starts at the top.
            scrollOffset = 0
            bottomBarVisible = true
            lastScrollActivity = .now
        }
        .task(id: lastScrollActivity) {
            // Auto-hide bottom bar after idle period — but only if user has
            // scrolled at least once (i.e., not on a freshly loaded article).
            try? await Task.sleep(for: .seconds(bottomBarIdleSeconds))
            if Date.now.timeIntervalSince(lastScrollActivity) >= bottomBarIdleSeconds,
               scrollOffset > 4 {
                withAnimation(.easeOut(duration: 0.25)) {
                    bottomBarVisible = false
                }
            }
        }
    }

    // MARK: - Top bar (collapsing)

    /// Approximate height of the fully expanded header (date row + display-xl
    /// + two pills). Used as content top inset to keep first paragraph below.
    private var expandedHeaderHeight: CGFloat { 220 }
    /// Height when fully collapsed (date row with topic indicator + lens pill only).
    private var collapsedHeaderHeight: CGFloat { 120 }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusRow
                .padding(.horizontal, BreevesSpace.s5)
                .padding(.top, BreevesSpace.s3)

            // Today's brief headline — collapses with scroll
            Text("Today's brief.")
                .breevesDisplayXL()
                .foregroundStyle(BreevesColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, BreevesSpace.s5)
                .opacity(1 - collapseFraction)
                .scaleEffect(1 - collapseFraction * 0.3, anchor: .topLeading)
                .frame(height: (1 - collapseFraction) * 56)
                .clipped()

            pillsRow
                .padding(.horizontal, BreevesSpace.s5)
                .padding(.vertical, BreevesSpace.s3)
        }
        .animation(.easeOut(duration: 0.18), value: collapseFraction > 0.5)
    }

    /// The date row. In collapsed mode, includes a topic indicator
    /// (chroma dot + topic name) since the Topic pill is hidden.
    private var statusRow: some View {
        let names = (app.briefing?.topics.map(\.topic)) ?? app.topics.map(\.name)
        let activeName = (activeTopic >= 0 && activeTopic < names.count) ? names[activeTopic] : ""

        return HStack(spacing: BreevesSpace.s2) {
            Text(formattedDate())
                .breevesCaption()
                .foregroundStyle(BreevesColor.textTertiary)
                .textCase(.uppercase)
                .lineLimit(1)

            if collapseFraction > 0.5 && !activeName.isEmpty {
                Text("·")
                    .breevesCaption()
                    .foregroundStyle(BreevesColor.textTertiary)
                Circle()
                    .fill(BreevesColor.topic(slot: activeTopic))
                    .frame(width: 6, height: 6)
                Text(activeName.uppercased())
                    .breevesCaption()
                    .fontWeight(.semibold)
                    .foregroundStyle(BreevesColor.topic(slot: activeTopic))
                    .lineLimit(1)
                    .transition(.opacity.combined(with: .offset(x: -6)))
            }

            Spacer()

            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(BreevesColor.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .animation(.easeOut(duration: 0.18), value: collapseFraction > 0.5)
        .animation(.easeOut(duration: 0.18), value: activeTopic)
    }

    @ViewBuilder
    private var pillsRow: some View {
        let names = (app.briefing?.topics.map(\.topic)) ?? app.topics.map(\.name)
        let topicBinding = Binding<Int>(
            get: { activeTopic },
            set: { newValue in
                withAnimation(BreevesMotion.lensToggle) {
                    activeTopic = min(max(0, newValue), max(0, names.count - 1))
                }
            }
        )

        @Bindable var bindable = app
        if collapseFraction > 0.5 {
            // Collapsed: lens pill only, full-width. Topic identity lives in
            // the date row (status row) above.
            LensToggleBinding(lens: $bindable.globalLens, action: BreevesMotion.lensToggle)
        } else {
            // Expanded: stacked, both full-width.
            VStack(spacing: BreevesSpace.s3) {
                TopicSelector(
                    selection: topicBinding,
                    labels: names,
                    topicColors: topicColors
                )
                LensToggleBinding(lens: $bindable.globalLens, action: BreevesMotion.lensToggle)
            }
        }
    }

    // MARK: - Bottom bar (auto-hide)

    private var bottomBar: some View {
        VStack(spacing: 0) {
            ProgressHairline(read: app.totalRead, total: app.totalArticles)
                .padding(.horizontal, BreevesSpace.s5)
                .padding(.vertical, BreevesSpace.s3)
        }
        .background(
            Rectangle()
                .fill(BreevesColor.bgCanvas.opacity(0.92))
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .opacity(bottomBarVisible ? 1 : 0)
        .offset(y: bottomBarVisible ? 0 : 20)
        .animation(.easeOut(duration: 0.25), value: bottomBarVisible)
        .accessibilityHidden(!bottomBarVisible)
    }

    // MARK: - Pager

    private func pager(briefing: DailyBriefing) -> some View {
        let topic = briefing.topics[min(activeTopic, briefing.topics.count - 1)]
        let articles = topic.articles
        let pageCount = articles.count + 1

        return TabView(selection: $activeArticle) {
            ForEach(Array(articles.enumerated()), id: \.element.id) { idx, article in
                articlePage(article: article, index: idx, total: articles.count)
                    .tag(idx)
            }
            nudgeCard(briefing: briefing, currentTopic: topic)
                .tag(pageCount - 1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .indexViewStyle(.page(backgroundDisplayMode: .never))
    }

    private func articlePage(article: Article, index: Int, total: Int) -> some View {
        ScrollView {
            ArticleCardView(
                article: article,
                index: index,
                total: total,
                lens: app.globalLens,
                isRead: app.readArticleIds.contains(article.id),
                onOpenFull: {
                    // Prefer the publisher's URL; fall back to the in-app
                    // article-detail placeholder if the article is a fixture
                    // without a real source URL.
                    fullArticleURL = article.url.flatMap(URL.init(string:))
                        ?? URL(string: "https://breeves.app/articles/\(article.id)")
                }
            )
            .padding(.horizontal, BreevesSpace.s5)
            // Top inset reserves room for the floating header (changes with collapse)
            .padding(.top, headerOffsetForContent)
            // Bottom inset reserves room for the floating progress bar
            .padding(.bottom, BreevesSpace.s7 + 64)
            .animation(BreevesMotion.lensToggle, value: app.globalLens)
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { oldOffset, newOffset in
            // Only the visible page should drive offset (tag matches activeArticle).
            guard activeArticle == index else { return }
            scrollOffset = max(0, newOffset)
            handleScrollChange(oldOffset: oldOffset, newOffset: newOffset)
        }
    }

    /// The article content is offset by however much of the header is currently visible.
    /// When fully collapsed the inset is just the collapsed header height.
    private var headerOffsetForContent: CGFloat {
        let expanded = expandedHeaderHeight
        let collapsed = collapsedHeaderHeight
        return collapsed + (expanded - collapsed) * (1 - collapseFraction)
    }

    private func handleScrollChange(oldOffset: CGFloat, newOffset: CGFloat) {
        let delta = newOffset - oldOffset
        guard abs(delta) > 1 else { return }
        let dir: ScrollDirection = delta > 0 ? .down : .up
        // Any scroll motion brings the bottom bar back.
        if !bottomBarVisible {
            withAnimation(.easeOut(duration: 0.2)) {
                bottomBarVisible = true
            }
        }
        lastScrollDirection = dir
        lastScrollActivity = .now
    }

    // MARK: - Nudge card (unchanged from previous)

    @ViewBuilder
    private func nudgeCard(briefing: DailyBriefing, currentTopic: TopicBriefing) -> some View {
        let nextIdx = (activeTopic + 1) % briefing.topics.count
        let isLastTopic = activeTopic == briefing.topics.count - 1
        let next = briefing.topics[nextIdx]
        let allRead = briefing.topics
            .flatMap(\.articles)
            .allSatisfy { app.readArticleIds.contains($0.id) }

        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: BreevesSpace.s7)
                Hairline(strength: .standard)
                Spacer().frame(height: BreevesSpace.s5)

                VStack(alignment: .leading, spacing: BreevesSpace.s4) {
                    if allRead {
                        Text("YOU'RE ALL CAUGHT UP.")
                            .breevesLabelM()
                            .foregroundStyle(BreevesColor.textTertiary)
                        Text("Tomorrow's brief lands at \(deliveryTime()).")
                            .breevesHeadlineL()
                            .foregroundStyle(BreevesColor.textPrimary)
                    } else if isLastTopic {
                        Text("END OF \(currentTopic.topic.uppercased())")
                            .breevesLabelM()
                            .foregroundStyle(BreevesColor.textTertiary)
                        Text("Three topics down. Pick one to revisit, or wait for tomorrow.")
                            .breevesHeadlineL()
                            .foregroundStyle(BreevesColor.textPrimary)
                    } else {
                        Text("END OF \(currentTopic.topic.uppercased())")
                            .breevesLabelM()
                            .foregroundStyle(BreevesColor.textTertiary)

                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text("Next: ")
                                .breevesHeadlineL()
                                .foregroundStyle(BreevesColor.textSecondary)
                            Text(next.topic)
                                .breevesHeadlineL()
                                .foregroundStyle(BreevesColor.topic(slot: nextIdx))
                        }

                        Text("\(next.articles.count) articles · about \(estimatedTopicMinutes(next)) minutes.")
                            .breevesBodyM()
                            .foregroundStyle(BreevesColor.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer().frame(height: BreevesSpace.s6)

                if !allRead && !isLastTopic {
                    Button {
                        withAnimation(BreevesMotion.lensToggle) {
                            activeTopic = nextIdx
                            activeArticle = 0
                        }
                    } label: {
                        HStack(spacing: BreevesSpace.s2) {
                            Text("Begin \(next.topic)")
                                .breevesBodyL()
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(BreevesColor.accentPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(BreevesColor.bgElevated1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(BreevesColor.accentPrimary, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                } else if isLastTopic && !allRead {
                    Button {
                        withAnimation(BreevesMotion.lensToggle) {
                            activeTopic = 0
                            activeArticle = 0
                        }
                    } label: {
                        HStack(spacing: BreevesSpace.s2) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back to \(briefing.topics[0].topic)")
                                .breevesBodyL()
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(BreevesColor.accentPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(BreevesColor.bgElevated1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(BreevesColor.accentPrimary, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, BreevesSpace.s5)
            .padding(.top, headerOffsetForContent)
            .padding(.bottom, BreevesSpace.s7 + 64)
        }
        .scrollIndicators(.hidden)
    }

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: BreevesSpace.s5) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: BreevesSpace.s3) {
                    Hairline()
                    Rectangle()
                        .fill(BreevesColor.hairlineStandard)
                        .frame(height: 28)
                        .frame(maxWidth: 240)
                    Rectangle()
                        .fill(BreevesColor.hairlineFaint)
                        .frame(height: 16)
                    Rectangle()
                        .fill(BreevesColor.hairlineFaint)
                        .frame(height: 16)
                        .frame(maxWidth: 180)
                }
                .padding(.vertical, BreevesSpace.s4)
            }
        }
        .padding(.horizontal, BreevesSpace.s5)
    }

    private func errorState(message: String) -> some View {
        VStack(alignment: .leading, spacing: BreevesSpace.s2) {
            Hairline()
            Text(message)
                .breevesCaption()
                .foregroundStyle(BreevesColor.stateDanger)
            Button {
                Task { await app.loadBriefing() }
            } label: {
                Text("Retry")
                    .breevesCaption()
                    .fontWeight(.semibold)
                    .foregroundStyle(BreevesColor.accentPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, BreevesSpace.s4)
        .padding(.horizontal, BreevesSpace.s5)
    }

    // MARK: - Helpers

    private func formattedDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · dd MMM"
        return f.string(from: Date()).uppercased()
    }

    private func deliveryTime() -> String {
        var c = DateComponents()
        c.hour = app.preferences.notificationHour
        c.minute = app.preferences.notificationMinute
        let date = Calendar.current.date(from: c) ?? Date()
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    private func estimatedTopicMinutes(_ topic: TopicBriefing) -> Int {
        max(1, Int((Double(topic.articles.count) * 1.7).rounded()))
    }
}

private struct LensToggleBinding: View {
    @Binding var lens: ReadingLens
    let action: Animation

    var body: some View {
        let intBinding = Binding<Int>(
            get: { ReadingLens.allCases.firstIndex(of: lens) ?? 0 },
            set: { idx in
                withAnimation(action) {
                    lens = ReadingLens.allCases[idx]
                }
            }
        )
        return LensToggle(selection: intBinding)
    }
}

private struct IdentifiableURL: Identifiable, Hashable {
    let url: URL
    var id: URL { url }
}

private struct SafariSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.preferredControlTintColor = UIColor(BreevesColor.accentPrimary)
        vc.preferredBarTintColor = UIColor(BreevesColor.bgCanvas)
        return vc
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
