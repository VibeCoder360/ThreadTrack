import SwiftUI
import SwiftData
import PhotosUI

// MARK: - AddItemView
struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedCategory: ClothingCategory = .tops
    @State private var selectedColor: ColorTag = .black
    @State private var maxWears: Int = 3
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Photo Section
                    photoSection

                    // Name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Item Name")
                            .ttSectionHeader("Item Name")
                        TextField("e.g. Navy Oxford Shirt", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.horizontal)

                    // Category
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .ttSectionHeader("Category")
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(ClothingCategory.allCases) { cat in
                                categoryButton(cat)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Color Tag
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color")
                            .ttSectionHeader("Color")
                        FlowLayout(spacing: 8) {
                            ForEach(ColorTag.allCases) { color in
                                colorChip(color)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Laundry Threshold
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Laundry Threshold")
                                .ttSectionHeader("Laundry Threshold")
                            Spacer()
                            Text("\(maxWears) wears")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(TTColorTheme.accent)
                        }

                        Stepper("Wears before laundry", value: $maxWears, in: 1...10)
                            .labelsHidden()

                        Text("Item will be flagged for laundry after \(maxWears) wears")
                            .font(.caption)
                            .foregroundColor(TTColorTheme.tertiaryText)
                    }
                    .padding(.horizontal)
                    .ttCard()
                }
                .padding(.vertical)
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveItem() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraCaptureView(image: $selectedImage)
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                    }
                }
            }
        }
    }

    // MARK: - Photo Section
    @ViewBuilder
    private var photoSection: some View {
        VStack(spacing: 12) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            selectedImage = nil
                            selectedItem = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }
                        .padding(8)
                    }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(TTColorTheme.secondaryBackground)
                    .frame(height: 200)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "camera")
                                .font(.largeTitle)
                                .foregroundColor(TTColorTheme.tertiaryText)
                            Text("Add a photo")
                                .font(.subheadline)
                                .foregroundColor(TTColorTheme.tertiaryText)
                        }
                    }
            }

            HStack(spacing: 16) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    showCamera = true
                } label: {
                    Label("Camera", systemImage: "camera")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Category Button
    private func categoryButton(_ category: ClothingCategory) -> some View {
        Button {
            selectedCategory = category
        } label: {
            VStack(spacing: 4) {
                Image(systemName: category.systemImage)
                    .font(.title3)
                Text(category.displayName)
                    .font(.caption2)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(selectedCategory == category
                ? TTColorTheme.accent
                : TTColorTheme.tertiaryBackground)
            .foregroundColor(selectedCategory == category
                ? .white
                : TTColorTheme.secondaryText)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Color Chip
    private func colorChip(_ color: ColorTag) -> some View {
        Button {
            selectedColor = color
        } label: {
            Circle()
                .fill(color.swiftUIColor)
                .frame(width: 32, height: 32)
                .overlay {
                    if selectedColor == color {
                        Circle()
                            .strokeBorder(TTColorTheme.accent, lineWidth: 3)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save
    private func saveItem() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let imageData = selectedImage?.jpegData(compressionQuality: 0.8)
        let thumbnail = selectedImage?
            .prepareThumbnail(size: CGSize(width: 200, height: 200))
            ?.jpegData(compressionQuality: 0.6)

        let item = ClothingItem(
            name: trimmedName,
            category: selectedCategory,
            colorTag: selectedColor,
            photoData: imageData,
            thumbnailData: thumbnail,
            maxWearsBeforeLaundry: maxWears
        )

        modelContext.insert(item)
        dismiss()
    }
}

// MARK: - Simple Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                                  proposal: ProposedViewSize(result.sizes[index]))
        }
    }

    private struct LayoutResult {
        var size: CGSize
        var positions: [CGPoint]
        var sizes: [CGSize]
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            sizes.append(size)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }
        totalHeight = y + rowHeight
        return LayoutResult(
            size: CGSize(width: min(maxX, maxWidth), height: totalHeight),
            positions: positions,
            sizes: sizes
        )
    }
}
