import SwiftUI
import SwiftData

// MARK: - StatsView
struct StatsView: View {
    @Query private var items: [ClothingItem]
    @Query private var batches: [LaundryBatch]

    // Computed statistics
    private var totalItems: Int { items.count }
    private var totalWears: Int { items.reduce(0) { $0 + $1.wearCount } }
    private var avgWears: Double {
        totalItems > 0 ? Double(totalWears) / Double(totalItems) : 0
    }

    private var mostWorn: ClothingItem? {
        items.max { $0.wearCount < $1.wearCount }
    }

    private var leastWorn: ClothingItem? {
        items.min { $0.wearCount < $1.wearCount }
    }

    private var utilizationPercent: Double {
        guard totalItems > 0 else { return 0 }
        let recentlyWorn = items.filter {
            guard let last = $0.lastWornDate else { return false }
            return Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 99 < 30
        }.count
        return Double(recentlyWorn) / Double(totalItems) * 100
    }

    private var totalBatches: Int { batches.count }
    private var avgBatchSize: Double {
        totalBatches > 0 ? Double(batches.reduce(0) { $0 + $1.items.count }) / Double(totalBatches) : 0
    }

    private var categoryBreakdown: [(ClothingCategory, Int)] {
        var counts: [ClothingCategory: Int] = [:]
        for item in items {
            counts[item.category, default: 0] += 1
        }
        return counts.map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Overview stats grid
                    overviewGrid

                    // Most/Least worn
                    if totalItems > 0 {
                        mostLeastSection
                    }

                    // Category breakdown
                    if !categoryBreakdown.isEmpty {
                        categorySection
                    }

                    // Laundry insights
                    laundryInsightsSection

                    // Wardrobe utilization
                    utilizationSection
                }
                .padding()
            }
            .navigationTitle("Statistics")
        }
    }

    // MARK: - Overview Grid
    @ViewBuilder
    private var overviewGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(
                title: "Total Items",
                value: "\(totalItems)",
                icon: "tshirt",
                color: TTColorTheme.accent
            )
            StatCard(
                title: "Total Wears",
                value: "\(totalWears)",
                icon: "repeat",
                color: TTColorTheme.green
            )
            StatCard(
                title: "Avg Wears/Item",
                value: String(format: "%.1f", avgWears),
                icon: "chart.bar",
                color: TTColorTheme.orange
            )
            StatCard(
                title: "Laundry Batches",
                value: "\(totalBatches)",
                icon: "washer.fill",
                color: TTColorTheme.laundryDue
            )
        }
    }

    // MARK: - Most/Least Worn
    @ViewBuilder
    private var mostLeastSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wear Rankings")
                .font(.headline)

            if let most = mostWorn, most.wearCount > 0 {
                rankingRow(
                    item: most,
                    label: "Most Worn",
                    icon: "flame.fill",
                    color: TTColorTheme.laundryDue
                )
            }

            if let least = leastWorn {
                rankingRow(
                    item: least,
                    label: "Least Worn",
                    icon: "leaf",
                    color: TTColorTheme.laundryFresh
                )
            }
        }
        .padding()
        .background(TTColorTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func rankingRow(item: ClothingItem, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack(spacing: 4) {
                    Text(item.category.displayName)
                        .font(.caption)
                        .foregroundColor(TTColorTheme.secondaryText)
                    Text("•")
                        .font(.caption)
                        .foregroundColor(TTColorTheme.secondaryText)
                    Text(label)
                        .font(.caption)
                        .foregroundColor(color)
                        .fontWeight(.medium)
                }
            }

            Spacer()

            Text("\(item.wearCount)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }

    // MARK: - Category Breakdown
    @ViewBuilder
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Breakdown")
                .font(.headline)

            ForEach(categoryBreakdown, id: \.0) { category, count in
                HStack(spacing: 12) {
                    Image(systemName: category.systemImage)
                        .foregroundColor(TTColorTheme.secondaryText)
                        .frame(width: 24)

                    Text(category.displayName)
                        .font(.subheadline)

                    Spacer()

                    Text("\(count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(TTColorTheme.tertiaryBackground)
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(TTColorTheme.accent)
                                    .frame(width: geo.size.width * (totalItems > 0 ? Double(count) / Double(totalItems) : 0))
                            }
                    }
                    .frame(width: 80, height: 6)
                }
            }
        }
        .padding()
        .background(TTColorTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Laundry Insights
    @ViewBuilder
    private var laundryInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Laundry Insights")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Batches")
                        .font(.caption)
                        .foregroundColor(TTColorTheme.secondaryText)
                    Text("\(totalBatches)")
                        .font(.title3)
                        .fontWeight(.bold)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Avg Items/Batch")
                        .font(.caption)
                        .foregroundColor(TTColorTheme.secondaryText)
                    Text(String(format: "%.1f", avgBatchSize))
                        .font(.title3)
                        .fontWeight(.bold)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Items Due Now")
                        .font(.caption)
                        .foregroundColor(TTColorTheme.secondaryText)
                    Text("\(items.filter(\.laundryDue).count)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(items.contains(where: \.laundryDue) ? TTColorTheme.laundryDue : TTColorTheme.laundryFresh)
                }
            }
        }
        .padding()
        .background(TTColorTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Wardrobe Utilization
    @ViewBuilder
    private var utilizationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wardrobe Utilization")
                .font(.headline)

            Text("Percentage of items worn in the last 30 days")
                .font(.caption)
                .foregroundColor(TTColorTheme.secondaryText)

            ZStack {
                Circle()
                    .stroke(TTColorTheme.tertiaryBackground, lineWidth: 12)

                Circle()
                    .trim(from: 0, to: utilizationPercent / 100)
                    .stroke(utilizationColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: utilizationPercent)

                VStack(spacing: 2) {
                    Text(String(format: "%.0f%%", utilizationPercent))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(utilizationColor)
                    Text("utilized")
                        .font(.caption)
                        .foregroundColor(TTColorTheme.secondaryText)
                }
            }
            .frame(width: 120, height: 120)
            .frame(maxWidth: .infinity)

            Text(utilizationPercent >= 70
                ? "Great rotation! You're using most of your wardrobe."
                : utilizationPercent >= 40
                ? "Good start. Consider rotating some items you haven't worn."
                : "Many items are sitting unused. Time to rotate your wardrobe!")
                .font(.caption)
                .foregroundColor(TTColorTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(TTColorTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var utilizationColor: Color {
        if utilizationPercent >= 70 { return TTColorTheme.laundryFresh }
        if utilizationPercent >= 40 { return TTColorTheme.laundryWarning }
        return TTColorTheme.laundryDue
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(TTColorTheme.text)

            Text(title)
                .font(.caption)
                .foregroundColor(TTColorTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(TTColorTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
