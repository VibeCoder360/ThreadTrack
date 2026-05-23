import SwiftUI

// MARK: - WardrobeGridView

/// Main wardrobe view showing all items in a filterable grid.
/// Supports category filtering, search, multi-selection for batch laundry, and add/edit navigation.
struct WardrobeGridView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClothingItem.name) private var allItems: [ClothingItem]

    @State private var searchText: String = ""
    @State private var selectedCategory: ClothingCategory? = nil
    @State private var isMultiSelectMode: Bool = false
    @State private var selectedItems: Set<UUID> = []
    @State private var showingAddItem: Bool = false
    @State private var itemToEdit: ClothingItem?
    @State private var showingBatchConfirmation: Bool = false

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 12)
    ]

    private var wardrobeService: WardrobeService {
        WardrobeService(modelContext: modelContext)
    }

    /// Filtered items based on search text and category filter.
    private var filteredItems: [ClothingItem] {
        var items = allItems
        if let selectedCategory {
            items = items.filter { $0.category == selectedCategory }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            items = items.filter { item in
                item.name.localizedCaseInsensitiveContains(query)
                || (item.brand?.localizedCaseInsensitiveContains(query) ?? false)
                || item.tags.contains { $0.localizedCaseInsensitiveContains(query) }
            }
        }
        return items
    }

    /// Number of items needing laundry.
    private var dirtyItemCount: Int {
        allItems.filter(\.needsLaundry).count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter chips
                categoryScrollView

                // Items grid
                if filteredItems.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(filteredItems) { item in
                                itemCard(for: item)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationTitle("Wardrobe")
            .searchable(text: $searchText, prompt: "Search items...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isMultiSelectMode {
                        Button("Cancel") {
                            isMultiSelectMode = false
                            selectedItems.removeAll()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isMultiSelectMode {
                        Button("Laundry (\(selectedItems.count))") {
                            showingBatchConfirmation = true
                        }
                        .disabled(selectedItems.isEmpty)
                    } else {
                        Menu {
                            Button {
                                isMultiSelectMode = true
                            } label: {
                                Label("Select Multiple", systemImage: "checklist")
                            }
                            Button {
                                showingAddItem = true
                            } label: {
                                Label("Add Item", systemImage: "plus")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView()
            }
            .sheet(item: $itemToEdit) { item in
                EditItemView(item: item)
            }
            .alert("Mark as Laundered", isPresented: $showingBatchConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Launder \(selectedItems.count) Items") {
                    batchLaunder()
                }
            } message: {
                Text("This will reset the wear count for \(selectedItems.count) items and create a laundry batch record.")
            }
        }
    }

    // MARK: - Category Filter Scroll

    @ViewBuilder
    private var categoryScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                FilterChip(
                    title: "All",
                    count: allItems.count,
                    isSelected: selectedCategory == nil,
                    accentColor: .blue
                ) {
                    withAnimation { selectedCategory = nil }
                }

                // Category chips
                ForEach(ClothingCategory.allCases) { cat in
                    let count = allItems.filter { $0.category == cat }.count
                    FilterChip(
                        title: cat.displayName,
                        count: count,
                        isSelected: selectedCategory == cat,
                        accentColor: Color(hex: cat.accentColorHex) ?? .gray
                    ) {
                        withAnimation {
                            selectedCategory = selectedCategory == cat ? nil : cat
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tshirt")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No items yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Tap + to add your first clothing item")
                .foregroundStyle(.secondary)
            Button("Add Item") {
                showingAddItem = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Item Card

    @ViewBuilder
    private func itemCard(for item: ClothingItem) -> some View {
        ItemCard(item: item)
            .onTapGesture {
                if isMultiSelectMode {
                    toggleSelection(item)
                } else {
                    itemToEdit = item
                }
            }
            .overlay {
                if isMultiSelectMode && selectedItems.contains(item.id) {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor, lineWidth: 3)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white, .blue)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(8)
                }
            }
    }

    // MARK: - Actions

    private func toggleSelection(_ item: ClothingItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    private func batchLaunder() {
        let itemsToLaunder = allItems.filter { selectedItems.contains($0.id) }
        wardrobeService.markAsLaundered(items: itemsToLaunder)
        isMultiSelectMode = false
        selectedItems.removeAll()
    }
}

// MARK: - FilterChip

/// A small chip for category filtering.
struct FilterChip: View {

    let title: String
    let count: Int
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(isSelected ? .white.opacity(0.3) : Color(.systemGray5)))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(isSelected ? accentColor : Color(.systemGray5))
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WardrobeGridView()
        .modelContainer(for: [ClothingItem.self, DailyOutfit.self, LaundryBatch.self], inMemory: true)
}
