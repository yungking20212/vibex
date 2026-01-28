import SwiftUI

struct AIGameView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("AI Game — Coming Soon")
                .font(.title2).bold()
            Text("We're building playful AI experiences. Check back soon for mini-games, challenges, and socials.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Spacer()

            Image(systemName: "gamecontroller.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .foregroundStyle(LinearGradient(colors: [Color.vbPurple, Color.vbPink, Color.vbBlue], startPoint: .topLeading, endPoint: .bottomTrailing))

            Spacer()

            Button("Notify me") {
                // Placeholder action: wire up notifications or feature flags later
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("AI Game")
    }
}

struct AIGameView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { AIGameView() }
    }
}
