import SwiftUI
import Combine
import AVFoundation
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var player = AudioPlayerManager()

    var body: some View {
        NavigationView {
            ZStack {
                // Light background
                Color(hex: "f5f7fa")
                    .ignoresSafeArea()

                VStack(spacing: 0) {

                    // MARK: - Header
                    VStack(spacing: 16) {
                        Text("المشغل الذكي")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color(hex: "1e293b"))
                            .padding(.top, 20)

                        // File Picker Button
                        Button(action: { player.showPicker = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.badge.plus")
                                    .font(.system(size: 16, weight: .medium))
                                Text("اختر ملف صوتي أو فيديو")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "2563EB"))
                            .cornerRadius(12)
                        }

                        if !player.fileName.isEmpty {
                            Text(player.fileName)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(Color(hex: "64748b"))
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    ScrollView {
                        VStack(spacing: 16) {

                            // MARK: - Progress Section
                            VStack(spacing: 16) {
                                // Time Display
                                HStack {
                                    Text(player.formatTime(player.currentTime))
                                        .font(.system(.subheadline, design: .monospaced))
                                        .foregroundColor(Color(hex: "475569"))
                                    Spacer()
                                    Text(player.formatTime(player.duration))
                                        .font(.system(.subheadline, design: .monospaced))
                                        .foregroundColor(Color(hex: "475569"))
                                }

                                // Progress Slider
                                ProgressSlider(
                                    value: $player.currentTime,
                                    duration: player.duration,
                                    onSeek: { player.seekTo($0) }
                                )
                            }
                            .padding(20)
                            .background(Color.white)
                            .cornerRadius(16)

                            // MARK: - Speed Control
                            ControlRow(
                                icon: "speedometer",
                                title: "السرعة",
                                value: player.speed,
                                format: { String(format: "%.2fx", $0) },
                                color: Color(hex: "2563EB"),
                                onDecrease: { player.speed = max(0.5, player.speed - 0.01); player.applySpeed() },
                                onIncrease: { player.speed = min(2.0, player.speed + 0.01); player.applySpeed() },
                                onReset: { player.speed = 1.0; player.applySpeed() },
                                sliderBinding: $player.speed,
                                onSliderChange: { player.applySpeed() }
                            )

                            // MARK: - Pitch Control
                            ControlRow(
                                icon: "waveform.path",
                                title: "الطبقة",
                                value: player.pitch,
                                format: { String(format: "%.2fx", $0) },
                                color: Color(hex: "7c3aed"),
                                onDecrease: { player.pitch = max(0.5, player.pitch - 0.01); player.applyPitch() },
                                onIncrease: { player.pitch = min(2.0, player.pitch + 0.01); player.applyPitch() },
                                onReset: { player.pitch = 1.0; player.applyPitch() },
                                sliderBinding: $player.pitch,
                                onSliderChange: { player.applyPitch() }
                            )

                            // MARK: - A-B Loop Section
                            VStack(spacing: 16) {
                                Text("تكرار المقطع (A-B)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color(hex: "334155"))
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                HStack(spacing: 12) {
                                    // Loop A Button
                                    LoopPointButton(
                                        label: "A",
                                        time: player.loopA,
                                        isActive: player.loopA != nil,
                                        format: player.formatTime
                                    ) {
                                        player.setA()
                                        hapticFeedback()
                                    }

                                    // Loop Toggle
                                    VStack(spacing: 4) {
                                        Button(action: {
                                            if player.loopA != nil && player.loopB != nil {
                                                player.loopEnabled.toggle()
                                                hapticFeedback()
                                            }
                                        }) {
                                            Image(systemName: player.loopEnabled ? "repeat.1" : "repeat")
                                                .font(.system(size: 22, weight: .medium))
                                                .foregroundColor(player.loopA != nil && player.loopB != nil ? Color(hex: "2563EB") : Color(hex: "cbd5e1"))
                                                .frame(width: 50, height: 50)
                                                .background(
                                                    Circle()
                                                        .fill(player.loopEnabled ? Color(hex: "2563EB").opacity(0.1) : Color(hex: "f1f5f9"))
                                                )
                                        }
                                        Text(player.loopEnabled ? "تفعيل" : "إيقاف")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(Color(hex: "94a3b8"))
                                    }

                                    // Loop B Button
                                    LoopPointButton(
                                        label: "B",
                                        time: player.loopB,
                                        isActive: player.loopB != nil,
                                        format: player.formatTime
                                    ) {
                                        player.setB()
                                        hapticFeedback()
                                    }

                                    // Clear Button
                                    Button(action: {
                                        player.clearLoop()
                                        hapticFeedback()
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Color(hex: "94a3b8"))
                                            .frame(width: 36, height: 36)
                                            .background(Color(hex: "f1f5f9"))
                                            .cornerRadius(10)
                                    }
                                }
                            }
                            .padding(20)
                            .background(Color.white)
                            .cornerRadius(16)

                            // Extra spacing for bottom controls
                            Color.clear.frame(height: 100)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                    }
                }

                // MARK: - Bottom Playback Controls
                VStack {
                    Spacer()
                    HStack(spacing: 24) {
                        // Backward Button
                        Button(action: { player.seek(-3); hapticFeedback() }) {
                            Image(systemName: "gobackward")
                                .font(.system(size: 24))
                                .foregroundColor(Color(hex: "475569"))
                        }
                        .frame(width: 56, height: 56)
                        .background(Color.white)
                        .cornerRadius(28)
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)

                        // Play/Pause Button
                        Button(action: { player.togglePlay(); hapticFeedback() }) {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                                .offset(x: player.isPlaying ? 0 : 3)
                        }
                        .frame(width: 72, height: 72)
                        .background(Color(hex: "2563EB"))
                        .cornerRadius(36)
                        .shadow(color: Color(hex: "2563EB").opacity(0.3), radius: 12, x: 0, y: 6)

                        // Forward Button
                        Button(action: { player.seek(3); hapticFeedback() }) {
                            Image(systemName: "goforward")
                                .font(.system(size: 24))
                                .foregroundColor(Color(hex: "475569"))
                        }
                        .frame(width: 56, height: 56)
                        .background(Color.white)
                        .cornerRadius(28)
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                    }
                    .padding(.bottom, 30)
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

// MARK: - Progress Slider
struct ProgressSlider: View {
    @Binding var value: Double
    let duration: Double
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: "e2e8f0"))
                    .frame(height: 6)

                // Progress
                let progress = duration > 0 ? max(0, min(1, value / duration)) : 0
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: "2563EB"))
                    .frame(width: max(0, geometry.size.width * CGFloat(progress)), height: 6)

                // Thumb
                Circle()
                    .fill(Color(hex: "2563EB"))
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                    )
                    .offset(x: geometry.size.width * CGFloat(progress) - 9)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let newValue = Double(drag.location.x / geometry.size.width) * duration
                        value = max(0, min(newValue, duration))
                    }
                    .onEnded { drag in
                        let newValue = Double(drag.location.x / geometry.size.width) * duration
                        onSeek(max(0, min(newValue, duration)))
                    }
            )
        }
        .frame(height: 24)
        .environment(\.layoutDirection, .leftToRight)
    }
}

// MARK: - Control Row
struct ControlRow: View {
    let icon: String
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
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "475569"))
                Button(action: { onReset(); haptic() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "94a3b8"))
                }
                Spacer()
                Text(format(value))
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }

            HStack(spacing: 12) {
                Button(action: { onDecrease(); haptic() }) {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(color)
                        .frame(width: 32, height: 32)
                        .background(color.opacity(0.1))
                        .cornerRadius(8)
                }

                Slider(value: $sliderBinding, in: 0.5...2.0, step: 0.01)
                    .accentColor(color)
                    .onChange(of: sliderBinding) { _, _ in onSliderChange() }

                Button(action: { onIncrease(); haptic() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(color)
                        .frame(width: 32, height: 32)
                        .background(color.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
    }

    func haptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Loop Point Button
struct LoopPointButton: View {
    let label: String
    let time: Double?
    let isActive: Bool
    let format: (Double) -> String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isActive ? .white : Color(hex: "2563EB"))
                Text(time != nil ? format(time!) : "--:--.-")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(isActive ? .white : Color(hex: "64748b"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isActive ? Color(hex: "2563EB") : Color(hex: "f1f5f9"))
            .cornerRadius(12)
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
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
    @Published var loopEnabled: Bool = true

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
            loopA = nil
            loopB = nil
            loopEnabled = true
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

    func seek(_ seconds: Double) {
        seekTo(max(0, min(currentTime + seconds, duration)))
    }

    func applySpeed() {
        pitchControl.rate = Float(speed)
    }

    func applyPitch() {
        pitchControl.pitch = Float(log2(pitch) * 1200)
    }

    func setA() {
        loopA = currentTime
    }

    func setB() {
        if loopA != nil && currentTime > loopA! {
            loopB = currentTime
            loopEnabled = true
        }
    }

    func clearLoop() {
        loopA = nil
        loopB = nil
        loopEnabled = true
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying else { return }
            DispatchQueue.main.async {
                self.currentTime = min(self.currentTime + (0.05 * self.speed), self.duration)
                if self.loopEnabled,
                   let a = self.loopA,
                   let b = self.loopB,
                   self.currentTime >= b {
                    self.seekTo(a)
                }
            }
        }
    }

    func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        let dec = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", m, s, dec)
    }
}

#Preview {
    ContentView()
}
