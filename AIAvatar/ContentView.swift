import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var camera = CameraCapture()
    @Environment(\.scenePhase) private var scenePhase

    private var state: CameraSnapshot { camera.snapshot }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("AI Avatar").font(.title2.weight(.semibold))
                Spacer()
                Circle().fill(state.phase == .live ? Color.green : Color.secondary).frame(width: 7, height: 7)
                Text(state.phase.label).foregroundStyle(.secondary)
            }
            .padding(16)

            Divider()

            HStack(spacing: 10) {
                Picker("Camera", selection: Binding(
                    get: { state.selectedDevice?.id ?? "" },
                    set: { camera.selectDevice(id: $0) }
                )) {
                    if state.selectedDevice == nil { Text("Select camera").tag("") }
                    ForEach(state.devices) { device in
                        Text("\(device.name) (\(device.kind.label))").tag(device.id)
                    }
                }
                .frame(maxWidth: 440)
                .disabled(state.permission != .authorized || state.devices.isEmpty)

                Button { camera.refreshDevices() } label: { Image(systemName: "arrow.clockwise") }
                    .help("Refresh cameras")

                Toggle("Automatic", isOn: Binding(
                    get: { state.isAutomaticSelection },
                    set: { automatic in
                        if automatic {
                            camera.useAutomaticSelection()
                        } else if let id = state.selectedDevice?.id {
                            camera.selectDevice(id: id)
                        }
                    }
                ))
                .toggleStyle(.checkbox)
                .disabled(state.devices.isEmpty)
                .help("Prefer iPhone Continuity Camera when available")

                Spacer(minLength: 0)

                Button {
                    if state.wantsRunning { camera.stop() } else { camera.start() }
                } label: {
                    Label(state.wantsRunning ? "Stop" : "Start", systemImage: state.wantsRunning ? "stop.fill" : "play.fill")
                }
                .disabled(state.permission == .requesting || state.permission == .denied || state.permission == .restricted)
            }
            .padding(12)

            ProcessingControls(processor: camera.processor)

            ZStack {
                Color.black
                CameraPreviewView(session: camera.session)
                    .opacity(state.phase == .live ? 1 : 0)
                ProcessedPreview(processor: camera.processor, visible: state.phase == .live)
                if state.phase != .live {
                    VStack(spacing: 14) {
                        Image(systemName: "video").font(.system(size: 32)).foregroundStyle(.white.opacity(0.7))
                        Text(previewMessage).font(.title3).foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        if state.permission == .denied {
                            Button("Open Camera Settings") { openCameraSettings() }
                        }
                        if state.permission == .requesting || state.phase == .starting {
                            ProgressView().controlSize(.small)
                        }
                    }
                    .padding(24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Live camera preview")

            if let error = state.errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error).textSelection(.enabled)
                    Spacer(minLength: 0)
                    Button { camera.refreshDevices() } label: { Image(systemName: "arrow.clockwise") }
                        .help("Retry camera")
                }
                .foregroundStyle(.red)
                .padding(12)
            }

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.selectedDevice?.name ?? "No camera selected").fontWeight(.medium)
                    if let device = state.selectedDevice {
                        Text(device.kind.label).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if state.metrics.width > 0 {
                    Text("\(state.metrics.width) x \(state.metrics.height)")
                    Text(String(format: "%.1f FPS", state.metrics.framesPerSecond))
                    Text("\(state.metrics.droppedFrames) dropped")
                }
            }
            .font(.callout.monospacedDigit())
            .padding(12)
        }
        .frame(minWidth: 760, minHeight: 500)
        .onAppear { camera.start(); camera.processor.prepare() }
        .onDisappear { camera.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { camera.refreshDevices() }
        }
    }

    private var previewMessage: String {
        switch state.permission {
        case .unknown, .requesting: return "Requesting camera access"
        case .denied: return "Camera access is disabled"
        case .restricted: return "Camera access is restricted on this Mac"
        case .authorized: return state.phase.label
        }
    }

    private func openCameraSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct ProcessingControls: View {
    @ObservedObject var processor: FrameProcessor

    var body: some View {
        HStack(spacing: 12) {
            Picker("Video", selection: Binding(get: { processor.snapshot.active }, set: { processor.setEnabled($0) })) {
                Text("Original").tag(false)
                Text("AI Identity").tag(true)
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 180).disabled(!processor.snapshot.ready)
            Button { importReference() } label: { Image(systemName: "photo.badge.plus") }
                .help("Import the fixed identity reference")
            Text(processor.snapshot.status).font(.callout).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if processor.snapshot.image != nil && processor.snapshot.active {
                Text(String(format: "AI %.1f FPS | %.0f ms | %.0f MB GPU peak", processor.snapshot.framesPerSecond, processor.snapshot.milliseconds, processor.snapshot.memoryMB))
                    .font(.caption.monospacedDigit())
            }
        }
        .padding(.horizontal, 12).padding(.bottom, 12)
    }

    private func importReference() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            if response == .OK, let url = panel.url { processor.importReference(url) }
        }
    }
}

private struct ProcessedPreview: View {
    @ObservedObject var processor: FrameProcessor
    let visible: Bool
    var body: some View {
        if visible, processor.snapshot.active, let image = processor.snapshot.image {
            Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity).background(.black)
        }
    }
}
