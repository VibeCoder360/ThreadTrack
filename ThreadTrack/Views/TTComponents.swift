import SwiftUI

// MARK: - Wardrobe Item Card
struct ClothingItemCard: View {
    let item: ClothingItem
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(spacing: 8) {
                // Photo or placeholder
                if let thumbnailData = item.thumbnailData,
                   let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(TTColorTheme.tertiaryBackground)
                        .frame(height: 100)
                        .overlay {
                            Image(systemName: item.category.systemImage)
                                .font(.largeTitle)
                                .foregroundColor(TTColorTheme.tertiaryText)
                        }
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(TTColorTheme.text)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(item.colorTag.swiftUIColor)
                            .frame(width: 8, height: 8)

                        Text(item.category.displayName)
                            .font(.caption)
                            .foregroundColor(TTColorTheme.secondaryText)
                    }

                    // Laundry progress bar
                    VStack(alignment: .leading, spacing: 2) {
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(TTColorTheme.tertiaryBackground)
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(progressColor)
                                        .frame(width: geo.size.width * item.laundryProgress)
                                }
                        }
                        .frame(height: 4)

                        Text("\(item.wearsRemaining) wear\(item.wearsRemaining == 1 ? "" : "s") left")
                            .font(.caption2)
                            .foregroundColor(progressColor)
                    }
                }
            }
            .padding(8)
            .background(TTColorTheme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var progressColor: Color {
        switch item.wearsRemaining {
        case 0: return TTColorTheme.laundryDue
        case 1: return TTColorTheme.laundryWarning
        default: return TTColorTheme.laundryFresh
        }
    }
}

// MARK: - Empty State View
struct TTEmptyStateView: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundColor(TTColorTheme.tertiaryText)

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(TTColorTheme.secondaryText)

            Text(subtitle)
                .font(.body)
                .foregroundColor(TTColorTheme.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Category Filter Chips
struct CategoryFilterChips: View {
    @Binding var selectedCategory: ClothingCategory?
    let categories: [ClothingCategory] = ClothingCategory.allCases

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    label: "All",
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil,
                    onTap: { selectedCategory = nil }
                )

                ForEach(categories) { cat in
                    FilterChip(
                        label: cat.displayName,
                        icon: cat.systemImage,
                        isSelected: selectedCategory == cat,
                        onTap: { selectedCategory = cat }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

struct FilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? TTColorTheme.accent : TTColorTheme.tertiaryBackground)
            .foregroundColor(isSelected ? .white : TTColorTheme.secondaryText)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
