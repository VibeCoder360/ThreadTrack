// ExportView.swift
// ThreadTrack — Analytics Engine
//
// Share sheet wrapper + format picker for exporting analytics data.
// iOS 16+ using UIActivityViewController via UIViewControllerRepresentable.

import SwiftUI
import UIKit

// MARK: - Export Options View

public struct ExportView: View {
    let analyticsService: AnalyticsService
    @State private var isSharing = false
    @State private var sharedItems: [Any]?
    @State private var exportFormat: DataExportService.ExportFormat = .json
    @State private var selectedSection: ExportableSection? = nil
    @State private var showFullReport = true

    public init(analyticsService: AnalyticsService) {
        self.analyticsService = analyticsService
    }

    public var body: some View {
        Form {
            // MARK: Format Picker
            Section {
                Picker("Format", selection: $exportFormat) {
                    ForEach(DataExportService.ExportFormat.allCases, id: \.self) { fmt in
                        Text(fmt.rawValue).tag(fmt)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Export Format")
            }

            // MARK: Scope
            Section {
                Toggle("Full Analytics Report", isOn: $showFullReport)
                    .tint(.blue)

                if !showFullReport {
                    Picker("Section", selection: $selectedSection) {
                        Text("Cost Per Wear").tag(ExportableSection.costPerWear as ExportableSection?)
                        Text("Wear Frequency").tag(ExportableSection.wearFrequency as ExportableSection?)
                        Text("Category Breakdown").tag(ExportableSection.categoryBreakdown as ExportableSection?)
                        Text("Laundry Stats").tag(ExportableSection.laundry as ExportableSection?)
                        Text("Outfit Variety").tag(ExportableSection.outfitVariety as ExportableSection?)
                    }
                }
            } header: {
                Text("Scope")
            }

            // MARK: Export Button
            Section {
                Button {
                    performExport()
                } label: {
                    HStack {
                        Spacer()
                        Label("Export & Share", systemImage: "square.and.arrow.up")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .disabled(analyticsService.snapshot == nil)
            }
        }
        .navigationTitle("Export Data")
        .sheet(isPresented: $isSharing) {
            if let items = sharedItems {
                ActivitySheet(activityItems: items)
            }
        }
    }

    // MARK: Export Logic

    private func performExport() {
        do {
            let data: Data
            let filename: String

            if showFullReport {
                data = try analyticsService.exportFullReport(format: exportFormat)
                filename = "ThreadTrack_FullAnalytics"
            } else if let section = selectedSection {
                data = try analyticsService.export(section: section, format: exportFormat)
                filename = "ThreadTrack_\(sectionLabel(section))"
            } else {
                data = try analyticsService.exportFullReport(format: exportFormat)
                filename = "ThreadTrack_FullAnalytics"
            }

            let url = try analyticsService.saveReport(format: exportFormat, filename: filename)
            self.sharedItems = [url]
            self.isSharing = true
        } catch {
            // In production, surface via alert. For now, silently fail.
        }
    }

    private func sectionLabel(_ section: ExportableSection) -> String {
        switch section {
        case .costPerWear:      return "CostPerWear"
        case .wearFrequency:    return "WearFrequency"
        case .categoryBreakdown: return "CategoryBreakdown"
        case .laundry:           return "LaundryStats"
        case .outfitVariety:     return "OutfitVariety"
        }
    }
}

// MARK: - UIActivityViewController Bridge

struct ActivitySheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in
            dismiss()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
