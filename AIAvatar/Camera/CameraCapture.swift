import AVFoundation
import Combine
import CoreMedia
import CoreVideo
import Foundation

enum CameraPermission: Equatable, Sendable {
    case unknown, requesting, authorized, denied, restricted
}

enum CapturePhase: Equatable, Sendable {
    case idle, starting, live, paused, noCamera, interrupted, waitingForFrames, failed

    var label: String {
        switch self {
        case .idle: return "Camera not started"
        case .starting: return "Starting camera"
        case .live: return "Live"
        case .paused: return "Camera stopped"
        case .noCamera: return "No camera available"
        case .interrupted: return "Camera interrupted"
        case .waitingForFrames: return "Waiting for camera video"
        case .failed: return "Camera unavailable"
        }
    }
}

struct CameraSnapshot: Equatable, Sendable {
    var permission: CameraPermission = .unknown
    var phase: CapturePhase = .idle
    var devices: [CameraDevice] = []
    var selectedDevice: CameraDevice?
    var isAutomaticSelection = true
    var wantsRunning = false
    var errorMessage: String?
    var metrics = CaptureMetrics()
}

// Session configuration, selection, frame callbacks and the watchdog share one serial queue.
// SwiftUI receives immutable snapshots on the main queue; it never starts or stops the session.
final class CameraCapture: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published private(set) var snapshot = CameraSnapshot()
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "dev.vero2002.aiavatar.capture", qos: .userInitiated)
    private let videoOutput = AVCaptureVideoDataOutput()
    private let discovery = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.continuityCamera, .builtInWideAngleCamera, .external, .deskViewCamera],
        mediaType: .video,
        position: .unspecified
    )
    private var current = CameraSnapshot()
    private var policy = CameraSelectionPolicy()
    private var activeInput: AVCaptureDeviceInput?
    private var observations: [NSObjectProtocol] = []
    private var discoveryObservation: NSKeyValueObservation?
    private var watchdog: DispatchSourceTimer?
    private var frameRate = FrameRateMeter()
    private var lastFrameTime: TimeInterval?
    private var sessionStartTime: TimeInterval?
    private var runtimeRecoveryAttempted = false
    private var isInterrupted = false

    override init() {
        super.init()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        observeDevicesAndSession()
        let timer = DispatchSource.makeTimerSource(queue: sessionQueue)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in self?.checkFrameDelivery() }
        timer.resume()
        watchdog = timer
    }

    deinit {
        watchdog?.cancel()
        discoveryObservation?.invalidate()
        observations.forEach { NotificationCenter.default.removeObserver($0) }
        videoOutput.setSampleBufferDelegate(nil, queue: nil)
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            current.wantsRunning = true
            runtimeRecoveryAttempted = false
            checkPermissionAndRefresh()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            current.wantsRunning = false
            if session.isRunning { session.stopRunning() }
            resetMetrics()
            current.phase = current.selectedDevice == nil ? .noCamera : .paused
            publish()
        }
    }

    func refreshDevices() {
        sessionQueue.async { [weak self] in self?.checkPermissionAndRefresh() }
    }

    func selectDevice(id: String) {
        sessionQueue.async { [weak self] in
            guard let self, current.permission == .authorized,
                  let device = discovery.devices.first(where: { $0.uniqueID == id }) else { return }
            let oldPolicy = policy
            policy.select(id)
            if configure(device) {
                current.isAutomaticSelection = false
            } else {
                policy = oldPolicy
            }
            publish()
        }
    }

    func useAutomaticSelection() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            policy.useAutomaticSelection()
            current.isAutomaticSelection = true
            checkPermissionAndRefresh()
        }
    }

    private func checkPermissionAndRefresh() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            current.permission = .authorized
            refreshOnSessionQueue()
        case .notDetermined:
            guard current.permission != .requesting else { return }
            current.permission = .requesting
            publish()
            AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
                self?.sessionQueue.async { [weak self] in self?.checkPermissionAndRefresh() }
            }
        case .denied:
            releaseCamera()
            current.permission = .denied
            current.devices = []
            current.errorMessage = nil
            publish()
        case .restricted:
            releaseCamera()
            current.permission = .restricted
            current.devices = []
            current.errorMessage = nil
            publish()
        @unknown default:
            releaseCamera()
            current.permission = .restricted
            publish()
        }
    }

    private func refreshOnSessionQueue() {
        let actualDevices = discovery.devices.filter { $0.isConnected }
        current.devices = CameraDevice.sorted(actualDevices.map(CameraDevice.init))
        current.isAutomaticSelection = policy.isAutomatic
        if let activeInput, !actualDevices.contains(where: { $0.uniqueID == activeInput.device.uniqueID }) {
            releaseCamera()
        }
        guard let preferred = policy.preferredDevice(in: current.devices),
              let device = actualDevices.first(where: { $0.uniqueID == preferred.id }) else {
            releaseCamera()
            current.phase = .noCamera
            current.errorMessage = nil
            publish()
            return
        }
        if activeInput?.device.uniqueID != preferred.id || activeInput?.device.isConnected != true {
            _ = configure(device)
        } else if current.wantsRunning && !session.isRunning && !isInterrupted {
            startSession()
        }
        publish()
    }

    @discardableResult
    private func configure(_ device: AVCaptureDevice) -> Bool {
        if activeInput?.device.uniqueID == device.uniqueID && device.isConnected {
            if current.wantsRunning && !session.isRunning { startSession() }
            return true
        }
        let newInput: AVCaptureDeviceInput
        do {
            newInput = try AVCaptureDeviceInput(device: device)
        } catch {
            configurationFailed("Could not open \(device.localizedName): \(error.localizedDescription)")
            return false
        }

        let previousInput = activeInput
        session.beginConfiguration()
        if let previousInput { session.removeInput(previousInput) }
        guard session.canAddInput(newInput) else {
            restoreInput(previousInput)
            session.commitConfiguration()
            configurationFailed("The camera could not be attached to the capture session.")
            return false
        }
        session.addInput(newInput)
        if !session.outputs.contains(where: { $0 === videoOutput }) {
            guard session.canAddOutput(videoOutput) else {
                session.removeInput(newInput)
                restoreInput(previousInput)
                session.commitConfiguration()
                configurationFailed("The camera does not support video frame output.")
                return false
            }
            session.addOutput(videoOutput)
        }
        if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        } else if session.canSetSessionPreset(.medium) {
            session.sessionPreset = .medium
        }
        let formats = videoOutput.availableVideoPixelFormatTypes
        let preferredFormats = [kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                                kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                                kCVPixelFormatType_32BGRA]
        if let format = preferredFormats.first(where: { formats.contains($0) }) {
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: format]
        }
        session.commitConfiguration()
        activeInput = newInput
        current.selectedDevice = CameraDevice(device)
        current.errorMessage = nil
        resetMetrics()
        configureFrameRate(device)
        if current.wantsRunning {
            startSession()
        } else {
            current.phase = .paused
        }
        return true
    }

    private func restoreInput(_ input: AVCaptureDeviceInput?) {
        if let input, input.device.isConnected, session.canAddInput(input) {
            session.addInput(input)
            activeInput = input
        } else {
            activeInput = nil
            current.selectedDevice = nil
            resetMetrics()
        }
    }

    private func configureFrameRate(_ device: AVCaptureDevice) {
        guard device.activeFormat.videoSupportedFrameRateRanges.contains(where: {
            $0.minFrameRate <= 30 && $0.maxFrameRate >= 30
        }) else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            let duration = CMTime(value: 1, timescale: 30)
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
        } catch {
            // The camera's native frame rate remains usable; report the measured delivery rate.
            current.errorMessage = "Camera opened, but 30 FPS could not be requested: \(error.localizedDescription)"
        }
    }

    private func startSession() {
        guard !isInterrupted else {
            current.phase = .interrupted
            publish()
            return
        }
        current.phase = .starting
        current.errorMessage = nil
        sessionStartTime = ProcessInfo.processInfo.systemUptime
        publish()
        if !session.isRunning { session.startRunning() }
        if !session.isRunning {
            current.phase = .failed
            current.errorMessage = "The camera session could not start. Check whether another app is using the camera."
        }
    }

    private func releaseCamera() {
        if session.isRunning { session.stopRunning() }
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }
        session.commitConfiguration()
        activeInput = nil
        current.selectedDevice = nil
        current.phase = .noCamera
        resetMetrics()
    }

    private func configurationFailed(_ message: String) {
        current.errorMessage = message
        if activeInput == nil || !session.isRunning { current.phase = .failed }
        publish()
    }

    private func resetMetrics() {
        frameRate.reset()
        lastFrameTime = nil
        sessionStartTime = nil
        current.metrics = CaptureMetrics()
    }

    private func publish() {
        let value = current
        DispatchQueue.main.async { [weak self] in self?.snapshot = value }
    }

    private func observeDevicesAndSession() {
        discoveryObservation = discovery.observe(\.devices, options: [.new]) { [weak self] _, _ in
            self?.refreshDevices()
        }
        let center = NotificationCenter.default
        for name in [AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification] {
            observations.append(center.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
                self?.refreshDevices()
            })
        }
        observations.append(center.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: nil
        ) { [weak self] _ in
            self?.sessionQueue.async { [weak self] in
                guard let self else { return }
                isInterrupted = true
                guard current.wantsRunning else { return }
                current.phase = .interrupted
                current.metrics.framesPerSecond = 0
                publish()
            }
        })
        observations.append(center.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil
        ) { [weak self] _ in
            self?.sessionQueue.async { [weak self] in
                guard let self else { return }
                isInterrupted = false
                resetMetrics()
                current.phase = current.wantsRunning ? .starting : .paused
                sessionStartTime = ProcessInfo.processInfo.systemUptime
                checkPermissionAndRefresh()
            }
        })
        observations.append(center.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil
        ) { [weak self] notification in
            let error = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError
            self?.sessionQueue.async { [weak self] in self?.handleRuntimeError(error) }
        })
    }

    private func handleRuntimeError(_ error: NSError?) {
        guard current.wantsRunning else { return }
        if !runtimeRecoveryAttempted {
            runtimeRecoveryAttempted = true
            releaseCamera()
            isInterrupted = false
            refreshOnSessionQueue()
        } else {
            current.phase = .failed
            current.errorMessage = error?.localizedDescription ?? "The camera session reported an error."
            current.metrics.framesPerSecond = 0
            publish()
        }
    }

    private func checkFrameDelivery() {
        guard current.wantsRunning, session.isRunning, !isInterrupted,
              current.phase != .failed,
              let reference = lastFrameTime ?? sessionStartTime else { return }
        if ProcessInfo.processInfo.systemUptime - reference > 3 && current.phase != .waitingForFrames {
            current.phase = .waitingForFrames
            current.metrics.framesPerSecond = 0
            publish()
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard current.wantsRunning, !isInterrupted,
              CMSampleBufferDataIsReady(sampleBuffer),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let now = ProcessInfo.processInfo.systemUptime
        lastFrameTime = now
        let changedPhase = current.phase != .live
        current.phase = .live
        if let metrics = frameRate.recordFrame(
            at: now, width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer)
        ) {
            current.metrics = metrics
            publish()
        } else if changedPhase {
            publish()
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        frameRate.recordDrop()
    }
}
