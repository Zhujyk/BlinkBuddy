import SwiftUI

// Phase 1 keeps this scoped to in-menu reminder copy. A real popup surface is deferred.
struct BreakupPopupView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Look away for 20 seconds", systemImage: "figure.walk")
                .font(.subheadline.weight(.semibold))

            Text("BlinkBuddy is ready for a fuller reminder surface in a later phase, but the menu state already reflects when a break is due.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }
}
