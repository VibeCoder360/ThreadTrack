import SwiftUI
import PhotosUI

// MARK: - AddItemView

/// Form for adding a new clothing item to the wardrobe.
struct AddItemView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedCategory: ClothingCategory = .tops
    @State private var brand: String = ""
    @State private var color: String = ""
    @State private var notes: String = ""
    @State private var tagInput: String = ""
    @State private var tags: [String] = []
    @State private var laundryThreshold: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var savedPhotoFilename: String?

    private var wardrobeService: WardrobeService {
        WardrobeService(modelContext: modelContext)
    }

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                basicInfoSection
                categorySection
                detailsSection
                laundrySection
                tagsSection
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
                }
            }
            .onChange(of: selectedPhotoItem) {
                Task {
                    if let item = selectedPhotoItem {
                        savedPhotoFilename = await ClothingImageStore.save(from: item)
                    }
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var photoSection: some View {
        Section("Photo") {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack {
                    if let savedPhotoFilename {
                        if let img = ClothingImageStore.load(filename: savedPhotoFilename) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    Label(
                        savedPhotoFilename == nil ? "Choose Photo" : "Change Photo",
                        systemImage: "photo.on.rectangle.angled"
                    )
                }
            }
            if let savedPhotoFilename {
                Button("Remove Photo", role: .destructive) {
                    ClothingImageStore.delete(filename: savedPhotoFilename)
                    savedPhotoFilename = nil
                    selectedPhotoItem = nil
                }
            }
        }
    }

    @ViewBuilder
    private var basicInfoSection: some View {
        Section("Basic Info") {
            TextField("Name *", text: $name)
            TextField("Brand", text: $brand)
            TextField("Color", text: $color)
        }
    }

    @ViewBuilder
    private var categorySection: some View {
        Section("Category") {
            Picker("Category", selection: $selectedCategory) {
                ForEach(ClothingCategory.allCases) { cat in
                    Label(cat.displayName, systemImage: cat.systemImage)
                        .tag(cat)
                }
            }
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        Section("Details") {
            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    @ViewBuilder
    private var laundrySection: some View {
        Section("Laundry") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Wears before laundry")
                    .font(.subheadline)
                HStack {
                    TextField("Threshold", text: $laundryThreshold)
                        .keyboardType(.numberPad)
                        .frame(width: 60)
                    Text("(default: \(selectedCategory.defaultLaundryThreshold))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private var tagsSection: some View {
        Section("Tags") {
            HStack {
                TextField("Add tag", text: $tagInput)
                    .onSubmit { addTag() }
                Button("Add", action: addTag)
                    .disabled(tagInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if !tags.isEmpty {
                FlowLayout(tags: tags) { tag in
                    HStack(spacing: 4) {
                        Text(tag)
                            .font(.caption)
                        Button {
                            tags.removeAll { $0 == tag }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(.systemGray5)))
                }
            }
        }
    }

    // MARK: - Actions

    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty && !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        tagInput = ""
    }

    private func saveItem() {
        let threshold = Int(laundryThreshold) ?? selectedCategory.defaultLaundryThreshold
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        wardrobeService.addItem(
            name: trimmedName,
            category: selectedCategory,
            brand: brand.isEmpty ? nil : brand,
            color: color.isEmpty ? nil : color,
            notes: notes.isEmpty ? nil : notes,
            tags: tags,
            photoFilename: savedPhotoFilename,
            laundryThreshold: threshold
        )
        dismiss()
    }
}

// MARK: - FlowLayout

/// Simple flow layout for tag chips.
struct FlowLayout: View {
    let tags: [String]
    let tagView: (String) -> some View

    var body: some View {
        WrappingHStack(tags) { tag in
            tagView(tag)
        }
    }
}

/// A horizontal stack that wraps to the next line when items overflow.
struct WrappingHStack<Data: RandomAccessCollection, Content: View>: View {
    let data: Data
    let content: (Data.Element) -> Content

    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }

    var body: some View {
        FlowLayoutLayout(data: data, content: content)
    }
}

/// Internal layout implementation for wrapping HStack.
struct FlowLayoutLayout<Data: RandomAccessCollection, Content: View>: Layout {
    let data: Data
    let content: (Data.Element) -> Content

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private struct LayoutResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + 4
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + 4
            totalWidth = max(totalWidth, x)
        }

        totalHeight = y + rowHeight
        return LayoutResult(size: CGSize(width: min(totalWidth, maxWidth), height: totalHeight), positions: positions)
    }
}

#Preview {
    AddItemView()
}
