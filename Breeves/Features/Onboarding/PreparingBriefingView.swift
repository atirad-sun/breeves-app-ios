import SwiftUI
import DesignSystem

/// First-run loading screen shown after Begin while the live pipeline
/// generates today's briefing. Cold-cache run takes 60-100s — without
/// feedback the user assumes the app froze. We rotate status copy that
/// loosely tracks pipeline stages (fetch → extract → summarize) so the
/// wait feels like progress instead of a hang.
///
/// We don't surface real progress events from the Edge Function: that
/// would need streaming + per-user telemetry the MVP doesn't carry. The
/// rotating copy is timing-based and intentionally vague — it's about
/// reassurance, not accuracy.
struct PreparingBriefingView: View {
    private static let messages: [String] = [
        "Scanning today's headlines…",
        "Reading the full articles…",
        "Distilling the signal…",
        "Drafting your briefing…",
        "Almost there — final polish…",
    ]

    @State private var messageIndex: Int = 0
    @State private var elapsed: TimeInterval = 0
    @State private var pulse: Bool = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var currentMessage: String {
        Self.messages[min(messageIndex, Self.messages.count - 1)]
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: BreevesSpace.s5) {
                BrassMark()
                    .scaleEffect(pulse ? 1.06 : 1.0)
                    .opacity(pulse ? 0.85 : 1.0)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)

                Text("Preparing your first briefing")
                    .breevesDisplayL()
                    .foregroundStyle(BreevesColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)

                Text(currentMessage)
                    .breevesBodyM()
                    .foregroundStyle(BreevesColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .id(messageIndex)
                    .transition(.opacity.combined(with: .offset(y: 4)))
            }

            Spacer()

            VStack(spacing: BreevesSpace.s2) {
                ProgressView()
                    .controlSize(.regular)
                    .tint(BreevesColor.accentPrimary)

                Text(reassurance)
                    .breevesCaption()
                    .foregroundStyle(BreevesColor.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .padding(.bottom, BreevesSpace.s7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, BreevesSpace.s5)
        .background(BreevesColor.bgCanvas.ignoresSafeArea())
        .onAppear { pulse = true }
        .onReceive(timer) { _ in
            elapsed += 1
            // Advance the rotating copy roughly every 12s. Caps at the last
            // message; the screen is dismissed by the AppModel routing the
            // moment loadBriefing() returns.
            let nextIndex = min(Int(elapsed / 12), Self.messages.count - 1)
            if nextIndex != messageIndex {
                withAnimation(.easeInOut(duration: 0.3)) {
                    messageIndex = nextIndex
                }
            }
        }
    }

    /// Honest about the wait. Cold-cache pipeline is ~90s; subsequent
    /// days are instant because the briefing row is already cached.
    private var reassurance: String {
        if elapsed < 30 {
            return "This usually takes about a minute. Hang tight."
        } else if elapsed < 75 {
            return "Almost done — pulling articles, summarizing each one."
        } else {
            return "Taking a little longer than usual. We'll be there shortly."
        }
    }
}
