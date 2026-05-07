import SwiftUI

struct PackageInputView: View {
    @Environment(UserSettings.self) private var settings
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var package = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Android Log Filter")
                .font(.headline)

            Text("Enter a package name to filter logs, or leave empty to capture all logs.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("com.example.app", text: $package)
                .textFieldStyle(.roundedBorder)
                .onAppear { package = settings.lastAndroidPackage }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Start Recording") {
                    settings.lastAndroidPackage = package
                    dismiss()
                    Task { await appState.startRecording(package: package.isEmpty ? nil : package) }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}
