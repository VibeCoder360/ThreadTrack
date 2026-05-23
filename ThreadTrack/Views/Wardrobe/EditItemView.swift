import SwiftUI
import PhotosUI

// MARK: - EditItemView

/// Form for editing an existing clothing item.
struct EditItemView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let item: ClothingItem

    @State private var name: String
    @State private var selectedCategory: ClothingCategory
    @State private var brand: String
    @State private var color: String
    @State private var notes: String
    @State private var tagInput: String
    @State private var tags: [String]
    @State private var laundryThreshold: String
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var savedPhotoFilename: String?
    @State private var isNewPhoto: Bool = false

    private var wardrobeService: WardrobeService {
        WardrobeService(modelContext: modelContext)
    }

    init(item: ClothingItem) {
        self.item = item
        _name = State(initialValue: item.name)
        _selectedCategory = State(initialValue: item.category)
        _brand = State(initialValue: item.brand ?? "")
        _color = State(initialValue: item.color ?? "")
        _notes = State(initialValue: item.notes ?? "")
        _tagInput = State(initialValue: "")
        _tags = State(initialValue: item.tags)
        _laundryThreshold = State(initialValue: String(item.laundryThreshold))
        _savedPhotoFilename = State(initialValue: item.photoFilename)
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
                dangerSection
            }
            .navigationTitle("Edit Item")
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
                    if let pickerItem = selectedPhotoItem {
                        let filename = await ClothingImageStore.save(from: pickerItem)
                        if filename != nil {
                            isNewPhoto = true
                        }
                        savedPhotoFilename = filename
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
                        savedPhotoFilename == nil ? "Add Photo" : "Change Photo",
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
            HStack {
                Text("Current wear count:")
                    .foregroundStyle(.secondary)
                Text("\(item.wearCount)")
                    .fontWeight(.semibold)
                    .foregroundStyle(item.needsLaundry ? .red : .primary)
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

    @ViewBuilder
    private var dangerSection: some View {
        Section {
            Button("Delete Item", role: .destructive) {
                wardrobeService.deleteItem(item)
                dismiss()
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
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        wardrobeService.updateItem(
            item,
            name: trimmedName,
            category: selectedCategory,
            brand: brand.isEmpty ? nil : brand,
            color: color.isEmpty ? nil : color,
            notes: notes.isEmpty ? nil : notes,
            tags: tags,
            photoFilename: savedPhotoFilename,
            laundryThreshold: Int(laundryThreshold)
        )
        dismiss()
    }
}

#Preview {
    EditItemView(
        item: ClothingItem(name: "Blue T-Shirt", category: .tops, brand: "Uniqlo")
    )
}
