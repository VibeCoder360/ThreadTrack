import SwiftUI

// MARK: - SettingsView
struct SettingsView: View {
    @AppStorage("notificationEnabled") private var notificationEnabled = true
    @AppStorage("laundryReminderTime") private var laundryReminderTime = "09:00"
    @AppStorage("dailyReminderEnabled") private var dailyReminderEnabled = false
    @AppStorage("defaultLaundryThreshold") private var defaultLaundryThreshold = 3
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false

    @State private var showingExport = false
    @State private var showingResetAlert = false

    var body: some View {
        NavigationStack {
            Form {
                // Notifications Section
                Section {
                    Toggle("Laundry Reminders", isOn: $notificationEnabled)

                    if notificationEnabled {
                        HStack {
                            Text("Reminder Time")
                            Spacer()
                            Text(laundryReminderTime)
                                .foregroundColor(TTColorTheme.secondaryText)
                        }

                        Toggle("Daily Outfit Reminder", isOn: $dailyReminderEnabled)
                    }
                } header: {
                    Text("Notifications")
                }

                // Defaults Section
                Section {
                    Stepper("Default laundry threshold: \(defaultLaundryThreshold) wears",
                            value: $defaultLaundryThreshold, in: 1...10)

                    Toggle("Dark Mode", isOn: $darkModeEnabled)
                } header: {
                    Text("Defaults")
                }

                // Data Section
                Section {
                    Button {
                        exportData()
                    } label: {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive) {
                        showingResetAlert = true
                    } label: {
                        Label("Reset All Data", systemImage: "trash")
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Export your wardrobe data as JSON. Reset will delete all items, outfits, and laundry history.")
                }

                // About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(TTColorTheme.secondaryText)
                    }
                    HStack {
                        Text("Built with")
                        Spacer()
                        Text("SwiftUI + SwiftData")
                            .foregroundColor(TTColorTheme.secondaryText)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .alert("Reset All Data?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    // Reset handled by the app's data controller
                }
            } message: {
                Text("This action cannot be undone. All wardrobe items, outfits, and laundry history will be permanently deleted.")
            }
        }
    }

    private func exportData() {
        // Export logic placeholder — the data controller will provide the actual export
        // This is wired to a ShareLink or file export in the full app
    }
}

// MARK: - Notification Settings Detail
struct NotificationSettingsView: View {
    @AppStorage("notificationEnabled") private var notificationEnabled = true
    @AppStorage("laundryReminderTime") private var laundryReminderTime = "09:00"
    @AppStorage("dailyReminderEnabled") private var dailyReminderEnabled = false

    var body: some View {
        Form {
            Toggle("Enable Notifications", isOn: $notificationEnabled)

            if notificationEnabled {
                Section("Laundry Reminders") {
                    Toggle("Laundry Due Alerts", isOn: .constant(true))

                    HStack {
                        Text("Reminder Time")
                        Spacer()
                        Text(laundryReminderTime)
                            .foregroundColor(TTColorTheme.secondaryText)
                    }
                }

                Section("Daily Reminders") {
                    Toggle("Evening Outfit Log", isOn: $dailyReminderEnabled)
                }
            }
        }
        .navigationTitle("Notifications")
    }
}

// MARK: - Threshold Settings
struct ThresholdSettingsView: View {
    @AppStorage("defaultLaundryThreshold") private var defaultLaundryThreshold = 3

    var body: some View {
        Form {
            Section("Default Laundry Threshold") {
                Stepper("Wears before laundry: \(defaultLaundryThreshold)",
                        value: $defaultLaundryThreshold, in: 1...10)

                Text("This sets the default for new items. Individual items can have different thresholds.")
                    .font(.caption)
                    .foregroundColor(TTColorTheme.secondaryText)
            }

            Section("Threshold Guide") {
                thresholdRow(wears: 1, description: "Daily items (underwear, socks)")
                thresholdRow(wears: 2, description: "Frequent wear (t-shirts, gym clothes)")
                thresholdRow(wears: 3, description: "Regular items (shirts, pants)")
                thresholdRow(wears: 5, description: "Light wear (jackets, outerwear)")
                thresholdRow(wears: 10, description: "Rarely washed (formal wear, coats)")
            }
        }
        .navigationTitle("Thresholds")
    }

    private func thresholdRow(wears: Int, description: String) -> some View {
        HStack {
            Text("\(wears)x")
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(width: 40)
            Text(description)
                .font(.caption)
                .foregroundColor(TTColorTheme.secondaryText)
        }
    }
}
