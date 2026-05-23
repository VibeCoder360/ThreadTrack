import SwiftUI
import SwiftData

@main
struct ThreadTrackApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: ClothingItem.self, DailyOutfit.self, LaundryBatch.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
        }
        .modelContainer(modelContainer)
    }
}
