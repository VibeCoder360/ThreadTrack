import SwiftUI
import SwiftData

// MARK: - LaundryView
struct LaundryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [ClothingItem]
    @Query(sort: \LaundryBatch.date, order: .reverse) private var batches: [LaundryBatch]
    @State private var selectedItems: Set<UUID> = []
    @State private var showHistory = false

    private var dueItems: [ClothingItem] {
        allItems.filter { $0.laundryDue }
    }

    private var dirtyItems: [ClothingItem] {
        allItems.filter { $0.isDirty }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showHistory {
                    laundryHistory
                } else {
                    laundryDueView
                }
            }
            .navigationTitle("Laundry")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showHistory.toggle()
                    } label: {
                        Text(showHistory ? "Due Items" : "History")
                            .font(.subheadline)
                    }
                }
            }
            .animation(.easeInOut, value: showHistory)
        }
    }

    // MARK: - Due Items View
    @ViewBuilder
    private var laundryDueView: some View {
        if dueItems.isEmpty {
            TTEmptyStateView(
                systemImage: "checkmark.seal",
                title: "All Clean!",
                subtitle: "No items are due for laundry right now"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                // Summary header
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundColor(TTColorTheme.laundryDue)
                    Text("\(dueItems.count) items due")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Button {
                        if selectedItems.isEmpty {
                            selectedItems = Set(dueItems.map(\.id))
                        } else {
                            selectedItems.removeAll()
                        }
                    } label: {
                        Text(selectedItems == Set(dueItems.map(\.id)) ? "Deselect All" : "Select All")
                            .font(.caption)
                            .foregroundColor(TTColorTheme.accent)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(TTColorTheme.laundryDue.opacity(0.1))

                // Items list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(dueItems) { item in
                            LaundryItemRow(
                                item: item,
                                isSelected: selectedItems.contains(item.id)
                            ) {
                                toggleItem(item)
                            }
                        }
                    }
                    .padding()
                }

                // Batch action button
                if !selectedItems.isEmpty {
                    Button {
                        startLaundry()
                    } label: {
                        Label("Start Laundry (\(selectedItems.count) items)",
                              systemImage: "washer.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(TTColorTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Laundry History
    @ViewBuilder
    private var laundryHistory: some View {
        if batches.isEmpty {
            TTEmptyStateView(
                systemImage: "clock",
                title: "No History",
                subtitle: "Completed laundry batches will appear here"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(batches) { batch in
                        LaundryBatchCard(batch: batch)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Actions
    private func toggleItem(_ item: ClothingItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    private func startLaundry() {
        let itemsToClean = allItems.filter { selectedItems.contains($0.id) }

        guard !itemsToClean.isEmpty else { return }

        // Create laundry batch
        let batch = LaundryBatch(items: itemsToClean)
        modelContext.insert(batch)

        // Reset items
        for item in itemsToClean {
            item.wearCount = 0
            item.isDirty = false
            item.lastWornDate = nil
        }

        selectedItems.removeAll()
    }
}

// MARK: - Laundry Item Row
struct LaundryItemRow: View {
    let item: ClothingItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if let thumb = item.thumbnailData, let img = UIImage(data: thumb) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(TTColorTheme.tertiaryBackground)
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: item.category.systemImage)
                                .font(.caption)
                                .foregroundColor(TTColorTheme.tertiaryText)
                        }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(TTColorTheme.text)
                    Text(item.category.displayName)
                        .font(.caption)
                        .foregroundColor(TTColorTheme.secondaryText)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("Worn \(item.wearCount)x")
                        .font(.caption)
                        .foregroundColor(TTColorTheme.laundryDue)
                }

                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? TTColorTheme.accent : TTColorTheme.tertiaryText)
                    .font(.title3)
            }
            .padding(10)
            .background(isSelected
                ? TTColorTheme.accent.opacity(0.1)
                : TTColorTheme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Laundry Batch Card
struct LaundryBatchCard: View {
    let batch: LaundryBatch

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: batch.isCompleted ? "checkmark.circle.fill" : "washer.fill")
                    .foregroundColor(batch.isCompleted ? TTColorTheme.laundryFresh : TTColorTheme.accent)

                Text(batch.date, style: .date)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text("\(batch.items.count) items")
                    .font(.caption)
                    .foregroundColor(TTColorTheme.secondaryText)
            }

            if batch.isCompleted, let completedDate = batch.completedDate {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("Completed \(completedDate, style: .relative)")
                        .font(.caption)
                        .foregroundColor(TTColorTheme.secondaryText)
                }
            }

            // Item thumbnails
            if !batch.items.isEmpty {
                HStack(spacing: 6) {
                    ForEach(batch.items) { item in
                        if let thumb = item.thumbnailData, let img = UIImage(data: thumb) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                        }
                    }
                }
            }
        }
        .padding()
        .background(TTColorTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
