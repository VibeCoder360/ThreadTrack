import SwiftUI

// MARK: - ItemCard

/// A single wardrobe item card showing photo, name, wear count, and laundry indicator.
struct ItemCard: View {

    let item: ClothingItem

    @State private var loadedImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Photo / placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))

                if let loadedImage {
                    Image(uiImage: loadedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 120)
                        .clipped()
                } else {
                    Image(systemName: item.category.systemImage)
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                        .frame(height: 120)
                }

                // Laundry badge
                if item.needsLaundry {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "drop.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Circle().fill(.red))
                                .padding(6)
                        }
                        Spacer()
                    }
                }

                // Category badge
                VStack {
                    HStack {
                        Text(item.category.displayName)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(item.categoryColor))
                            .padding(6)
                        Spacer()
                    }
                    Spacer()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Name
            Text(item.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            // Brand + wear count row
            HStack {
                if let brand = item.brand {
                    Text(brand)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                wearCountLabel
            }

            // Cleanliness progress bar
            cleanlinessBar
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        .task {
            if let filename = item.photoFilename {
                loadedImage = ClothingImageStore.load(filename: filename)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var wearCountLabel: some View {
        HStack(spacing: 2) {
            Image(systemName: "repeat")
                .font(.caption2)
            Text("\(item.wearCount)/\(item.laundryThreshold)")
                .font(.caption)
                .monospacedDigit()
        }
        .foregroundStyle(item.needsLaundry ? .red : .secondary)
    }

    private var cleanlinessBar: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(.systemGray5))
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(cleanlinessColor)
                        .frame(width: geo.size.width * item.cleanlinessRatio)
                }
        }
        .frame(height: 4)
    }

    private var cleanlinessColor: Color {
        let ratio = item.cleanlinessRatio
        if ratio > 0.6 { return .green }
        if ratio > 0.3 { return .orange }
        return .red
    }

    private var categoryColor: Color {
        Color(hex: item.category.accentColorHex) ?? .gray
    }
}

// MARK: - Color Hex Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    let item = ClothingItem(name: "Blue T-Shirt", category: .tops, brand: "Uniqlo")
    return ItemCard(item: item)
        .frame(width: 160)
        .padding()
}
