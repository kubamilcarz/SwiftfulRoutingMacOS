import SwiftUI

struct RegressionSwipeScreen: View {
    let session: RegressionSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button("Edge button taps: \(session.taps)") { session.taps += 1 }
                Text("Tap the edge button and toolbar control; scroll vertically. Then drag inward from the content edge to return.")
                ForEach(0..<30) { index in Text("Scrollable row \(index)") }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Test toolbar", systemImage: "hand.tap") { session.taps += 1 }
            }
        }
    }
}
