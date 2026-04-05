import AVFoundation
import UIKit

class CameraService: NSObject, ObservableObject {
    @Published var isSessionRunning = false
    @Published var isFrontCamera = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .off

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?
    private var captureCompletion: ((Data?) -> Void)?

    func configure() async throws {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            guard await AVCaptureDevice.requestAccess(for: .video) else { return }
        }

        session.beginConfiguration()
        session.sessionPreset = .photo

        // Add back camera input
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        let input = try AVCaptureDeviceInput(device: device)
        if session.canAddInput(input) { session.addInput(input) }
        currentDevice = device

        if session.canAddOutput(output) { session.addOutput(output) }
        output.maxPhotoQualityPrioritization = .quality

        session.commitConfiguration()
        session.startRunning()
        await MainActor.run { isSessionRunning = true }
    }

    func capturePhoto(completion: @escaping (Data?) -> Void) {
        captureCompletion = completion
        let settings = AVCapturePhotoSettings()
        if currentDevice?.hasFlash == true {
            settings.flashMode = flashMode
        }
        output.capturePhoto(with: settings, delegate: self)
    }

    func switchCamera() {
        session.beginConfiguration()
        guard let currentInput = session.inputs.first as? AVCaptureDeviceInput else {
            session.commitConfiguration()
            return
        }
        session.removeInput(currentInput)

        let newPosition: AVCaptureDevice.Position = isFrontCamera ? .back : .front
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
              let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
            // Restore original input if we fail
            if session.canAddInput(currentInput) { session.addInput(currentInput) }
            session.commitConfiguration()
            return
        }

        if session.canAddInput(newInput) {
            session.addInput(newInput)
            currentDevice = newDevice
            isFrontCamera.toggle()
        }
        session.commitConfiguration()
    }

    func toggleFlash() {
        flashMode = flashMode == .off ? .on : .off
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            print("CameraService: capture error – \(error.localizedDescription)")
            captureCompletion?(nil)
            captureCompletion = nil
            return
        }
        let data = photo.fileDataRepresentation()
        captureCompletion?(data)
        captureCompletion = nil
    }
}
