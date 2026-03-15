import SwiftUI
import Combine
import AVFoundation
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var player = AudioPlayerManager()

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(hex: "f8f9ff"),
                        Color(hex: "e8eaf6")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // MARK: - Title
                        Text("المشغل الذكي")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "6366f1"), Color(hex: "06b6d4")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .padding(.top, 10)

                        // MARK: - File Picker Button
                        Button(action: { player.showPicker = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 20, weight: .semibold))
                                Text("اختر ملف صوتي أو فيديو")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "6366f1"), Color(hex: "06b6d4")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: Color(hex: "6366f1").opacity(0.3), radius: 8, x: 0, y: 4)
                        }

                        if !player.fileName.isEmpty {
                            Text(player.fileName)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(Color(hex: "6366f1"))
                                .padding(.horizontal)
                        }

                        // MARK: - Play Button Section
                        VStack(spacing: 20) {
                            // Large Play Button
                            Button(action: { player.togglePlay(); hapticFeedback() }) {
                                ZStack {
                                    // Glow shadow
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "6366f1"), Color(hex: "06b6d4")],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 100, height: 100)
                                        .shadow(color: Color(hex: "6366f1").opacity(0.5), radius: 20, x: 0, y: 10)

                                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 44))
                                        .foregroundColor(.white)
                                        .offset(x: player.isPlaying ? 0 : 4)
                                }
                            }

                            // Skip Controls
                            HStack(spacing: 50) {
                                Button(action: { player.seek(-3); hapticFeedback() }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "gobackward")
                                            .font(.system(size: 24, weight: .medium))
                                        Text("3s")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundColor(Color(hex: "6366f1"))
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                                }

                                Button(action: { player.seek(3); hapticFeedback() }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "goforward")
                                            .font(.system(size: 24, weight: .medium))
                                        Text("3s")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundColor(Color(hex: "6366f1"))
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                                }
                            }
                        }
                        .padding(.vertical, 10)

                        // MARK: - Progress Section
                        VStack(spacing: 12) {
                            HStack {
                                Text(player.formatTime(player.currentTime))
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundColor(Color(hex: "6366f1"))
                                Spacer()
                                Text(player.formatTime(player.duration))
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundColor(Color(hex: "6366f1"))
                            }

                            // Custom Gradient Slider
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Background track
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 8)

                                    // Progress track with gradient
                                    let progress = max(0, min(1, player.duration > 0 ? player.currentTime / player.duration : 0))
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "6366f1"), Color(hex: "06b6d4")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geometry.size.width * CGFloat(progress), height: 8)

                                    // Thumb
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "6366f1"), Color(hex: "06b6d4")],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 8, height: 8)
                                        )
                                        .shadow(color: Color(hex: "6366f1").opacity(0.4), radius: 4, x: 0, y: 2)
                                        .offset(x: geometry.size.width * CGFloat(progress) - 10)
                                }
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let newTime = Double(value.location.x / geometry.size.width) * player.duration
                                            player.currentTime = max(0, min(newTime, player.duration))
                                        }
                                        .onEnded { value in
                                            let newTime = Double(value.location.x / geometry.size.width) * player.duration
                                            player.seekTo(max(0, min(newTime, player.duration)))
                                        }
                                )
                            }
                            .frame(height: 20)
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)

                        // MARK: - Speed Control
                        ControlCard(
                            title: "السرعة",
                            value: player.speed,
                            format: { String(format: "%.2fx", $0) },
                            color: Color(hex: "6366f1"),
                            onDecrease: { player.speed = max(0.5, player.speed - 0.01); player.applySpeed(); hapticFeedback() },
                            onIncrease: { player.speed = min(2.0, player.speed + 0.01); player.applySpeed(); hapticFeedback() },
                            onReset: { player.speed = 1.0; player.applySpeed(); hapticFeedback() },
                            sliderBinding: $player.speed,
                            onSliderChange: { player.applySpeed() }
                        )

                        // MARK: - Pitch Control
                        ControlCard(
                            title: "الطبقة",
                            value: player.pitch,
                            format: { String(format: "%.2fx", $0) },
                            color: Color(hex: "8b5cf6"),
                            onDecrease: { player.pitch = max(0.5, player.pitch - 0.01); player.applyPitch(); hapticFeedback() },
                            onIncrease: { player.pitch = min(2.0, player.pitch + 0.01); player.applyPitch(); hapticFeedback() },
                            onReset: { player.pitch = 1.0; player.applyPitch(); hapticFeedback() },
                            sliderBinding: $player.pitch,
                            onSliderChange: { player.applyPitch() }
                        )

                        // MARK: - A-B Loop Section
                        VStack(spacing: 12) {
                            Text("تحديد مقطع دقيق (A-B Loop)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "374151"))

                            HStack(spacing: 12) {
                                LoopButtonModern(
                                    title: "بداية A",
                                    time: player.loopA,
                                    action: player.setA,
                                    format: player.formatTime,
                                    color: Color(hex: "6366f1")
                                )

                                LoopButtonModern(
                                    title: "نهاية B",
                                    time: player.loopB,
                                    action: player.setB,
                                    format: player.formatTime,
                                    color: Color(hex: "06b6d4")
                                )

                                Button(action: { player.clearLoop(); hapticFeedback() }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 18, weight: .medium))
                                        Text("مسح")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
                    }
                    .padding(20)
                }
            }
            .navigationBarHidden(true)
            .environment(\.layoutDirection, .rightToLeft)
            .fileImporter(isPresented: $player.showPicker, allowedContentTypes: [UTType.audio, UTType.movie]) { result in
                switch result {
                case .success(let url):
                    player.loadFile(url: url)
                case .failure(let error):
                    print("فشل اختيار الملف: \(error.localizedDescription)")
                }
            }
        }
    }

    func hapticFeedback() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Control Card Component
struct ControlCard: View {
    let title: String
    let value: Double
    let format: (Double) -> String
    let color: Color
    let onDecrease: () -> Void
    let onIncrease: () -> Void
    let onReset: () -> Void
    @Binding var sliderBinding: Double
    let onSliderChange: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(title): \(format(value))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "374151"))
                Spacer()
                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(color)
                        .padding(8)
                        .background(color.opacity(0.1))
                        .clipShape(Circle())
                }
            }

            HStack(spacing: 16) {
                Button(action: onDecrease) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(color)
                }

                Slider(value: $sliderBinding, in: 0.5...2.0, step: 0.01)
                    .accentColor(color)
                    .onChange(of: sliderBinding) { _, _ in
                        onSliderChange()
                    }

                Button(action: onIncrease) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(color)
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Modern Loop Button
struct LoopButtonModern: View {
    let title: String
    let time: Double?
    let action: () -> Void
    let format: (Double) -> String
    let color: Color

    var body: some View {
        Button(action: {
            action()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "6b7280"))
                Text(time != nil ? format(time!) : "--:--.-")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Audio Manager
class AudioPlayerManager: NSObject, ObservableObject {
    private var engine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var pitchControl = AVAudioUnitTimePitch()
    private var audioFile: AVAudioFile?
    private var timer: Timer?

    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var fileName = ""
    @Published var speed: Double = 1.0
    @Published var pitch: Double = 1.0
    @Published var showPicker = false
    @Published var loopA: Double? = nil
    @Published var loopB: Double? = nil

    override init() {
        super.init()
        setupAudioSession()
        setupEngine()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch { print("Audio Session Error: \(error)") }
    }

    private func setupEngine() {
        engine.attach(playerNode)
        engine.attach(pitchControl)
        engine.connect(playerNode, to: pitchControl, format: nil)
        engine.connect(pitchControl, to: engine.mainMixerNode, format: nil)
    }

    func loadFile(url: URL) {
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer { if shouldStopAccessing { url.stopAccessingSecurityScopedResource() } }

        do {
            playerNode.stop()
            audioFile = try AVAudioFile(forReading: url)
            fileName = url.lastPathComponent
            duration = Double(audioFile!.length) / audioFile!.fileFormat.sampleRate
            currentTime = 0
            scheduleFile()
            startTimer()
        } catch { print("File Load Error: \(error)") }
    }

    private func scheduleFile() {
        guard let file = audioFile else { return }
        playerNode.scheduleFile(file, at: nil)
    }

    func togglePlay() {
        if isPlaying {
            playerNode.pause()
            isPlaying = false
        } else {
            if !engine.isRunning { try? engine.start() }
            playerNode.play()
            isPlaying = true
        }
    }

    func seekTo(_ time: Double) {
        guard let file = audioFile else { return }
        let sampleTime = AVAudioFramePosition(time * file.fileFormat.sampleRate)
        let remainingFrames = AVAudioFrameCount(max(0, file.length - sampleTime))
        playerNode.stop()
        if remainingFrames > 0 {
            playerNode.scheduleSegment(file, startingFrame: sampleTime, frameCount: remainingFrames, at: nil)
            if isPlaying { playerNode.play() }
        }
        currentTime = time
    }

    func seek(_ seconds: Double) { seekTo(max(0, min(currentTime + seconds, duration))) }
    func applySpeed() { pitchControl.rate = Float(speed) }
    func applyPitch() { pitchControl.pitch = Float(log2(pitch) * 1200) }
    func setA() { loopA = currentTime }
    func setB() { loopB = currentTime }
    func clearLoop() { loopA = nil; loopB = nil }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying else { return }
            DispatchQueue.main.async {
                self.currentTime = min(self.currentTime + (0.05 * self.speed), self.duration)
                if let a = self.loopA, let b = self.loopB, self.currentTime >= b { self.seekTo(a) }
            }
        }
    }

    func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60, s = Int(seconds) % 60, dec = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", m, s, dec)
    }
}

#Preview {
    ContentView()
}
