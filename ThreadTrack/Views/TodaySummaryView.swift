import SwiftUI
import SwiftData

// MARK: - TodaySummaryView
struct TodaySummaryView: View {
    @Query(sort: \ClothingItem.wearCount, order: .descending) private var items: [ClothingItem]
    @Query(sort: \DailyOutfit.date, order: .reverse) private var outfits: [DailyOutfit]

    private var todayOutfit: DailyOutfit? {
        outfits.first { Calendar.current.isDateInToday($0.date) }
    }

    private var laundryDueItems: [ClothingItem] {
        items.filter { $0.laundryDue }
    }

    private var approachingLaundryItems: [ClothingItem] {
        items.filter { !$0.laundryDue && $0.wearsRemaining <= 1 }
    }

    private var totalItems: Int { items.count }
    private var cleanItems: Int { items.filter { !$0.laundryDue }.count }
    private var wardrobeHealth: Double {
        guard totalItems > 0 else { return 1.0 }
        return Double(cleanItems) / Double(totalItems)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Wardrobe Health Card
                    healthCard

                    // Today's Outfit
                    if let outfit = todayOutfit {
                        todayOutfitCard(outfit)
                    }

                    // Items Approaching Laundry
                    if !approachingLaundryItems.isEmpty {
                        approachingLaundrySection
                    }

                    // Items Due for Laundry
                    if !laundryDueItems.isEmpty {
                        laundryDueSection
                    }

                    // Wear Count Summary
                    wearCountSection
                }
                .padding()
            }
            .navigationTitle("Today's Summary")
        }
    }

    // MARK: - Health Card
    @ViewBuilder
    private var healthCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Wardrobe Health")
                        .font(.headline)
                    Text("\(cleanItems) of \(totalItems) items clean")
                        .font(.subheadline)
                        .foregroundColor(TTColorTheme.secondaryText)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(TTColorTheme.tertiaryBackground, lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: wardrobeHealth)
                        .stroke(healthColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: wardrobeHealth)
                    Text("\(Int(wardrobeHealth * 100))%")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .frame(width: 60, height: 60)
            }
        }
        .padding()
        .background(TTColorTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var healthColor: Color {
        if wardrobeHealth >= 0.7 { return TTColorTheme.laundryFresh }
        if wardrobeHealth >= 0.4 { return TTColorTheme.laundryWarning }
        return TTColorTheme.laundryDue
    }

    // MARK: - Today's Outfit Card
    @ViewBuilder
    private func todayOutfitCard(_ outfit: DailyOutfit) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.wear.2")
                    .foregroundColor(TTColorTheme.accent)
                Text("Today's Outfit")
                    .font(.headline)
            }

            if let photoData = outfit.photoData, let img = UIImage(data: photoData) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if !outfit.items.isEmpty {
                HStack(spacing: 8) {
                    ForEach(outfit.items) { item in
                        VStack(spacing: 2) {
                            if let thumb = item.thumbnailData, let ui = UIImage(data: thumb) {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 36, height: 36)
                                    .clipShape(Circle())
                            }
                            Text(item.name)
                                .font(.caption2)
                                .lineLimit(1)
                                .foregroundColor(TTColorTheme.secondaryText)
                        }
                    }
                }
            }
        }
        .padding()
        .background(TTColorTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Approaching Laundry
    @ViewBuilder
    private var approachingLaundrySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(TTColorTheme.laundryWarning)
                Text("Almost Due for Laundry")
                    .font(.headline)
            }

            ForEach(approachingLaundryItems) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(item.category.displayName)
                            .font(.caption)
                            .foregroundColor(TTColorTheme.secondaryText)
                    }

                    Spacer()

                    Text("1 wear left")
                        .font(.caption)
                        .foregroundColor(TTColorTheme.laundryWarning)
                        .fontWeight(.medium)
                }
                .padding(8)
                .background(TTColorTheme.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(TTColorTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Laundry Due Section
    @ViewBuilder
    private var laundryDueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.octagon.fill")
                    .foregroundColor(TTColorTheme.laundryDue)
                Text("Laundry Due")
                    .font(.headline)
            }

            ForEach(laundryDueItems) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(item.category.displayName)
                            .font(.caption)
                            .foregroundColor(TTColorTheme.secondaryText)
                    }

                    Spacer()

                    Image(systemName: "drop.fill")
                        .foregroundColor(TTColorTheme.laundryDue)
                }
                .padding(8)
                .background(TTColorTheme.laundryDue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(TTColorTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Wear Count Summary
    @ViewBuilder
    private var wearCountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wear Count Summary")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Items")
                        .font(.caption)
                        .foregroundColor(TTColorTheme.secondaryText)
                    Text("\(totalItems)")
                        .font(.title)
                        .fontWeight(.bold)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Clean")
                        .font(.caption)
                        .foregroundColor(TTColorTheme.secondaryText)
                    Text("\(cleanItems)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(TTColorTheme.laundryFresh)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Dirty")
                        .font(.caption)
                        .foregroundColor(TTColorTheme.secondaryText)
                    Text("\(laundryDueItems.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(TTColorTheme.laundryDue)
                }
            }
        }
        .padding()
        .background(TTColorTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
