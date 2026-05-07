import SwiftUI

struct LogViewerView: View {
    @State var logStream = LogStreamService()
    let device: Device

    @State private var filterText = ""
    @State private var autoScroll = true

    var filteredLines: [String] {
        if filterText.isEmpty {
            return logStream.lines
        }
        return logStream.lines.filter { $0.localizedCaseInsensitiveContains(filterText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Image(systemName: logStream.isStreaming ? "circle.fill" : "circle")
                    .foregroundStyle(logStream.isStreaming ? .green : .gray)
                    .font(.caption)

                Text(device.displayName)
                    .font(.headline)

                Spacer()

                TextField("Filter...", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)

                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.checkbox)

                Button("Clear") { logStream.clear() }

                if logStream.isStreaming {
                    Button("Stop") { logStream.stop() }
                } else {
                    Button("Start") { startStream() }
                }
            }
            .padding(8)

            Divider()

            // Log content
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(filteredLines.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 1)
                                .background(index % 2 == 0 ? Color.clear : Color.gray.opacity(0.05))
                                .id(index)
                        }
                    }
                }
                .onChange(of: filteredLines.count) {
                    if autoScroll, let last = filteredLines.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
        .frame(minWidth: 700, minHeight: 400)
        .onAppear { startStream() }
        .onDisappear { logStream.stop() }
    }

    private func startStream() {
        switch device.platform {
        case .android: logStream.startAndroidStream(device: device)
        case .ios: logStream.startIOSStream(device: device)
        }
    }
}
