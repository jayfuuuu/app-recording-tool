import SwiftUI

struct SetupView: View {
    @Environment(UserSettings.self) private var settings
    @State private var viewModel = SetupViewModel()
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
                Text("MobileRecorder Setup")
                    .font(.title2.bold())
                Text("Check and install required tools")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            // Tool rows
            VStack(spacing: 12) {
                toolRow(
                    name: "Homebrew",
                    icon: "mug",
                    status: viewModel.brewStatus,
                    installAction: nil,
                    browseAction: nil
                )

                toolRow(
                    name: "adb (Android)",
                    icon: "androidlogo",
                    status: viewModel.adbStatus,
                    installAction: viewModel.brewStatus.isFound && !viewModel.adbStatus.isFound ? {
                        Task { await viewModel.installAdb() }
                    } : nil,
                    browseAction: {
                        browseForTool { path in viewModel.setAdbPath(path) }
                    }
                )

                toolRow(
                    name: "idb (iOS)",
                    icon: "apple.logo",
                    status: viewModel.idbStatus,
                    installAction: viewModel.brewStatus.isFound && !viewModel.idbStatus.isFound ? {
                        Task { await viewModel.installIdb() }
                    } : nil,
                    browseAction: {
                        browseForTool { path in viewModel.setIdbPath(path) }
                    }
                )
            }
            .padding(16)

            // Install log
            if !viewModel.installLog.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Install Log")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(viewModel.installLog)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("log-bottom")
                        }
                        .onChange(of: viewModel.installLog) {
                            proxy.scrollTo("log-bottom", anchor: .bottom)
                        }
                    }
                    .frame(height: 120)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            Spacer()

            Divider()

            // Bottom buttons
            HStack {
                Button("Skip") {
                    settings.setupCompleted = true
                    onDismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button("Done") {
                    viewModel.saveSettings(settings)
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isInstalling)
            }
            .padding(16)
        }
        .frame(width: 480, height: 420)
        .onAppear {
            viewModel.checkAll()
        }
    }

    @ViewBuilder
    private func toolRow(
        name: String,
        icon: String,
        status: ToolStatus,
        installAction: (() -> Void)?,
        browseAction: (() -> Void)?
    ) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 10, height: 10)

            Image(systemName: icon)
                .frame(width: 20)

            Text(name)
                .frame(width: 100, alignment: .leading)

            Text(status.displayText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if let browse = browseAction {
                Button("Browse") {
                    browse()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if let action = installAction {
                Button("Install") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.isInstalling)
            }
        }
    }

    private func browseForTool(onSelect: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Select the tool executable"
        panel.prompt = "Select"
        panel.directoryURL = URL(fileURLWithPath: "/usr/local/bin")
        if panel.runModal() == .OK, let url = panel.url {
            onSelect(url.path)
        }
    }

    private func statusColor(_ status: ToolStatus) -> Color {
        switch status {
        case .found, .installed: return .green
        case .notFound: return .red
        case .checking, .installing: return .orange
        case .failed: return .red
        }
    }
}
