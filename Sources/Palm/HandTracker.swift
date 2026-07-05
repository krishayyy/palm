import Foundation
import AVFoundation
import Vision
import CoreGraphics

struct HandPointerState: Equatable {
    var normalizedPosition: CGPoint // (0,0) bottom-left .. (1,1) top-right, mirrored
    var isPinching: Bool
    var pinchDistance: CGFloat
    var label: String // "L" or "R"
}

@MainActor
protocol HandTrackerDelegate: AnyObject {
    func handTracker(_ tracker: HandTracker, didUpdate hands: [HandPointerState])
}

// Captures webcam frames and runs Vision's native hand-pose model on each one.
// Chosen over MediaPipe because it's ANE-accelerated and ships in the OS already.
final class HandTracker: NSObject, @unchecked Sendable {

    @MainActor weak var delegate: HandTrackerDelegate?

    private let session = AVCaptureSession()
    private let videoOutputQueue = DispatchQueue(label: "com.krishay.palm.videoQueue")
    private var handPoseRequest: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 2
        return request
    }()

    // Hysteresis: pinch-on triggers at a tighter distance than pinch-off releases,
    // so noisy landmark jitter right at one threshold doesn't cause rapid on/off flicker.
    private let pinchOnThreshold: CGFloat = 0.045
    private let pinchOffThreshold: CGFloat = 0.065

    private var pinchStateByChirality: [VNChirality: Bool] = [:]

    private var isRunning = false

    func start() {
        guard !isRunning else { return }
        isRunning = true
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted, let self else { return }
            self.configureSessionIfNeeded()
            self.session.startRunning()
        }
    }

    func stop() {
        isRunning = false
        session.stopRunning()
    }

    private var configured = false

    private func configureSessionIfNeeded() {
        guard !configured else { return }
        configured = true

        session.beginConfiguration()
        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: videoOutputQueue)
        output.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        if let connection = output.connection(with: .video) {
            connection.isVideoMirrored = false // we mirror manually via the x-flip below
        }
        session.commitConfiguration()
    }

    private func process(pixelBuffer: CVPixelBuffer) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([handPoseRequest])
        } catch {
            return
        }
        guard let observations = handPoseRequest.results, !observations.isEmpty else {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.delegate?.handTracker(self, didUpdate: [])
            }
            return
        }

        var states: [HandPointerState] = []
        for observation in observations {
            guard let state = pointerState(from: observation) else { continue }
            states.append(state)
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.delegate?.handTracker(self, didUpdate: states)
        }
    }

    private func pointerState(from observation: VNHumanHandPoseObservation) -> HandPointerState? {
        guard let allPoints = try? observation.recognizedPoints(.all) else { return nil }
        guard let indexTip = allPoints[.indexTip], indexTip.confidence > 0.3 else { return nil }
        guard let thumbTip = allPoints[.thumbTip], thumbTip.confidence > 0.3 else { return nil }

        // Vision's coordinate space is (0,0) bottom-left, (1,1) top-right already.
        // Mirror the x-axis so moving your hand right moves the pointer right on
        // screen as if looking in a mirror, which is the natural feel for a webcam.
        let mirroredX = 1.0 - indexTip.location.x
        let position = CGPoint(x: mirroredX, y: indexTip.location.y)

        let dx = thumbTip.location.x - indexTip.location.x
        let dy = thumbTip.location.y - indexTip.location.y
        let distance = sqrt(dx * dx + dy * dy)

        let chirality = observation.chirality
        let wasPinching = pinchStateByChirality[chirality] ?? false
        let isPinching: Bool
        if wasPinching {
            isPinching = distance < pinchOffThreshold
        } else {
            isPinching = distance < pinchOnThreshold
        }
        pinchStateByChirality[chirality] = isPinching

        // Vision reports chirality from the subject's own perspective; since the
        // image isn't mirrored before detection, .left/.right map directly to the
        // hand as seen by the user in a mirror-like webcam view.
        let label = chirality == .left ? "L" : "R"

        return HandPointerState(normalizedPosition: position, isPinching: isPinching, pinchDistance: distance, label: label)
    }
}

extension HandTracker: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        process(pixelBuffer: pixelBuffer)
    }
}
