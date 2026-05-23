import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "tshirt")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Text("ThreadTrack")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Smart Wardrobe & Laundry Tracker")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("ThreadTrack")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ClothingItem.self, inMemory: true)
}
