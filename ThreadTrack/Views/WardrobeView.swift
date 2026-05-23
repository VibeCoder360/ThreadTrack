import SwiftUI
import SwiftData

// MARK: - WardrobeView
struct WardrobeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClothingItem.addedDate, order: .reverse) private var items: [ClothingItem]
    @State private var searchText = ""
    @State private var selectedCategory: ClothingCategory?
    @State private var displayMode: DisplayMode = .grid
    @State private var showingAddItem = false

    enum DisplayMode: String, CaseIterable {
        case grid, list
        var icon: String {
            switch self {
            case .grid: return "square.grid.2x2"
            case .list: return "list.bullet"
            }
        }
    }

    private var filteredItems: [ClothingItem] {
        items.filter { item in
            let matchesSearch = searchText.isEmpty ||
                item.name.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == nil ||
                item.category == selectedCategory
            return matchesSearch && matchesCategory
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(TTColorTheme.tertiaryText)
                        TextField("Search wardrobe...", text: $searchText)
                            .textFieldStyle(.plain)
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(TTColorTheme.tertiaryText)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .background(TTColorTheme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Display mode toggle
                    Picker("Display", selection: $displayMode) {
                        ForEach(DisplayMode.allCases, id: \.self) { mode in
                            Image(systemName: mode.icon).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 80)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Category filter chips
                CategoryFilterChips(selectedCategory: $selectedCategory)
                    .padding(.vertical, 8)

                // Content
                if filteredItems.isEmpty {
                    TTEmptyStateView(
                        systemImage: "tshirt",
                        title: "No Items Found",
                        subtitle: searchText.isEmpty
                            ? "Tap + to add your first clothing item"
                            : "Try a different search term"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        if displayMode == .grid {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 12) {
                                ForEach(filteredItems) { item in
                                    ClothingItemCard(item: item)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom)
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredItems) { item in
                                    ClothingItemRow(item: item)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom)
                        }
                    }
                }
            }
            .navigationTitle("Wardrobe")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddItem = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .fullScreenCover(isPresented: $showingAddItem) {
                AddItemView()
            }
        }
    }
}

// MARK: - List Row Variant
struct ClothingItemRow: View {
    let item: ClothingItem

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let thumbnailData = item.thumbnailData,
               let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(TTColorTheme.tertiaryBackground)
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: item.category.systemImage)
                            .foregroundColor(TTColorTheme.tertiaryText)
                    }
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(TTColorTheme.text)

                    Circle()
                        .fill(item.colorTag.swiftUIColor)
                        .frame(width: 10, height: 10)
                }

                Text(item.category.displayName)
                    .font(.caption)
                    .foregroundColor(TTColorTheme.secondaryText)
            }

            Spacer()

            // Wear count badge
            VStack {
                Text("\(item.wearsRemaining)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(laundryColor)
                Text("left")
                    .font(.caption2)
                    .foregroundColor(TTColorTheme.secondaryText)
            }
            .padding(8)
            .background(TTColorTheme.tertiaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
        .background(TTColorTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var laundryColor: Color {
        switch item.wearsRemaining {
        case 0: return TTColorTheme.laundryDue
        case 1: return TTColorTheme.laundryWarning
        default: return TTColorTheme.laundryFresh
        }
    }
}
