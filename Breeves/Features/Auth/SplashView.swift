import SwiftUI
import DesignSystem

struct SplashView: View {
    @State private var visible = false

    var body: some View {
        VStack(spacing: BreevesSpace.s4) {
            Spacer()
            BrassMark()
            Text("Breeves")
                .breevesDisplayXL()
                .foregroundStyle(BreevesColor.textPrimary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BreevesColor.bgCanvas)
        .opacity(visible ? 1 : 0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6)) { visible = true }
        }
    }
}
