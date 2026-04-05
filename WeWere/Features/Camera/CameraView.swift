import SwiftUI
import AVFoundation

struct CameraView: View {
    let eventId: UUID

    @StateObject private var cameraService = CameraService()
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var photoCount: Int = 0
    @State private var showFlash: Bool = false

    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    var body: some View {
        ZStack {
            if isSimulator {
                // Simulator: show a fake viewfinder
                simulatorPreview
            } else {
                // Device: real camera
                CameraPreviewView(session: cameraService.session)
                    .ignoresSafeArea()
            }

            // Viewfinder vignette overlay
            RadialGradient(
                colors: [.clear, .black.opacity(0.8)],
                center: .center,
                startRadius: 100,
                endRadius: UIScreen.main.bounds.height * 0.5
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // UI overlay
            VStack(spacing: 0) {
                // Top bar
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                Spacer()

                // Photo counter
                Text(String(format: "%03d", photoCount))
                    .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 64))
                    .foregroundColor(.white.opacity(0.6))
                    .monospacedDigit()

                // Metadata
                Text("ISO 400 | 1/125 | 35mm")
                    .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 12))
                    .foregroundColor(Color(hex: "919191"))
                    .padding(.top, 4)

                if isSimulator {
                    Text("SIMULATOR MODE")
                        .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 10))
                        .foregroundColor(Color(hex: "D4A853"))
                        .padding(.top, 8)
                }

                Spacer()

                // Shutter button
                ShutterButton(action: capturePhoto)
                    .padding(.bottom, 48)
            }

            // Flash overlay
            if showFlash {
                Color.white
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .task {
            // Load current photo count for this event
            let photoService = PhotoService()
            if let count = try? await photoService.getPhotoCount(eventId: eventId) {
                photoCount = count
            }
            if !isSimulator {
                try? await cameraService.configure()
            }
        }
    }

    // MARK: - Simulator Preview

    private var simulatorPreview: some View {
        ZStack {
            // Fake viewfinder with animated gradient
            LinearGradient(
                colors: [
                    Color(hex: "1a1a2e"),
                    Color(hex: "16213e"),
                    Color(hex: "0f3460"),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Crosshair
            VStack(spacing: 0) {
                Rectangle().fill(.white.opacity(0.15)).frame(width: 1, height: 40)
                Spacer().frame(height: 8)
                Rectangle().fill(.white.opacity(0.15)).frame(width: 1, height: 40)
            }
            HStack(spacing: 0) {
                Rectangle().fill(.white.opacity(0.15)).frame(width: 40, height: 1)
                Spacer().frame(width: 8)
                Rectangle().fill(.white.opacity(0.15)).frame(width: 40, height: 1)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Button {
                cameraService.toggleFlash()
            } label: {
                Image(systemName: cameraService.flashMode == .off ? "bolt.slash.fill" : "bolt.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }

            Button {
                cameraService.switchCamera()
            } label: {
                Image(systemName: "camera.rotate")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Capture

    private func capturePhoto() {
        // Haptic feedback
        HapticManager.shutter()

        // White flash animation
        withAnimation(.easeOut(duration: 0.15)) {
            showFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeIn(duration: 0.15)) {
                showFlash = false
            }
        }

        if isSimulator {
            // Generate a test image on simulator
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1080, height: 1440))
            let testImage = renderer.jpegData(withCompressionQuality: 0.8) { ctx in
                // Random color fill to make each "photo" unique
                let hue = CGFloat.random(in: 0...1)
                UIColor(hue: hue, saturation: 0.3, brightness: 0.4, alpha: 1).setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 1080, height: 1440))

                // Draw some shapes
                UIColor.white.withAlphaComponent(0.1).setFill()
                ctx.fill(CGRect(x: 200, y: 400, width: 680, height: 400))

                // Add text
                let text = "SIM #\(photoCount + 1)" as NSString
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 60, weight: .bold),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.3)
                ]
                text.draw(at: CGPoint(x: 380, y: 560), withAttributes: attrs)
            }

            photoCount += 1
            Task {
                let photoService = PhotoService()
                // Apply retro filter before upload
                let filtered = RetroFilter.apply(to: testImage) ?? testImage
                do {
                    _ = try await photoService.uploadPhoto(eventId: eventId, imageData: filtered)
                    print("Simulator photo \(photoCount) uploaded (filtered)")
                } catch {
                    print("Upload failed: \(error)")
                }
            }
        } else {
            cameraService.capturePhoto { data in
                guard let imageData = data else { return }
                photoCount += 1
                Task {
                    let photoService = PhotoService()
                    // Apply retro filter before upload
                    let filtered = RetroFilter.apply(to: imageData) ?? imageData
                    do {
                        _ = try await photoService.uploadPhoto(eventId: eventId, imageData: filtered)
                        print("Photo \(photoCount) uploaded (filtered)")
                    } catch {
                        print("Upload failed: \(error)")
                    }
                }
            }
        }
    }
}
