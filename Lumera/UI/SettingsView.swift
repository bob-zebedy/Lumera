import SwiftUI
import CoreLocation

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    var appBuild: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}

struct SettingsView: View {
    @Bindable var settings: Settings
    let availableLenses: [Lens]
    let zoomFactors: [Lens: Double]
    let locationAuthStatus: CLAuthorizationStatus
    let isCameraAvailable: Bool
    let onChange: () -> Void
    @Environment(\.dismiss) private var dismiss

    private static let privacyPolicyURL = "https://github.com/bob-zebedy/Lumera/blob/main/PRIVACY.md"
    private static let contactEmail = "lumera@zabrian.com"
    private static let copyrightLine = "© 2026 Bob"

    private var locationDenied: Bool {
        locationAuthStatus == .denied || locationAuthStatus == .restricted
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("HDR", isOn: $settings.useComputationalPhotography)
                        .onChange(of: settings.useComputationalPhotography) { _, _ in onChange() }
                        .disabled(!isCameraAvailable)
                    Toggle("Face Detection", isOn: $settings.objectDetectionEnabled)
                        .onChange(of: settings.objectDetectionEnabled) { _, _ in onChange() }
                    Toggle("Record Location in Photos", isOn: $settings.embedLocation)
                        .disabled(locationDenied)
                        .onChange(of: settings.embedLocation) { _, _ in onChange() }
                } header: {
                    Text("Photo")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("HDR enables Smart HDR / Deep Fusion / Night Mode.")
                        if locationDenied {
                            Text("Location permission denied")
                        }
                    }
                }

                Section {
                    Toggle("Show Grid", isOn: $settings.showGrid)
                    Toggle("Haptic Feedback", isOn: $settings.hapticFeedbackEnabled)
                } header: {
                    Text("Interface")
                }

                Section {
                    Picker("Format", selection: $settings.defaultFormat) {
                        ForEach(PhotoFormat.allCases) { format in
                            Text(format.displayLabel).tag(format)
                        }
                    }
                    .disabled(!isCameraAvailable)
                    Picker("Lens", selection: $settings.defaultLens) {
                        ForEach(availableLenses.isEmpty ? Lens.allCases : availableLenses) { lens in
                            Text("\(lens.dynamicLabel(zoomFactor: zoomFactors[lens]))  \(lens.longName)").tag(lens)
                        }
                    }
                    .disabled(!isCameraAvailable)
                    Picker("Flash", selection: $settings.defaultFlashMode) {
                        ForEach(FlashMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .disabled(!isCameraAvailable)
                    Picker("Aspect Ratio", selection: $settings.defaultAspectRatio) {
                        ForEach(AspectRatio.allCases) { ratio in
                            Text(ratio.label).tag(ratio)
                        }
                    }
                    Toggle("Manual Mode", isOn: $settings.panelExpandedAtLaunch)
                } header: {
                    Text("Defaults")
                } footer: {
                    Text("Applied next launch")
                }

                Section {
                    Button {
                        settings.hasShownOnboarding = false
                        dismiss()
                    } label: {
                        HStack {
                            Label("Replay Tutorial", systemImage: "graduationcap")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.appVersion)
                    LabeledContent("Build Version", value: Bundle.main.appBuild)
                    if let privacyURL = URL(string: Self.privacyPolicyURL) {
                        Link(destination: privacyURL) {
                            HStack {
                                Text("Privacy Policy")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    if let mailURL = URL(string: "mailto:\(Self.contactEmail)") {
                        Link(destination: mailURL) {
                            HStack {
                                Text("Contact")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(Self.contactEmail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Text(Self.copyrightLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
