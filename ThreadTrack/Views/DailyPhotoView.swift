import SwiftUI
import AVFoundation
import SwiftData

// MARK: - DailyPhotoView (Main Screen)
struct DailyPhotoView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyOutfit.date, order: .reverse) private var outfits: [DailyOutfit]
    @State private var capturedImage: UIImage? = nil
    @State private var showingCamera = false
    @State private var showingReview = false

    private var todayOutfit: DailyOutfit? {
        let calendar = Calendar.current
        return outfits.first { calendar.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let outfit = todayOutfit {
                    // Today's outfit already logged
                    VStack(spacing: 16) {
                        if let photoData = outfit.photoData, let img = UIImage(data: photoData) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        Label("Today's outfit logged", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundColor(TTColorTheme.laundryFresh)

                        if !outfit.items.isEmpty {
                            Text("\(outfit.items.count) items tracked")
                                .font(.subheadline)
                                .foregroundColor(TTColorTheme.secondaryText)
                        }

                        HStack(spacing: 12) {
                            ForEach(outfit.items) { item in
                                VStack(spacing: 4) {
                                    if let thumb = item.thumbnailData, let uiImg = UIImage(data: thumb) {
                                        Image(uiImage: uiImg)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 48, height: 48)
                                            .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(TTColorTheme.tertiaryBackground)
                                            .frame(width: 48, height: 48)
                                    }
                                    Text(item.name)
                                        .font(.caption2)
                                        .foregroundColor(TTColorTheme.secondaryText)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                } else {
                    // No outfit yet today — prompt to capture
                    VStack(spacing: 20) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 64))
                            .foregroundColor(TTColorTheme.tertiaryText)

                        Text("No outfit logged today")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Take a photo of today's outfit to track what you're wearing")
                            .font(.subheadline)
                            .foregroundColor(TTColorTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button {
                            showingCamera = true
                        } label: {
                            Label("Capture Today's Outfit", systemImage: "camera.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(TTColorTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 60)
                }

                Spacer()

                // Recent outfits
                let recent = outfits.filter { !Calendar.current.isDateInToday($0.date) }.prefix(3)
                if !recent.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Outfits")
                            .ttSectionHeader("Recent Outfits")

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(recent, id: \.id) { outfit in
                                    VStack(spacing: 4) {
                                        if let data = outfit.photoData, let img = UIImage(data: data) {
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 80, height: 80)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        } else {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(TTColorTheme.tertiaryBackground)
                                                .frame(width: 80, height: 80)
                                        }
                                        Text(outfit.date, style: .relative)
                                            .font(.caption2)
                                            .foregroundColor(TTColorTheme.secondaryText)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .ttCard()
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Today")
            .fullScreenCover(isPresented: $showingCamera) {
                CameraCaptureView(capturedImage: $capturedImage)
            }
            .fullScreenCover(isPresented: $showingReview) {
                if let img = capturedImage {
                    OutfitReviewView(image: img) { matchedItems in
                        saveOutfit(image: img, items: matchedItems)
                    }
                }
            }
            .onChange(of: capturedImage) { _, newImage in
                if newImage != nil {
                    capturedImage = nil
                    // The camera view handles its own review; if we get an image here, show review
                }
            }
        }
    }

    private func saveOutfit(image: UIImage, items: [ClothingItem]) {
        let photoData = image.jpegData(compressionQuality: 0.8)
        let outfit = DailyOutfit(photoData: photoData, items: items)
        modelContext.insert(outfit)

        // Increment wear count for matched items
        for item in items {
            item.wearCount += 1
            item.lastWornDate = Date()
            item.isDirty = item.laundryDue
        }
    }
}

// MARK: - Camera Capture View
struct CameraCaptureView: View {
    @Binding var capturedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var showingReview = false
    @State private var tempCaptured: UIImage? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewRepresentable(capturedImage: $tempCaptured)

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    Spacer()
                }
                .padding(.top, 50)

                Spacer()

                Button {
                    showingReview = true
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(.white, lineWidth: 4)
                            .frame(width: 72, height: 72)
                        Circle()
                            .fill(.white)
                            .frame(width: 58, height: 58)
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .fullScreenCover(isPresented: $showingReview) {
            if let img = tempCaptured {
                OutfitReviewView(image: img) { items in
                    capturedImage = img
                    // For now, items are saved from review. Just dismiss.
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Camera Preview (UIViewRepresentable)
struct CameraPreviewRepresentable: UIViewRepresentable {
    @Binding var capturedImage: UIImage?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, AVCapturePhotoCaptureDelegate {
        var parent: CameraPreviewRepresentable
        var session: AVCaptureSession?
        var output: AVCapturePhotoOutput?

        init(_ parent: CameraPreviewRepresentable) {
            self.parent = parent
        }

        func photoOutput(_ output: AVCapturePhotoOutput,
                         didFinishProcessingPhoto photo: AVCapturePhoto,
                         error: Error?) {
            if let data = photo.fileDataRepresentation(),
               let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.parent.capturedImage = image
                }
            }
        }
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let session = AVCaptureSession()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                     for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return view
        }

        if session.canAddInput(input) { session.addInput(input) }

        let photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.frame = view.bounds
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)

        context.coordinator.session = session
        context.coordinator.output = photoOutput

        // Start session on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - Outfit Review View (Tag/Match Screen)
struct OutfitReviewView: View {
    let image: UIImage
    let onComplete: ([ClothingItem]) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [ClothingItem]
    @State private var searchText = ""
    @State private var selectedItems: Set<UUID> = []

    private var filteredItems: [ClothingItem] {
        allItems.filter { item in
            searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Preview image
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()

                // Search & Match
                VStack(spacing: 8) {
                    Text("Tag items in this outfit")
                        .font(.headline)
                        .padding(.horizontal)

                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(TTColorTheme.tertiaryText)
                        TextField("Search items...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(TTColorTheme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)

                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(filteredItems) { item in
                                OutfitItemRow(item: item, isSelected: selectedItems.contains(item.id)) {
                                    toggleItem(item)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Confirm button
                Button {
                    let matched = allItems.filter { selectedItems.contains($0.id) }
                    onComplete(matched)
                } label: {
                    Text("Save Outfit (\(selectedItems.count) items)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(TTColorTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding()
            }
            .navigationTitle("Tag Outfit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") {
                        onComplete([])
                    }
                }
            }
        }
    }

    private func toggleItem(_ item: ClothingItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }
}

// MARK: - Outfit Item Row
struct OutfitItemRow: View {
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
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(TTColorTheme.tertiaryBackground)
                        .frame(width: 40, height: 40)
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

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? TTColorTheme.accent : TTColorTheme.tertiaryText)
                    .font(.title3)
            }
            .padding(10)
            .background(isSelected ? TTColorTheme.accent.opacity(0.1) : TTColorTheme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
