import SwiftUI
import PhotosUI

// MARK: - Daily Photo View (Entry Point)

/// The main daily outfit capture screen.
/// Flow: Camera → Review → Match/Tag → Summary
struct DailyPhotoView: View {

    @State private var flowStep: FlowStep = .camera
    @State private var capturedPhotoData: Data?
    @State private var capturedPhotoImage: Image?
    @State private var matches: [ClothingMatch] = []
    @State private var confirmedMatches: [ClothingMatch] = []
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showManualTagMode = false
    @State private var selectedManualItems: Set<UUID> = []

    // Dependencies
    let cameraService: CameraService
    let matcher: ClothingMatcher
    let outfitService: DailyOutfitService
    let summaryVM: TodaySummaryViewModel

    // MARK: - Flow Steps

    enum FlowStep {
        case camera
        case reviewing
        case matching
        case summary
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                switch flowStep {
                case .camera:
                    cameraStep
                case .reviewing:
                    reviewStep
                case .matching:
                    matchStep
                case .summary:
                    summaryStep
                }
            }
            .animation(.easeInOut(duration: 0.3), value: flowStep)
            .navigationTitle(flowTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if flowStep != .camera {
                        Button("Back") {
                            goBack()
                        }
                    }
                }
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let errorMessage { Text(errorMessage) }
            }
        }
    }

    // MARK: - Navigation

    private var flowTitle: String {
        switch flowStep {
        case .camera: return "Daily Outfit"
        case .reviewing: return "Review Photo"
        case .matching: return "Match Clothing"
        case .summary: return "Today's Outfit"
        }
    }

    private func goBack() {
        switch flowStep {
        case .camera: break
        case .reviewing: flowStep = .camera
        case .matching: flowStep = .reviewing
        case .summary: flowStep = .camera
        }
    }

    // MARK: - Step 1: Camera

    private var cameraStep: some View {
        ZStack {
            // Camera preview
            if cameraService.previewImage != nil {
                cameraService.previewImage!
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                Color.black
                    .overlay {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Starting camera...")
                                .foregroundStyle(.secondary)
                        }
                    }
            }

            // Controls overlay
            VStack {
                Spacer()

                HStack(spacing: 48) {
                    // Switch camera
                    Button {
                        Task { try? await cameraService.switchCamera() }
                    } label: {
                        Image(systemName: "camera.rotate")
                            .font(.title)
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                            .background(.ultraThinMaterial, in: Circle())
                    }

                    // Capture button
                    Button {
                        Task { await capturePhoto() }
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(.white, lineWidth: 4)
                                .frame(width: 72, height: 72)
                            Circle()
                                .fill(.white)
                                .frame(width: 58, height: 58)
                        }
                    }
                    .disabled(isProcessing)

                    // Placeholder for symmetry
                    Color.clear.frame(width: 50, height: 50)
                }
                .padding(.bottom, 40)
            }
        }
        .task {
            do {
                try await cameraService.start()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .onDisappear {
            cameraService.stop()
        }
    }

    // MARK: - Step 2: Review

    private var reviewStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let image = capturedPhotoImage {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 400)
                        .cornerRadius(16)
                        .shadow(radius: 8)
                }

                VStack(spacing: 12) {
                    Text("Good to go?")
                        .font(.headline)

                    Text("We'll analyze this photo to match items in your wardrobe.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                // Action buttons
                VStack(spacing: 12) {
                    // Auto-match (Approach B)
                    Button {
                        Task { await runMatching() }
                    } label: {
                        Label("Auto-Match from Wardrobe", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }
                    .disabled(isProcessing)

                    // Manual tag (Approach A)
                    Button {
                        showManualTagMode = true
                    } label: {
                        Label("Manually Tag Items", systemImage: "hand.tap")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.secondary.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                    }

                    // Retake
                    Button {
                        retakePhoto()
                    } label: {
                        Label("Retake", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .overlay {
            if isProcessing {
                ProgressView("Analyzing clothing...")
                    .padding()
                    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .sheet(isPresented: $showManualTagMode) {
            ManualTagSheet(
                selectedItems: $selectedManualItems,
                onConfirm: {
                    Task { await confirmManualTag() }
                }
            )
        }
    }

    // MARK: - Step 3: Match

    private var matchStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if matches.isEmpty {
                    ContentUnavailableView(
                        "No Matches Found",
                        systemImage: "magnifyingglass",
                        description: Text("No wardrobe items matched with sufficient confidence. Try tagging manually or add this item to your wardrobe.")
                    )
                } else {
                    Text("Select items you're wearing:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    LazyVStack(spacing: 8) {
                        ForEach(matches) { match in
                            MatchCandidateRow(
                                match: match,
                                isSelected: confirmedMatches.contains(where: { $0.id == match.id }),
                                onToggle: { toggleMatch(match) }
                            )
                        }
                    }
                    .padding(.horizontal)
                }

                // Confirm button
                if !confirmedMatches.isEmpty {
                    Button {
                        Task { await confirmOutfit() }
                    } label: {
                        Label(
                            "Confirm Outfit (\(confirmedMatches.count) items)",
                            systemImage: "checkmark.circle.fill"
                        )
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        .bold()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .padding(.vertical)
        }
        .overlay {
            if isProcessing {
                ProgressView("Matching...")
                    .padding()
                    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Step 4: Summary

    private var summaryStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Outfit photo
                if let image = capturedPhotoImage {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                        .padding(.horizontal)
                }

                // Matched items list
                if let summary = outfitService.todayOutfit {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Text("Outfit Recorded")
                                .font(.headline)
                            Spacer()
                            Text(summaryVM.outfitDateString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(summaryVM.matchedItems) { item in
                            SummaryItemRow(item: item)
                        }
                    }
                    .padding(.horizontal)
                }

                // Laundry alerts
                if summaryVM.laundryAlertCount > 0 {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("\(summaryVM.laundryAlertCount) item(s) need laundry!")
                            .foregroundStyle(.red)
                            .bold()
                    }
                    .padding()
                    .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Actions

    private func capturePhoto() async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            let captured = try await cameraService.capturePhoto()
            self.capturedPhotoData = captured.originalData

            // Convert to Image for display
            if let nsImage = NSImage(data: captured.originalData) {
                self.capturedPhotoImage = Image(nsImage: nsImage)
            }

            cameraService.stop()
            flowStep = .reviewing
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func retakePhoto() {
        capturedPhotoData = nil
        capturedPhotoImage = nil
        matches = []
        confirmedMatches = []
        flowStep = .camera
    }

    private func runMatching() async {
        guard let photoData = capturedPhotoData else { return }

        isProcessing = true
        defer { isProcessing = false }

        do {
            matches = try await outfitService.matchClothing(in: photoData)
            confirmedMatches = []
            flowStep = .matching
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func confirmManualTag() async {
        showManualTagMode = false
        guard let photoData = capturedPhotoData else { return }

        isProcessing = true
        defer { isProcessing = false }

        let manualItems = selectedManualItems.map { uuid in
            WardrobeItemInfo(id: uuid, name: "Item", category: "Unknown", thumbnailData: nil)
        }

        do {
            try await outfitService.manualTagOutfit(selectedItems: manualItems, photoData: photoData)
            summaryVM.load()
            flowStep = .summary
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleMatch(_ match: ClothingMatch) {
        if let index = confirmedMatches.firstIndex(where: { $0.id == match.id }) {
            confirmedMatches.remove(at: index)
        } else {
            confirmedMatches.append(match)
        }
    }

    private func confirmOutfit() async {
        guard let photoData = capturedPhotoData else { return }

        isProcessing = true
        defer { isProcessing = false }

        do {
            try await outfitService.confirmOutfit(
                confirmedMatches: confirmedMatches,
                photoData: photoData
            )
            summaryVM.load()
            flowStep = .summary
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Match Candidate Row

private struct MatchCandidateRow: View {
    let match: ClothingMatch
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .green : .secondary)

                // Item info
                VStack(alignment: .leading, spacing: 4) {
                    Text(match.name)
                        .font(.headline)
                    Text(match.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Confidence
                VStack {
                    Text("\(Int(match.confidence * 100))%")
                        .font(.subheadline.bold())
                        .foregroundStyle(confidenceColor)
                    Text("match")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.green.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.green : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var confidenceColor: Color {
        if match.confidence >= 0.9 { return .green }
        if match.confidence >= 0.8 { return .yellow }
        return .orange
    }
}

// MARK: - Summary Item Row

private struct SummaryItemRow: View {
    let item: TodaySummaryViewModel.ItemRow

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.categoryIcon)
                .font(.title3)
                .foregroundStyle(item.urgencyColor)
                .frame(width: 32, height: 32)
                .background(item.urgencyColor.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline.bold())
                Text(item.wearsRemainingText)
                    .font(.caption)
                    .foregroundStyle(item.urgencyColor)
            }

            Spacer()

            // Progress bar
            VStack(alignment: .trailing, spacing: 4) {
                ProgressView(value: item.progress)
                    .tint(item.urgencyColor)
                    .frame(width: 80)
                Text("\(item.wearCount)/\(item.maxWears)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Manual Tag Sheet

private struct ManualTagSheet: View {
    @Binding var selectedItems: Set<UUID>
    let onConfirm: () -> Void

    // Placeholder — in production, this would fetch from the wardrobe repository
    private let sampleItems: [WardrobeItemInfo] = [
        WardrobeItemInfo(id: UUID(), name: "Blue T-Shirt", category: "Tops", thumbnailData: nil),
        WardrobeItemInfo(id: UUID(), name: "Black Jeans", category: "Bottoms", thumbnailData: nil),
        WardrobeItemInfo(id: UUID(), name: "White Sneakers", category: "Shoes", thumbnailData: nil),
    ]

    var body: some View {
        NavigationStack {
            List(sampleItems) { item in
                HStack {
                    Text(item.name)
                    Spacer()
                    if selectedItems.contains(item.id) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedItems.contains(item.id) {
                        selectedItems.remove(item.id)
                    } else {
                        selectedItems.insert(item.id)
                    }
                }
            }
            .navigationTitle("Tag Items")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { /* dismiss */ }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm (\(selectedItems.count))") {
                        onConfirm()
                    }
                    .disabled(selectedItems.isEmpty)
                    .bold()
                }
            }
        }
        .frame(minWidth: 400, idealHeight: 500)
    }
}
